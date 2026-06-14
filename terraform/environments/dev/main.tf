module "kms_eks" {
  source = "../../modules/kms"

  alias_name  = "${local.name_prefix}-dev-eks"
  description = "KMS key for EKS envelope encryption of Kubernetes secrets."
  tags        = local.common_tags
}

module "kms_rds" {
  source = "../../modules/kms"

  alias_name  = "${local.name_prefix}-dev-rds"
  description = "KMS key for RDS encryption at rest."
  tags        = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name         = "${local.name_prefix}-dev"
  cluster_name = var.cluster_name
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
  tags         = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                         = var.cluster_name
  vpc_id                               = module.vpc.vpc_id
  subnet_ids                           = module.vpc.private_subnet_ids
  control_plane_subnet_ids             = module.vpc.private_subnet_ids
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  kms_key_arn                          = module.kms_eks.key_arn
  tags                                 = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  identifier          = "${local.name_prefix}-dev-postgres"
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  vpc_id              = module.vpc.vpc_id
  database_subnet_ids = module.vpc.database_subnet_ids
  allowed_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  kms_key_arn         = module.kms_rds.key_arn
  tags                = local.common_tags
}

resource "aws_iam_policy" "cert_manager" {
  name        = "${local.name_prefix}-dev-cert-manager"
  description = "Allows cert-manager to fulfill DNS-01 ACME challenges via Route 53."
  policy      = data.aws_iam_policy_document.cert_manager.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "external_dns" {
  name        = "${local.name_prefix}-dev-external-dns"
  description = "Allows external-dns to manage Route 53 records for Ingress hostnames."
  policy      = data.aws_iam_policy_document.external_dns.json
  tags        = local.common_tags
}

module "irsa_cert_manager" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-cert-manager"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "cert-manager"
  service_account_name = "cert-manager"
  policy_arns          = [aws_iam_policy.cert_manager.arn]
  tags                 = local.common_tags
}

module "irsa_external_dns" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-external-dns"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "external-dns"
  service_account_name = "external-dns"
  policy_arns          = [aws_iam_policy.external_dns.arn]
  tags                 = local.common_tags
}

resource "aws_ecr_repository" "demo_api" {
  name                 = "${local.name_prefix}/demo-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "demo_api" {
  repository = aws_ecr_repository.demo_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 tagged images."
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name_prefix}-dev-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_policy" "github_actions" {
  name        = "${local.name_prefix}-dev-github-actions"
  description = "ECR push and EKS describe access for GitHub Actions CI."
  policy      = data.aws_iam_policy_document.github_actions.json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

resource "aws_route53_zone" "main" {
  name = var.route53_zone_name
  tags = local.common_tags
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.4"
  namespace        = "argocd"
  create_namespace = true

  values = [
    file("${path.module}/../../platform/argocd/values.yaml")
  ]

  depends_on = [module.eks]
}
