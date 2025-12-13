#!/usr/bin/env -S bash -exuo pipefail

FLOX_ENV_DIR="${FLOX_ENV_DIR:-/var/lib/rancher/rke2}"

if [[ -z "${RKE2_KPT_SKIP_FLOX:-}" ]]; then
  if command -v flox >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(flox activate --dir "${FLOX_ENV_DIR}")
  else
    echo "[rke2-kpt-deploy] flox command not found, continuing without flox environment" >&2
  fi
fi

usage() {
  echo "Usage: rke2-kpt-deploy <package-path> [options] -- [setter args]" >&2
  echo >&2
  echo "Options:" >&2
  echo "  --timeout[=DURATION]   Override reconcile timeout (default: 3m or ${KPT_LIVE_TIMEOUT})" >&2
  echo "  --skip-fn              Skip kpt fn eval (run live apply only)" >&2
  echo "  --render-output-dir DIR  Write fn render output to DIR and apply from there" >&2
  echo "  --<flag>               Additional kpt fn flags before \"--\" pass through to kpt fn eval" >&2
}

package_path="${1:-}"
if [[ -z "${package_path}" ]]; then
  usage >&2
  exit 64
fi
shift

timeout="${KPT_LIVE_TIMEOUT:-3m}"
render_output_dir=""
run_fn=1
fn_flags=()
while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --timeout=*)
      timeout="${1#*=}"
      shift
      ;;
    --timeout)
      if [[ ${#} -lt 2 ]]; then
        echo "[rke2-kpt-deploy] --timeout requires a value" >&2
        exit 64
      fi
      timeout="${2}"
      shift 2
      ;;
    --skip-fn)
      run_fn=0
      shift
      ;;
    --render-output-dir=*)
      render_output_dir="${1#*=}"
      shift
      ;;
    --render-output-dir)
      if [[ ${#} -lt 2 ]]; then
        echo "[rke2-kpt-deploy] --render-output-dir requires a value" >&2
        exit 64
      fi
      render_output_dir="${2}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      fn_flags+=("${1}")
      shift
      ;;
  esac
done

setter_args=(${@})
fn_config_file=""
cleanup() {
  if [[ -n "${fn_config_file}" && -f "${fn_config_file}" ]]; then
    rm -f "${fn_config_file}"
  fi
}
trap cleanup EXIT

if [[ -n "${render_output_dir}" ]]; then
  rm -rf "${render_output_dir}"
  mkdir -p "${render_output_dir}"
fi

if (( ${#setter_args[@]} )); then
  if ! command -v yq >/dev/null 2>&1; then
    echo "[rke2-kpt-deploy] yq command is required for setter arguments" >&2
    exit 1
  fi

  fn_config_file="$(mktemp)"
  yq -n '
    .apiVersion = "v1" |
    .kind = "ConfigMap" |
    .metadata.name = "apply-setters-input" |
    .data = {}
  ' > "${fn_config_file}"

  for kv in "${setter_args[@]}"; do
    if [[ "${kv}" != *=* ]]; then
      echo "[rke2-kpt-deploy] setter argument '${kv}' must be key=value" >&2
      exit 64
    fi
    key="${kv%%=*}"
    value="${kv#*=}"
    yq eval --inplace ".data.\"${key}\" = \"${value}\"" "${fn_config_file}"
  done
  if ! kpt fn eval "${package_path}" \
    --image ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2 \
    --fn-config "${fn_config_file}"; then
    echo "[rke2-kpt-deploy] apply-setters failed" >&2
    exit 1
  fi
fi
apply_path="${render_output_dir:-${package_path}}"
render_args=("${package_path}" "${fn_flags[@]}")
if [[ -n "${render_output_dir}" ]]; then
  render_args+=(--output "${render_output_dir}")
fi
if [[ ${run_fn} -eq 1 ]]; then
  kpt fn render "${render_args[@]}"
fi

kpt live apply "${apply_path}" \
  --reconcile-timeout="${timeout}" \
  --cache-dir=${KPT_CACHE_DIR:-/var/lib/rancher/rke2/kpt-live-cache} \
  --inventory-policy=adopt
