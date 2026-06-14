#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
FAILURES=0

check() {
  local name="$1"
  shift
  if "$@" &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} ${name}"
  else
    echo -e "${RED}[FAIL]${NC} ${name}"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "==> Verifying platform health..."
echo ""

check "Cluster reachable" kubectl cluster-info

check "All nodes Ready" bash -c '
  ! kubectl get nodes -o jsonpath="{.items[*].status.conditions[-1].type}" | grep -qv Ready
'

check "kube-system pods running" bash -c '
  [ "$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)" -eq 0 ]
'

check "ArgoCD server running" kubectl get deploy -n argocd argocd-server

check "ArgoCD apps synced" bash -c '
  ! argocd app list -o json 2>/dev/null | jq -e ".[] | select(.status.sync.status != \"Synced\")" &>/dev/null
'

check "ingress-nginx controller" kubectl get deploy -n ingress-nginx ingress-nginx-controller

check "cert-manager webhook" kubectl get deploy -n cert-manager cert-manager-webhook

check "Prometheus running" kubectl get statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus

check "Grafana running" kubectl get deploy -n monitoring kube-prometheus-stack-grafana

echo ""
if [ "${FAILURES}" -gt 0 ]; then
  echo -e "${RED}${FAILURES} check(s) failed.${NC}"
  exit 1
else
  echo -e "${GREEN}All checks passed.${NC}"
fi
