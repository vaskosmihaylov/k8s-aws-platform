# 5. Platform Layer

Each platform component is upstream Helm chart + a `values.yaml` in `platform/<component>/`. Small but each has an interview-relevant talking point.

## ingress-nginx

`platform/ingress-nginx/values.yaml`:

- **NLB annotations**: `service.beta.kubernetes.io/aws-load-balancer-type: nlb` — L4 LB
- **Metrics**: `metrics.enabled=true`, `metrics.serviceMonitor.enabled=true`
- **Platform pinning**: `nodeSelector` + `tolerations` keep it on platform nodes

!!! question "Why NLB not ALB?"
    NLB is L4 — TLS termination happens at ingress-nginx, not the LB. Lets ingress-nginx handle SNI, cert rotation via cert-manager, ModSecurity, etc. ALB terminates TLS at AWS, which limits in-cluster cert flexibility.

## cert-manager

- **IRSA SA annotation**: `eks.amazonaws.com/role-arn: arn:aws:iam::649822034735:role/k8s-platform-dev-cert-manager` (verified live)
- **CRDs installed** by the chart (`installCRDs=true`)
- **DNS-01 over HTTP-01** because we want wildcard certs and DNS-01 doesn't require the LB to be publicly reachable during issuance

!!! warning "Known follow-up — dual source block"
    `argocd/platform/cert-manager.yaml` has **both** a singular `source:` (no `$values`) and a plural `sources:` (with `$values`). Currently Healthy because plural wins, but the spec is invalid. If singular ever wins, cert-manager installs with default Helm values (no IRSA → DNS-01 broken). Delete the singular `source:` block.

## kube-prometheus-stack

`platform/kube-prometheus-stack/values.yaml`:

- Grafana with ingress
- Prometheus retention 15 d, 20 Gi PV
- Alertmanager with empty receivers (demo)

!!! question "Why this over plain Helm prometheus + grafana?"
    The **Prometheus Operator** is the answer. It owns three CRDs that make Prometheus dynamic:

    - `ServiceMonitor` — "scrape Services with this label"
    - `PodMonitor` — same but for Pods directly
    - `PrometheusRule` — alerting rules, labelled and discovered

    No `prometheus.yml` reloads. No static configs. Apps just declare scrape intent.

## Loki {#loki}

Currently **broken**. Sync error from Argo CD:

```
Failed to load target state: failed to generate manifest for source 1 of 2: 
Error: execution error at (loki/templates/validate.yaml:31:4): 
You have more than zero replicas configured for both the single binary and 
simple scalable targets. If this was intentional change the deploymentMode 
to the transitional 'SingleBinary<->SimpleScalable' mode
```

`platform/loki/values.yaml` is setting replicas on both `singleBinary` and `read/write/backend` (the simple-scalable path). Chart 6.6.4 rejects that.

The Application shows `Healthy` because there are no pods to be unhealthy — Argo CD just can't render the chart, so nothing got deployed. `verify-platform.sh` doesn't catch it because the script's loki check is one of the false-PASS cases.

!!! tip "Fix"
    Pick one mode. For demos, single-binary + filesystem storage:

    ```yaml
    deploymentMode: SingleBinary
    singleBinary:
      replicas: 1
    read:
      replicas: 0
    write:
      replicas: 0
    backend:
      replicas: 0
    ```

    For production: simple-scalable + S3 + boltdb-shipper for index. That's the interview talking point — single-binary is for demos, simple-scalable is what you'd actually run.

## prometheus-adapter

Custom rule exposing `http_requests_per_second` from `http_requests_total` over the last minute:

```yaml
rules:
  custom:
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: { resource: "namespace" }
          pod:       { resource: "pod" }
      name:
        matches: "^(.*)_total"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)'
```

This serves the `v1beta1.custom.metrics.k8s.io` APIService — confirmed live and Available. Enables HPA v2 to scale on `Pods` or `Object` metrics, not just CPU/memory.

## Kyverno

3 ClusterPolicies in `platform/kyverno/policies/`:

- **Disallow `:latest` image tag** — forces explicit versioning
- **Require resource limits** — every container must have `resources.limits`
- **Require probes** — at least liveness + readiness on each container

!!! question "Why Kyverno over OPA / Gatekeeper?"
    The policy language is **YAML / JSON pattern matching**, not Rego. Lower-friction onboarding. Gatekeeper is more powerful for complex constraints but the Rego learning curve is real. Kyverno covers ~90% of K8s policy use cases.
