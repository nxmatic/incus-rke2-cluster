ifndef make.d/macros.mk

include $(make-dir)/make.mk
include $(top-dir)/.gmsl/gmsl

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
    $(strip $(foreach 1,$1,
        $(call __check-variable-defined,$1,$(strip $(value 2)))))
endef

define __check-variable-defined =
    $(if $(value $1),,
        $(error Undefined variable '$1'$(if $2, ($2))$(if $(value @),
                required by target '$@')))
endef

endif
