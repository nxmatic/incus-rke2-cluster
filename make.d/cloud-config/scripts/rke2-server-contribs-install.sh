#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "RKE2 static manifests directory"
MANIFESTS_SRV_DIR="/srv/rke2-contribs"
MANIFESTS_RKE2_DIR="/var/lib/rancher/rke2/server/manifests/contribs.d"

for layer in cicd ha gitops networking runtime storage; do
	mkdir -p "${MANIFESTS_RKE2_DIR}/${layer}"
	mount -o bind \
		"${MANIFESTS_SRV_DIR}/${layer}" \
		"${MANIFESTS_RKE2_DIR}/${layer}"
done

: "Generate GHCR docker registry secret from CLUSTER_GITHUB_TOKEN (replicator work-around)"
if [[ -n "${CLUSTER_GITHUB_TOKEN:-}" ]]; then
  for ns in kube-system porch-system porch-fn-system tekton-pipelines; do
    kubectl create secret docker-registry ghcr-pull \
      --namespace="$ns" \
      --docker-server=ghcr.io \
      --docker-username="${CLUSTER_GITHUB_USERNAME:-x-access-token}" \
      --docker-password="${CLUSTER_GITHUB_TOKEN}" \
      --dry-run=client -o yaml > "${MANIFESTS_RKE2_DIR}/0-ghcr-pull-${ns}.yaml"

    # Porch and other workloads rely on the image pull secret without replicator; annotate for porch if present.
    yq eval -i '.metadata.annotations."porch.kpt.dev/git-auth" = "https"' \
      "${MANIFESTS_RKE2_DIR}/0-ghcr-pull-${ns}.yaml"
  done
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping ghcr-pull generation"
fi

: "Generate GitHub git credentials secret from CLUSTER_GITHUB_TOKEN (replicator work-around)"
if [[ -n "${CLUSTER_GITHUB_TOKEN:-}" ]]; then
  for ns in kube-system porch-system porch-fn-system tekton-pipelines; do
    kubectl create secret generic github-token \
      --namespace="$ns" \
      --from-literal=username="${CLUSTER_GITHUB_USERNAME:-x-access-token}" \
      --from-literal=password="${CLUSTER_GITHUB_TOKEN}" \
      --type=kubernetes.io/basic-auth \
      --dry-run=client -o yaml > "${MANIFESTS_RKE2_DIR}/1-github-token-${ns}.yaml"

    # Porch git auth annotation still needed for porch-system; harmless elsewhere.
    yq eval -i '.metadata.annotations."porch.kpt.dev/git-auth" = "https"' \
      "${MANIFESTS_RKE2_DIR}/1-github-token-${ns}.yaml"
  done
else
  : "WARNING: CLUSTER_GITHUB_TOKEN not set, skipping github-token generation"
fi

: "Mounted contribs in server manifests"
tree "$MANIFESTS_RKE2_DIR"