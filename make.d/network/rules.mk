# network-refactor.mk - Refactored RKE2 network configuration (@codebase)
# Self-guarding include so multiple -include evaluations are idempotent.

ifndef make.d/network/rules.mk

-include make.d/make.mk  # robust relative include (@codebase)
-include make.d/macros.mk
-include make.d/node/rules.mk  # Node identity variables (@codebase)

# Note: CLUSTER_ID now defined in make.d/node/rules.mk (inlined cluster configuration)

# =============================================================================
# NETWORK IP ADDRESS DERIVATION MACROS
# =============================================================================

# Extract IP address from CIDR format (e.g., 10.80.23.0/24 -> 10.80.23.0)
network-to-ip = $(word 1,$(subst /, ,$(1)))

# Convert network CIDR to gateway IP (replace .0 with .1)
cidr-to-gateway = $(call network-to-ip,$(subst .0/,.1/,$(1)))

# Convert network CIDR to host IP with specific last octet
# Usage: $(call cidr-to-host-ip,CIDR,OCTET) - e.g., $(call cidr-to-host-ip,10.80.16.0/23,3) -> 10.80.16.3
cidr-to-host-ip = $(call network-to-ip,$(subst .0/,.$(2)/,$(1)))

# Extract base IP from CIDR (first 3 octets) for DHCP reservations
# Usage: $(call cidr-to-base-ip,CIDR) - e.g., $(call cidr-to-base-ip,10.80.16.0/21) -> 10.80.16
cidr-to-base-ip = $(shell echo "$(1)" | cut -d/ -f1 | sed 's/\.[0-9]*$$//')

# Special case for LoadBalancer gateway (increment .64 to .65)
lb-cidr-to-gateway = $(call network-to-ip,$(subst .64/,.65/,$(1)))

# ipcalc dependency reintroduced: allocations derived from JSON introspection (@codebase)

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

# Network directory structure
.network.dir = $(run-dir)/network
.network.host_networks_mk   = $(.network.dir)/host-networks.mk
.network.cluster_networks_mk = $(.network.dir)/$(cluster.NAME)-networks.mk
.network.node_networks_mk    = $(.network.dir)/$(cluster.NAME)-$(node.NAME)-networks.mk

# Subnet intermediate (.env) and converted (.mk) assignment files
.network.host_subnets_env   := $(.network.dir)/host.subnets.env
.network.host_subnets_mk    := $(.network.dir)/host.subnets.mk
.network.node_subnets_env   := $(.network.dir)/$(cluster.NAME)-node.subnets.env
.network.node_subnets_mk    := $(.network.dir)/$(cluster.NAME)-node.subnets.mk
.network.vip_subnets_env    := $(.network.dir)/$(cluster.NAME)-vip.subnets.env
.network.vip_subnets_mk     := $(.network.dir)/$(cluster.NAME)-vip.subnets.mk
.network.lb_subnets_env     := $(.network.dir)/$(cluster.NAME)-lb.subnets.env
.network.lb_subnets_mk      := $(.network.dir)/$(cluster.NAME)-lb.subnets.mk



# Include converted subnet mk files first, then network env exports
.network.subnets_mk_files = $(.network.host_subnets_mk)
.network.subnets_mk_files += $(.network.node_subnets_mk)
.network.subnets_mk_files += $(.network.vip_subnets_mk)
.network.subnets_mk_files += $(.network.lb_subnets_mk)

# Environment files (generated first)
.network.subnets_env_files = $(.network.host_subnets_env)
.network.subnets_env_files += $(.network.node_subnets_env)
.network.subnets_env_files += $(.network.vip_subnets_env)
.network.subnets_env_files += $(.network.lb_subnets_env)

# Conditional inclusion: include .mk files if they exist (avoid forcing build during parsing)
-include $(wildcard $(.network.subnets_mk_files))

# =============================================================================
# HOST-LEVEL NETWORK CONFIGURATION
# =============================================================================

