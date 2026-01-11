# incus-macros.mk - Incus helper macros (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/macros.mk
make.d/incus/macros.mk := make.d/incus/macros.mk

# Template function to generate cleanup targets for different resource types
# Usage: $(call define-cleanup-target,RESOURCE_TYPE,list_command,yq_expr,delete_command)
define define-cleanup-target
cleanup-project-$(1)@incus: ## destructive: delete all $(1) in project rke2
	incus $(2) --project=$(.incus.project.name) --format=yaml | $(3) |
	  xargs -r -n1 $(4) || true
endef

endif
