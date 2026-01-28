#!/usr/bin/env -S bash -exu -o pipefail

: "Load the RKE2 environment"
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Generate systemd mount unit for containerd zfs snapshotter"
UNIT=var-lib-rancher-rke2-agent-containerd-io.containerd.snapshotter.v1.zfs.mount
cat <<EOF > /etc/systemd/system/$UNIT
[Unit]
Description=Mount containerd zfs snapshotter directory for RKE2 (ZFS dataset)
DefaultDependencies=no
Before=cloud-init.service
Before=rke2-${RKE2LAB_NODE_KIND}.service

[Mount]
What=tank/rke2/control-nodes/${RKE2LAB_NODE_NAME}/containerd
Where=/var/lib/rancher/rke2/agent/containerd/io.containerd.snapshotter.v1.zfs
Type=zfs
Options=defaults

[Install]
WantedBy=multi-user.target
RequiredBy=rke2-${RKE2LAB_NODE_KIND}.service
EOF

: "Enable the mount unit"
systemctl daemon-reload
systemctl enable "$UNIT"
