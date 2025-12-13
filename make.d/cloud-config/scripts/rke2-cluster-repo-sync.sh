#!/usr/bin/env -S bash -exu -o pipefail

repo_dir="${CLUSTER_STATE_DIR}"
default_repo="https://github.com/nxmatic/fleet-manifests.git"
default_branch="rke2-subtree"

if [[ -f /etc/rancher/rke2/environment ]]; then
  # shellcheck disable=SC1091
  source /etc/rancher/rke2/environment
fi

repo_url="${CLUSTER_STATE_REPO_URL:-${default_repo}}"
repo_branch="${CLUSTER_STATE_BRANCH:-${default_branch}}"

if command -v flox >/dev/null 2>&1; then
  source <( flox activate --dir /var/lib/cloud/seed/nocloud )
fi

if [[ -z "${repo_url}" ]]; then
  echo "[rke2-cluster-repo-sync] CLUSTER_STATE_REPO_URL not set" >&2
  exit 1
fi

mkdir -p "$(dirname "${repo_dir}")"
if [[ -d "${repo_dir}/.git" ]]; then
  git -C "${repo_dir}" fetch origin "${repo_branch}"
  git -C "${repo_dir}" reset --hard "origin/${repo_branch}"
  git -C "${repo_dir}" clean -fdx
else
  git clone --single-branch --branch "${repo_branch}" "${repo_url}" "${repo_dir}"
fi
