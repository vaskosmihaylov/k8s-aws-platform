#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://demo-api.k8s.gaiaderma.com/api/v1/items}"
DURATION="${2:-120s}"
CONCURRENCY="${3:-50}"

echo "==> Load test target: ${URL}"
echo "==> Duration: ${DURATION}, Concurrency: ${CONCURRENCY}"
echo ""
echo "Watch HPA in another terminal:"
echo "  kubectl get hpa -n dev -w"
echo ""

if command -v hey &>/dev/null; then
  hey -z "${DURATION}" -c "${CONCURRENCY}" "${URL}"
else
  echo "Error: 'hey' is not installed."
  echo "Install with: brew install hey"
  exit 1
fi
