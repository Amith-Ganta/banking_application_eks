# Ansible bootstrap

`bootstrap.yml` provisions a **fresh Ubuntu/Debian bootstrap host** (an EC2
instance you stand up separately — not an EKS worker node, not your laptop)
with Docker, Go, kubectl, AWS CLI v2, Helm, Terraform, and the Argo CD CLI,
then points it at the `banking-dev` EKS cluster and bootstraps Argo CD +
GitOps exactly as described in
[docs/aws/04-argocd.md](../docs/aws/04-argocd.md).

## Step 0 — provision the bootstrap host

If you don't already have a host to target, `terraform/bootstrap` stands one
up — a small EC2 instance with an IAM role and, critically, an **EKS access
entry** so its `kubectl`/`helm` calls actually work against `banking-dev`
(the cluster's `API_AND_CONFIG_MAP` auth mode gives a brand-new IAM role zero
Kubernetes RBAC otherwise). Full details in
[terraform/bootstrap/README.md](../terraform/bootstrap/README.md).

```bash
cd ../terraform/bootstrap
terraform init
terraform apply -var="key_pair_name=<your-key-pair>" -var="allowed_ssh_cidr=<your-ip>/32"
terraform output public_ip
cd ../../ansible
```

Already have a host of your own with the right IAM permissions? Skip this
step and go straight to Usage below.

## Usage

```bash
cp inventory.ini.example inventory.ini
# edit inventory.ini with your bootstrap host's IP/DNS, SSH user and key

ansible-playbook -i inventory.ini bootstrap.yml
```

## Requirements

- Ansible with the `kubernetes.core` collection installed on the control
  machine: `ansible-galaxy collection install -r requirements.yml`.
- The target host must have outbound internet access and either an IAM
  instance profile or `~/.aws/credentials` with permission to run
  `aws eks update-kubeconfig` and deploy to the cluster. If the host also
  needs to actually *call* the Kubernetes API (this playbook does), its
  principal needs an EKS access entry too — `terraform/bootstrap` sets this
  up automatically; a hand-rolled host needs one created manually.
- The cluster itself must already exist (`terraform/environments/dev`).

`ansible.cfg` disables strict host-key checking so the first, non-interactive
SSH connection to a freshly launched bootstrap host doesn't hang waiting on a
known_hosts prompt.
