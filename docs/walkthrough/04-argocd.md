# 4. Argo CD — The Platform's Spine

Argo CD is installed once by Terraform; everything else installs via Argo CD.

## Bootstrap order

```
Terraform helm_release       ──┐
                               ├─ Argo CD installed (chicken-and-egg solved)
                               │
kubectl apply argocd/bootstrap/
            root-app.yaml    ──┤
                               ├─ "root" Application created
                               │
root watches argocd/platform/* ┤
                               ├─ Argo CD creates child Applications
                               │
each child watches             ─┤
  platform/<name>/             │
  (Helm values) or apps/<name>/├─ Resources deployed
  (Kustomize)                  │
```

!!! question "Interview probe"
    "How do you bootstrap Argo CD itself if Argo CD is supposed to manage everything?"
    → Terraform installs it once via `helm_release`. After that, Argo CD even manages its *own* values via a self-referencing Application (App-of-Apps is recursive — the root Application includes Argo CD itself).

## Sync waves — dependency ordering

The annotation `argocd.argoproj.io/sync-wave: "<N>"` controls order. Lower wave numbers complete first.

| Wave | Applications | Why this wave |
|---|---|---|
| **-1** | `priority-classes` | Must exist before any pod claims a class. |
| **0** | `namespaces`, `cert-manager` | Namespaces have PSS labels + ResourceQuota + LimitRange + default-deny NP. cert-manager CRDs are needed by ingress. |
| **1** | `ingress-nginx` | Uses `platform-critical` PriorityClass from wave -1. |
| **2** | `kube-prometheus-stack`, `loki` | Observability stack. |
| **3** | `prometheus-adapter`, `kyverno` | prometheus-adapter needs Prometheus; kyverno uses `ServerSideApply=true`. |
| **4** | `demo-api-dev`, `demo-api-prod` | App layer; needs cert-manager (TLS), prometheus-adapter (HPA metric), and the KSOPS-decrypted DB secret all already in place. |

Live evidence (2026-06-22, after the kyverno/gp3/KSOPS handoff session):

```
NAMESPACE   KIND          NAME                    SYNC STATUS   HEALTH STATUS
argocd      Application   cert-manager            Synced        Healthy
argocd      Application   demo-api-dev            OutOfSync     Degraded
argocd      Application   demo-api-prod           OutOfSync     Degraded
argocd      Application   ingress-nginx           Synced        Progressing
argocd      Application   kube-prometheus-stack   Synced        Progressing
argocd      Application   kyverno                 Synced        Healthy
argocd      Application   loki                    Synced        Healthy
argocd      Application   namespaces              Synced        Healthy
argocd      Application   priority-classes        Synced        Healthy
argocd      Application   prometheus-adapter      Synced        Healthy
argocd      Application   root                    Synced        Healthy
```

`loki` was `Unknown` due to a chart values bug — now fixed; see [Platform Layer → loki](05-platform.md#loki).

`demo-api-{dev,prod}` are `OutOfSync`/`Degraded` because, as of this snapshot, none of the
handoff-session changes (the demo-api image, the ConfigMap/Secret/PodMonitor/Ingress manifests, the
KSOPS wiring itself) are pushed yet — Argo CD is still tracking the last-synced commit
(`beede5c`), which predates all of it. Expected to resolve to Synced/Healthy once pushed and
synced; see [App Layer](06-app.md) for everything that's now wired.

## ArgoCD's own Helm values changed for KSOPS

`platform/argocd/values.yaml` gained `configs.cm.kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"`
and a `viaductoss/ksops` init container on `repoServer`, plus a `repoServer.serviceAccount.annotations`
IRSA role ARN (from the new `module "irsa_argocd_repo_server"`). **Because Argo CD itself is
Terraform-managed, not GitOps-managed**, none of this takes effect on a Git push/sync — it requires
`terraform apply` (specifically updates `helm_release.argocd` in place). This was the actual mechanism
behind this session's "KSOPS infra" apply: 0 resources added, 1 changed (the helm_release).

## Two non-obvious details

### Multi-source with `$values` ref

Each platform Application declares **both** the upstream Helm chart and this repo as a `$values` source. Argo CD merges your `platform/<component>/values.yaml` into the chart at render time.

```yaml
spec:
  sources:
    - chart: ingress-nginx
      repoURL: https://kubernetes.github.io/ingress-nginx
      targetRevision: 4.11.2
      helm:
        valueFiles:
          - $values/platform/ingress-nginx/values.yaml
    - ref: values
      repoURL: https://github.com/vaskosmihaylov/k8s-aws-platform.git
      targetRevision: main
```

**Why not commit a vendored chart?** Vendoring rots. Multi-source means you bump the chart version in the Application CR and re-sync.

### Kyverno needs `ServerSideApply=true`

Kyverno CRDs (especially `clusterpolicies.kyverno.io`) **exceed 256 KiB**.

Client-side `kubectl apply` stores the entire object in the `kubectl.kubernetes.io/last-applied-configuration` annotation, which has a 256 KiB ceiling.

The fix: server-side apply. kube-apiserver tracks fields in `metadata.managedFields` instead.

`argocd/platform/kyverno.yaml`:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - ServerSideApply=true
```

### The orphan-manifest fix

`apps/priority-classes.yaml` and `apps/namespaces/*.yaml` were in the repo but no Application targeted them. Two new Applications in `argocd/platform/` wire them in:

- `priority-classes.yaml` (sync-wave `-1`)
- `namespaces.yaml` (sync-wave `0`)

The root App-of-Apps picks them up automatically because it watches `argocd/platform/*.yaml`.