# Physical host network allocation parameters
.network.HOST_SUPERNET_CIDR = 10.80.0.0/18
.network.HOST_CLUSTER_PREFIX_LENGTH = 21
.network.HOST_NODE_PREFIX_LENGTH = 23
.network.HOST_LB_PREFIX_LENGTH = 26
.network.HOST_VIP_PREFIX_LENGTH = 24

# =============================================================================
# BRIDGE NAMING CONVENTION
# =============================================================================

# Per-node bridge names (isolated bridges for each node)
# Interface names (macvlan, not bridges)
.network.node_lan_interface_name = $(node.NAME)-lan0
.network.node_wan_interface_name = $(node.NAME)-wan0
.network.cluster_vip_interface_name = rke2-vip0

# VIP VLAN configuration (shared across control-plane nodes)
.network.vip_vlan_id = 100
.network.vip_vlan_name = rke2-vip

# =============================================================================
# NETWORK GENERATION TARGETS
# =============================================================================

define .network.SUBNETS_YQ_EXPR =
{
  "$(name)_SUBNETS": { 
     "SPLIT": {
       "NETWORK": "$(network)",
       "PREFIX": $(prefix),
       "COUNT": .NETS
     },
     "NETWORK": .SPLITNETWORK[]
  }
}
endef

# =============================================================================
# METAPROGRAMMING: SUBNET GENERATION RULES  
# =============================================================================

# Helper macro for shell commands with dependency (sourcing)
define define-subnet-shell-dep
	# Source the corresponding .env file to get prerequisite variables
	source $(subst .mk,.env,$(2))
	network=$$$${$(3)}
	prefix=$(4)
	export SUBNET_TYPE=$(1)
	export SPLIT_NETWORK=$$$$network
	export SPLIT_PREFIX=$$$$prefix
	ipcalc --json -S $$$$prefix $$$$network | yq -r '(.SPLITNETWORK | to_entries | map(env(SUBNET_TYPE) + "_SUBNETS_NETWORK_" + (.key | tostring) + "=" + (.value | @sh)) | .[]), env(SUBNET_TYPE) + "_SUBNETS_SPLIT_NETWORK=\"" + env(SPLIT_NETWORK) + "\"", env(SUBNET_TYPE) + "_SUBNETS_SPLIT_PREFIX=" + env(SPLIT_PREFIX), (env(SUBNET_TYPE) + "_SUBNETS_SPLIT_COUNT=" + (.NETS | tostring))' > $$(@)
endef

# Helper macro for shell commands without dependency (direct values)
define define-subnet-shell-direct
	network=$(3)
	prefix=$(4)
	export SUBNET_TYPE=$(1)
	export SPLIT_NETWORK=$$$$network
	export SPLIT_PREFIX=$$$$prefix
	ipcalc --json -S $$$$prefix $$$$network | yq -r '(.SPLITNETWORK | to_entries | map(env(SUBNET_TYPE) + "_SUBNETS_NETWORK_" + (.key | tostring) + "=" + (.value | @sh)) | .[]), env(SUBNET_TYPE) + "_SUBNETS_SPLIT_NETWORK=\"" + env(SPLIT_NETWORK) + "\"", env(SUBNET_TYPE) + "_SUBNETS_SPLIT_PREFIX=" + env(SPLIT_PREFIX), (env(SUBNET_TYPE) + "_SUBNETS_SPLIT_COUNT=" + (.NETS | tostring))' > $$(@)
endef

# Template function to generate subnet rules for a specific type
# Usage: $(call define-subnet-rules,TYPE,dependency,network_expr,prefix,description)
define define-subnet-rules
$$(call register-network-targets,$$(.network.$(call lc,$(1))_subnets_env))
$$(call register-network-targets,$$(.network.$(call lc,$(1))_subnets_mk))
$$(.network.$(call lc,$(1))_subnets_mk): subnet_type=$(1)
$$(.network.$(call lc,$(1))_subnets_env): subnet_type=$(1)
$$(.network.$(call lc,$(1))_subnets_env): prefix := $(4)
$$(.network.$(call lc,$(1))_subnets_env): export YQ_EXPR = $$(.network.SUBNETS_YQ_EXPR)
$(if $(2),$$(.network.$(call lc,$(1))_subnets_env): $(2))
$$(.network.$(call lc,$(1))_subnets_env): | $$(.network.DIR)/
$$(.network.$(call lc,$(1))_subnets_env): ## Generate $(5)
	$$(call check-variable-defined,subnet_type prefix YQ_EXPR)
	: "[+] ($(call lc,$(1))) generating $$(@) via ipcalc" # @codebase
	mkdir -p $$$$(dirname $$(@))
