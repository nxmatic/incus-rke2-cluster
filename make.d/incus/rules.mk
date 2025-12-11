# incus.mk - Incus Infrastructure Management (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/rules.mk

-include make.d/make.mk  # Ensure availability when file used standalone (@codebase)
-include make.d/node/rules.mk  # Node identity and role variables (@codebase)
-include make.d/cluster/rules.mk  # Cluster configuration and variables (@codebase)
-include make.d/network/rules.mk  # Network targets and variables (@codebase)
-include make.d/cloud-config/rules.mk  # Cloud-config targets and variables (@codebase)

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

# Directory layout (per-instance runtime)
.incus.secrets_file ?= $(abspath $(.make.top-dir)/.secrets)
YQ_BIN ?= $(shell command -v yq 2>/dev/null)

define incus-secret-from-yaml
$(strip $(if $(and $(YQ_BIN),$(wildcard $(.incus.secrets_file))),$(shell $(YQ_BIN) -r '$(1) // ""' $(.incus.secrets_file) 2>/dev/null),))
endef

define incus-secret
$(strip $(call incus-secret-from-yaml,$(1)))
endef
.incus.dir ?= $(run-dir)/incus
.incus.image_dir ?= $(.incus.dir)
.incus.instance_dir ?= $(.incus.dir)/$(node.NAME)
.incus.nocloud_dir ?= $(.incus.instance_dir)/nocloud
.incus.shared_dir ?= $(.incus.instance_dir)/shared
.incus.kubeconfig_dir ?= $(.incus.instance_dir)/kube
.incus.logs_dir ?= $(.incus.instance_dir)/logs

# Incus image / config artifacts  
.incus.preseed_filename ?= incus-preseed.yaml
.incus.preseed_file ?= $(.incus.dir)/preseed.yaml
.incus.distrobuilder_file ?= $(make-dir)/incus/incus-distrobuilder.yaml
.incus.distrobuilder_logfile ?= $(.incus.image_dir)/distrobuilder.log
.incus.image_import_marker_file ?= $(.incus.image_dir)/import.tstamp
.incus.image_build_files ?= $(.incus.image_dir)/incus.tar.xz $(.incus.image_dir)/rootfs.squashfs
.incus.project_marker_file ?= $(.incus.dir)/project.tstamp

.incus.config_instance_marker_file ?= $(.incus.instance_dir)/init-instance.tstamp
.incus.instance_config_filename ?= incus-instance-config.yaml
.incus.instance_config_template ?= $(make-dir)/incus/$(.incus.instance_config_filename)
.incus.instance_config_file ?= $(.incus.instance_dir)/config.yaml

# Per-instance NoCloud files  
.incus.instance_metadata_file ?= $(.incus.nocloud_dir)/metadata
.incus.instance_userdata_file ?= $(.incus.nocloud_dir)/userdata
.incus.instance_netcfg_file ?= $(.incus.nocloud_dir)/network-config

# RUN_ prefixed variables for template compatibility
.incus.run_instance_dir = $(.incus.instance_dir)
.incus.run_nocloud_metadata_file = $(.incus.instance_metadata_file)
.incus.run_nocloud_userdata_file = $(.incus.instance_userdata_file)
.incus.run_nocloud_netcfg_file = $(.incus.instance_netcfg_file)

# Cluster environment file
.incus.cluster_env_file ?= $(.incus.instance_dir)/cluster-env.mk
-include $(.incus.cluster_env_file)

# Primary/secondary host interfaces (macvlan parents)
.incus.lima_lan_interface ?= vmlan0
.incus.lima_vmnet_interface ?= vmwan0
.incus.lima_primary_interface ?= $(.incus.lima_lan_interface)
.incus.lima_secondary_interface ?= $(.incus.lima_vmnet_interface)
.incus.egress_interface ?= $(.incus.lima_primary_interface)

# Tailscale secrets (canonical naming only, file-based fallback removed) – used for image build & cleanup (@codebase)
# Notes:
#  - Secrets resolve exclusively from the SOPS-managed YAML (.secrets).
#  - Populate tailscale.*, github.*, and docker.configJson entries with `sops --in-place` edits.
.incus.tskey_client_id ?= $(call incus-secret,.tailscale.client.id)
.incus.tskey_client_token ?= $(call incus-secret,.tailscale.client.token)
.incus.tskey_api_id ?= $(call incus-secret,.tailscale.api.id)
.incus.tskey_api_token ?= $(call incus-secret,.tailscale.api.token)
.incus.cluster_github_token ?= $(call incus-secret,.github.token)
.incus.cluster_github_username ?= $(or $(call incus-secret,.github.username,),x-access-token)
.incus.docker_config_json ?= $(call incus-secret,.docker.configJson)

# Instance naming defaults (image alias)
.incus.image_name ?= control-node

