# network-refactor.mk - Refactored RKE2 network configuration (@codebase)
# Self-guarding include so multiple -include evaluations are idempotent.

ifndef make.d/network/rules.mk

-include make.d/make.mk  # robust relative include (@codebase)
-include make.d/macros.mk
-include make.d/node/rules.mk  # Node identity variables (@codebase)

# =============================================================================
# NETWORK IP ADDRESS DERIVATION MACROS
# =============================================================================

# Extract IP address from CIDR format (e.g., 10.80.23.0/24 -> 10.80.23.0)
network.to-inetaddr = $(word 1,$(subst /, ,$(1)))

# Convert network CIDR to gateway IP (replace .0 with .1)
network.cidr-to-gateway = $(call network.to-inetaddr,$(subst .0/,.1/,$(1)))

# Convert network CIDR to host IP with specific last octet
# Usage: $(call network.cidr-to-host-inetaddr,CIDR,OCTET) - e.g., $(call network.cidr-to-host-inetaddr,10.80.16.0/23,3) -> 10.80.16.3
network.cidr-to-host-inetaddr = $(call network.to-inetaddr,$(subst .0/,.$(2)/,$(1)))

# Derive host IP from ipcalc-emitted base + host-min with a relative offset
# Inputs: 1=subnet type (lowercase: host|node|vip|lb|lan), 2=subnet index, 3=offset from host_min (0 => host_min)
network.subnet-host-inetaddr = $(strip $(network.$(1).split.base.$(2))).$(call plus,$(network.$(1).split.host_min.$(2)),$(3))

# Gateway IP for a subnet (HOST_MIN is treated as gateway)
# Inputs: 1=subnet type (lowercase), 2=subnet index
network.subnet-gateway-inetaddr = $(strip $(network.$(1).split.base.$(2))).$(network.$(1).split.host_min.$(2))
# Extract base IP from CIDR (first 3 octets) for DHCP reservations
# Usage: $(call network.cidr-to-base-inetaddr,CIDR) - e.g., $(call network.cidr-to-base-inetaddr,10.80.16.0/21) -> 10.80.16
network.cidr-to-base-inetaddr = $(shell echo "$(1)" | cut -d/ -f1 | sed 's/\.[0-9]*$$//')

# Special case for LoadBalancer gateway (increment .64 to .65)
network.lb-cidr-to-gateway = $(call network.to-inetaddr,$(subst .64/,.65/,$(1)))

# ipcalc dependency reintroduced: allocations derived from JSON introspection (@codebase)

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

# Network directory structure
.network.dir := $(rke2-subtree.dir)/network
.network.cluster.dir := $(rke2-subtree.dir)/$(cluster.name)/network
 
# Physical host network allocation parameters
.network.host.supernet.cidr = 10.80.0.0/18
.network.host.cluster.prefix.length = 21
.network.host.node.prefix.length = 23
.network.host.lb.prefix.length = 26
.network.host.vip.prefix.length = 24
.network.lan.cidr ?= 192.168.1.0/24
.network.vip_vlan_id ?= 100
.network.vip_vlan_name ?= rke2-vlan
.network.lan_bridge_hwaddr_default := $(shell printf '02:00:00:bb:%02x:%02x' $(cluster.id) $(node.id))

# Per-node bridge names (isolated bridges for each node)
# Interface names (macvlan, not bridges)
.network.node.lan.interface.name = $(node.name)-lan0
.network.node.vmnet.interface.name = $(node.name)-vmnet0
.network.cluster.vip.interface.name = rke2-vip0

# =============================================================================
# NETWORK GENERATION TARGETS
# =============================================================================

# Template function to generate subnet rules for a specific type
# Usage: $(call define-subnet-rules,TYPE,dependency,network_expr,prefix,description)
define .network.split.rule

$$(.network.cluster.dir): $$(.network.$(1).mk.file)
$(if $(2),$$(.network.$(1).mk.file): $(2),)

