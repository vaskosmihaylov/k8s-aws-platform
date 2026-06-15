# 3. EKS Shape

EKS 1.31 (N-1 from GA), hardened by default, with a mixed on-demand + spot node strategy.

## Version and endpoint

- **EKS 1.31** — one minor version behind GA. Lets third-party operators (Argo CD, Kyverno, Prometheus Operator) publish compatibility statements.
- **Public + private endpoint** with `public_access_cidrs` whitelist to a single home IP.

!!! question "Interview probe"
    "Why not private-only?" → Private-only requires a bastion or VPN to reach the API. The whitelist is the pragmatic middle ground for a solo build. Production would be private-only + bastion.

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

Hosts the demo-api. **Why spot?** Stateless app pods are perfect spot candidates; PDB + multiple replicas + topology spread make eviction safe.

## CNI

**AWS VPC CNI** with two key knobs:

- **Prefix delegation** — each ENI gets `/28` prefixes instead of one IP at a time. Raises the pods-per-node ceiling on small instance types. Default cap on t3.medium without prefix delegation is ~17 pods; with it, you're bound by CPU/memory.
- **`enableNetworkPolicy: true`** — VPC CNI itself enforces NetworkPolicy resources via eBPF. Recent (2023+) and lets you skip Calico.

The alternative is **Calico or Cilium as a separate CNI** with the operational cost of running them. Used to be the default; now optional.

## EBS CSI — the manual-step caveat

EKS 1.31 ships **no default StorageClass and no CSI driver out of the box**.

- The driver itself was added as a managed addon + IRSA in `main.tf`
- The `gp3` StorageClass with `is-default-class: "true"` is currently `kubectl apply`'d by hand post-Terraform

Live state confirms both:

```
gp2             kubernetes.io/aws-ebs   Delete   WaitForFirstConsumer   false
gp3 (default)   ebs.csi.aws.com         Delete   WaitForFirstConsumer   true
```

`gp2` is the legacy in-tree provisioner — kept around for historical reasons, but the in-tree provisioner was removed and only `ebs.csi.aws.com` would actually work.

!!! warning "Follow-up"
    Convert the `gp3` StorageClass apply to a `kubernetes_manifest` resource (kubernetes-provider) or a `null_resource` with `local-exec`. Currently a known IaC gap.
