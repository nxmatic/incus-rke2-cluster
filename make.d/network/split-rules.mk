# network-split-rules.mk - Subnet generation rules (@codebase)
# Self-guarding include for subnet generation

ifndef make.d/network/split-rules.mk
make.d/network/split-rules.mk := make.d/network/split-rules.mk

# Template function to generate subnet rules for a specific type
# Usage: $(call define-subnet-rules,TYPE,dependency,network_expr,prefix,description)
rke2.d/network/%.mk: ## Generate $(*) subnet definitions
	: "[+] ($(1)) generating $(@) via ipcalc type=$(type) network=$(network) prefix=$(prefix)  (level=$(MAKELEVEL) restart=$(MAKE_RESTARTS))" # @codebase
	mkdir -p $$(dirname $(@))
	set -a
	TYPE=$(type)
	NETWORK=$(network)
	source <( ipcalc --json --split $(prefix) $(network) |
		      yq -p json -o shell )
	set +a
	cat <<EoF > $(@)
	# Generated network subnet definitions for type=$(type) network=$(network) prefix=$(prefix)
	$(warning [network] Loading $(*))
	.network.$(type).eval := eval
	.network.$(type).call := call
	
	.network.$(type).split.network := $(network)
	.network.$(type).split.prefix := $(prefix)
	.network.$(type).split.count := $${NETS}
	.network.$(type).split.addresses := $${ADDRESSES}
	$$( for SPLITNETWORK in $${!SPLITNETWORK@}; do ipcalc --json "$${!SPLITNETWORK}"; done |
		yq -p json -o shell ea '[ . | with_entries( .key |= downcase ) |
		                          . + { "cidr" : (.network + "/" + (.prefix)) } ]' - |
		sed -e 's/_/./g' -e 's/^/.network.$(type).split/'
	)
	EoF

define .network.split.rule
ifndef .network.split.rule.$(1)
.network.split.rule.$(1) := .network.split.rule.$(1)

$$(.network.cluster.dir): $$(.network.$(1).mk)
$(if $(2),$$(.network.$(1).mk): $(2),)
$$(.network.$(1).mk): $(2)
$$(.network.$(1).mk): type=$(1)
$$(.network.$(1).mk): network=$(3)
$$(.network.$(1).mk): prefix := $(4)
$$(.network.$(1).mk): make.d/network/rules.mk | $$(.network.dir)/
endif # .network.split.rule.$(1)
endef

$(.network.cluster.dir): | $(.network.cluster.dir)/
	: "Generated network directory $@" # @codebase

# Generate rules for each subnet type (use immediate expansion to resolve variables)
.network.host.mk := $(.network.dir)/host.mk
.network.node.mk := $(.network.dir)/node.mk
.network.vip.mk := $(.network.dir)/vip.mk
.network.lb.mk := $(.network.dir)/lb.mk
.network.lan.mk := $(.network.dir)/lan.mk

.network.mks := $(.network.host.mk) $(.network.node.mk) $(.network.vip.mk) $(.network.lb.mk) $(.network.lan.mk)
.network.subnets.mks := $(.network.mks)

# Existence predicates (treat empty/generated-but-blank files as missing) (@codebase)
.network.host.exists := $(and $(wildcard $(.network.host.mk)),$(strip $(.network.host.split.network)))
.network.node.exists := $(and $(wildcard $(.network.node.mk)),$(strip $(.network.node.split.network)))


# Guarded generation using function conditionals
$(if $(.network.host.exists), \
	$(eval $(call .network.split.rule,vip,$$(.network.host.mk),$$(.network.host.cluster.cidr),24,VIP subnet allocation for control plane)) \
	$(if $(.network.node.exists), \
	$(eval $(call .network.split.rule,lb,$$(.network.node.mk),$$(.network.node.base.cidr),26,LoadBalancer subnet allocation within node network)) \
		$(eval $(call .network.split.rule,lan,,$$(.network.lan.cidr),27,Home LAN subnet allocation for clusters)), \
		$(eval $(call .network.split.rule,node,$$(.network.host.mk),$$(.network.host.cluster.cidr),23,node-level subnet allocation within cluster)) \
		$(warning [network] node.mk missing; rebuilding it will trigger makefile restart to wire node/vip/lb/lan splits)), \
	$(eval $(call .network.split.rule,host,,10.80.0.0/18,21,host-level subnet allocation from super-network)) \
	$(eval $(call .network.split.rule,node,$$(.network.host.mk),$$(.network.host.cluster.cidr),23,node-level subnet allocation within cluster)) \
	$(eval $(call .network.split.rule,vip,$$(.network.host.mk),$$(.network.host.cluster.cidr),24,VIP subnet allocation for control plane)) \
	$(eval $(call .network.split.rule,lb,$$(.network.node.mk),$$(.network.node.base.cidr),26,LoadBalancer subnet allocation within node network)) \
	$(eval $(call .network.split.rule,lan,,$$(.network.lan.cidr),27,Home LAN subnet allocation for clusters)) \
	$(warning [network] host.mk missing; rebuilding it will trigger makefile restart to wire node/vip/lb/lan splits))

endif
