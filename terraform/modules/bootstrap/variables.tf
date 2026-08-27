variable "name" {
  description = "Resource name prefix (e.g. banking-dev)."
  type        = string
}

variable "cluster_name" {
  description = "Existing EKS cluster to grant this host access to."
  type        = string
}

variable "vpc_id" {
  description = "VPC the bootstrap host runs in (should match the cluster's VPC)."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID to launch the host into (needs a public IP for SSH)."
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access. Create one with: aws ec2 create-key-pair --key-name <name> --query 'KeyMaterial' --output text > <name>.pem"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in on port 22, e.g. \"<your-ip>/32\". No default on purpose — never leave SSH open to 0.0.0.0/0."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bootstrap host."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
