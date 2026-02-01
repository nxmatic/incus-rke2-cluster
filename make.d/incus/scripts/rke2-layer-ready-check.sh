#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 environment for kubectl and tooling"
source <(flox activate --dir /var/lib/rancher/rke2)

log() {
  echo "[rke2-layer-ready] $*"
}

usage() {
  echo "Usage: $(basename "$0") <layer|layer/subpath>" >&2
  echo "Example: $(basename "$0") networking" >&2
  echo "         $(basename "$0") mesh" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

layer="${1%/}"
base_dir="${RKE2LAB_MANIFESTS_DIR:-/srv/host/manifests.d}"
src_dir="${base_dir}/${layer}"
timeout="${RKE2_LAYER_READY_TIMEOUT:-300s}"

if [[ ! -d "${src_dir}" ]]; then
  log "Manifest directory not found: ${src_dir}"
  exit 1
fi

declare -a crds
declare -a workloads

collect_with_yq() {
  local -a files
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "${src_dir}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

  if [[ ${#files[@]} -eq 0 ]]; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    crds+=("${line}")
  done < <(yq -r 'select(.kind == "CustomResourceDefinition") | .metadata.name' "${files[@]}" | sort -u)

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    workloads+=("${line}")
  done < <(
    yq -r 'select(.kind == "Deployment" or .kind == "DaemonSet" or .kind == "StatefulSet") |
      "\(.kind)\t\(.metadata.name)\t\(.metadata.namespace // "default")"' "${files[@]}" | sort -u
  )
}

collect_with_awk() {
  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      if [[ "${line}" == CRD* ]]; then
        crds+=("${line#CRD\t}")
      else
        workloads+=("${line}")
      fi
    done < <(
      awk '
        function flush_doc() {
          if (kind == "CustomResourceDefinition" && name != "") {
            print "CRD\t" name
          } else if (kind == "Deployment" || kind == "DaemonSet" || kind == "StatefulSet") {
            if (name != "") {
              if (ns == "") ns = "default"
              print kind "\t" name "\t" ns
            }
          }
          kind=""; name=""; ns=""; inmeta=0
        }
        /^---/ { flush_doc(); next }
        /^kind:/ { kind=$2; next }
        /^metadata:/ { inmeta=1; next }
        inmeta && /^[[:space:]]+name:/ { name=$2; next }
        inmeta && /^[[:space:]]+namespace:/ { ns=$2; next }
        /^[^[:space:]]/ { inmeta=0 }
        END { flush_doc() }
      ' "${file}" | sort -u
    )
  done < <(find "${src_dir}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
}

if command -v yq >/dev/null 2>&1; then
  collect_with_yq
else
  log "yq not found; falling back to awk-based parsing"
  collect_with_awk
fi

if [[ ${#crds[@]} -gt 0 ]]; then
  log "Waiting for CRDs to be established"
  for crd in "${crds[@]}"; do
    kubectl wait --for=condition=established "crd/${crd}" --timeout="${timeout}"
  done
fi

if [[ ${#workloads[@]} -eq 0 ]]; then
  log "No workloads found for layer ${layer}; skipping workload readiness"
  exit 0
fi

log "Waiting for workloads in layer ${layer}"
for entry in "${workloads[@]}"; do
  IFS=$'\t' read -r kind name namespace <<<"${entry}"
  resource=$(echo "${kind}" | tr '[:upper:]' '[:lower:]')

  kubectl get namespace "${namespace}" >/dev/null 2>&1 || kubectl create namespace "${namespace}" >/dev/null
  kubectl -n "${namespace}" rollout status "${resource}/${name}" --timeout="${timeout}"
done

log "Layer ${layer} workloads are ready"