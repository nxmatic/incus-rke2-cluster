# node/rules.mk - Node identity & role/type derivation (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef node/rules.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Ownership: This layer determines node-specific variables (name, type, role, ID).
# Makefile should not contain ifeq chains for role derivation. Other layers use
# exported RKE2_NODE_* vars. (@codebase)
# -----------------------------------------------------------------------------

# Accept NAME override; default master
RKE2_NODE_NAME ?= $(if $(NAME),$(NAME),master)

# Derive node role/type
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

# Node ID derivation (simple mapping; extend if more peers/workers added)
# Provide default index assignments; customize via metaprogramming layer later.
ifeq ($(RKE2_NODE_ROLE),master)
  RKE2_NODE_ID ?= 0
else ifeq ($(RKE2_NODE_NAME),peer1)
  RKE2_NODE_ID ?= 1
else ifeq ($(RKE2_NODE_NAME),peer2)
  RKE2_NODE_ID ?= 2
else ifeq ($(RKE2_NODE_NAME),peer3)
  RKE2_NODE_ID ?= 3
else ifeq ($(RKE2_NODE_NAME),worker1)
  RKE2_NODE_ID ?= 10
else ifeq ($(RKE2_NODE_NAME),worker2)
  RKE2_NODE_ID ?= 11
else
  RKE2_NODE_ID ?= 99
endif

# Export node-layer variables
export RKE2_NODE_NAME
export RKE2_NODE_TYPE
export RKE2_NODE_ROLE
export RKE2_NODE_ID

# Validation target for node layer
.PHONY: test@node

test@node:
	@echo "[test@node] Validating node role/type derivation"; \
	missing=0; \
	for v in RKE2_NODE_NAME RKE2_NODE_TYPE RKE2_NODE_ROLE RKE2_NODE_ID; do \
	  val=$$(eval echo "$$"$$v); \
	  if [ -z "$$val" ]; then echo "[!] Missing $$v"; missing=$$((missing+1)); else echo "[ok] $$v=$$val"; fi; \
	done; \
	if [ $$missing -gt 0 ]; then echo "[FAIL] $$missing node vars missing"; exit 1; else echo "[PASS] Node variables present"; fi

endif # node/rules.mk