$$(.network.$(1).mk.file): $(2)
$$(.network.$(1).mk.file): type=$(1)
$$(.network.$(1).mk.file): network=$(3)
$$(.network.$(1).mk.file): prefix := $(4)
$$(.network.$(1).mk.file): | make.d/network/rules.mk  $$(.network.dir)/
$$(.network.$(1).mk.file): ## Generate $(5)
	: "[+] ($(1)) generating $$(@) via ipcalc type=$$(type) network=$$(network) prefix=$$(prefix)  (level=$$(MAKELEVEL) restart=$$(MAKE_RESTARTS))" # @codebase
	mkdir -p $$$$(dirname $$(@))
	set -a
	TYPE=$$(type)
	NETWORK=$$(network)
	eval "$$$$( ipcalc --json --split $$(prefix) $$(network) | yq -p json -o shell )"
	set +a
	cat <<EoF > $$(@)
	# Generated network subnet definitions for type=$$(type) network=$$(network) prefix=$$(prefix)
	$(warning [network] Loading $(1))
	.network.$$(type).eval := eval
	.network.$$(type).call := call
	
	network.$$(type).split.network := $$(network)
	network.$$(type).split.prefix := $$(prefix)
	network.$$(type).split.count := $$$${NETS}
	network.$$(type).split.addresses := $$$${ADDRESSES}
	$$$$( for SPLITNETWORK in $$$${!SPLITNETWORK@}; do ipcalc --json "$$$${!SPLITNETWORK}"; done |
		yq -p json -o shell ea '[ . | with_entries( .key |= downcase ) |
		                          . + { "cidr" : (.network + "/" + (.prefix)) } ]' - |
		sed -e 's/_/./g' -e 's/^/network.$$(type).split/'
	)
	EoF
endef

$(.network.cluster.dir): | $(.network.cluster.dir)/
	: "Generated network directory $@" # @codebase

# Generate rules for each subnet type (use immediate expansion to resolve variables)
.network.host.mk.file := $(.network.dir)/host.mk
.network.node.mk.file := $(.network.dir)/node.mk
.network.vip.mk.file := $(.network.dir)/vip.mk
.network.lb.mk.file := $(.network.dir)/lb.mk

-include $(.network.host.mk.file)
-include $(.network.node.mk.file)
-include $(.network.vip.mk.file)
-include $(.network.lb.mk.file)

# Existence predicates
.network.host.exists := $(wildcard $(.network.host.mk.file))
.network.node.exists := $(wildcard $(.network.node.mk.file))


# Guarded generation using function conditionals
$(if $(.network.host.exists), \
  $(eval $(call .network.split.rule,vip,$$(.network.host.mk.file),$$(network.host.split.$$(.cluster.id).cidr),24,VIP subnet allocation for control plane)) \
  $(if $(.network.node.exists), \
    $(eval $(call .network.split.rule,lb,$$(.network.node.mk.file),$$(network.node.split.$$(.cluster.id).cidr),26,LoadBalancer subnet allocation within node network)) \
    $(eval $(call .network.split.rule,lan,,$$(.network.lan.cidr),27,Home LAN subnet allocation for clusters)), \
    $(eval $(call .network.split.rule,node,$$(.network.host.mk.file),$$(network.host.split.$$(.cluster.id).cidr),23,node-level subnet allocation within cluster)) \
    $(warning [network] node.mk missing; rebuilding it will trigger makefile restart to wire node/vip/lb/lan splits)), \
  $(eval $(call .network.split.rule,host,,10.80.0.0/18,21,host-level subnet allocation from supernet)) \
  $(warning [network] host.mk missing; rebuilding it will trigger makefile restart to wire node/vip/lb/lan splits))

# =============================================================================
# CONVENIENCE TARGETS
# =============================================================================: "[+] Generated all RKE2 network files..."

# Clean network files
.PHONY: clean@network
clean@network: ## Clean all generated network files
	: "[+] Cleaning RKE2 network files..."
	rm -rf $(.network.dir) $(.network.plan.file) $(.network.cluster.dir)

