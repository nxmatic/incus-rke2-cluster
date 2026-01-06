# incus.mk - Incus Infrastructure Management (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/rules.mk

make.d/incus/rules.mk := make.d/incus/rules.mk  # guard to allow safe re-inclusion (@codebase)

-include make.d/make.mk  # Ensure availability when file used standalone (@codebase)
-include make.d/node/rules.mk  # Node identity and role variables (@codebase)
-include make.d/cluster/rules.mk  # Cluster configuration and variables (@codebase)
-include make.d/network/rules.mk  # Network targets and variables (@codebase)
-include make.d/kpt/rules.mk  # KPT catalog targets and variables (@codebase)
-include make.d/cloud-config/rules.mk  # Cloud-config targets and variables (@codebase)

-include $(.incus.env.file)

# =============================================================================
# PRIVATE VARIABLES (internal layer implementation)
# =============================================================================

.incus.dir = $(rke2-subtree.dir)/$(cluster.name)/incus
.incus.build.local.dir = /tmp/incus-build/$(strip $(cluster.name))
	
# should be kept outside of ZFS
.incus.image.dir = $(.incus.dir)
.incus.instance.dir = $(.incus.dir)/$(node.name)
.incus.nocloud.dir = $(.incus.instance.dir)/nocloud
.incus.shared.dir = $(.incus.instance.dir)/shared
.incus.kubeconfig.dir = $(.incus.instance.dir)/kube
.incus.logs.dir = $(.incus.instance.dir)/logs

# Incus image / config artifacts  
.incus.preseed.filename = incus-preseed.yaml
.incus.preseed.file = $(.incus.dir)/preseed.yaml
.incus.distrobuilder.file = $(make-dir)/incus/incus-distrobuilder.yaml
.incus.distrobuilder.log.file = $(.incus.image.dir)/distrobuilder.log
.incus.image.import.marker.file = $(.incus.image.dir)/import.tstamp
.incus.image.build.files = $(.incus.image.dir)/incus.tar.xz $(.incus.image.dir)/rootfs.squashfs
.incus.project.marker.file = $(.incus.dir)/project.tstamp

.incus.instance.config.marker.file = $(.incus.instance.dir)/init-instance.tstamp
.incus.instance.config.filename = incus-instance-config.yaml
.incus.instance.config.template = $(make-dir)/incus/$(.incus.instance.config.filename)
.incus.instance.config.file = $(.incus.instance.dir)/config.yaml

# Per-instance NoCloud files  
.incus.instance.metadata.file = $(.incus.nocloud.dir)/metadata
.incus.instance.userdata.file = $(.incus.nocloud.dir)/userdata
.incus.instance.netcfg.file = $(.incus.nocloud.dir)/network-config

# RUN_ prefixed variables for template compatibility
.incus.run.instance.dir = $(.incus.instance.dir)
.incus.run.nocloud.metadata.file = $(.incus.instance.metadata.file)
.incus.run.nocloud.userdata.file = $(.incus.instance.userdata.file)
.incus.run.nocloud.netcfg.file = $(.incus.instance.netcfg.file)
.incus.cleanup.pre.cmd =

# Cluster environment file
.incus.env.file = $(.incus.instance.dir)/env.mk

# Primary/secondary host interfaces (macvlan parents)
.incus.lima.lan.interface = vmlan0
.incus.lima.vmnet.interface = vmwan0
.incus.lima.primary.interface = $(.incus.lima.lan.interface)
.incus.lima.secondary.interface = $(.incus.lima.vmnet.interface)
.incus.egress.interface = $(.incus.lima.primary.interface)

# Instance naming defaults (image alias)
.incus.image.name = control-node

# Cluster inet address discovery helpers (IP unwrapping via yq)
.incus.inet.yq.expr = .[].state.network.vmnet0.addresses[] | select(.family == "inet") | .address

# =============================================================================
# Cluster Environment File Generation (@codebase)
# =============================================================================

# Cluster master token template (retained for compatibility)
.cluster.master.inet = $(call network.subnet-host-ip,node,0,10)

define .incus.cluster.token.content :=
# Bootstrap server points at the master primary IP (@codebase)
server: https://$(.cluster.master.inet):9345
token: $(cluster.token)
endef

# =============================================================================
# Cluster Environment File Generation (@codebase)
# =============================================================================

