# =============================================================================
# IMPROVED SELECTIVE ALWAYS-MAKE SYSTEM (@codebase)
# Using modern GNU Make features for cleaner implementation
# =============================================================================

# Enable secondary expansion for dynamic prerequisites
.SECONDEXPANSION:

# Parse .always-make parameter (same as current)
.always-make.modes := $(subst $(comma), ,$(strip $(.always-make)))
.always-make.cloud-config := $(if $(filter cloud-config,$(.always-make.modes)),$(true),$(false))
.always-make.network := $(if $(filter network,$(.always-make.modes)),$(true),$(false))
.always-make.incus := $(if $(filter incus,$(.always-make.modes)),$(true),$(false))
.always-make.instance-config := $(if $(filter instance-config,$(.always-make.modes)),$(true),$(false))
.always-make.distrobuilder := $(if $(filter distrobuilder,$(.always-make.modes)),$(true),$(false))
.always-make.all := $(if $(filter all,$(.always-make.modes)),$(true),$(false))

# Create mode-specific force targets that are always out of date
.FORCE.cloud-config:
.FORCE.network:
.FORCE.incus:
.FORCE.instance-config:
.FORCE.distrobuilder:
.FORCE.all:

.PHONY: .FORCE.cloud-config .FORCE.network .FORCE.incus .FORCE.instance-config .FORCE.distrobuilder .FORCE.all

# Helper function using .EXTRA_PREREQS (cleaner than .PHONY)
# This adds force prerequisites without affecting $^ in recipes
define always-make-if
$(if $(filter $(true),$(.always-make.$(1))),$(eval $(2): .EXTRA_PREREQS += .FORCE.$(1)))
endef

# Convenience macros (same interface as current)
define always-make-cloud-config
$(call always-make-if,cloud-config,$(1))
endef

define always-make-network
$(call always-make-if,network,$(1))
endef

define always-make-incus
$(call always-make-if,incus,$(1))
endef

define always-make-instance-config  
$(call always-make-if,instance-config,$(1))
endef

define always-make-distrobuilder
$(call always-make-if,distrobuilder,$(1))
endef

# Advanced: Auto-detection of expensive operations from command goals
.always-make.auto-expensive := $(if $(filter %image %distrobuilder %build-image,$(MAKECMDGOALS)),$(true),$(false))

# Advanced: Target-specific variable approach for rule files that prefer it
# Usage in rule files:
# $(my-targets): .always-make.mode = cloud-config
# Then targets automatically get force behavior based on their mode

# Generic pattern for target-specific mode handling
%: $$(if $$(filter $$(true),$$(.always-make.$$(or $$(.always-make.mode),none))),.FORCE.$$(or $$(.always-make.mode),none))

# Reliability improvements
.DELETE_ON_ERROR:  # Clean up partial builds on error
.PRECIOUS: $(distrobuilder-images)  # Protect expensive builds from deletion
.NOTINTERMEDIATE: $(config-files)   # Prevent config files from being deleted as intermediate

# Status display (same as current)
_always_make_modes := $(strip $(.always-make.modes))
_always_make_modes := $(if $(_always_make_modes),$(_always_make_modes),none)

# Example of how rule files would integrate (much cleaner):
# Instead of manually calling $(call always-make-cloud-config,target) in each rule,
# rule files can simply do:
# $(cloud-config-targets): .always-make.mode = cloud-config
# $(network-targets): .always-make.mode = network