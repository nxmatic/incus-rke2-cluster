ifndef make.d/network/rules.mk

make.d/network/rules.mk := make.d/network/rules.mk

# Modular network rules: all logic is now sourced from split files
include make.d/network/macros.mk
include make.d/network/vars.mk
include make.d/network/targets.mk
include make.d/network/split-rules.mk
include make.d/network/network-deps.mk

include make.d/network/env.mk

endif # make.d/network/rules.mk guard
