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

path="${1%/}"
layer_dir=$(dirname "${path}")
pkg_name=$(basename "${path}")

# Normalize layer_dir when no slash was provided
if [[ "${layer_dir}" == "." ]]; then
  layer_dir="${pkg_name}"
  pkg_name=""
fi

src_dir="${BASE_DIR}/${path}"
if [[ ! -d "${src_dir}" ]]; then
  echo "[rke2-manifests-install] source manifest directory not found: ${src_dir}" >&2
  exit 1
fi

if [[ -z "${pkg_name}" ]]; then
  : "Install all manifests for layer ${layer_dir}"
  stow_dir="${BASE_DIR}"
  target_dir="${DST_DIR}/${layer_dir}"
  mkdir -p "${target_dir}"
  xstow -d "${stow_dir}" -t "${target_dir}" "${layer_dir}"
else
  : "Install package ${pkg_name} for layer ${layer_dir}"
  stow_dir="${BASE_DIR}/${layer_dir}"
  target_dir="${DST_DIR}/${layer_dir}/${pkg_name}"
  mkdir -p "${target_dir}"
  xstow -d "${stow_dir}" -t "${target_dir}" "${pkg_name}"
fi
