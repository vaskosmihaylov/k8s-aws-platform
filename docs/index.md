# k8s-aws-platform

AWS EKS showcase platform. Fully bootstrapped, GitOps-managed, observable, and policy-enforced.

!!! success "Platform state (2026-06-22)"
    All Argo CD Applications Synced/Healthy, including `loki` (fixed — see [Platform Layer](walkthrough/05-platform.md#loki)). `make verify` reports all checks passing.

    Handoff punch-list closed out this session: kyverno cleanup CronJob image fix, `gp3`
    StorageClass moved into Terraform, demo-api built end-to-end and wired with a SOPS+KSOPS
    DB secret, ConfigMap, PodMonitor, custom HPA metric, and ClusterIssuer/Ingress. See
    [App Layer](walkthrough/06-app.md) and [Platform Layer](walkthrough/05-platform.md).

## What this platform is

A **production-shaped 12-factor web service stack on AWS EKS**:

- **Frontend**: ingress-nginx behind an AWS NLB, TLS from Let's Encrypt (DNS-01 via Route 53)
- **App**: Go REST API (`apps/demo-api/`) — `/healthz`, `/readyz`, `/metrics`, `/api/v1/items`
- **State**: RDS PostgreSQL 16, SSL-only, isolated subnets
- **Ops**: Argo CD GitOps, kube-prometheus-stack + Loki + Grafana (all Synced/Healthy), HPA on CPU + custom `http_requests_per_second`
- **Policy**: Kyverno 3 ClusterPolicies, Pod Security Standards (`baseline` dev / `restricted` prod), default-deny NetworkPolicies
- **Secrets**: SOPS + AWS KMS via KSOPS plugin in Argo CD repo-server
- **CI/CD**: GitHub Actions via OIDC federation — no long-lived AWS keys

## Reading order

| If you want… | Start here |
|---|---|
| The 30-second pitch | This page |
| The full architecture picture | [Architecture](architecture.md) |
| To trace one layer at a time | [1. Project Shape](walkthrough/01-project-shape.md) → … → [8. Security Story](walkthrough/08-security.md) |
| To understand what's harder without EKS | [On-Prem Comparison](operating/onprem-comparison.md) |
| To click around the running cluster | [Browser Access](operating/browser.md) |
| To know how you'd debug a node without SSH | [Node Troubleshooting](operating/troubleshooting.md) |
| To rebuild from scratch | [AWS Setup Guide](aws-setup-guide.md) |

## Master diagram (request path)

```mermaid
flowchart LR
    user([Browser /<br/>API client])
    dns[(Route 53<br/>apex: gaiaderma.com)]
    extdns[external-dns<br/>IRSA]
    cm[cert-manager<br/>IRSA]
    le[(Let's Encrypt<br/>ACME DNS-01)]
    nlb{{AWS NLB}}
    ingress[ingress-nginx<br/>on platform nodes]
    svc[Service<br/>ClusterIP]
    pods[demo-api Pods<br/>spread across AZs<br/>+ HPA scales]
    rds[(RDS Postgres 16)]
    ebs[(EBS gp3 via CSI)]

    user -->|DNS lookup| dns
    user -->|TLS 443| nlb
    nlb --> ingress
    ingress --> svc
    svc --> pods
    pods --> rds
    pods -.uses.-> ebs

    extdns -.creates A records.-> dns
    cm -.DNS-01 challenge.-> dns
    cm -.requests cert.-> le
    cm -.injects TLS Secret.-> ingress
```

For the layered view with VPC subnets, KMS, ECR, etc., see [Architecture](architecture.md).

## Live cluster facts

Verified via the read-only kubernetes-mcp-server against the live cluster on 2026-06-15:

| Resource | State |
|---|---|
| Nodes | 2 Ready: `t3.large` ON_DEMAND (platform), `t3.medium` SPOT (apps), both in `eu-west-1a` |
| Argo CD Applications | 9 total — 7 Synced/Healthy, `kube-prometheus-stack` + `ingress-nginx` Progressing (pods Running), `loki` Synced/Healthy (fixed) |
| StorageClass | `gp3 (default)` via `ebs.csi.aws.com`, **managed in Terraform** (`kubernetes_storage_class_v1.gp3`, imported); legacy `gp2` retained |
| cert-manager IRSA | SA annotated with `arn:aws:iam::649822034735:role/k8s-platform-dev-cert-manager` |
| Custom metrics API | `v1beta1.custom.metrics.k8s.io` Available, backed by `monitoring/prometheus-adapter` |
| Default-deny NetworkPolicy | Live in `dev` namespace |

## Running this site locally

```bash
pip install mkdocs-material pymdown-extensions
make docs-serve     # http://localhost:8000
make docs-build     # static site -> site/
```
