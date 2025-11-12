# Headscale kpt Package

This package deploys Headscale server for Tailscale-compatible mesh networking in RKE2 clusters.

## Components

- **Namespace**: `headscale` namespace for all components
- **LoadBalancer IP Pool**: Cilium L2 IP pool for home LAN access
  - bioskop: `192.168.1.192/27` (first IP: `192.168.1.193`)
  - alcide: `192.168.1.64/27` (first IP: `192.168.1.65`)
- **ConfigMaps**: Headscale configuration, ACL policy, DERP map
  - DNS: Uses `.lan` domain from bbox router
  - MagicDNS enabled for hostname resolution within mesh
- **Server Deployment**: Headscale server with LoadBalancer service
  - Tailscale operator provides TLS termination (external access)
  - Internal clients use HTTP ClusterIP
- **Bootstrap Job**: Creates admin user and generates reusable preauth key
- **Client DaemonSet**: Joins control-plane nodes to Headscale mesh
  - Hostname format: `${DARWIN_HOST}-${NODE_NAME}`
  - Uses internal HTTP URL for registration

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

### Deploy with kubectl (Current Method)

```bash
# From inside master container (mounted at /var/lib/incus-rke2-cluster)
ssh lima-nerd-nixos "incus exec master -- flox activate --dir /var/lib/rancher/rke2 -- kubectl apply -f /var/lib/incus-rke2-cluster/kpt-packages/mesh/headscale/"

# Or from Lima VM
ssh lima-nerd-nixos
incus exec master -- flox activate --dir /var/lib/rancher/rke2 -- kubectl apply -f /var/lib/incus-rke2-cluster/kpt-packages/mesh/headscale/

# Verify deployment
kubectl get pods -n headscale
kubectl get svc -n headscale
```

**Note:** `kpt live apply` has initialization detection issues with virtiofs mounts, so direct `kubectl apply` is used instead.

## Configuration

Customize using kpt setters in Kptfile:

- `headscale-version`: Headscale container image version (default: 0.27.0)
- `cluster-name`: Cluster name for hostname tagging (default: bioskop)
- `home-lan-pool`: LoadBalancer IP pool CIDR (bioskop: 192.168.1.192/27, alcide: 192.168.1.64/27)
- `headscale-lb-ip`: First usable IP from pool (bioskop: 192.168.1.193, alcide: 192.168.1.65)
- `home-lan-pool`: CIDR block for LoadBalancer IP pool (default: 192.168.1.192/27)
- `headscale-lb-ip`: LoadBalancer IP for Headscale service (default: 192.168.1.193)

## Deployment Status

### ✅ Completed on alcide

- Deployed and operational on alcide cluster
- LoadBalancer IP: `192.168.1.192` (using bioskop's pool - to be migrated)
- Server: Running with `.lan` DNS configuration
- Bootstrap: Completed (admin user + preauth key in Secret)
- Client: 1 node registered (`alcide-master-control-node`)

### 🎯 Planned for bioskop

- Target LoadBalancer IP: `192.168.1.193`
- Will become permanent Headscale control plane
- alcide will migrate to client-only mode
- See: `docs/sessions/2025-11-12-bioskop-headscale-deployment.adoc`

## Prerequisites for bioskop Deployment

1. **Lima VM**: Configured with bridged networking (vmlan0/vmlan1)
2. **RKE2 Cluster**: Master node deployed via `make NAME=master start`
3. **Mount**: `/var/lib/incus-rke2-cluster` accessible in master container
4. **Network**: bioskop on home LAN (192.168.1.x) with bbox router

## See Also

- Original cloud-config: `make.d/cloud-config/cloud-config.master.headscale.yaml`
- kpt documentation: https://kpt.dev/
- Migration plan: `docs/kpt-migration-plan.adoc`
