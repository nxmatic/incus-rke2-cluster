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

## 🌐 Networking Modes (New)

Two topology strategies are now supported via the `NETWORK_MODE` Make variable:

- `per-node` (default): Each control-plane node gets its own bridge (`rke2-<name>-br`) and profile. Matches original design and keeps per-node dnsmasq zones isolated.
- `shared`: All control-plane nodes share a single bridge (`rke2-shared-br`) and profile (`rke2-shared`). This reduces nftables churn and simplifies debugging of outbound egress, at the cost of fewer isolation boundaries.

Set at invocation time:

```
make NETWORK_MODE=shared NAME=master start
make NETWORK_MODE=shared NAME=peer1 start
```

Idempotency: In shared mode the preseed step only initializes Incus once; subsequent node brings skip `incus admin init` when the shared bridge already exists.

## ✅ Preflight Network Diagnostics

Before starting additional control-plane nodes (especially when reproducing egress issues) run:

```
./scripts/preflight-network.sh
```

It performs:
- DNS resolution checks
- Raw TCP connect timing (port 443 common registries)
- Minimal HTTPS curl probes
- nftables postrouting excerpt
- Conntrack entry counts

If failures are detected, address them (e.g., flush conntrack, verify MASQUERADE rules) prior to `make start` to avoid cascading Cilium image pull timeouts.

## 🧬 Minimal Cilium Configuration Option

For rapid bring‑up or when troubleshooting networking, a trimmed Cilium HelmChartConfig template is provided: `rke2-cilium-config-minimal.yaml.tmpl`.

Key differences from the full feature set:
- Disables BGP control plane, clustermesh, Envoy, Gateway API, ingress controller
- Keeps Hubble relay (CLI status) but removes UI
- Turns off L2 announcements & neighbor discovery initially
- Partial kube‑proxy replacement (simpler datapath)
- Disables L7 proxying, host firewall, encryption

To activate, copy or template it as the runtime manifest before RKE2 starts (e.g. place or render to `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml`). The master bootstrap file `rke2-cilium-config.yaml.tmpl` can be swapped out or gated by an environment variable enhancement (future improvement idea).

### NEW: CILIUM_PROFILE Selection

Profiles are now auto-selected on the master node via `CILIUM_PROFILE` (default: `full`). The Makefile injects `environment.CILIUM_PROFILE` and a systemd pre-start script renders:

- `full` → `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.full.yaml.tmpl`
- `minimal` → `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.minimal.yaml.tmpl`

Usage examples:

```
make NETWORK_MODE=shared CILIUM_PROFILE=minimal NAME=master start
make NETWORK_MODE=shared CILIUM_PROFILE=minimal NAME=peer1 start
```

Once stable you can rebuild with `CILIUM_PROFILE=full` to enable BGP, ingress controller, Envoy, L2 announcements, etc. Peers inherit whichever manifest was rendered by the master.

## 🔄 Migration Path to Shared Mode

1. Stop existing instances: `make NAME=peer1 stop` etc.
2. Clean per-node artifacts (optional) or reuse: `make clean-all`.
3. Recreate master with `NETWORK_MODE=shared`.
4. Launch peers with the same `NETWORK_MODE` value.
5. (Optional) Transition to full Cilium features by restoring the original HelmChartConfig once stability verified.

## 📝 Future Enhancements

- Gate selection of minimal vs full Cilium config via `CILIUM_PROFILE` variable.
- Automated post-flight script to diff nftables & conntrack before/after peer addition.
- Optional image pre-pull/cache step for hardened CNI plugin images.

