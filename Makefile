# Makefile for Incus RKE2 Cluster

include make.mk

## Helpers (SUDO, REMOTE_EXEC, INCUS, separators) now provided by make.mk (@codebase)

-include .gmsl/gmsl

.gmsl/gmsl:
	: Loading git sub-modules 
	git submodule update --init --recursive


#-----------------------------
# Topology / Networking Mode
#-----------------------------

# Dual-stack always enabled (@codebase)
# We embed both IPv4 and IPv6 cluster/service CIDRs directly; legacy ENABLE_IPV6
# toggle removed to simplify path. Future per-prefix customization can reintroduce
# derivation, but the control plane and Cilium are now expected to run dual-stack.

NAME ?= $(name)
NAME ?= $(if $(NAME),$(NAME),master)

# Directories
SECRETS_DIR := .secrets.d
RUN_DIR := .run.d
IMAGE_DIR := $(RUN_DIR)/image
RUN_INSTANCE_DIR := $(RUN_DIR)/$(RKE2_NODE_NAME)
INCUS_DIR := $(RUN_INSTANCE_DIR)/incus
NOCLOUD_DIR := $(RUN_INSTANCE_DIR)/nocloud
SHARED_DIR := $(RUN_INSTANCE_DIR)/shared
KUBECONFIG_DIR := $(RUN_INSTANCE_DIR)/kube
LOGS_DIR := $(RUN_INSTANCE_DIR)/logs

# RKE2 Cluster Configuration

# Node name from command line or default to master
RKE2_NODE_NAME ?= $(name)
RKE2_NODE_NAME ?= $(if $(RKE2_NODE_NAME),$(RKE2_NODE_NAME),master)

# Cluster configuration
RKE2_CLUSTER_NAME ?= $(LIMA_HOSTNAME)
RKE2_CLUSTER_TOKEN ?= $(RKE2_CLUSTER_NAME)
RKE2_CLUSTER_DOMAIN := cluster.local

# Infrastructure naming
RKE2_IMAGE_NAME := rke2-control-node

# Determine RKE2 node type and role
ifeq ($(RKE2_NODE_NAME),master)
	RKE2_NODE_TYPE := server
	RKE2_NODE_ROLE := master
else ifneq (,$(findstring peer,$(RKE2_NODE_NAME)))
	RKE2_NODE_TYPE := server
	RKE2_NODE_ROLE := peer
else
	RKE2_NODE_TYPE := agent
	RKE2_NODE_ROLE := worker
endif

# RKE2 Kubernetes network CIDRs (per-cluster allocation)
ifeq (bioskop,$(RKE2_CLUSTER_NAME))
RKE2_POD_NETWORK_CIDR := 10.42.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.43.0.0/16
else ifeq (alcide,$(RKE2_CLUSTER_NAME))
RKE2_POD_NETWORK_CIDR := 10.44.0.0/16
RKE2_SERVICE_NETWORK_CIDR := 10.45.0.0/16
else
$(error No Pod/Service CIDR mapping for cluster: $(RKE2_CLUSTER_NAME))
endif

## ---------------------------------------------------------------------------
## Hierarchical Addressing (unconditional) (@codebase)
## ---------------------------------------------------------------------------
## Global (all clusters):
##   IPv4 supernet: 10.80.0.0/12
##   IPv6 supernet: fd70:80::/32
## Per-cluster aggregate:
##   IPv4 /20 block: 10.80.(CLUSTER_ID*16).0/20  (third octet span of 16 values)
##   IPv6 /48 block: fd70:80:CLUSTER_ID::/48
## Per-node (bridge) subnet (kept compact, same L3 for inter-node reachability):
##   We carve per-node /28s inside a single anchor third octet (the first of the /20)
##   Node index n ⇒ base host offset = n*16; network = 10.80.<baseThird>.<n*16>.0/28
##   Gateway = 10.80.<baseThird>.<n*16 + 1>
##   This yields non-overlapping slices while keeping all nodes within one /24
##   for simpler routing (kernel treats them as same broadcast domain, but we
##   still create distinct bridges; if later consolidated to one bridge the
##   allocations remain valid). (@codebase)
## IPv6: per-node /64 inside cluster /48 ⇒ fd70:80:<cluster>::<nodeIndex>:/64
## ---------------------------------------------------------------------------

# Hierarchical network allocation using ipcalc for proper CIDR splitting
# Infrastructure: 10.80.0.0/18 -> 8 clusters (/21 each) -> N nodes (/23 each)
# HOST_SUPERNET: Physical host network space (Class B)
# CLUSTER_NETWORK: Per-cluster allocation within host supernet  
# NODE_NETWORK: Per-node allocation within cluster network

# Cluster configuration now handled by cluster-config.mk (@codebase)
# RKE2_CLUSTER_ID is automatically set based on RKE2_CLUSTER_NAME

# Network configuration moved to network.mk (@codebase)

# Node configuration now handled by cluster-config.mk (@codebase)
# RKE2_NODE_ID, RKE2_NODE_TYPE, and RKE2_NODE_ROLE are automatically set

