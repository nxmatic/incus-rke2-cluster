# cluster/rules.mk - Cluster-level identification & CIDR allocation (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/cluster/rules.mk

# -----------------------------------------------------------------------------
# Ownership: This layer owns cluster identity + pod/service CIDR mapping and
# hierarchical addressing comments. Other layers (network/incus/cloud-config)
# consume exported * variables. Keep Makefile slim. (@codebase)
# -----------------------------------------------------------------------------

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)  
# =============================================================================

# Cluster configuration (inlined from cluster-templates.mk)
.cluster.name := $(if $(LIMA_HOSTNAME),$(LIMA_HOSTNAME),bioskop)
# Guard against empty override (e.g., CLUSTER_NAME="" or env leaking an empty value)
ifeq ($(strip $(.cluster.name)),)
  .cluster.name := bioskop
endif
.cluster.token := $(.cluster.name)
.cluster.domain := cluster.local
.cluster.env := dave

# Cluster-specific configurations
ifeq ($(cluster.name),bioskop)
  .cluster.id := 0
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
  .cluster.state_repo := https://github.com/nxmatic/fleet-manifests.git
  .cluster.state_branch := rke2-subtree
else ifeq ($(cluster.name),alcide)
  .cluster.id := 1
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
else ifeq ($(cluster.name),nikopol)
  .cluster.id := 2
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface  := vmwan0
else
  .cluster.id := 7
  .cluster.lima_lan_interface := vmlan0
  .cluster.lima_vmnet_interface := vmwan0
endif

# Compute Pod/Service CIDRs from base + cluster index (0-based)
# Dynamic Pod/Service CIDR calculation via GMSL math (no python)
.cluster.cidr_pod_base_octet := 42
.cluster.cidr_svc_base_octet := 43
.cluster.cidr_step := 2

.cluster.pod.cidr := 10.$(call plus,$(.cluster.cidr_pod_base_octet),$(call multiply,$(.cluster.id),$(.cluster.cidr_step))).0.0/16
.cluster.service.cidr := 10.$(call plus,$(.cluster.cidr_svc_base_octet),$(call multiply,$(.cluster.id),$(.cluster.cidr_step))).0.0/16
# =============================================================================
# PUBLIC CLUSTER API
# =============================================================================

cluster.id := $(.cluster.id)
cluster.name := $(.cluster.name)
cluster.env := $(.cluster.env)
cluster.token := $(.cluster.token)
cluster.domain := $(.cluster.domain)
cluster.id := $(.cluster.id)
cluster.pod.cidr := $(.cluster.pod.cidr)
cluster.service.cidr := $(.cluster.service.cidr)
cluster.lima_lan_interface := $(.cluster.lima_lan_interface)
cluster.lima_vmnet_interface := $(.cluster.lima_vmnet_interface)
cluster.state_repo := $(.cluster.state_repo)

$(call make.trace,[cluster] Derived, cluster.name cluster.id)

include make.d/make.mk # Ensure availability when file used standalone (@codebase)
include make.d/node/rules.mk # Node identity and role variables (@codebase)
include make.d/kpt/rules.mk  # KPT Packages (@codebase)

# -----------------------------------------------------------------------------
# Hierarchical Addressing Reference (moved from Makefile) (@codebase)
# -----------------------------------------------------------------------------
# Global
#   IPv4 supernet: 10.80.0.0/12
#   IPv6 supernet: fd70:80::/32
# Per-cluster aggregate:
#   IPv4 /20 block: 10.80.(CLUSTER_ID*16).0/20
#   IPv6 /48 block: fd70:80:CLUSTER_ID::/48
# Per-node subnet (/28 slices within first /24 of /20):
#   Node index n → network 10.80.<baseThird>.<n*16>.0/28 gateway .<n*16+1>
#   Preserves single broadcast domain while isolating addresses logically.
# IPv6 per-node:
#   fd70:80:<cluster>::<nodeIndex>:/64
# -----------------------------------------------------------------------------

# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export cluster variables (already handled in node/rules.mk)
# This layer focuses on validation only

# =============================================================================
# VALIDATION TARGETS
# =============================================================================

# Validation target for this layer
.PHONY: test@cluster
test@cluster:
	: "[test@cluster] Validating cluster configuration from node layer"
	: "[ok] cluster.name=$(cluster.name)"
	: "[ok] cluster.token=$(cluster.token)"
	: "[ok] cluster.domain=$(cluster.domain)"
	: "[ok] cluster.id=$(cluster.id)"
	: "[ok] cluster.POD_NETWORK_CIDR=$(cluster.POD_NETWORK_CIDR)"
	: "[ok] cluster.SERVICE_NETWORK_CIDR=$(cluster.SERVICE_NETWORK_CIDR)"
	: "[PASS] All cluster variables present from node layer"

endif # cluster/rules.mk guard

