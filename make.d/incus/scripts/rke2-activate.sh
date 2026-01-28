#!/usr/bin/env -S bash -exu -o pipefail

: "Disable IPv6 system-wide"
sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

: "Configure system-wide DNS"
ln -fs /run/systemd/resolve/resolv.conf /etc/resolv.conf

: "Enable RKE2 systemd units"
systemctl enable \
	rke2-network-config.service \
	rke2-network-debug.service \
	rke2-network-wait.service \
	rke2-route-cleanup.service \
	zfs-early-umount.service \
	rke2-remount-shared.service \
	rke2-networking-manifests-install.service \
	rke2-tekton-pipelines-manifests-install.service

: "Start network configuration service immediately"
systemctl enable --now rke2-network-config.service

: "Start and wait for the RKE2 installation to complete"
systemctl enable --now rke2-install

: "Load the RKE2 environment"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Expose bind-mounted helper scripts on PATH (strip .sh suffix)"
scripts_dir=${RKE2LAB_SCRIPTS_DIR}
if [ -d "$scripts_dir" ]; then
  for src in "$scripts_dir"/*.sh; do
    [ -f "$src" ] || continue
    base=$(basename "${src%.sh}")
    ln -sf "$src" "/usr/local/sbin/$base"
  done
fi

: "Install and enable remaining systemd services"
rke2-enable-containerd-zfs-mount

: "Start the RKE2 service"
systemctl start --no-block rke2-${RKE2LAB_NODE_KIND}
