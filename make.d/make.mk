# make.mk - Centralized Make macros, environment, helpers (@codebase)

ifndef make.mk

make.mk := $(lastword $(MAKEFILE_LIST))

true  ?= T
false ?=

### hook trace

make.is-dry-run := $(findstring n,$(firstword -$(MAKEFLAGS)),$(true),$(false))
make.if-dry-run = $(if $(make.is-dry-run),$(1),$(2))

# Unified trace system - single .trace parameter controls all tracing (@codebase)
# Parse .trace=mode[,mode] syntax for all trace types including make-level
.trace.modes := $(subst $(comma), ,$(strip $(.trace)))
.trace.make := $(if $(filter make,$(.trace.modes)),$(true),$(false))
.trace.shell := $(if $(filter shell,$(.trace.modes)),$(true),$(false))
.trace.vars := $(if $(filter vars,$(.trace.modes)),$(true),$(false))
.trace.targets := $(if $(filter targets,$(.trace.modes)),$(true),$(false))
.trace.incus := $(if $(filter incus,$(.trace.modes)),$(true),$(false))
.trace.network := $(if $(filter network,$(.trace.modes)),$(true),$(false))
.trace.kpt := $(if $(filter kpt,$(.trace.modes)),$(true),$(false))

# Backward compatibility: still honor MAKETRACE environment variable
.trace.make := $(if $(filter enabled,$(MAKETRACE)),$(true),$(.trace.make))

# Active trace modes summary for help display
_trace_modes := $(strip $(.trace.modes))
_trace_modes := $(if $(_trace_modes),$(_trace_modes),none)

# =============================================================================
# SELECTIVE ALWAYS-MAKE SYSTEM (@codebase)
# =============================================================================
# Unified always-make system - single .always-make parameter controls selective rebuilds
# Usage: make .always-make=cloud-config,network target
# Available modes: cloud-config, network, incus, instance-config, distrobuilder, all
# This allows selective force rebuilds without expensive operations like distrobuilder

# Parse .always-make=mode[,mode] syntax for selective rebuilds
.always-make.modes := $(subst $(comma), ,$(strip $(.always-make)))
.always-make.cloud-config := $(if $(filter cloud-config,$(.always-make.modes)),$(true),$(false))
.always-make.network := $(if $(filter network,$(.always-make.modes)),$(true),$(false))
.always-make.incus := $(if $(filter incus,$(.always-make.modes)),$(true),$(false))
.always-make.instance-config := $(if $(filter instance-config,$(.always-make.modes)),$(true),$(false))
.always-make.distrobuilder := $(if $(filter distrobuilder,$(.always-make.modes)),$(true),$(false))
.always-make.all := $(if $(filter all,$(.always-make.modes)),$(true),$(false))

# Global always-make flag (when all mode is enabled or --always-make is used)
.always-make.global := $(if $(filter all,$(.always-make.modes)),$(true),$(false))

# Active always-make modes summary for help display
_always_make_modes := $(strip $(.always-make.modes))
_always_make_modes := $(if $(_always_make_modes),$(_always_make_modes),none)

# =============================================================================
# METAPROGRAMMED TARGET COLLECTION SYSTEM (@codebase)
# =============================================================================
# Collect targets by category for GNU Make special target management
# These lists are populated by rule files using the register macros below

# Target collections for different categories
.make.cloud-config-targets :=
.make.network-targets :=
.make.incus-targets :=
.make.distrobuilder-targets :=
.make.instance-config-targets :=
.make.expensive-targets :=
.make.config-targets :=

# Force targets for each always-make mode (always out-of-date)
.FORCE.cloud-config:
.FORCE.network:
.FORCE.incus:
.FORCE.instance-config:
.FORCE.distrobuilder:
.FORCE.all:

.PHONY: .FORCE.cloud-config .FORCE.network .FORCE.incus .FORCE.instance-config .FORCE.distrobuilder .FORCE.all

# Helper functions for selective always-make using .EXTRA_PREREQS (cleaner than .PHONY)
# Usage: $(call always-make-if,mode,target) - adds force prerequisite without affecting $^
define always-make-if
$(if $(filter $(true),$(.always-make.$(1))),$(eval $(2): .EXTRA_PREREQS += .FORCE.$(1)))
endef

# Convenience macros for common always-make patterns
define always-make-cloud-config
$(call always-make-if,cloud-config,$(1))
endef

define always-make-network
$(call always-make-if,network,$(1))
endef

define always-make-incus
$(call always-make-if,incus,$(1))
endef