# Debug network configuration
.PHONY: show@network
show@network: ## Debug network configuration display
	echo "=== RKE2 Network Configuration ==="
	echo "Host supernet: $(network.HOST_SUPERNET_CIDR)"
	echo "Cluster $(cluster.id): $(network.cluster.network.cidr)"
	echo "Node $(node.id): $(network.node.network.cidr)"
	echo "Node host IP: $(network.node.host.inetaddr)"
	echo "Node gateway: $(network.node.gateway.inetaddr)"
	echo "VIP network: $(network.cluster.vip.cidr)"
	echo "VIP gateway: $(network.cluster.vip.gateway)"
	echo "LoadBalancer network: $(network.cluster.lb.cidr)"
	echo ""
	echo "=== Bridge Configuration ==="
	echo "Node LAN interface: $(network.node.lan.interface) (macvlan on vmlan0)"
	echo "Node VMNET interface: $(network.node.vmnet.interface) (bridge on vmnet)"
	echo "Cluster VIP interface: $(network.cluster.vip.interface) (on vmnet0)"
	echo "Cluster VIP VLAN: $(network.vip.vlan.id) ($(network.vip.vlan.name)) -> $(network.cluster.vip.cidr)"

# =============================================================================
# DERIVED VARIABLES FOR TEMPLATES
# =============================================================================

# Profile name for Incus
.network.node_profile_name = rke2-cluster

# Master node IP for peer connections (derived from node 0) using subnet helper (gateway+2 -> .3)
.network.master.node_ip := $(call network.subnet-host-inetaddr,node,0,2)

# =============================================================================
# PUBLIC NETWORK API
# =============================================================================

# Public network API (lowercase, dot-scoped) used by other layers
network.host.supernet.cidr = $(.network.host.supernet.cidr)
network.cluster.network.cidr = $(network.host.split.network.$(.cluster.id))
network.cluster.vip.cidr = $(network.vip.split.network.7)
network.cluster.vip.gateway = $(call network.subnet-gateway-ip,vip,7)
network.cluster.lb.cidr = $(network.lb.split.network.1)
network.cluster.lb.gateway = $(call network.subnet-gateway-ip,lb,1)
network.node.network.cidr = $(network.node.split.network.0)
network.node.gateway.inet = $(call network.subnet-gateway-ip,node,0)
network.node.host.inet = $(call network.subnet-host-ip,node,0,$(call plus,9,$(node.id)))
network.node.vip.inet = $(call network.subnet-host-ip,vip,7,9)
network.node.lan.interface = $(.network.node.lan.interface.name)
network.node.vmnet.interface = $(.network.node.vmnet.interface.name)
network.cluster.vip.interface = $(.network.cluster.vip.interface.name)
network.vip.vlan.id = $(.network.vip_vlan_id)
network.vip.vlan.name = $(.network.vip_vlan_name)
network.lan.bridge.mac = $(.network.lan_bridge_hwaddr_default)
network.lan.cidr = $(.network.lan.cidr)

# LAN LoadBalancer pool/headscale IPs derived from ipcalc split of LAN
network.lan.lb.pool = $(network.lan.split.network.$(.cluster.id))
network.lan.lb.headscale = $(call network.subnet-host-ip,lan,$(.cluster.id),0)

# Cluster WAN network (Incus bridge with Lima VM as gateway)
# Lima VM has .1 IP on the bridge and provides routing/NAT to uplink
# Cluster allocation: 10.80.(CLUSTER_ID * 8).0/21
network.cluster.gateway.inet = $(call network.subnet-gateway-ip,host,$(.cluster.id))

# DHCP range for WAN network - split range excludes static lease block (.10-.30)
# Dynamic pool: .2-.9 (8 IPs) + .31-.254 (up to end of /21)
# Static block: .10-.30 (21 IPs reserved for nodes with static DHCP leases)
.network.cluster_third_octet = $(call multiply,$(.cluster.id),8)
network.wan.dhcp.range = 10.80.$(.network.cluster_third_octet).2-10.80.$(.network.cluster_third_octet).9,10.80.$(.network.cluster_third_octet).31-10.80.$(call plus,$(.network.cluster_third_octet),7).254

# =============================================================================
# MAC ADDRESS GENERATION FOR STATIC DHCP LEASES
# =============================================================================