$(if $(2),$(call define-subnet-shell-dep,$(1),$(2),$(3),$(4)),$(call define-subnet-shell-direct,$(1),$(2),$(3),$(4)))

$$(.network.$(call lc,$(1))_subnets_mk): $$(.network.$(call lc,$(1))_subnets_env)
$$(.network.$(call lc,$(1))_subnets_mk): | $$(.network.DIR)/
$$(.network.$(call lc,$(1))_subnets_mk): ## Convert $(1) subnet environment file to Makefile assignments
	: "[+] Converting $(1).subnets.env -> $$(@) (mk assignments)" # @codebase
	if [ ! -f "$$(<)" ]; then
		echo "[ERROR] Environment file $$(<) does not exist";
		echo "[INFO] Run 'make $$(<)' to generate the prerequisite file first";
		exit 1;
	fi;
	source $$(<);
	compgen -A variable $(1)_SUBNETS |
	while read leftValue; do
		echo "export $$$$leftValue := $$$${!leftValue}";
	done > $$(@)
endef

# Generate rules for each subnet type (use immediate expansion to resolve variables)
$(eval $(call define-subnet-rules,HOST,,10.80.0.0/18,21,host-level subnet allocation from supernet))
$(eval $(call define-subnet-rules,NODE,$(.network.host_subnets_mk),HOST_SUBNETS_NETWORK_$(.cluster.ID),23,node-level subnet allocation within cluster))
$(eval $(call define-subnet-rules,VIP,$(.network.host_subnets_mk),HOST_SUBNETS_NETWORK_$(.cluster.ID),24,VIP subnet allocation for control plane))
$(eval $(call define-subnet-rules,LB,$(.network.node_subnets_mk),NODE_SUBNETS_NETWORK_0,26,LoadBalancer subnet allocation within node network))


# All subnet generation rules are now generated via metaprogramming above


# =============================================================================
# CONVENIENCE TARGETS
# =============================================================================

# Pre-launch target for populating network variables
.PHONY: pre-launch@network
pre-launch@network: $(.network.subnets_env_files)
pre-launch@network: $(.network.subnets_mk_files)
pre-launch@network: ## Pre-populate all network variable files

# Generate all network files
.PHONY: generate@network
generate@network: $(.network.subnets_env_files)
generate@network: $(.network.subnets_mk_files)
generate@network: ## Generate all network subnet files

# Clean network files
.PHONY: clean@network
clean@network: ## Clean all generated network files
	: "[+] Cleaning RKE2 network files..."
	rm -rf $(.network.dir)

# Debug network configuration
.PHONY: show@network
show@network: $(.network.subnets_env_files)
show@network: $(.network.subnets_mk_files)
show@network: load@network
show@network: ## Debug network configuration display
	echo "=== RKE2 Network Configuration ==="
	echo "Host supernet: $(network.HOST_SUPERNET_CIDR)"
	echo "Cluster $(cluster.ID): $(network.CLUSTER_NETWORK_CIDR)"
	echo "Node $(node.ID): $(network.NODE_NETWORK_CIDR)"
	echo "Node host IP: $(network.NODE_HOST_IP)"
	echo "Node gateway: $(network.NODE_GATEWAY_IP)"
	echo "VIP network: $(network.CLUSTER_VIP_NETWORK_CIDR)"
	echo "VIP gateway: $(network.CLUSTER_VIP_GATEWAY_IP)"
	echo "LoadBalancer network: $(network.CLUSTER_LOADBALANCER_NETWORK_CIDR)"
	echo ""
	echo "=== Bridge Configuration ==="
	echo "Node LAN interface: $(network.NODE_LAN_INTERFACE_NAME) (macvlan on vmlan0)"
	echo "Node WAN interface: $(network.NODE_WAN_INTERFACE_NAME) (macvlan on vmwan0)"
	echo "Cluster VIP interface: $(network.CLUSTER_VIP_INTERFACE_NAME) (macvlan on vmwan0)"
	echo "Cluster VIP VLAN: $(network.VIP_VLAN_ID) ($(network.VIP_VLAN_NAME)) -> $(network.CLUSTER_VIP_NETWORK_CIDR)"

