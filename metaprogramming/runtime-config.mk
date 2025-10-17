# runtime-config.mk - Dynamic runtime configuration using constructed include files (@codebase)
# Generates configuration files at runtime based on current state

#-----------------------------
# Dynamic Configuration Generation
#-----------------------------

# Generated configuration file
RUNTIME_CONFIG_FILE := $(RUN_DIR)/runtime.auto.mk

# Avoid rebuilding during clean operations
ifneq (,$(filter-out clean clean-%,$(MAKECMDGOALS)))
-include $(RUNTIME_CONFIG_FILE)
endif

#-----------------------------
# Runtime Configuration Template
#-----------------------------

define RUNTIME_CONFIG_TEMPLATE
# Auto-generated runtime configuration
# Generated at $(shell date)

# Current runtime context
CURRENT_CLUSTER := $(RKE2_CLUSTER_NAME)
CURRENT_NODE := $(RKE2_NODE_NAME)  
CURRENT_NODE_TYPE := $(RKE2_NODE_TYPE)

# Generated network variables
RKE2_NODE_HOST_IP := $(shell $(MAKE) -s show@rke2-node-host-ip 2>/dev/null || echo "unknown")
RKE2_NODE_VIP_IP := $(shell $(MAKE) -s show@rke2-node-vip-ip 2>/dev/null || echo "unknown")

# Runtime instance status
INSTANCE_EXISTS := $(shell incus info $(RKE2_NODE_NAME) --project=rke2 >/dev/null 2>&1 && echo "true" || echo "false")
INSTANCE_RUNNING := $(shell incus info $(RKE2_NODE_NAME) --project=rke2 2>/dev/null | grep -q "Status: Running" && echo "true" || echo "false")

# Generated target shortcuts
ifneq ($$(INSTANCE_EXISTS),true)
start@incus: instance@incus
endif

ifeq ($$(INSTANCE_RUNNING),true)
.PHONY: restart@incus
restart@incus: stop@incus start@incus
endif

# Environment-specific overrides
ifeq ($(LIMA_HOST),)
# Running on native Linux
SUDO_PREFIX :=
else
# Running via Lima VM
SUDO_PREFIX := $(REMOTE_EXEC)
endif

endef

#-----------------------------
# Configuration File Generation
#-----------------------------

$(RUNTIME_CONFIG_FILE): Makefile network.mk $(CLUSTER_ENV_FILE) | $(RUN_DIR)/
	@echo "[+] Generating runtime configuration..."
	@echo '$(subst $(newline),\n,$(RUNTIME_CONFIG_TEMPLATE))' > $@

# Force regeneration when key files change
$(RUNTIME_CONFIG_FILE): $(shell find . -name "*.mk" -newer $(RUNTIME_CONFIG_FILE) 2>/dev/null)

#-----------------------------
# Context-Aware Helper Targets  
#-----------------------------

.PHONY: show-runtime-config check-runtime-state

show-runtime-config: $(RUNTIME_CONFIG_FILE) ## Display auto-generated runtime configuration
	@echo "Runtime Configuration:"
	@echo "===================="
	@cat $(RUNTIME_CONFIG_FILE)

check-runtime-state: ## Check current runtime state of cluster and nodes
	@echo "Current Runtime State:"
	@echo "====================="
	@echo "Cluster: $(RKE2_CLUSTER_NAME)"
	@echo "Node: $(RKE2_NODE_NAME) ($(RKE2_NODE_TYPE)/$(RKE2_NODE_ROLE))"
	@echo "Instance exists: $(shell incus info $(RKE2_NODE_NAME) --project=rke2 >/dev/null 2>&1 && echo "yes" || echo "no")"
	@echo "Instance running: $(shell incus info $(RKE2_NODE_NAME) --project=rke2 2>/dev/null | grep -q "Status: Running" && echo "yes" || echo "no")"
	@echo "Network allocated: $(shell test -f $(CLUSTER_ENV_FILE) && echo "yes" || echo "no")"

# Define newline for template substitution
define newline


endef