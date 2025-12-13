#!/usr/bin/env -S bash -exuo pipefail

manifest_file="/etc/rke2-kpt-packages.yaml"
dest_dir="/var/lib/rancher/rke2/server/manifests"

log() {
  echo "[rke2-manifests-unpack] $*" >&2
}

if [[ -f /etc/rancher/rke2/environment ]]; then
  # shellcheck disable=SC1091
  source /etc/rancher/rke2/environment
fi

repo_dir="${CLUSTER_STATE_DIR:-}"

if command -v flox >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source <(flox activate --dir /var/lib/rancher/rke2)
fi

if [[ -z "${repo_dir}" ]]; then
  log "CLUSTER_STATE_DIR is unset; skipping manifest generation"
  exit 0
fi

if [[ ! -d "${repo_dir}" ]]; then
  log "state repo ${repo_dir} missing; skipping manifest generation"
  exit 0
fi

if [[ ! -f "${manifest_file}" ]]; then
  log "manifest list ${manifest_file} missing; skipping"
  exit 0
fi

for tool in kpt yq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    log "required tool '${tool}' not found in PATH"
    exit 1
  fi
done

mkdir -p "${dest_dir}"
rm -f "${dest_dir}"/kpt-*.yaml || true

pkg_count=$(yq '.packages | length' "${manifest_file}")
if [[ "${pkg_count}" == "null" ]] || (( pkg_count == 0 )); then
  log "no packages defined in ${manifest_file}"
  exit 0
fi

for idx in $(seq 0 $((pkg_count - 1))); do
  name=$(yq -r ".packages[${idx}].name // \"package-${idx}\"" "${manifest_file}")
  target=$(yq -r ".packages[${idx}].target // \"\"" "${manifest_file}")
  if [[ -z "${target}" || "${target}" == "null" ]]; then
    log "skipping package index ${idx}: missing target"
    continue
  fi

  src="${repo_dir}/${target}"
  if [[ ! -d "${src}" ]]; then
    log "skipping ${name}: ${src} not present"
    continue
  fi

  tmp=$(mktemp)
  if kpt fn source "${src}" --output unwrap >"${tmp}"; then
    safe_name=$(echo "${name}" | tr ' /' '__')
    dest_file="${dest_dir}/kpt-$(printf '%02d' "${idx}")-${safe_name}.yaml"
    mv "${tmp}" "${dest_file}"
    log "wrote ${dest_file}"
  else
    log "failed to unwrap ${name}"
    rm -f "${tmp}"
  fi
done

exit 0