# rules.mk - KPT package catalog and manifests management (@codebase)

# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/kpt/rules.mk

make.d/kpt/rules.mk := make.d/kpt/rules.mk  # guard to allow safe re-inclusion (@codebase)

include make.d/network/rules.mk

include make.d/kpt/macros.mk
include make.d/kpt/vars.mk
include make.d/kpt/env.mk
include make.d/kpt/targets.mk
include make.d/kpt/setters.mk


endif # make.d/kpt/rules.mk guard
