#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl and tooling"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Source and destination manifest roots" # @codebase
SRC_DIR="${RKE2LAB_MANIFESTS_DIR:-/srv/host/rke2/manifests.d}"
DST_DIR="/var/lib/rancher/rke2/server/manifests"
PKG_PATH="cicd/tekton-pipelines"

if [[ ! -d "${SRC_DIR}/${PKG_PATH}" ]]; then
  echo "[rke2-tekton-pipelines-manifests-install] source manifest directory not found: ${SRC_DIR}/${PKG_PATH}" >&2
  exit 1
fi

mkdir -p "${DST_DIR}/cicd"

src_layer="${SRC_DIR}/${PKG_PATH}"
dst_layer="${DST_DIR}/${PKG_PATH}"

: "[rke2-tekton-pipelines-manifests-install] linking ${dst_layer} -> ${src_layer}"

ln -sfn "${src_layer}" "${dst_layer}"
