#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl and tooling"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Source and destination manifest roots"
SRC_DIR="${RKE2LAB_MANIFESTS_DIR:-/srv/host/rke2/manifests.d}"
DST_DIR="/var/lib/rancher/rke2/server/manifests"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[rke2-networking-manifests-install] source manifest directory not found: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${DST_DIR}/networking"

# Clean up any legacy cilium symlink/dir
rm -rf "${DST_DIR}/networking/cilium"

for pkg in cilium-advanced cilium-config traefik; do
  src_layer="${SRC_DIR}/networking/${pkg}"
  dst_layer="${DST_DIR}/networking/${pkg}"
  if [[ -d "${src_layer}" ]]; then
    rm -rf "${dst_layer}"
    ln -sfn "${src_layer}" "${dst_layer}"
    echo "[rke2-networking-manifests-install] linked ${dst_layer} -> ${src_layer}"
  else
    echo "[rke2-networking-manifests-install] skipping missing layer: networking/${pkg}" >&2
  fi
done

: "List installed manifests for debugging"
find "${DST_DIR}" -maxdepth 2 -type f -print | sort
