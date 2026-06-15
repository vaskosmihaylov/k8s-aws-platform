# Browser Access

What you can click in a browser right now. Argo CD ingress + Grafana ingress aren't yet exposed publicly — until then, port-forward.

## Port-forward URLs

| URL | Command | What you see |
|---|---|---|
| `https://localhost:8443` | `make port-forward-argocd` | Argo CD UI |
| `http://localhost:3000` | `make port-forward-grafana` | Grafana |
| `http://localhost:9090` | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090` | Prometheus expression browser |
| `http://localhost:9093` | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093` | Alertmanager |
| `http://localhost:8080` | `make port-forward-api` (once demo-api is deployed) | demo-api endpoints |
| `http://localhost:8001` | `kubectl proxy` | Generic K8s API proxy |

## Argo CD UI

```bash
make port-forward-argocd
# then visit https://localhost:8443 (accept the self-signed cert warning)
```

Login:

```bash
# username
admin

# password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

**First thing to look at**: the App-of-Apps tree. Click `root` → see all child Applications and their sync waves visualized. Click `loki` → "Last Sync Result" tab → you see the exact Helm rendering error.

Click `cert-manager` → resource tree → the live IRSA-annotated ServiceAccount is proof IRSA is wired (not just configured in Terraform).

## Grafana

```bash
make port-forward-grafana
# then visit http://localhost:3000
```

Login:

```bash
# username
admin

# password
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

Pre-loaded dashboards:

- **Kubernetes / API server** — control plane health
- **Kubernetes / Nodes** — node-exporter metrics
- **Kubernetes / Pod** — resource use per pod
- **Prometheus stats** — scrape success, ingestion rate

Data sources: Prometheus (default) + Loki. Loki is currently the broken one — see [Platform Layer → Loki](../walkthrough/05-platform.md#loki).

## Prometheus

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# visit http://localhost:9090
```

Most useful pages:

- **Status → Targets** — shows scrape health. Useful when a ServiceMonitor isn't picking up.
- **Status → Service Discovery** — what Prometheus thinks it should be scraping.
- **Graph** — eyeball `http_requests_per_second` once demo-api is up. Same metric the HPA reads.

## demo-api (once deployed)

```bash
make port-forward-api
```

| Endpoint | What it returns |
|---|---|
| `GET /healthz` | 200 — liveness probe target |
| `GET /readyz` | 200 if DB connection up — readiness probe target |
| `GET /metrics` | Prometheus exposition (request count, latency histograms) |
| `GET /api/v1/items` | CRUD list |
| `POST /api/v1/items` | Create |
| `GET /api/v1/items/{id}` | Read |
| `PUT /api/v1/items/{id}` | Update |
| `DELETE /api/v1/items/{id}` | Delete |

## After Argo CD + external-dns + ingress is fully wired

Per `mem:core`, the planned public hostnames are:

- `https://argocd.k8s.gaiaderma.com` — Argo CD UI with TLS from Let's Encrypt
- `https://grafana.k8s.gaiaderma.com` — Grafana

That's the next milestone after wiring the demo-api repo. Until then, port-forwards above work.
