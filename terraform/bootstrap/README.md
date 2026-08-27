# Ansible bootstrap host — AWS resources (standalone Terraform stack)

This is an **optional, standalone** Terraform stack that provisions the **EC2
host Ansible targets** (`../../ansible/bootstrap.yml`). It is **deliberately
separate** from the core infrastructure in [`../environments/dev`](../environments/dev):

- It has its **own state file** (`dev/bootstrap.tfstate` in the shared state
  bucket), so it can be applied and destroyed **independently** of the cluster.
- A normal core-infra `terraform apply` (in `environments/dev`) **never**
  creates these resources — this stack is opt-in.
- It reads the **already-running VPC and cluster** via data sources (no
  dependency on the Phase-1 stack's outputs).

> This stack creates only the **host and its AWS identity**. What actually
> happens on the host (installing Docker/kubectl/Helm/Argo CD CLI, bootstrapping
> GitOps) is `ansible/bootstrap.yml`, documented alongside
> [docs/aws/04-argocd.md](../../docs/aws/04-argocd.md).

---

## Why this isn't just "launch an EC2 instance"

The EKS cluster's `authentication_mode` is `API_AND_CONFIG_MAP` (see
[`../modules/eks/main.tf`](../modules/eks/main.tf)), and
`enable_cluster_creator_admin_permissions` only grants **the identity that ran
`terraform apply` for the cluster** an EKS access entry. A brand-new IAM role —
like the one this bootstrap host assumes — gets **zero** Kubernetes RBAC by
default, even after `aws eks update-kubeconfig` succeeds. Without an access
entry, every `kubectl`/`helm`/Argo CD bootstrap command from this host would
fail with a 403 the moment it touched the API server.

This stack creates that access entry so the host actually works out of the box.

## What Terraform creates here

| Resource | Purpose |
|---|---|
| `aws_instance.bootstrap` | Ubuntu 22.04 EC2 host (public subnet, public IP) that Ansible targets. |
| `aws_security_group.bootstrap` | Allows SSH (22) only from `var.allowed_ssh_cidr` — never `0.0.0.0/0`. |
| `aws_iam_role.bootstrap` + instance profile | The host's identity. |
| `aws_iam_role_policy.eks_describe` | Just enough (`eks:DescribeCluster`/`ListClusters`) for `aws eks update-kubeconfig` to work. |
| `aws_iam_role_policy_attachment.ssm` | `AmazonSSMManagedInstanceCore` — lets you `aws ssm start-session` into the host even before SSH access is dialed in. |
| `aws_eks_access_entry` + `aws_eks_access_policy_association` | Grants the host's IAM role `AmazonEKSClusterAdminPolicy` on the cluster — the actual Kubernetes-side authorization described above. |

## What it does NOT do
- ❌ Does **not** install anything on the host (that's `ansible/bootstrap.yml`).
- ❌ Does **not** touch the EKS cluster's node groups, workloads, or core infra state.
- ❌ Does **not** manage an SSH key pair — you bring your own (see below), so no
  private key material ever lands in Terraform state.

---

## Prerequisites
- The **EKS cluster and VPC already exist** (`terraform/environments/dev`).
- An **existing EC2 key pair**:
  ```bash
  aws ec2 create-key-pair --key-name banking-bootstrap \
    --query 'KeyMaterial' --output text > banking-bootstrap.pem
  chmod 400 banking-bootstrap.pem
  ```
- Your current public IP, for `allowed_ssh_cidr`:
  ```bash
  curl -s ifconfig.me   # -> e.g. 203.0.113.5, use "203.0.113.5/32"
  ```

## Usage
```bash
cd terraform/bootstrap

terraform init
terraform plan  -var="key_pair_name=banking-bootstrap" -var="allowed_ssh_cidr=<your-ip>/32"
terraform apply -var="key_pair_name=banking-bootstrap" -var="allowed_ssh_cidr=<your-ip>/32"

terraform output public_ip
```

Then point Ansible at it — see [`../../ansible/README.md`](../../ansible/README.md):
```bash
cd ../../ansible
cp inventory.ini.example inventory.ini
# fill in ansible_host = terraform output public_ip, ansible_ssh_private_key_file = path to banking-bootstrap.pem
ansible-playbook -i inventory.ini bootstrap.yml
```

## Teardown (independent of the cluster)
```bash
cd terraform/bootstrap
terraform destroy -var="key_pair_name=banking-bootstrap" -var="allowed_ssh_cidr=<your-ip>/32"
```
There's no reason to leave this host running once Argo CD is bootstrapped —
everything after that is managed by GitOps, not by this box.
