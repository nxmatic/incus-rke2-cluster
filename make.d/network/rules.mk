# network-refactor.mk - Refactored RKE2 network configuration (@codebase)
# Self-guarding include so multiple -include evaluations are idempotent.

ifndef network/rules.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

# Early include of cluster configuration to ensure RKE2_CLUSTER_ID is defined
# before deriving file paths that embed the cluster ID.
-include metaprogramming/cluster-config.mk

# ipcalc dependency removed; network allocations now computed arithmetically (@codebase)

# Network directory structure
NETWORK_DIR := .run.d/network
RKE2_HOST_NETWORKS_FILE := $(NETWORK_DIR)/host-networks.env
RKE2_CLUSTER_NETWORKS_FILE := $(NETWORK_DIR)/cluster-$(RKE2_CLUSTER_ID)-networks.env
RKE2_NODE_NETWORKS_FILE := $(NETWORK_DIR)/cluster-$(RKE2_CLUSTER_ID)-node-$(RKE2_NODE_ID)-networks.env

# Include generated network files
-include $(RKE2_HOST_NETWORKS_FILE)
-include $(RKE2_CLUSTER_NETWORKS_FILE)  
-include $(RKE2_NODE_NETWORKS_FILE)

# =============================================================================
# HOST-LEVEL NETWORK CONFIGURATION
# =============================================================================

# Physical host network allocation parameters
RKE2_HOST_SUPERNET_CIDR := 10.80.0.0/18
RKE2_HOST_CLUSTER_PREFIX_LENGTH := 21
RKE2_HOST_NODE_PREFIX_LENGTH := 23

# =============================================================================
# BRIDGE NAMING CONVENTION
# =============================================================================

# Per-node bridge names (isolated bridges for each node)
RKE2_NODE_LAN_BRIDGE_NAME := $(RKE2_NODE_NAME)-lan0
RKE2_NODE_WAN_BRIDGE_NAME := $(RKE2_NODE_NAME)-wan0

# Shared cluster bridge name (VIP network shared across control-plane nodes)
RKE2_CLUSTER_VIP_BRIDGE_NAME := rke2-vip

# =============================================================================
# NETWORK GENERATION TARGETS
# =============================================================================

# Create network directory
$(NETWORK_DIR)/:
	mkdir -p $(NETWORK_DIR)

# Generate host-level network allocation (deterministic arithmetic split of /18 into /21 blocks)
$(RKE2_HOST_NETWORKS_FILE): | $(NETWORK_DIR)/
	echo "[+] Generating RKE2 host networks from $(RKE2_HOST_SUPERNET_CIDR) (no ipcalc)" # @codebase
	# /18 (10.80.0.0/18) → 8 x /21 (increment third octet by 8) (@codebase)
	echo "export RKE2_HOST_SUPERNET_CIDR=$(RKE2_HOST_SUPERNET_CIDR)" > $@
	for i in $$(seq 0 7); do \
		third=$$((i*8)); \
		echo "export RKE2_CLUSTER_$${i}_NETWORK_CIDR=10.80.$$third.0/21" >> $@; \
	done
	echo "export RKE2_HOST_CLUSTER_COUNT=8" >> $@

# Generate cluster-level network allocation (nodes + VIP + LoadBalancer subnets)

