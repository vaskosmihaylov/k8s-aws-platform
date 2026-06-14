variable "region" {
  description = "AWS region for the Terraform state backend resources."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project name used as a prefix for all bootstrap resource names."
  type        = string
  default     = "k8s-platform"
}
