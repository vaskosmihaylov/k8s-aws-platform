variable "alias_name" {
  description = "KMS key alias (without the 'alias/' prefix)."
  type        = string
}

variable "description" {
  description = "Description of the KMS key."
  type        = string
}

variable "key_policy" {
  description = "JSON-encoded IAM key policy document. Defaults to account-root full access."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the KMS key and alias."
  type        = map(string)
  default     = {}
}
