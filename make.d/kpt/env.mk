# incus-env.mk - Incus environment exports (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/kpt/env.mk

make.d/kpt/env.mk := make.d/kpt/env.mk

-include rke2.d/$(cluster.name)/$(node.name)/kpt.env.mk

define .kpt.env.mk :=
export KPT_MANIFESTS_DIR=$(abspath $(.kpt.manifests.dir))
export KPT_CONFIG_DIR=$(abspath $(.kpt.render.dir)/runtime/rke2-config/configmaps)
endef

endif
