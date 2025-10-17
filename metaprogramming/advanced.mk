# advanced-targets.mk - Advanced target generation using constructed macro names (@codebase)
# Demonstrates sophisticated metaprogramming patterns from the Make papers

#-----------------------------
# Target-Specific Configuration
#-----------------------------

# Define per-target configuration using constructed macro names
master_SPECIAL_FLAGS := --bootstrap
peer1_SPECIAL_FLAGS := --join-peer
peer2_SPECIAL_FLAGS := --join-peer  
peer3_SPECIAL_FLAGS := --join-peer
worker1_SPECIAL_FLAGS := --join-worker
worker2_SPECIAL_FLAGS := --join-worker

# Per-cluster resource limits
bioskop_MEMORY_LIMIT := 4GiB
bioskop_CPU_LIMIT := 2
alcide_MEMORY_LIMIT := 8GiB  
alcide_CPU_LIMIT := 4

# Per-node-type specific configuration
server_MIN_MEMORY := 2GiB
server_MIN_CPU := 2
agent_MIN_MEMORY := 1GiB
agent_MIN_CPU := 1

#-----------------------------
# Advanced Pattern Rules with Constructed Names
#-----------------------------

# Generic instance configuration using constructed macro names
.PHONY: config-instance@incus
config-instance@incus:
	@echo "[+] Configuring instance $(RKE2_NODE_NAME) with type-specific settings"
	@echo "  Special flags: $($(RKE2_NODE_NAME)_SPECIAL_FLAGS)"
	@echo "  Memory limit: $($(RKE2_CLUSTER_NAME)_MEMORY_LIMIT)"  
	@echo "  CPU limit: $($(RKE2_CLUSTER_NAME)_CPU_LIMIT)"
	@echo "  Min memory: $($(RKE2_NODE_TYPE)_MIN_MEMORY)"
	@echo "  Min CPU: $($(RKE2_NODE_TYPE)_MIN_CPU)"
	incus config set $(RKE2_NODE_NAME) --project=rke2 \
		limits.memory=$(or $($(RKE2_CLUSTER_NAME)_MEMORY_LIMIT),$($(RKE2_NODE_TYPE)_MIN_MEMORY))
	incus config set $(RKE2_NODE_NAME) --project=rke2 \
		limits.cpu=$(or $($(RKE2_CLUSTER_NAME)_CPU_LIMIT),$($(RKE2_NODE_TYPE)_MIN_CPU))

#-----------------------------
# Context-Aware Recipe Generation
#-----------------------------

# Template for generating context-aware recipes
define CONTEXT_AWARE_RECIPE_TEMPLATE
$(1)@incus: config-instance@incus
$(1)@incus:
	@echo "[+] Executing $(1) for node $$(RKE2_NODE_NAME) with flags: $$($$($$(RKE2_NODE_NAME)_SPECIAL_FLAGS))"
	$(2) $$($$($$(RKE2_NODE_NAME)_SPECIAL_FLAGS))
endef

# Generate context-aware targets
$(eval $(call CONTEXT_AWARE_RECIPE_TEMPLATE,bootstrap-rke2,rke2 server))
$(eval $(call CONTEXT_AWARE_RECIPE_TEMPLATE,join-cluster,rke2 agent))

#-----------------------------
# Debugging and Introspection Targets
#-----------------------------

.PHONY: debug-variables show-constructed-values

debug-variables: ## Show constructed variable values for debugging
	@echo "Variable Construction Debug:"
	@echo "=========================="
	@echo "Node name: $(RKE2_NODE_NAME)"
	@echo "Node type: $(RKE2_NODE_TYPE)"  
	@echo "Cluster name: $(RKE2_CLUSTER_NAME)"
	@echo ""
	@echo "Constructed Variables:"
	@echo "$(RKE2_NODE_NAME)_SPECIAL_FLAGS = $($(RKE2_NODE_NAME)_SPECIAL_FLAGS)"
	@echo "$(RKE2_CLUSTER_NAME)_MEMORY_LIMIT = $($(RKE2_CLUSTER_NAME)_MEMORY_LIMIT)"
	@echo "$(RKE2_NODE_TYPE)_MIN_MEMORY = $($(RKE2_NODE_TYPE)_MIN_MEMORY)"

# Target-specific variable demonstration
debug-target-vars: ## Show target-specific variables for current node
	@echo "Target-specific variables for current node:"
	@$(foreach var,SPECIAL_FLAGS MEMORY_LIMIT CPU_LIMIT MIN_MEMORY MIN_CPU, \
		echo "  $(var): $($(RKE2_NODE_NAME)_$(var)) $($(RKE2_CLUSTER_NAME)_$(var)) $($(RKE2_NODE_TYPE)_$(var))";)

show-constructed-values: ## Show current constructed variable values
	@echo "Current Constructed Values:"
	@echo "=========================="
	$(info Node flags: $($(RKE2_NODE_NAME)_SPECIAL_FLAGS))
	$(info Cluster memory: $($(RKE2_CLUSTER_NAME)_MEMORY_LIMIT))
	$(info Type memory: $($(RKE2_NODE_TYPE)_MIN_MEMORY))
	$(info Effective memory: $(or $($(RKE2_CLUSTER_NAME)_MEMORY_LIMIT),$($(RKE2_NODE_TYPE)_MIN_MEMORY)))

#-----------------------------
# Advanced Foreach Usage
#-----------------------------

# Generate comprehensive status report using foreach and constructed names
.PHONY: status-report

.PHONY: status-report

define STATUS_CHECK_TEMPLATE
echo "=== Status for $(1) ==="
echo "Node type: $$($(1)_NODE_TYPE)"
echo "Special flags: $$($(1)_SPECIAL_FLAGS)" 
echo "Instance status: $$(incus info $(1) --project=rke2 2>/dev/null | grep Status || echo "Not found")"
echo ""
endef

status-report: ## Generate comprehensive cluster status report
	@echo "Comprehensive Cluster Status Report"
	@echo "=================================="
	@$(foreach node,$(SUPPORTED_NODES),$(STATUS_CHECK_TEMPLATE))

#-----------------------------
# Pattern-Based Resource Management  
#-----------------------------

# Use pattern rules with constructed names for resource scaling
scale-%-memory: ## Scale memory for specific node (e.g., make scale-master-memory)
	@echo "[+] Scaling memory for node $* to $($(*)_MEMORY_LIMIT)"
	incus config set $* --project=rke2 limits.memory=$($(*)_MEMORY_LIMIT)

scale-%-cpu: ## Scale CPU for specific node (e.g., make scale-master-cpu)
	@echo "[+] Scaling CPU for node $* to $($(*)_CPU_LIMIT)"
	incus config set $* --project=rke2 limits.cpu=$($(*)_CPU_LIMIT)

# Bulk scaling operations
.PHONY: scale-cluster-resources
scale-cluster-resources: ## Scale resources for all nodes in cluster
	@echo "[+] Scaling all cluster resources"
	$(foreach node,$(SUPPORTED_NODES),$(MAKE) scale-$(node)-memory scale-$(node)-cpu;)