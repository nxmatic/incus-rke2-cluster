#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 environment for kubectl and tooling"
source <(flox activate --dir /var/lib/rancher/rke2)

log() {
  echo "[rke2-layer-ready] $*"
}

usage() {
  echo "Usage: $(basename "$0") <layer|layer/subpath> [--package <name>]" >&2
  echo "Example: $(basename "$0") networking" >&2
  echo "         $(basename "$0") mesh" >&2
  echo "         $(basename "$0") storage --package openebs-zfs" >&2
}

layer=""
package_filter=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--package)
      package_filter="${2:-}"
      if [[ -z "${package_filter}" ]]; then
        log "Missing package name for $1"
        usage
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -* )
      log "Unknown option: $1"
      usage
      exit 1
      ;;
    * )
      if [[ -n "${layer}" ]]; then
        log "Unexpected argument: $1"
        usage
        exit 1
      fi
      layer="$1"
      shift
      ;;
  esac
done

if [[ -z "${layer}" ]]; then
  usage
  exit 1
fi

layer="${layer%/}"
base_dir="${RKE2LAB_MANIFESTS_DIR:-/srv/host/manifests.d}"
src_dir="${base_dir}/${layer}"
timeout="${RKE2_LAYER_READY_TIMEOUT:-300s}"

if [[ ! -d "${src_dir}" ]]; then
  log "Manifest directory not found: ${src_dir}"
  exit 1
fi

if [[ -n "${package_filter}" ]]; then
  package_dir="${src_dir}/${package_filter}"
  if [[ -d "${package_dir}" ]]; then
    src_dir="${package_dir}"
  else
    log "Package directory not found: ${package_dir}; falling back to layer scan"
  fi
fi

declare -a namespaces=()
declare -a crds=()
declare -a workloads=()

loadMetadataFromManifestFiles() {
  local -a files
  local package_selector
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "${src_dir}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

  if [[ ${#files[@]} -eq 0 ]]; then
    return 0
  fi

  namespaces=( $( yq ea '[.. | select(has("namespace")) | .namespace | select(.)] | unique | .[]' "${files[@]}" ) )

  package_selector='.'
  if [[ -n "${package_filter}" ]]; then
    package_selector='select(.metadata.annotations["kpt.dev/package-name"] == "'"${package_filter}"'")'
  fi

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    crds+=("${line}")
  done < <(yq -r "${package_selector} | select(.kind == \"CustomResourceDefinition\") | .metadata.name" "${files[@]}" | sort -u)

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    workloads+=("${line}")
  done < <(
    yq -r "${package_selector} | select(.kind == \"Deployment\" or .kind == \"DaemonSet\" or .kind == \"StatefulSet\") |
      [.kind, .metadata.name, (.metadata.namespace // \"default\")] | @tsv" "${files[@]}" | sort -u
  )
}

loadMetadataFromManifestFiles

if [[ ${#crds[@]} -gt 0 ]]; then
  log "Waiting for CRDs to be established"
  for crd in "${crds[@]}"; do
    kubectl wait --for=condition=established "crd/${crd}" --timeout="${timeout}"
  done
fi

log "Ensuring namespaces exist for layer ${layer}${package_filter:+ (package ${package_filter})}"
if [[ ${#namespaces[@]} -eq 0 ]]; then
  log "No namespaces found for layer ${layer}${package_filter:+ (package ${package_filter})}; skipping namespace creation"
  exit 0
fi
for namespace in "${namespaces[@]}"; do
  kubectl wait --for=create "namespace/${namespace}" --timeout=30s
  kubectl wait --for=jsonpath='{.status.phase}'=Active "namespace/${namespace}" --timeout="10s"
done

log "Waiting for workloads in layer ${layer}${package_filter:+ (package ${package_filter})}"
for entry in "${workloads[@]}"; do
  IFS=$'\t' read -r kind name namespace <<<"${entry}"
  resource=$(echo "${kind}" | tr '[:upper:]' '[:lower:]')

  kubectl get namespace "${namespace}" >/dev/null 2>&1 || kubectl create namespace "${namespace}" >/dev/null
  kubectl -n "${namespace}" rollout status "${resource}/${name}" --timeout="${timeout}"
done

log "Layer ${layer} workloads are ready"
