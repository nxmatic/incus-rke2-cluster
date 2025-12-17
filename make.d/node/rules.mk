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
.cluster.TOKEN ?= $(.cluster.name)
.cluster.DOMAIN = cluster.local

# Cluster-specific configurations
ifeq ($(.cluster.name),bioskop)
  .cluster.id := 1
  .cluster.POD_NETWORK_CIDR := 10.42.0.0/16
  .cluster.SERVICE_NETWORK_CIDR := 10.43.0.0/16
  .cluster.LIMA_LAN_INTERFACE := vmlan0
  .cluster.LIMA_VMNET_INTERFACE := vmwan0
  .cluster.STATE_REPO := https://github.com/nxmatic/fleet-manifests.git
  .cluster.STATE_BRANCH := rke2-subtree
else ifeq ($(.cluster.name),alcide)
  .cluster.id := 2
  .cluster.POD_NETWORK_CIDR := 10.44.0.0/16
  .cluster.SERVICE_NETWORK_CIDR := 10.45.0.0/16
  .cluster.LIMA_LAN_INTERFACE := vmlan0
  .cluster.LIMA_VMNET_INTERFACE := vmwan0
  .cluster.STATE_REPO := https://github.com/nxmatic/fleet-manifests.git
  .cluster.STATE_BRANCH := rke2-subtree
else ifeq ($(.cluster.name),nikopol)
  .cluster.id := 2
  .cluster.POD_NETWORK_CIDR := 10.44.0.0/16
  .cluster.SERVICE_NETWORK_CIDR := 10.45.0.0/16
  .cluster.LIMA_LAN_INTERFACE := vmlan0
  .cluster.LIMA_VMNET_INTERFACE := vmwan0
  .cluster.STATE_REPO := https://github.com/nxmatic/fleet-manifests.git
  .cluster.STATE_BRANCH := rke2-subtree
else
  $(error [node] Unknown cluster: $(.cluster.name). Supported clusters: bioskop alcide nikopol)
endif

# Public cluster API
cluster.name := $(.cluster.name)
cluster.TOKEN := $(.cluster.TOKEN)
cluster.DOMAIN := $(.cluster.DOMAIN)
cluster.id := $(.cluster.id)
cluster.POD_NETWORK_CIDR := $(.cluster.POD_NETWORK_CIDR)
cluster.SERVICE_NETWORK_CIDR := $(.cluster.SERVICE_NETWORK_CIDR)
cluster.LIMA_LAN_INTERFACE := $(.cluster.LIMA_LAN_INTERFACE)
cluster.LIMA_VMNET_INTERFACE := $(.cluster.LIMA_VMNET_INTERFACE)
cluster.STATE_REPO := $(.cluster.STATE_REPO)
cluster.STATE_BRANCH := $(.cluster.STATE_BRANCH)

# Export cluster variables for environment/templates
export CLUSTER_NAME := $(cluster.name)
export CLUSTER_TOKEN := $(cluster.TOKEN)
export CLUSTER_DOMAIN := $(cluster.DOMAIN)
export CLUSTER_ID := $(cluster.id)
export POD_NETWORK_CIDR := $(cluster.POD_NETWORK_CIDR)
export SERVICE_NETWORK_CIDR := $(cluster.SERVICE_NETWORK_CIDR)
export LIMA_LAN_INTERFACE := $(cluster.LIMA_LAN_INTERFACE)
export LIMA_VMNET_INTERFACE := $(cluster.LIMA_VMNET_INTERFACE)

# =============================================================================
# NODE CONFIGURATION APPLICATION
# =============================================================================

# Node configuration data (inlined from cluster-templates.mk)
.node.CONFIG_master = server master 0
.node.CONFIG_peer1 := server peer 1  
.node.CONFIG_peer2 := server peer 2
.node.CONFIG_peer3 := server peer 3
.node.CONFIG_worker1 := agent worker 10
.node.CONFIG_worker2 := agent worker 11

# Macro to extract node attributes from .node.CONFIG_* variables
# Usage: $(call get-node-attr,NODE_NAME,POSITION)
# Example: $(call get-node-attr,peer1,1) returns "server"
define get-node-attr
$(word $(2),$(.node.CONFIG_$(1)))
endef

# Derive node role/type using metaprogramming lookup
ifdef .node.CONFIG_$(.node.name)
  .node.TYPE := $(call get-node-attr,$(.node.name),1)
  .node.ROLE := $(call get-node-attr,$(.node.name),2)
  .node.id := $(call get-node-attr,$(.node.name),3)
else
  $(error [node] Unknown node: $(.node.name). Supported nodes: master peer1 peer2 peer3 worker1 worker2)
endif

# Public node API
node.name := $(.node.name)
node.TYPE := $(.node.TYPE)
node.ROLE := $(.node.ROLE)
node.id := $(.node.id)

# Export node variables for environment/templates
export NODE_NAME := $(node.name)
export NODE_TYPE := $(node.TYPE)
export NODE_ROLE := $(node.ROLE)
export NODE_ID := $(node.id)

# Validation target for node layer
.PHONY: test@node

test@node:
	: "[test@node] Validating node role/type derivation"
	: "[ok] node.name=$(node.name)"
	: "[ok] node.TYPE=$(node.TYPE)" 
	: "[ok] node.ROLE=$(node.ROLE)"
	: "[ok] node.id=$(node.id)"
	: "[ok] .node.config_key=$(.node.config_key)"
	: "[PASS] Node variables present"



endif # make.d/node/rules.mk