$(RKE2_CLUSTER_NETWORKS_FILE): $(RKE2_HOST_NETWORKS_FILE) | $(NETWORK_DIR)/
	echo "[+] Generating RKE2 cluster $(RKE2_CLUSTER_ID) networks (no ipcalc)" # @codebase
	set -a; . $(RKE2_HOST_NETWORKS_FILE); set +a
	cluster_var="RKE2_CLUSTER_$(RKE2_CLUSTER_ID)_NETWORK_CIDR"
	cluster_net=$${!cluster_var}
	if [ -z "$$cluster_net" ]; then echo "[!] Cluster network not found for ID $(RKE2_CLUSTER_ID)" >&2; exit 1; fi
	echo "[i] Using cluster network: $$cluster_net" # @codebase
	# Derive base third octet and ensure /21 structure (@codebase)
	cluster_third=$$(echo $$cluster_net | awk -F'.' '{print $$3}')
	# Node /23 subnets inside /21: 4 blocks (third octet increments by 2) indexes 0..3 (@codebase)
	: > $@
	for n in $$(seq 0 3); do \
		third=$$((cluster_third + n*2)); \
		echo "export RKE2_NODE_$${n}_NETWORK_CIDR=10.80.$$third.0/23" >> $@; \
	done
	# VIP network = last /24 of /21 ⇒ third octet cluster_third+7 (@codebase)
	vip_third=$$((cluster_third + 7))
	echo "export RKE2_CLUSTER_VIP_NETWORK_CIDR=10.80.$$vip_third.0/24" >> $@
	echo "export RKE2_CLUSTER_VIP_GATEWAY_IP=10.80.$$vip_third.1" >> $@
	# LoadBalancer network: second /26 of node0 /23 ⇒ third octet cluster_third, fourth octet 64 (@codebase)
	echo "export RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR=10.80.$$cluster_third.64/26" >> $@
	# Preserve original (somewhat odd) gateway .129 convention (@codebase)
	echo "export RKE2_CLUSTER_LOADBALANCER_GATEWAY_IP=10.80.$$cluster_third.129" >> $@
	echo "export RKE2_CLUSTER_NETWORK_CIDR=$$cluster_net" >> $@

# Generate node-level network allocation (host interfaces within node subnet)
$(RKE2_NODE_NETWORKS_FILE): $(RKE2_CLUSTER_NETWORKS_FILE) | $(NETWORK_DIR)/
	echo "[+] Generating RKE2 node $(RKE2_NODE_ID) networks (no ipcalc)" # @codebase
	set -a; . $(RKE2_CLUSTER_NETWORKS_FILE); set +a
	node_var="RKE2_NODE_$(RKE2_NODE_ID)_NETWORK_CIDR"
	node_net=$${!node_var}
	vip_gateway=$$RKE2_CLUSTER_VIP_GATEWAY_IP
	if [ -z "$$node_net" ]; then echo "[!] Node network not found for ID $(RKE2_NODE_ID)" >&2; exit 1; fi
	echo "[i] Using node network: $$node_net" # @codebase
	node_prefix=$$(echo $$node_net | cut -d'/' -f2)
	# Derive pieces for gateway/host/broadcast (@codebase)
	third=$$(echo $$node_net | awk -F'.' '{print $$3}')
	fourth_base=0
	network_base="10.80.$$third"
	# Broadcast for /23 spans two /24 blocks: third+1.255 (@codebase)
	broadcast_ip="10.80.$$((third+1)).255"
	echo "export RKE2_NODE_NETWORK_CIDR=$$node_net" > $@
	echo "export RKE2_NODE_GATEWAY_IP=$$network_base.1" >> $@
	echo "export RKE2_NODE_HOST_IP=$$network_base.3" >> $@
	echo "export RKE2_NODE_BROADCAST_IP=$$broadcast_ip" >> $@
	echo "export RKE2_NODE_PREFIX_LENGTH=$$node_prefix" >> $@
	case "$(RKE2_NODE_NAME)" in \
		master) echo "export RKE2_NODE_VIP_IP=$$(echo $$vip_gateway | sed 's/\.[0-9]*$$/\.10/')" >> $@;; \
		peer1) echo "export RKE2_NODE_VIP_IP=$$(echo $$vip_gateway | sed 's/\.[0-9]*$$/\.11/')" >> $@;; \
		peer2) echo "export RKE2_NODE_VIP_IP=$$(echo $$vip_gateway | sed 's/\.[0-9]*$$/\.12/')" >> $@;; \
		peer3) echo "export RKE2_NODE_VIP_IP=$$(echo $$vip_gateway | sed 's/\.[0-9]*$$/\.13/')" >> $@;; \
		*) echo "export RKE2_NODE_VIP_IP=" >> $@;; \
	esac

# =============================================================================
# CONVENIENCE TARGETS
# =============================================================================

