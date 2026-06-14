# 1. Project Bootstrap and Infrastructure Decisions

Date: 2026-06-14

## Status

Accepted

## Context

Building an AWS EKS showcase project to demonstrate cloud-native Kubernetes platform engineering skills. The project needs to cover infrastructure provisioning, GitOps, observability, security hardening, and CI/CD — all defensible under technical interview pressure.

## Decision

- **IaC**: Terraform with community modules for VPC and EKS (proven, well-maintained), raw resources for RDS (more control over security config).
- **State management**: Two-stage bootstrap — local state creates S3+DynamoDB backend, then environments use remote backend.
- **GitOps**: ArgoCD with app-of-apps pattern. ArgoCD itself installed via Terraform helm_release (chicken-and-egg), everything else managed by ArgoCD.
- **Manifests**: Kustomize base+overlays for application workloads. Helm values files (no custom charts) for third-party platform components.
- **Secrets**: SOPS with AWS KMS, KSOPS plugin in ArgoCD repo-server.
- **CI/CD**: GitHub Actions with OIDC federation to AWS (no long-lived credentials).

## Consequences

- Bootstrap must be run before any environment can be provisioned.
- ArgoCD Application CRs must use sync-waves to handle dependency ordering.
- Two separate repos: config (this) and app (k8s-demo-api) to demonstrate proper GitOps separation.
- Budget ~$180/mo while running; `terraform destroy` when interview process completes.
