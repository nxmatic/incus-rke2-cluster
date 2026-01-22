# cloud-config/rules.mk - Cloud-config generation and management (@codebase)
# Self-guarding include pattern for idempotent multiple inclusion.

ifndef make.d/cloud-config/rules.mk

make.d/cloud-config/rules.mk := make.d/cloud-config/rules.mk  # guard to allow safe re-inclusion (@codebase)

include make.d/rke2.mk  # Ensure availability when file used standalone (@codebase)
include make.d/node/rules.mk  # Node identity and role variables (@codebase)
include make.d/network/rules.mk  # Network configuration variables (@codebase)
include make.d/cluster/rules.mk  # Cluster configuration and variables (@codebase)

-include $(network.env.mk)
-include rke2.d/$(cluster.name)/$(node.name)/cloud-config.env.mk

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

# Cloud-config source template paths (lazy evaluation for dynamic reload) (@codebase)
.cloud-config.source_dir = $(make-dir)/cloud-config
.cloud-config.common = $(.cloud-config.source_dir)/cloud-config.common.yaml
.cloud-config.server = $(.cloud-config.source_dir)/cloud-config.server.yaml
.cloud-config.master.base = $(.cloud-config.source_dir)/cloud-config.master.base.yaml
.cloud-config.master.cilium = $(.cloud-config.source_dir)/cloud-config.master.cilium.yaml
.cloud-config.master.kube_vip = $(.cloud-config.source_dir)/cloud-config.master.kube-vip.yaml
.cloud-config.peer = $(.cloud-config.source_dir)/cloud-config.peer.yaml

# Temp workspace for generated yq scripts and merge outputs (@codebase)
.cloud-config.tmp.dir = $(tmp-dir)/cloud-config/$(cluster.name)/$(node.name)
.cloud-config.yq.file = $(.cloud-config.tmp.dir)/user-data.yq
.cloud-config.tmp.output = $(.cloud-config.tmp.dir)/user-data.tmp



# Output files (nocloud format) - node-specific paths matching incus structure (@codebase)
.cloud-config.dir = $(rke2-subtree.dir)/${cluster.name}/$(node.name)
.cloud-config.metadata.file = $(.cloud-config.dir)/meta-data
.cloud-config.userdata.file = $(.cloud-config.dir)/user-data
.cloud-config.netcfg.file = $(.cloud-config.dir)/network-config

# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export cloud-config variables for use in YAML templates via yq envsubst

define .cloud-config.env.mk =

export CLOUDCONFIG_METADATA_FILE := $(abspath $(.cloud-config.metadata.file))
export CLOUDCONFIG_USERDATA_FILE := $(abspath $(.cloud-config.userdata.file))
export CLOUDCONFIG_NETCFG_FILE := $(abspath $(.cloud-config.netcfg.file))

endef

# =============================================================================
# CLOUD-CONFIG GENERATION RULES
# =============================================================================

# Metadata template (private)
## Metadata template (deterministic instance-id) (@codebase)
## Decision: Use stable instance-id format to avoid unnecessary cloud-init reinitialization.
## Format: <name>-cluster<clusterID>-node<nodeID>
define .cloud-config.metadata_template
instance-id: ${cluster.name}-${node.name}
local-hostname: $(cluster.name)-$(node.name)
endef

$(call register-cloud-config-targets,$(.cloud-config.metadata.file))
$(.cloud-config.metadata.file): | $(.cloud-config.dir)/
$(.cloud-config.metadata.file): export METADATA_INLINE := $(.cloud-config.metadata_template)
$(.cloud-config.metadata.file):
	: "[+] Generating meta-data file for instance $(node.name)..."
	echo "$$METADATA_INLINE" > $(@)

#-----------------------------
# Generate cloud-init user-data file using yq for YAML correctness
#-----------------------------

$(.cloud-config.userdata.file): | $(.cloud-config.dir)/
$(.cloud-config.userdata.file): $(.cloud-config.common) ## common fragment (@codebase)
$(.cloud-config.userdata.file): $(.cloud-config.server) ## server fragment (@codebase)
ifeq ($(node.ROLE),master)
$(.cloud-config.userdata.file): $(.cloud-config.master.base) ## master base fragment (@codebase)
$(.cloud-config.userdata.file): $(.cloud-config.master.cilium) ## master cilium fragment (@codebase)
$(.cloud-config.userdata.file): $(.cloud-config.master.kube_vip) ## master kube-vip fragment (@codebase)
endif

ifeq ($(node.ROLE),peer)
$(.cloud-config.userdata.file): $(.cloud-config.peer) ## peer fragment (@codebase)
endif
$(.cloud-config.userdata.file): export CLUSTER_VIP_GATEWAY_IP := $(CLUSTER_VIP_GATEWAY_IP)
$(.cloud-config.userdata.file): export NODE_GATEWAY_IP := $(NODE_GATEWAY_IP)
$(.cloud-config.userdata.file): export NODE_HOST_IP := $(NODE_HOST_IP)
$(.cloud-config.userdata.file): | $(.cloud-config.tmp.dir)/

