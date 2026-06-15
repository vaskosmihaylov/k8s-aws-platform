terraform {
  backend "s3" {
    bucket       = "k8s-platform-terraform-state-649822034735"
    key          = "environments/dev/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
