variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (for tagging)."
  type        = string
  default     = "dev"
}

variable "name" {
  description = "Resource name prefix."
  type        = string
  default     = "banking-dev"
}

variable "cluster_name" {
  description = "Existing EKS cluster to grant the bootstrap host access to."
  type        = string
  default     = "banking-dev"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH. Create one first: aws ec2 create-key-pair --key-name banking-bootstrap --query 'KeyMaterial' --output text > banking-bootstrap.pem && chmod 400 banking-bootstrap.pem"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Your IP in CIDR form, e.g. \"203.0.113.5/32\". Find it with `curl -s ifconfig.me`. No default — never leave SSH open to 0.0.0.0/0."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bootstrap host."
  type        = string
  default     = "t3.small"
}
