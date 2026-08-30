# IAM roles for EKS: the cluster control-plane role and the worker node role,
# each with the AWS-managed policies EKS requires. These are consumed by the EKS
# module in Phase 9.

data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Worker node role ---
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-eks-node"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
  tags               = var.tags
}

# Managed policies required by EKS worker nodes.
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- Policy for CI to push images to ECR (attach to a CI user/role later) ---
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "AuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid    = "PushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name        = "${var.name}-ecr-push"
  description = "Allows pushing container images to ECR (for CI)."
  policy      = data.aws_iam_policy_document.ecr_push.json
  tags        = var.tags
}

# --- GitHub Actions OIDC federation ---
# Replaces long-lived AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY secrets in CI.
# GitHub's runner exchanges its workflow OIDC token for short-lived AWS creds
# by assuming this role directly — no static keys stored anywhere.
#
# count-gated on create_github_oidc: an AWS account allows only ONE OIDC
# provider per issuer URL, so only the environment that sets this true (dev)
# actually creates it. qa/prod call this same module but leave it false.
data "tls_certificate" "github_actions" {
  count = var.create_github_oidc ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count           = var.create_github_oidc ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions[0].certificates[0].sha1_fingerprint]
  tags            = var.tags
}

data "aws_iam_policy_document" "github_actions_assume" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to: pushes to main (build+push+gitops job) and PRs from this repo
    # (build+scan + terraform plan jobs). No other ref/repo can assume this role.
    # Wildcard suffix on org/repo tolerates GitHub's "owner@id/repo@id" sub format,
    # which it emits instead of plain "owner/repo" once a repo/org has rename history.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}*/${var.github_repo}*:ref:refs/heads/main",
        "repo:${var.github_org}*/${var.github_repo}*:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count              = var.create_github_oidc ? 1 : 0
  name               = "${var.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume[0].json
  tags               = var.tags
}

# Image push (build job) — same scoped policy the old IAM user used.
resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  count      = var.create_github_oidc ? 1 : 0
  role       = aws_iam_role.github_actions[0].name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# `terraform plan` in CI is read-only by design (only a human runs apply, per
# project convention) — AWS-managed ReadOnlyAccess is the correct scope, no
# custom policy needed and no risk of CI mutating infra.
resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  count      = var.create_github_oidc ? 1 : 0
  role       = aws_iam_role.github_actions[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