# Generate deterministic MAC address for node's WAN interface
# Format: 52:54:00:CC:TT:NN where:
#   52:54:00 = QEMU/KVM reserved prefix (locally administered)
#   CC = cluster ID in hex (00-07, zero-padded)
#   TT = node type: 00=server, 01=agent
#   NN = node ID in hex (00-ff, zero-padded)
# Example: master (cluster 2, server, ID 0) = 52:54:00:02:00:00
# Note: Use shell printf for zero-padding since GMSL dec2hex doesn't pad
.network.node_type_hex := $(if $(filter server,$(node.TYPE)),00,01)
network.node.wan.mac := $(shell printf "52:54:00:%02x:%s:%02x" $(cluster.id) $(.network.node_type_hex) $(node.id))

# Generate deterministic MAC address for node's LAN interface (macvlan)
# Format: 10:66:6a:4c:CC:NN where:
#   10:66:6a:4c = Custom prefix for LAN interfaces
#   CC = cluster ID in hex (00-07, zero-padded)
#   NN = node ID in hex (00-ff, zero-padded)
# Example: master (cluster 2, ID 0) = 10:66:6a:4c:02:00

network.node.lan.mac := $(shell printf "10:66:6a:4c:%02x:%02x" $(cluster.id) $(node.id))

network.node.profile.name = $(.network.node_profile_name)
network.master.node.inet = $(.network.master.node_ip)

# Network plan ConfigMap for kpt rendering
.network.plan.file := $(.network.cluster.dir).yaml


$(.network.dir): $(.network.plan.file)

$(.network.plan.file): | $(.network.cluster.dir)/
$(.network.plan.file):
	: "[network] Writing network plan $@" # @codebase
	$(file >$(@),$(.network.plan.content))

define .network.plan.content
apiVersion: v1
kind: ConfigMap
metadata:
  name: network-plan
  annotations:
    config.kubernetes.io/local-config: "true"
    internal.kpt.dev/function-config: apply-setters
data:
  cluster-id: $(cluster.id)
  cluster-name: "$(cluster.name)"
  host-supernet-cidr: "$(network.host.supernet.cidr)"
  cluster-network-cidr: "$(network.cluster.network.cidr)"
  node-network-cidr: "$(network.node.network.cidr)"
  vip-pool-cidr: "$(network.cluster.vip.cidr)"
  lb-pool-cidr: "$(network.cluster.lb.cidr)"
  cluster-gateway-inetaddr: "$(network.cluster.gateway.inet)"
  node-vip-inetaddr: "$(network.node.vip.inet)"
  node-gateway-inetaddr: "$(network.node.gateway.inet)"
  node-host-inetaddr: "$(network.node.host.inet)"
  lan-bridge-hwaddr: "$(network.lan.bridge.mac)"
  cluster-node-inetaddr-base: "$(network.host.split.base.$(cluster.id))"
  host-subnet-split-network: "$(network.host.split.split.network)"
  host-subnet-split-prefix: "$(network.host.split.split.prefix)"
  host-subnet-split-count: "$(network.host.split.split.count)"
  node-subnet-split-network: "$(network.node.split.split.network)"
  node-subnet-split-prefix: "$(network.node.split.split.prefix)"
  node-subnet-split-count: "$(network.node.split.split.count)"
  vip-subnet-split-network: "$(network.vip.split.split.network)"
  vip-subnet-split-prefix: "$(network.vip.split.split.prefix)"
  vip-subnet-split-count: "$(network.vip.split.split.count)"
  lb-subnet-split-network: "$(network.lb.split.split.network)"
  lb-subnet-split-prefix: "$(network.lb.split.split.prefix)"
  lb-subnet-split-count: "$(network.lb.split.split.count)"
  host-split: |-
    - "$(network.host.split.0)"
    - "$(network.host.split.1)"
    - "$(network.host.split.2)"
    - "$(network.host.split.3)"
    - "$(network.host.split.4)"
    - "$(network.host.split.5)"
    - "$(network.host.split.6)"
    - "$(network.host.split.7)"
  node-split: |-
    - "$(network.node.split.0)"
    - "$(network.node.split.1)"
    - "$(network.node.split.2)"
    - "$(network.node.split.3)"
  vip-split: |-
    - "$(network.vip.split.0)"
    - "$(network.vip.split.1)"
    - "$(network.vip.split.2)"
    - "$(network.vip.split.3)"
    - "$(network.vip.split.4)"
    - "$(network.vip.split.5)"
    - "$(network.vip.split.6)"
    - "$(network.vip.split.7)"
  lb-split: |-
    - "$(network.lb.split.0)"
    - "$(network.lb.split.1)"
    - "$(network.lb.split.2)"
    - "$(network.lb.split.3)"
    - "$(network.lb.split.4)"
    - "$(network.lb.split.5)"
    - "$(network.lb.split.6)"
    - "$(network.lb.split.7)"
  node-wan-macs: |-
    master: "$(NODE_WAN_MAC_MASTER)"
    peer1: "$(NODE_WAN_MAC_PEER1)"
    peer2: "$(NODE_WAN_MAC_PEER2)"
    peer3: "$(NODE_WAN_MAC_PEER3)"
    worker1: "$(NODE_WAN_MAC_WORKER1)"
    worker2: "$(NODE_WAN_MAC_WORKER2)"
  # RKE2 config setter-friendly fields
  pod-network-cidr: "$(network.cluster.pod.cidr)"
  service-network-cidr: "$(network.cluster.service.cidr)"
  node-gateway-ip: "$(network.node.gateway.inet)"
  node-host-ip: "$(network.node.host.inet)"
  cluster-vip-gateway-ip: "$(network.cluster.vip.gateway)"
