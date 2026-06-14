# Repository Structure -- Confirmed 2026-06-14

Confirmed after reviews by K8s specialist, Terraform engineer, Platform engineer, and Security engineer agents.

## Config Repo: k8s-aws-platform

```
k8s-aws-platform/
├── terraform/
│   ├── bootstrap/              # S3 + DynamoDB (local state, prevent_destroy)
│   ├── modules/
│   │   ├── vpc/                # wraps terraform-aws-modules/vpc
│   │   ├── eks/                # wraps terraform-aws-modules/eks
│   │   ├── rds/                # raw resources
│   │   ├── irsa/               # reusable IRSA role factory
│   │   └── kms/                # KMS key + alias + policy
│   └── environments/
│       └── dev/
│           ├── main.tf         # module calls only
│           ├── locals.tf       # name_prefix, common_tags
│           ├── data.tf         # aws_caller_identity, policy docs
│           ├── variables.tf
│           ├── outputs.tf
│           ├── backend.tf
│           └── terraform.tfvars
├── argocd/
│   ├── bootstrap/              # root app-of-apps (applied once manually)
│   ├── platform/               # Application CRs with sync-waves
│   └── apps/                   # Application CRs for workloads
├── platform/                   # Helm values for platform components
│   ├── ingress-nginx/
│   ├── cert-manager/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── prometheus-adapter/
│   └── kyverno/
├── apps/                       # Kustomize base + overlays
│   ├── demo-api/
│   │   ├── base/               # deployment, service, hpa, networkpolicy, pdb
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   └── namespaces/
│       ├── dev.yaml            # namespace + PSS labels + RBAC + quotas + netpol
│       └── prod.yaml
├── scripts/
│   ├── load-test.sh
│   └── verify-platform.sh
├── decisions/                  # ADRs (Architecture Decision Records)
├── .github/workflows/
│   ├── terraform-plan.yml      # runs on PR, paths: terraform/**
│   ├── terraform-apply.yml     # runs on merge, paths: terraform/**
│   └── validate-manifests.yml  # runs on PR, paths: argocd/**, platform/**, apps/**
├── Makefile
├── .pre-commit-config.yaml
├── .sops.yaml
└── README.md
```

## App Repo: k8s-demo-api

```
k8s-demo-api/
├── cmd/                        # Go main package
├── internal/                   # App logic, handlers, DB
├── Dockerfile                  # Multi-stage, non-root, distroless/scratch
├── .github/workflows/          # Build, test, push ECR, update config repo
└── README.md
```

## Key Design Principles

- ArgoCD orchestration (argocd/) is separated from deployed content (platform/, apps/)
- ArgoCD Application CRs in argocd/ point to their corresponding directories in platform/ or apps/
- Kustomize base+overlays for environment-specific app config
- Helm values files for third-party platform components
- Terraform split into main.tf/locals.tf/data.tf for readability at scale
- ArgoCD installed via Terraform helm_release (chicken-and-egg), everything else via ArgoCD