# Cluster inet address discovery helpers (IP extraction via yq)
.incus.inet_yq_expr ?= .[].state.network.vmnet0.addresses[] | select(.family == "inet") | .address

# =============================================================================
# PUBLIC INCUS API  
# =============================================================================



# =============================================================================
# EXPORTS FOR TEMPLATE USAGE
# =============================================================================

# Export variables for use in YAML templates via yq envsubst
export RUN_INSTANCE_DIR := $(.incus.instance_dir)
export INCUS_PROJECT_NAME := rke2
export RUN_NOCLOUD_METADATA_FILE := $(.incus.run_nocloud_metadata_file)
export RUN_NOCLOUD_USERDATA_FILE := $(.incus.run_nocloud_userdata_file)
export RUN_NOCLOUD_NETCFG_FILE := $(.incus.run_nocloud_netcfg_file)
export INCUS_EGRESS_INTERFACE := $(.incus.egress_interface)
export TSKEY_CLIENT_ID := $(.incus.tskey_client_id)
export TSKEY_CLIENT_TOKEN := $(.incus.tskey_client_token)
# Fleet manifests repo provides the canonical kpt render tree (@codebase)
FLEET_MANIFESTS_ROOT ?= $(if $(wildcard /var/lib/git/nxmatic/fleet-manifests/.git),/var/lib/git/nxmatic/fleet-manifests,$(abspath $(top-dir)/fleet))
CLUSTER_STATE_DIR ?= $(FLEET_MANIFESTS_ROOT)/rke2/$(CLUSTER_NAME)
export CLUSTER_STATE_DIR
export CLUSTER_GITHUB_TOKEN := $(.incus.cluster_github_token)
export CLUSTER_GITHUB_USERNAME := $(.incus.cluster_github_username)
export CLUSTER_DOCKER_CONFIG_JSON := $(.incus.docker_config_json)
export NODE_PROFILE_NAME := $(network.NODE_PROFILE_NAME)
export IMAGE_NAME := $(.incus.image_name)
export CLUSTER_INET_MASTER := $(call cidr-to-host-ip,$(NODE_SUBNETS_NETWORK_0),$(call plus,10,0))
# Instance config always uses VM logical paths since Incus runs on the VM
export RUN_WORKSPACE_DIR := /var/lib/nixos/config/modules/nixos/incus-rke2-cluster
define INCUS_INET_CMD
$(shell incus list $(1) --format=yaml | yq eval '$(.incus.inet_yq_expr)' -)
endef

# Cluster master token template (retained for compatibility)
define MASTER_TOKEN_TEMPLATE
# Bootstrap server points at the master primary IP (CLUSTER_INET_MASTER now mapped to primary) (@codebase)
server: https://$(CLUSTER_INET_MASTER):9345
token: $(CLUSTER_TOKEN)
endef

# =============================================================================
# Cluster Environment File Generation (@codebase)
# =============================================================================

define .incus.cluster_env_template :=
CLUSTER_NAME=$(cluster.NAME)
NODE_NAME=$(node.NAME)
NODE_ROLE=$(node.ROLE)
CLUSTER_ID=$(cluster.ID)
NODE_ID=$(node.ID)
IMAGE_NAME=$(.incus.image_name)
endef

$(.incus.cluster_env_file): | $(.incus.instance_dir)/
$(.incus.cluster_env_file):
	: "[+] Generating cluster environment file $(@)" $(file >$(@),$(.incus.cluster_env_template))

# Incus execution mode: local (on NixOS) or remote (Darwin -> Lima) (@codebase)
.incus.remote_repo_root ?= /var/lib/nixos/config
.incus.exec.mode = $(if $(filter $(true),$(host.IS_REMOTE_INCUS_BUILD)),remote,local)

# Incus command invocation with conditional remote wrapper (@codebase)
.incus.remote_prefix = $(if $(filter remote,$(.incus.exec.mode)),$(REMOTE_EXEC),)
.incus.command = $(.incus.remote_prefix) incus
.incus.distrobuilder_command = $(.incus.remote_prefix) sudo distrobuilder

# Distrobuilder build context resolution (@codebase)
.incus.build.mode = $(.incus.exec.mode)
.incus.distrobuilder_workdir = $(if $(filter remote,$(.incus.build.mode)),$(.incus.remote_repo_root)/modules/nixos/incus-rke2-cluster,$(abspath $(top-dir)))
# Local build directory in VM (not virtiofs) for better filesystem compatibility
.incus.local_build_dir := $(shell mktemp -u -d --suffix=rke2)
# Absolute path used in build command; local mode uses repository-relative path directly
# Remote mode: prepend full subdirectory path from repo root to reach cluster workspace
# Configuration files (local paths only)
.incus.distrobuilder_file_abs = $(.incus.distrobuilder_file)

