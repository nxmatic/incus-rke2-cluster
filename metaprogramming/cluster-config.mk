# cluster-config.mk - Data-driven cluster configuration (@codebase)
# Uses eval() function to generate rules dynamically from configuration data

#-----------------------------
# Cluster Configuration Data
#-----------------------------

# Define cluster configurations as structured data
define CLUSTER_bioskop_CONFIG
RKE2_CLUSTER_ID := 1
RKE2_POD_NETWORK_CIDR := 10.42.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.43.0.0/16
LIMA_LAN_INTERFACE := vmlan0
LIMA_WAN_INTERFACE := vmwan0
endef

define CLUSTER_alcide_CONFIG
RKE2_CLUSTER_ID := 2
RKE2_POD_NETWORK_CIDR := 10.44.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.45.0.0/16
LIMA_LAN_INTERFACE := vmlan0
LIMA_WAN_INTERFACE := vmwan0
endef

# Node type configurations
define NODE_master_CONFIG
RKE2_NODE_ID := 0
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := master
endef

define NODE_peer1_CONFIG
RKE2_NODE_ID := 1
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define NODE_peer2_CONFIG
RKE2_NODE_ID := 2
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define NODE_peer3_CONFIG
RKE2_NODE_ID := 3
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define NODE_worker1_CONFIG
RKE2_NODE_ID := 4
RKE2_NODE_TYPE := agent
RKE2_NODE_ROLE := worker
endef

define NODE_worker2_CONFIG
RKE2_NODE_ID := 5
RKE2_NODE_TYPE := agent
RKE2_NODE_ROLE := worker
endef

# Supported clusters and nodes
SUPPORTED_CLUSTERS := bioskop alcide
SUPPORTED_NODES := master peer1 peer2 peer3 worker1 worker2

#-----------------------------
# Dynamic Configuration Application
#-----------------------------

# Template for cluster-specific variable assignment
define APPLY_CLUSTER_CONFIG_TEMPLATE
$(if $(CLUSTER_$(1)_CONFIG),$(eval $(CLUSTER_$(1)_CONFIG)),$(info Warning: No config found for cluster: $(1)))
endef

# Template for node-specific variable assignment  
define APPLY_NODE_CONFIG_TEMPLATE
$(if $(NODE_$(1)_CONFIG),$(eval $(NODE_$(1)_CONFIG)),$(info Warning: No config found for node: $(1)))
endef

# Apply configurations based on current selections (only if variables are defined)
ifneq ($(RKE2_CLUSTER_NAME),)
$(call APPLY_CLUSTER_CONFIG_TEMPLATE,$(RKE2_CLUSTER_NAME))
endif
ifneq ($(RKE2_NODE_NAME),)
$(call APPLY_NODE_CONFIG_TEMPLATE,$(RKE2_NODE_NAME))
endif

#-----------------------------
# Generate Per-Node Target Rules Using eval()
#-----------------------------

# Template for generating per-node lifecycle rules
define GENERATE_NODE_RULES_TEMPLATE
.PHONY: start-$(1) stop-$(1) delete-$(1) clean-$(1) shell-$(1)

start-$(1): ## Start $(1) node in current cluster
	@echo "[+] Starting node $(1) in cluster $(RKE2_CLUSTER_NAME)"
	$$(MAKE) NAME=$(1) start@incus

stop-$(1): ## Stop $(1) node
	@echo "[+] Stopping node $(1)"
	$$(MAKE) NAME=$(1) stop@incus

delete-$(1): ## Delete $(1) node instance
	@echo "[+] Deleting node $(1)"
	$$(MAKE) NAME=$(1) delete@incus

clean-$(1): ## Clean $(1) node completely
	@echo "[+] Cleaning node $(1)"
	$$(MAKE) NAME=$(1) clean@incus

shell-$(1): ## Open shell in $(1) node
	@echo "[+] Opening shell in node $(1)"
	$$(MAKE) NAME=$(1) shell@incus

# Node-specific network diagnostics
network-$(1): ## Show network diagnostics for $(1) node
	@echo "[+] Network diagnostics for node $(1)"
	$$(MAKE) NAME=$(1) vm-network@incus
endef

# Generate rules for all supported nodes
$(foreach node,$(SUPPORTED_NODES),$(eval $(call GENERATE_NODE_RULES_TEMPLATE,$(node))))

#-----------------------------
# Generate Cluster-Wide Operations
#-----------------------------

# Template for cluster-wide operations
define GENERATE_CLUSTER_RULES_TEMPLATE
.PHONY: start-cluster-$(1) stop-cluster-$(1) clean-cluster-$(1)

start-cluster-$(1): ## Start all nodes in $(1) cluster
	@echo "[+] Starting all nodes in cluster $(1)"
	$$(foreach node,$$(SUPPORTED_NODES),$$(MAKE) RKE2_CLUSTER_NAME=$(1) NAME=$$(node) start@incus;)

stop-cluster-$(1): ## Stop all nodes in $(1) cluster
	@echo "[+] Stopping all nodes in cluster $(1)"
	$$(foreach node,$$(SUPPORTED_NODES),$$(MAKE) RKE2_CLUSTER_NAME=$(1) NAME=$$(node) stop@incus;)

clean-cluster-$(1): ## Clean all nodes in $(1) cluster (destructive)
	@echo "[+] Cleaning all nodes in cluster $(1)"
	$$(foreach node,$$(SUPPORTED_NODES),$$(MAKE) RKE2_CLUSTER_NAME=$(1) NAME=$$(node) clean@incus;)
endef

# Generate cluster-wide rules for all supported clusters
$(foreach cluster,$(SUPPORTED_CLUSTERS),$(eval $(call GENERATE_CLUSTER_RULES_TEMPLATE,$(cluster))))