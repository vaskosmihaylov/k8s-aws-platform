# 3. EKS Shape

EKS 1.31 (N-1 from GA), hardened by default, with a mixed on-demand + spot node strategy.

## Version and endpoint

- **EKS 1.31** — one minor version behind GA. Lets third-party operators (Argo CD, Kyverno, Prometheus Operator) publish compatibility statements.
- **Public + private endpoint** with `public_access_cidrs` whitelist to a single operator IP.

!!! question "Interview probe"
    "Why not private-only?" → Private-only requires a bastion, VPN, or private runner path to reach the API.
    The whitelist is the pragmatic middle ground for a solo build. Production would be private-only
    plus a runner/bastion/VPN path.

## Hardening

| Control | What it does |
|---|---|
| **Control plane logs** (all 5 types) → CloudWatch | api, audit, authenticator, controllerManager, scheduler. Audit log is the one auditors actually want. ~$0.50/GB ingest. |
| **Envelope encryption** with EKS KMS key | Secret resources are encrypted again at the etcd layer — not just by EBS-at-rest. |
| **IMDSv2 enforced, `hop_limit=1`** | Pods can't reach the node's instance metadata service via hop 2 — that's what would let a compromised pod assume the node's IAM role. **Single most important EC2-side hardening.** |
| **Managed addons** | coredns, kube-proxy, vpc-cni, ebs-csi — version pinned in Terraform; AWS owns lifecycle. |
| **EBS CSI with IRSA** | Driver runs with its own IAM role; no node-level perms. |

## Node groups — why mixed

Two managed node groups (confirmed live):

### Platform — `t3.large` ON_DEMAND, tainted

```yaml
taint:
  key: dedicated
  value: platform
  effect: NoSchedule
labels:
  node-role: platform
```

Hosts Argo CD, cert-manager, ingress-nginx, Prometheus, Kyverno.
Tolerations + `nodeSelector: node-role=platform` on Helm values pin them here.

**Why on-demand?** Platform pods can't tolerate spot eviction without 30 s drain blowing up DNS / ingress.

### Apps — `t3.medium` SPOT, no taints

Hosts the demo-api. **Why spot?** Stateless app pods are perfect spot candidates; PDB + prod replicas
make eviction safer than running stateful platform components there.

!!! note "Desired-size caveat"
    The wrapper sets the apps node group `desired_size = 2`, but the upstream EKS managed node group
    module ignores `scaling_config[0].desired_size` after creation so autoscalers or manual AWS changes
    do not fight Terraform. Live AWS currently reports desired size `1`, max size `2`, and there are no
    Pending pods. If the interview story needs two live apps nodes, scale it explicitly with
    `aws eks update-nodegroup-config` or add a dedicated capacity-management path instead of assuming
    Terraform will reconcile desired size.

## CNI

**AWS VPC CNI** with two key knobs:

- **Prefix delegation** — each ENI gets `/28` prefixes instead of one IP at a time. Raises the pods-per-node ceiling on small instance types. Default cap on t3.medium without prefix delegation is ~17 pods; with it, you're bound by CPU/memory.
- **`enableNetworkPolicy: true`** — VPC CNI itself enforces NetworkPolicy resources via eBPF. Recent (2023+) and lets you skip Calico.

The alternative is **Calico or Cilium as a separate CNI** with the operational cost of running them. Used to be the default; now optional.

## EBS CSI and default gp3 StorageClass

EKS 1.31 ships **no default StorageClass and no CSI driver out of the box**.

- The driver itself was added as a managed addon + IRSA in `main.tf`
- The `gp3` StorageClass with `is-default-class: "true"` is managed by Terraform as `kubernetes_storage_class_v1.gp3`

Live state:

```
gp2             kubernetes.io/aws-ebs   Delete   WaitForFirstConsumer   false
gp3 (default)   ebs.csi.aws.com         Delete   WaitForFirstConsumer   true
```

`gp2` is the legacy in-tree provisioner — kept around for historical reasons, but the in-tree provisioner was removed and only `ebs.csi.aws.com` would actually work.

## Upstream docs to read

- [Amazon EKS cluster endpoint access](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html) — public/private endpoint modes and CIDR allowlists.
- [Amazon EKS managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) — lifecycle and scaling model for EKS-managed nodes.
- [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) — why EBS provisioning is a CSI add-on and not a built-in default.
- [Amazon VPC CNI network policy](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html) — how the AWS CNI enforces NetworkPolicy.