# =============================================================================
# BUILD VERIFICATION
# =============================================================================

# Preflight verification: ensure remote repo root and distrobuilder file exist (@codebase)
.PHONY: verify-context@incus
verify-context@incus:
	: "[+] Verifying distrobuilder context (local mode)"
	if sudo test -f $(.incus.distrobuilder_file_abs); then echo "  ✓ local distrobuilder file: $(.incus.distrobuilder_file_abs)"; else echo "  ✗ missing local distrobuilder file: $(.incus.distrobuilder_file_abs)"; fi



#-----------------------------
# Dependency Check Target
#-----------------------------

.PHONY: deps@incus
deps@incus: ## Check availability of local incus and required tools (@codebase)
	: "[+] Checking local Incus dependencies ...";
	ERR=0;
	for cmd in incus yq timeout distrobuilder; do
		if command -v $$cmd >/dev/null 2>&1; then
			echo "  ✓ $$cmd";
		else
			echo "  ✗ $$cmd (missing)"; ERR=1;
		fi;
	done;
	if [ "$$ERR" = "1" ]; then echo "[!] Required dependencies missing"; exit 1; fi;
	: "[+] Required dependencies present";
	: "[i] ipcalc usage confined to network layer (not required for incus lifecycle)"; ## @codebase

# Re-enable advanced targets include (non-recursive refactor complete)
-include advanced-targets.mk

#-----------------------------
# Preseed Rendering Targets
#-----------------------------

.PHONY: preseed@incus

preseed@incus: $(.incus.preseed_file)
preseed@incus:
	: "[+] Applying incus preseed ..."
	$(.incus.command) admin init --preseed < $(.incus.preseed_file)

$(.incus.preseed_file): $(make-dir)/incus/$(.incus.preseed_filename)
$(.incus.preseed_file): load@network
$(.incus.preseed_file): | $(.incus.dir)/
$(.incus.preseed_file):
	: "[+] Generating preseed file (pure envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $(<) > $@

# =============================================================================
# Instance Config Rendering (moved from Makefile) (@codebase)
# =============================================================================

$(.incus.instance_config_file): $(.incus.instance_config_template)
$(.incus.instance_config_file): $(.incus.project_marker_file)
$(.incus.instance_config_file): $(.incus.instance_metadata_file)
$(.incus.instance_config_file): $(.incus.instance_userdata_file) 
$(.incus.instance_config_file): $(.incus.instance_netcfg_file)
$(.incus.instance_config_file): | $(.incus.instance_dir)/
$(.incus.instance_config_file): | $(.incus.nocloud_dir)/
# Note: RUN_ variables exported globally above, NOCLOUD_ variables exported from cloud-config rules
$(.incus.instance_config_file):
	: "[+] Rendering instance config (envsubst via yq) ...";
	yq eval '( ... | select(tag=="!!str") ) |= envsubst(ne,nu)' $(.incus.instance_config_template) > $(@)

#-----------------------------
# Per-instance NoCloud file generation  
#-----------------------------

# Metadata and userdata now generated directly by cloud-config layer
# $(.incus.instance_metadata_file): $(NOCLOUD_METADATA_FILE) | $(.incus.nocloud_dir)/
# $(.incus.instance_metadata_file):
#	: "[+] Copying per-instance metadata file ..."
#	cp $(NOCLOUD_METADATA_FILE) $@

# $(.incus.instance_userdata_file): $(NOCLOUD_USERDATA_FILE) | $(.incus.nocloud_dir)/
# $(.incus.instance_userdata_file):
#	: "[+] Copying per-instance userdata file ..."  
#	cp $(NOCLOUD_USERDATA_FILE) $@

# Network-config now generated directly by cloud-config layer
# $(.incus.instance_netcfg_file): $(make-dir)/network/network-config.yaml test@network | $(.incus.nocloud_dir)/
# $(.incus.instance_netcfg_file):
#	: "[+] Rendering per-instance network-config (envsubst via yq) ..."
#	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $< > $@

.PHONY: render@instance-config
render@instance-config: test@network $(.incus.instance_config_file) ## Explicit render of Incus instance config
render@instance-config:
	: "[+] Instance config rendered at $(.incus.instance_config_file)"

.PHONY: validate@cluster
validate@cluster: test@network validate@cloud-config ## Aggregate cluster validation (network + cloud-config)
validate@cluster:
	: "[+] Cluster validation complete (network + cloud-config)"

#-----------------------------
# Project Management Targets
#-----------------------------

.PHONY: switch-project@incus remove-project@incus cleanup-orphaned-networks@incus
.PHONY: cleanup-instances@incus cleanup-images@incus cleanup-networks@incus cleanup-profiles@incus cleanup-volumes@incus remove-project-rke2@incus