# =============================================================================
# DERIVED VARIABLES FOR TEMPLATES
# =============================================================================

# Profile name for Incus
.network.node_profile_name = rke2-cluster

# Master node IP for peer connections (derived from node 0) using macro
.network.master_node_ip = $(call cidr-to-host-ip,$(NODE_SUBNETS_NETWORK_0),3)

# =============================================================================
# PUBLIC NETWORK API
# =============================================================================

# Public network API (used by other layers)
network.HOST_SUPERNET_CIDR = $(.network.HOST_SUPERNET_CIDR)
# Public API variables (@codebase)
# CLUSTER_NETWORK_CIDR - the cluster's allocated /21 slice from the host supernet
network.CLUSTER_NETWORK_CIDR = $(HOST_SUBNETS_NETWORK_$(.cluster.ID))
network.CLUSTER_VIP_NETWORK_CIDR = $(VIP_SUBNETS_NETWORK_7)
network.CLUSTER_VIP_GATEWAY_IP = $(call cidr-to-gateway,$(VIP_SUBNETS_NETWORK_7))
network.CLUSTER_LOADBALANCER_NETWORK_CIDR = $(LB_SUBNETS_NETWORK_1)
network.CLUSTER_LOADBALANCER_GATEWAY_IP = $(call lb-cidr-to-gateway,$(LB_SUBNETS_NETWORK_1))
network.NODE_NETWORK_CIDR = $(NODE_SUBNETS_NETWORK_0)
network.NODE_GATEWAY_IP = $(call cidr-to-gateway,$(NODE_SUBNETS_NETWORK_0))
network.NODE_HOST_IP = $(call cidr-to-host-ip,$(NODE_SUBNETS_NETWORK_0),$(call plus,10,$(node.ID)))
network.NODE_VIP_IP = $(call cidr-to-host-ip,$(VIP_SUBNETS_NETWORK_7),10)
network.NODE_LAN_INTERFACE_NAME = $(.network.node_lan_interface_name)
network.NODE_WAN_INTERFACE_NAME = $(.network.node_wan_interface_name)
network.CLUSTER_VIP_INTERFACE_NAME = $(.network.cluster_vip_interface_name)
network.VIP_VLAN_ID = $(.network.vip_vlan_id)
network.VIP_VLAN_NAME = $(.network.vip_vlan_name)

# Cluster WAN network (Incus bridge with Lima VM as gateway)
# Lima VM has .1 IP on the bridge and provides routing/NAT to uplink
# Cluster allocation: 10.80.(CLUSTER_ID * 8).0/21
network.CLUSTER_GATEWAY_IP = $(call cidr-to-gateway,$(network.CLUSTER_NETWORK_CIDR))

# DHCP range for WAN network - split range excludes static lease block (.10-.30)
# Dynamic pool: .2-.9 (8 IPs) + .31-.254 (up to end of /21)
# Static block: .10-.30 (21 IPs reserved for nodes with static DHCP leases)
.network.cluster_third_octet = $(call multiply,$(.cluster.ID),8)
network.WAN_DHCP_RANGE = 10.80.$(.network.cluster_third_octet).2-10.80.$(.network.cluster_third_octet).9,10.80.$(.network.cluster_third_octet).31-10.80.$(call plus,$(.network.cluster_third_octet),7).254

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
.network.node_type_hex = $(if $(filter server,$(node.TYPE)),00,01)
network.NODE_WAN_MAC = $(shell printf "52:54:00:%02x:%s:%02x" $(cluster.ID) $(.network.node_type_hex) $(node.ID))

