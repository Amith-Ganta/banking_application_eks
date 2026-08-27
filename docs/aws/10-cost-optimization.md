# Phase 10 — Cost Awareness & Right-Sizing (EKS)

> **Status:** 📝 Reference — describes the current cost posture and the concrete
> next steps to cut spend further. Nothing here is required to run the
> platform; treat it as the cost story to tell in review.

## Current posture

| Decision | Where | Cost impact |
|---|---|---|
| Managed node group, **ON_DEMAND**, `m7i-flex.large` (dev) / `t3.xlarge` (prod) | `terraform/environments/{dev,prod}/variables.tf` | Simplest to reason about; no spot-interruption handling needed for a self-hosted Postgres/Kafka node. Dev is pinned to `m7i-flex.large` specifically because the AWS account is on the Free Plan, which blocks non-free-tier instance families — a stopgap noted in the variable's own description. |
| Cluster autoscaling via `min/max/desired` on the node group (dev: 1/6/5, prod: 3/8/4) | same | Scales node count to load instead of running a fixed fleet at peak size. |
| Per-service **HPA** on all 30 microservices + api-gateway + frontend | `deploy/helm/banking-platform/templates/*hpa*` | Pods scale to traffic rather than being sized for worst-case; keeps the node group smaller than a static-replica deployment would need. |
| Tuned `requests`/`limits` per service (not defaults) | chart `values.yaml` | Bin-packing efficiency — the scheduler isn't reserving more than each Go service actually needs. |
| **Self-hosted** Postgres/Redis/Kafka in-cluster, not RDS/ElastiCache/MSK | `deploy/helm/banking-platform/templates/postgres.yaml` etc. | Avoids per-managed-service monthly minimums (RDS + ElastiCache + MSK would each carry a base cost) at the expense of owning backup/HA (mitigated by Velero, see [08-velero.md](08-velero.md)). |
| S3 for Velero backups + Terraform state, versioned | `terraform/modules/velero`, `terraform/bootstrap` | Object storage is cents/GB; the real cost lever here is **retention**, not the storage class. |

## Where the next real savings are

1. **Karpenter instead of the managed node group + Cluster Autoscaler.**
   Karpenter provisions the *exact* instance shape a pending pod needs (rather
   than scaling a fixed instance-type node group) and can mix in **Spot** for
   the stateless services (every Go microservice + frontend — none hold local
   state), keeping only the Postgres/Kafka/Redis nodes on On-Demand. This is
   the highest-leverage change available and is a straight swap in
   `terraform/modules/eks` (the `aws-ia/eks-blueprints-addons` pattern already
   used for `cluster_addons` in that module supports adding the Karpenter
   addon + a `NodePool`/`EC2NodeClass` CR pair).
2. **Kubecost (or OpenCost)** for per-namespace/per-service cost allocation —
   installs as another Argo CD app the same way `kube-prometheus-stack` does,
   and answers "which of the 30 services is the expensive one" instead of only
   seeing the total AWS bill.
3. **Spot for CI runners**, if self-hosted runners are ever added — GitHub-hosted
   runners (current setup, see [03-github-actions-cicd.md](03-github-actions-cicd.md))
   already avoid this cost entirely.
4. **Shorter Velero retention tiering**: the `--ttl 168h0m0s` (7-day) schedule
   in [08-velero.md](08-velero.md) Step 5 is already short; an S3 lifecycle
   rule to transition anything retained longer (e.g. a monthly manual backup)
   to Glacier would cut long-term backup storage cost further.

## Why this order

Karpenter is listed first because it's the only change that touches the
*compute* bill directly (the dominant cost line for an EKS cluster running a
self-hosted data layer); Kubecost is listed second because visibility should
exist before optimizing further — right-sizing without per-service cost data
is guesswork.
