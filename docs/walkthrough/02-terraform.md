# 2. Terraform Foundation

The AWS layer is built with Terraform in two stages: state backend first (local), then the actual stack (remote).

## Two-stage state — the chicken-and-egg fix

```
terraform/bootstrap/        ┐
                            │  LOCAL state. Creates S3 bucket + DynamoDB table.
                            │  prevent_destroy on the bucket so you can't
                            │  accidentally terraform-destroy your own state.
                            ┘

terraform/environments/dev/ ┐
                            │  REMOTE state in that S3 bucket.
                            │  backend "s3" { use_lockfile = true }
                            │  (S3-native lock; dynamodb_table is deprecated.)
                            ┘
```

!!! question "Interview probe"
    "How do you bootstrap state when state itself lives in the thing you're bootstrapping?"
    → This exact pattern. Local state for one-time backend creation, then migrate.

## Modules — thin wrappers

### VPC (`terraform/modules/vpc/`)

Wraps `terraform-aws-modules/vpc ~5.8`.

- 3 Availability Zones
- Public + private + isolated DB subnets
- **Single NAT gateway** — cost trade-off; multi-NAT is the HA answer if asked
- VPC flow logs to CloudWatch

### KMS (`terraform/modules/kms/`)

Separate keys per concern (EKS envelope encryption, RDS at-rest).

Reality is **3 keys** because the EKS community module also creates its own internal key.
Easy fix: set `create_kms_key = false` in the EKS wrapper — listed as a follow-up.

### RDS (`terraform/modules/rds/`)

**Raw resources** — not a community wrapper. RDS knobs are too opinionated to abstract well.

- PostgreSQL 16, `db.t3.micro`
- `publicly_accessible = false`, isolated subnets
- `force_ssl` parameter group enforces TLS at the engine level
- Encryption at rest with the RDS KMS key

### IRSA (`terraform/modules/irsa/`) {#irsa}

The IAM-for-pods primitive used by cert-manager, external-dns, EBS CSI, Kyverno cleanup, and others.

The module is a **factory**: caller passes a namespace + SA name + IAM policy document; the module mints an IAM role with the correct trust policy bound to the EKS OIDC provider.

```hcl
module "irsa_cert_manager" {
  source = "../../modules/irsa"

  role_name        = "${local.name_prefix}-cert-manager"
  cluster_oidc_arn = module.eks.oidc_provider_arn
  namespace        = "cert-manager"
  service_account  = "cert-manager"
  policy_json      = data.aws_iam_policy_document.cert_manager.json
}
```

The annotation on the ServiceAccount inside the cluster is what wires the two together:

```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::649822034735:role/k8s-platform-dev-cert-manager
```

**This is the AWS pattern that has no clean on-prem equivalent** — see [On-Prem Comparison](../operating/onprem-comparison.md).

### KSOPS: a KMS key + IRSA for the ArgoCD repo-server itself (2026-06-22)

Same factory, new caller — `module "irsa_argocd_repo_server"` grants `kms:Decrypt`/`kms:DescribeKey`
on a dedicated `module "kms_sops"` key (alias `k8s-platform-sops`, the same one referenced in
`.sops.yaml`'s `creation_rules`). Unlike the other IRSA roles above, this one is for a **platform
control-plane component**, not an app — it's how Argo CD's own repo-server decrypts SOPS-encrypted
Secret manifests via the KSOPS kustomize exec plugin before generating the final manifest. See
[App Layer → Secrets](06-app.md#secrets) for the end-to-end flow.

### `gp3` default StorageClass — now in Terraform, not a manual step

`kubernetes_storage_class_v1.gp3` in `terraform/environments/dev/main.tf` (the `hashicorp/kubernetes`
provider, already configured for `helm_release.argocd`). Originally created by hand post-bootstrap;
imported (`terraform import kubernetes_storage_class_v1.gp3 gp3`) then brought under management —
`terraform plan` now shows no drift for it.

## Route 53 — the apex-vs-subdomain story

The original plan was to delegate the `k8s.gaiaderma.com` *subdomain* and leave the rest on Hostinger.

**Hostinger does not expose per-subdomain NS delegation** for this domain, so the entire apex `gaiaderma.com` was delegated to AWS via Hostinger custom nameservers.

- cert-manager and external-dns scope to `aws_route53_zone.main.zone_id` (read from Terraform output)
- Chart values still use `*.k8s.gaiaderma.com` hostnames — those are records inside the apex zone
- The IRSA scope on external-dns can be narrowed by ARN if you want least-privilege

!!! note "Interview takeaway"
    This is the *correct* call. You explain the registrar constraint forced apex delegation, and you note that IRSA policy scope can still be narrowed.

## GitHub OIDC — no long-lived AWS keys

A single IAM role assumed by GitHub Actions via OpenID Connect. The trust policy in `terraform/environments/dev/data.tf` accepts three `sub` forms:

| Sub | Used by |
|---|---|
| `repo:<org>/k8s-aws-platform:environment:production` | `terraform-apply.yml` (push to main, declares `environment: production`) |
| `repo:<org>/k8s-aws-platform:pull_request` | `terraform-plan.yml` (PR builds) |
| `repo:<org>/k8s-demo-api:ref:refs/heads/main` | App repo CI when it lands |

`AWS_ROLE_ARN` is a **repo-level GitHub variable** (not a secret — ARNs aren't sensitive), so both workflows see it without per-environment duplication. Only one GitHub Environment exists (`production`).

See [CI/CD](07-cicd.md) for the workflow detail.
