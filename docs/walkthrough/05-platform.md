# 5. Platform Layer

Each platform component is upstream Helm chart + a `values.yaml` in `platform/<component>/`. Small but each has an interview-relevant talking point.

## ingress-nginx

`platform/ingress-nginx/values.yaml`:

- **NLB annotations**: `service.beta.kubernetes.io/aws-load-balancer-type: external`,
  `aws-load-balancer-scheme: internet-facing`, `aws-load-balancer-nlb-target-type: ip`
- **Metrics**: `metrics.enabled=true`, `metrics.serviceMonitor.enabled=true`
- **Platform pinning**: `nodeSelector` + `tolerations` keep it on platform nodes
- **Admission webhook certgen placement**: patch Jobs also run on the platform node so they do not
  get stuck behind apps-node pod pressure

!!! question "Why NLB not ALB?"
    NLB is L4 — TLS termination happens at ingress-nginx, not the LB. Lets ingress-nginx handle SNI, cert rotation via cert-manager, ModSecurity, etc. ALB terminates TLS at AWS, which limits in-cluster cert flexibility.

## AWS Load Balancer Controller

This is the controller that made the ingress-nginx `LoadBalancer` Service actually provision an AWS
NLB. The in-tree AWS cloud provider cannot satisfy the combination used here:

- `aws-load-balancer-type: external`
- `aws-load-balancer-nlb-target-type: ip`

The split is deliberate:

- Terraform owns AWS IAM: vendored upstream IAM policy JSON, `aws_iam_policy.aws_lb_controller`,
  and `module.irsa_aws_lb_controller`.
- Argo CD owns the Helm chart: `argocd/platform/aws-load-balancer-controller.yaml` plus
  `platform/aws-load-balancer-controller/values.yaml`.

Two important fixes made it stable:

1. `vpcId` is pinned in values. Auto-discovery through IMDS fails from pods because node metadata
   uses IMDSv2 with `hop_limit=1`; raising the hop limit would expose node-role credentials to pods.
2. Argo CD ignores webhook TLS Secret data and webhook `caBundle` drift because the chart/controller
   manage those values out-of-band.

## cert-manager

- **IRSA SA annotation**: `eks.amazonaws.com/role-arn: arn:aws:iam::649822034735:role/k8s-platform-dev-cert-manager` (verified live)
- **CRDs installed** by the chart (`installCRDs=true`)
- **DNS-01 over HTTP-01** because we want wildcard certs and DNS-01 doesn't require the LB to be publicly reachable during issuance

!!! success "Fixed (2026-06-22) — dual source block"
    `argocd/platform/cert-manager.yaml` had **both** a singular `source:` (no `$values`) and a plural `sources:` (with `$values`) — an invalid spec where the plural happened to win, but if the singular ever won, cert-manager would install with default Helm values (no IRSA → DNS-01 broken). The stray singular block has been removed; committed and verified live (root reconciled, `cert-manager` Application Healthy with only the plural block in spec).

- **ClusterIssuers**: two issuers (`letsencrypt-staging`, `letsencrypt-prod`) are embedded directly in `platform/cert-manager/values.yaml` via `extraObjects` — both DNS-01 over Route53, scoped to the same `hostedZoneID` the IRSA policy grants. demo-api's Ingress uses the staging issuer first (avoids Let's Encrypt rate limits) before switching to prod.

Live certificates are Ready for Argo CD and both demo-api environments.

## external-dns

`external-dns` watches Ingress resources and reconciles Route 53 records for `gaiaderma.com`.

Key settings:

- `provider.name: aws`
- `sources: [ingress]`
- `domainFilters: [gaiaderma.com]`
- `registry: txt` with `txtOwnerId: k8s-platform-dev`
- `policy: upsert-only`
- `aws-zone-type: public`
- `prefer-alias: true`
- IRSA ServiceAccount annotation for `k8s-platform-dev-external-dns`

Final live signal:

```
external-dns ... 1/1 Running
All records are already up to date
```

Public hostnames currently resolve and serve HTTPS:

- `argocd.k8s.gaiaderma.com`
- `demo-dev.k8s.gaiaderma.com`
- `demo.k8s.gaiaderma.com`
- `grafana.k8s.gaiaderma.com`

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

**Fixed (2026-06-22).** This was a genuinely instructive bug: the `grafana/loki` chart's
`templates/validate.yaml` enforces several cross-field invariants, but `helm template` (what Argo CD's
manifest generation runs) only surfaces **one validation error per render** — fixing it just reveals
the next one. It took 4 sequential rounds to get from `Unknown` sync to `Synced`/`Healthy`.