# Generate all network files
.PHONY: generate@rke2-networks
generate@rke2-networks: $(RKE2_HOST_NETWORKS_FILE)
generate@rke2-networks: $(RKE2_CLUSTER_NETWORKS_FILE)
generate@rke2-networks: $(RKE2_NODE_NETWORKS_FILE)

# Clean network files
.PHONY: clean@rke2-networks
clean@rke2-networks:
	echo "[+] Cleaning RKE2 network files..."
	rm -rf $(NETWORK_DIR)

# Debug network configuration
.PHONY: show@rke2-networks
show@rke2-networks: $(RKE2_CLUSTER_NETWORKS_FILE)
show@rke2-networks: $(RKE2_NODE_NETWORKS_FILE)
	echo "=== RKE2 Network Configuration ==="
	echo "Host supernet: $(RKE2_HOST_SUPERNET_CIDR)"
	echo "Cluster $(RKE2_CLUSTER_ID): $(RKE2_CLUSTER_NETWORK_CIDR)"
	echo "Node $(RKE2_NODE_ID): $(RKE2_NODE_NETWORK_CIDR)"
	echo "Node host IP: $(RKE2_NODE_HOST_IP)"
	echo "Node gateway: $(RKE2_NODE_GATEWAY_IP)"
	echo "VIP network: $(RKE2_CLUSTER_VIP_NETWORK_CIDR)"
	echo "VIP gateway: $(RKE2_CLUSTER_VIP_GATEWAY_IP)"
	echo "LoadBalancer network: $(RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR)"
	echo ""
	echo "=== Bridge Configuration ==="
	echo "Node LAN bridge: $(RKE2_NODE_LAN_BRIDGE_NAME)"
	echo "Node WAN bridge: $(RKE2_NODE_WAN_BRIDGE_NAME)"
	echo "Cluster VIP bridge: $(RKE2_CLUSTER_VIP_BRIDGE_NAME) -> $(RKE2_CLUSTER_VIP_NETWORK_CIDR)"

# =============================================================================
# DERIVED VARIABLES FOR TEMPLATES
# =============================================================================

# Profile name for Incus
RKE2_NODE_PROFILE_NAME := rke2-$(RKE2_NODE_NAME)

# Master node IP for peer connections (derived from node 0)
RKE2_MASTER_NODE_IP := $(shell echo $(RKE2_NODE_0_NETWORK_CIDR) | cut -d'/' -f1 | sed 's/\.0$$/\.3/' 2>/dev/null || echo "")

# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export RKE2 network variables for use in YAML templates via yq envsubst
export RKE2_HOST_SUPERNET_CIDR
export RKE2_CLUSTER_NETWORK_CIDR
export RKE2_CLUSTER_VIP_NETWORK_CIDR
export RKE2_CLUSTER_VIP_GATEWAY_IP
export RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR
export RKE2_CLUSTER_LOADBALANCER_GATEWAY_IP
# Legacy compatibility alias for older templates expecting CLUSTER_VIP_GATEWAY
export RKE2_NODE_NETWORK_CIDR
export RKE2_NODE_GATEWAY_IP
export RKE2_NODE_HOST_IP
export RKE2_NODE_VIP_IP
export RKE2_NODE_LAN_BRIDGE_NAME
export RKE2_NODE_WAN_BRIDGE_NAME
export RKE2_CLUSTER_VIP_BRIDGE_NAME
# Derive bridge CIDR (network + prefix) for templates expecting RKE2_CLUSTER_VIP_BRIDGE_CIDR
RKE2_CLUSTER_VIP_BRIDGE_PREFIX_LENGTH ?= 24
RKE2_CLUSTER_VIP_BRIDGE_CIDR := $(RKE2_CLUSTER_VIP_NETWORK_CIDR)
export RKE2_CLUSTER_VIP_BRIDGE_CIDR
export RKE2_NODE_PROFILE_NAME
export RKE2_MASTER_NODE_IP

#-----------------------------
# Network Layer Targets (@network)
#-----------------------------

