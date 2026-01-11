#!/usr/bin/env -S bash -euxo pipefail

# Symlink committed RKE2 config fragments from /.rke2lab/rke2-config.d/config.yaml.d
# into /etc/rancher/rke2/config.yaml.d before rke2-server starts.

SRC_DIR="/.rke2lab/rke2-config.d/configmaps"
DEST_DIR="/etc/rancher/rke2/config.yaml.d"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[rke2-config-install] source directory missing: ${SRC_DIR}" >&2
  exit 1
fi

source <( flox activate --dir /var/lib/cloud/seed/nocloud )

mkdir -p "${DEST_DIR}"

find "${DEST_DIR}" -maxdepth 1 -type f -name '*.yaml' -delete

shopt -s nullglob
for cm in "${SRC_DIR}"/*.yaml; do
  yq -r ".data" "$cm" > "${DEST_DIR}/$(basename "$cm")"
done

exit 0