#!/usr/bin/env -S bash -eu -o pipefail

# Symlink committed RKE2 config fragments from /srv/rke2-config/config.yaml.d
# into /etc/rancher/rke2/config.yaml.d before rke2-server starts.

set -o pipefail

SRC_DIR="/srv/rke2-config/configmaps"
DEST_DIR="/etc/rancher/rke2/config.yaml.d"

mkdir -p "${DEST_DIR}"

# If source is missing, do nothing (keeps server start from failing)
if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[rke2-config-install] source directory missing: ${SRC_DIR}" >&2
  exit 0
fi

find "${DEST_DIR}" -maxdepth 1 -type f -name '*.yaml' -delete

shopt -s nullglob
for cm in "${SRC_DIR}"/*.yaml; do
  yq -r '.data | to_entries[] | [.key, .value] | @tsv' "$cm" | while IFS=$'\t' read -r key value; do
    printf '%s\n' "$value" > "${DEST_DIR}/${key}"
  done
done

exit 0