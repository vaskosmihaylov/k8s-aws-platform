# 1. Project Shape

Two repositories. Strict separation between **platform/config** and **app source**.

## The split

| Repo | Owns | Pace of change |
|---|---|---|
| `k8s-aws-platform` (this) | Terraform infra, Argo CD bootstrap, platform Helm values, app manifests (Kustomize), CI for infra + manifest validation | Slow, deliberate |
| `k8s-demo-api` (planned, not yet created) | Go REST API source, Dockerfile, app CI that builds image, pushes ECR, updates image tag in this repo | Fast, every commit |

## Why split

Three interview-defensible reasons:

1. **Blast radius.** A bad app commit can't accidentally re-apply Terraform or change platform Helm values.
2. **Permissions.** Developers get `write` on the app repo; only platform owners merge to the config repo.
3. **GitOps integrity.** Argo CD reads only this repo. The app repo *proposes* a one-line image-tag change via PR; Argo CD never reads the app repo directly. This is the GitOps "no push-to-cluster" pattern — clusters pull from config; CI never `kubectl apply`s.

## High-level repo layout

```
k8s-aws-platform/
├── terraform/
│   ├── bootstrap/              # S3 + DynamoDB state backend (local state, prevent_destroy)
│   ├── modules/                # vpc, eks, rds, irsa, kms — thin wrappers
│   └── environments/dev/       # actual stack: module calls + ECR + GH OIDC + Route 53 + ArgoCD
├── argocd/
│   ├── bootstrap/root-app.yaml # App-of-Apps root
│   ├── platform/               # Application CRs per platform component
│   └── apps/                   # Application CRs for demo-api dev + prod
├── platform/                   # Helm values per component (no custom charts)
├── apps/
│   ├── demo-api/               # Kustomize base + dev/prod overlays
│   ├── namespaces/             # dev (PSS baseline) + prod (PSS restricted) + quotas
│   └── priority-classes.yaml
├── docs/                       # this site + drawio + setup guide
├── scripts/                    # load-test.sh, verify-platform.sh
├── .github/workflows/          # terraform-plan, terraform-apply, validate-manifests
└── Makefile
```

See [AWS Setup Guide](../aws-setup-guide.md) for the 15-step bootstrap; you're through Step 14.
