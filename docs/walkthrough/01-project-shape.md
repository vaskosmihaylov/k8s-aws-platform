# 1. Project Shape

Two repositories. Strict separation between **platform/config** and **app source**.

## The split

| Repo | Owns | Pace of change |
|---|---|---|
| `k8s-aws-platform` (this) | Terraform infra, Argo CD bootstrap, platform Helm values, app manifests (Kustomize), CI for infra + manifest validation | Slow, deliberate |
| `k8s-demo-api` (separate private repo) | Go REST API source, Dockerfile, app CI that builds and tests the app, then pushes image tags to ECR | Fast, every commit |

## Why split

Three interview-defensible reasons:

1. **Blast radius.** A bad app commit can't accidentally re-apply Terraform or change platform Helm values.
2. **Permissions.** Developers get `write` on the app repo; only platform owners merge to the config repo.
3. **GitOps integrity.** Argo CD reads only this repo. The app repo *proposes* a one-line image-tag change via PR; Argo CD never reads the app repo directly. This is the GitOps "no push-to-cluster" pattern — clusters pull from config; CI never `kubectl apply`s.

## High-level repo layout

```
k8s-aws-platform/
├── terraform/
│   ├── bootstrap/              # S3 state bucket (local state, prevent_destroy); legacy DynamoDB lock table still exists
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

See [AWS Setup Guide](../aws-setup-guide.md) for the bootstrap sequence. The current live environment
has completed the platform, app, DNS, TLS, observability, and policy layers.

## Why the app repo is separate work

The platform is complete without editing `k8s-demo-api` in this repo. The app repo is a separate
artifact with its own tests, Dockerfile, and build workflow. Treat future app changes as normal
application delivery:

1. Change and test Go code in `k8s-demo-api`.
2. Build and push a new immutable image tag to ECR.
3. Update this repo's Kustomize image tag through a PR.
4. Let Argo CD pull the new config and roll the deployment.
