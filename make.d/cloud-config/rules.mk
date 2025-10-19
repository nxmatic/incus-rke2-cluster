# cloud-config/rules.mk - Cloud-config generation and management (@codebase)
# Self-guarding include pattern for idempotent multiple inclusion.

ifndef make.d/cloud-config/rules.mk

-include make.d/make.mk  # Ensure availability when file used standalone (@codebase)
-include make.d/node/rules.mk  # Node identity and role variables (@codebase)
-include make.d/network/rules.mk  # Network configuration variables (@codebase)
-include make.d/cluster/rules.mk  # Cluster configuration and variables (@codebase)

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

# Cloud-config source template paths
.cloud-config.source_dir := $(make-dir)/cloud-config
.cloud-config.common := $(.cloud-config.source_dir)/cloud-config.common.yaml
.cloud-config.server := $(.cloud-config.source_dir)/cloud-config.server.yaml
.cloud-config.master_base := $(.cloud-config.source_dir)/cloud-config.master.base.yaml
.cloud-config.master_cilium := $(.cloud-config.source_dir)/cloud-config.master.cilium.yaml
.cloud-config.master_kube_vip := $(.cloud-config.source_dir)/cloud-config.master.kube-vip.yaml
.cloud-config.peer := $(.cloud-config.source_dir)/cloud-config.peer.yaml

# Output files (nocloud format) - node-specific paths matching incus structure
.cloud-config.nocloud_dir := $(run-dir)/incus/$(node.NAME)/nocloud
.cloud-config.metadata_file := $(.cloud-config.nocloud_dir)/metadata
.cloud-config.userdata_file := $(.cloud-config.nocloud_dir)/userdata
.cloud-config.netcfg_file := $(.cloud-config.nocloud_dir)/network-config

# =============================================================================
# PUBLIC CLOUD-CONFIG API
# =============================================================================

# Public cloud-config API (used by other layers)
cloud-config.NOCLOUD_DIR := $(.cloud-config.nocloud_dir)
cloud-config.METADATA_FILE := $(.cloud-config.metadata_file)
cloud-config.USERDATA_FILE := $(.cloud-config.userdata_file)
cloud-config.NETWORK_CONFIG_FILE := $(.cloud-config.netcfg_file)

# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export cloud-config variables for use in YAML templates via yq envsubst
export NOCLOUD_METADATA_FILE := $(cloud-config.METADATA_FILE)
export NOCLOUD_USERDATA_FILE := $(cloud-config.USERDATA_FILE)
export NOCLOUD_NETCFG_FILE := $(cloud-config.NETWORK_CONFIG_FILE)

# =============================================================================
# CLOUD-CONFIG GENERATION RULES
# =============================================================================

# Metadata template (private)
define .cloud-config.metadata_template :=
instance-id: $(node.NAME)-$(shell uuidgen | tr '[:upper:]' '[:lower:]')
local-hostname: $(node.NAME).$(cluster.DOMAIN)
endef

$(call register-cloud-config-targets,$(.cloud-config.metadata_file))
$(.cloud-config.metadata_file): | $(.cloud-config.nocloud_dir)/
$(.cloud-config.metadata_file): export METADATA_INLINE := $(.cloud-config.metadata_template)
$(.cloud-config.metadata_file):
	echo "[+] Generating meta-data file for instance $(node.NAME)..."
	echo "$$METADATA_INLINE" > $(@)

#-----------------------------
# Generate cloud-init user-data file using yq for YAML correctness
#-----------------------------

$(.cloud-config.userdata_file): | $(.cloud-config.nocloud_dir)/
$(.cloud-config.userdata_file): $(.cloud-config.common) ## common fragment (@codebase)
$(.cloud-config.userdata_file): $(.cloud-config.server) ## server fragment (@codebase)
ifeq ($(node.ROLE),master)
$(.cloud-config.userdata_file): $(.cloud-config.master_base) ## master base fragment (@codebase)
$(.cloud-config.userdata_file): $(.cloud-config.master_cilium) ## master cilium fragment (@codebase)
$(.cloud-config.userdata_file): $(.cloud-config.master_kube_vip) ## master kube-vip fragment (@codebase)
else ifeq ($(node.ROLE),peer)
$(.cloud-config.userdata_file): $(.cloud-config.peer) ## peer fragment (@codebase)
endif

