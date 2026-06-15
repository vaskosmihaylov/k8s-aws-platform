# 6. App Layer

`apps/demo-api/` is the canonical "good citizen" app config — Kustomize base + dev/prod overlays.

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
│   └── kustomization.yaml
└── overlays/
    ├── dev/    # replicas=1, LOG_LEVEL=debug, image tag patched by CI
    └── prod/   # replicas=3, LOG_LEVEL=info, topology spread by zone
```

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

Live state:

```
NAMESPACE   POD-SELECTOR   AGE
dev         <none>         44m   (default-deny)
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
