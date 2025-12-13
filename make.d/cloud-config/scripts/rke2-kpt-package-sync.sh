#!/usr/bin/env -S bash -exuo pipefail

repo_dir="${CLUSTER_STATE_DIR}"
manifest="/etc/rke2-kpt-packages.yaml"
default_branch="main"

if [[ -f /etc/rancher/rke2/environment ]]; then
  # shellcheck disable=SC1091
  source /etc/rancher/rke2/environment
fi

branch="${CLUSTER_STATE_BRANCH:-${default_branch}}"

if [[ ! -d "${repo_dir}/.git" ]]; then
  echo "[rke2-kpt-package-sync] No downstream repo found at ${repo_dir}" >&2
  exit 0
fi

if [[ ! -f "${manifest}" ]]; then
  echo "[rke2-kpt-package-sync] Manifest ${manifest} missing" >&2
  exit 0
fi

if command -v flox >/dev/null 2>&1; then
  source <( flox activate --dir /var/lib/rancher/rke2 )
fi

for tool in git kpt yq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "[rke2-kpt-package-sync] Required tool '${tool}' not found" >&2
    exit 1
  fi
done

cd "${repo_dir}"

pkg_count=$(yq '.packages | length' "${manifest}")
if [[ "${pkg_count}" == "null" ]] || (( pkg_count == 0 )); then
  echo "[rke2-kpt-package-sync] No packages defined in ${manifest}" >&2
  exit 0
fi

for idx in $(seq 0 $((pkg_count - 1))); do
  target=$(yq -r ".packages[${idx}].target" "${manifest}")
  source_url=$(yq -r ".packages[${idx}].source" "${manifest}")
  ref=$(yq -r ".packages[${idx}].ref // \"\"" "${manifest}")
  if [[ -z "${target}" || -z "${source_url}" || "${target}" == "null" || "${source_url}" == "null" ]]; then
    echo "[rke2-kpt-package-sync] Skipping package index ${idx} due to incomplete metadata" >&2
    continue
  fi

  [[ "${ref}" == "null" ]] && ref=""

  spec="${source_url}"
  if [[ -n "${ref}" ]]; then
    spec="${spec}@${ref}"
  fi

  if [[ ! -d "${target}" ]] || [[ ! -f "${target}/Kptfile" ]]; then
    echo "[rke2-kpt-package-sync] Fetching ${target} from ${spec}"
    rm -rf "${target}"
    mkdir -p "$(dirname "${target}")"
    kpt pkg get "${spec}" "${target}"
    continue
  fi

  echo "[rke2-kpt-package-sync] Updating ${target}"
  if ! kpt pkg update "${target}" --strategy=resource-merge; then
    echo "[rke2-kpt-package-sync] Update failed for ${target}, refetching" >&2
    rm -rf "${target}"
    mkdir -p "$(dirname "${target}")"
    kpt pkg get "${spec}" "${target}"
  fi
done

if git status --porcelain | grep -q .; then
  git config user.name "${GIT_AUTHOR_NAME:-rke2-automation}"
  git config user.email "${GIT_AUTHOR_EMAIL:-rke2-automation@local}"
  git add .
  if git commit -m "chore: sync kpt packages"; then
    git push origin "${branch}"
  else
    echo "[rke2-kpt-package-sync] No changes to commit" >&2
  fi
else
  echo "[rke2-kpt-package-sync] No changes detected"
fi

exit 0
