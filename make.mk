# make.mk - Centralized Make macros, environment, helpers (@codebase)
# -----------------------------------------------------------------------------
# Provides:
#   - Trace mode parsing (.trace variable)
#   - Shell configuration (Bash flags, optional -x when shell tracing)
#   - Global .ONESHELL and .SILENT directives
#   - Trace output macros (trace, trace-var, trace-incus, trace-network)
#   - Common helper variables (SUDO, REMOTE_EXEC)
#   - Dynamic grouped help system with optional filtering
# -----------------------------------------------------------------------------

# User-specified trace control: comma-separated list of modes.
.trace ?=

# Early default for RKE2_NODE_NAME so network layer has a value; simple non-recursive default.
RKE2_NODE_NAME ?= master

empty :=
space := $(empty) $(empty)
comma := ,

# Parse trace modes (convert comma-separated to space-separated)
_trace_modes = $(strip $(subst $(comma), ,$(.trace)))
_has_trace = $(if $(filter $(1),$(_trace_modes)),yes,)

# Shell configuration based on trace modes
_shell_opts := --noprofile --norc -euo pipefail
ifneq ($(call _has_trace,shell),)
_shell_opts += -x
endif
SHELL := /bin/bash $(_shell_opts)

.ONESHELL:
.SILENT:

_trace_shell    = $(call _has_trace,shell)
_trace_vars     = $(call _has_trace,vars)
_trace_targets  = $(call _has_trace,targets)
_trace_incus    = $(call _has_trace,incus)
_trace_network  = $(call _has_trace,network)
_trace_oneshell = $(call _has_trace,oneshell)

# Trace macros ---------------------------------------------------------------
ifneq ($(call _has_trace,targets),)
define trace
$(info [TRACE] $(1))
endef
else
define trace
endef
endif

ifneq ($(call _has_trace,vars),)
define trace-var
$(info [TRACE] $(1) = $($(1)))
endef
else
define trace-var
endef
endif

ifneq ($(call _has_trace,incus),)
define trace-incus
$(info [TRACE] Incus: $(1))
endef
else
define trace-incus
endef
endif

ifneq ($(call _has_trace,network),)
define trace-network
$(info [TRACE] Network: $(1))
endef
else
define trace-network
endef
endif

# SUDO wrapper detection (works on NixOS or fallback to system sudo)
SUDO := $(shell test -x /run/wrappers/bin/sudo && echo /run/wrappers/bin/sudo || command -v sudo)

# Remote execution detection (macOS host vs NixOS guest) - depends on LIMA_HOSTNAME
LIMA_HOST ?= $(LIMA_HOSTNAME)
# Remote execution: when running from macOS (no /run/wrappers/bin/sudo), wrap commands to
#   1. ssh into Lima host
#   2. cd into the bind-mounted repo path matching current relative path
#   3. activate flox environment (if available) so required tools are present
# Assumes same absolute path exists on remote (bind mount); fall back to plain ssh if cd fails.
REMOTE_REPO_PATH ?= $(CURDIR)
REMOTE_EXEC := $(shell if [ -x /run/wrappers/bin/sudo ]; then echo ""; else echo "ssh $(LIMA_HOST) 'cd $(REMOTE_REPO_PATH) 2>/dev/null || cd ~; if command -v flox >/dev/null 2>&1; then eval \"$$(/usr/bin/flox activate --print-env)\"; fi; '"; fi)

# Dynamic help macro ---------------------------------------------------------
define make-help
$(call trace,Entering target: help)
echo "Usage: make <target> [NAME=node] [RKE2_CLUSTER_NAME=cluster] [.trace=...] [FILTER=regex]"; \
echo ""; \
echo "Active trace modes: $(_trace_modes)"; \
echo "Shell: $(SHELL)"; \
echo "Loaded makefiles: $(words $(MAKEFILE_LIST))"; \
ALL_HELP_LINES=$$(grep -h -E '^[a-zA-Z0-9_.@%-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort -u); \
FILTER_VAL="${FILTER:-}"; \
if [ -n "$$FILTER_VAL" ]; then \
  echo "Filtering targets by regex: $$FILTER_VAL"; \
  ALL_HELP_LINES=$$(echo "$$ALL_HELP_LINES" | grep -E "$$FILTER_VAL" || true); \
fi; \
bold='\033[1m'; cyan='\033[36m'; reset='\033[0m'; \
echo ""; \
echo "Target groups:"; \
group() { grp_name="$$1"; shift; pattern="$$1"; shift; lines=$$(echo "$$ALL_HELP_LINES" | grep -E "^($$pattern):" || true); count=$$(echo "$$lines" | grep -c . || true); printf "\n${bold}[$$grp_name]${reset} (%s)\n" "$$count"; echo "$$lines" | awk -v c="$$cyan" -v r="$$reset" 'BEGIN{FS=":.*?## "} NF>=2 {printf "  %s%-30s%s %s\n", c, $$1, r, $$2}' ; }; \
group Lifecycle 'start|stop|delete|clean|clean-all|shell|instance|status|debug|scale|restart'; \
group Network 'summary@network|diagnostics@network|status@network|allocation@network|validate@network|generate@rke2-networks|show@rke2-networks'; \
group Cloud-Config 'validate-cloud-config|lint-cloud-config|debug-cloud-config-merge|show-cloud-config-files'; \
group Metaprogramming 'features@meta|targets@meta|enable@meta|disable@meta|debug-variables|show-constructed-values|status-report|start-[a-z0-9]+|stop-[a-z0-9]+|clean-[a-z0-9]+|start-cluster-[a-z0-9]+'; \
group Utility 'help|lint-yaml|zfs.allow|remove-hosts@tailscale'; \
echo ""; \
echo "Total targets: $$(echo "$$ALL_HELP_LINES" | grep -c . || true)"; \
echo ""; \
echo "Trace modes (.trace=mode[,mode]):"; \
echo "  shell    -> bash -x execution trace"; \
echo "  vars     -> variable evaluation via trace-var macro"; \
echo "  targets  -> target entry/exit via trace macro"; \
echo "  incus    -> Incus API call tracing"; \
echo "  network  -> network operations tracing"; \
echo ""; \
echo "Examples:"; \
echo "  make start NAME=master"; \
echo "  make start NAME=peer1 .trace=targets,vars"; \
echo "  make summary@network .trace=network"; \
echo "  make help FILTER=cluster"; \
echo ""; \
echo "Metaprogramming generated targets appear once features are included.";
endef

.PHONY: help
help: ## Show grouped help for all targets (use FILTER=regex to filter)
	$(make-help)

# -----------------------------------------------------------------------------
# End of make.mk
# -----------------------------------------------------------------------------
