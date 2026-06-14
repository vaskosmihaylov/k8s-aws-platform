# Task Completion Checks

Run these before considering a coding task done. Adapt as project files are created.

## Terraform changes
1. `terraform fmt -check -recursive` — formatting
2. `terraform validate` — syntax/config validation
3. `terraform plan` — no unexpected changes
4. `pre-commit run terraform-fmt --all-files` — hook passes

## Kubernetes manifest changes
1. `kubeconform -strict -kubernetes-version 1.31.0 <files>` — schema validation
2. `yamllint <files>` — YAML lint
3. `pre-commit run --all-files` — all hooks pass

## General
1. `pre-commit run --all-files` — always run before considering done
2. Verify no secrets in staged files (detect-secrets hook)
3. For ArgoCD Application CRs: confirm `spec.source.path` matches actual directory