# yq expressions for cloud-config merging with environment variable substitution
# YQ cloud-config expressions (manually defined for now - TODO: metaprogramming)
define YQ_CLOUD_CONFIG_MERGE_REDUCE
select(fi == 0) |
( . as $$item ireduce (
	{ "write_files": [], "runcmd": [] };
	. * $$item |
	.write_files = (.write_files // []) + ($$item.write_files // []) |
	.runcmd = (.runcmd // []) + ($$item.runcmd // [])
	)
) |
( .write_files |= ( (. // []) | reverse | unique_by(.path) | reverse ) ) |
( .runcmd |= ( (. // []) | unique ) ) |
( .. | select( tag == "!!str" ) ) |= envsubst(ne,nu)
endef

# Single expression reused for all supported merge counts to avoid duplicate outputs
YQ_CLOUD_CONFIG_EXPR_2 = $(YQ_CLOUD_CONFIG_MERGE_REDUCE)
YQ_CLOUD_CONFIG_EXPR_3 = $(YQ_CLOUD_CONFIG_MERGE_REDUCE)
YQ_CLOUD_CONFIG_EXPR_5 = $(YQ_CLOUD_CONFIG_MERGE_REDUCE)
YQ_CLOUD_CONFIG_EXPR_6 = $(YQ_CLOUD_CONFIG_MERGE_REDUCE)

# Macro for executing the appropriate yq cloud-config merge based on file count
define EXECUTE_YQ_CLOUD_CONFIG_MERGE
$(if $(YQ_CLOUD_CONFIG_EXPR_$(1)),
mkdir -p $(.cloud-config.tmp.dir)
echo '$(YQ_CLOUD_CONFIG_EXPR_$(1))' > $(.cloud-config.yq.file)
yq eval-all --unwrapScalar --from-file=$(.cloud-config.yq.file) $(2) |
	sed -e '/^---$$/d' > $(.cloud-config.tmp.output)
 ( echo "#cloud-config"; cat $(.cloud-config.tmp.output) ) > $(3)
 rm -f $(.cloud-config.tmp.output) $(.cloud-config.yq.file),
$(error Unsupported file count: $(1) (expected 2, 3, 5, or 6)))
endef

$(.cloud-config.tmp.dir)/:
	mkdir -p $(@)

# Note: Dependencies already defined above for different node roles
$(call register-cloud-config-targets,$(.cloud-config.userdata.file))
$(.cloud-config.userdata.file):
	: "[+] Merging cloud-config fragments (common/server/node) with envsubst ..."
	$(eval _merge_sources := $(filter %.yaml,$^))
	$(eval _file_count := $(call length,$(_merge_sources)))
	$(call EXECUTE_YQ_CLOUD_CONFIG_MERGE,$(_file_count),$(_merge_sources),$@)
	yq eval --inplace '$(YQ_INLINE_SCRIPT_LOAD)' $@

#-----------------------------
# Generate NoCloud network-config file
#-----------------------------

$(call register-network-targets,$(.cloud-config.netcfg.file))
$(.cloud-config.netcfg.file): $(make-dir)/cloud-config/network-config.yaml
$(.cloud-config.netcfg.file): | $(.cloud-config.dir)/
$(.cloud-config.netcfg.file):
	: "[+] Rendering network-config (envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $< > $@

#-----------------------------
# Cloud-config validation and linting
#-----------------------------

CLOUD_CONFIG_FILES := $(wildcard $(.cloud-config.source_dir)/*.yaml)

.PHONY: lint@cloud-config validate@cloud-config

lint@cloud-config: ## Lint cloud-config YAML files
	: "[+] Linting cloud-config files..."
	yamllint $(CLOUD_CONFIG_FILES)

validate@cloud-config: $(.cloud-config.userdata.file) ## Validate merged cloud-config
	: "[+] Validating merged cloud-config..."
	cloud-init schema --config-file $(.cloud-config.userdata.file) || echo "cloud-init not available for validation"

#-----------------------------
# Cloud-config debugging targets  
#-----------------------------

.PHONY: show-files@cloud-config debug-merge@cloud-config

show-files@cloud-config: ## Show cloud-config files for current node type
	echo "Cloud-config files for $(node.name) ($(node.ROLE)):"
	echo "  Common: $(.cloud-config.common)"
	echo "  Server: $(.cloud-config.server)"
ifeq ($(node.ROLE),master)
	echo "  Master base: $(.cloud-config.master.base)"
	echo "  Master Cilium: $(.cloud-config.master.cilium)"
	echo "  Master Kube-vip: $(.cloud-config.master.kube_vip)"
else ifeq ($(node.ROLE),peer)
	echo "  Peer: $(.cloud-config.peer)"
endif

debug-merge@cloud-config: ## Debug cloud-config merge process
	: "[+] Debugging cloud-config merge for $(node.name)..."
	: "Files to merge: $^"
	: "Output file: $(.cloud-config.userdata.file)"
	: "File count: $(call length,$^)"

endif  # make.d/cloud-config/rules.mk guard
