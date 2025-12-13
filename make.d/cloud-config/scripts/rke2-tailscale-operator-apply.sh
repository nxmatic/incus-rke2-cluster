#!/usr/bin/env -S bash -exuo pipefail

if [[ ${#} -lt 1 ]]; then
  echo "Usage: rke2-tailscale-operator-apply <package-dir> [timeout]" >&2
  exit 64
fi

package_dir="${1}"
timeout="${2:-3m}"

source <(flox activate --dir /var/lib/rancher/rke2)

kpt live apply "${package_dir}" --reconcile-timeout="${timeout}"
