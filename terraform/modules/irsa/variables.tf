variable "role_name" {
  description = "Name of the IAM role to create."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from the EKS cluster (without https://)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider associated with the EKS cluster."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name that will assume this role."
  type        = string
}

variable "policy_arns" {
  description = "Map of IAM policy ARNs to attach to the role, keyed by stable attachment names."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to the IAM role."
  type        = map(string)
  default     = {}
}
