#!/usr/bin/env -S bash -exu -o pipefail

: "Configure system-wide DNS"
ln -fs /run/systemd/resolve/resolv.conf /etc/resolv.conf

: "Start and wait for the RKE2 installation to complete"
systemctl enable --now rke2-install

: "Load the RKE2 environment"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Load the RKE2 environment and generate the named units"
"${RKE2LAB_SCRIPTS_DIR:-/.rke2lab/scripts.d}"/rke2-enable-containerd-zfs-mount.sh

: "Expose bind-mounted helper scripts on PATH (strip .sh suffix)"
scripts_dir=${RKE2LAB_SCRIPTS_DIR:-/.rke2lab/scripts.d}
if [ -d "$scripts_dir" ]; then
  for src in "$scripts_dir"/*.sh; do
    [ -f "$src" ] || continue
    base=$(basename "${src%.sh}")
    ln -sf "$src" "/usr/local/sbin/$base"
  done
fi

: "Start the RKE2 service"
systemctl start --no-block rke2-${RKE2LAB_NODE_TYPE}