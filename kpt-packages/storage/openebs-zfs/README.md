# OpenEBS ZFS CSI Driver

This kpt package deploys the OpenEBS ZFS CSI driver for persistent storage backed by ZFS.

## Components

- **Namespace**: Creates `openebs` namespace
- **HelmChart**: Deploys OpenEBS ZFS LocalPV chart v2.8.0
- **StorageClass**: Configures `openebs-zfs` storage class with WaitForFirstConsumer binding

## Setters

- `poolname`: ZFS pool name (default: `tank`)
- `kubelet-dir`: Kubelet directory for RKE2 (default: `/var/lib/rancher/rke2/agent`)

## Usage

```bash
# Apply setters if needed
kpt fn eval --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  poolname=tank \
  kubelet-dir=/var/lib/rancher/rke2/agent

# Deploy
kpt live init .
kpt live apply .
```

## Dependencies

- ZFS kernel module loaded on all nodes
- ZFS pool created (e.g., `tank`)
- Proper ZFS permissions configured
