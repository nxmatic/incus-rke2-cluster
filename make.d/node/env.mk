ifndef make.d/node/env.mk
make.d/node/env.mk := make.d/node/env.mk

# Layer env export (@codebase)
-include rke2.d/$(cluster.name)/$(node.name)/node.env.mk

define .node.env.mk :=
export NODE_NAME := $(node.name)
export NODE_TYPE := $(node.type)
export NODE_ROLE := $(node.role)
export NODE_ID   := $(node.id)
endef

endif