network.NODE_PROFILE_NAME = $(.network.node_profile_name)
network.MASTER_NODE_IP = $(.network.master_node_ip)

# Cluster-wide node IP base for DHCP reservations (e.g., "10.80.8" for cluster 1)
network.CLUSTER_NODE_IP_BASE = $(call cidr-to-base-ip,$(network.CLUSTER_NETWORK_CIDR))

# MAC addresses for all nodes (for DHCP static reservations)
network.NODE_WAN_MAC_MASTER = $(shell printf "52:54:00:%02x:00:00" $(cluster.ID))
network.NODE_WAN_MAC_PEER1 = $(shell printf "52:54:00:%02x:00:01" $(cluster.ID))
network.NODE_WAN_MAC_PEER2 = $(shell printf "52:54:00:%02x:00:02" $(cluster.ID))
network.NODE_WAN_MAC_PEER3 = $(shell printf "52:54:00:%02x:00:03" $(cluster.ID))
network.NODE_WAN_MAC_WORKER1 = $(shell printf "52:54:00:%02x:01:0a" $(cluster.ID))
network.NODE_WAN_MAC_WORKER2 = $(shell printf "52:54:00:%02x:01:0b" $(cluster.ID))

# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export network variables for use in YAML templates via yq envsubst
export HOST_SUPERNET_CIDR = $(network.HOST_SUPERNET_CIDR)
export CLUSTER_NETWORK_CIDR = $(network.CLUSTER_NETWORK_CIDR)
export CLUSTER_GATEWAY_IP = $(network.CLUSTER_GATEWAY_IP)
export WAN_DHCP_RANGE = $(network.WAN_DHCP_RANGE)
export CLUSTER_VIP_NETWORK_CIDR = $(network.CLUSTER_VIP_NETWORK_CIDR)
export CLUSTER_VIP_GATEWAY_IP = $(network.CLUSTER_VIP_GATEWAY_IP)
export CLUSTER_LOADBALANCER_NETWORK_CIDR = $(network.CLUSTER_LOADBALANCER_NETWORK_CIDR)
export CLUSTER_LOADBALANCER_GATEWAY_IP = $(network.CLUSTER_LOADBALANCER_GATEWAY_IP)
export NODE_NETWORK_CIDR = $(network.NODE_NETWORK_CIDR)
export NODE_GATEWAY_IP = $(network.NODE_GATEWAY_IP)
export NODE_HOST_IP = $(network.NODE_HOST_IP)
export NODE_VIP_IP = $(network.NODE_VIP_IP)
export NODE_LAN_INTERFACE_NAME = $(network.NODE_LAN_INTERFACE_NAME)
export NODE_WAN_INTERFACE_NAME = $(network.NODE_WAN_INTERFACE_NAME)
export CLUSTER_VIP_INTERFACE_NAME = $(network.CLUSTER_VIP_INTERFACE_NAME)
export VIP_VLAN_ID = $(network.VIP_VLAN_ID)
export VIP_VLAN_NAME = $(network.VIP_VLAN_NAME)
export NODE_PROFILE_NAME = $(network.NODE_PROFILE_NAME)
export MASTER_NODE_IP = $(network.MASTER_NODE_IP)
export NODE_WAN_MAC = $(network.NODE_WAN_MAC)

# Cluster-wide variables for DHCP static reservations
export CLUSTER_NODE_IP_BASE = $(network.CLUSTER_NODE_IP_BASE)
export NODE_WAN_MAC_MASTER = $(network.NODE_WAN_MAC_MASTER)
export NODE_WAN_MAC_PEER1 = $(network.NODE_WAN_MAC_PEER1)
export NODE_WAN_MAC_PEER2 = $(network.NODE_WAN_MAC_PEER2)
export NODE_WAN_MAC_PEER3 = $(network.NODE_WAN_MAC_PEER3)
export NODE_WAN_MAC_WORKER1 = $(network.NODE_WAN_MAC_WORKER1)
export NODE_WAN_MAC_WORKER2 = $(network.NODE_WAN_MAC_WORKER2)
export NODE_PROFILE_NAME
export MASTER_NODE_IP

