#!/usr/bin/env bash
set -euo pipefail

cluster="${1:-default}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${repo_root}"

packages=(
  porch
  porch-resources
  replicator
  flux-operator
  tekton-pipelines
  traefik
  cilium
)

packages_dir="${repo_root}/packages"
rendered_dir="${repo_root}/rendered"
manifests_dir="${repo_root}/manifests/${cluster}"

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "render.sh: missing required command '$1'" >&2
    exit 1
  fi
}

require_bin kpt
require_bin kustomize
require_bin rsync

log() {
  echo "render.sh: $*" >&2
}

generate_kustomization() {
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

render_package() {
  local pkg="$1"
  local src="${packages_dir}/${pkg}"
  local dest="${rendered_dir}/${pkg}"
  local -a rsync_excludes=(
    "--exclude=.local*/"
    "--exclude=*setters*.yaml"
    "--exclude=render-helm-chart.yaml"
  )

  [[ -d "${src}" ]] || {
    log "source package ${src} missing"
    exit 1
  }

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  rsync -a --delete "${src}/" "${tmp}/${pkg}/"
  pushd "${tmp}/${pkg}" >/dev/null
  log "running kpt fn render for ${pkg}"
  kpt fn render >/dev/null
  popd >/dev/null

  rm -rf "${dest}"
  mkdir -p "${dest}"
  rsync -a --delete "${rsync_excludes[@]}" "${tmp}/${pkg}/" "${dest}/"
  generate_kustomization "${dest}"

  rm -rf "${tmp}"
  trap - RETURN
}

mkdir -p "${rendered_dir}" "${manifests_dir}"

for pkg in "${packages[@]}"; do
  render_package "${pkg}"
done

idx=0
for pkg in "${packages[@]}"; do
  overlay_path="overlays/${cluster}/${pkg}"
  [[ -d "${overlay_path}" ]] || {
    log "overlay ${overlay_path} missing"
    exit 1
  }

  dest_file=$(printf "%s/kpt-%02d-%s.yaml" "${manifests_dir}" "${idx}" "${pkg}")
  log "building ${pkg} -> ${dest_file}"
  kustomize build "${overlay_path}" >"${dest_file}"
  idx=$((idx + 1))
done

log "wrote ${idx} manifests into ${manifests_dir}"