define .incus.env.content :=
# Generated assignments for cluster $(cluster.name) (ID: $(cluster.id)) - do not edit manually

export INCUS_CLUSTER_NAME=$(cluster.name)
export INCUS_CLUSTER_TOKEN=$(cluster.token)
export INCUS_CLUSTER_DOMAIN=$(cluster.domain)
export INCUS_NODE_NAME=$(node.name)
export INCUS_NODE_ROLE=$(node.role)
export INCUS_CLUSTER_ID=$(cluster.id)
export INCUS_NODE_ID=$(node.id)
export INCUS_IMAGE_NAME=$(.incus.image.name)

export INCUS_CLUSTER_RK2E_MANIFESTS_DIR=$(abspath $(.kpt.manifests.dir))
export INCUS_CLUSTER_RKE2_CONFIG_DIR=$(abspath $(rke2-subtree.dir)/$(cluster.name)/catalog/runtime/rke2-config)

export INCUS_HOST_SUPERNET_CIDR=$(network.host.supernet.cidr)
export INCUS_CLUSTER_NETWORK_CIDR=$(network.cluster.cidr)
export INCUS_CLUSTER_NETWORK_POD_CIDR=$(network.cluster.pod.cidr)
export INCUS_CLUSTER_NETWORK_SERVICE_CIDR=$(cluster.service.cidr)
export INCUS_CLUSTER_VIP_NETWORK_CIDR=$(network.cluster.vip.cidr)
export INCUS_CLUSTER_VIP_GATEWAY_IP=$(network.cluster.vip.gateway)
export INCUS_CLUSTER_LOADBALANCER_NETWORK_CIDR=$(network.cluster.lb.cidr)
export INCUS_CLUSTER_LOADBALANCER_GATEWAY_IP=$(network.cluster.lb.gateway)
export INCUS_NODE_NETWORK_CIDR=$(network.node.cidr)
export INCUS_NODE_GATEWAY_IP=$(network.node.gateway.inet)
export INCUS_NODE_HOST_IP=$(network.node.host.inet)
export INCUS_NODE_VIP_IP=$(network.node.vip.inet)
export INCUS_NODE_LAN_INTERFACE_NAME=$(network.node.lan.interface)
export INCUS_NODE_VMNET_INTERFACE_NAME=$(network.node.vmnet.interface)
export INCUS_CLUSTER_VIP_INTERFACE_NAME=$(network.cluster.vip.interface)
export INCUS_VIP_VLAN_ID=$(network.vip.vlan.id)
export INCUS_VIP_VLAN_NAME=$(network.vip.vlan.name)
export INCUS_LAN_BR_HWADDR=$(network.lan.bridge.mac)
export INCUS_CLUSTER_GATEWAY_IP=$(network.cluster.gateway.inet)
export INCUS_WAN_DHCP_RANGE=$(network.wan.dhcp.range)
export INCUS_NODE_WAN_MAC=$(network.node.wan.mac)
export INCUS_NODE_LAN_MAC=$(network.node.lan.mac)
export INCUS_NODE_PROFILE_NAME=$(network.node.profile.name)
export INCUS_MASTER_NODE_IP=$(network.master.node.inet)

export INCUS_LAN_LOADBALANCER_POOL=$(network.lan.lb.pool)
export INCUS_LAN_HEADSCALE_IP=$(network.lan.headscale.inet)
export INCUS_LAN_TAILSCALE_IP=$(network.lan.tailscale.inet)
export INCUS_HOME_LAN_LOADBALANCER_POOL=$(network.lan.lb.pool)