define always-make-instance-config
$(call always-make-if,instance-config,$(1))
endef

define always-make-distrobuilder
$(call always-make-if,distrobuilder,$(1))
endef

# Target registration macros for metaprogramming
# These macros register targets into collections and apply always-make logic
define register-cloud-config-targets
$(eval .make.cloud-config-targets += $(1))
$(call always-make-cloud-config,$(1))
endef

define register-network-targets
$(eval .make.network-targets += $(1))
$(call always-make-network,$(1))
endef

define register-incus-targets
$(eval .make.incus-targets += $(1))
$(call always-make-incus,$(1))
endef

define register-distrobuilder-targets
$(eval .make.distrobuilder-targets += $(1))
$(eval .make.expensive-targets += $(1))
$(call always-make-distrobuilder,$(1))
endef

define register-instance-config-targets
$(eval .make.instance-config-targets += $(1))
$(call always-make-instance-config,$(1))
endef

define register-config-targets
$(eval .make.config-targets += $(1))
endef

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

# Unified trace macros - all controlled by .trace parameter (@codebase)
ifeq ($(true),$(.trace.make))
override make.trace = $(warning make.mk: $(1) $(if $(2),($(foreach var,$(2),$(var)=$($(var)))),(no vars)))
make.is-trace := $(true)
make.if-trace = $(1)
$(call make.trace,enabling make-level trace)
# Preserve all intermediate build artifacts when make-level tracing is enabled (@codebase)
# This aids debugging by retaining generated .env/.mk subnet assignments, merged YAML, etc.
.SECONDARY:
else
make.is-trace := $(false)
make.if-trace = $(2)
endif

# ----------------------------------------------------------------------------
# Host / platform detection (Darwin vs NixOS) (@codebase)
# ----------------------------------------------------------------------------
# Determines whether Incus image builds should execute locally (NixOS host)
# or via REMOTE_EXEC (Darwin host controlling a Lima VM). Containers are
# never the build context for distrobuilder.

host.UNAME := $(shell uname -s)
host.IS_DARWIN := $(if $(filter Darwin,$(host.UNAME)),$(true),$(false))
host.IS_LINUX := $(if $(filter Linux,$(host.UNAME)),$(true),$(false))
host.IS_NIXOS := $(if $(and $(host.IS_LINUX),$(wildcard /etc/NIXOS)),$(true),$(false))

# Build mode: Always local (NixOS VM only)

$(call make.trace,host-detection,(host.UNAME host.IS_DARWIN host.IS_NIXOS))

# Early environment validation: Incus operations require NixOS
ifneq ($(host.IS_NIXOS),T)
$(warn [make.mk] Incus cluster operations must run on NixOS VM, not $(host.UNAME). Please SSH into lima-nerd-nixos and run from /var/lib/nixos/config/modules/nixos/incus-rke2-cluster)
endif

# Layer-specific trace macros
define trace
$(if $(filter $(true),$(.trace.targets)),$(warning [trace:targets] $(1)))
endef

define trace-var
$(if $(filter $(true),$(.trace.vars)),$(warning [trace:vars] $(1)=$($(1))))
endef

define trace-incus
$(if $(filter $(true),$(.trace.incus)),$(warning [trace:incus] $(1)))
endef

define trace-network
$(if $(filter $(true),$(.trace.network)),$(warning [trace:network] $(1)))
endef

# =============================================================================
# GNU MAKE SPECIAL TARGETS FOR RELIABILITY & PERFORMANCE (@codebase)
# =============================================================================

# Delete partial files on error for build reliability
.DELETE_ON_ERROR:

# Enable secondary expansion for dynamic prerequisites
.SECONDEXPANSION:

# Auto-detection of expensive operations from command goals
.make.auto-expensive := $(if $(filter %image %distrobuilder %build-image,$(MAKECMDGOALS)),$(true),$(false))
.make.auto-rebuild := $(if $(filter rebuild% clean% nuke%,$(MAKECMDGOALS)),$(true),$(false))

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
.SECONDARY:
.SECONDEXPANSION:
.ONESHELL:
.SILENT:
.SHELLFLAGS = -e -cs -o pipefail

export PS4 = '[trace] $$LINENO: '

