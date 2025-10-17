# network-deps.mk - Advanced network dependency management using secondary expansion (@codebase)
# Uses .SECONDEXPANSION to create dynamic prerequisite relationships

.SECONDEXPANSION:

#-----------------------------
# Network Dependency Templates
#-----------------------------

# Template for bridge dependencies - each node depends on its bridges
define BRIDGE_DEPS_TEMPLATE
$(1)_REQUIRED_BRIDGES := rke2-$(1)-lan rke2-$(1)-wan rke2-vip
endef

# Generate bridge dependencies for all nodes
$(foreach node,$(SUPPORTED_NODES),$(eval $(call BRIDGE_DEPS_TEMPLATE,$(node))))

#-----------------------------
# Secondary Expansion Rules
#-----------------------------

# Network setup with secondary expansion for dynamic bridge dependencies
setup-network-%: | $$($$*_REQUIRED_BRIDGES:%=bridge-%)
	@echo "[+] Network setup complete for node $*"

# Bridge creation with constructed prerequisites  
bridge-%:
	@echo "[+] Creating bridge $*"
	@# Bridge creation logic would go here
	$(INCUS) network create $* --project=rke2 || echo "Bridge $* already exists"

# Instance startup depends on network setup (using secondary expansion)
start@incus: | setup-network-$$(RKE2_NODE_NAME)
	@echo "[+] Starting instance with network dependencies satisfied"

# Clean bridge dependencies
clean-bridges-%: 
	@echo "[+] Cleaning bridges for node $*"
	$(foreach bridge,$($(*)_REQUIRED_BRIDGES),$(INCUS) network delete $(bridge) --project=rke2 2>/dev/null || true;)

#-----------------------------
# Advanced Pattern Matching
#-----------------------------

# Use secondary expansion with pattern matching for config files
$(RUN_INSTANCE_DIR)/%.yaml: $$($$*_CONFIG_TEMPLATE) | $(RUN_INSTANCE_DIR)/
	@echo "[+] Generating config $@ from template $($(*)_CONFIG_TEMPLATE)"
	@yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $($(*)_CONFIG_TEMPLATE) > $@

# Define config templates per component
incus_CONFIG_TEMPLATE := incus-instance-config.yaml
network_CONFIG_TEMPLATE := network-config.yaml
cloud_CONFIG_TEMPLATE := cloud-config.common.yaml