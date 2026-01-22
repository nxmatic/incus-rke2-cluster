#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 flox environment for kubectl and tooling"
source <( flox activate --dir /var/lib/rancher/rke2 )

if [[ -z "${RKE2LAB_MANIFESTS_DIR:-}" ]]; then
  echo "[rke2-manifests-install] RKE2LAB_MANIFESTS_DIR is required (exported by incus env file)" >&2
  exit 1
fi

if [[ -z "${RKE2_SERVER_MANIFESTS_DIR:-}" ]]; then
  echo "[rke2-manifests-install] RKE2_SERVER_MANIFESTS_DIR is required (exported by incus env file)" >&2
  exit 1
fi

BASE_DIR="${RKE2LAB_MANIFESTS_DIR}"
DST_DIR="${RKE2_SERVER_MANIFESTS_DIR}"

usage() {
  echo "Usage: $(basename "$0") <layer|layer/subpath>" >&2
  echo "Example: $(basename "$0") networking" >&2
  echo "         $(basename "$0") cicd/tekton-pipelines" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if ! command -v xstow >/dev/null 2>&1; then
  echo "[rke2-manifests-install] xstow is required but not found in PATH" >&2
  exit 1
fi

path="${1%/}"
parent_dir=$(dirname "${path}")
pkg_name=$(basename "${path}")

# Normalize parent_dir when no slash was provided
if [[ "${parent_dir}" == "." ]]; then
  parent_dir=""
fi

src_dir="${BASE_DIR}/${path}"
if [[ ! -d "${src_dir}" ]]; then
  echo "[rke2-manifests-install] source manifest directory not found: ${src_dir}" >&2
  exit 1
fi

stow_dir="${BASE_DIR}/${parent_dir}"
target_dir="${DST_DIR}/${parent_dir}"

mkdir -p "${target_dir}"

: "Restow to refresh symlinks if they already exist in ${target_dir} for package ${pkg_name}"
xstow -R -d "${stow_dir}" -t "${target_dir}" "${pkg_name}"
