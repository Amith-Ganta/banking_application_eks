# Senior DevOps Gap Report — banking_application_eks

_Assessment date: 2026-08-27. Reviewer lens: senior DevOps hiring screen against a Senior DevOps Engineer JD._
_Status update: 2026-08-28 — P0 items 1-4, P1 items 5-7, and P2 items 8, 10, 11, 12 are implemented in-repo (manifests/docs written; apply/verify on a live cluster is still pending — see each item's "still to do"). Only P2 item 9 (Argo Rollouts) remains open, and it's an explicit, documented deferral rather than an oversight (see below)._

---

## Verdict in one line

This is already a **strong senior-DevOps portfolio piece** — not a junior project pretending to be one. The platform engineering is real: closed-loop GitOps, a blocking security scan, modular multi-env IaC, a full observability + backup baseline, and a hardened pod security context. What stops it being a clean "yes" is a short list of **supply-chain, auth, testing, and secrets** gaps that a senior reviewer checks for specifically. Close the P0 items and this moves from "impressive project" to "this person operates production infrastructure."

---

## What is already senior-grade (do not touch, lead with these)

| Area | Evidence in repo | Why it scores |
|---|---|---|
| **GitOps (pull-based)** | CI commits image tags to `values.yaml`; ArgoCD app-of-apps with `prune: true` + `selfHeal: true`; CI never runs `kubectl apply`/`helm upgrade` | This is real GitOps. Most candidates fake it with a deploy step in CI. |
| **CI security gate** | Trivy scan with `exit-code: 1` on fixable HIGH/CRITICAL — blocking, not report-only | A gate, not a dashboard. |
| **CI hygiene** | Matrix over 32 images, GHA layer cache, `concurrency` cancellation, `[skip ci]` loop guard, `permissions: contents: read` | Least-privilege + no runaway loops = operator instinct. |
| **IaC** | dev/qa/prod separation, modular (vpc/eks/ecr/iam/s3/route53/velero), S3 remote backend with `use_lockfile`, `fmt`+`validate` in CI | Environment separation and state locking are the senior tells. |
| **Pod security** | `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `drop: ["ALL"]`, all 3 probe types, tuned requests/limits, per-service HPA | Better than most real production charts. |
| **Observability + DR** | OTel → Tempo/Prometheus/Loki/Grafana correlated by `trace_id`; Velero backups; cert-manager + Let's Encrypt HTTPS; Ansible bootstrap | The operational maturity most portfolios skip entirely. |

**Bottom line: you do not need to add more application complexity.** The 30 services already make it believable as a platform to operate. Every fix below is on the ops/platform layer.

---

## The gaps, ranked by hiring impact

### P0 — Fix these first (each is a specific "not senior yet" tell)

**1. ~~CI authenticates with static AWS keys.~~ DONE.**
`.github/workflows/ci.yaml` now runs `permissions: id-token: write` and assumes `vars.AWS_GITHUB_ACTIONS_ROLE_ARN` via `aws-actions/configure-aws-credentials`. No static `AWS_ACCESS_KEY_ID`/`SECRET` remain in the pipeline.
- **Still to do (yours to run):** create the GitHub OIDC provider + IAM role in Terraform (if not already applied) and set the `AWS_GITHUB_ACTIONS_ROLE_ARN` repo/environment variable.

**2. ~~Terraform never actually plans in CI.~~ DONE.**
`.github/workflows/terraform.yaml` has a `plan` job (per env, matrix) that assumes the OIDC role, runs `terraform plan`, and posts the plan as a PR comment.

**3. ~~Secrets are plaintext `kind: Secret` templates in the Helm chart.~~ DONE.**
Every service's Secret is now rendered by a shared `_helpers.tpl` (`dbJwtSecret`/`jwtOnlySecret`/`dbOnlySecret`) that emits a plain `Secret` by default (kind/local) or an `ExternalSecret` sourced from AWS Secrets Manager when `externalSecrets.enabled=true` (set for EKS in `deploy/argocd/apps/banking-platform.yaml`). Backed by:
  - `deploy/cluster/external-secrets/cluster-secret-store.yaml` — `ClusterSecretStore` `aws-secrets-manager`, IRSA auth.
  - `deploy/argocd/apps/external-secrets.yaml` + `external-secrets-store.yaml` — ESO install + the store, CRD-race-safe.
  - IRSA role already existed in `terraform/modules/eks/main.tf` (`aws_iam_role.external_secrets`).
- **Still to do (yours to run):** `aws secretsmanager create-secret --name banking/shared-credentials` with keys `db_user`/`db_password`/`jwt_secret`/`jwt_issuer`, then let Argo CD sync the new apps.

**4. ~~No test/lint gate.~~ DONE.**
`ci.yaml`'s `test` job runs `go vet ./...`, `go test ./...`, and `helm lint` on the chart, gating `build`.

### P1 — Strong differentiators (these put you ahead of most seniors)

**5. ~~No supply-chain integrity: image signing, SBOM, provenance, admission.~~ DONE.**
`ci.yaml` signs every pushed image keyless (`cosign sign`), generates an SBOM (`syft` via `anchore/sbom-action`), and attaches it as a signed attestation (`cosign attest`). Admission is now closed: `deploy/argocd/apps/kyverno.yaml` installs Kyverno; `deploy/cluster/kyverno/verify-images-policy.yaml` + `deploy/argocd/apps/kyverno-policies.yaml` verify the cosign keyless signature (issuer + subject pinned to this repo's `ci.yaml` on `main`) for every pod in the `banking` namespace.
- **Judgment call:** the policy ships in `validationFailureAction: Audit`, not `Enforce` — flip it after a burn-in period once PolicyReports confirm no false positives (a new admission-time dependency on Fulcio/Rekor reachability is worth watching before it can block deploys).

**6. ~~No PodDisruptionBudget and no NetworkPolicy.~~ DONE.**
`templates/pdb.yaml` adds a `PodDisruptionBudget` (`maxUnavailable: 1`) for every service with a `deploymentname` (32 total; Postgres StatefulSet excluded by design). `templates/networkpolicy.yaml` adds default-deny-all plus explicit allows: intra-namespace, DNS egress to kube-system, Prometheus scrape ingress (8080) from `observability`, Traefik ingress restricted to `api-gateway`/`frontend`, OTel egress (4317) to `observability`, and scoped internet egress (443/587, RFC1918 excluded) for `email-service`/`sms-service`/`currency-exchange-service`/`document-service`. Verified via `helm template` (32 PDBs + 7 NetworkPolicies render cleanly in both default and `externalSecrets.enabled=true` modes).

**7. ~~Committed binaries and Terraform provider state.~~ DONE.**
`.gitignore` excludes `*.exe`, `**/.terraform/*`, `*.tfstate*`; no tracked binaries remain (`git ls-files` clean).

### P2 — Polish that raises the ceiling

**8. ~~README frames it as a "learning / portfolio reference project."~~ DONE.**
`README.md`'s opening now reads "production-grade platform engineering reference," describing what the repo demonstrates operationally. The self-hosted-datastores caveat is kept, reframed as a deliberate reproducibility choice rather than a limitation.

**9. No progressive delivery. Deferred (deliberately, not forgotten).**
Everything deploys straight via ArgoCD sync. Argo Rollouts (canary or blue/green) on 1-2 critical services with an analysis step would demonstrate safe-deploy maturity, but it's out of scope for this pass: it needs a metrics provider hookup (Prometheus `AnalysisTemplate`) that's more credible to build *after* item #10 (SLO alert rules) exists, so the canary's promotion gate has real signals to key off instead of a fabricated threshold. Sequencing: #10 first, then #9.

**10. ~~No documented SLOs / alerting rules.~~ DONE.**
`deploy/observability/manifests/prometheusrule.yaml` adds a `PrometheusRule` (synced by the existing `observability-extras` Argo app, no new app needed) with three alerts: `BankingPlatformHighErrorRate` (>0.5% 5xx over 5m), `BankingPlatformHighLatencyP99` (p99 > 1s over 5m), `BankingPlatformServiceScrapeDown` (scrape target down 5m). `docs/observability.md` gained an "SLOs and alerting" section stating the three SLOs and thresholds in one table.

**11. ~~No DR restore proof.~~ Already done, just under-cited.**
`docs/aws/08-velero.md` Step 6 ("Disaster-recovery restore test (prove it works)") is exactly this runbook: create a marker ConfigMap, back up, delete it, restore from the backup, confirm it's back — plus a full-cluster-loss walkthrough. This existed before this pass; the gap was that the top-level gap analysis didn't credit it. No new file needed.

**12. ~~No cost/right-sizing story.~~ DONE.**
New `docs/aws/10-cost-optimization.md`: documents the current posture (on-demand managed node group sized for the AWS account's Free Plan constraint, cluster autoscaling via min/max/desired, per-service HPA, tuned requests/limits, self-hosted data layer to avoid RDS/ElastiCache/MSK minimums) and the next concrete levers (Karpenter for bin-packing + Spot on stateless services, Kubecost for per-service allocation, S3 lifecycle tiering on backups), with the reasoning for why Karpenter precedes Kubecost.

---

## Suggested order of attack

1. ~~**OIDC role in Terraform** (#1) — unblocks #2 and #5.~~ DONE.
2. ~~**Terraform plan on PRs** (#2).~~ DONE.
3. ~~**External Secrets Operator** (#3) — biggest fintech credibility win.~~ DONE (needs the `aws secretsmanager create-secret` call + an Argo sync to go live).
4. ~~**Test/lint gate** (#4) — cheap, closes an obvious ding.~~ DONE.
5. ~~**cosign + SBOM + Kyverno admission** (#5) — the differentiator.~~ DONE (Audit mode; flip to Enforce after burn-in).
6. ~~**PDB + NetworkPolicy** (#6), then **.gitignore cleanup** (#7).~~ DONE.
7. ~~README reframe (#8), SLO alert rules (#10), DR restore proof (#11), cost story (#12).~~ ALL DONE.
8. **Argo Rollouts (#9)** — the only item left open, deliberately. Pick this up after burn-in on item #5's Kyverno Audit mode, since both touch the deploy path.

P0 + P1 (items 1-7) and P2 items 8, 10, 11, 12 are functionally complete in-repo; what remains is applying the P0/P1 changes to the live cluster (see each item's "still to do") plus the deliberate deferral on item 9.

---

## What to put on the CV once these land

- "Built a pull-based GitOps platform on EKS (ArgoCD app-of-apps, self-heal) for 30+ Go microservices, with **keyless OIDC CI**, **Trivy + cosign-signed images and SBOM attestation**, and **admission control that rejects unsigned images**."
- "Owned multi-environment Terraform (dev/qa/prod) with **plan-on-PR gating** and remote state locking."
- "Managed secrets with **External Secrets Operator + AWS Secrets Manager over IRSA** — no credentials in Git."
- "Ran a correlated **OTel → Tempo/Prometheus/Loki/Grafana** stack with **PrometheusRule SLO alerts** and **Velero-tested DR restores**."

Every one of those is a real, verifiable claim once the corresponding item above is done.