export INCUS_NODE_WAN_MAC_MASTER=$(shell printf '52:54:00:%02x:00:00' $(cluster.id))
export INCUS_NODE_WAN_MAC_PEER1=$(shell printf '52:54:00:%02x:00:01' $(cluster.id))
export INCUS_NODE_WAN_MAC_PEER2=$(shell printf '52:54:00:%02x:00:02' $(cluster.id))
export INCUS_NODE_WAN_MAC_PEER3=$(shell printf '52:54:00:%02x:00:03' $(cluster.id))
export INCUS_NODE_WAN_MAC_WORKER1=$(shell printf '52:54:00:%02x:01:0a' $(cluster.id))
export INCUS_NODE_WAN_MAC_WORKER2=$(shell printf '52:54:00:%02x:01:0b' $(cluster.id))
export INCUS_CLUSTER_NODE_IP_BASE=$(call cidr-to-base-inetaddr,$(network.host.split.$(.cluster.id).cidr))
export INCUS_PROJECT_NAME=rke2
export INCUS_RUN_INSTANCE_DIR=$(.incus.instance.dir)
export INCUS_RUN_NOCLOUD_METADATA_FILE=$(.incus.run.nocloud.metadata.file)
export INCUS_RUN_NOCLOUD_USERDATA_FILE=$(.incus.run.nocloud.userdata.file)
export INCUS_RUN_NOCLOUD_NETCFG_FILE=$(.incus.run.nocloud.netcfg.file)
export INCUS_CLUSTER_INET_MASTER=$(call network.subnet-host-ip,node,0,9)
export INCUS_RUN_WORKSPACE_DIR=/var/lib/nixos/config/modules/nixos/incus-rke2-cluster
export INCUS_EGRESS_INTERFACE=$(.incus.egress.interface)
endef

$(.incus.env.file): $(.network.subnets.mk.files) | $(.incus.instance.dir)/
$(.incus.env.file):
	: "[+] Generating cluster environment file $(@)" $(file >$(@),$(.incus.env.content))

# Incus execution mode: local (on NixOS) or remote (Darwin -> Lima) (@codebase)
.incus.remote.repo.root = /var/lib/nixos/config
.incus.exec.mode = $(if $(filter $(true),$(host.IS_REMOTE_INCUS_BUILD)),remote,local)

# Incus command invocation with conditional remote wrapper (@codebase)
.incus.remote.prefix = $(if $(filter remote,$(.incus.exec.mode)),$(REMOTE_EXEC),)
.incus.command = $(.incus.remote.prefix) incus
.incus.distrobuilder.command = $(.incus.remote.prefix) sudo distrobuilder

# Distrobuilder build context resolution (@codebase)
.incus.build.mode = $(.incus.exec.mode)
.incus.distrobuilder.workdir = $(if $(filter remote,$(.incus.build.mode)),$(.incus.remote.repo.root)/modules/nixos/incus-rke2-cluster,$(abspath $(top-dir)))
.incus.distrobuilder.file.abs = $(.incus.distrobuilder.file)

# =============================================================================
# BUILD VERIFICATION
# =============================================================================

# Preflight verification: ensure remote repo root and distrobuilder file exist (@codebase)
.PHONY: verify-context@incus
verify-context@incus:
	: "[+] Verifying distrobuilder context (local mode)"
	if sudo test -f $(.incus.distrobuilder.file.abs); then
	  echo "  ✓ local distrobuilder file: $(.incus.distrobuilder.file.abs)"
	else
	  echo "  ✗ missing local distrobuilder file: $(.incus.distrobuilder.file.abs)" 2>&2
	  exit 1
	fi



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

preseed@incus: $(.incus.preseed.file)
preseed@incus:
	: "[+] Applying incus preseed ..."
	$(.incus.command) admin init --preseed < $(.incus.preseed.file)

$(.incus.preseed.file): $(make-dir)/incus/$(.incus.preseed.filename)
$(.incus.preseed.file): $(.incus.env.file)
$(.incus.preseed.file): | $(.incus.dir)/
$(.incus.preseed.file):
	: "[+] Generating preseed file (pure envsubst via yq) ..."
	set -a; . $(.incus.env.file); set +a; \
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $(<) > $@

# =============================================================================
# Instance Config Rendering (moved from Makefile) (@codebase)
# =============================================================================

$(.incus.instance.config.file): $(.incus.instance.config.template)
$(.incus.instance.config.file): $(.incus.project.marker.file)
$(.incus.instance.config.file): $(.incus.instance.metadata.file)
$(.incus.instance.config.file): $(.incus.instance.userdata.file) 
$(.incus.instance.config.file): $(.incus.instance.netcfg.file)
$(.incus.instance.config.file): $(.incus.env.file)
$(.incus.instance.config.file): $(.kpt.manifests.dir)
$(.incus.instance.config.file): | $(.incus.instance.dir)/
$(.incus.instance.config.file): | $(.incus.nocloud.dir)/
$(.incus.instance.config.file):
	: "[+] Rendering instance config (envsubst via yq) ...";
	set -a; . $(.incus.env.file); set +a; \
	yq eval '( ... | select(tag=="!!str") ) |= envsubst(ne,nu)' $(.incus.instance.config.template) > $(@)