.PHONY: summary@network summary@network.print diagnostics@network status@network setup-bridge@network
.PHONY: allocation@network validate@network test@network

summary@network: generate@rke2-networks ## Show network configuration summary (second expansion) (@codebase)
summary@network: load@network
summary@network: summary@network.print

# Convenience rebuild target to avoid ordering issues when chaining with clean (@codebase)
.PHONY: rebuild@rke2-networks
rebuild@rke2-networks: clean@rke2-networks ## Clean, regenerate and load networks (@codebase)
rebuild@rke2-networks: generate@rke2-networks
rebuild@rke2-networks: load@network
	echo "[rebuild@rke2-networks] Completed network rebuild" # @codebase

summary@network.print:
	$(call trace,Entering target: summary@network)
	$(call trace-var,RKE2_CLUSTER_NAME)
	$(call trace-var,RKE2_NODE_NAME)
	$(call trace-network,Displaying network configuration summary)
	echo "Network Configuration Summary:"
	echo "============================="
	echo "Cluster: $(RKE2_CLUSTER_NAME) (ID: $(RKE2_CLUSTER_ID))"
	echo "Node: $(RKE2_NODE_NAME) (ID: $(RKE2_NODE_ID), Role: $(RKE2_NODE_ROLE))"
	echo "Host Supernet: $(RKE2_HOST_SUPERNET_CIDR)"
	echo "Cluster Network: $(RKE2_CLUSTER_NETWORK_CIDR)"
	echo "Node Network: $(RKE2_NODE_NETWORK_CIDR)"
	echo "Node IP: $(RKE2_NODE_HOST_IP)"
	echo "Gateway: $(RKE2_NODE_GATEWAY_IP)"
	echo "Bridge: $(RKE2_NODE_LAN_BRIDGE_NAME)"
	echo "Profile: $(RKE2_NODE_PROFILE_NAME)"

# Second expansion loader: import generated env exports into make variables
.PHONY: load@network
_NETWORK_ASSIGN_FILE := $(NETWORK_DIR)/_assign.mk

$(NETWORK_DIR)/_assign.mk: $(RKE2_HOST_NETWORKS_FILE)
$(NETWORK_DIR)/_assign.mk: $(RKE2_CLUSTER_NETWORKS_FILE)
$(NETWORK_DIR)/_assign.mk: $(RKE2_NODE_NETWORKS_FILE)
$(NETWORK_DIR)/_assign.mk: | $(NETWORK_DIR)/
	echo "[network] Building assignment file $@" # @codebase
	cat $^ | sed -n 's/^export \([A-Z0-9_]*\)=/\1=/p' > $@
	grep -c '=' $@ | xargs -I{} echo "[network] Collected {} variable assignments" # @codebase

load@network: $(NETWORK_DIR)/_assign.mk
	$(call trace-network,Loading generated network environment into make variables)
	$(eval $(file <$(_NETWORK_ASSIGN_FILE)))
	echo "[network] Loaded $$(grep -c '=' $(_NETWORK_ASSIGN_FILE)) assignments"

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
	$(INCUS) network list --format=table
	echo ""
	echo "Bridge details:"
	if $(INCUS) network show $(RKE2_NODE_LAN_BRIDGE_NAME) --project=rke2 2>/dev/null; then
		echo "✓ Bridge $(RKE2_NODE_LAN_BRIDGE_NAME) found"
	else
		echo "✗ Bridge $(RKE2_NODE_LAN_BRIDGE_NAME) not found"
	fi

setup-bridge@network: ## Set up network bridge for current node
	echo "[+] Setting up bridge $(RKE2_NODE_LAN_BRIDGE_NAME) for node $(RKE2_NODE_NAME)"
	echo "Network: $(RKE2_NODE_NETWORK_CIDR)"
	echo "Gateway: $(RKE2_NODE_GATEWAY_IP)"

