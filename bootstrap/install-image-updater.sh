#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${ROOT_DIR}/.kube/kubeconfig.yaml"

echo "Installing Argo CD Image Updater into argocd namespace..."
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

echo "Waiting for rollout..."
kubectl rollout status -n argocd deploy/argocd-image-updater --timeout=180s

cat <<'EOF'

==============================================
Argo CD Image Updater is installed.

Next steps to make it work with ghcr.io:

1. Create a GitHub PAT with read:packages scope and write access to your study repo.
2. Create Kubernetes Secrets:

   # registry pull secret (name matches pullsecret annotation)
   kubectl -n argocd create secret docker-registry ghcr-creds \
     --docker-server=ghcr.io \
     --docker-username=YOUR_USERNAME \
     --docker-password=YOUR_PAT

   # git write-back token (referenced from argocd-image-updater-secret)
   kubectl -n argocd create secret generic git-creds \
     --from-literal=username=YOUR_USERNAME \
     --from-literal=password=YOUR_PAT

3. Configure write-back credentials:

   kubectl -n argocd patch configmap argocd-image-updater-config \
     --patch '{"data":{"git.user":"image-updater[bot]","git.email":"updater@example.com"}}'

4. Apply the Stage 2 / 3 Applications once secrets are in place.
==============================================
EOF
