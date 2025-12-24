# node/rules.mk - Node identity & role/type derivation (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/node/rules.mk

-include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Ownership: This layer determines node-specific variables (name, type, role, ID).
# Makefile should not contain ifeq chains for role derivation. Other layers use
# exported NODE_* vars. (@codebase)
# -----------------------------------------------------------------------------

# Accept NAME override; default master
.node.name ?= $(if $(name),$(name),master)

# Node configuration lookup key for .node-config.* rules
.node.config_key = .node-config.$(.node.name)

# Cluster configuration (inlined from cluster-templates.mk)
.cluster.name ?= $(if $(LIMA_HOSTNAME),$(LIMA_HOSTNAME),bioskop)
.cluster.token ?= $(.cluster.name)
.cluster.domain = cluster.local

# Dynamic Pod/Service CIDR calculation via GMSL math (no python)
cidr_pod_base_octet := 42
cidr_svc_base_octet := 43
cidr_step := 2

# Cluster-specific configurations
ifeq ($(.cluster.name),bioskop)
  .cluster.id := 0
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
  .cluster.state_repo := https://github.com/nxmatic/fleet-manifests.git
  .cluster.state_branch := rke2-subtree
else ifeq ($(.cluster.name),alcide)
  .cluster.id := 1
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
else ifeq ($(.cluster.name),nikopol)
  .cluster.id := 2
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface  := vmwan0
else
  .cluster.id := 7
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
endif

# Compute Pod/Service CIDRs from base + cluster index (0-based)
.cluster.pod_network_cidr := 10.$(call plus,$(cidr_pod_base_octet),$(call multiply,$(.cluster.id),$(cidr_step))).0.0/16
.cluster.service_network_cidr := 10.$(call plus,$(cidr_svc_base_octet),$(call multiply,$(.cluster.id),$(cidr_step))).0.0/16

# Public cluster API
cluster.id := $(.cluster.id)
cluster.name := $(.cluster.name)
cluster.token := $(.cluster.token)
cluster.domain := $(.cluster.domain)
cluster.id := $(.cluster.id)
cluster.pod_network_cidr := $(.cluster.pod_network_cidr)
cluster.service_network_cidr := $(.cluster.service_network_cidr)
cluster.lima_lan_interface := $(.cluster.lima_lan_interface)
cluster.lima_vmnet_interface := $(.cluster.lima_vmnet_interface)
cluster.state_repo := $(.cluster.state_repo)
cluster.state_branch := $(.cluster.state_branch)

# =============================================================================
# NODE CONFIGURATION APPLICATION
# =============================================================================

# Node configuration data (inlined from cluster-templates.mk)
.node.config.master = server master 0
.node.config.peer1 := server peer 1  
.node.config.peer2 := server peer 2
.node.config.peer3 := server peer 3
.node.config.worker1 := agent worker 10
.node.config.worker2 := agent worker 11

# Macro to extract node attributes from .node.CONFIG_* variables
# Usage: $(call get-node-attr,NODE_NAME,POSITION)
# Example: $(call get-node-attr,peer1,1) returns "server"
define get-node-attr
$(word $(2),$(.node.config.$(1)))
endef

# Derive node role/type using metaprogramming lookup
ifdef .node.config.$(.node.name)
  .node.type := $(call get-node-attr,$(.node.name),1)
  .node.role := $(call get-node-attr,$(.node.name),2)
  .node.id := $(call get-node-attr,$(.node.name),3)
else
  $(error [node] Unknown node: $(.node.name). Supported nodes: master peer1 peer2 peer3 worker1 worker2)
endif

# Public node API
node.name := $(.node.name)
node.type := $(.node.type)
node.role := $(.node.role)
node.id := $(.node.id)

# Export node variables for environment/templates
export NODE_NAME := $(node.name)
export NODE_TYPE := $(node.type)
export NODE_ROLE := $(node.role)
export NODE_ID := $(node.id)

# Validation target for node layer
.PHONY: test@node

test@node: ## Validate node role/type derivation
  : "[ok] cluster.id=$(cluster.id)"
  : "[ok] cluster.name=$(cluster.name)"
	: "[ok] node.name=$(node.name)"
	: "[ok] node.type=$(node.type)" 
	: "[ok] node.role=$(node.role)"
	: "[ok] node.id=$(node.id)"
	: "[ok] .node.config_key=$(.node.config_key)"
	: "[PASS] Node variables present"

endif # make.d/node/rules.mk

