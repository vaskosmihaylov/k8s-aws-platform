terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-ACCOUNT_ID"
    key            = "environments/dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "k8s-platform-terraform-locks"
    encrypt        = true
  }
}