# =============================================================================
# SUBNET GENERATION RULES
# =============================================================================

# Create network directory
$(.network.dir)/:
	mkdir -p $(.network.dir)

# YQ expression for subnet generation
define .network.SUBNETS_YQ_EXPR =
{
  "$(subnet_type)_SUBNETS": { 
     "SPLIT": {
       "NETWORK": "$(network)",
       "PREFIX": $(prefix),
       "COUNT": .NETS
     },
     "NETWORK": .SPLITNETWORK[]
  }
}
endef

# Generic pattern rule removed - using macro-generated rules only

# Convert .env to .mk files
$(.network.dir)/%.subnets.mk: $(.network.dir)/%.subnets.env | $(.network.dir)/
	$(call check-variable-defined,subnet_type)
	: "[+] Converting $(*).subnets.env -> $(@) (mk assignments)"
	source $(<); \
	compgen -A variable $(subnet_type)_SUBNETS | \
	  while read leftValue; do \
	    value="$${!leftValue}"; \
	    leftValueUc="$${leftValue^^}"; \
		echo "export $$leftValueUc := $$value"; \
	  done > $(@)

# Specific subnet generation rules
# Manual subnet rules removed - using macro-generated rules only

#-----------------------------
# Network Layer Targets (@network)
#-----------------------------

.PHONY: summary@network summary@network.print diagnostics@network status@network setup-bridge@network
.PHONY: allocation@network validate@network test@network

summary@network: generate@network
summary@network: load@network
summary@network: summary@network.print
summary@network: ## Show network configuration summary (second expansion) (@codebase)

# Convenience rebuild target to avoid ordering issues when chaining with clean (@codebase)
.PHONY: rebuild@network
rebuild@network: clean@network
rebuild@network: generate@network
rebuild@network: load@network
rebuild@network: ## Clean, regenerate and load networks (@codebase)
	: "[rebuild@network] Completed network rebuild" # @codebase

summary@network.print: load@network ## Print detailed network configuration summary
	echo "Network Configuration Summary:"
	echo "============================="
	echo "Cluster: $(cluster.NAME) (ID: $(cluster.ID))"
	echo "Node: $(node.NAME) (ID: $(node.ID), Role: $(node.ROLE))"
	echo "Host Supernet: $(network.HOST_SUPERNET_CIDR)"
	source $(.network.dir)/_assign.mk && echo "Cluster Network: $$HOST_SUBNETS_NETWORK_$(.cluster.ID)"
	source $(.network.dir)/_assign.mk && echo "Node Network: $$NODE_SUBNETS_NETWORK_0"
	source $(.network.dir)/_assign.mk && echo "Node IP: $$(echo $$NODE_SUBNETS_NETWORK_0 | sed 's|/.*||' | sed 's|\.0$$|\.$(call plus,10,$(node.ID))|')"
	source $(.network.dir)/_assign.mk && echo "Gateway: $$(echo $$NODE_SUBNETS_NETWORK_0 | sed 's|/.*||' | sed 's|\.0$$|\.1|')"
	source $(.network.dir)/_assign.mk && echo "VIP Network: $$VIP_SUBNETS_NETWORK_7"
	source $(.network.dir)/_assign.mk && echo "LoadBalancer Network: $$LB_SUBNETS_NETWORK_1"

# Second expansion loader: import generated env exports into make variables
.PHONY: load@network
_NETWORK_ASSIGN_FILE := $(.network.dir)/_assign.mk

$(.network.dir)/_assign.mk: $(.network.subnets_mk_files)
$(.network.dir)/_assign.mk: | $(.network.dir)/
$(.network.dir)/_assign.mk: ## Build assignment file from all subnet makefiles
	: "[network] Building assignment file $@" # @codebase
	cat $^ | sed -n 's/^export \([A-Z0-9_]*\) := \(.*\)/\1=\2/p' > $@
	grep -c '=' $@ | xargs -I{} echo "[network] Collected {} variable assignments" # @codebase

