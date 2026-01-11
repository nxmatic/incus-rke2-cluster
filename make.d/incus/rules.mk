ifndef make.d/incus/rules.mk

make.d/incus/rules.mk := make.d/incus/rules.mk

include make.d/network/rules.mk
include make.d/cluster/rules.mk
include make.d/node/rules.mk

# incus.mk - Incus Infrastructure Management (@codebase)
# Layer entrypoint: only includes sub-makefiles for modularity
include make.d/incus/macros.mk
include make.d/incus/vars.mk
include make.d/incus/targets.mk

include make.d/incus/env.mk

endif # make.d/incus/rules.mk guard

