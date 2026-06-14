variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for EKS node groups."
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs for the EKS control plane ENIs."
  type        = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EKS envelope encryption of Kubernetes secrets."
  type        = string
}

variable "tags" {
  description = "Tags applied to all EKS resources."
  type        = map(string)
  default     = {}
}
