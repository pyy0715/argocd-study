#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${ROOT_DIR}/.kube/kubeconfig.yaml"

# v1.x uses an ImageUpdater CRD instead of Application annotations.
# The manifest already pins the argocd namespace, so -n is unnecessary.
echo "Installing Argo CD Image Updater (stable) into argocd namespace..."
kubectl apply \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml

echo "Waiting for rollout..."
kubectl rollout status -n argocd deploy/argocd-image-updater-controller --timeout=180s

cat <<'EOF'

==============================================
Argo CD Image Updater is installed.

Next steps:

1. Create a GitHub PAT with
     - read:packages        (for registry token)
     - repo                 (for git write-back to your study repo)
   A single PAT covering both scopes is fine for local study.

2. Create Kubernetes Secrets in the argocd namespace:

   # registry pull secret — only needed for PRIVATE ghcr images.
   # Public images (like this study repo) can skip it.
   kubectl -n argocd create secret docker-registry ghcr-creds \
     --docker-server=ghcr.io \
     --docker-username=pyy0715 \
     --docker-password=<PAT>

   # git write-back secret — referenced by the ImageUpdater CR.
   kubectl -n argocd create secret generic git-creds \
     --from-literal=username=pyy0715 \
     --from-literal=password=<PAT>

3. (Optional) Override commit author:

   kubectl -n argocd patch configmap argocd-image-updater-config \
     --patch '{"data":{"git.user":"image-updater[bot]","git.email":"updater@example.com"}}'

4. Apply the ImageUpdater CR that targets the hello Application:

   kubectl apply -f bootstrap/image-updater-hello.yaml

See docs/02-image-updater.md for the full walkthrough.
==============================================
EOF
