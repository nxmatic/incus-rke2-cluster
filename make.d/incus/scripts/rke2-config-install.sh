#!/usr/bin/env -S bash -euxo pipefail

# Symlink committed RKE2 config fragments from ${RKE2LAB_CONFIG_DIR}/config.yaml.d
# into /etc/rancher/rke2/config.yaml.d before rke2-server starts.

source <( flox activate --dir /var/lib/cloud )

RKE2LAB_CONFIG_DIR=${RKE2LAB_CONFIG_DIR:?RKE2LAB_CONFIG_DIR is required}

if [[ ! -d "${RKE2LAB_CONFIG_DIR}" ]]; then
  echo "[rke2-config-install] source directory missing: ${RKE2LAB_CONFIG_DIR}" >&2
  exit 1
fi

DEST_DIR="/etc/rancher/rke2/config.yaml.d"

mkdir -p "${DEST_DIR}"

# find "${DEST_DIR}" -maxdepth 1 -type f -name '*.yaml' -delete

shopt -s nullglob
for cm in "${RKE2LAB_CONFIG_DIR}"/*.yaml; do
  yq -r ".data" "$cm" > "${DEST_DIR}/$(basename "$cm")"
done

exit 0