# yq expressions for cloud-config merging with environment variable substitution
# YQ cloud-config expressions (manually defined for now - TODO: metaprogramming)
define YQ_CLOUD_CONFIG_MERGE_3_FILES
"#cloud-config" as $$preamble | \
select(fileIndex == 0) as $$a | \
select(fileIndex == 1) as $$b | \
select(fileIndex == 2) as $$c | \
($$a * $$b * $$c) | \
.write_files = ($$a.write_files // []) + ($$b.write_files // []) + ($$c.write_files // []) | \
.runcmd = ($$a.runcmd // []) + ($$b.runcmd // []) + ($$c.runcmd // []) | \
( .. | select( tag == "!!str" ) ) |= envsubst(ne,nu) | \
$$preamble + "\n" + (. | to_yaml | sub("^---\n"; ""))
endef

define YQ_CLOUD_CONFIG_MERGE_5_FILES
"#cloud-config" as $$preamble | \
select(fileIndex == 0) as $$a | \
select(fileIndex == 1) as $$b | \
select(fileIndex == 2) as $$c | \
select(fileIndex == 3) as $$d | \
select(fileIndex == 4) as $$e | \
($$a * $$b * $$c * $$d * $$e) | \
.write_files = ($$a.write_files // []) + ($$b.write_files // []) + ($$c.write_files // []) + ($$d.write_files // []) + ($$e.write_files // []) | \
.runcmd = ($$a.runcmd // []) + ($$b.runcmd // []) + ($$c.runcmd // []) + ($$d.runcmd // []) + ($$e.runcmd // []) | \
( .. | select( tag == "!!str" ) ) |= envsubst(ne,nu) | \
$$preamble + "\n" + (. | to_yaml | sub("^---\n"; ""))
endef

# YQ cloud-config expression lookup by file count
YQ_CLOUD_CONFIG_EXPR_3 = $(YQ_CLOUD_CONFIG_MERGE_3_FILES)
YQ_CLOUD_CONFIG_EXPR_5 = $(YQ_CLOUD_CONFIG_MERGE_5_FILES)

# Macro for executing the appropriate yq cloud-config merge based on file count
define EXECUTE_YQ_CLOUD_CONFIG_MERGE
$(if $(YQ_CLOUD_CONFIG_EXPR_$(1)),
echo '$(YQ_CLOUD_CONFIG_EXPR_$(1))' > $(3).yq && yq eval-all --unwrapScalar --from-file=$(3).yq $(2) > $(3) && rm $(3).yq,
$(error Unsupported file count: $(1) (expected 3 or 5)))
endef

# Note: Dependencies already defined above for different node roles
$(call register-cloud-config-targets,$(.cloud-config.userdata_file))
$(.cloud-config.userdata_file):
	echo "[+] Merging cloud-config fragments (common/server/node) with envsubst ..."
	$(eval _file_count := $(call length,$^))
	$(call EXECUTE_YQ_CLOUD_CONFIG_MERGE,$(_file_count),$^,$@)

#-----------------------------
# Generate NoCloud network-config file
#-----------------------------

$(call register-network-targets,$(.cloud-config.netcfg_file))
$(.cloud-config.netcfg_file): $(make-dir)/network/network-config.yaml
$(.cloud-config.netcfg_file): | $(.cloud-config.nocloud_dir)/
$(.cloud-config.netcfg_file):
	echo "[+] Rendering network-config (envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $< > $@

#-----------------------------
# Cloud-config validation and linting
#-----------------------------

CLOUD_CONFIG_FILES := $(wildcard $(.cloud-config.source_dir)/*.yaml)

.PHONY: lint@cloud-config validate@cloud-config

lint@cloud-config: ## Lint cloud-config YAML files
	echo "[+] Linting cloud-config files..."
	yamllint $(CLOUD_CONFIG_FILES)

validate@cloud-config: $(.cloud-config.userdata_file) ## Validate merged cloud-config
	echo "[+] Validating merged cloud-config..."
	cloud-init schema --config-file $(.cloud-config.userdata_file) || echo "cloud-init not available for validation"

#-----------------------------
# Cloud-config debugging targets  
#-----------------------------

.PHONY: show-files@cloud-config debug-merge@cloud-config

show-files@cloud-config: ## Show cloud-config files for current node type
	echo "Cloud-config files for $(node.NAME) ($(node.ROLE)):"
	echo "  Common: $(.cloud-config.common)"
	echo "  Server: $(.cloud-config.server)"
ifeq ($(node.ROLE),master)
	echo "  Master base: $(.cloud-config.master_base)"
	echo "  Master Cilium: $(.cloud-config.master_cilium)"
	echo "  Master Kube-vip: $(.cloud-config.master_kube_vip)"
else ifeq ($(node.ROLE),peer)
	echo "  Peer: $(.cloud-config.peer)"
endif

debug-merge@cloud-config: ## Debug cloud-config merge process
	echo "[+] Debugging cloud-config merge for $(node.NAME)..."
	echo "Files to merge: $^"
	echo "Output file: $(.cloud-config.userdata_file)"
	echo "File count: $(call length,$^)"

endif  # make.d/cloud-config/rules.mk guard
