ifndef make.d/rke2.mk

make.d/rke2.mk := make.d/rke2.mk

include make.d/make.mk
include make.d/cluster/rules.mk
include make.d/node/rules.mk
include make.d/network/rules.mk
include make.d/cloud-config/rules.mk
include make.d/incus/rules.mk
include make.d/kpt/rules.mk

-include rke2.d/$(cluster.name)/incus.env.mk
-include rke2.d/$(cluster.name)/rke2.env.mk

define .rke2.env.mk =
export CLUSTER_ID=$(cluster.id)
export CLUSTER_NAME=$(cluster.name)
export CLUSTER_ENV=$(cluster.env)
export CLUSTER_TOKEN=$(cluster.token)
export CLUSTER_DOMAIN=$(cluster.domain)
export CLUSTER_FLOX_ENABLED=$(cluster.flox.enabled)
endef

export RKE2_DIR=$(abspath $(rke2.dir))

# RKE2 subtree directory
rke2.dir        := $(call top-dir.to,rke2.d)
# Guard: if computed local-dir collapses to '/rke2' (top-dir became '/'), rebase to current working directory (@codebase)
ifeq ($(rke2.dir),/rke2.d)
rke2.dir := $(CURDIR)/rke2.d
$(info [make.mk] Rebased rke2.dir to $(rke2.dir) (top-dir resolved to '/'))
endif
rke2.git.remote ?= fleet
rke2.git.branch ?= rke2
rke2.git.subtree.dir ?= fleet

# generate/load rke2 env cache

$(shell mkdir -p $(rke2.dir)/$(cluster.name)/$(node.name)/)

rke2.d/$(cluster.name)/%.env.mk: name = $(*)
rke2.d/$(cluster.name)/%.env.mk:
	: "Generating $(file >$(@),$(.make.layer.env.content))$(@)"

rke2.d/$(cluster.name)/$(node.name)/%.env.mk: name = $(*)
rke2.d/$(cluster.name)/$(node.name)/%.env.mk:
	: "Generating $(file >$(@),$(.make.layer.env.content))$(@)"

define .make.layer.env.content =
ifndef $(name).env.mk
$(name).env.mk := $(@)
$(.$(name).env.mk)
endif
endef

endif # make.d/rke2.mk