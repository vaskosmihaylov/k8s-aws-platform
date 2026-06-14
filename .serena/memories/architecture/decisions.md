# Architecture Decisions -- k8s-aws-platform

All decisions grilled and confirmed 2026-06-14. Validated by 4 specialist agents (K8s, Terraform, Platform, Security).

## Purpose
Deep-dive learning project for SciPlay Senior K8s/DevOps Engineer interview. Every decision must be defensible under technical interview pressure.

## Infrastructure

- **Terraform state:** Two-stage bootstrap (local state creates S3+DynamoDB, environments/ uses remote backend). `prevent_destroy` on state bucket, versioning + SSE enabled.
- **Terraform modules:** Thin wrappers around community modules (`terraform-aws-modules/vpc`, `terraform-aws-modules/eks`). Raw resources for RDS. Reusable IRSA helper module.
- **VPC:** 3 AZs, public + private + isolated (database) subnets, single NAT gateway. VPC flow logs enabled.
- **EKS:** Version 1.31 (N-1), with planned upgrade to 1.32 later as a separate exercise.
- **Node groups:** Mixed -- 1x `t3.large` on-demand (platform, tainted `NoSchedule`), 1-2x `t3.medium` spot (apps). Prefix delegation enabled on VPC CNI.
- **CNI:** AWS VPC CNI with `enableNetworkPolicy: true`.
- **EKS API:** Public+private with CIDR whitelisting (home IP only).
- **EKS hardening:** Control plane logging (all 5 types), envelope encryption (KMS), IMDSv2 enforced (hop_limit=1), managed addons (coredns, kube-proxy, vpc-cni) in Terraform.
- **RDS:** PostgreSQL db.t3.micro in isolated subnets, SSL enforced, encryption at rest (KMS), `publicly_accessible=false`.
- **DNS:** k8s.gaiaderma.com -- NS delegation from Hostinger to Route 53. cert-manager DNS-01 validation.
- **Budget:** ~$180/mo, keep running through interview process, `terraform destroy` when done.

## Kubernetes

- **Namespaces:** Single cluster, namespace-isolated (dev + prod).
- **PSS:** `enforce: restricted` on prod, `enforce: baseline` + `warn: restricted` on dev.
- **RBAC:** Role-per-team (platform-admin, developer scoped to dev, viewer read-only in prod). `automountServiceAccountToken: false` on default SA.
- **Network Policies:** Default-deny ingress+egress per namespace, explicit allows for DNS, ingress-nginx, Prometheus scraping, app->RDS, ArgoCD, Loki.
- **LimitRange + ResourceQuota** per namespace.
- **PDBs** on all multi-replica deployments.
- **Topology spread constraints** across AZs.
- **Priority Classes:** `platform-critical` + `app-default`.
- **Graceful shutdown:** `terminationGracePeriodSeconds` + preStop hooks.

## Platform Components

- **Ingress:** ingress-nginx + cert-manager + Let's Encrypt (DNS-01 via Route 53).
- **GitOps:** ArgoCD with app-of-apps pattern. Installed via Terraform `helm_release`. Sync-waves for dependency ordering.
- **Observability:** kube-prometheus-stack + Grafana Loki + custom dashboards + Prometheus Adapter for HPA custom metrics.
- **Secrets:** SOPS + AWS KMS (KSOPS plugin in ArgoCD repo-server). `.sops.yaml` with `encrypted_regex` for data/stringData only.
- **Policy:** Kyverno with 3 policies (disallow latest tag, require resource limits, require probes).
- **HPA:** autoscaling/v2 with CPU/memory + custom `http_requests_per_second` metric via Prometheus Adapter. No cluster autoscaler.

## CI/CD

- **Separate repos:** `k8s-aws-platform` (config/platform) + `k8s-demo-api` (Go app).
- **GitHub Actions:** 3 workflows in config repo (terraform-plan on PR, terraform-apply on merge, validate-manifests). App repo CI builds image, pushes to ECR, updates image tag in config repo via kustomize edit.
- **AWS auth:** GitHub OIDC federation (no long-lived access keys).
- **ECR:** scan_on_push, lifecycle policy (keep last 10 images).

## Demo App

- Go REST API + RDS PostgreSQL.
- Endpoints: /healthz, /readyz, /metrics (Prometheus), /api/v1/items (CRUD).
- Structured JSON logging (Loki-parseable).
- Multi-stage Dockerfile, non-root user, distroless/scratch base.
- All three probe types (liveness, readiness, startup).

## Developer Experience

- Makefile (bootstrap, plan, apply, validate, port-forward, teardown).
- Pre-commit hooks (terraform fmt, kubeconform, detect-secrets, yamllint).
- ADR (Architecture Decision Records) directory.
- Load test script (k6/hey) for HPA demo.
- Mermaid architecture diagram in README.
