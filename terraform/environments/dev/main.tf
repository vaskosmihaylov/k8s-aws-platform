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

# Alias name must exactly match the `kms:` field in .sops.yaml at the repo root.
module "kms_sops" {
  source = "../../modules/kms"

  alias_name  = "k8s-platform-sops"
  description = "KMS key for SOPS-encrypted secrets, decrypted by Argo CD's KSOPS repo-server plugin."
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
  policy_arns = {
    cert_manager = aws_iam_policy.cert_manager.arn
  }
  tags = local.common_tags
}

module "irsa_external_dns" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-external-dns"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "external-dns"
  service_account_name = "external-dns"
  policy_arns = {
    external_dns = aws_iam_policy.external_dns.arn
  }
  tags = local.common_tags
}

module "irsa_ebs_csi" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-ebs-csi"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "kube-system"
  service_account_name = "ebs-csi-controller-sa"
  policy_arns = {
    ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
  tags = local.common_tags
}

resource "aws_iam_policy" "argocd_repo_server_kms" {
  name        = "${local.name_prefix}-dev-argocd-repo-server-kms"
  description = "Allows Argo CD's repo-server to decrypt SOPS-encrypted secrets via KSOPS."
  policy      = data.aws_iam_policy_document.argocd_repo_server_kms.json
  tags        = local.common_tags
}

module "irsa_argocd_repo_server" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-argocd-repo-server"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "argocd"
  service_account_name = "argocd-repo-server"
  policy_arns = {
    kms_decrypt = aws_iam_policy.argocd_repo_server_kms.arn
  }
  tags = local.common_tags
}

# AWS infra (IAM policy + IRSA role) for the AWS Load Balancer Controller lives here;
# the controller's Helm chart is deployed via Argo CD (argocd/platform/aws-load-balancer-controller.yaml),
# matching the cert-manager/external-dns split. The policy JSON is vendored verbatim from upstream
# (kubernetes-sigs/aws-load-balancer-controller v3.4.0 docs/install/iam_policy.json) — re-pull it from
# the matching git tag when bumping the chart version.
resource "aws_iam_policy" "aws_lb_controller" {
  name        = "${local.name_prefix}-dev-aws-lb-controller"
  description = "Permissions for the AWS Load Balancer Controller to manage ELBv2 resources."
  policy      = file("${path.module}/policies/aws-lb-controller-iam-policy.json")
  tags        = local.common_tags
}

module "irsa_aws_lb_controller" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-aws-lb-controller"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
  policy_arns = {
    aws_lb_controller = aws_iam_policy.aws_lb_controller.arn
  }
  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.irsa_ebs_csi.role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.common_tags
}

# EKS 1.31 ships with no CSI driver and no default StorageClass, so PVCs hang
# forever without one. This was originally created by a manual `kubectl apply`
# post-bootstrap; now managed here (imported, not recreated).
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
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

resource "aws_iam_role" "terraform_github_actions" {
  name               = "${local.name_prefix}-dev-terraform-github-actions"
  assume_role_policy = data.aws_iam_policy_document.terraform_github_actions_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "terraform_github_actions_admin" {
  role       = aws_iam_role.terraform_github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_eks_access_entry" "terraform_github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.terraform_github_actions.arn
  type          = "STANDARD"
  tags          = local.common_tags
}

resource "aws_eks_access_policy_association" "terraform_github_actions_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.terraform_github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_github_actions]
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

  # The umbrella chart rolls many components; the default 300s wait is tight on this 2-node
  # cluster and has expired ("context deadline exceeded") during past upgrades. The real fix is
  # platform placement for every component (see platform/argocd/values.yaml), but give the rollout
  # headroom too.
  timeout = 600

  values = [
    file("${path.module}/../../../platform/argocd/values.yaml")
  ]

  # IRSA role ARN is only known after the module above runs, so it's injected
  # here rather than hardcoded into the static values.yaml file.
  set {
    name  = "repoServer.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_argocd_repo_server.role_arn
  }

  depends_on = [module.eks]
}
