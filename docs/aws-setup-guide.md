# AWS Account Setup Guide

Step-by-step instructions to find and configure all placeholder values in this project.

## Prerequisites

- AWS CLI v2 installed (`brew install awscli`)
- An AWS account with admin access
- `jq` installed (`brew install jq`)
- Terraform >= 1.7 installed (`brew install terraform`)
- kubectl installed (`brew install kubectl`)
- helm installed (`brew install helm`)
- pre-commit installed (`brew install pre-commit`)
- hey installed for load testing (`brew install hey`)
- sops installed (`brew install sops`)

## Step 1: Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: eu-west-1
# Default output format: json
```

Verify access:

```bash
aws sts get-caller-identity
```

Note the `Account` field — this is your **ACCOUNT_ID** used throughout the project.

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: ${ACCOUNT_ID}"
```

## Step 2: Replace ACCOUNT_ID Placeholders

The following files contain `ACCOUNT_ID` placeholders that must be replaced with your actual AWS account ID:

| File | What to replace |
|------|----------------|
| `terraform/environments/dev/backend.tf` | S3 bucket name suffix |
| `apps/demo-api/base/deployment.yaml` | ECR image URI |
| `apps/demo-api/base/serviceaccount.yaml` | IRSA role ARN |
| `apps/demo-api/overlays/dev/kustomization.yaml` | ECR image name |
| `apps/demo-api/overlays/prod/kustomization.yaml` | ECR image name |
| `platform/cert-manager/values.yaml` | IRSA role ARN |
| `.sops.yaml` | KMS key alias ARN |

Run this to replace all at once:

```bash
# From the project root
find . -type f \( -name '*.yaml' -o -name '*.tf' -o -name '*.yml' \) \
  -not -path './.git/*' \
  -exec sed -i '' "s/ACCOUNT_ID/${ACCOUNT_ID}/g" {} +

echo "Replaced ACCOUNT_ID in all files."
```

Verify:

```bash
grep -r 'ACCOUNT_ID' --include='*.yaml' --include='*.tf' --include='*.yml' .
# Should return no results
```

## Step 3: Set Your Home IP for EKS API Whitelisting

The EKS API server is public but restricted to your IP. Find your current public IP:

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your public IP: ${MY_IP}"
```

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
cluster_endpoint_public_access_cidrs = ["<YOUR_IP>/32"]
```

Replace `<YOUR_IP>` with the output above. Example: `["93.123.45.67/32"]`.

> **Note:** If your ISP assigns dynamic IPs, you'll need to update this value when your IP changes.

## Step 4: Set the Database Password

Never commit the password to version control. Use an environment variable:

```bash
# Generate a strong password
export TF_VAR_db_password=$(openssl rand -hex 24)
echo "Save this password securely: ${TF_VAR_db_password}"
```

Remove the placeholder from `terraform/environments/dev/terraform.tfvars`:

```hcl
# Delete or comment out this line:
# db_password = "REPLACE_ME"
```

Terraform will read `TF_VAR_db_password` from your environment automatically.

> **Important:** Save this password somewhere secure (e.g., 1Password, macOS Keychain). You'll need it to construct the DATABASE_URL Kubernetes secret later.

## Step 5: Set Your GitHub Username

Edit `terraform/environments/dev/terraform.tfvars` and confirm the `github_org` value:

```hcl
github_org = "vaskosmihaylov"
```

This must match the GitHub account/org that owns the `k8s-aws-platform` and `k8s-demo-api` repositories.

## Step 6: Bootstrap Terraform State Backend

This creates the S3 bucket and DynamoDB table for remote state. Run once:

```bash
make bootstrap
```

After it completes, note the bucket name from the output. Update `terraform/environments/dev/backend.tf` with the actual bucket name:

```bash
# The bucket name follows this pattern:
echo "k8s-platform-terraform-state-${ACCOUNT_ID}"
```

