# network-refactor.mk - Refactored RKE2 network configuration (@codebase)
# Modern hierarchical network system with consistent RKE2-focused naming

# Check for required tools
IPCALC := $(shell command -v ipcalc || echo "false")
ifeq ($(IPCALC),false)
$(error ipcalc command not found. Please install ipcalc package)
endif

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
	@mkdir -p $(NETWORK_DIR)

# Generate host-level network allocation (split supernet into cluster subnets)
$(RKE2_HOST_NETWORKS_FILE): | $(NETWORK_DIR)/
	@echo "[+] Generating RKE2 host networks from $(RKE2_HOST_SUPERNET_CIDR)..."
	@$(IPCALC) $(RKE2_HOST_SUPERNET_CIDR) --split $(RKE2_HOST_CLUSTER_PREFIX_LENGTH) --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[] | "export RKE2_CLUSTER_" + (.key | tostring) + "_NETWORK_CIDR=" + .value' > $@
	@echo "export RKE2_HOST_SUPERNET_CIDR=$(RKE2_HOST_SUPERNET_CIDR)" >> $@
	@$(IPCALC) $(RKE2_HOST_SUPERNET_CIDR) --split $(RKE2_HOST_CLUSTER_PREFIX_LENGTH) --json | \
		yq -p json '"export RKE2_HOST_CLUSTER_COUNT=" + .NETS' >> $@

# Generate cluster-level network allocation (nodes + VIP + LoadBalancer subnets)
$(RKE2_CLUSTER_NETWORKS_FILE): $(RKE2_HOST_NETWORKS_FILE) | $(NETWORK_DIR)/
	@echo "[+] Generating RKE2 cluster $(RKE2_CLUSTER_ID) networks..."
	@. $(RKE2_HOST_NETWORKS_FILE); \
	cluster_net=$$RKE2_CLUSTER_$(RKE2_CLUSTER_ID)_NETWORK_CIDR; \
	echo "[i] Using cluster network: $$cluster_net"; \
	$(IPCALC) $$cluster_net --split $(RKE2_HOST_NODE_PREFIX_LENGTH) --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[] | "export RKE2_NODE_" + (.key | tostring) + "_NETWORK_CIDR=" + .value' > $@; \
	$(IPCALC) $$cluster_net --split 24 --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[7] | "export RKE2_CLUSTER_VIP_NETWORK_CIDR=" + .value' >> $@; \
	$(IPCALC) $$cluster_net --split 24 --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[7] | .value' | \
		awk -F'.' '{print "export RKE2_CLUSTER_VIP_GATEWAY_IP=" $$1 "." $$2 "." $$3 ".1"}' >> $@; \
	node0_net=$$($(IPCALC) $$cluster_net --split $(RKE2_HOST_NODE_PREFIX_LENGTH) --json | yq -p json '.SPLITNETWORK | to_entries | .[0] | .value'); \
	echo "[i] Using node0 network for LoadBalancers: $$node0_net"; \
	$(IPCALC) $$node0_net --split 26 --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[1] | "export RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR=" + .value' >> $@; \
	$(IPCALC) $$node0_net --split 26 --json | \
		yq -p json '.SPLITNETWORK | to_entries | .[1] | .value' | \
		awk -F'.' '{print "export RKE2_CLUSTER_LOADBALANCER_GATEWAY_IP=" $$1 "." $$2 "." $$3 ".129"}' >> $@; \
	echo "export RKE2_CLUSTER_NETWORK_CIDR=$$cluster_net" >> $@

