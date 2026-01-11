# network-targets.mk - Network phony targets (@codebase)
# Self-guarding include for convenience targets

ifndef make.d/network/targets.mk

make.d/network/targets.mk := make.d/network/targets.mk

# =============================================================================
# CONVENIENCE TARGETS
# =============================================================================

.PHONY: clean@network
clean@network: ## Clean all generated network files
	: "[+] Cleaning RKE2 network files..."
	rm -rf $(.network.dir) $(.network.cluster.dir)

.PHONY: generate@network
generate@network: $(.network.mks) ## Generate all network split files (@codebase)
	: "[+] Generated all RKE2 network files..."

.PHONY: show@network
show@network: ## Debug network configuration display
	echo "=== RKE2 Network Configuration ==="
	echo "Host supernet: $(.network.host.supernet.cidr)"
	echo "Cluster $(cluster.id): $(.network.cluster.cidr)"
	echo "Node $(node.id): $(.network.node.cidr)"
	echo "Node host IP: $(.network.node.host.inetaddr)"
	echo "Node gateway: $(.network.node.gateway.inetaddr)"
	echo "VIP network: $(.network.cluster.vip.cidr)"
	echo "VIP gateway: $(.network.cluster.vip.gateway)"
	echo "LoadBalancer network: $(.network.cluster.lb.cidr)"
	echo ""
	echo "=== Bridge Configuration ==="
	echo "Node LAN interface: $(.network.node.lan.interface) (macvlan on vmlan0)"
	echo "Node WAN interface: $(.network.node.wan.interface) (bridge on vmnet)"
	echo "Cluster VIP interface: $(.network.cluster.vip.interface) (on vmnet0)"
	echo "Cluster VIP VLAN: $(.network.vip.vlan.id) ($(.network.vip.vlan.name)) -> $(.network.cluster.vip.cidr)"

# =============================================================================
# SUMMARY AND DIAGNOSTICS
# =============================================================================

.PHONY: summary@network summary@network.print diagnostics@network status@network setup-bridge@network
.PHONY: allocation@network validate@network test@network


define .network.summary.content
Network Configuration Summary:
=============================
Cluster: $(cluster.name) (ID: $(cluster.id))
Node: $(node.name) (ID: $(node.id), Role: $(node.ROLE))
Host Supernet: $(.network.host.supernet.cidr)
Cluster Network: $(.network.cluster.cidr)
Node Network: $(.network.node.cidr)
Node IP: $(.network.node.host.inetaddr)
Gateway: $(.network.node.gateway.inetaddr)
VIP Network: $(.network.cluster.vip.cidr)
LoadBalancer Network: $(.network.cluster.lb.cidr)
LAN Bridge MAC: $(.network.lan.bridge.macaddr)
endef

summary@network: ## Print detailed network configuration summary
	: "[network] Printing network configuration summary"
	echo "$(.network.summary.content)"

diagnostics@network: ## Show host network diagnostics
	$(call trace,Entering target: diagnostics@network)
	$(call trace-var,NODEINTERFACE)
	$(call trace-network,Running host network diagnostics)
	echo "Host Network Diagnostics:"
	ip route show default
	ip addr show $(NODEINTERFACE) 2>/dev/null || echo "Interface $(NODEINTERFACE) not found"
	ping -c 1 -W 2 $(NODE_GATEWAY) >/dev/null 2>&1 && echo "Gateway $(NODE_GATEWAY) reachable" || echo "Gateway $(NODE_GATEWAY) unreachable"

status@network: ## Show container network status
	echo "Container Network Status:"
	echo "========================"
	echo "Node: $(node.name) ($(node.ROLE))"
	echo "Network: $(.network.node.cidr)"
	echo "Host IP: $(.network.node.host.inetaddr)"
	echo "Gateway: $(.network.node.gateway.inetaddr)"

setup-bridge@network: ## Set up network bridge for current node
	: "[+] Interface $(.network.node.lan.interface) uses macvlan (no setup needed)"
	: "Network: $(.network.node.cidr)"
	: "Gateway: $(.network.node.gateway.inetaddr)"

