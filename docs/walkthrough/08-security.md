# 8. Security Story

A single defense-in-depth narrative you can tell start to finish in interview.

## Layered controls

| # | Layer | Control | Fails closed because |
|---|---|---|---|
| 1 | **Identity** (CI → AWS) | GitHub OIDC, no long-lived keys | Tokens are 15 min; trust policy scopes to specific sub forms |
| 2 | **Network** (VPC) | Private subnets, RDS in isolated subnets, `publicly_accessible=false`, NAT egress only | RDS unreachable from internet by design |
| 3 | **Host** (EC2) | IMDSv2 enforced, `hop_limit=1` | Pod can't reach metadata service via second hop |
| 4 | **Pod identity** (IRSA) | SA token → STS → scoped IAM role | No long-lived AWS creds in pods or nodes |
| 5 | **Data at rest** | KMS envelope encryption for etcd Secrets, KMS for EBS + RDS, SSL-only on RDS | Encryption keys are AWS-managed, not in-cluster |
| 6 | **Admission** | PSS `restricted` in prod, `baseline` in dev, Kyverno ClusterPolicies | Manifests violating policy rejected at admission |
| 7 | **Authorization** | RBAC role-per-team, `automountServiceAccountToken: false` on default SA | Default SA can't talk to K8s API even if pod escapes |
| 8 | **Network** (in-cluster) | NetworkPolicy default-deny ingress + egress per namespace | Explicit allows for DNS, ingress, scraping, app→RDS |
| 9 | **Supply chain** | ECR scan-on-push, lifecycle (10 images), distroless + non-root images | Vulnerable images surfaced at push; old tags expire |
| 10 | **Secrets in git** | SOPS + AWS KMS via KSOPS plugin in Argo CD repo-server | Decrypt requires KMS access; pull-without-decrypt yields ciphertext |
| 11 | **Terraform access** | Human admin access entry pinned; Terraform CI role has its own EKS access entry | Local and CI callers no longer overwrite each other's cluster-admin principal |

## The single most useful interview answer

> "Each control fails independently. If Kyverno is bypassed by a CRD bug, PSS still enforces. If PSS is bypassed by upgrade, NetworkPolicy still isolates. If a pod escapes, IMDSv2 `hop_limit=1` still blocks node-role assumption. **Compromise needs to cascade through multiple independent layers, not break a single one.**"

## What's deliberately *not* enabled

These are choices, not gaps:

- **SSH to nodes** — disabled. K8s API + `kubectl debug node` covers the diagnostic surface. See [Node Troubleshooting](../operating/troubleshooting.md).
- **SSM Session Manager** — not enabled. Could be added with `AmazonSSMManagedInstanceCore` on the node role + CloudWatch sink for session logs. Currently more attack surface than value.
- **WAF / Shield Advanced** — out of scope for the demo budget; would be the next layer for a real prod ingress.
- **Vault for in-cluster secrets** — SOPS + KMS covers the secrets-in-git case. Vault would add dynamic database creds; useful but ops overhead not justified here.
- **Cluster autoscaler** — not enabled. HPA + manually-sized node groups for the demo footprint.
- **Broad GitHub-hosted runner IP allowlisting** — not enabled. Standard runner IPs are dynamic and
  shared. Terraform applies that need the Kubernetes API should run locally, on a self-hosted runner
  with private network access, or on a larger runner with static IP ranges.

## Upstream docs to read

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) — `baseline` and `restricted`.
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) — namespace label enforcement.
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) — default-deny plus explicit allows.
- [Amazon EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) — pod-to-AWS identity without node credentials.
- [GitHub OIDC with AWS](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) — short-lived CI credentials.
- [GitHub-hosted runner networking](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#ip-addresses) — why shared runner IP ranges are not a strong allowlist boundary.
