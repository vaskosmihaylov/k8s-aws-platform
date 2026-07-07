locals {
  name_prefix = "k8s-platform"

  terraform_state_bucket = "k8s-platform-terraform-state-649822034735"
  terraform_state_key    = "environments/dev/terraform.tfstate"

  common_tags = {
    Project     = "k8s-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
