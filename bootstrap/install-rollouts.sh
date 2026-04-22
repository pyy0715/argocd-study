#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${ROOT_DIR}/.kube/kubeconfig.yaml"

echo "Installing Argo Rollouts controller into argo-rollouts namespace..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "Waiting for rollout..."
kubectl rollout status -n argo-rollouts deploy/argo-rollouts --timeout=180s

cat <<'EOF'

==============================================
Argo Rollouts is installed.

Optional: install the kubectl plugin for easier observation.
  brew install argoproj/tap/kubectl-argo-rollouts
  # or
  mise use -g argo-rollouts

Observe a Rollout:
  kubectl argo rollouts get rollout hello -n hello --watch

Promote a paused step manually:
  kubectl argo rollouts promote hello -n hello
==============================================
EOF
