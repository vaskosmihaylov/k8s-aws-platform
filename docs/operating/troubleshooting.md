# Node Troubleshooting

EKS managed nodes don't expose SSH; IMDSv2 `hop_limit=1` blocks pod-side metadata access. **This is correct.** Here's the escalation ladder, in interview order.

## 1. Don't shell — query the K8s API first

90% of "node issues" are scheduler, kubelet, or networking problems visible without ever logging in.

```bash
kubectl describe node <name>                       # conditions, taints, capacity, allocated resources
kubectl get events -A --sort-by='.lastTimestamp'   # the actual signal
kubectl top node                                    # if metrics-server is up
kubectl logs -n kube-system <pod>                  # for cloud-controller, kube-proxy, etc.
```

## 2. `kubectl debug node` — modern, K8s-native shell

```bash
kubectl debug node/ip-10-0-11-98.eu-west-1.compute.internal -it --image=ubuntu
# inside the debug pod:
chroot /host /bin/bash   # now you're on the node
```

The debug pod is privileged, mounts the host filesystem at `/host`, and is auto-cleaned up on exit. **Works identically on EKS, GKE, AKS.**

## 3. AWS SSM Session Manager (deliberately not enabled)

If you want `aws ssm start-session --target i-...`:

1. Add managed policy `AmazonSSMManagedInstanceCore` to the **node role** in Terraform
2. SSM agent is preinstalled on the EKS-optimized AL2023 AMI
3. Then: `aws ssm start-session --target <instance-id>` — no inbound ports opened

!!! note "Why it's currently NOT enabled"
    Less attack surface, everything debuggable via the K8s API, and SSM session logs would need CloudWatch sink + retention setup. This is a defensible choice, not a gap. If you enable it, you also enable session log capture for audit.

## 4. Control-plane logs in CloudWatch

All 5 EKS control-plane log types are enabled. For weird scheduler / admission / audit issues:

- Log group: `/aws/eks/<cluster>/cluster`
- Log streams: `kube-apiserver-audit-*`, `kube-scheduler-*`, `kube-controller-manager-*`, `kube-apiserver-*`, `authenticator-*`

The audit log is *invaluable* for "who did what when" — interview gold.

```bash
aws logs filter-log-events \
  --log-group-name /aws/eks/k8s-platform-dev/cluster \
  --log-stream-name-prefix kube-apiserver-audit \
  --filter-pattern '{ $.verb = "delete" }'
```

## 5. VPC Flow Logs

VPC has flow logs on. For "pod can't reach RDS" or "ingress isn't getting traffic", the flow log answers: *was the packet even routed?*

```bash
aws logs filter-log-events \
  --log-group-name /aws/vpc/flow-logs/<vpc-id> \
  --filter-pattern 'REJECT'
```

## Interview answer

> "I don't SSH to EKS nodes.
>
> I escalate: `kubectl describe` → `kubectl events` → `kubectl logs` → `kubectl debug node` → CloudWatch control-plane logs → VPC flow logs.
>
> SSM is the bail-out when I genuinely need a shell, and it's something I'd add deliberately with audit logging on, not a default."

## Per-symptom playbook

| Symptom | First check |
|---|---|
| Pod stuck in `Pending` | `kubectl describe pod` → events. Usually: PVC waiting for first consumer, no node matches taints, resource quota exhausted, PriorityClass invalid. |
| Pod in `CrashLoopBackOff` | `kubectl logs --previous`. Then `kubectl describe pod` for last termination reason. |
| Pod `ImagePullBackOff` | `kubectl describe pod` → events. ECR auth? Image tag typo? Lifecycle expired the tag? |
| Service has endpoints but traffic doesn't reach pods | NetworkPolicy default-deny. Check explicit allow exists. |
| HPA stuck at min replicas under load | `kubectl describe hpa`. Metric API reachable? prometheus-adapter healthy? |
| Argo CD app Out of Sync | `argocd app diff <name>` or click "App Diff" in UI. Cluster drift or manifest change? |
| Argo CD app Unknown | Helm template error or repo-server can't reach git. Check `kubectl logs -n argocd deploy/argocd-repo-server`. |
| Cert not issuing | `kubectl describe certificate`, then `certificaterequest`, then `order`, then `challenge`. The chain tells you which step failed. |