switch-project@incus: preseed@incus ## Switch to RKE2 project and ensure images are available (@codebase)
switch-project@incus: $(.incus.project_marker_file)
switch-project@incus:
	: "[+] Switching to project $(CLUSTER_NAME)"
	$(.incus.command) project switch rke2 || true

remove-project@incus: cleanup-project-instances@incus ## Remove entire RKE2 project (destructive) (@codebase)
remove-project@incus: cleanup-project-images@incus
remove-project@incus: cleanup-project-networks@incus
remove-project@incus: cleanup-project-profiles@incus
remove-project@incus: cleanup-project-volumes@incus
remove-project@incus:
	: "[+] Deleting project $(CLUSTER_NAME)"
	$(.incus.command) project delete rke2 || true
	: "[+] Cleaning up local runtime directory..."
	rm -rf $(.incus.dir) 2>/dev/null || true

cleanup-orphaned-networks@incus: ## Clean up orphaned RKE2 networks in default project
	: "[+] Cleaning up orphaned RKE2-related networks in default project..."
	$(.incus.command) network list --project=default --format=csv -c n,u | \
		grep ',0$$' | cut -d, -f1 | \
		grep -E '(rke2|vmnet-br|lan-br)' | \
		xargs -r -n1 $(.incus.command) network delete --project=default 2>/dev/null || true
	: "[+] Cleaning up orphaned RKE2 profiles in default project..."
	$(.incus.command) profile list --project=default --format=csv -c n | \
		grep -E '(rke2|cluster)' | \
		xargs -r -n1 $(.incus.command) profile delete --project=default 2>/dev/null || true
	: "[+] Orphaned resource cleanup complete"

# =============================================================================
# METAPROGRAMMING: CLEANUP TARGET GENERATION  
# =============================================================================

# Template function to generate cleanup targets for different resource types
# Usage: $(call define-cleanup-target,RESOURCE_TYPE,list_command,yq_expr,delete_command)
define define-cleanup-target
cleanup-project-$(1)@incus: ## destructive: delete all $(1) in project rke2
	$(.incus.command) $(2) --project=rke2 --format=yaml | $(3) |
	  xargs -r -n1 $(4) || true
endef

# Generate cleanup targets for each resource type
$(eval $(call define-cleanup-target,instances,list,yq -r eval '.[].name',$(.incus.command) delete -f --project rke2))
$(eval $(call define-cleanup-target,images,image list,yq -r eval '.[].fingerprint',$(.incus.command) image delete --project rke2))
$(eval $(call define-cleanup-target,networks,network list,yq -r eval '.[].name',echo $(.incus.command) network delete --project rke2))
$(eval $(call define-cleanup-target,profiles,profile list,yq -r '.[] | select(.name != "default") | .name',$(.incus.command) profile delete --project rke2))

define INCUS_VOLUME_YQ
.[] | 
  with( select( .type | test("snapshot") | not and .type == "custom" ); .del=.name ) | 
  with( select( .type | test("snapshot") | not and .type != "custom" ); .del=( .type + "/" + .name ) ) |
  select( .type | test("snapshot") | not ) |
  .del
endef

cleanup-project-volumes@incus: cleanup-project-volumes-snapshots@incus
cleanup-project-volumes@incus: export YQ_EXPR := $(INCUS_VOLUME_YQ)
cleanup-project-volumes@incus: 
	: "destructive: delete all snapshots then volumes in each storage pool (project rke2)"
	$(.incus.command) storage volume list --project=rke2 --format=yaml default |
		yq -r --from-file=<(echo "$$YQ_EXPR") |
	    xargs -r -n1 $(.incus.command) storage volume delete --project=rke2 default || true

define INCUS_SNAPSHOT_YQ
.[] |
  with( select( .type | test("snapshot") ); .del=.name) |
  select( .type | test("snapshot") ) |
  .del
endef

cleanup-project-volumes-snapshots@incus: export YQ_EXPR := $(INCUS_SNAPSHOT_YQ)
cleanup-project-volumes-snapshots@incus: 
	: "destructive: delete all snapshots in each storage pool (project rke2)"
	$(.incus.command) storage volume list --project=rke2 --format=yaml default |
		yq -r --from-file=<(echo "$$YQ_EXPR") |
	    xargs -r -n1 $(.incus.command) storage volume snapshot delete --project=rke2 default || true

$(.incus.project_marker_file): $(.incus.preseed_file)
$(.incus.project_marker_file): | $(.incus.dir)/
$(.incus.project_marker_file):
	: "[+] Ensuring preseed configuration is applied..."
	$(.incus.command) admin init --preseed < $(.incus.preseed_file) || true
	: "[+] Creating incus project rke2 if not exists..."
	$(.incus.command) project create rke2 || true
	: "[+] Copying incus profile $(NODE_PROFILE_NAME) from default to rke2 project"
	$(.incus.command) profile copy --project=default --target-project=rke2 $(NODE_PROFILE_NAME) $(NODE_PROFILE_NAME) || true
	touch $@

