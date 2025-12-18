#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Load environment variables from incus instance config"
if [[ -f /etc/rancher/rke2/environment ]]; then
  set -a
  source /etc/rancher/rke2/environment
  set +a
fi

: "RKE2 static manifests directory"
MANIFESTS_DIR="/var/lib/rancher/rke2/server/manifests"
mkdir -p "$MANIFESTS_DIR"


: "Generate GHCR docker registry secret from CLUSTER_GITHUB_TOKEN"
if [[ -n "${CLUSTER_GITHUB_TOKEN:-}" ]]; then
  for ns in kube-system porch-system porch-fn-system tekton-pipelines; do
    kubectl create secret docker-registry ghcr-pull \
      --namespace="$ns" \
      --docker-server=ghcr.io \
      --docker-username="${CLUSTER_GITHUB_USERNAME:-x-access-token}" \
      --docker-password="${CLUSTER_GITHUB_TOKEN}" \
      --dry-run=client -o yaml > "$MANIFESTS_DIR/0-ghcr-pull-${ns}.yaml"

    # Porch and other workloads rely on the image pull secret without replicator; annotate for porch if present.
    yq eval -i '.metadata.annotations."porch.kpt.dev/git-auth" = "https"' \
      "$MANIFESTS_DIR/0-ghcr-pull-${ns}.yaml"
  done
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping ghcr-pull generation"
fi

: "Generate GitHub git credentials secret from CLUSTER_GITHUB_TOKEN"
if [[ -n "${CLUSTER_GITHUB_TOKEN:-}" ]]; then
  for ns in kube-system porch-system porch-fn-system tekton-pipelines; do
    kubectl create secret generic github-token \
      --namespace="$ns" \
      --from-literal=username="${CLUSTER_GITHUB_USERNAME:-x-access-token}" \
      --from-literal=password="${CLUSTER_GITHUB_TOKEN}" \
      --type=kubernetes.io/basic-auth \
      --dry-run=client -o yaml > "$MANIFESTS_DIR/1-github-token-${ns}.yaml"

    # Porch git auth annotation still needed for porch-system; harmless elsewhere.
    yq eval -i '.metadata.annotations."porch.kpt.dev/git-auth" = "https"' \
      "$MANIFESTS_DIR/1-github-token-${ns}.yaml"
  done
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping github-token generation"
fi

: "Secrets generated successfully in $MANIFESTS_DIR"
ls -la "$MANIFESTS_DIR"
