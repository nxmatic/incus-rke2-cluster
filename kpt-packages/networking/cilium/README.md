# Cilium Advanced Networking kpt Package

This package deploys Cilium advanced networking features (BGP, L2 announcements, IP pools) for RKE2 clusters. The core CNI HelmChartConfig remains in RKE2 cloud-config for bootstrap.

## Components

- **IP Pools**: LoadBalancer and VIP address pools for Cilium IPAM
  - `load-balancers`: 10.80.8.128/26 (addresses 129-190)
  - `virtual-addresses`: 10.80.15.0/24 (addresses 1-254)
- **L2 Announcements**: ARP-based IP advertisement on vmnet0/lan0 interfaces
- **BGP Configuration**: Peering with gateway router (ASN 65001 ↔ 65000)
- **BGP Advertisement**: Service LoadBalancer IPs and PodCIDR routes

## Architecture

Cilium advanced features provide:

- **LoadBalancer IPAM**: Automatic IP assignment for LoadBalancer services
- **L2 Announcements**: Layer 2 IP advertisement via ARP (vmnet0, lan0)
- **BGP Peering**: Dynamic route exchange with gateway router
- **Service Advertisement**: BGP announcements for LoadBalancer IPs and PodCIDR

## Critical Notes

⚠️ **This is Phase 3a (High Risk) - Networking Core**:

- Affects all cluster networking (LoadBalancer services, BGP routing)
- Core CNI (HelmChartConfig) must remain in RKE2 bootstrap
- Only advanced features migrated to kpt for declarative management
- Requires careful testing with BGP verification and service connectivity

## Prerequisites

1. **Core CNI**: RKE2 HelmChartConfig must deploy Cilium CNI first
2. **BGP Gateway**: Router at 10.80.0.1 with ASN 65000 configured
3. **Network Interfaces**: vmnet0 and lan0 available on control-plane nodes
4. **IP Pool Ranges**: No conflicts with existing network allocations

## Usage

### Deploy with kpt live

⚠️ **CRITICAL**: Core CNI must be running before deploying this package!

```bash
# From inside master container with kpt available
ssh lima-nerd-nixos
incus exec master -- bash
source <( flox activate --dir /var/lib/rancher/rke2 )
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Verify Cilium CNI is running
kubectl get pods -n kube-system -l k8s-app=cilium

# Deploy advanced features
cd /var/lib/incus-rke2-cluster/kpt-packages/networking/cilium
kpt live apply . --reconcile-timeout=2m

# Check status
kpt live status .
```

### Verification

After deployment, verify networking features:

```bash
# Check IP pools
kubectl get ciliumpools

# Check L2 announcement policy
kubectl get ciliuml2announcementpolicies

# Check BGP configuration
kubectl get ciliumbgpclusterconfigs
kubectl get ciliumbgpadvertisements

# Verify BGP peering (requires cilium CLI)
cilium bgp peers

# Test LoadBalancer IP assignment
kubectl create service loadbalancer test-lb --tcp=80:80
kubectl get svc test-lb -o wide
# Should get IP from 10.80.8.129-190 range
kubectl delete svc test-lb

# Check Cilium status
cilium status
```

### BGP Verification

Verify BGP peering with gateway router:

```bash
# Check BGP session state
cilium bgp peers

# Expected output:
# Node           Local AS   Peer AS   Peer Address   Session State   Uptime     ...
# master         65001      65000     10.80.0.1      established     XXm XXs    ...

# On gateway router, check BGP neighbor
# (commands depend on router OS - example for FRR/Bird)
# vtysh -c "show bgp summary"
# birdc show protocols
```

## Configuration

Customize using kpt setters in Kptfile:

- `cluster-name`: Cluster name for identification (default: bioskop-cluster)
- `cluster-id`: Numeric cluster ID (default: 15)
- `lb-pool-cidr`: LoadBalancer IP pool CIDR (default: 10.80.8.128/26)
- `lb-pool-min`: LoadBalancer pool minimum IP (default: 129)
- `lb-pool-max`: LoadBalancer pool maximum IP (default: 190)
- `vip-pool-cidr`: VIP pool CIDR (default: 10.80.15.0/24)
- `vip-pool-min`: VIP pool minimum IP (default: 1)
- `vip-pool-max`: VIP pool maximum IP (default: 254)
- `l2-interface-1`: Primary L2 announcement interface (default: vmnet0)
- `l2-interface-2`: Secondary L2 announcement interface (default: lan0)
- `bgp-local-asn`: Local BGP AS number (default: 65001)
- `bgp-peer-asn`: Peer BGP AS number (default: 65000)
- `node-gateway-ip`: Gateway router IP address (default: 10.80.0.1)

