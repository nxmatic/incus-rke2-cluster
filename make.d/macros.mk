ifndef make.d/macros.mk

# NOTE: make.mk and gmsl are included by the main Makefile, not here

define \n :=

endef

define space :=
$() $()
endef

newline:=$(\n)
empty:=$()
comma:=,

define defer-variable-expansion =
$(1) = $(eval $(1) := $(2))$($(1))
endef

define check-variable-defined =
$(strip $(foreach arg,$(1),$(call __check-variable-defined,$(arg))))
endef

define __check-variable-defined =
$(if $(value $(1)),,$(error Undefined variable '$(1)' $(if $(value @),required by target '$(@)')))
endef

endif
