variable "name" {
  description = "Name prefix for IAM resources."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "create_github_oidc" {
  description = "Create the GitHub Actions OIDC provider + CI role. An AWS account can only have ONE OIDC provider per issuer URL, so this must be true in exactly one environment (dev) — leave false in qa/prod to avoid an EntityAlreadyExists collision if they're ever applied."
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub org/user that owns the repo allowed to assume the CI role via OIDC. Required only when create_github_oidc is true."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo name allowed to assume the CI role via OIDC. Required only when create_github_oidc is true."
  type        = string
  default     = ""
}