# Generate node-level network allocation (host interfaces within node subnet)
$(RKE2_NODE_NETWORKS_FILE): $(RKE2_CLUSTER_NETWORKS_FILE) | $(NETWORK_DIR)/
	@echo "[+] Generating RKE2 node $(RKE2_NODE_ID) networks..."
	@. $(RKE2_CLUSTER_NETWORKS_FILE); \
	node_net=$$RKE2_NODE_$(RKE2_NODE_ID)_NETWORK_CIDR; \
	echo "[i] Using node network: $$node_net"; \
	node_prefix=$$(echo $$node_net | cut -d'/' -f2); \
	echo "export RKE2_NODE_NETWORK_CIDR=$$node_net" > $@; \
	echo "export RKE2_NODE_GATEWAY_IP=$$($(IPCALC) $$node_net --json | yq -p json '.NETWORK | split(".") | .[0:3] | join(".") + ".1"')" >> $@; \
	echo "export RKE2_NODE_HOST_IP=$$($(IPCALC) $$node_net --json | yq -p json '.NETWORK | split(".") | .[0:3] | join(".") + ".3"')" >> $@; \
	echo "export RKE2_NODE_BROADCAST_IP=$$($(IPCALC) $$node_net --json | yq -p json .BROADCAST)" >> $@; \
	echo "export RKE2_NODE_PREFIX_LENGTH=$$node_prefix" >> $@; \
	vip_gateway=$$RKE2_CLUSTER_VIP_GATEWAY_IP; \
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
generate@rke2-networks: $(RKE2_HOST_NETWORKS_FILE) $(RKE2_CLUSTER_NETWORKS_FILE) $(RKE2_NODE_NETWORKS_FILE)

# Clean network files
.PHONY: clean@rke2-networks
clean@rke2-networks:
	@echo "[+] Cleaning RKE2 network files..."
	@rm -rf $(NETWORK_DIR)

# Debug network configuration
.PHONY: show@rke2-networks
show@rke2-networks: $(RKE2_CLUSTER_NETWORKS_FILE) $(RKE2_NODE_NETWORKS_FILE)
	@echo "=== RKE2 Network Configuration ==="
	@echo "Host supernet: $(RKE2_HOST_SUPERNET_CIDR)"
	@echo "Cluster $(RKE2_CLUSTER_ID): $(RKE2_CLUSTER_NETWORK_CIDR)"
	@echo "Node $(RKE2_NODE_ID): $(RKE2_NODE_NETWORK_CIDR)"
	@echo "Node host IP: $(RKE2_NODE_HOST_IP)"
	@echo "Node gateway: $(RKE2_NODE_GATEWAY_IP)"
	@echo "VIP network: $(RKE2_CLUSTER_VIP_NETWORK_CIDR)"
	@echo "VIP gateway: $(RKE2_CLUSTER_VIP_GATEWAY_IP)"
	@echo "LoadBalancer network: $(RKE2_CLUSTER_LOADBALANCER_NETWORK_CIDR)"
	@echo ""
	@echo "=== Bridge Configuration ==="
	@echo "Node LAN bridge: $(RKE2_NODE_LAN_BRIDGE_NAME)"
	@echo "Node WAN bridge: $(RKE2_NODE_WAN_BRIDGE_NAME)"
	@echo "Cluster VIP bridge: $(RKE2_CLUSTER_VIP_BRIDGE_NAME) -> $(RKE2_CLUSTER_VIP_NETWORK_CIDR)"

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
export RKE2_NODE_NETWORK_CIDR
export RKE2_NODE_GATEWAY_IP
export RKE2_NODE_HOST_IP
export RKE2_NODE_VIP_IP
export RKE2_NODE_LAN_BRIDGE_NAME
export RKE2_NODE_WAN_BRIDGE_NAME
export RKE2_CLUSTER_VIP_BRIDGE_NAME
export RKE2_NODE_PROFILE_NAME
export RKE2_MASTER_NODE_IP

#-----------------------------
# Network Layer Targets (@network)
#-----------------------------

.PHONY: summary@network diagnostics@network status@network setup-bridge@network
.PHONY: allocation@network validate@network

