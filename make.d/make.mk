# make.mk - Centralized Make macros, environment, helpers (@codebase)

ifndef make.mk

make.mk := $(lastword $(MAKEFILE_LIST))

true  ?= T
false ?=

### hook trace

make.is-dry-run := $(findstring n,$(firstword -$(MAKEFLAGS)),$(true),$(false))
make.if-dry-run = $(if $(make.is-dry-run),$(1),$(2))

ifndef make.trace
make.trace := $(MAKETRACE)
make.trace := $(if $(findstring n,$(firstword -$(MAKEFLAGS))),enabled,$(make.trace))
endif

define make.to-options.with-pattern =
$(foreach pattern,$(1),$(call .make.to-options.with-pattern))
endef

define .make.to-options.with-pattern =
$(if $(filter $(pattern),$(firstword $(MAKECMDGOALS))),$(foreach command,$(firstword $(MAKECMDGOALS)),$(call .make.to-options.with-goals,$(MAKECMDGOALS))))
endef

define .make.to-options.with-goals =
$(foreach goal,$(1),$(call .make.to-options.with-goal.if-match))
$(call make.trace,using goals as command options,$(command)*options)
endef

define .make.to-options.with-goal.if-match =
$(if $(filter-out $(command),$(goal)),$(call .make.to-option.with-goal))
endef

define .make.to-option.with-goal =
$(eval $(command)*options += $(goal))
$(eval .PHONY: $(goal))
endef

ifeq (enabled,$(filter enabled,$(make.trace)))
override undefine make.trace
make.trace = $(warning make.mk: $(1) ($(foreach var,$(2),$(var)=$($(var)))))
make.is-trace := $(true)
make.if-trace = $(1)
$(call make.trace,enabling trace)
else
override undefine make.trace
make.is-trace := $(false)
make.if-trace = $(2)
endif

make.is-verbose = $(make.is-trace)
make.if-verbose = $(make.if-trace)

# can't disable built-in rules and variables (required by nodejs module builds)
# MAKEFLAGS += --no-builtin-rules
# MAKEFLAGS += --no-builtin-variables

# Should no print directories
MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := noop
.DELETE_ON_ERROR:
.EXTRA_PREREQS: .make

.SUFFIXES:

.ONESHELL:
.SHELLFLAGS = -e -cs -o pipefail
.SECONDEXPANSION:

ifdef make.trace
.make.shell := $(SHELL)
SHELL=$(call make.trace,Building $@$(if $<, (from $<))$(if $?, ($? newer)))$(.make.shell)
.SHELLFLAGS += -x
endif

### bootstrap

.make.mk          := $(abspath $(make.mk))
.make.dir         := $(abspath $(dir $(.make.mk)))
.make.top-dir     := $(abspath $(.make.dir)/..)
.make.current-dir := $(abspath $(CURDIR))

define .make.del-last-slash =
$(subst $() $(),/,$(strip $(subst /, ,$(1))))
endef

define .make.rel-parent =
$(if $(filter .,$(1)),$(1),$(call .make.del-last-slash,$(foreach word,$(subst /, ,$(1)),../)))
endef

define .make.del-slash-or-dot =
$(if $(1),$(patsubst /%,%,$(1)),.)
endef

define .make.rel-path =
$(call .make.del-slash-or-dot,$(subst $(.make.top-dir),,$(1)))
endef

current-dir            := $(call .make.rel-path,$(.make.current-dir))
top-dir                := $(call .make.rel-parent,$(current-dir))
top-dir.name           := $(lastword $(subst /, ,$(realpath $(top-dir))))
top-dir.is-current-dir := $(if $(filter .,$(top-dir)),$(true),$(false))
top-dir.to-dir         := $(if $(top-dir.is-current-dir),,$(top-dir)/)
top-dir.to              = $(top-dir.to-dir)$(1)
run-root               := $(call top-dir.to,.run.d)
etc-dir                := $(run-root)/etc
bin-dir                := $(run-root)/bin
build-dir              := $(run-root)/build
tmp-dir                := $(run-root)/tmp
lib-dir                := $(run-root)/lib
var-dir                := $(run-root)/var
run-dir                := $(run-root)/run
cache-dir              := $(var-dir)/cache
manifest-dir           := $(var-dir)/manifest
make-dir               := $(call top-dir.to,make.d)

