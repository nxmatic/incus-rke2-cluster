# cluster/rules.mk - Cluster-level identification & CIDR allocation (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef cluster/rules.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

# -----------------------------------------------------------------------------
# Ownership: This layer owns cluster identity + pod/service CIDR mapping and
# hierarchical addressing comments. Other layers (network/incus/cloud-config)
# consume exported RKE2_* variables. Keep Makefile slim. (@codebase)
# -----------------------------------------------------------------------------

# Cluster identity (may already be set in parent; provide defaults)
RKE2_CLUSTER_NAME ?= $(LIMA_HOSTNAME)
RKE2_CLUSTER_TOKEN ?= $(RKE2_CLUSTER_NAME)
RKE2_CLUSTER_DOMAIN ?= cluster.local

# Pod/Service CIDR mapping (previously inline in Makefile)
ifeq (bioskop,$(RKE2_CLUSTER_NAME))
  RKE2_POD_NETWORK_CIDR ?= 10.42.0.0/16
  RKE2_SERVICE_NETWORK_CIDR ?= 10.43.0.0/16
else ifeq (alcide,$(RKE2_CLUSTER_NAME))
  RKE2_POD_NETWORK_CIDR ?= 10.44.0.0/16
  RKE2_SERVICE_NETWORK_CIDR ?= 10.45.0.0/16
else
  $(error [cluster] No Pod/Service CIDR mapping for cluster: $(RKE2_CLUSTER_NAME))
endif

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

# Export cluster-layer variables for downstream envsubst usage
export RKE2_CLUSTER_NAME
export RKE2_CLUSTER_TOKEN
export RKE2_CLUSTER_DOMAIN
export RKE2_POD_NETWORK_CIDR
export RKE2_SERVICE_NETWORK_CIDR

# Validation target for this layer
.PHONY: test@cluster

test@cluster:
	@echo "[test@cluster] Validating cluster CIDR mapping"; \
	missing=0; \
	for v in RKE2_CLUSTER_NAME RKE2_CLUSTER_TOKEN RKE2_CLUSTER_DOMAIN RKE2_POD_NETWORK_CIDR RKE2_SERVICE_NETWORK_CIDR; do \
	  val=$$(eval echo "$$"$$v); \
	  if [ -z "$$val" ]; then echo "[!] Missing $$v"; missing=$$((missing+1)); else echo "[ok] $$v=$$val"; fi; \
	done; \
	if [ $$missing -gt 0 ]; then echo "[FAIL] $$missing cluster vars missing"; exit 1; else echo "[PASS] Cluster variables present"; fi

endif # cluster/rules.mk guard

