# Code Conventions

## Terraform
- Thin module wrappers around community modules (vpc, eks); raw resources where community modules don't fit (rds).
- Environment root split: main.tf (module calls only), locals.tf (name_prefix, common_tags), data.tf (lookups/policy docs), variables.tf, outputs.tf, backend.tf, terraform.tfvars.
- Reusable IRSA helper module for IAM-to-K8s-SA bindings.

## Kubernetes Manifests
- Kustomize base + overlays (dev/prod) for application workloads.
- Helm values files (no custom charts) for third-party platform components.
- Namespace YAML bundles namespace + PSS labels + RBAC + quotas + default-deny network policies.
- ArgoCD Application CRs in argocd/ directory, separated from deployed content in platform/ and apps/.
- Sync-waves for dependency ordering in ArgoCD.

## Secrets
- SOPS encryption with AWS KMS. `.sops.yaml` with `encrypted_regex` targeting data/stringData only.
- KSOPS plugin in ArgoCD repo-server for decryption.

## General
- ADRs in decisions/ directory.
- Mermaid architecture diagram in README.
