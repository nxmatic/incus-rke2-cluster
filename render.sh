#!/usr/bin/env bash
set -euo pipefail

cluster="${1}"
packages=("${@:2}")
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${repo_root}"

declare -A packages_dir=()
packages_dir["state"]="${repo_root}/packages"
packages_dir["cluster"]="${repo_root}/clusters/${cluster}/packages"
manifests_file="${repo_root}/clusters/${cluster}/manifests.yaml"

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "render.sh: missing required command '$1'" >&2
    exit 1
  fi
}

require_bin kpt
require_bin kustomize

log() {
  echo "render.sh: $*" >&2
}

package:kustomization() {
  local dir="$1"
  local file="${dir}/kustomization.yaml"
  mapfile -t resources < <(cd "${dir}" && find . -type f -name '*.yaml' ! -name 'kustomization.yaml' | sort)
  {
    echo "apiVersion: kustomize.config.k8s.io/v1beta1"
    echo "kind: Kustomization"
    if [[ ${#resources[@]} -gt 0 ]]; then
      echo "resources:"
      for res in "${resources[@]}"; do
        res="${res#./}"
        echo "  - ${res}"
      done
    else
      echo "resources: []"
    fi
  } >"${file}"
}

package:render() {
  local pkg="$1"
  local src="${packages_dir["state"]}/${pkg}"
  local dest="${packages_dir["cluster"]}/${pkg}"

  if [[ ! -d "${src}" ]]; then
    log "package ${pkg} missing in ${packages_dir["state"]}"
    exit 1
  fi

  log "running kpt fn render for ${pkg} from ${src}"
  rm -rf "${dest}"
  kpt fn render "${src}" -o "${dest}"

  package:kustomization "${dest}"
}

rm -fr "${packages_dir["cluster"]}"
mkdir -p "${packages_dir["cluster"]}"
rm -f "${manifests_file}"

for pkg in "${packages[@]}"; do
  package:render "${pkg}"
done

cat <<EOF > "${packages_dir["cluster"]}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
$( for pkg in "${packages[@]}"; do
  echo "  - ./$(basename "${pkg}")"
done )
EOF

kustomize build "clusters/${cluster}" >"${manifests_file}"

log "wrote manifests to ${manifests_file}"
