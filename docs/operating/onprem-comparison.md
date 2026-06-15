# On-Prem Comparison

Framed against Pixelpark reality: which parts of this stack are meaningfully harder *without* AWS, versus which have direct equivalents you already operate.

## Concern-by-concern

| Concern | EKS here | On-prem vSphere / HAProxy / Puppet equivalent | Verdict |
|---|---|---|---|
| **K8s control plane** | Managed. Multi-AZ. AWS owns etcd backups, upgrades, security patches. | 3 control-plane VMs, kubeadm / RKE / kubespray, etcd backup cron, upgrade rehearsals. | **Much harder on-prem.** This is what you pay AWS for. |
| **Node lifecycle** | Managed node group + spot mix. Auto-replacement on AZ failure. | Terraform vSphere VM + Puppet for kubelet / containerd / CNI. Pets vs. cattle if you're not careful. | **Slightly harder on-prem,** but Pixelpark already has the muscle. |
| **Pod-level cloud IAM (IRSA)** | First-class. SA → IAM role with zero infrastructure beyond Terraform. | No clean equivalent. Closest: Vault + Kubernetes auth + Vault Agent Injector, or static AWS keys in Secret. | **Significantly harder on-prem.** Second AWS killer feature. |
| **Load balancer** | NLB via Service annotation. AWS owns the LB. | HAProxy fleet you manage via Puppet / Hiera. | **Equivalent or easier on-prem** — you already do this and it's stable. |
| **TLS automation** | cert-manager + DNS-01 + IRSA + Let's Encrypt + Route 53. | cert-manager + DNS-01 + internal DNS provider, or HAProxy + file certs renewed by cron. | **Equivalent.** cert-manager runs both places identically. |
| **Block storage** | EBS CSI + gp3, encrypted, per-AZ. | Ceph RBD CSI (you have Ceph), or vSphere CSI. | **Equivalent or *easier* on-prem.** Ceph is more flexible (RWX via CephFS, snapshots). |
| **Logs** | Loki (here) + S3 (production target). | Elasticsearch 8.19 + Logstash + Filebeat (you have this). | **Equivalent.** ES is heavier ops; Loki is cheaper for high volume. |
| **Metrics** | kube-prometheus-stack. | Same stack, federated from K8s to central Prometheus (you have this). | **Equivalent.** |
| **DNS for apps** | external-dns + Route 53 via IRSA. | external-dns + internal DNS provider. | **Equivalent** if you have programmable DNS (PowerDNS, RFC 2136). |
| **Secrets at rest in git** | SOPS + AWS KMS. | SOPS + age (file key) or Vault Transit. | **Equivalent.** KMS removes key-material management; age is just a file. |
| **GitOps** | Argo CD. | Argo CD (you run 50+ apps). | **Identical.** Same patterns transfer 100%. |
| **CI/CD AWS auth** | OIDC, no static keys. | Static creds, or Vault dynamic AWS secrets engine. | **AWS wins** for cleanliness. |
| **Cost** | ~$180/mo for this footprint. | vSphere VMs already paid for; ops time is the real cost. | **Different shape.** Cloud is OpEx; on-prem looks cheap until you count SRE time. |

## The two-line answer

> "The **managed control plane** and **IRSA** are where EKS earns its money. Everything else — LB, storage, observability, GitOps, DNS — has a direct on-prem equivalent that's often simpler to operate if you already have the platform. The trade is OpEx versus ops engineering time."

## What this means for the interview

Pixelpark experience covers ~80% of this stack already (Argo CD, Prometheus, HAProxy LBs, Ceph storage, Terraform with vSphere provider, Elasticsearch). The cloud-K8s gap closed by this project is concentrated in:

1. **EKS managed control plane lifecycle** — endpoint config, control-plane logging, IAM-vs-K8s-auth (aws-auth ConfigMap or access entries), addon management.
2. **IRSA** — OIDC provider, trust policies, projected SA tokens.
3. **AWS networking primitives** — VPC subnets, security groups, NAT gateways, NLB annotations, Route 53 hosted zones.
4. **AWS-native CI/CD federation** — GitHub OIDC, no long-lived keys.

Everything else is a transferable conversation about *which* tool, not whether you've used something like it.