## 🧪 New Diagnostics & Profile Controls (Added)

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/analyze-cilium-sysdump.sh` | Summarize / diff two Cilium sysdump archives (now warns if L7 proxy active with kube-proxy replacement disabled). |
| `scripts/diagnostics-cilium-egress.sh` | Original lightweight on-demand snapshot for egress issues. |
| `scripts/diagnostics-cilium-egress-extended.sh` | Extended capture: iptables, ip rules, Cilium maps, policies, fqdn cache, conntrack, optional pod curl. |
| `scripts/preflight-network.sh` | Pre-node-add checks (DNS, HTTPS reachability, nftables/conntrack). |
| `scripts/minimal-cilium-profile-snippet.yaml` | YAML values fragment enforcing deterministic minimal profile (L7 proxy, Hubble, DNS proxy off). |

### Minimal Profile Enforcement

The earlier “minimal” mode could still end up with `EnableL7Proxy=true` if implicit chart defaults enabled any Envoy-dependent feature. To guarantee a lean datapath:

1. Merge `scripts/minimal-cilium-profile-snippet.yaml` into the rendered `rke2-cilium-config.minimal` HelmChartConfig values.
2. Confirm after restart:
	 - `cilium status | grep EnableL7Proxy` → `false`
	 - No `envoy` process inside Cilium pods.

### Extended Diagnostics Usage

Run a comprehensive capture (optionally targeting a DNS pod for test curl):

```
./scripts/diagnostics-cilium-egress-extended.sh \
	--namespace kube-system \
	--pod-selector k8s-app=coredns \
	--curl-host https://example.com
```

Artifacts land under `.logs.d/diag-<timestamp>/` including a synthesized `SUMMARY.txt` with L7/KPR flags and Envoy presence.

### Analyzer Improvements

`analyze-cilium-sysdump.sh` now:
- Produces accurate LB frontend/backend counts
- Emits a warning line if L7 proxy is enabled while kube-proxy replacement is off (common unintended combo in test clusters)
- Marks empty LB diff sections explicitly

### Next Ideas

- Auto-attach iptables & conntrack diffs into sysdump analyzer when provided as auxiliary files.
- Add heuristic warnings for: zero endpoints, absent NAT map with iptables masquerade mismatch, MTU disparities between `eth0` and `cilium_vxlan`.

---
@codebase

## 🧩 Profile Refactor (Base + Overlays)

To remove complexity and runtime mutation, the master cloud-config is now split:

Files:
1. `cloud-config.master.base.yaml` – Core master bootstrap (Traefik, OpenEBS, Tailscale, control-plane LB Service, validation script). No Cilium profile manifests and no Envoy Gateway now.
2. `cloud-config.master.cilium-full.yaml` – Full-feature Cilium (BGP, Envoy, Gateway API, Ingress Controller, Hubble Relay + UI, L7 proxy, cluster resources CRDs, Envoy Gateway manifest).
3. `cloud-config.master.cilium-minimal.yaml` – Strict minimal Cilium (no Envoy, no Hubble, no BGP CRDs, no L7, no gateway/ingress, socket LB off).

Removed: legacy `cloud-config.master.yaml` and profile selector script.

The previous in-file profile selector script (`rke2-cilium-profile-select`) and dual template approach are deprecated. Each overlay writes a canonical `rke2-cilium-config.yaml.tmpl`, so only one Cilium HelmChartConfig manifests at provision time and no pruning step is required.

### Using the overlays

### Automatic composition via Makefile

The Makefile now auto-composes the user-data before instance init:

```
make CILIUM_PROFILE=minimal NAME=master start
make CILIUM_PROFILE=full NAME=master start
```

Internally it concatenates `cloud-config.master.base.yaml` with the selected overlay into `.run.d/<name>/nocloud/userdata.yaml`.

Then feed the composed file to the instance creation or the NoCloud seed.

### Rationale
- Eliminates runtime mutation & yq pruning.
- Avoids surprises with implicit L7 enablement.
- Isolates BGP/advanced features to full overlay; minimal overlay produces deterministic lean datapath.

### Validation Checklist
Minimal:
```
kubectl -n kube-system exec ds/cilium -- cilium config view | grep -E 'EnableL7Proxy|KubeProxyReplacement'
```
Expect: `EnableL7Proxy: false`, `KubeProxyReplacement: false`.

Full:
```
kubectl -n kube-system exec ds/cilium -- cilium status | grep -E 'Hubble|L7'
```
Expect Hubble OK and L7 proxy enabled.

### Migration Notes
- Old in-node selector & dual templates removed.
- Any automation that previously depended on modifying files inside the node should now rely on `CILIUM_PROFILE` at compose time.
- Envoy Gateway installs only with the full overlay.


---
@codebase
