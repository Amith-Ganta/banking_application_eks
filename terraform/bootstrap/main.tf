# Standalone root for the Ansible bootstrap host. Reads the EXISTING VPC/cluster
# via data sources (no dependency on the Phase-1 state), then calls the reusable
# bootstrap module. Apply this on its own: `cd terraform/bootstrap && terraform apply`.

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.name]
  }
}

# Any public subnet works — it just needs a route to an internet gateway.
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.name}-public-*"]
  }
}

module "bootstrap" {
  source = "../modules/bootstrap"

  name             = var.name
  cluster_name     = var.cluster_name
  vpc_id           = data.aws_vpc.this.id
  subnet_id        = tolist(data.aws_subnets.public.ids)[0]
  key_pair_name    = var.key_pair_name
  allowed_ssh_cidr = var.allowed_ssh_cidr
  instance_type    = var.instance_type
}
