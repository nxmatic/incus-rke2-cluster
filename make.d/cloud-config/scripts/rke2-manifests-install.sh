#!/usr/bin/env -S bash -exuo pipefail

log() {
  echo "[rke2-manifests-install] $*" >&2
}

if command -v flox >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source <(flox activate --dir /var/lib/rancher/rke2)
fi

dest_dir="/var/lib/rancher/rke2/server/manifests"
repo_dir="${CLUSTER_STATE_DIR:-}"

if [[ -z "${repo_dir}" ]]; then
  log "CLUSTER_STATE_DIR is unset; skipping manifest generation"
  exit 0
fi

if [[ ! -d "${repo_dir}" ]]; then
  log "state repo ${repo_dir} missing; skipping manifest generation"
  exit 0
fi

ln -fs \
	${CLUSTER_STATE_DIR}/rke2/clusters/${CLUSTER_NAME}/manifests.yaml \
	/var/lib/rancher/rke2/server/manifests/contribs.yaml

exit 0