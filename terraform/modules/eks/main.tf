module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.14"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }
  kms_key_administrators = var.kms_key_administrators

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  eks_managed_node_groups = {
    platform = {
      name           = "platform"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 1
      desired_size = 1

      labels = {
        node-role = "platform"
      }

      taints = [
        {
          key    = "node-role"
          value  = "platform"
          effect = "NO_SCHEDULE"
        }
      ]

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }

    apps = {
      name           = "apps"
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 2
      desired_size = 2

      labels = {
        node-role = "apps"
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }

  # Keep access entries explicit so local and CI plans do not alternate the
  # cluster_creator principal based on the caller identity running Terraform.
  enable_cluster_creator_admin_permissions = false
  access_entries                           = var.access_entries

  tags = var.tags
}