#-----------------------------
# Network Diagnostics Targets
#-----------------------------

.PHONY: show-network@incus diagnostics@incus network-status@incus

show-network@incus: preseed@incus ## Show network configuration summary
show-network@incus:
	: "[i] Network Configuration Summary"
	: "================================="
	echo "Host LAN parent: $(LIMA_LAN_INTERFACE) -> container lan0 (macvlan)"
	echo "Incus bridge: vmnet -> container vmnet0"
	echo "VIP Gateway: $(CLUSTER_VIP_GATEWAY_IP) ($(CLUSTER_VIP_NETWORK_CIDR))"
	: "Mode: LAN macvlan + Incus bridge for cluster communication"
	: ""
	: "[i] Host interface state:"
	: "  $(LIMA_LAN_INTERFACE): $$(ip link show $(LIMA_LAN_INTERFACE) | grep -o 'state [A-Z]*' || echo 'unknown state')"
	: ""
	: "[i] IP assignments:"
	: "  $(LIMA_LAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_LAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"
	: ""
	: "(Container interfaces visible after instance start)"

diagnostics@incus: ## Run complete network diagnostics from host
diagnostics@incus:
	: "[i] Host Network Diagnostics"
	: "============================"
	: "Parent interfaces: $(LIMA_LAN_INTERFACE), $(LIMA_WAN_INTERFACE)"
	: "Host MACs:"
	: "  $(LIMA_LAN_INTERFACE): $$(cat /sys/class/net/$(LIMA_LAN_INTERFACE)/address 2>/dev/null || echo 'n/a')"
	: "  $(LIMA_WAN_INTERFACE): $$(cat /sys/class/net/$(LIMA_WAN_INTERFACE)/address 2>/dev/null || echo 'n/a')"
	: ""
	: "Host IP assignments:"
	: "  $(LIMA_LAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_LAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"
	: "  $(LIMA_WAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_WAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"

network-status@incus: ## Show container network status
	: "[i] Container Network Status"
	: "============================"
	: "Container: $(NODE_NAME)"
	if $(.incus.command) info $(NODE_NAME) --project=rke2 >/dev/null 2>&1; then
		: "Container network interfaces:";
		$(.incus.command) exec $(NODE_NAME) --project=rke2 -- ip -o addr show lan0 2>/dev/null || echo "  lan0: not available";
		$(.incus.command) exec $(NODE_NAME) --project=rke2 -- ip -o addr show vmnet0 2>/dev/null || echo "  vmnet0: not available";
		: "";
		: "Connectivity test:";
		$(.incus.command) exec $(NODE_NAME) --project=rke2 -- ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "  Internet: OK" || echo "  Internet: FAILED";
	else
		: "Container $(NODE_NAME) not found or not running";
	fi

#-----------------------------
# Image Management Targets
#-----------------------------

.PHONY: image@incus

image@incus: $(.incus.image_import_marker_file) ## Aggregate image build/import marker (@codebase)

$(.incus.image_import_marker_file): $(.incus.image_build_files)
$(.incus.image_import_marker_file): switch-project@incus
$(.incus.image_import_marker_file): | $(.incus.dir)/
$(.incus.image_import_marker_file):
	if $(.incus.command) image show $(IMAGE_NAME) --project=rke2 >/dev/null 2>&1; then
		: "[✓] Image $(IMAGE_NAME) already present; skipping import"
	else
		: "[+] Importing image for instance $(NODE_NAME) into rke2 project..."
		$(.incus.command) image import --alias $(IMAGE_NAME) $(.incus.image_build_files)
	fi
	touch $@

$(call register-distrobuilder-targets,$(.incus.image_build_files))
# ($(IMAGE_NAME)) TSKEY export removed; image build uses TSKEY_CLIENT directly (@codebase)
# Local build target that always uses local filesystem (never virtiofs)
# This is an internal target that creates the actual image files with robust cleanup
$(.incus.image_build_files)&: $(.incus.distrobuilder_file) | $(.incus.dir)/ verify-context@incus switch-project@incus
	: "[+] Building image files (local mode)"
	echo "[+] Building image locally using native filesystem (not virtiofs)"
	sudo mkdir -p $(.incus.dir)
	echo "[+] Building filesystem first, then packing into Incus image"
	sudo env -i PATH="$$PATH" DEBIAN_FRONTEND=noninteractive  \
		distrobuilder build-dir $(.incus.distrobuilder_file_abs) "$(.incus.local_build_dir)" --debug --disable-overlay --cleanup
	echo "[+] Creating temporary config for packing (without debootstrap options)"
	sed '/options:/,/variant: "buildd"/d' $(.incus.distrobuilder_file_abs) > "$(.incus.local_build_dir)-pack.yaml"
	echo "[+] Packing filesystem into Incus image format"
	sudo env -i PATH="$$PATH" HOME="$$HOME" USER="$$USER" DEBIAN_FRONTEND=noninteractive \
		distrobuilder pack-incus "$(.incus.local_build_dir)-pack.yaml" "$(.incus.local_build_dir)" $(.incus.dir) --debug

