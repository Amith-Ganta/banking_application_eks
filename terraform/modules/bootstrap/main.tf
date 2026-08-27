# A small EC2 host that Ansible (../../ansible/bootstrap.yml) targets to install
# Docker/Go/kubectl/Helm/Terraform/Argo CD CLI and bootstrap GitOps onto an
# EXISTING EKS cluster. This module only creates the host + its IAM identity;
# it does not touch the cluster's node groups or workloads.
#
# The tricky part isn't the EC2 instance — it's that `cluster_name`'s
# authentication_mode is API_AND_CONFIG_MAP (see ../eks/main.tf), so a brand
# new IAM role gets zero Kubernetes RBAC by default even after
# `aws eks update-kubeconfig` succeeds. The access entry + policy association
# below are what actually let this host's kubectl/helm talk to the cluster.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# --- Network access ---
resource "aws_security_group" "bootstrap" {
  name        = "${var.name}-bootstrap"
  description = "SSH access to the Ansible bootstrap host."
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from the allowed CIDR only."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-bootstrap" })
}

# --- IAM identity for the host ---
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bootstrap" {
  name               = "${var.name}-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

# Just enough to run `aws eks update-kubeconfig` — Kubernetes-level
# authorization comes from the access entry below, not this policy.
data "aws_iam_policy_document" "eks_describe" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster", "eks:ListClusters"]
    resources = [data.aws_eks_cluster.this.arn]
  }
}

resource "aws_iam_role_policy" "eks_describe" {
  name   = "eks-describe"
  role   = aws_iam_role.bootstrap.id
  policy = data.aws_iam_policy_document.eks_describe.json
}

# SSM Session Manager as a break-glass shell — works even before allowed_ssh_cidr
# is dialed in correctly, no open port needed.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bootstrap" {
  name = "${var.name}-bootstrap"
  role = aws_iam_role.bootstrap.name
}

# --- Kubernetes-side authorization (EKS access entries, not aws-auth) ---
resource "aws_eks_access_entry" "bootstrap" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.bootstrap.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bootstrap_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.bootstrap.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bootstrap]
}

# --- The host itself ---
resource "aws_instance" "bootstrap" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bootstrap.id]
  iam_instance_profile   = aws_iam_instance_profile.bootstrap.name
  key_name               = var.key_pair_name

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = merge(var.tags, { Name = "${var.name}-bootstrap" })
}