#-----------------------------
# Per-instance NoCloud file generation  
#-----------------------------

.PHONY: render@instance-config
render@instance-config: test@network $(.incus.instance.config.file) ## Explicit render of Incus instance config
render@instance-config:
	: "[+] Instance config rendered at $(.incus.instance.config.file)"

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
switch-project@incus: $(.incus.project.marker.file)
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

$(.incus.project.marker.file): $(.incus.preseed.file)
$(.incus.project.marker.file): | $(.incus.dir)/
$(.incus.project.marker.file):
	: "[+] Ensuring preseed configuration is applied..."
	$(.incus.command) admin init --preseed < $(.incus.preseed.file) || true
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
	: "Container: $(node.name)"
	if $(.incus.command) info $(node.name) --project=rke2 >/dev/null 2>&1; then
		: "Container network interfaces:";
		$(.incus.command) exec $(node.name) --project=rke2 -- ip -o addr show lan0 2>/dev/null || echo "  lan0: not available";
		$(.incus.command) exec $(node.name) --project=rke2 -- ip -o addr show vmnet0 2>/dev/null || echo "  vmnet0: not available";
		: "";
		: "Connectivity test:";
		$(.incus.command) exec $(node.name) --project=rke2 -- ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "  Internet: OK" || echo "  Internet: FAILED";
	else
		: "Container $(node.name) not found or not running";
	fi

#-----------------------------
# Image Management Targets
#-----------------------------

.PHONY: image@incus

image@incus: $(.incus.image.import.marker.file) ## Aggregate image build/import marker (@codebase)

$(.incus.image.import.marker.file): $(.incus.image.build.files)
$(.incus.image.import.marker.file): switch-project@incus
$(.incus.image.import.marker.file): | $(.incus.dir)/
$(.incus.image.import.marker.file):
	if $(.incus.command) image show $(.incus.image.name) --project=rke2 >/dev/null 2>&1; then
		: "[✓] Image $(.incus.image.name) already present; skipping import"
	else
		: "[+] Importing image for instance $(node.name) into rke2 project..."
		$(.incus.command) image import --alias $(.incus.image.name) $(.incus.image.build.files)
	fi
	touch $@

$(call register-distrobuilder-targets,$(.incus.image.build.files))
# ($(.incus.image.name)) TSKEY export removed; image build uses TSKEY_CLIENT directly (@codebase)
# Local build target that always uses local filesystem (never virtiofs)
# This is an internal target that creates the actual image files with robust cleanup
$(.incus.image.build.files)&: $(.incus.distrobuilder.file) | $(.incus.dir)/ verify-context@incus switch-project@incus
	: "[+] Building image files (local mode)"
	echo "[+] Building image locally using native filesystem (not virtiofs)"
	sudo mkdir -p $(.incus.dir)
	echo "[+] Building filesystem first, then packing into Incus image"
	sudo distrobuilder build-dir $(.incus.distrobuilder.file.abs) "$(.incus.build.local.dir)" --disable-overlay
	echo "[+] Creating temporary config for packing (without debootstrap options)"
	PACK_CFG="/tmp/${cluster.name}-pack.yaml"
	sed '/^options:/,/^ *variant: "buildd"/d' $(.incus.distrobuilder.file.abs) > "$$PACK_CFG"
	echo "  [i] pack config: $$PACK_CFG"
	echo "[+] Packing filesystem into Incus image format"
	sudo distrobuilder pack-incus "$$PACK_CFG" "$(.incus.build.local.dir)" $(.incus.dir) --debug

# Helper phony target for remote build delegation
.PHONY: build-image-local@incus
build-image-local@incus: $(.incus.image.build.files)
	: "[✓] Image build completed (files: $(.incus.image.build.files))"

# Manual cleanup targets for troubleshooting
.PHONY: cleanup-debootstrap@incus force-cleanup-debootstrap@incus
cleanup-debootstrap@incus: ## Clean up debootstrap temp directories manually
	$(.incus.cleanup.pre.cmd)

