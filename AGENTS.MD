# k8s-aws-platform — agent guide

Shared instructions for Codex and Claude Code. This repository is an EKS/GitOps platform, so correctness means reviewable desired state, explicit target identity, and a safe rollout path—not direct cluster mutation.

## Repository map

- `terraform/bootstrap/` — S3/DynamoDB state bootstrap.
- `terraform/environments/dev/` — AWS VPC, EKS, RDS, KMS, and IRSA composition for `eu-west-1`.
- `terraform/modules/` — reusable Terraform modules.
- `argocd/` — root and platform Argo CD Applications.
- `platform/` — Helm values and Kyverno policies.
- `apps/` — Kustomize bases and dev/prod overlays; `*.enc.yaml` files are SOPS-encrypted.
- `.github/workflows/` — Terraform plan/apply and manifest validation.
- `decisions/` and `docs/` — architectural decisions, operating guidance, and walkthroughs.

## Safety invariants

- Treat every AWS account, kube context, namespace, Terraform backend, and Argo CD target as production-capable until positively identified.
- Desired-state changes flow through Git, Terraform, Helm/Kustomize, and Argo CD. Do not use imperative `kubectl apply`, `helm upgrade`, `argocd app sync`, Terraform apply/destroy/import/state mutation, or equivalent actions without explicit authorization for the exact target.
- The user runs live `kubectl` commands manually. Provide the smallest read-only command and interpret pasted output.
- Never decrypt, print, or replace `apps/**/secret.enc.yaml`; never read kubeconfigs, cloud credentials, Terraform state, plan files containing sensitive values, or local `.env` files.
- `terraform/bootstrap` and `.github/workflows/terraform-apply.yml` have account-wide blast radius. Changes require explicit rollback and recovery reasoning.
- Pushes to `main` touching `terraform/**` run Terraform apply through the production GitHub environment. Treat workflow and branch actions as deployment actions.
- Do not commit, push, open or merge a PR, publish an issue/comment, or change remote state without explicit authorization for that action. Never force-push, bypass hooks, or bulk-stage with `git add .` / `-A`; stage named files only.

## Validation interface

Use `make check` for the non-deploying repository gate. Use narrower commands while editing:

```text
terraform fmt -check -recursive terraform/
pre-commit run --all-files
kustomize build apps/demo-api/base
make docs-build
```

`pre-commit` hooks may rewrite local formatting; inspect `git diff` afterward. Terraform plan requires backend/cloud access: first verify AWS identity, region, working directory, workspace, and backend, then obtain approval before running it. Validation never authorizes apply.

## Workflow routing

- Small infrastructure change: inspect → edit → `infra-change-validation` → `code-review`.
- Platform feature or migration: `grill-with-docs` → `to-spec` → `implement`.
- Multi-part effort: add `to-tickets` after the spec.
- Hard failure or regression: `diagnosing-bugs` with a tight non-mutating feedback loop.
- Use native CLIs and repository files. No MCP server is required for this repository.
- Delegate only independent read-only research or review. Keep implementation under one writing owner.
- Deterministic command gates live in `.claude/settings.json` and `.codex/rules/security.rules`; prose here does not replace them.

Issue-tracker and domain-doc conventions live under `docs/agents/`.

## Ingress admission invariant

The `ingress-nginx-admission` `ValidatingWebhookConfiguration.caBundle` is injected by a PostSync cert-generation Job and guarded by `ignoreDifferences` in `argocd/platform/ingress-nginx.yaml`. Never hand-delete the webhook, its Secret, or its Jobs. Reconcile through the reviewed GitOps path; hand deletion previously caused a multi-hour outage.

## Done criteria

Report `PASS`, `SKIP`, `WARN`, and `FAIL` for applicable checks. A change is ready for review only when rendered output or plans have been inspected, target scope is explicit, policy/security checks pass, secrets remain protected, and rollout observation plus rollback are stated. Do not claim a change is safe to deploy.
