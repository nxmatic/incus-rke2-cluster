ifndef network/network-deps.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

#-----------------------------
# Network Dependency Templates
#-----------------------------

.network.supported.nodes := master peer1 peer2 peer3 worker1 worker2

# Template for bridge dependencies - each node depends on its bridges
define .network.bridge-deps-template
.network.$(1).required.bridges := rke2-$(1)-lan rke2-$(1)-wan rke2-vip
endef

# Generate bridge dependencies for all nodes (disabled for now, no bridges needed)
#
# $(foreach node,$(.network.supported.nodes),$(eval $(call .network.bridge-deps-template,$(node))))

#-----------------------------
# Secondary Expansion Rules
#-----------------------------


# Network setup rules for each node (avoiding multiple target patterns)
$(foreach node,$(.network.supported.nodes), \
	$(eval setup-network-$(node): | $(foreach bridge,$(.network.$(node).required.bridges),bridge-$(bridge))) \
	$(eval setup-network-$(node): ; : "[+] Network setup complete for node $(node)") \
	$(warning [network] Defined setup-network-$(node) with bridges: $(.network.$(node).required.bridges)) \
)

# Bridge creation with constructed prerequisites  
bridge-%:
	: "[+] Creating bridge $*"
	# Bridge creation logic would go here
	incus network create $* --project=$(.incus.project.name) || echo "Bridge $* already exists"

# Instance startup depends on network setup (using secondary expansion)
start@incus: | setup-network-$$(node.name)
	: "[+] Starting instance with network dependencies satisfied"

# Clean bridge dependencies
clean-bridges-%: 
	: "[+] Cleaning bridges for node $*"
	$(foreach bridge,$(.network.$(*).required.bridges),incus network delete $(bridge) --project=$(.incus.project.name) 2>/dev/null || true;)

#-----------------------------
# Advanced Pattern Matching
#-----------------------------

# Use secondary expansion with pattern matching for config files
$(RUN_INSTANCE_DIR)/%.yaml: $(RUN_INSTANCE_DIR)/ $(RUN_INSTANCE_DIR)/template-%.yaml
	: "[+] Generating config $@ from template $<"
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $< > $@

# Define config templates per component
INCUS_CONFIG_TEMPLATE := incus-instance-config.yaml
NETCFG_TEMPLATE := network-config.yaml
CLOUD_CONFIG_TEMPLATE := cloud-config.common.yaml

endif # network/network-deps.mk guard
