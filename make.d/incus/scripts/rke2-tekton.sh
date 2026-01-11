#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl and tooling"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Wait for API server readiness"
until kubectl get --raw /readyz &>/dev/null; do
  echo "[rke2-tekton] waiting for API server..." >&2
  sleep 5
done

: "Source manifest root" # @codebase
SRC_DIR="${RKE2LAB_MANIFESTS_DIR:-/srv/host/rke2/manifests.d}/cicd/tekton-pipelines"
if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[rke2-tekton] source manifest directory not found: ${SRC_DIR}" >&2
  exit 1
fi

: "Apply Tekton Pipelines manifests (recursive)"
kubectl apply -R -f "${SRC_DIR}" --server-side=false

echo "[rke2-tekton] applied Tekton Pipelines manifests from ${SRC_DIR}"
