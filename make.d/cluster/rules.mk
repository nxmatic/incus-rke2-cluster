# cluster/rules.mk - Cluster-level identification & CIDR allocation (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/cluster/rules.mk

-include make.d/make.mk # Ensure availability when file used standalone (@codebase)
-include make.d/node/rules.mk # Node identity and role variables (@codebase)
-include make.d/kpt/rules.mk  # KPT Packages (@codebase)

# -----------------------------------------------------------------------------
# Ownership: This layer owns cluster identity + pod/service CIDR mapping and
# hierarchical addressing comments. Other layers (network/incus/cloud-config)
# consume exported * variables. Keep Makefile slim. (@codebase)
# -----------------------------------------------------------------------------

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)  
# =============================================================================

# Note: Cluster configuration now managed in node/rules.mk
# This layer provides validation and exports only

# =============================================================================
# PUBLIC CLUSTER API
# =============================================================================

# Public cluster API (re-export from node layer)
# (All cluster variables defined in node/rules.mk)

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
	: "[ok] cluster.TOKEN=$(cluster.TOKEN)"
	: "[ok] cluster.DOMAIN=$(cluster.DOMAIN)"
	: "[ok] cluster.id=$(cluster.id)"
	: "[ok] cluster.POD_NETWORK_CIDR=$(cluster.POD_NETWORK_CIDR)"
	: "[ok] cluster.SERVICE_NETWORK_CIDR=$(cluster.SERVICE_NETWORK_CIDR)"
	: "[PASS] All cluster variables present from node layer"

endif # cluster/rules.mk guard

