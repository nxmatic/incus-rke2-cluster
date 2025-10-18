ifndef metaprogramming/cluster-config.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

#-----------------------------
# Cluster Configuration Data
#-----------------------------

# Define cluster configurations as structured data
define .cluster-config.bioskop
RKE2_CLUSTER_ID := 1
RKE2_POD_NETWORK_CIDR := 10.42.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.43.0.0/16
LIMA_LAN_INTERFACE := vmlan0
LIMA_WAN_INTERFACE := vmwan0
endef

define .cluster-config.alcide
RKE2_CLUSTER_ID := 2
RKE2_POD_NETWORK_CIDR := 10.44.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.45.0.0/16
LIMA_LAN_INTERFACE := vmlan0
LIMA_WAN_INTERFACE := vmwan0
endef

# Node type configurations
define .node-config.master
RKE2_NODE_ID := 0
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := master
endef

define .node-config.peer1
RKE2_NODE_ID := 1
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define .node-config.peer2
RKE2_NODE_ID := 2
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define .node-config.peer3
RKE2_NODE_ID := 3
RKE2_NODE_TYPE := server
RKE2_NODE_ROLE := peer
endef

define .node-config.worker1
RKE2_NODE_ID := 4
RKE2_NODE_TYPE := agent
RKE2_NODE_ROLE := worker
endef

define .node-config.worker2
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
$(if $(CLUSTER_$(1)_CONFIG),$(eval $(.cluster-config.$(1))),$(info Warning: No config found for cluster: $(1)))
endef

# Template for node-specific variable assignment  
define APPLY_NODE_CONFIG_TEMPLATE
$(if $(NODE_$(1)_CONFIG),$(eval $(.node-config.$(1))),$(info Warning: No config found for node: $(1)))
endef

# Apply configurations based on current selections (only if variables are defined)
ifneq ($(RKE2_CLUSTER_NAME),)
$(call APPLY_CLUSTER_CONFIG_TEMPLATE,$(RKE2_CLUSTER_NAME))
endif
ifneq ($(RKE2_NODE_NAME),)
$(call APPLY_NODE_CONFIG_TEMPLATE,$(RKE2_NODE_NAME))
endif

#-----------------------------
# Generate Per-Node & Cluster Target Rules Using eval() (guarded)
# Non-recursive: rely on dependency graph; no nested $(MAKE) calls.
#-----------------------------

# Template for generating per-node lifecycle aggregation targets
define GENERATE_NODE_RULES_TEMPLATE
.PHONY: start-$(1) stop-$(1) delete-$(1) clean-$(1) shell-$(1) network-$(1)

# Target-specific variable assignments
start-$(1): NAME=$(1)
start-$(1): start@incus ## Start $(1) node (delegates to start@incus)

stop-$(1): NAME=$(1)
stop-$(1): stop@incus ## Stop $(1) node

delete-$(1): NAME=$(1)
delete-$(1): delete@incus ## Delete $(1) node instance

clean-$(1): NAME=$(1)
clean-$(1): clean@incus ## Clean $(1) node completely

shell-$(1): NAME=$(1)
shell-$(1): shell@incus ## Open shell in $(1) node

network-$(1): NAME=$(1)
network-$(1): vm-network@incus ## Network diagnostics for $(1) node
endef

# Generate rules for all supported nodes (adds dependencies; no recipes)
$(foreach node,$(SUPPORTED_NODES),$(eval $(call GENERATE_NODE_RULES_TEMPLATE,$(node))))

# Cluster-wide aggregation targets
define GENERATE_CLUSTER_RULES_TEMPLATE
.PHONY: start-cluster-$(1) stop-cluster-$(1) clean-cluster-$(1)

start-cluster-$(1): RKE2_CLUSTER_NAME=$(1)
start-cluster-$(1): $(addprefix start-,$(SUPPORTED_NODES)) ## Start all nodes in cluster $(1)
	@echo "[+] Cluster $(1) start complete"

stop-cluster-$(1): RKE2_CLUSTER_NAME=$(1)
stop-cluster-$(1): $(addprefix stop-,$(SUPPORTED_NODES)) ## Stop all nodes in cluster $(1)
	@echo "[+] Cluster $(1) stop complete"

clean-cluster-$(1): RKE2_CLUSTER_NAME=$(1)
clean-cluster-$(1): $(addprefix clean-,$(SUPPORTED_NODES)) ## Clean all nodes in cluster $(1) (destructive)
	@echo "[+] Cluster $(1) clean complete"
endef

$(foreach cluster,$(SUPPORTED_CLUSTERS),$(eval $(call GENERATE_CLUSTER_RULES_TEMPLATE,$(cluster))))

_CLUSTER_RULES_GENERATED := 1

endif # metaprogramming/cluster-config.mk guard