# Include layered modules using rules.mk convention (@codebase)
# Skip metaprogramming-heavy modules for help target to avoid evaluation issues
ifneq ($(MAKECMDGOALS),help)
-include network/rules.mk
-include metaprogramming/rules.mk
endif

# Always include core infrastructure modules
-include incus/rules.mk
-include cloud-config/rules.mk


# Legacy compatibility aliases for templates (all logic moved to RKE2_ variables above)
CLUSTER_NAME := $(RKE2_CLUSTER_NAME)
CLUSTER_PODS_CIDR := $(RKE2_POD_NETWORK_CIDR)
CLUSTER_SERVICES_CIDR := $(RKE2_SERVICE_NETWORK_CIDR)
CLUSTER_DOMAIN := $(RKE2_CLUSTER_DOMAIN)
## Legacy 172.31.* addressing overrides removed (@codebase)
## The hierarchical 10.80.* / fd70:80::* assignments defined earlier are authoritative.
## Keeping this comment block to avoid accidental reintroduction.

# =============================================================================
# RKE2 VARIABLE EXPORTS FOR TEMPLATES
# =============================================================================

# Export RKE2 variables for YAML template rendering
export RKE2_CLUSTER_NAME
export RKE2_CLUSTER_TOKEN
export RKE2_CLUSTER_DOMAIN
export RKE2_NODE_NAME
export RKE2_NODE_TYPE
export RKE2_NODE_ROLE
export RKE2_POD_NETWORK_CIDR
export RKE2_SERVICE_NETWORK_CIDR
export RKE2_CLUSTER_ID
export RKE2_NODE_ID

# Bridge configuration moved to network.mk (@codebase)

RKE2_NODE_PROFILE_NAME := rke2-$(RKE2_NODE_NAME)


# Primary/secondary (LAN/WAN) Lima host interfaces (udev renamed) (@codebase)
LIMA_LAN_INTERFACE ?= vmlan0
LIMA_WAN_INTERFACE ?= vmwan0
LIMA_PRIMARY_INTERFACE := $(LIMA_LAN_INTERFACE)
LIMA_SECONDARY_INTERFACE := $(LIMA_WAN_INTERFACE)

# Network mode for preseed template
NETWORK_MODE := L2-bridge

# Host interface to use for cluster egress traffic (using LAN bridge for LoadBalancer access)
INCUS_EGRESS_INTERFACE := $(LIMA_PRIMARY_INTERFACE)
export INCUS_EGRESS_INTERFACE

#-----------------------------
# Tailscale Configuration
#-----------------------------
TSID ?= $(file <$(SECRETS_DIR)/tsid)
TSKEY_CLIENT ?= $(file <$(SECRETS_DIR)/tskey-client)
TSKEY_API ?= $(file <$(SECRETS_DIR)/tskey-api)

# After interface rename (big-bang) eth0→lan0, eth1→wan0.
# WAN hosts VIP, lan0 is LAN bridge. For host container IPv4 detection we now use wan0 (NAT side)
INCUS_INET_YQ_EXPR := .[].state.network.wan0.addresses[] | select(.family == "inet") | .address
define INCUS_INET_CMD
$(shell incus list $(1) --format=yaml | yq eval '$(INCUS_INET_YQ_EXPR)' -)
endef

define RKE2_MASTER_TOKEN_TEMPLATE
# Bootstrap server points at the master primary IP (CLUSTER_INET_MASTER now mapped to primary) (@codebase)
server: https://$(CLUSTER_INET_MASTER):9345
token: $(CLUSTER_TOKEN)
endef

# Config Paths
## Templates now use existing Makefile variables directly (CLUSTER_* etc.) so no extra exports required.

INCUS_PRESSED_FILENAME := incus-preseed.yaml
INCUS_PRESSED_FILE := $(INCUS_DIR)/preseed.yaml

INCUS_DISTROBUILDER_FILE := ./incus-distrobuilder.yaml
INCUS_DISTROBUILDER_LOGFILE := $(IMAGE_DIR)/distrobuilder.log

INCUS_IMAGE_IMPORT_MARKER_FILE := $(IMAGE_DIR)/import.tstamp
INCUS_IMAGE_BUILD_FILES := $(IMAGE_DIR)/incus.tar.xz $(IMAGE_DIR)/rootfs.squashfs

INCUS_CREATE_PROJECT_MARKER_FILE := $(INCUS_DIR)/create-project.tstamp
INCUS_BRIDGE_SETUP_MARKER_FILE := $(INCUS_DIR)/bridge-setup.tstamp
INCUS_CONFIG_INSTANCE_MARKER_FILE := $(INCUS_DIR)/init-instance.tstamp

INCUS_INSTANCE_CONFIG_FILENAME := incus-instance-config.yaml
INCUS_INSTANCE_CONFIG_FILE := $(INCUS_DIR)/config.yaml
INCUS_ZFS_ALLOW_MARKER_FILE := $(INCUS_DIR)/zfs-allow.tstamp

NOCLOUD_METADATA_FILE := $(NOCLOUD_DIR)/metadata
NOCLOUD_USERDATA_FILE := $(NOCLOUD_DIR)/userdata
NOCLOUD_NETCFG_FILE := $(NOCLOUD_DIR)/network-config

