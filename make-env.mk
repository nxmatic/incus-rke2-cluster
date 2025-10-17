# make-env.mk - Centralized Make environment configuration (@codebase)
# -----------------------------------------------------------------------------
# Provides:
#   - Trace mode parsing (.trace variable)
#   - Shell configuration (Bash flags, optional -x when shell tracing)
#   - Global .ONESHELL and .SILENT directives
#   - Trace output macros (trace, trace-var, trace-incus, trace-network)
#
# Usage:
#   Include at the very top of your primary Makefile:
#       include make-env.mk
#   Then invoke with optional trace modes:
#       make <target> .trace=shell,vars
# -----------------------------------------------------------------------------

# User-specified trace control: comma-separated list of modes.
.trace ?=

# Internal helpers / separators
empty :=
comma := ,
colon := :
space := $(empty) $(empty)

# Parse trace modes (convert comma-separated to space-separated)
_trace_modes = $(strip $(subst $(comma), ,$(.trace)))
_has_trace = $(if $(filter $(1),$(_trace_modes)),yes,)

# Shell configuration based on trace modes
_shell_opts := --noprofile --norc -euo pipefail
ifneq ($(call _has_trace,shell),)
_shell_opts += -x
endif
SHELL := /bin/bash $(_shell_opts)

# Enable .ONESHELL globally (single shell per multi-line recipe)
.ONESHELL:
# Silence command echoing by default (use .trace=shell to see execution)
.SILENT:

# Legacy compatibility trace variables (kept for existing modules)
_trace_shell    = $(call _has_trace,shell)
_trace_vars     = $(call _has_trace,vars)
_trace_targets  = $(call _has_trace,targets)
_trace_incus    = $(call _has_trace,incus)
_trace_network  = $(call _has_trace,network)
_trace_oneshell = $(call _has_trace,oneshell)

# Conditional trace output macros (using $(info) for immediate output)
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

# -----------------------------------------------------------------------------
# End of make-env.mk
# -----------------------------------------------------------------------------
