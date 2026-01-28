ifndef make.d/node/env.mk
make.d/node/env.mk := make.d/node/env.mk

# Layer env export (@codebase)
-include rke2.d/$(cluster.name)/$(node.name)/node.env.mk

define .node.env.mk :=
export NODE_NAME := $(node.name)
export NODE_KIND := $(node.kind)
export NODE_NAME := $(node.role)
export NODE_ID   := $(node.id)
endef

endif