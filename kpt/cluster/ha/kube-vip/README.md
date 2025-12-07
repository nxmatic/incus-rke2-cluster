# Kube-VIP kpt Package

This package deploys Kube-VIP for high-availability Kubernetes API server VIP management in RKE2 clusters.

## Components

- **Namespace**: `kube-vip` for all Kube-VIP components
- **DaemonSet**: Runs on control-plane nodes for VIP management
- **VIP Configuration**: Manages Kubernetes API server virtual IP
  - bioskop: `10.80.15.1` (CLUSTER_VIP_GATEWAY_IP)
  - alcide: `10.80.23.1` (CLUSTER_VIP_GATEWAY_IP)
  - Interface: `vmnet0` (cluster network)
  - ARP-based failover with leader election
- **Backup NodePort**: `30443` for emergency access if VIP fails

## Architecture

Kube-VIP provides:
- **HA Control Plane**: Virtual IP for Kubernetes API server
- **Leader Election**: Automatic failover between control-plane nodes
- **ARP Advertisement**: Layer 2 VIP announcement
- **Independent of Cilium**: Avoids IPAM conflicts with LoadBalancer

## Critical Notes

⚠️ **This is a Phase 2 (Medium Risk) component**:
- Manages control plane VIP - cluster access depends on it
- Must not cause API server interruption during migration
- Requires testing on non-production cluster first
- Rollback plan: Redeploy from cloud-config if issues occur

## Usage

### Deploy with kpt live (⚠️ Use with caution)

**IMPORTANT**: Test on non-production cluster first!

```bash
# From inside master container with kpt available
ssh lima-nerd-nixos
incus exec master -- bash
source <( flox activate --dir /var/lib/rancher/rke2 )
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Deploy with kpt live (adopts existing resources)
cd /var/lib/incus-rke2-cluster/kpt/cluster/ha/kube-vip
kpt live apply . --inventory-policy=adopt --reconcile-timeout=2m

# Check status
kpt live status .

# Verify VIP is responding
curl -k https://10.80.15.1:6443/healthz
```

**Note**: The `--inventory-policy=adopt` flag is required on first apply to take ownership of existing Kube-VIP resources deployed via RKE2 manifests.

### Verification

After deployment, verify:

```bash
# Check Kube-VIP pods
kubectl get pods -n kube-vip

# Check VIP address
kubectl get ds -n kube-vip kube-vip-ds -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="address")].value}'

# Test VIP connectivity
curl -k https://10.80.15.1:6443/healthz

# Check backup NodePort
kubectl get svc -n kube-system control-plane-nodeport

# View Kube-VIP logs
kubectl logs -n kube-vip -l app=kube-vip
```

## Configuration

Customize using kpt setters in Kptfile:

- `kube-vip-version`: Kube-VIP image version (default: v0.8.7)
- `cluster-vip-address`: Virtual IP address (default: 10.80.15.1)
- `cluster-vip-interface`: Network interface for VIP (default: vmnet0)
- `kube-vip-namespace`: Namespace for Kube-VIP components (default: kube-vip)

Example:

```bash
kpt fn eval . --image ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2 -- \
  cluster-vip-address=10.80.15.10
```

## Rollback Strategy

If migration causes issues:

1. **Quick Rollback**: Delete kpt-managed resources, RKE2 will recreate from manifests
   ```bash
   kpt live destroy /var/lib/incus-rke2-cluster/kpt/cluster/ha/kube-vip
   kubectl delete -f /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
   kubectl apply -f /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
   ```

2. **Full Rollback**: Restore cloud-config and redeploy container
   ```bash
   # Revert changes to cloud-config.master.kube-vip.yaml
   # Redeploy master container
   make NAME=master stop && make NAME=master start
   ```

3. **Emergency Access**: Use NodePort if VIP is down
   ```bash
   export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
   # Access via node IP + NodePort 30443
   kubectl --server=https://<node-ip>:30443 get nodes
   ```

## Deployment Status

### 🎯 Ready for Testing

- Created from cloud-config extraction (Phase 2 migration)
- Currently deployed via RKE2 manifests
- **Requires testing on non-production before bioskop**
- Medium risk - affects control plane accessibility

## Integration

- **RKE2**: API server configured to use VIP address
- **kubectl**: KUBECONFIG points to VIP address
- **HA**: Automatic failover between control-plane nodes
- **Independent**: No Cilium LoadBalancer IPAM dependency

## Prerequisites

1. **Control Plane Nodes**: Labeled with `node-role.kubernetes.io/control-plane`
2. **Network**: vmnet0 interface available on all control-plane nodes
3. **VIP Address**: Must be in same subnet as node IPs
4. **No IP Conflict**: VIP address not used by other services

## See Also

- Original cloud-config: `make.d/cloud-config/cloud-config.master.kube-vip.yaml`
- Kube-VIP docs: <https://kube-vip.io/>
- Migration plan: `docs/kpt-migration-plan.adoc`