force-cleanup-debootstrap@incus: ## Force cleanup all temp directories and build artifacts
	: "[+] Force cleanup of all build-related temporary directories..."
	sudo rm -rf /tmp/tmp.*rke2* /tmp/*distrobuilder* /tmp/debian-* 2>/dev/null || true
	sudo find /tmp -name debootstrap -type d -exec rm -rf {} + 2>/dev/null || true
	sudo find /tmp -name "*.deb" -mtime -1 -exec rm -f {} + 2>/dev/null || true
	: "[+] Force cleanup complete"

# Explicit user-invocable phony targets for image build lifecycle (@codebase)
.PHONY: build-image@incus force-build-image@incus

# Normal build: rely on existing incremental rule; just report artifacts
build-image@incus: $(.incus.image.build.files)
	: "[+] Incus image artifacts present: $(.incus.image.build.files)"

# Force rebuild: remove artifacts then invoke underlying build rule
force-build-image@incus:
	: "[+] Forcing Incus image rebuild (removing old artifacts)";
	rm -f $(.incus.image.build.files)
	$(MAKE) $(.incus.image.build.files)
	: "[✓] Rebuild complete: $(.incus.image.build.files)"

#-----------------------------
# Instance Lifecycle Targets
#-----------------------------

.PHONY: create@incus start@incus shell@incus stop@incus delete@incus clean@incus remove-member@etcd
.ONESHELL:

# Ensure instance exists; if marker file is present but Incus instance is missing (e.g. created locally only), recreate.
## Grouped prerequisites for create@incus
# Image artifacts (auto-placeholders if image already imported in Incus) (@codebase)
create@incus: $(.incus.image.build.files)
# Instance configuration
create@incus: $(.incus.instance.config.file)
create@incus: $(.incus.instance.config.marker.file) ## Create instance configuration and setup (@codebase)
# Runtime directories (order-only)
create@incus: | $(.incus.dir)/
create@incus: | $(.incus.nocloud.dir)/
create@incus: | $(.incus.shared.dir)/
create@incus: | $(.incus.kubeconfig.dir)/
create@incus: | $(.incus.logs.dir)/
create@incus: | $(.kpt.manifests.dir)/
create@incus: switch-project@incus
create@incus:
	: "[+] Ensuring Incus instance $(node.name) in project rke2...";
	if ! $(.incus.command) info $(node.name) --project=rke2 >/dev/null 2>&1; then
		: "[!] Instance $(node.name) missing; creating";
		rm -f $(.incus.instance.config.marker.file);
		$(.incus.command) init $(.incus.image.name) $(node.name) --project=rke2 < $(.incus.instance.config.file);
	else
		: "[✓] Instance $(node.name) already exists";
	fi

.PHONY: recreate-create@incus
## Grouped prerequisites for create-create@incus
# Image availability / ensure
create-create@incus: ensure-image@incus

# Rendered instance config
create-create@incus: $(.incus.instance.config.file)
# Cluster environment context
create-create@incus: $(CLUSTER_ENV_FILE)
# Validated network (strict)
create-create@incus: test@network
# Runtime directories (order-only)
create-create@incus: | $(.incus.dir)/
create-create@incus: | $(.incus.shared.dir)/
create-create@incus: | $(.incus.kubeconfig.dir)/
create-create@incus: | $(.incus.logs.dir)/
create-create@incus:
	: "[+] Recreating Incus instance $(node.name) in project rke2...";
	$(.incus.command) init $(.incus.image.name) $(node.name) --project=rke2 < $(.incus.instance.config.file);

# Image ensure target (build + import if missing)
.PHONY: ensure-image@incus
ensure-image@incus:
	: "[+] Ensuring image $(.incus.image.name) exists in project rke2...";
	if ! $(.incus.command) image show $(.incus.image.name) --project=rke2 >/dev/null 2>&1; then
		echo "[e] Image $(.incus.image.name) missing";
		exit 1;
	fi
	: "[i] VIP interface defined in profile - no separate device addition needed"
	touch $(.incus.instance.config.marker.file)

# Helper target to rebuild marker safely (expands original dependency chain)

## Grouped prerequisites for init marker (instance first init)
# Imported image marker
$(.incus.instance.config.marker.file).init: $(.incus.image.import.marker.file)

# Instance configuration file
$(.incus.instance.config.marker.file).init: $(.incus.instance.config.file)
# Cluster environment file
$(.incus.instance.config.marker.file).init: $(.incus.env.file)
# Network validation
$(.incus.instance.config.marker.file).init: test@network
# Runtime directories (order-only)
$(.incus.instance.config.marker.file).init: | $(.incus.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.shared.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.kubeconfig.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.logs.dir)/
$(.incus.instance.config.marker.file).init:
	: "[+] Initializing instance $(node.name) in project rke2..."
	$(.incus.command) init $(.incus.image.name) $(node.name) --project=rke2 < $(.incus.instance.config.file)
	: "[i] Interfaces: lan0 (macvlan) + vmnet0 (Incus bridge)"

$(.incus.instance.config.marker.file): $(.incus.instance.config.marker.file).init
$(.incus.instance.config.marker.file): | $(.incus.dir)/ ## Ensure incus dir exists before cloud-init cleanup (@codebase)
	: "[+] Ensuring clean cloud-init state for fresh network configuration..."
	: $(.incus.command) exec $(node.name) -- rm -rf /var/lib/cloud/instance /var/lib/cloud/instances /var/lib/cloud/data /var/lib/cloud/sem || true
	: $(.incus.command) exec $(node.name) -- rm -rf /run/cloud-init /run/systemd/network/10-netplan-* || true
	touch $@

start@incus: switch-project@incus
start@incus: create@incus
start@incus: zfs.allow 
start@incus: ## Start the Incus instance
	$(call trace,Entering target: start@incus)
	$(call trace-var,incus.node.name)
	$(call trace-incus,Starting instance $(node.name))
	: "[+] Starting instance $(node.name)...";
	if $(.incus.command) start $(node.name); then
		echo "✓ Instance $(node.name) started successfully";
	else
		echo "✗ Failed to start instance $(node.name)";
		exit 1;
	fi
	$(call trace,Completed target: start@incus)

shell@incus: ## Open interactive shell in the instance
	: "[+] Opening a shell in instance $(node.name)...";
	if $(.incus.command) info $(node.name) --project=rke2 >/dev/null 2>&1; then
		echo "✓ Instance $(node.name) is available";
		$(.incus.command) exec $(node.name) --project=rke2 -- zsh;
	else
		echo "✗ Instance $(node.name) not found or not running";
		echo "Use 'make start' to start the instance first";
		exit 1;
	fi

stop@incus: ## Stop the running instance
	: "[+] Stopping instance $(node.name) if running..."
	$(.incus.command) stop $(node.name) || true

delete@incus: ## Delete the instance (keeps configuration)
	: "[+] Removing instance $(node.name)..."
	$(.incus.command) delete -f $(node.name) || true
	rm -f $(.incus.instance.config.marker.file) || true

.PHONY: remove-member@etcd
remove-member@etcd: nodeName = $(node.name)
remove-member@etcd: ## Remove etcd member for peer/server nodes from cluster
	@if [ "$(nodeName)" != "master" ] && [ "$(NODE_TYPE)" = "server" ]; then
		: "[+] Removing etcd member for $(nodeName)..."
		if $(.incus.command) info master --project=rke2 >/dev/null 2>&1; then
			NODE_IP="10.80.$$(( $(cluster.id) * 8 )).$$(( 10 + $(NODE_ID) ))"
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
clean@incus: nodeName = $(node.name)
clean@incus: ## Remove instance, profiles, storage volumes, and runtime directories
	: "[+] Removing $(nodeName) if exists..."
	$(.incus.command) profile delete rke2-$(nodeName) --project=rke2 || true
	$(.incus.command) profile delete rke2-$(nodeName) --project default || true
	# All networks (LAN/WAN/VIP) are macvlan (no Incus-managed networks to delete)
	# Remove persistent storage volume to ensure clean cloud-init state
	$(.incus.command) storage volume delete default containers/$(nodeName) || true
	: "[+] Cleaning up run directory..."
	rm -fr $(.incus.instance.dir)

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

.incus.zfs.allow.marker.file = $(rke2-subtree.dir)/zfs-allow-tank.marker

zfs.allow: $(.incus.zfs.allow.marker.file) ## Ensure ZFS permissions are set for Incus on tank dataset

$(.incus.zfs.allow.marker.file):| $(.incus.zfs.allow.marker.dir)/
$(.incus.zfs.allow.marker.file):
	: "[+] Allowing ZFS permissions for tank..."
	$(SUDO) zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	$(SUDO) zfs allow -e @allperms tank
	touch $@

endif  # incus/rules.mk guard
