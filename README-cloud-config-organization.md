# Cloud Config Reorganization Summary

## 📁 File Structure

The cloud config files have been reorganized into a more logical and maintainable structure:

```
cloud-config.common.yaml         # Base configuration for ALL nodes (masters + agents)
cloud-config.server.yaml         # Shared configuration for ALL control plane nodes
cloud-config.master.yaml         # Master node specific configuration
cloud-config.peer1.yaml          # Peer1 node specific configuration  
cloud-config.peer2.yaml          # Peer2 node specific configuration
cloud-config.agent.yaml          # Agent/worker node configuration
```

## 🎯 Configuration Layering

### Layer 1: Common Base (`cloud-config.common.yaml`)
- System configuration (ZFS, DNS)
- RKE2 & Kubelet base configuration  
- Containerd ZFS snapshotter setup
- Flox environment setup
- Systemd services and scripts
- Shell configurations
- Utility scripts

**Applied to:** ALL nodes (masters, peers, agents)

### Layer 2: Control Plane Shared (`cloud-config.server.yaml`)
- Core RKE2 server configuration
- CNI (Cilium) configuration with BGP
- Shared systemd service overrides
- Pre-start and validation scripts
- Control plane load balancer service

**Applied to:** ALL control plane nodes (master, peer1, peer2)

### Layer 3: Bootstrap Only (`cloud-config.master.yaml`)
- Traefik ingress controller installation
- Envoy Gateway installation job
- OpenEBS ZFS storage provisioner
- Tailscale operator installation

**Applied to:** Master node ONLY during first boot

### Layer 4: Node Specific
- **`cloud-config.peer1.yaml`**: Peer1-specific ETCD, ... configuration  
- **`cloud-config.peer2.yaml`**: Peer2-specific ETCD, ... configuration

**Applied to:** Each individual control plane node

## 🔄 Key Changes Made

### ✅ Moved to Shared Control Plane Config
- Core RKE2 server settings (`core.yaml`, `disable.yaml`)
- Systemd service overrides and dependencies
- Pre-start script with IP change detection and manifest patching
- Cilium validation script (adapted for all control plane nodes)
- Cilium CNI configuration and BGP setup
- Control plane load balancer service

### 🏗️ Moved to Bootstrap-Only Config  
- Traefik HelmChartConfig (bootstrap installs, others inherit)
- Envoy Gateway installation job
- OpenEBS ZFS HelmChart and StorageClass
- Tailscale operator HelmChart and Connector

### 🔒 Kept Node-Specific
- ETCD node names (`master-control-node`, `peer1-control-node`, `peer2-control-node`)
- Node-specific IP configurations
- Advanced ETCD peer configurations (commented/optional)

## 💡 Benefits

1. **Reduced Duplication**: Common configurations are defined once
2. **Clear Separation**: Bootstrap vs. runtime configurations are separate
3. **Easier Maintenance**: Related configurations are grouped logically
4. **Flexible Deployment**: Can compose different combinations for different deployment scenarios
5. **Better Scaling**: Easy to add new peer nodes with just node-specific config

## 🚀 Usage Pattern

For deploying control plane nodes, you would typically use:

**Master Node:**
```bash
# Layer all configurations
- cloud-config.common.yaml
- cloud-config.server.yaml  
- cloud-config.master.yaml
```

**Peer Nodes:**
```bash
# Skip bootstrap components
- cloud-config.common.yaml
- cloud-config.server.yaml
- cloud-config.peer1.yaml  # or peer2.yaml
```

## 🔧 Customization Points

1. **Node Names**: Update ETCD node-name in each peer config
2. **IP Addresses**: Ensure ETCD peer URLs match your network topology
3. **Bootstrap Components**: Modify bootstrap.yaml for different component versions
4. **Cluster Variables**: Use environment variables for cluster-specific settings

## ⚠️ Migration Notes

- The reorganization maintains all functionality while improving structure
- Bootstrap components are now clearly separated from runtime configuration
- Scripts have been adapted to work on all control plane nodes safely
- ETCD configurations are now properly node-specific

This structure provides a solid foundation for managing complex RKE2 deployments with multiple control plane nodes!
