#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

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
	mkdir -p /var/lib/rancher/rke2/server/db
    echo "${inet[current]}" > "$file"
  fi
}

: "Check server database for IP address changes"
db::check

# Manifests are installed pre-start via rke2-cilium.service
