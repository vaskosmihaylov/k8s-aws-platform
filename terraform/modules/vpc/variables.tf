variable "name" {
  description = "Name prefix used for VPC resources."
  type        = string
}

variable "cidr" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to deploy subnets into."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets hosting EKS nodes (one per AZ)."
  type        = list(string)
  default     = ["10.0.10.0/23", "10.0.12.0/23", "10.0.14.0/23"]
}

variable "database_subnets" {
  description = "CIDR blocks for isolated database subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "cluster_name" {
  description = "EKS cluster name. Used for subnet discovery tags."
  type        = string
}

variable "tags" {
  description = "Tags applied to all VPC resources."
  type        = map(string)
  default     = {}
}