1. **Deployment mode conflict.** First sync error:

   ```
   Failed to load target state: failed to generate manifest for source 1 of 2:
   Error: execution error at (loki/templates/validate.yaml:31:4):
   You have more than zero replicas configured for both the single binary and
   simple scalable targets. If this was intentional change the deploymentMode
   to the transitional 'SingleBinary<->SimpleScalable' mode
   ```

   `platform/loki/values.yaml` was setting replicas on both `singleBinary` and `read/write/backend`
   (the simple-scalable path) — chart 6.6.4 rejects that. Fix: `deploymentMode: SingleBinary` +
   zeroed `backend.replicas`/`read.replicas`/`write.replicas`.

2. **Missing schema config.** Chart 6.6.4 has no default `schemaConfig` — it's mandatory. Added
   `loki.schemaConfig` (`store: tsdb`, `object_store: filesystem`, `schema: v13`).

3. **Oversized default caches.** `chunksCache`/`resultsCache` default to Memcached subcharts
   requesting ~9.8Gi memory **each** — wildly oversized for this 2-node demo cluster, caused
   `FailedScheduling` on both nodes. Disabled both (`chunksCache.enabled: false`,
   `resultsCache.enabled: false`, top-level keys, not nested under `loki:`) — this is the chart's
   own documented recommendation for resource-constrained environments.

4. **Canary/test coupling.** `lokiCanary.enabled: false` is also a top-level key —
   `monitoring.lokiCanary.enabled` doesn't exist and silently no-ops. Once the canary is disabled,
   `test.enabled: false` is also required: the chart's `validate.yaml` has
   `if and (not lokiCanary.enabled) test.enabled`, and `test.enabled` defaults `true` assuming the
   canary exists for `helm test` to probe. Argo CD never runs `helm test`, so disabling it is correct.

Final state: `loki` Application `Synced`/`Healthy`, single `loki-0` pod `Running`/`Ready`.

**Lesson:** the Application showed `Healthy` even while broken, because there were no pods to be
unhealthy — Argo CD just couldn't render the chart, so nothing got deployed. `Unknown` sync status
was the real signal, not `Health`. `verify-platform.sh`'s loki check was a false-PASS case for the
same reason.

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

!!! note "Second rule added for demo-api (2026-06-22)"
    The original rule derives `http_requests_per_second` from the **nginx ingress** series (Service-resource type). demo-api's HPA wants a **Pods**-resource metric instead, so a second rule was added mapping the app's own `http_requests_total{namespace,pod}` (scraped via the [PodMonitor](06-app.md#observability) below) to `http_requests_per_second` on the `pod` resource, using the Pods-type aggregation pattern (`sum(rate(...)) by (<<.GroupBy>>)`). Both rules coexist; nginx's is unaffected.

## Kyverno

3 ClusterPolicies in `platform/kyverno/policies/`:

- **Disallow `:latest` image tag** — forces explicit versioning
- **Require resource limits** — every container must have `resources.limits`
- **Require probes** — at least liveness + readiness on each container

!!! question "Why Kyverno over OPA / Gatekeeper?"
    The policy language is **YAML / JSON pattern matching**, not Rego. Lower-friction onboarding. Gatekeeper is more powerful for complex constraints but the Rego learning curve is real. Kyverno covers ~90% of K8s policy use cases.

### Cleanup CronJob image fix

Kyverno's chart ships 5 cleanup `CronJob`s (admission/cluster-admission/update-requests/ephemeral/
cluster-ephemeral reports) plus 2 helm-hook Jobs, all defaulting to `bitnami/kubectl:1.28.5`.
Bitnami deprecated its general Docker Hub catalog in August 2025, so every run hit
`ImagePullBackOff` — and because these are CronJobs, that's not a one-time failure, it's a
recurring one every 10 minutes, each spawning a fresh broken pod.

Fix in `platform/kyverno/values.yaml`: override all 7 image refs to `bitnamilegacy/kubectl:1.28.5`
(Bitnami's relocated legacy registry — a drop-in replacement that still ships bash, which the
cleanup script needs; `registry.k8s.io/kubectl` is distroless/no-shell and would break it).
Verified via `helm template`.

Final state: `kyverno` is `Synced`/`Healthy`, its controllers run on the platform node, and the
cluster has no Pending pods.

## Upstream docs to read

- [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) — how Services and Ingresses become AWS load balancers.
- [AWS Load Balancer Controller Service annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/) — the `external` and `nlb-target-type: ip` annotations.
- [cert-manager Route 53 DNS-01](https://cert-manager.io/docs/configuration/acme/dns01/route53/) — Route 53 solver configuration for ACME challenges.
- [external-dns AWS tutorial](https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/aws/) — Route 53 record reconciliation.
- [Prometheus Operator API](https://prometheus-operator.dev/docs/developer/getting-started/) — why `ServiceMonitor`, `PodMonitor`, and `PrometheusRule` exist.
- [Kyverno policies](https://kyverno.io/docs/writing-policies/) — pattern-based admission policy without Rego.