# Helper phony target for remote build delegation
.PHONY: build-image-local@incus
build-image-local@incus: $(.incus.image_build_files)
	: "[✓] Image build completed (files: $(.incus.image_build_files))"

# Manual cleanup targets for troubleshooting
.PHONY: cleanup-debootstrap@incus force-cleanup-debootstrap@incus
cleanup-debootstrap@incus: ## Clean up debootstrap temp directories manually
	$(.incus.cleanup_pre_cmd)

force-cleanup-debootstrap@incus: ## Force cleanup all temp directories and build artifacts
	: "[+] Force cleanup of all build-related temporary directories..."
	sudo rm -rf /tmp/tmp.*rke2* /tmp/*distrobuilder* /tmp/debian-* 2>/dev/null || true
	sudo find /tmp -name debootstrap -type d -exec rm -rf {} + 2>/dev/null || true
	sudo find /tmp -name "*.deb" -mtime -1 -exec rm -f {} + 2>/dev/null || true
	: "[+] Force cleanup complete"

# Explicit user-invocable phony targets for image build lifecycle (@codebase)
.PHONY: build-image@incus force-build-image@incus

# Normal build: rely on existing incremental rule; just report artifacts
build-image@incus: $(.incus.image_build_files)
	: "[+] Incus image artifacts present: $(.incus.image_build_files)"

# Force rebuild: remove artifacts then invoke underlying build rule
force-build-image@incus:
	: "[+] Forcing Incus image rebuild (removing old artifacts)";
	rm -f $(.incus.image_build_files)
	$(MAKE) $(.incus.image_build_files)
	: "[✓] Rebuild complete: $(.incus.image_build_files)"

#-----------------------------
# Instance Lifecycle Targets
#-----------------------------

.PHONY: create@incus start@incus shell@incus stop@incus delete@incus clean@incus remove-member@etcd
.ONESHELL:

# Ensure instance exists; if marker file is present but Incus instance is missing (e.g. created locally only), recreate.
## Grouped prerequisites for create@incus
# Image artifacts (auto-placeholders if image already imported in Incus) (@codebase)
create@incus: $(.incus.image_build_files)
# Instance configuration
create@incus: $(.incus.instance_config_file)
create@incus: $(.incus.config_instance_marker_file) ## Create instance configuration and setup (@codebase)
# Network dependencies
create@incus: generate@network
# Runtime directories (order-only)
create@incus: | $(.incus.dir)/
create@incus: | $(.incus.nocloud_dir)/
create@incus: | $(.incus.shared_dir)/
create@incus: | $(.incus.kubeconfig_dir)/
create@incus: | $(.incus.logs_dir)/
create@incus: switch-project@incus
create@incus:
	: "[+] Ensuring Incus instance $(NODE_NAME) in project rke2...";
	if ! $(.incus.command) info $(NODE_NAME) --project=rke2 >/dev/null 2>&1; then
		: "[!] Instance $(NODE_NAME) missing; creating";
		rm -f $(.incus.config_instance_marker_file);
		$(.incus.command) init $(IMAGE_NAME) $(NODE_NAME) --project=rke2 < $(.incus.instance_config_file);
	else
		: "[✓] Instance $(NODE_NAME) already exists";
	fi

.PHONY: recreate-create@incus
## Grouped prerequisites for create-create@incus
# Image availability / ensure
create-create@incus: ensure-image@incus

# Rendered instance config
create-create@incus: $(.incus.instance_config_file)
# Cluster environment context
create-create@incus: $(CLUSTER_ENV_FILE)
# Validated network (strict)
create-create@incus: test@network
# Runtime directories (order-only)
create-create@incus: | $(.incus.dir)/
create-create@incus: | $(.incus.shared_dir)/
create-create@incus: | $(.incus.kubeconfig_dir)/
create-create@incus: | $(.incus.logs_dir)/
create-create@incus:
	: "[+] Recreating Incus instance $(NAME) in project rke2...";
	$(.incus.command) init $(IMAGE_NAME) $(NAME) --project=rke2 < $(.incus.instance_config_file);

# Image ensure target (build + import if missing)
.PHONY: ensure-image@incus
ensure-image@incus:
	: "[+] Ensuring image $(IMAGE_NAME) exists in project rke2...";
	if ! $(.incus.command) image show $(IMAGE_NAME) --project=rke2 >/dev/null 2>&1; then
		echo "[e] Image $(IMAGE_NAME) missing";
		exit 1;
	fi
	: "[i] VIP interface defined in profile - no separate device addition needed"
	touch $(.incus.config_instance_marker_file)

# Helper target to rebuild marker safely (expands original dependency chain)

## Grouped prerequisites for init marker (instance first init)
# Imported image marker
$(.incus.config_instance_marker_file).init: $(.incus.image_import_marker_file)

# Instance configuration file
$(.incus.config_instance_marker_file).init: $(.incus.instance_config_file)
# Cluster environment file
$(.incus.config_instance_marker_file).init: $(.incus.cluster_env_file)
# Network validation
$(.incus.config_instance_marker_file).init: test@network
# Runtime directories (order-only)
$(.incus.config_instance_marker_file).init: | $(.incus.dir)/
$(.incus.config_instance_marker_file).init: | $(.incus.shared_dir)/
$(.incus.config_instance_marker_file).init: | $(.incus.kubeconfig_dir)/
$(.incus.config_instance_marker_file).init: | $(.incus.logs_dir)/
$(.incus.config_instance_marker_file).init:
	: "[+] Initializing instance $(NODE_NAME) in project rke2..."
	$(.incus.command) init $(IMAGE_NAME) $(NODE_NAME) --project=rke2 < $(.incus.instance_config_file)
	: "[i] Interfaces: lan0 (macvlan) + vmnet0 (Incus bridge)"

$(.incus.config_instance_marker_file): $(.incus.config_instance_marker_file).init
$(.incus.config_instance_marker_file): | $(.incus.dir)/ ## Ensure incus dir exists before cloud-init cleanup (@codebase)
	: "[+] Ensuring clean cloud-init state for fresh network configuration..."
	: $(.incus.command) exec $(NODE_NAME) -- rm -rf /var/lib/cloud/instance /var/lib/cloud/instances /var/lib/cloud/data /var/lib/cloud/sem || true
	: $(.incus.command) exec $(NODE_NAME) -- rm -rf /run/cloud-init /run/systemd/network/10-netplan-* || true
	touch $@

start@incus: switch-project@incus
start@incus: create@incus
start@incus: zfs.allow 
start@incus: ## Start the Incus instance
	$(call trace,Entering target: start@incus)
	$(call trace-var,NODE_NAME)
	$(call trace-incus,Starting instance $(NODE_NAME))
	: "[+] Starting instance $(NODE_NAME)...";
	if $(.incus.command) start $(NODE_NAME); then
		echo "✓ Instance $(NODE_NAME) started successfully";
	else
		echo "✗ Failed to start instance $(NODE_NAME)";
		exit 1;
	fi
	$(call trace,Completed target: start@incus)

shell@incus: ## Open interactive shell in the instance
	: "[+] Opening a shell in instance $(NODE_NAME)...";
	if $(.incus.command) info $(NODE_NAME) --project=rke2 >/dev/null 2>&1; then
		echo "✓ Instance $(NODE_NAME) is available";
		$(.incus.command) exec $(NODE_NAME) --project=rke2 -- zsh;
	else
		echo "✗ Instance $(NODE_NAME) not found or not running";
		echo "Use 'make start' to start the instance first";
		exit 1;
	fi

stop@incus: ## Stop the running instance
	: "[+] Stopping instance $(NODE_NAME) if running..."
	$(.incus.command) stop $(NODE_NAME) || true

delete@incus: ## Delete the instance (keeps configuration)
	: "[+] Removing instance $(NODE_NAME)..."
	$(.incus.command) delete -f $(NODE_NAME) || true
	rm -f $(.incus.config_instance_marker_file) || true

.PHONY: remove-member@etcd
remove-member@etcd: nodeName ?= $(NODE_NAME)
remove-member@etcd: ## Remove etcd member for peer/server nodes from cluster
	@if [ "$(nodeName)" != "master" ] && [ "$(NODE_TYPE)" = "server" ]; then
		: "[+] Removing etcd member for $(nodeName)..."
		if $(.incus.command) info master --project=rke2 >/dev/null 2>&1; then
			NODE_IP="10.80.$$(( $(cluster.ID) * 8 )).$$(( 10 + $(NODE_ID) ))"
			MEMBER_ID=$$($(.incus.command) exec master --project=rke2 -- etcdctl member list --write-out=simple | grep "$$NODE_IP" | awk '{print $$1}' | tr -d ',' || true)
			if [ -n "$$MEMBER_ID" ]; then
				: "[+] Found etcd member $$MEMBER_ID for $(nodeName) at $$NODE_IP"
				$(.incus.command) exec master --project=rke2 -- etcdctl member remove $$MEMBER_ID || true
				: "[✓] Removed etcd member $$MEMBER_ID"
			else
				: "[i] No etcd member found for $(nodeName) at $$NODE_IP"
			fi
		else
			: "[!] Master node not running, cannot remove etcd member"
		fi
	else
		: "[i] Skipping etcd member removal for $(nodeName) (master or non-server node)"
	fi

clean@incus: remove-member@etcd
clean@incus: delete@incus 
clean@incus: remove-hosts@tailscale
clean@incus: nodeName ?= $(NODE_NAME)
clean@incus: ## Remove instance, profiles, storage volumes, and runtime directories
	: "[+] Removing $(nodeName) if exists..."
	$(.incus.command) profile delete rke2-$(nodeName) --project=rke2 || true
	$(.incus.command) profile delete rke2-$(nodeName) --project default || true
	# All networks (LAN/WAN/VIP) are macvlan (no Incus-managed networks to delete)
	# Remove persistent storage volume to ensure clean cloud-init state
	$(.incus.command) storage volume delete default containers/$(nodeName) || true
	: "[+] Cleaning up run directory..."
	rm -fr $(.incus.instance_dir)

clean-all@incus: ## Clean all cluster nodes and shared resources (destructive)
	: "[+] Cleaning all nodes (master peers workers)...";
	for name in master peer1 peer2 peer3 worker1 worker2; do \
		echo "[+] Cleaning node $${name}..."; \
		$(.incus.command) delete $${name} --project=rke2 --force 2>/dev/null || true; \
		$(.incus.command) delete $${name} --project=default --force 2>/dev/null || true; \
		$(.incus.command) profile delete rke2-$${name} --project=rke2 2>/dev/null || true; \
		$(.incus.command) profile delete rke2-$${name} --project=default 2>/dev/null || true; \
		$(.incus.command) storage volume delete default containers/$${name} 2>/dev/null || true; \
	done; \
	: "[+] Removing entire local run directory..."; \
	rm -rf $(.incus.dir) 2>/dev/null || true; \
	: "[+] Cleaning shared cluster resources..."; \
	: "[+] Cleaning up Incus-managed networks..."; \
	$(.incus.command) network list --project=rke2 --format=csv -c n,t | grep ',bridge$$' | cut -d, -f1 | xargs -r -n1 $(.incus.command) network delete --project=rke2 2>/dev/null || true; \
	: "[+] Cleaning up shared profiles..."; \
	$(.incus.command) profile list --project=rke2 --format=csv -c n | grep -v '^default$$' | xargs -r -n1 $(.incus.command) profile delete --project=rke2 2>/dev/null || true; \
	: "[+] All cluster resources cleaned up"

#-----------------------------
# ZFS Permissions Target
#-----------------------------

.PHONY: zfs.allow

zfs.allow: $(INCUS_ZFS_ALLOW_MARKER_FILE)

$(INCUS_ZFS_ALLOW_MARKER_FILE):| $(DIR)/
	: "[+] Allowing ZFS permissions for tank..."
	$(SUDO) zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	$(SUDO) zfs allow -e @allperms tank
	touch $@

#-----------------------------
# Tailscale Device Cleanup Target
#-----------------------------

.PHONY: remove-hosts@tailscale

define TAILSCALE_RM_HOSTS_SCRIPT
curl -fsSL -H "Authorization: Bearer $${TSKEY_API}" https://api.tailscale.com/api/v2/tailnet/-/devices |
	yq -p json eval --from-file=<(echo "$${YQ_EXPR}") |
	xargs -I{} curl -fsS -X DELETE -H "Authorization: Bearer $${TSKEY_API}" "https://api.tailscale.com/api/v2/device/{}"
endef

define TAILSCALE_RM_HOSTS_YQ_EXPR
.devices[] | 
  select( .hostname | 
          test("^$(CLUSTER_NAME)-(tailscale-operator|controlplane)") ) |
	.id
endef

remove-hosts@tailscale: export TSID := $(TSID)
# (legacy TSKEY removed; using global TSKEY_API) (@codebase)
remove-hosts@tailscale: export HOST := $(CLUSTER_NAME)
remove-hosts@tailscale: export SCRIPT := $(TAILSCALE_RM_HOSTS_SCRIPT)
remove-hosts@tailscale: export YQ_EXPR := $(TAILSCALE_RM_HOSTS_YQ_EXPR)
remove-hosts@tailscale: export NODE := $(NAME)
remove-hosts@tailscale:
	: "[+] Querying Tailscale devices with key $${TSKEY_API},prefix $${HOST}, yq-expr $${YQ_EXPR} ..."
	( [[ $$NODE == "master" ]] && eval "$$SCRIPT" ) || true

endif  # incus/rules.mk guard