.make.dirs = $(etc-dir) $(bin-dir) $(build-dir) $(tmp-dir) $(lib-dir) $(var-dir) $(cache-dir) $(manifest-dir)
.make.files := $(filter-out make.d/make.mk,$(subst $(top-dir)/,,$(wildcard $(make-dir)/*.mk)))

$(shell mkdir -p $(.make.dirs))

$(.make.files): ;

.make: ;

.make: $(suffix /,$(make.dirs))

.PHONY: .make

# generate/load caches

$(cache-dir)/%.mk:
	@: $(file >$(@),$(.make.cache.mk.template))

$(cache-dir)/%.mk: name = $(*)

$(cache-dir)/%.env:
	@: $(file >$(@),$(.make.cache.env.template))

$(cache-dir)/%.env: name = $(*)

$(top-dir)/%/:
	@: $(info lazy creating folder $(@))
	mkdir -p $(@)

define .make.cache.mk.template  =
ifndef $(name)-cache.mk
_$(name)_cache_mk := $(@)
$($(name).cache.mk)
endif
endef

define .make.cache.env.template =
export _$(name)_cache_env=$(@)
$($(name).env)
endef

define make.cache.is-loaded =
$(call make.cache.if-loaded,$(1),$(2),$(true),$(false))
endef

define make.cache.if-loaded =
$(call make.cache.with-left,$(1),$(2),$(3),$(4))
endef

define make.cache.with-left =
$(foreach left,_$(strip $(1))_cache_$(strip $(2)),$(call make.cache.with-right,$(3),$(4)))
endef

define make.cache.with-right =
$(foreach right,$(origin $(left)),$(call make.cache.eval-conditional,$(1),$(2)))
endef

define make.cache.eval-conditional =
$(if $(filter undefined,$(right)),$(2),$(1))
endef

###

.PHONY: noop
noop: ;


## Inline help (removed make-help macro; using .ONESHELL) (@codebase)
.PHONY: help
help: ## Show grouped help for all targets (use FILTER=regex to filter)
	$(call trace,Entering target: help)
	echo "Usage: make <target> [NAME=node] [RKE2_CLUSTER_NAME=cluster] [.trace=...] [FILTER=regex]";
	echo "";
	echo "Active trace modes: $(_trace_modes)";
	echo "Shell: $(SHELL)";
	echo "Loaded makefiles: $(words $(MAKEFILE_LIST))";
	ALL_HELP_LINES=$$(grep -h -E '^[a-zA-Z0-9_.@%-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort -u); \
	FILTER_VAL="$$FILTER"; \
	if [ -n "$$FILTER_VAL" ]; then \
	  echo "Filtering targets by regex: $$FILTER_VAL"; \
	  ALL_HELP_LINES=$$(echo "$$ALL_HELP_LINES" | grep -E "$$FILTER_VAL" || true); \
	fi; \
	bold='\033[1m'; cyan='\033[36m'; reset='\033[0m'; \
	echo ""; \
	echo "Target groups:"; \
	group() { grp_name="$$1"; pattern="$$2"; lines=$$(echo "$$ALL_HELP_LINES" | grep -E "^($$pattern):" || true); count=$$(echo "$$lines" | grep -c . || true); printf "\n${bold}[$$grp_name]${reset} (%s)\n" "$$count"; echo "$$lines" | awk -v c="$$cyan" -v r="$$reset" 'BEGIN{FS=":.*?## "} NF>=2 {printf "  %s%-30s%s %s\n", c, $$1, r, $$2}' ; }; \
	group Lifecycle 'start|stop|delete|clean|clean-all|shell|instance|status|debug|scale|restart'; \
	group Network 'summary@network|diagnostics@network|status@network|allocation@network|validate@network|generate@rke2-networks|show@rke2-networks'; \
	group Cloud-Config 'validate-cloud-config|lint-cloud-config|debug-cloud-config-merge|show-cloud-config-files'; \
	group Metaprogramming 'features@meta|targets@meta|enable@meta|disable@meta|debug-variables|show-constructed-values|status-report|start-[a-z0-9]+|stop-[a-z0-9]+|clean-[a-z0-9]+|start-cluster-[a-z0-9]+'; \
	group Utility 'help|lint-yaml|zfs.allow|remove-hosts@tailscale'; \
	echo ""; \
	echo "Total targets: $$(echo "$$ALL_HELP_LINES" | grep -c . || true)"; \
	echo ""; \
	echo "Trace modes (.trace=mode[,mode]):"; \
	echo "  shell    -> bash -x execution trace"; \
	echo "  vars     -> variable evaluation via trace-var macro"; \
	echo "  targets  -> target entry/exit via trace macro"; \
	echo "  incus    -> Incus API call tracing"; \
	echo "  network  -> network operations tracing"; \
	echo ""; \
	echo "Examples:"; \
	echo "  make start NAME=master"; \
	echo "  make start NAME=peer1 .trace=targets,vars"; \
	echo "  make summary@network .trace=network"; \
	echo "  make help FILTER=cluster"; \
	echo ""; \
	echo "Metaprogramming generated targets appear once features are included.";


.PHONY: help

.FORCE:

.PHONY: .FORCE

ifdef make.force
override make.force := .FORCE
endif

define .make.hook =
.make.tmp.list := $$(MAKEFILE_LIST)
.make.tmp.path := $$(lastword $$(.make.tmp.list))

.make.tmp.list := $$(filter-out $$(.make.tmp.path),$$(.make.tmp.list))
.make.tmp.path := $$(patsubst $(top-dir)/%,%,$$(lastword $$(.make.tmp.list)))
.make.tmp.file := $$(notdir $$(.make.tmp.path))
.make.tmp.dir  := $$(dir $$(.make.tmp.path))
.make.tmp.name := $$(basename $$(.make.tmp.file))
.make.tmp.context := $$(basename $$(.make.tmp.path))

ifndef $$(.make.tmp.path)

$$(.make.tmp.path) := $$(.make.tmp.path) # marker

$$(.make.tmp.context).path := $$(.make.tmp.path) # values
$$(.make.tmp.context).dir := $$(patsubst $(top-dir)/,%,$$(.make.tmp.dir))
$$(.make.tmp.context).file := $$(.make.tmp.file)
$$(.make.tmp.context).name := $$(.make.tmp.name)

$$(call make.trace,loading,$$(.make.tmp.context).path)

endif
endef

noop: $(bin-dir)/make~reset.sh

$(bin-dir)/make~reset.sh: | $(bin-dir)/
	@: $(file >$(bin-dir)/make~reset.sh,$(make~reset.sh))

define make~reset.sh :=
#!/usr/bin/env sh
cd $(top-dir)
[ -n "$${ZSH_VERSION+x}" ] && setopt localoptions rmstarsilent
rm -f $(cache-dir)/* && pushd .. && popd
make noop
endef

else

$(eval $(.make.hook))

endif
