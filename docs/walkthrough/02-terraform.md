# 2. Terraform Foundation

The AWS layer is built with Terraform in two stages: state backend first (local), then the actual stack (remote).

## Two-stage state — the chicken-and-egg fix

```
terraform/bootstrap/        ┐
                            │  LOCAL state. Creates S3 bucket, bucket versioning,
                            │  encryption, public-access block, and a legacy
                            │  DynamoDB lock table. The bucket has prevent_destroy
                            │  so you can't
                            │  accidentally terraform-destroy your own state.
                            ┘

terraform/environments/dev/ ┐
                            │  REMOTE state in that S3 bucket.
                            │  backend "s3" { use_lockfile = true }
                            │  S3-native lock files are the active lock mechanism.
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

Separate keys per concern:

- `alias/k8s-platform-dev-eks` — passed to the EKS module for Kubernetes Secret envelope encryption.
- `alias/k8s-platform-dev-rds` — RDS encryption at rest.
- `alias/k8s-platform-sops` — SOPS/KSOPS decryption by the Argo CD repo-server.

The upstream EKS module also creates an internal KMS key for its own cluster encryption policy path.
That key's administrators are explicit now: the human admin user plus the Terraform GitHub Actions
role. This avoids the caller-dependent drift where a local plan and a CI plan alternated the key
administrator based on who ran Terraform.

### RDS (`terraform/modules/rds/`)

**Raw resources** — not a community wrapper. RDS knobs are too opinionated to abstract well.

- PostgreSQL 16, `db.t3.micro`
- `publicly_accessible = false`, isolated subnets
- `force_ssl` parameter group enforces TLS at the engine level
- Encryption at rest with the RDS KMS key

### IRSA (`terraform/modules/irsa/`) {#irsa}

The IAM-for-pods primitive used by cert-manager, external-dns, EBS CSI, AWS Load Balancer Controller,
and Argo CD repo-server.

The module is a **factory**: caller passes a namespace + SA name + IAM policy document; the module mints an IAM role with the correct trust policy bound to the EKS OIDC provider.

```hcl
module "irsa_cert_manager" {
  source = "../../modules/irsa"

  role_name            = "${local.name_prefix}-dev-cert-manager"
  oidc_provider_url    = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn    = module.eks.oidc_provider_arn
  namespace            = "cert-manager"
  service_account_name = "cert-manager"
  policy_arns = {
    cert_manager = aws_iam_policy.cert_manager.arn
  }
}
```

The annotation on the ServiceAccount inside the cluster is what wires the two together:

```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::649822034735:role/k8s-platform-dev-cert-manager
```

**This is the AWS pattern that has no clean on-prem equivalent** — see [On-Prem Comparison](../operating/onprem-comparison.md).

### KSOPS: a KMS key + IRSA for the Argo CD repo-server itself

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

Two IAM roles are assumed by GitHub Actions via OpenID Connect:

| Role | Used by | Scope |
|---|---|---|
| `k8s-platform-dev-github-actions` | app repo image build/push and config-repo PR plan | ECR push, S3 state object access, EKS describe |
| `k8s-platform-dev-terraform-github-actions` | protected `terraform-apply.yml` | Terraform admin role plus EKS access entry / cluster-admin policy |

The trust policies in `terraform/environments/dev/data.tf` intentionally differ. The Terraform role
accepts only the protected production environment subject; the app/ECR role accepts the app repo main
branch plus narrower config-repo subjects:

| Sub | Used by |
|---|---|
| `repo:<org>/k8s-aws-platform:environment:production` | Terraform Apply production environment |
| `repo:<org>/k8s-aws-platform:pull_request` | Config-repo PR plan / validation role |
| `repo:<org>/k8s-demo-api:ref:refs/heads/main` | App repo CI image build/push |

`TERRAFORM_AWS_ROLE_ARN` is the repo variable used by Terraform Apply. `AWS_ROLE_ARN` remains for
the narrower app/ECR role and the PR plan workflow. ARNs are not secrets; the security boundary is
the OIDC trust condition plus the IAM policy.

### Terraform caller identity drift

The upstream EKS module's `enable_cluster_creator_admin_permissions = true` creates a
`cluster_creator` access entry for **the identity currently running Terraform**. That was fine while
all plans ran locally, but once GitHub Actions ran the plan, Terraform wanted to replace the human
admin access entry with the CI role.

The fix is to make access entries explicit in the wrapper:

- `enable_cluster_creator_admin_permissions = false`
- `access_entries.cluster_creator.principal_arn = arn:aws:iam::649822034735:user/vasko-k8s-platform-admin`
- a separate `aws_eks_access_entry.terraform_github_actions` grants the CI role cluster-admin

This keeps local and CI plans stable.

### CI reachability boundary

GitHub-hosted runners can assume AWS roles, but standard runners cannot reach the Kubernetes API
because the public EKS endpoint is allowlisted to a single operator `/32`. Do not widen the endpoint
to all GitHub Actions IP ranges. Use local apply, a self-hosted runner inside the VPC/network path,
or a GitHub larger runner with static IP ranges.

The current PR plan workflow remains intentionally lower-privilege. If you want reliable remote
plans, add a dedicated read-only Terraform plan role and run it from a network path that can reach
the EKS API.

See [CI/CD](07-cicd.md) for the workflow detail.

## Upstream docs to read

- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) — `use_lockfile = true`, state storage, and locking.
- [terraform-aws-modules/eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) — module inputs such as access entries, node groups, and KMS settings.
- [Amazon EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) — how Kubernetes ServiceAccounts assume IAM roles.
- [GitHub OIDC with AWS](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) — short-lived CI credentials without static AWS keys.
