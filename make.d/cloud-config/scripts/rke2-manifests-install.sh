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
  kubectl create secret docker-registry ghcr-pull \
    --namespace=kube-system \
    --docker-server=ghcr.io \
    --docker-username="${CLUSTER_GITHUB_USER:-nxmatic}" \
    --docker-password="${CLUSTER_GITHUB_TOKEN}" \
    --dry-run=client -o yaml > "$MANIFESTS_DIR/0-ghcr-pull.yaml"
  
  : "Add replicator annotation for cross-namespace usage"
  yq eval -i '.metadata.annotations."replicator.v1.mittwald.de/replicate-to" = "porch-system,porch-fn-system,tekton-pipelines"' \
    "$MANIFESTS_DIR/0-ghcr-pull.yaml"
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping ghcr-pull generation"
fi

: "Generate GitHub git credentials secret from CLUSTER_GITHUB_TOKEN"
if [[ -n "${CLUSTER_GITHUB_TOKEN:-}" ]]; then
  kubectl create secret generic github-token \
    --namespace=kube-system \
    --from-literal=username=x-access-token \
    --from-literal=password="${CLUSTER_GITHUB_TOKEN}" \
    --type=kubernetes.io/basic-auth \
    --dry-run=client -o yaml > "$MANIFESTS_DIR/1-github-token.yaml"
  
  : "Add annotations for porch git-auth and replication"
  yq eval -i '
    .metadata.annotations."porch.kpt.dev/git-auth" = "ssh" |
    .metadata.annotations."replicator.v1.mittwald.de/replicate-to" = "porch-system,porch-fn-system,tekton-pipelines"
  ' "$MANIFESTS_DIR/1-github-token.yaml"
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping github-token generation"
fi

: "Secrets generated successfully in $MANIFESTS_DIR"
ls -la "$MANIFESTS_DIR"
