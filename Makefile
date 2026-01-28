# Makefile for Incus RKE2 Cluster

# NOTE (@codebase): Incus-specific variables (directories, image artifacts, NoCloud paths,
# Tailscale secrets, network mode, instance config rendering, cluster env file generation)
# have been relocated to `incus/rules.mk` for clearer layer ownership. This Makefile now
# focuses on high-level orchestration and legacy aliases only. Avoid reintroducing those
# definitions here; extend `incus/rules.mk` instead.

include make.d/make.mk

## Helpers (SUDO, REMOTE_EXEC, INCUS, separators) now provided by make.mk (@codebase)
# Use NixOS sudo wrapper if available, fallback to system sudo
SUDO := $(shell test -x /run/wrappers/bin/sudo && echo /run/wrappers/bin/sudo || command -v sudo)

# Remote execution for Lima VM - auto-detect if we're on macOS host vs NixOS guest
LIMA_HOST := lima-nerd-nixos
REMOTE_EXEC := $(shell if [ -x /run/wrappers/bin/sudo ]; then echo ""; else echo "ssh $(LIMA_HOST)"; fi)

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

## Incus image naming now owned by incus/rules.mk (@codebase)

## Node role/type derivation moved to node/rules.mk (@codebase)

## Pod/Service CIDR mapping now owned by cluster/rules.mk (@codebase)

## Hierarchical addressing reference moved to cluster/rules.mk (@codebase)

# Hierarchical network allocation using ipcalc for proper CIDR splitting
# Infrastructure: 10.80.0.0/18 -> 8 clusters (/21 each) -> N nodes (/23 each)
# HOST_SUPERNET: Physical host network space (Class B)
# CLUSTER_NETWORK: Per-cluster allocation within host supernet  
# NODE_NETWORK: Per-node allocation within cluster network

# Cluster configuration now handled by cluster-config.mk (@codebase)
# CLUSTER_ID is automatically set based on CLUSTER_NAME

# Network configuration moved to network.mk (@codebase)

# Node configuration now handled by cluster-config.mk (@codebase)
# NODE_ID, NODE_KIND, and NODE_ROLE are automatically set

# Include layered modules using rules.mk convention (@codebase)
-include make.d/rke2.mk
-include make.d/cluster/rules.mk
-include make.d/node/rules.mk
-include make.d/network/rules.mk
-include make.d/plantuml/rules.mk
-include make.d/cloud-config/rules.mk
-include make.d/incus/rules.mk
-include make.d/kpt/rules.mk

# Legacy compatibility aliases for templates (all logic moved to  variables above)
CLUSTER_NAME := $(CLUSTER_NAME)
CLUSTER_PODS_CIDR := $(POD_NETWORK_CIDR)
CLUSTER_SERVICES_CIDR := $(SERVICE_NETWORK_CIDR)
CLUSTER_DOMAIN := $(CLUSTER_DOMAIN)
## Legacy 172.31.* addressing overrides removed (@codebase)
## The hierarchical 10.80.* / fd70:80::* assignments defined earlier are authoritative.
## Keeping this comment block to avoid accidental reintroduction.


# Bridge configuration moved to network.mk (@codebase)

NODE_PROFILE_NAME := rke2-cluster


## Host interface definitions & NETWORK_MODE relocated to incus/rules.mk (@codebase)

## Tailscale secret loading, inet helpers moved to incus/rules.mk (@codebase)

# Config Paths
## Templates now use existing Makefile variables directly (CLUSTER_* etc.) so no extra exports required.

## Incus artifact paths & NoCloud file variables moved to incus/rules.mk (@codebase)

#-----------------------------

## Template environment exports now performed inside incus/rules.mk (@codebase)

## Cluster environment file generation handled in incus/rules.mk (@codebase)

.PHONY: all start stop delete clean shell

# Make help the default target (@codebase)
.DEFAULT_GOAL := help

.PHONY: debug-trace help

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
clean: clean@network clean@incus ## Clean all generated files
shell: shell@incus ## Open interactive shell in RKE2 node
instance: instance@incus ## Create RKE2 instance without starting

# Ensure dependencies for lifecycle targets explicitly (avoid undefined MAIN_TARGETS variable) (@codebase)
start stop delete shell instance: preseed@incus image@incus switch-project@incus

.PHONY: start stop delete clean shell instance clean-project clean-orphaned

# High-level cluster management  
.PHONY: clean-all clean-project clean-orphaned

clean-all: clean-project ## Clean everything - removes entire RKE2 project, all resources, and local files (destructive)
clean-all: clean@network
clean-all: cleanup-orphaned-networks@incus

clean-project: remove-project@incus ## Remove entire RKE2 project including all resources
clean-orphaned: cleanup-orphaned-networks@incus ## Clean up orphaned networks and profiles in default project

## Instance config rendering & cluster validation relocated to incus/rules.mk (@codebase)

# Cloud-config generation now handled by cloud-config/rules.mk (@codebase)

#-----------------------------
# Lint: YAML (yamllint)  
#-----------------------------
YAML_FILES := $(make-dir)/cloud-config/$(wildcard cloud-config.*.yaml incus-*.yaml)

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

.PHONY: docs-diagrams
docs-diagrams: diagrams@plantuml ## Regenerate committed PlantUML diagrams (alias)

# Advanced targets (from metaprogramming modules) (@codebase)
.PHONY: debug-variables show-runtime-config

debug-variables: ## Show constructed variable values for debugging
show-runtime-config: ## Display auto-generated runtime configuration
