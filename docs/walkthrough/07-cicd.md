# 7. CI/CD

Three GitHub Actions workflows in this repo, three OIDC sub forms, one shared IAM role.

## Flow

```mermaid
flowchart LR
    subgraph "config repo: k8s-aws-platform"
        pr1[PR opened]
        merge1[merge to main]
    end
    subgraph "app repo: k8s-demo-api (planned)"
        commit[commit to main]
    end

    pr1 -->|terraform-plan.yml<br/>OIDC: pull_request sub| ghap1[GH Actions]
    ghap1 -->|terraform plan| aws1[AWS]
    aws1 -->|posts plan| pr1

    pr1 -->|validate-manifests.yml| ghap2[yamllint + kubeconform]

    merge1 -->|terraform-apply.yml<br/>OIDC: environment:production sub| ghap3[GH Actions]
    ghap3 -->|terraform apply| aws2[AWS]

    commit -->|build + ECR push<br/>OIDC: ref:refs/heads/main sub| ghap4[GH Actions]
    ghap4 -->|ECR| ecr[(ECR scan_on_push)]
    ghap4 -->|kustomize edit set image<br/>+ git push| pr1

    classDef oidc fill:#9f9,stroke:#360,color:#000
    class ghap1,ghap3,ghap4 oidc
```

## Workflows (in this repo)

### `terraform-plan.yml`

- **Trigger**: PR
- **OIDC sub**: `repo:<org>/k8s-aws-platform:pull_request`
- **What**: `terraform init && terraform plan`, posts plan as PR comment

### `terraform-apply.yml`

- **Trigger**: push to `main`
- **OIDC sub**: `repo:<org>/k8s-aws-platform:environment:production` (declares `environment: production`)
- **What**: `terraform init && terraform apply`

### `validate-manifests.yml`

- **Trigger**: PR
- **What**: `yamllint` + `kubeconform` against all manifests in `argocd/`, `platform/`, `apps/`
- No AWS access needed — no OIDC

## App repo flow (planned)

When `k8s-demo-api` lands:

1. App commit triggers build
2. Multi-stage Dockerfile produces distroless, non-root image
3. Image pushed to ECR (scan-on-push, lifecycle keeps last 10)
4. Workflow opens PR against this repo: `cd apps/demo-api/overlays/dev && kustomize edit set image demo-api=<ECR_URL>:<TAG>`
5. PR merge triggers Argo CD sync → pods roll

## Single OIDC role, multiple sub forms

One GitHub Environment (`production`). `AWS_ROLE_ARN` is a **repo-level GitHub variable** (not a secret — ARNs aren't sensitive).

The IAM role's trust policy accepts:

```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:<org>/k8s-aws-platform:environment:production",
      "repo:<org>/k8s-aws-platform:pull_request",
      "repo:<org>/k8s-demo-api:ref:refs/heads/main"
    ]
  }
}
```

!!! note "Interview elegance"
    Three workflows, three sub forms, one shared role — no long-lived AWS keys anywhere. The trust relationship is what limits blast radius.
