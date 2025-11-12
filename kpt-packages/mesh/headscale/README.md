# Headscale kpt Package

This package deploys Headscale server for Tailscale-compatible mesh networking in RKE2 clusters.

## Components

- **Namespace**: `headscale` namespace for all components
- **LoadBalancer IP Pool**: Cilium L2 IP pool for home LAN access (192.168.1.192/27)
- **ConfigMaps**: Headscale configuration, ACL policy, DERP map
- **Server Deployment**: Headscale server with LoadBalancer service
- **Bootstrap Job**: Creates admin user and preauth key (in cloud-config, not kpt yet)
- **Client DaemonSet**: Tailscale client on control-plane nodes (in cloud-config, not kpt yet)

## Usage

### Deploy with kpt

```bash
# Fetch the package
kpt pkg get /path/to/kpt-packages/mesh/headscale ./headscale-local

# Customize settings (optional)
kpt fn eval headscale-local --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  headscale-version=0.27.0 \
  cluster-name=bioskop \
  headscale-lb-ip=192.168.1.193

# Render and validate
kpt fn render headscale-local

# Deploy to cluster
kpt live init headscale-local
kpt live apply headscale-local --reconcile-timeout=2m
```

### Deploy with kubectl

```bash
# Render to stdout
kpt fn render /path/to/kpt-packages/mesh/headscale

# Apply directly
kpt fn render /path/to/kpt-packages/mesh/headscale | kubectl apply -f -
```

## Configuration

Customize using kpt setters in Kptfile:

- `headscale-version`: Headscale container image version (default: 0.27.0)
- `cluster-name`: Cluster name for hostname tagging (default: bioskop)
- `home-lan-pool`: CIDR block for LoadBalancer IP pool (default: 192.168.1.192/27)
- `headscale-lb-ip`: LoadBalancer IP for Headscale service (default: 192.168.1.193)

## Notes

- This is a **learning example** showing how to migrate from cloud-config to kpt
- Currently only server deployment is included
- Bootstrap job and client DaemonSet remain in cloud-config for now
- NOT deployed to cluster yet - this is preparation work only

## See Also

- Original cloud-config: `make.d/cloud-config/cloud-config.master.headscale.yaml`
- kpt documentation: https://kpt.dev/
- Migration plan: `docs/kpt-migration-plan.adoc`