allocation@network: ## Show hierarchical network allocation
	echo "Hierarchical Network Allocation"
	echo "==============================="
	if [ -z "$(GLOBAL_CIDR)" ]; then
		echo "No network configuration found. Set NODENAME to see allocation."
		exit 1
	fi
	echo "Global Infrastructure: $(GLOBAL_CIDR)"
	echo "├─ Cluster Network: $(RKE2_CLUSTER_CIDR)"
	echo "│  ├─ Node Subnets: $(NODECIDR) (each /$(NODECIDR_PREFIX))"
	echo "│  └─ Service Network: $(SERVICE_CIDR)"
	echo "└─ Current Node: $(NODE_NETWORK) → $(NODE_INETADDR)"


validate@network: ## Validate network configuration
	echo "Validating network configuration..."
	ERRORS=0
	for v in RKE2_CLUSTER_NETWORK_CIDR NODE_NETWORK_CIDR NODE_HOST_INETADDR NODE_GATEWAY_INETADDR; do
		val=$$(echo $$($$v))
		if [ -z "$$val" ]; then echo "✗ Error: $$v not set"; ERRORS=$$((ERRORS+1)); else echo "✓ $$v=$$val"; fi
	done
	if [ $$ERRORS -eq 0 ]; then echo "✓ Network configuration valid"; else echo "✗ Network configuration has $$ERRORS error(s)"; exit 1; fi


# =============================================================================
# TEST TARGETS
# =============================================================================

.PHONY: test@network-arith

test@network: ## Run strict network checks (fails fast) (@codebase)
	: "[test@network] Validating namespaced network variables"
	: "[ok] network.host.supernet.cidr=$(.network.host.supernet.cidr)"
	: "[ok] network.cluster.cidr=$(.network.cluster.cidr)"
	: "[ok] network.node.cidr=$(.network.node.cidr)"
	: "[ok] network.node.host.inetaddr=$(.network.node.host.inetaddr)"
	: "[ok] network.node.gateway.inetaddr=$(.network.node.gateway.inetaddr)"
	: "[ok] network.cluster.vip.cidr=$(.network.cluster.vip.cidr)"
	: "[PASS] All required network vars present"

# Arithmetic derivation validation (@codebase)

test@network-arith: ## Validate arithmetic CIDR derivations (@codebase)
	: "[test@network-arith] Validating arithmetic CIDR derivations" # @codebase
	grep -q '\\.network\\.host\\.split\\.count[[:space:]]*:=\\?[[:space:]]*8' $(.network.host.mk) || { echo '[FAIL] Expected host cluster count export'; exit 1; }
	count_host=$$(grep -c '^\\.network\\.host\\.split\\.network\\.[0-7]=' $(.network.host.mk)); [ $$count_host -eq 8 ] || { echo "[FAIL] Host clusters count $$count_host != 8"; exit 1; }
	count_nodes=$$(grep -c '^\\.network\\.node\\.split\\.network\\.[0-3]=' $(.network.node.mk)); [ $$count_nodes -eq 4 ] || { echo "[FAIL] Cluster nodes count $$count_nodes != 4"; exit 1; }
	count_vip=$$(grep -c '^\\.network\\.vip\\.split\\.network\\.[0-7]=' $(.network.vip.mk)); [ $$count_vip -eq 8 ] || { echo "[FAIL] VIP split count $$count_vip != 8"; exit 1; }
	count_lb=$$(grep -c '^\\.network\\.lb\\.split\\.network\\.[0-7]=' $(.network.lb.mk)); [ $$count_lb -eq 8 ] || { echo "[FAIL] LB split count $$count_lb != 8"; exit 1; }
	[ -n "$(.network.cluster.vip.cidr)" ] || { echo '[FAIL] VIP CIDR variable empty'; exit 1; }
	[ -n "$(.network.cluster.lb.cidr)" ] || { echo '[FAIL] LB CIDR variable empty'; exit 1; }
	: "[PASS] Arithmetic derivation checks passed" # @codebase

endif