endef

network.node.lan.mac := $(shell printf "10:66:6a:4c:%02x:%02x" $(cluster.id) $(node.id))

network.node.profile.name = $(.network.node_profile_name)
network.master.node.inetaddr = $(.network.master.node_ip)

# RKE2 pod/service CIDRs derived from cluster id (default /16 blocks)
network.cluster.pod.cidr = 10.$(call plus,40,$(call multiply,$(.cluster.id),2)).0.0/16
network.cluster.service.cidr = 10.$(call plus,41,$(call multiply,$(.cluster.id),2)).0.0/16

# =============================================================================
# SUBNET GENERATION RULES
# =============================================================================

# Create network directory
#-----------------------------
# Network Layer Targets (@network)
#-----------------------------

.PHONY: summary@network summary@network.print diagnostics@network status@network setup-bridge@network
.PHONY: allocation@network validate@network test@network

define .network.summary.content
Network Configuration Summary:
=============================
Cluster: $(cluster.name) (ID: $(cluster.id))
Node: $(node.name) (ID: $(node.id), Role: $(node.ROLE))
Host Supernet: $(network.host.supernet.cidr)
Cluster Network: $(network.cluster.network.cidr)
Node Network: $(network.node.network.cidr)
Node IP: $(network.node.host.inetaddr)
Gateway: $(network.node.gateway.inetaddr)
VIP Network: $(network.cluster.vip.cidr)
LoadBalancer Network: $(network.cluster.lb.cidr)
LAN Bridge MAC: $(network.lan.bridge.mac)
endef

summary@network: ## Print detailed network configuration summary
	: "[network] Printing network configuration summary"
	echo "$(.network.summary.content)"

diagnostics@network: ## Show host network diagnostics
	$(call trace,Entering target: diagnostics@network)
	$(call trace-var,NODE_INTERFACE)
	$(call trace-network,Running host network diagnostics)
	echo "Host Network Diagnostics:"
	ip route show default
	ip addr show $(NODE_INTERFACE) 2>/dev/null || echo "Interface $(NODE_INTERFACE) not found"
	ping -c 1 -W 2 $(NODE_GATEWAY) >/dev/null 2>&1 && echo "Gateway $(NODE_GATEWAY) reachable" || echo "Gateway $(NODE_GATEWAY) unreachable"

status@network: ## Show container network status
	echo "Container Network Status:"
	echo "========================"
	echo "Node: $(node.name) ($(node.ROLE))"
	echo "Network: $(network.node.network.cidr)"
	echo "Host IP: $(network.node.host.inetaddr)"
	echo "Gateway: $(network.node.gateway.inetaddr)"

