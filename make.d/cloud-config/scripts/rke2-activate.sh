#!/usr/bin/env -S bash -exu -o pipefail

: "Configure system-wide DNS"
ln -fs /run/systemd/resolve/resolv.conf /etc/resolv.conf

: "Start and wait for the RKE2 installation to complete"
systemctl enable --now rke2-install

: "Load the RKE2 environment"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Load the RKE2 environment and generate the named units"
/usr/local/sbin/rke2-enable-containerd-zfs-mount

: "Enable and start the RKE2 service"
systemctl --no-block --now \
  enable rke2-${NODE_TYPE}
