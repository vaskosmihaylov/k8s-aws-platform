locals {
  name_prefix = "k8s-platform"

  common_tags = {
    Project     = "k8s-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
