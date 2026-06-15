variable "region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "k8s-platform-dev"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Restrict to your IP."
  type        = list(string)
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128 && can(regex("^[!-~]+$", var.db_password)) && !can(regex("[/@\"]", var.db_password))
    error_message = "db_password must be 8-128 printable ASCII characters and must not contain '/', '@', double quotes, or spaces."
  }
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance."
  type        = string
  default     = "dbadmin"
}

variable "db_name" {
  description = "Name of the initial database to create in the RDS instance."
  type        = string
  default     = "appdb"
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repositories."
  type        = string
}

variable "github_repo" {
  description = "Name of the GitHub repository for GitHub Actions OIDC trust (config repo)."
  type        = string
  default     = "k8s-aws-platform"
}

variable "github_app_repo" {
  description = "Name of the GitHub repository for the demo application."
  type        = string
  default     = "k8s-demo-api"
}

variable "route53_zone_name" {
  description = "Route 53 hosted zone domain name."
  type        = string
  default     = "k8s.gaiaderma.com"
}