summary@network: ## Show network configuration summary
	$(call trace,Entering target: summary@network)
	$(call trace-var,RKE2_CLUSTER_NAME)
	$(call trace-var,RKE2_NODE_NAME)
	$(call trace-network,Displaying network configuration summary)
	echo "Network Configuration Summary:"; \
	echo "============================="; \
	echo "Cluster: $(RKE2_CLUSTER_NAME) (ID: $(RKE2_CLUSTER_ID))"; \
	echo "Node: $(RKE2_NODE_NAME) (ID: $(RKE2_NODE_ID), Role: $(RKE2_NODE_ROLE))"
	@echo "Host Supernet: $(RKE2_HOST_SUPERNET_CIDR)"
	@echo "Cluster Network: $(RKE2_CLUSTER_NETWORK_CIDR)"
	@echo "Node Network: $(RKE2_NODE_NETWORK_CIDR)"
	@echo "Node IP: $(RKE2_NODE_HOST_IP)"
	@echo "Gateway: $(RKE2_NODE_GATEWAY_IP)"
	@echo "Bridge: $(RKE2_NODE_LAN_BRIDGE_NAME)"
	@echo "Profile: $(RKE2_NODE_PROFILE_NAME)"

diagnostics@network: ## Show host network diagnostics
	$(call trace,Entering target: diagnostics@network)
	$(call trace-var,NODE_INTERFACE)
	$(call trace-network,Running host network diagnostics)
	echo "Host Network Diagnostics:"; \
	ip route show default; \
	ip addr show $(NODE_INTERFACE) 2>/dev/null || echo "Interface $(NODE_INTERFACE) not found"
	@ping -c 1 -W 2 $(NODE_GATEWAY) >/dev/null 2>&1 && echo "Gateway $(NODE_GATEWAY) reachable" || echo "Gateway $(NODE_GATEWAY) unreachable"

status@network: ## Show container network status
	echo "Container Network Status:"; \
	echo "========================"; \
	$(INCUS) network list --format=table; \
	echo ""; \
	echo "Bridge details:"; \
	if $(INCUS) network show $(RKE2_NODE_LAN_BRIDGE_NAME) --project=rke2 2>/dev/null; then \
		echo "✓ Bridge $(RKE2_NODE_LAN_BRIDGE_NAME) found"; \
	else \
		echo "✗ Bridge $(RKE2_NODE_LAN_BRIDGE_NAME) not found"; \
	fi

setup-bridge@network: ## Set up network bridge for current node
	@echo "[+] Setting up bridge $(RKE2_NODE_LAN_BRIDGE_NAME) for node $(RKE2_NODE_NAME)"
	@echo "Network: $(RKE2_NODE_NETWORK_CIDR)"
	@echo "Gateway: $(RKE2_NODE_GATEWAY_IP)"

allocation@network: ## Show hierarchical network allocation
	echo "Hierarchical Network Allocation"; \
	echo "==============================="; \
	if [ -n "$(GLOBAL_CIDR)" ]; then \
		echo "Global Infrastructure: $(GLOBAL_CIDR)"; \
		echo "├─ Cluster Network: $(CLUSTER_CIDR)"; \
		echo "│  ├─ Node Subnets: $(NODE_CIDR) (each /$(NODE_CIDR_PREFIX))"; \
		echo "│  └─ Service Network: $(SERVICE_CIDR)"; \
		echo "└─ Current Node: $(NODE_NETWORK) → $(NODE_IP)"; \
	else \
		echo "No network configuration found. Set RKE2_NODE_NAME to see allocation."; \
	fi

validate@network: ## Validate network configuration
	echo "Validating network configuration..."; \
	ERRORS=0; \
	if [ -z "$(NODE_IP)" ]; then \
		echo "✗ Error: NODE_IP not set"; \
		ERRORS=$$((ERRORS + 1)); \
	else \
		echo "✓ NODE_IP: $(NODE_IP)"; \
	fi; \
	if [ -z "$(NODE_GATEWAY)" ]; then \
		echo "✗ Error: NODE_GATEWAY not set"; \
		ERRORS=$$((ERRORS + 1)); \
	else \
		echo "✓ NODE_GATEWAY: $(NODE_GATEWAY)"; \
	fi; \
	if [ $$ERRORS -eq 0 ]; then \
		echo "✓ Network configuration valid"; \
	else \
		echo "✗ Network configuration has $$ERRORS error(s)"; \
		exit 1; \
	fi