#-----------------------------

# Network mode for preseed template
NETWORK_MODE := L2-bridge

# Export essential variables for YAML template rendering
export NETWORK_MODE
export LIMA_PRIMARY_INTERFACE
export LIMA_LAN_INTERFACE
export LIMA_WAN_INTERFACE
export TSID
export TSKEY := $(TSKEY_CLIENT)

# Directory exports for templates
export RUN_INSTANCE_DIR
export NOCLOUD_USERDATA_FILE
export NOCLOUD_METADATA_FILE
export NOCLOUD_NETCFG_FILE

.PHONY: all start stop delete clean shell

# Make help the default target (@codebase)
.DEFAULT_GOAL := help

.PHONY: debug-trace help


.PHONY: help
help: ## Show this help message with available targets
	$(make-help)

all: start ## Build and start the default RKE2 node (master)

# Advanced metaprogramming-powered shortcuts (@codebase)
.PHONY: debug status scale
debug: debug-variables show-runtime-config ## Debug variable construction and runtime config
status: status-report check-runtime-state ## Show comprehensive cluster and runtime status
scale: scale-cluster-resources ## Scale cluster resources (memory/CPU) for all nodes

#-----------------------------
# High-Level Target Aliases
#-----------------------------

# Main lifecycle targets (delegate to incus.mk)
start: start@incus ## Start RKE2 node instance (creates if needed)
stop: stop@incus ## Stop running RKE2 node instance
delete: delete@incus ## Delete RKE2 node instance (keeps config) 
clean: clean@incus ## Clean RKE2 node (delete instance + config)
shell: shell@incus ## Open interactive shell in RKE2 node
instance: instance@incus ## Create RKE2 instance without starting

# Ensure dependencies for main targets
$(MAIN_TARGETS): preseed@incus image@incus switch-project@incus

.PHONY: $(MAIN_TARGETS)

# High-level cluster management
clean-all: clean-all@incus ## Clean all nodes in cluster (destructive)

#-----------------------------
# Generate $(INCUS_INSTANCE_CONFIG_FILE) directly from template (envsubst pass only)
#-----------------------------
$(INCUS_INSTANCE_CONFIG_FILE): $(INCUS_INSTANCE_CONFIG_FILENAME)
$(INCUS_INSTANCE_CONFIG_FILE): $(NOCLOUD_METADATA_FILE) $(NOCLOUD_USERDATA_FILE) $(NOCLOUD_NETCFG_FILE)
$(INCUS_INSTANCE_CONFIG_FILE):
	@: "[+] Rendering instance config (envsubst via yq) ..."
	yq eval '( ... | select(tag=="!!str") ) |= envsubst(ne,nu)' $(INCUS_INSTANCE_CONFIG_FILENAME) > $(@)

# Cloud-config generation now handled by cloud-config/rules.mk (@codebase)

#-----------------------------
# Lint: YAML (yamllint)  
#-----------------------------
YAML_FILES := $(wildcard cloud-config.*.yaml incus-*.yaml)

# Layer target aliases for clean interface (@codebase)
.PHONY: network host-network vm-network bridge-setup show-allocation validate-network
.PHONY: validate-cloud-config lint-cloud-config debug-cloud-config-merge show-cloud-config-files  
.PHONY: show-metaprogramming-features list-generated-targets enable-metaprogramming disable-metaprogramming
.PHONY: lint-yaml

# Network layer aliases
network: summary@network ## Show network configuration summary
host-network: diagnostics@network ## Show host network diagnostics
vm-network: status@network ## Show container network status
bridge-setup: setup-bridge@network ## Set up network bridge for current node
show-allocation: allocation@network ## Show hierarchical network allocation
validate-network: validate@network ## Validate network configuration

# Cloud-config layer aliases
validate-cloud-config: validate@cloud-config ## Validate merged cloud-config
lint-cloud-config: lint@cloud-config ## Lint cloud-config YAML files
debug-cloud-config-merge: debug-merge@cloud-config ## Debug cloud-config merge process
show-cloud-config-files: show-files@cloud-config ## Show cloud-config files for current node type

# Metaprogramming layer aliases
show-metaprogramming-features: features@meta ## Show available metaprogramming features
list-generated-targets: targets@meta ## List all metaprogramming-generated targets
enable-metaprogramming: enable@meta ## Enable advanced metaprogramming features
disable-metaprogramming: disable@meta ## Disable metaprogramming (use basic targets only)

# Utility targets
lint-yaml: ## Lint YAML configuration files
	@: "[+] Running yamllint on YAML source files"
	yamllint $(YAML_FILES)

# Advanced targets (from metaprogramming modules) (@codebase)
.PHONY: start-master start-peer1 start-worker1 debug-variables show-runtime-config
start-master: ## Start master node (control plane bootstrap)
start-peer1: ## Start peer1 node (control plane join)
start-worker1: ## Start worker1 node (worker join)
debug-variables: ## Show constructed variable values for debugging
show-runtime-config: ## Display auto-generated runtime configuration

#-----------------------------
# Create necessary directories
#-----------------------------
%/:
	mkdir -p $(@)

