# metaprogramming/rules.mk - Advanced metaprogramming features (@codebase)
# Self-guarding include pattern for idempotent multiple inclusion.

ifndef metaprogramming/rules.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

#-----------------------------
# Metaprogramming Module Includes
#-----------------------------

# Only include these for non-help targets to avoid evaluation issues
ifneq ($(MAKECMDGOALS),help)
-include metaprogramming/cluster-config.mk
-include metaprogramming/runtime-config.mk  
-include metaprogramming/advanced.mk
endif

#-----------------------------
# Metaprogramming Control Targets
#-----------------------------

.PHONY: enable@meta disable@meta features@meta targets@meta

enable@meta: ## Enable advanced metaprogramming features
	echo "[+] Metaprogramming features are enabled"
	echo "Available generated targets:"
	echo "  Per-node: start-master, start-peer1, start-worker1, etc."
	echo "  Per-cluster: start-cluster-bioskop, stop-cluster-alcide"
	echo "  Scaling: scale-master-memory, scale-cluster-resources"
	echo "  Debugging: debug-variables, show-constructed-values"

disable@meta: ## Disable metaprogramming (use basic targets only)
	echo "[+] Using basic targets only (metaprogramming disabled)"
	echo "Use standard targets: make start NAME=node, make clean-all, etc."

#-----------------------------
# Metaprogramming Documentation Targets
#-----------------------------

.PHONY: show-metaprogramming-features list-generated-targets

features@meta: ## Show available metaprogramming features
	echo "Advanced Metaprogramming Features:"
	echo "=================================="
	echo ""
	echo "1. Dynamic Rule Generation (eval function)"
	echo "   - Generates targets for all supported nodes: $(SUPPORTED_NODES)"
	echo "   - Generates targets for all supported clusters: $(SUPPORTED_CLUSTERS)"
	echo ""
	echo "2. Constructed Macro Names"
	echo "   - Node-specific configuration: \$$(NODE_\$${NODE}_CONFIG)"
	echo "   - Cluster-specific settings: \$$(CLUSTER_\$${CLUSTER}_CONFIG)"
	echo ""
	echo "3. Runtime Configuration Generation"
	echo "   - Auto-generated: $(RUNTIME_CONFIG_FILE)"
	echo "   - Context-aware target selection"
	echo ""
	echo "4. Secondary Expansion (network dependencies)"
	echo "   - Dynamic bridge dependencies per node"
	echo "   - Automatic prerequisite resolution"

targets@meta: ## List all metaprogramming-generated targets
	echo "Generated Targets (available when metaprogramming is enabled):"
	echo "============================================================="
	echo ""
	echo "Per-node lifecycle targets:"
	$(foreach node,$(SUPPORTED_NODES),echo "  start-$(node), stop-$(node), clean-$(node), shell-$(node)";)
	echo ""
	echo "Per-cluster operations:"
	$(foreach cluster,$(SUPPORTED_CLUSTERS),echo "  start-cluster-$(cluster), stop-cluster-$(cluster), clean-cluster-$(cluster)";)
	echo ""
	echo "Resource scaling:"
	$(foreach node,$(SUPPORTED_NODES),echo "  scale-$(node)-memory, scale-$(node)-cpu";)
	echo "  scale-cluster-resources"
	echo ""
	echo "Debugging and introspection:"
	echo "  debug-variables, show-constructed-values, status-report"

endif # metaprogramming/rules.mk guard
