variable "identifier" {
  description = "Unique identifier for the RDS instance."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128 && can(regex("^[!-~]+$", var.db_password)) && !can(regex("[/@\"]", var.db_password))
    error_message = "db_password must be 8-128 printable ASCII characters and must not contain '/', '@', double quotes, or spaces."
  }
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance is deployed."
  type        = string
}

variable "database_subnet_ids" {
  description = "List of isolated subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect on port 5432 (typically private subnet CIDRs)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for RDS encryption at rest."
  type        = string
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when destroying the instance."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to all RDS resources."
  type        = map(string)
  default     = {}
}
