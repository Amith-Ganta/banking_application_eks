terraform {
  backend "s3" {
    bucket       = "banking-eks-tfstate-651103158261"
    key          = "prod/networking.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