# Shell tracing: activated by either .trace=make or .trace=shell (@codebase)
# Note: .trace=make includes shell tracing for complete make-level debugging experience
ifeq ($(true),$(.trace.make))
.make.shell := $(SHELL)
SHELL=$(call make.trace,Building $@$(if $<, (from $<))$(if $?, ($? newer)))$(.make.shell)
.SHELLFLAGS += -x
export PS4 = '+ [trace:make] $$LINENO: '
else ifeq ($(true),$(.trace.shell))
.SHELLFLAGS += -x
export PS4 = '+ [trace:shell] $$LINENO: '
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
local-dir            := $(call top-dir.to,.local.d)
# Guard: if computed local-dir collapses to '/.local.d' (top-dir became '/'), rebase to current working directory (@codebase)
ifeq ($(local-dir),/.local.d)
local-dir := $(CURDIR)/.local.d
$(info [make.mk] Rebased local-dir to $(local-dir) (top-dir resolved to '/'))
endif
etc-dir                := $(local-dir)/etc
bin-dir                := $(local-dir)/bin
build-dir              := $(local-dir)/build
tmp-dir                := $(local-dir)/tmp
lib-dir                := $(local-dir)/lib
var-dir                := $(local-dir)/var
run-dir                := $(local-dir)/run
cache-dir              := $(var-dir)/cache
manifest-dir           := $(var-dir)/manifest
make-dir               := $(call top-dir.to,make.d)

# RKE2 subtree directory
rke2-subtree.dir        := $(call top-dir.to,rke2-subtree)
rke2-subtree.git.remote ?= fleet
rke2-subtree.git.branch ?= rke2-subtree
rke2-subtree.git.subtree.dir ?= fleet


