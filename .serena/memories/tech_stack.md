# Tech Stack

## Infrastructure
- **IaC:** Terraform (community modules for VPC/EKS, raw resources for RDS)
- **State:** S3 + DynamoDB backend (two-stage bootstrap)
- **Cloud:** AWS — VPC, EKS 1.31, RDS PostgreSQL, KMS, Route 53, ECR
- **DNS:** k8s.gaiaderma.com (NS delegation from Hostinger to Route 53)

## Kubernetes Platform
- **Cluster:** EKS 1.31, mixed node groups (on-demand t3.large + spot t3.medium)
- **CNI:** AWS VPC CNI with network policy support
- **Ingress:** ingress-nginx + cert-manager (Let's Encrypt DNS-01)
- **GitOps:** ArgoCD (app-of-apps, installed via Terraform helm_release)
- **Observability:** kube-prometheus-stack, Grafana Loki, Prometheus Adapter
- **Secrets:** SOPS + AWS KMS (KSOPS plugin in ArgoCD)
- **Policy:** Kyverno (3 policies)
- **Manifests:** Kustomize (base + overlays for dev/prod), Helm values for platform components

## Application
- **Language:** Go
- **Database:** PostgreSQL (RDS db.t3.micro)
- **Container:** Multi-stage Dockerfile, distroless/scratch, non-root

## CI/CD
- **Pipelines:** GitHub Actions (3 workflows: terraform-plan, terraform-apply, validate-manifests)
- **Auth:** GitHub OIDC federation to AWS (no long-lived keys)
- **Registry:** ECR with scan_on_push, lifecycle policy

## Local Tooling
- Pre-commit hooks (terraform fmt, kubeconform, detect-secrets, yamllint)
- Makefile for common operations
- k6/hey for load testing
