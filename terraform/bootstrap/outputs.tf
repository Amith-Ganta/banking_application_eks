output "public_ip" {
  description = "Bootstrap host public IP — put this in ansible/inventory.ini as ansible_host."
  value       = module.bootstrap.public_ip
}

output "public_dns" {
  description = "Bootstrap host public DNS name (alternative to public_ip)."
  value       = module.bootstrap.public_dns
}

output "ssh_command" {
  description = "Quick manual SSH check before running Ansible."
  value       = "ssh -i <your-key>.pem ubuntu@${module.bootstrap.public_ip}"
}

output "iam_role_arn" {
  description = "IAM role assumed by the host (already granted an EKS access entry)."
  value       = module.bootstrap.iam_role_arn
}
