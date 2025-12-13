#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

: "Install the RKE2 server or agent binaries"
curl -sfL https://get.rke2.io | env DEBUG=1 sh -

: "Patch containerd to use systemd cgroup driver"
if [ -f "$CONTAINERD_CONFIG_FILE" ]; then
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' "$CONTAINERD_CONFIG_FILE"
fi

: "Enable shared mount service"
systemctl daemon-reload
systemctl enable rke2-remount-shared