Example:

```bash
kpt fn eval . --image gcr.io/kpt-fn/apply-setters:v0.2 -- \
  bgp-peer-asn=65010 \
  node-gateway-ip=10.80.0.254
```

## Rollback Strategy

If migration causes networking issues:

1. **Quick Rollback**: Delete kpt-managed resources, redeploy from cloud-config
   ```bash
   kpt live destroy /var/lib/incus-rke2-cluster/kpt-packages/networking/cilium
   # RKE2 will recreate resources from cloud-config on next restart
   ```

2. **Restore cloud-config**: Revert cloud-config.master.cilium.yaml changes
   ```bash
   git checkout modules/nixos/incus-rke2-cluster/make.d/cloud-config/cloud-config.master.cilium.yaml
   # Redeploy master container
   ssh lima-nerd-nixos "cd /var/lib/nixos/config/modules/nixos/incus-rke2-cluster && source <(flox activate) && incus stop master --force && incus delete master && make NAME=master start"
   ```

3. **Emergency Access**: If BGP fails, services remain accessible via direct node IPs
   ```bash
   # Access services via NodePort or direct pod IPs
   kubectl get pods -o wide
   kubectl get svc -o wide
   ```

## Deployment Status

### 🎯 Ready for Testing

- Created from cloud-config extraction (Phase 3a migration)
- Core CNI remains in RKE2 HelmChartConfig (safe)
- Advanced features migrated: IP pools, BGP, L2 announcements
- **HIGH RISK**: Requires BGP gateway configuration and careful testing

## Integration

- **Core CNI**: HelmChartConfig in RKE2 deploys Cilium CNI (tunnel/VXLAN mode)
- **IP Pools**: Cilium IPAM assigns LoadBalancer IPs from defined ranges
- **L2 Announcements**: ARP advertisements on vmnet0/lan0 for LoadBalancer IPs
- **BGP**: Dynamic routing to gateway (10.80.0.1) for service reachability
- **Gateway API**: Envoy Gateway depends on LoadBalancer IPAM

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Cilium CNI (RKE2 HelmChartConfig)                           │
│ - Tunnel mode (VXLAN)                                       │
│ - Kube-proxy replacement                                    │
│ - L7 proxy, Hubble, Envoy                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Advanced Features (kpt package)                             │
├─────────────────────────────────────────────────────────────┤
│ IP Pools:                                                   │
│ • LoadBalancer: 10.80.8.129-190 (62 IPs)                  │
│ • VIP: 10.80.15.1-254 (254 IPs)                           │
├─────────────────────────────────────────────────────────────┤
│ L2 Announcements:                                           │
│ • Interfaces: vmnet0, lan0                                  │
│ • ARP-based IP advertisement                                │
├─────────────────────────────────────────────────────────────┤
│ BGP:                                                        │
│ • Local ASN: 65001                                          │
│ • Peer: 10.80.0.1 (ASN 65000)                              │
│ • Advertise: LoadBalancer IPs, PodCIDR                     │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### BGP Session Not Established

```bash
# Check BGP configuration
kubectl get ciliumbgpclusterconfigs -o yaml

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium | grep -i bgp

# Verify gateway router BGP config
# Ensure ASN 65000 and neighbor 10.80.0.X configured
```

### LoadBalancer IP Not Assigned

```bash
# Check IP pools
kubectl get ciliumpools -o yaml

# Check for IP exhaustion
kubectl get svc -A | grep LoadBalancer | wc -l
# Should be < 62 (max pool size)

# Force IP assignment
kubectl annotate svc <service-name> io.cilium/lb-ipam-ips=10.80.8.150
```

### L2 Announcements Not Working

```bash
# Check announcement policy
kubectl get ciliuml2announcementpolicies -o yaml

# Verify interfaces exist on nodes
kubectl get nodes -o wide
ssh <node-ip> ip addr show vmnet0
ssh <node-ip> ip addr show lan0

# Check ARP table on gateway
arp -n | grep 10.80.8
```

## See Also

- Original cloud-config: `make.d/cloud-config/cloud-config.master.cilium.yaml`
- Cilium BGP docs: <https://docs.cilium.io/en/stable/network/bgp-control-plane/>
- Cilium L2 announcements: <https://docs.cilium.io/en/stable/network/l2-announcements/>
- Migration plan: `docs/kpt-migration-plan.adoc`
