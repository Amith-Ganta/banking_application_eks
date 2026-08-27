output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN of the EKS worker node IAM role."
  value       = aws_iam_role.node.arn
}

output "ecr_push_policy_arn" {
  description = "ARN of the ECR push policy for CI."
  value       = aws_iam_policy.ecr_push.arn
}

output "github_actions_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC (no static AWS keys). Empty string in environments where create_github_oidc is false."
  value       = try(aws_iam_role.github_actions[0].arn, "")
}