.make.dirs := $(etc-dir) $(bin-dir) $(build-dir) $(tmp-dir) $(lib-dir) $(var-dir) $(run-dir) $(cache-dir) $(manifest-dir)
.make.files := $(filter-out make.d/make.mk,$(subst $(top-dir)/,,$(wildcard $(make-dir)/*.mk)))

$(shell mkdir -p $(.make.dirs))

$(.make.files): ;

.make: ;

.make: $(suffix /,$(make.dirs))

.PHONY: .make

# generate/load caches

$(cache-dir)/%.mk:
	: $(file >$(@),$(.make.cache.mk.template))

$(cache-dir)/%.mk: name = $(*)

$(cache-dir)/%.env:
	: $(file >$(@),$(.make.cache.env.template))

$(cache-dir)/%.env: name = $(*)

# Removed generic folder auto-create pattern (was over-matching file targets like *.subnet.mk) (@codebase)
# Explicit directory creation handled earlier via mkdir -p $(.make.dirs)

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

## Inline help (removed make-help macro; using .ONESHELL) (@codebase)
.PHONY: help
help: ## Show grouped help for all targets (use FILTER=regex to filter)
	$(call trace,Entering target: help)
	echo "Usage: make <target> [NAME=node] [CLUSTER_NAME=cluster] [.trace=mode[,mode]] [.always-make=mode[,mode]] [FILTER=regex]";
	echo "";
	echo "Active trace modes: $(_trace_modes)";
	echo "Active always-make modes: $(_always_make_modes)";
	echo "Shell: $(SHELL)";
	echo "Loaded makefiles: $(words $(MAKEFILE_LIST))";
	echo "Make trace: $(if $(filter $(true),$(.trace.make)),enabled,disabled)";
	ALL_HELP_LINES=$$(grep -h -E '^[a-zA-Z0-9_.@%-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort -u)
	FILTER_VAL="$$FILTER"
	if [ -n "$$FILTER_VAL" ]; then
	  echo "Filtering targets by regex: $$FILTER_VAL"
	  ALL_HELP_LINES=$$(echo "$$ALL_HELP_LINES" | grep -E "$$FILTER_VAL" || true)
	fi
	bold='\033[1m'; cyan='\033[36m'; reset='\033[0m'
	echo ""
	echo "Target groups:"
	# Dynamic target discovery by layer suffix (@codebase)
	group() { \
		grp_name="$$1"; layer_suffix="$$2"; custom_pattern="$$3"; \
		if [ -n "$$custom_pattern" ]; then \
			pattern="$$custom_pattern"; \
		else \
			pattern="[a-zA-Z0-9_.-]+@$$layer_suffix"; \
		fi; \
		lines=$$(echo "$$ALL_HELP_LINES" | grep -E "^$$pattern:" || true); \
		count=$$(echo "$$lines" | grep -c . || true); \
		if [ "$$count" -gt 0 ]; then \
			printf "\n${bold}[$$grp_name]${reset} (%s)\n" "$$count"; \
			echo "$$lines" | awk -v c="$$cyan" -v r="$$reset" 'BEGIN{FS=":.*?## "} NF>=2 {printf "  %s%-30s%s %s\n", c, $$1, r, $$2}' || true; \
		fi; \
	}
	: "Layer-based groups (auto-discovered by @suffix)"
	group "Node" "node"
	group "Incus" "incus" 
	group "Cluster" "cluster"
	group "Network" "network"
	group "Cloud-Config" "cloud-config"
	group "Metaprogramming" "meta"
	group "PlantUML" "plantuml"
	: "Special pattern-based groups for cross-cutting concerns"
	group "Utility" "" "^(help|lint-yaml|zfs\\.allow|remove-hosts@tailscale|noop)$$"
	echo ""
	echo "Total targets: $$(echo "$$ALL_HELP_LINES" | grep -c . || true)"
	echo ""
	echo "Unified Trace System (.trace=mode[,mode]):"
	echo "  make     -> Make-level tracing (variable evaluation, target building)"
	echo "  shell    -> Shell command execution trace (bash -x)"
	echo "  vars     -> Variable evaluation via trace-var macro"
	echo "  targets  -> Target entry/exit via trace macro"
	echo "  incus    -> Incus API call tracing"
	echo "  network  -> Network operations tracing"
	echo ""
	echo "Selective Always-Make System (.always-make=mode[,mode]):"
	echo "  cloud-config    -> Force rebuild of all cloud-config templates (userdata, metadata, network-config)"
	echo "  network         -> Force rebuild of all network configuration files (subnets, templates)"
	echo "  incus           -> Force rebuild of incus resources (profiles, storage, but not images)"
	echo "  instance-config -> Force rebuild of instance configuration files"
	echo "  distrobuilder   -> Force rebuild of distrobuilder images (expensive operation)"
	echo "  all             -> Force rebuild of everything (equivalent to .ALWAYS_MAKE)"
	echo ""
	echo "Advanced Features:"
	echo "  - Uses .EXTRA_PREREQS for cleaner force rebuilds (doesn't affect \$$^ variable)"
	echo "  - Auto-detects expensive operations from command goals (*image, *distrobuilder)"
	echo "  - Protects expensive builds with .PRECIOUS (won't delete on interrupt)"
	echo "  - Uses .NOTINTERMEDIATE to preserve important config files"
	echo "  - Enables .SECONDEXPANSION for dynamic prerequisites"
	echo "  - Adds .DELETE_ON_ERROR for better build reliability"
	echo ""
	echo "Examples:"
	echo "  make start NAME=master                     # No tracing, normal dependencies"
	echo "  make start NAME=peer1 .trace=targets,vars  # Layer tracing"
	echo "  make summary@network .trace=network        # Network-specific tracing"
	echo "  make start NAME=master .trace=make          # Make-level tracing"
	echo "  make start NAME=peer1 .trace=make,targets   # Combined tracing"
	echo "  make userdata .always-make=cloud-config    # Force rebuild cloud-config only"
	echo "  make start NAME=master .always-make=network,incus # Force network & incus rebuild"
	echo "  make help FILTER=cluster                   # Help filtering"
	echo ""
	echo "Metaprogramming generated targets appear once features are included.";

#-----------------------------
# Create necessary directories
#-----------------------------
%/:
	mkdir -p $(@)

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
$$(.make.tmp.context) := $$(.make.tmp.context) # guard variable expected by individual files
$$(.make.tmp.context).path := $$(.make.tmp.path) # values
$$(.make.tmp.context).dir := $$(patsubst $(top-dir)/,%,$$(.make.tmp.dir))
$$(.make.tmp.context).file := $$(.make.tmp.file)
$$(.make.tmp.context).name := $$(.make.tmp.name)

$$(call make.trace,Loading,$$(.make.tmp.context).path)

endif
endef

noop: ## Default goal: no operation
	echo "[+] noop target reached (default goal)"

else

$(eval $(.make.hook))

# =============================================================================
# SPECIAL TARGET APPLICATION (executed after all makefiles loaded) (@codebase)
# =============================================================================

# Apply GNU Make special targets based on collected target lists
# This happens after all rule files have registered their targets

# Protect expensive builds from deletion on interrupt
.PRECIOUS: $(.make.expensive-targets) $(.make.distrobuilder-targets)

# Prevent important config files from being deleted as intermediate files
.NOTINTERMEDIATE: $(.make.config-targets) $(.make.cloud-config-targets)

# Add auto-detected expensive operations to expensive targets if detected
ifeq ($(.make.auto-expensive),$(true))
$(call make.trace,auto-detected expensive operations from goals,$(MAKECMDGOALS))
.make.expensive-targets += $(filter %image %distrobuilder %build-image,$(MAKECMDGOALS))
endif

endif
