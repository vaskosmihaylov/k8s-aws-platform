# 6. App Layer

`apps/demo-api/` is the canonical "good citizen" app config — Kustomize base + dev/prod overlays.
The app itself lives in a separate repo, `k8s-demo-api` — minimal CRUD over Postgres, Go stdlib
`net/http` + `jackc/pgx/v5`, no framework, built TDD (vertical slices: one test, one impl, repeat).

Final live state:

- `demo-api-dev` and `demo-api-prod` are both `Synced`/`Healthy` in Argo CD.
- `https://demo-dev.k8s.gaiaderma.com/readyz` returns HTTP 200.
- `https://demo.k8s.gaiaderma.com/readyz` returns HTTP 200.
- No app pods are Pending.

## Layout

```
apps/demo-api/
├── base/
│   ├── deployment.yaml      # resources, probes (live/ready/startup),
│   │                        # seccompProfile RuntimeDefault, runAsNonRoot
│   ├── service.yaml         # ClusterIP
│   ├── hpa.yaml             # v2: CPU + custom http_requests_per_second target
│   ├── networkpolicy.yaml   # allow ingress-nginx -> demo-api;
│   │                        # allow demo-api -> RDS, Prometheus, DNS
│   ├── pdb.yaml             # minAvailable: 1
│   ├── serviceaccount.yaml  # automountServiceAccountToken: false
│   ├── podmonitor.yaml      # see Observability below
│   └── kustomization.yaml
└── overlays/
    ├── dev/    # replicas=1, LOG_LEVEL=debug (via ConfigMap), image tag patched by CI
    │           # + ingress.yaml, secret.enc.yaml, ksops-generator.yaml (see Secrets below)
    └── prod/   # replicas=3, LOG_LEVEL=info (via ConfigMap), topology spread by zone
                # + ingress.yaml, secret.enc.yaml, ksops-generator.yaml (same pattern)
```

## Secrets — SOPS + AWS KMS via KSOPS {#secrets}

The DB connection string (`DATABASE_URL`, Secret `demo-api-db`, key `url`) is delivered as a
**SOPS-encrypted manifest**, decrypted in-cluster by Argo CD's repo-server at manifest-generation
time — the plaintext secret never sits unencrypted in git or on disk outside a throwaway `/tmp` file
during creation.

Per overlay:

- `secret.enc.yaml` — a normal `Secret` manifest, `stringData.url` encrypted by `sops --encrypt`
  against `.sops.yaml`'s `creation_rules` (KMS key alias `k8s-platform-sops`).
- `ksops-generator.yaml` (`apiVersion: viaduct.ai/v1, kind: ksops`) — tells Kustomize's KSOPS
  exec-plugin which encrypted files to decrypt and emit as generated resources.
- Both overlay `kustomization.yaml`s reference the generator via `generators:`.

What makes this work cluster-side (all in `platform/argocd/values.yaml` +
`terraform/environments/dev/main.tf`, applied via Terraform since [Argo CD itself is
Terraform-managed](02-terraform.md)):

- `configs.cm.kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"` on the Argo CD
  `argocd-cm` ConfigMap — KSOPS is a kustomize *exec* plugin, both flags are required.
- A `viaductoss/ksops` init container on `repoServer` that drops the `ksops`/`kustomize` binaries
  into a shared `emptyDir` the main container's `PATH` picks up.
- `module "kms_sops"` (the KMS key) + `module "irsa_argocd_repo_server"` (grants
  `kms:Decrypt`/`DescribeKey` on it) — the repo-server's ServiceAccount is annotated with the
  resulting role ARN so it can actually call KMS at decrypt time.

!!! question "Why not Vault / External Secrets Operator?"
    SOPS + KMS covers the "secrets in git" threat model with zero extra in-cluster operator and no
    new attack surface — ciphertext is safe to commit, and decrypt requires the same KMS access a
    repo-server already needs for other things. Vault/ESO add real value (dynamic, rotated DB
    creds) but are ops overhead this demo's footprint doesn't justify. See [Security
    Story](08-security.md).

