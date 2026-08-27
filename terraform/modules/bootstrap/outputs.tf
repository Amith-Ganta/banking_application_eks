output "instance_id" {
  description = "EC2 instance ID of the bootstrap host."
  value       = aws_instance.bootstrap.id
}

output "public_ip" {
  description = "Public IP — put this in ansible/inventory.ini as ansible_host."
  value       = aws_instance.bootstrap.public_ip
}

output "public_dns" {
  description = "Public DNS name (alternative to public_ip)."
  value       = aws_instance.bootstrap.public_dns
}

output "iam_role_arn" {
  description = "IAM role assumed by the host (also the EKS access-entry principal)."
  value       = aws_iam_role.bootstrap.arn
}
