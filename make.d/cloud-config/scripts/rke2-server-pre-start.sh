#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

if [[ -f /etc/rancher/rke2/environment ]]; then
  # shellcheck disable=SC1091
  source /etc/rancher/rke2/environment
fi

db::check() {
  local -A inet=( [current]="$(nmcli -g IP4.ADDRESS device show vmnet0)" )
  local file="/var/lib/rancher/rke2/server/last-ip"
  if [[ -r "$file" ]]; then
    inet+=( [last]="$(cat "$file")" )
  else
    inet+=( [last]="" )
  fi
  if [[ "${inet[current]}" != "${inet[last]}" ]]; then
    : "IP address changed: ${inet[last]} - ${inet[current]}, resetting RKE2 server DB"
    rm -rf /var/lib/rancher/rke2/server/db
    echo "${inet[current]}" > "$file"
  fi
}

: "Check server database for IP address changes"
db::check

# Manifests are now installed post-start via rke2-server-contribs-install.service