## Observability — PodMonitor {#observability}

`apps/demo-api/base/podmonitor.yaml` scrapes `/metrics` every 30s. The label
`release: kube-prometheus-stack` is **required** — it's not a chart default, it's what the live
`Prometheus` CR's `podMonitorSelector.matchLabels` actually requires (confirmed against the live
object, not assumed from chart docs). Without it, Prometheus silently never discovers the pod.
This metric (`http_requests_total`) is what backs the second prometheus-adapter rule described in
[Platform Layer](05-platform.md#prometheus-adapter).

## Interview probes

### "Why all three probe types?"

- **startupProbe** gives slow-start apps headroom without weakening liveness
- **readiness** gates traffic during rolling updates
- **liveness** detects deadlocks

Conflating them is a classic junior mistake. Liveness firing while the app is still starting kills the pod loop.

### "Why `automountServiceAccountToken: false`?"

The API talks to Postgres via a connection string, not the K8s API. Mounting the SA token is unused attack surface. Default-deny.

### "Why PDB `minAvailable: 1` not `maxUnavailable`?"

- `minAvailable` handles scale-up gracefully — always keeps at least N running
- `maxUnavailable` can let you go to 0 during voluntary disruptions if you scaled down

For a 3-replica prod deployment, `minAvailable: 1` (or 2) is the safer phrasing.

### "Why HPA v2 not v1?"

Only v2 supports custom and external metrics. v1 was CPU-only. We use v2 because we scale on `http_requests_per_second` from the [prometheus-adapter](05-platform.md#prometheus-adapter).

## Namespaces — defense in depth at the boundary

```
apps/namespaces/
├── dev.yaml    # PSS enforce: baseline, warn: restricted
└── prod.yaml   # PSS enforce: restricted
```

Each namespace ships with:

- **`ResourceQuota`** — cpu/mem caps for the namespace
- **`LimitRange`** — per-pod default requests/limits
- **`NetworkPolicy`** named `default-deny`, no pod selector (matches all pods) — confirmed live in `dev`

Explicit allow policies sit alongside the default-deny. Layered defense.

Live state includes both namespaces with PSS labels, quotas, limits, and default-deny policies.
The previous single-namespace snippet was an intermediate verification, not the final state:

```
NAMESPACE   POD-SELECTOR   AGE
dev         <none>         44m   (default-deny)
prod        <none>         ...   (default-deny)
```

```
NAME    LABELS
dev     pod-security.kubernetes.io/enforce=baseline,
        pod-security.kubernetes.io/warn=restricted
prod    pod-security.kubernetes.io/enforce=restricted
```

## PriorityClasses

`apps/priority-classes.yaml`:

| Name | Value | globalDefault |
|---|---|---|
| `platform-critical` | 1,000,000,000 | no |
| `app-default` | 100 | **yes** |

If the cluster gets memory-pressured, kubelet evicts low-priority pods first. Platform stays up.

## Relationship to the app repo

The platform repo does not need to own Go source code to be complete. This repo owns the desired
runtime shape: Deployment, Service, HPA, PodMonitor, PDB, NetworkPolicy, Ingress, ConfigMap, and
encrypted Secret. The `k8s-demo-api` repo owns:

- Go handlers and store implementation
- unit/integration tests
- Dockerfile
- image build and ECR push workflow

Future app work should happen in that repo and then update image tags here. That is a good separate
chat/session boundary because the mental model is application development, not platform bootstrap.

## Upstream docs to read

- [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/) — base/overlay model.
- [Kubernetes probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) — liveness, readiness, and startup probes.
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) — HPA v2 behavior and scaling loop.
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) — namespace isolation and explicit allows.
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) — baseline vs restricted policy profiles.
- [SOPS](https://getsops.io/) and [KSOPS](https://github.com/viaduct-ai/kustomize-sops) — encrypted Kubernetes manifests rendered by Kustomize/Argo CD.
