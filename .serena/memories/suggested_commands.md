# Suggested Commands

Project is pre-implementation. Commands below are planned; update as files are created.

## Terraform (from terraform/environments/dev/)
- `terraform init` — initialize providers and backend
- `terraform plan -out=tfplan` — preview changes
- `terraform apply tfplan` — apply saved plan
- `terraform destroy` — tear down (budget: ~$180/mo, destroy when done)

## Bootstrap (from terraform/bootstrap/)
- `terraform init && terraform apply` — one-time S3+DynamoDB state backend setup (local state)

## Kubernetes
- `kubectl apply -k apps/demo-api/overlays/dev/` — deploy app (dev)
- `kubectl apply -f argocd/bootstrap/` — one-time ArgoCD app-of-apps bootstrap

## Validation
- `pre-commit run --all-files` — run all pre-commit hooks
- `kubeconform -strict -kubernetes-version 1.31.0` — validate K8s manifests

## Makefile (planned targets)
- `make bootstrap` — Terraform state backend
- `make plan` / `make apply` — Terraform plan/apply
- `make validate` — run manifest validation
- `make port-forward` — port-forward common services
- `make teardown` — destroy everything

## Load Testing
- `scripts/load-test.sh` — trigger HPA scaling demo (k6 or hey)

## Darwin-specific
- `brew install terraform kubectl helm argocd sops pre-commit kubeconform` — install tooling
