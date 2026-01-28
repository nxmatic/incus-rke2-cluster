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

ensure_tailscale_operator_oauth() {
  local namespace="${TAILSCALE_NAMESPACE:-tailscale-system}"

  if [[ -z "${TSKEY_OAUTH_ID:-}" || -z "${TSKEY_OAUTH_TOKEN:-}" ]]; then
    echo "[rke2-manifests-install] tailscale operator oauth vars missing (TSKEY_OAUTH_ID/TSKEY_OAUTH_TOKEN); skipping operator-oauth Secret" >&2
    return 0
  fi

  kubectl get namespace "${namespace}" >/dev/null 2>&1 || kubectl create namespace "${namespace}" >/dev/null

  kubectl -n "${namespace}" create secret generic operator-oauth \
    --from-literal=client_id="${TSKEY_OAUTH_ID}" \
    --from-literal=client_secret="${TSKEY_OAUTH_TOKEN}" \
    --dry-run=client -o yaml | 
	kubectl apply -f - >/dev/null
}

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

if [[ "${path}" == "mesh" || "${path}" == "mesh/tailscale" || "${path}" == mesh/tailscale/* ]]; then
  ensure_tailscale_operator_oauth
fi

stow_dir="${BASE_DIR}/${parent_dir}"
target_dir="${DST_DIR}/${path}"

mkdir -p "${target_dir}"

: "Restow to refresh symlinks if they already exist in ${target_dir} for package ${pkg_name}"
xstow -R -d "${stow_dir}" -t "${target_dir}" "${pkg_name}"
