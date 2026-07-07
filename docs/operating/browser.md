# Browser Access

What you can click in a browser right now. Public HTTPS works through Route 53, external-dns,
cert-manager, ingress-nginx, and the AWS NLB. Port-forwards are still useful for local debugging.

## Public URLs

| URL | What you see | Final check |
|---|---|---|
| `https://argocd.k8s.gaiaderma.com` | Argo CD UI | HTTP 200 |
| `https://grafana.k8s.gaiaderma.com` | Grafana login | HTTP 302 to `/login` |
| `https://demo-dev.k8s.gaiaderma.com/readyz` | dev app readiness | HTTP 200 |
| `https://demo.k8s.gaiaderma.com/readyz` | prod app readiness | HTTP 200 |

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

Data sources: Prometheus (default) + Loki. Both are Synced/Healthy — see [Platform Layer → Loki](../walkthrough/05-platform.md#loki) for the fix history.

## Prometheus

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# visit http://localhost:9090
```

Most useful pages:

- **Status → Targets** — shows scrape health. Useful when a ServiceMonitor isn't picking up.
- **Status → Service Discovery** — what Prometheus thinks it should be scraping.
- **Graph** — eyeball `http_requests_per_second` once demo-api is up. Same metric the HPA reads.

## demo-api

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

## DNS and TLS checks

```bash
for h in \
  argocd.k8s.gaiaderma.com \
  demo-dev.k8s.gaiaderma.com \
  demo.k8s.gaiaderma.com \
  grafana.k8s.gaiaderma.com
do
  echo "== $h =="
  dig +short "$h"
done
```

All four currently resolve to the same ingress NLB address path. The exact IP can change because the
NLB is AWS-managed; the stable contract is the DNS name.
