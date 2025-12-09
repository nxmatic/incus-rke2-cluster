# kpt Package Deployment Order

This document defines the correct deployment order for kpt packages due to dependencies between components.

## Deployment Sequence

Deploy packages in this order to satisfy dependencies:

### 1. High Availability (HA)
```bash
cd /var/lib/incus-rke2-cluster/kpt/catalog/ha/kube-vip
kpt live apply . --reconcile-timeout=2m
```

**Purpose**: Control plane VIP (10.80.15.1) must be available before other services that reference it.

**Dependencies**: None (bootstrap component)

**Provides**: 
- Control plane VIP on vmnet0 interface
- Required by: Cilium L2 announcements, Tailscale subnet router

---

### 2. Networking - Cilium Advanced Features
```bash
cd /var/lib/incus-rke2-cluster/kpt/catalog/networking/cilium
kpt live apply . --reconcile-timeout=2m
```

**Purpose**: LoadBalancer IPAM and BGP capabilities for service exposure.

**Dependencies**: 
- Kube-VIP (VIP must exist for L2 announcements)
- Core Cilium CNI (bootstrapped via RKE2)

**Provides**:
- LoadBalancer IP pool (10.80.8.128/26)
- L2 announcements for service IPs
- BGP peering capabilities
- Required by: Services using LoadBalancer type, Tailscale subnet routes

---

### 3. Mesh - Tailscale Operator

**Hybrid Deployment** (operator with kpt, Connector with kubectl):

```bash
cd /var/lib/incus-rke2-cluster/kpt/catalog/mesh/tailscale

# Stage 1: Deploy operator with kpt live
kpt live apply operator/ --reconcile-timeout=3m

# Wait for operator and CRD
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tailscale-operator -n tailscale-system --timeout=180s
kubectl wait --for condition=established crd/connectors.tailscale.com --timeout=60s

# Stage 2: Deploy Connector (cluster-scoped) with kubectl
kubectl apply -f 03-connector.yaml
```

**Purpose**: Tailscale Kubernetes operator for mesh networking and service exposure.

**Dependencies**: 
- Cilium LoadBalancer IPAM (for LoadBalancer pool subnet routing)
- Kube-VIP (for control plane VIP subnet routing)

**Provides**:
- Tailscale operator for cluster mesh access
- Subnet router advertising VIP + LoadBalancer pool
- Required by: Headscale (uses Tailscale operator for service exposure)

**Note**: After initial deployment, all files can be applied at once: `kubectl apply -f .`

---

### 4. Mesh - Headscale
```bash
cd /var/lib/incus-rke2-cluster/kpt/catalog/mesh/headscale
kpt live apply . --reconcile-timeout=3m
```

**Purpose**: Self-hosted Tailscale control server.

**Dependencies**: 
- **Tailscale operator** (Headscale service uses Tailscale for exposure)
- Cilium LoadBalancer IPAM (for LoadBalancer service IP)

**Provides**:
- Self-hosted Tailscale coordination server
- Tailscale mesh control plane
- No dependents currently

---

### 5. Networking - Envoy Gateway
```bash
cd /var/lib/incus-rke2-cluster/kpt/catalog/networking/envoy-gateway
kpt live apply . --reconcile-timeout=3m
```

**Purpose**: Modern API gateway for advanced traffic management.

**Dependencies**: 
- Cilium LoadBalancer IPAM (for Gateway LoadBalancer services)

**Provides**:
- Gateway API implementation
- Advanced routing, TLS termination
- No dependents currently

---

## Dependency Graph

```
┌─────────────────┐
│   Kube-VIP      │ (1. HA - Control Plane VIP)
│   10.80.15.1    │
└────────┬────────┘
         │
         ├──────────────────┐
         │                  │
         ▼                  ▼
┌─────────────────┐  ┌─────────────────┐
│ Cilium Advanced │  │                 │
│ • LoadBalancer  │  │  (VIP routes)   │
│ • L2 Announce   │  │                 │
│ • BGP           │  │                 │
└────────┬────────┘  │                 │
         │           │                 │
         ├───────────┴────────┐        │
         │                    │        │
         ▼                    ▼        ▼
┌─────────────────┐  ┌─────────────────────────┐
│ Envoy Gateway   │  │  Tailscale Operator     │
│ • Gateway API   │  │  • Mesh networking      │
│ • LoadBalancer  │  │  • Subnet router        │
└─────────────────┘  │    (VIP + LB pool)      │
                     └────────┬────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │   Headscale     │
                     │ • Control server│
                     │ • LoadBalancer  │
                     └─────────────────┘
```

## Verification Commands

After each deployment, verify status:

```bash
# Check kpt package status
kpt live status <package-path>

# Check all resources are Current
kubectl get <resources> -n <namespace>

# For LoadBalancer services, verify IP allocation
kubectl get svc -A -o wide | grep LoadBalancer
```

## Quick Deploy All (Correct Order)

For fresh deployments, use this script:

```bash
#!/bin/bash
set -e

PACKAGES=(
  "ha/kube-vip"
  "networking/cilium"
  "mesh/tailscale"
  "mesh/headscale"
  "networking/envoy-gateway"
)

for pkg in "${PACKAGES[@]}"; do
  echo "==> Deploying $pkg..."
  cd "/var/lib/incus-rke2-cluster/kpt/catalog/$pkg"
  kpt live apply . --reconcile-timeout=3m
  
  echo "==> Checking status..."
  kpt live status .
  echo ""
done

echo "==> All packages deployed!"
```

## Rollback Order

For rollback, reverse the order:

1. Envoy Gateway
2. Headscale  
3. Tailscale operator
4. Cilium advanced features
5. Kube-VIP (only if completely removing cluster)

## Troubleshooting Dependencies

### Tailscale operator fails to start
- **Check**: Kube-VIP VIP is up: `ip addr show vmnet0 | grep 10.80.15.1`
- **Check**: Cilium LoadBalancer pool exists: `kubectl get ciliumloadbalancerippools`

### Headscale service has no EXTERNAL-IP
- **Check**: Cilium IPAM working: `kubectl get svc -n headscale headscale`
- **Check**: Tailscale operator running: `kubectl get pods -n tailscale-system`

### Envoy Gateway LoadBalancers pending
- **Check**: Cilium IPAM pool has available IPs: `kubectl get ciliumloadbalancerippools -o yaml`

## See Also

- Individual package READMEs for component-specific details
- Migration plan: `docs/kpt-migration-plan.adoc`
- Cloud-config: `make.d/cloud-config/cloud-config.master.base.yaml`
