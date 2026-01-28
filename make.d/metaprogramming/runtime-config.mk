ifndef metaprogramming/runtime-config.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

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
CURRENT_CLUSTER := $(CLUSTER_NAME)
CURRENT_NODE := $(NODE_NAME)  
CURRENT_NODE_KIND := $(NODE_KIND)

# Generated network variables
## Removed recursive $(MAKE) calls to non-existent show@rke2-node-host-inetaddr/show@rke2-node-vip-inetaddr to avoid infinite recursion.
NODE_HOST_IP := $(NODE_HOST_IP)
NODE_VIP_IP := $(NODE_VIP_IP)

# Runtime instance status
INSTANCE_EXISTS := $(shell incus info $(NODE_NAME) --project=$(.incus.project.name) >/dev/null 2>&1 && echo "true" || echo "false")
INSTANCE_RUNNING := $(shell incus info $(NODE_NAME) --project=$(.incus.project.name) 2>/dev/null | grep -q "Status: Running" && echo "true" || echo "false")

# (No dynamic target injection; rely on canonical definitions in incus/rules.mk)
# Environment overrides removed (use existing REMOTE_EXEC from make.mk)

endef

#-----------------------------
# Configuration File Generation
#-----------------------------

$(RUNTIME_CONFIG_FILE): Makefile */rules.mk $(CLUSTER_ENV_FILE) | $(RUN_DIR)/
	echo "[+] Generating runtime configuration at $@..."; \
	{
	  printf '%s\n' "$(subst $(newline),\n,$(RUNTIME_CONFIG_TEMPLATE))"; \
	} > $@.tmp; \
	mv $@.tmp $@

# Force regeneration when key files change
$(RUNTIME_CONFIG_FILE): $(shell find . -name "*.mk" -newer $(RUNTIME_CONFIG_FILE) 2>/dev/null)

#-----------------------------
# Context-Aware Helper Targets  
#-----------------------------

.PHONY: show-runtime-config check-runtime-state

show-runtime-config: $(RUNTIME_CONFIG_FILE) ## Display auto-generated runtime configuration
	echo "Runtime Configuration:"
	echo "===================="
	cat $(RUNTIME_CONFIG_FILE)

check-runtime-state: ## Check current runtime state of cluster and nodes
	echo "Current Runtime State:"
	echo "====================="
	echo "Cluster: $(CLUSTER_NAME)"
	echo "Node: $(NODE_NAME) ($(NODE_KIND)/$(NODE_NAME))"
	echo "Instance exists: $(shell incus info $(NODE_NAME) --project=$(.incus.project.name) >/dev/null 2>&1 && echo "yes" || echo "no")"
	echo "Instance running: $(shell incus info $(NODE_NAME) --project=$(.incus.project.name) 2>/dev/null | grep -q "Status: Running" && echo "yes" || echo "no")"
	echo "Network allocated: $(shell test -f $(CLUSTER_ENV_FILE) && echo "yes" || echo "no")"

# Define newline for template substitution
define newline :=


endef

endif # metaprogramming/runtime-config.mk guard
