output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl for the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance."
  value       = module.rds.endpoint
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the demo-api image."
  value       = aws_ecr_repository.demo_api.repository_url
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID for the platform domain."
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Name servers for the Route 53 hosted zone. Delegate from registrar to these."
  value       = aws_route53_zone.main.name_servers
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "cert_manager_role_arn" {
  description = "ARN of the IRSA role for cert-manager."
  value       = module.irsa_cert_manager.role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the IRSA role for external-dns."
  value       = module.irsa_external_dns.role_arn
}

output "aws_lb_controller_role_arn" {
  description = "ARN of the IRSA role for the AWS Load Balancer Controller."
  value       = module.irsa_aws_lb_controller.role_arn
}