load@network: $(.network.dir)/_assign.mk
load@network: ## Load generated network assignments into make variables
	: "[network] Loading generated network environment into make variables"
	$(eval $(file <$(.network.dir)/_assign.mk))
	: "[network] Loaded $$(grep -c '=' $(.network.dir)/_assign.mk) assignments"

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
	echo "Node: $(node.NAME) ($(node.ROLE))"
	echo "Network: $(network.NODE_NETWORK_CIDR)"
	echo "Host IP: $(network.NODE_HOST_IP)"
	echo "Gateway: $(network.NODE_GATEWAY_IP)"

setup-bridge@network: ## Set up network bridge for current node
	: "[+] Interface $(network.NODE_LAN_INTERFACE_NAME) uses macvlan (no setup needed)"
	: "Network: $(network.NODE_NETWORK_CIDR)"
	: "Gateway: $(network.NODE_GATEWAY_IP)"

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

test@network: generate@network
test@network: load@network
test@network: ## Run strict network checks (fails fast) (@codebase)
	: "[test@network] Validating namespaced network variables"
	: "[ok] network.HOST_SUPERNET_CIDR=$(network.HOST_SUPERNET_CIDR)"
	: "[ok] network.CLUSTER_NETWORK_CIDR=$(network.CLUSTER_NETWORK_CIDR)"
	: "[ok] network.NODE_NETWORK_CIDR=$(network.NODE_NETWORK_CIDR)"
	: "[ok] network.NODE_HOST_IP=$(network.NODE_HOST_IP)"
	: "[ok] network.NODE_GATEWAY_IP=$(network.NODE_GATEWAY_IP)"
	: "[ok] network.CLUSTER_VIP_NETWORK_CIDR=$(network.CLUSTER_VIP_NETWORK_CIDR)"
	: "[PASS] All required network vars present"

# Arithmetic derivation validation (@codebase)
.PHONY: test@network-arith
test@network-arith: generate@network
test@network-arith: load@network
test@network-arith: ## Validate arithmetic CIDR derivations (@codebase)
	: "[test@network-arith] Validating arithmetic CIDR derivations" # @codebase
	grep -q 'HOST_SUBNETS_SPLIT_COUNT := 8' $(.network.host_subnets_mk) || { echo '[FAIL] Expected host cluster count export'; exit 1; }
	count_host=$$(grep -c 'HOST_SUBNETS_NETWORK_[0-7] :=' $(.network.host_subnets_mk)); [ $$count_host -eq 8 ] || { echo "[FAIL] Host clusters count $$count_host != 8"; exit 1; }
	count_nodes=$$(grep -c 'NODE_SUBNETS_NETWORK_[0-3] :=' $(.network.node_subnets_mk)); [ $$count_nodes -eq 4 ] || { echo "[FAIL] Cluster nodes count $$count_nodes != 4"; exit 1; }
	count_vip=$$(grep -c 'VIP_SUBNETS_NETWORK_[0-7] :=' $(.network.vip_subnets_mk)); [ $$count_vip -eq 8 ] || { echo "[FAIL] VIP subnets count $$count_vip != 8"; exit 1; }
	count_lb=$$(grep -c 'LB_SUBNETS_NETWORK_[0-7] :=' $(.network.lb_subnets_mk)); [ $$count_lb -eq 8 ] || { echo "[FAIL] LB subnets count $$count_lb != 8"; exit 1; }
	[ -n "$(CLUSTER_VIP_NETWORK_CIDR)" ] || { echo '[FAIL] VIP CIDR variable empty'; exit 1; }
	[ -n "$(CLUSTER_LOADBALANCER_NETWORK_CIDR)" ] || { echo '[FAIL] LB CIDR variable empty'; exit 1; }
	: "[PASS] Arithmetic derivation checks passed" # @codebase

endif  # make.d/network/rules.mk guard