Since you already replaced ACCOUNT_ID in Step 2, this should already be correct. Verify:

```bash
cat terraform/environments/dev/backend.tf
# bucket should show: k8s-platform-terraform-state-<your-12-digit-account-id>
```

## Step 7: Initialize and Plan Infrastructure

```bash
make init
make plan
```

Review the plan carefully. It will create:
- 1 VPC with 9 subnets (3 public, 3 private, 3 isolated)
- 1 EKS cluster with 2 node groups
- 1 RDS PostgreSQL instance
- 2 KMS keys (EKS + RDS)
- 1 ECR repository
- Route 53 hosted zone
- IAM roles (GitHub Actions OIDC, IRSA for cert-manager and external-dns)
- ArgoCD (via Helm)

## Step 8: Apply Infrastructure

```bash
make apply
```

This takes ~15-20 minutes. When complete, note the outputs:

```bash
cd terraform/environments/dev
terraform output
```

Key outputs you'll need:
- `configure_kubectl` — run this command to set up kubectl
- `route53_name_servers` — delegate these from your registrar
- `ecr_repository_url` — use this in your CI/CD pipeline
- `github_actions_role_arn` — set as GitHub Actions variable `AWS_ROLE_ARN`
- `cert_manager_role_arn` — already configured in cert-manager values
- `external_dns_role_arn` — for external-dns if you add it later

## Step 9: Configure kubectl

`make kubeconfig` writes to a dedicated file at `~/.kube/mcp-viewer.kubeconfig`
(not the default `~/.kube/config`) so the read-only Kubernetes MCP can be pointed
at it without colliding with any other clusters in your default kubeconfig.

```bash
make kubeconfig

# Verify (point kubectl at the new file)
KUBECONFIG=~/.kube/mcp-viewer.kubeconfig kubectl get nodes

# Or export it for the shell session
export KUBECONFIG=~/.kube/mcp-viewer.kubeconfig
kubectl get nodes
```

You should see 2 nodes: one `t3.large` (platform) and one `t3.medium` (apps).

Configure the Kubernetes MCP server to use this file (e.g. via the
`KUBECONFIG` env var in its MCP config) so it has read-only cluster access.

## Step 10: DNS Delegation (Route 53)

Route 53 hosts the **apex** `gaiaderma.com` zone (set via
`route53_zone_name = "gaiaderma.com"` in `terraform.tfvars`). Hostinger
delegates the whole domain to AWS by setting the registrar nameservers to the
Route 53 NS records.

> Note: an earlier version of this guide used a subdomain zone
> (`k8s.gaiaderma.com`) and asked Hostinger to add NS records for the `k8s`
> host. Hostinger's UI doesn't expose per-subdomain NS delegation for this
> domain, so we host the apex in Route 53 instead. Any non-platform records
> for `gaiaderma.com` (web, mail, etc.) would have to be recreated in Route
> 53 — for this demo, the domain is used only for the platform.

After `terraform apply`, get the NS records:

```bash
cd terraform/environments/dev
terraform output route53_name_servers
```

Go to your domain registrar (Hostinger for gaiaderma.com):

1. Log in to Hostinger control panel
2. Go to **Domains → gaiaderma.com → DNS / Nameservers**
3. Switch to **Use custom nameservers** (or equivalent) and enter the four
   `ns-XXX.awsdns-XX.*` values from `terraform output route53_name_servers`.
4. Save. Wait for DNS propagation (usually 15–30 minutes, can take up to 48h).

> Important: if you ran `terraform apply` previously with
> `route53_zone_name = "k8s.gaiaderma.com"`, the next apply will destroy the
> old subdomain zone and create a new apex zone with a **different** set of
> four NS records. After the apply, fetch the new NS records and update
> Hostinger again — the NS values you set the first time are now stale.

Verify delegation:

```bash
dig gaiaderma.com NS +short
# Should return the Route 53 name servers (ns-XXX.awsdns-XX.*)
```