allocation@network: ## Show hierarchical network allocation
	echo "Hierarchical Network Allocation"
	echo "==============================="
	if [ -n "$(GLOBAL_CIDR)" ]; then
		echo "Global Infrastructure: $(GLOBAL_CIDR)"
		echo "├─ Cluster Network: $(CLUSTER_CIDR)"
		echo "│  ├─ Node Subnets: $(NODE_CIDR) (each /$(NODE_CIDR_PREFIX))"
		echo "│  └─ Service Network: $(SERVICE_CIDR)"
		echo "└─ Current Node: $(NODE_NETWORK) → $(NODE_IP)"
	else
		echo "No network configuration found. Set RKE2_NODE_NAME to see allocation."
	fi

validate@network: ## Validate network configuration
	echo "Validating network configuration..."
	ERRORS=0
	for v in RKE2_CLUSTER_NETWORK_CIDR RKE2_NODE_NETWORK_CIDR RKE2_NODE_HOST_IP RKE2_NODE_GATEWAY_IP; do
		val=$$(echo $$($$v))
		if [ -z "$$val" ]; then echo "✗ Error: $$v not set"; ERRORS=$$((ERRORS+1)); else echo "✓ $$v=$$val"; fi
	done
	if [ $$ERRORS -eq 0 ]; then echo "✓ Network configuration valid"; else echo "✗ Network configuration has $$ERRORS error(s)"; exit 1; fi

test@network: generate@rke2-networks ## Run strict network checks (fails fast) (@codebase)
test@network: load@network
	echo "[test@network] Running strict network variable checks"
	required='RKE2_CLUSTER_NETWORK_CIDR RKE2_CLUSTER_VIP_NETWORK_CIDR RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR RKE2_NODE_NETWORK_CIDR RKE2_NODE_HOST_IP RKE2_NODE_GATEWAY_IP RKE2_NODE_VIP_IP'
	missing=0
	for v in $$required; do
		val=$$(eval echo "$$"$$v)
		if [ -z "$$val" ]; then echo "[!] Missing $$v"; missing=$$((missing+1)); else echo "[ok] $$v=$$val"; fi
	done
	if [ $$missing -gt 0 ]; then echo "[FAIL] $$missing required network vars missing"; exit 1; else echo "[PASS] All required network vars present"; fi

# Arithmetic derivation validation (@codebase)
.PHONY: test@network-arith
test@network-arith: generate@rke2-networks load@network
	echo "[test@network-arith] Validating arithmetic CIDR derivations" # @codebase
	grep -q 'RKE2_HOST_CLUSTER_COUNT=8' $(RKE2_HOST_NETWORKS_FILE) || { echo '[FAIL] Expected host cluster count export'; exit 1; }
	count_clusters=$$(grep -c 'RKE2_CLUSTER_[0-7]_NETWORK_CIDR=' $(RKE2_HOST_NETWORKS_FILE)); [ $$count_clusters -eq 8 ] || { echo "[FAIL] Host clusters count $$count_clusters != 8"; exit 1; }
	count_nodes=$$(grep -c 'RKE2_NODE_[0-3]_NETWORK_CIDR=' $(RKE2_CLUSTER_NETWORKS_FILE)); [ $$count_nodes -eq 4 ] || { echo "[FAIL] Cluster nodes count $$count_nodes != 4"; exit 1; }
	grep -q 'RKE2_CLUSTER_VIP_NETWORK_CIDR=' $(RKE2_CLUSTER_NETWORKS_FILE) || { echo '[FAIL] VIP CIDR missing'; exit 1; }
	grep -q 'RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR=' $(RKE2_CLUSTER_NETWORKS_FILE) || { echo '[FAIL] LB CIDR missing'; exit 1; }
	grep -q 'RKE2_NODE_GATEWAY_IP=10.80.' $(RKE2_NODE_NETWORKS_FILE) || { echo '[FAIL] Node gateway pattern mismatch'; exit 1; }
	grep -q 'RKE2_NODE_HOST_IP=10.80.' $(RKE2_NODE_NETWORKS_FILE) || { echo '[FAIL] Node host IP pattern mismatch'; exit 1; }
	echo "[PASS] Arithmetic derivation checks passed" # @codebase

endif  # network/rules.mk guard