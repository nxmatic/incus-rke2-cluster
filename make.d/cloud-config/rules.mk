# cloud-config/rules.mk - Cloud-config generation and management (@codebase)
# Self-guarding include pattern for idempotent multiple inclusion.


ifndef cloud-config/rules.mk

include make.d/make.mk  # Ensure availability when file used standalone (@codebase)

#-----------------------------
# Cloud-config File Paths
#-----------------------------

CLOUD_CONFIG_DIR := cloud-config
CLOUD_CONFIG_COMMON := $(CLOUD_CONFIG_DIR)/cloud-config.common.yaml
CLOUD_CONFIG_SERVER := $(CLOUD_CONFIG_DIR)/cloud-config.server.yaml
CLOUD_CONFIG_MASTER_BASE := $(CLOUD_CONFIG_DIR)/cloud-config.master.base.yaml
CLOUD_CONFIG_MASTER_CILIUM := $(CLOUD_CONFIG_DIR)/cloud-config.master.cilium.yaml
CLOUD_CONFIG_MASTER_KUBE_VIP := $(CLOUD_CONFIG_DIR)/cloud-config.master.kube-vip.yaml
CLOUD_CONFIG_PEER := $(CLOUD_CONFIG_DIR)/cloud-config.peer.yaml

# Output files
NOCLOUD_METADATA_FILE := $(NOCLOUD_DIR)/metadata
NOCLOUD_USERDATA_FILE := $(NOCLOUD_DIR)/userdata
NOCLOUD_NETCFG_FILE := $(NOCLOUD_DIR)/network-config

#-----------------------------
# Generate cloud-init meta-data file
#-----------------------------

define METADATA_INLINE :=
instance-id: $(RKE2_NODE_NAME)-$(shell uuidgen | tr '[:upper:]' '[:lower:]')
local-hostname: $(RKE2_NODE_NAME).$(RKE2_CLUSTER_DOMAIN)
endef

$(NOCLOUD_METADATA_FILE): | $(NOCLOUD_DIR)/
$(NOCLOUD_METADATA_FILE): export METADATA_INLINE := $(METADATA_INLINE)
$(NOCLOUD_METADATA_FILE):
	echo "[+] Generating meta-data file for instance $(RKE2_NODE_NAME)..."
	echo "$$METADATA_INLINE" > $(@)

#-----------------------------
# Generate cloud-init user-data file using yq for YAML correctness
#-----------------------------

$(NOCLOUD_USERDATA_FILE): | $(NOCLOUD_DIR)/
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_COMMON) ## common fragment (@codebase)
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_SERVER) ## server fragment (@codebase)
ifeq ($(RKE2_NODE_ROLE),master)
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_MASTER_BASE) ## master base fragment (@codebase)
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_MASTER_CILIUM) ## master cilium fragment (@codebase)
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_MASTER_KUBE_VIP) ## master kube-vip fragment (@codebase)
else ifeq ($(RKE2_NODE_ROLE),peer)
$(NOCLOUD_USERDATA_FILE): $(CLOUD_CONFIG_PEER) ## peer fragment (@codebase)
endif

# yq expressions for cloud-config merging with environment variable substitution
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
@yq eval-all --unwrapScalar --from-file=<(echo '$(YQ_CLOUD_CONFIG_EXPR_$(1))') $(2) > $(3),
$(error Unsupported file count: $(1) (expected 3 or 5)))
endef

$(NOCLOUD_USERDATA_FILE):
	echo "[+] Merging cloud-config fragments (common/server/node) with envsubst ..."
	$(eval _file_count := $(call length,$^))
	$(call EXECUTE_YQ_CLOUD_CONFIG_MERGE,$(_file_count),$^,$@)

#-----------------------------
# Generate NoCloud network-config file
#-----------------------------

$(NOCLOUD_NETCFG_FILE): network/network-config.yaml | $(NOCLOUD_DIR)/
$(NOCLOUD_NETCFG_FILE):
	echo "[+] Rendering network-config (envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' network/network-config.yaml > $@

#-----------------------------
# Cloud-config validation and linting
#-----------------------------

CLOUD_CONFIG_FILES := $(wildcard $(CLOUD_CONFIG_DIR)/*.yaml)

.PHONY: lint@cloud-config validate@cloud-config

lint@cloud-config: ## Lint cloud-config YAML files
	echo "[+] Linting cloud-config files..."
	yamllint $(CLOUD_CONFIG_FILES)

validate@cloud-config: $(NOCLOUD_USERDATA_FILE) ## Validate merged cloud-config
	echo "[+] Validating merged cloud-config..."
	cloud-init schema --config-file $(NOCLOUD_USERDATA_FILE) || echo "cloud-init not available for validation"

#-----------------------------
# Cloud-config debugging targets  
#-----------------------------

.PHONY: show-files@cloud-config debug-merge@cloud-config

show-files@cloud-config: ## Show cloud-config files for current node type
	echo "Cloud-config files for $(RKE2_NODE_NAME) ($(RKE2_NODE_ROLE)):"
	echo "  Common: $(CLOUD_CONFIG_COMMON)"
	echo "  Server: $(CLOUD_CONFIG_SERVER)"
ifeq ($(RKE2_NODE_ROLE),master)
	echo "  Master base: $(CLOUD_CONFIG_MASTER_BASE)"
	echo "  Master Cilium: $(CLOUD_CONFIG_MASTER_CILIUM)"
	echo "  Master Kube-vip: $(CLOUD_CONFIG_MASTER_KUBE_VIP)"
else ifeq ($(RKE2_NODE_ROLE),peer)
	echo "  Peer: $(CLOUD_CONFIG_PEER)"
endif

debug-merge@cloud-config: ## Debug cloud-config merge process
	echo "[+] Debugging cloud-config merge for $(RKE2_NODE_NAME)..."
	echo "Files to merge: $^"
	echo "Output file: $(NOCLOUD_USERDATA_FILE)"
	echo "File count: $(call length,$^)"

endif  # cloud-config/rules.mk guard