## Step 11: Set Up GitHub Actions OIDC

In your GitHub repository settings:

1. Go to **Settings > Environments**, create an environment called `production`
2. Add environment protection rules (optional but recommended): require approval
3. Go to **Settings > Variables and secrets > Variables**
4. Add repository variable:
   - Name: `AWS_ROLE_ARN`
   - Value: (from `terraform output github_actions_role_arn`)

## Step 12: Create the Demo API Database Secret

After the cluster is up and RDS is running:

```bash
# Get the RDS endpoint
RDS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw rds_endpoint)

# Create the secret in dev namespace
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic demo-api-db \
  --namespace=dev \
  --from-literal=url="postgres://dbadmin:${TF_VAR_db_password}@${RDS_ENDPOINT}/appdb?sslmode=require"

# Create ConfigMap
kubectl create configmap demo-api-config \
  --namespace=dev \
  --from-literal=log-level=debug
```

Repeat for prod namespace:

```bash
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic demo-api-db \
  --namespace=prod \
  --from-literal=url="postgres://dbadmin:${TF_VAR_db_password}@${RDS_ENDPOINT}/appdb?sslmode=require"

kubectl create configmap demo-api-config \
  --namespace=prod \
  --from-literal=log-level=info
```

> **Later:** Migrate these secrets to SOPS-encrypted manifests for GitOps management.

## Step 13: Bootstrap ArgoCD App-of-Apps

ArgoCD is installed by Terraform. Bootstrap the app-of-apps:

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Port-forward to access UI
make port-forward-argocd
# Open https://localhost:8443 in browser
# Login: admin / <password from above>

# Apply the root application
kubectl apply -f argocd/bootstrap/root-app.yaml
```

ArgoCD will now sync all platform components in order (sync-waves):
1. cert-manager (wave 0)
2. ingress-nginx (wave 1)
3. kube-prometheus-stack + loki (wave 2)
4. prometheus-adapter + kyverno (wave 3)

## Step 14: Verify Platform

```bash
make verify
```

## Step 15: Set Up Pre-commit Hooks

```bash
pre-commit install
pre-commit run --all-files
```

## Placeholder Reference

| Placeholder | Where to find the value | Files affected |
|------------|------------------------|----------------|
| `ACCOUNT_ID` | `aws sts get-caller-identity --query Account --output text` | 7 files (see Step 2) |
| `REPLACE_ME` (db_password) | Generate with `openssl rand -hex 24` | `terraform.tfvars` |
| `0.0.0.0/0` (CIDR) | `curl -s https://checkip.amazonaws.com` then append `/32` | `terraform.tfvars` |
| `vaskosmihaylov` (github_org) | Your GitHub username | `terraform.tfvars` |

## Estimated Monthly Cost

| Resource | Estimated Cost |
|----------|---------------|
| EKS control plane | $73 |
| t3.large (on-demand, platform) | $60 |
| t3.medium (spot, apps) | $15 |
| RDS db.t3.micro | $15 |
| NAT Gateway | $32 + data |
| Route 53 | $0.50 |
| EBS volumes (Prometheus, Grafana, Loki) | $5 |
| KMS keys (x2) | $2 |
| CloudWatch Logs | $3 |
| **Total** | **~$180/mo** |

To reduce costs when not actively working:
```bash
# Scale down node groups to 0 (keeps control plane running at $73/mo)
aws eks update-nodegroup-config \
  --cluster-name k8s-platform-dev \
  --nodegroup-name platform \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 \
  --region eu-west-1

aws eks update-nodegroup-config \
  --cluster-name k8s-platform-dev \
  --nodegroup-name apps \
  --scaling-config minSize=0,maxSize=2,desiredSize=0 \
  --region eu-west-1
```

To fully tear down when done:
```bash
make teardown
cd terraform/bootstrap && terraform destroy
```
