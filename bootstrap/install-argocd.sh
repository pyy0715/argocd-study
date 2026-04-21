#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KUBECONFIG_FILE="${ROOT_DIR}/.kube/kubeconfig.yaml"

if [[ ! -f "${KUBECONFIG_FILE}" ]]; then
  echo "kubeconfig not found at ${KUBECONFIG_FILE}"
  echo "Run 'docker compose up -d' first and wait for k3s to start."
  exit 1
fi

export KUBECONFIG="${KUBECONFIG_FILE}"

echo "Waiting for k3s node to become Ready..."
for _ in $(seq 1 60); do
  if kubectl get nodes 2>/dev/null | grep -q " Ready "; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=120s

echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# server-side apply is recommended by the official docs to avoid client-side
# size limits on the ArgoCD CRDs. Pin to a specific version in production.
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for argocd-server Deployment..."
kubectl rollout status -n argocd deploy/argocd-server --timeout=300s

echo
echo "=============================================="
echo "ArgoCD is ready."
echo
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo
echo "Access UI with:"
echo "  make port-forward"
echo "Then open https://localhost:8080 (user: admin)"
echo "=============================================="