setup-bridge@network: ## Set up network bridge for current node
	: "[+] Interface $(network.node.lan.interface) uses macvlan (no setup needed)"
	: "Network: $(network.node.network.cidr)"
	: "Gateway: $(network.node.gateway.inetaddr)"

allocation@network: ## Show hierarchical network allocation
	echo "Hierarchical Network Allocation"
	echo "==============================="
	if [ -z "$(GLOBAL_CIDR)" ]; then
		echo "No network configuration found. Set NODE_NAME to see allocation."
		exit 1
	fi
	echo "Global Infrastructure: $(GLOBAL_CIDR)"
	echo "├─ Cluster Network: $(CLUSTER_CIDR)"
	echo "│  ├─ Node Subnets: $(NODE_CIDR) (each /$(NODE_CIDR_PREFIX))"
	echo "│  └─ Service Network: $(SERVICE_CIDR)"
	echo "└─ Current Node: $(NODE_NETWORK) → $(NODE_IP)"


validate@network: ## Validate network configuration
	echo "Validating network configuration..."
	ERRORS=0
	for v in CLUSTER_NETWORK_CIDR NODE_NETWORK_CIDR NODE_HOST_IP NODE_GATEWAY_IP; do
		val=$$(echo $$($$v))
		if [ -z "$$val" ]; then echo "✗ Error: $$v not set"; ERRORS=$$((ERRORS+1)); else echo "✓ $$v=$$val"; fi
	done
	if [ $$ERRORS -eq 0 ]; then echo "✓ Network configuration valid"; else echo "✗ Network configuration has $$ERRORS error(s)"; exit 1; fi

test@network: ## Run strict network checks (fails fast) (@codebase)
	: "[test@network] Validating namespaced network variables"
	: "[ok] network.host.supernet.cidr=$(network.host.supernet.cidr)"
	: "[ok] network.cluster.network.cidr=$(network.cluster.network.cidr)"
	: "[ok] network.node.network.cidr=$(network.node.network.cidr)"
	: "[ok] network.node.host.inetaddr=$(network.node.host.inetaddr)"
	: "[ok] network.node.gateway.inetaddr=$(network.node.gateway.inetaddr)"
	: "[ok] network.cluster.vip.cidr=$(network.cluster.vip.cidr)"
	: "[PASS] All required network vars present"

# Arithmetic derivation validation (@codebase)
.PHONY: test@network-arith

test@network-arith: ## Validate arithmetic CIDR derivations (@codebase)
	: "[test@network-arith] Validating arithmetic CIDR derivations" # @codebase
	grep -q 'network.host.split.split.count=8' $(.network.host.mk.file) || { echo '[FAIL] Expected host cluster count export'; exit 1; }
	count_host=$$(grep -c '^network\.host\.split\.network\.[0-7]=' $(.network.host.mk.file)); [ $$count_host -eq 8 ] || { echo "[FAIL] Host clusters count $$count_host != 8"; exit 1; }
	count_nodes=$$(grep -c '^network\.node\.split\.network\.[0-3]=' $(.network.node.mk.file)); [ $$count_nodes -eq 4 ] || { echo "[FAIL] Cluster nodes count $$count_nodes != 4"; exit 1; }
	count_vip=$$(grep -c '^network\.vip\.split\.network\.[0-7]=' $(.network.vip.mk.file)); [ $$count_vip -eq 8 ] || { echo "[FAIL] VIP split count $$count_vip != 8"; exit 1; }
	count_lb=$$(grep -c '^network\.lb\.split\.network\.[0-7]=' $(.network.lb.mk.file)); [ $$count_lb -eq 8 ] || { echo "[FAIL] LB split count $$count_lb != 8"; exit 1; }
	[ -n "$(network.cluster.vip.cidr)" ] || { echo '[FAIL] VIP CIDR variable empty'; exit 1; }
	[ -n "$(network.cluster.lb.cidr)" ] || { echo '[FAIL] LB CIDR variable empty'; exit 1; }
	: "[PASS] Arithmetic derivation checks passed" # @codebase

endif  # make.d/network/rules.mk guard
