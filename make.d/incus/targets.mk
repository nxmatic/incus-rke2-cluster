# incus-targets.mk - Incus phony targets and rules (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/targets.mk
make.d/incus/targets.mk := make.d/incus/targets.mk

# =============================================================================
# BUILD VERIFICATION
# =============================================================================

.PHONY: verify-context@incus
verify-context@incus:
	: "[+] Verifying distrobuilder context (local mode)"
	if $(SUDO) test -f $(.incus.distrobuilder.file.abs); then
	  echo "  ✓ local distrobuilder file: $(.incus.distrobuilder.file.abs)";
	else
	  echo "  ✗ missing local distrobuilder file: $(.incus.distrobuilder.file.abs)" 2>&2;
	  exit 1;
	fi

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

-include advanced-targets.mk

#-----------------------------
# Preseed Rendering Targets
#-----------------------------

.PHONY: preseed@incus

preseed@incus: $(.incus.preseed.file)
preseed@incus:
	: "[+] Applying incus preseed ..."
	incus admin init --preseed < $(.incus.preseed.file)

$(.incus.preseed.file): $(make-dir)/incus/$(.incus.preseed.filename)
$(.incus.preseed.file): $(incus.env.mk) $(network.env.mk) $(node.env.file) $(cluster.env.mk)
$(.incus.preseed.file): | $(.incus.dir)/
$(.incus.preseed.file):
	: "[+] Generating preseed file (pure envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $(<) > $@

# =============================================================================
# Instance Config Rendering (moved from Makefile) (@codebase)
# =============================================================================

$(.incus.instance.config.file): $(.incus.instance.config.template)
$(.incus.instance.config.file): $(.incus.project.marker.file)
$(.incus.instance.config.file): $(.cloud-config.metadata.file)
$(.incus.instance.config.file): $(.cloud-config.userdata.file)
$(.incus.instance.config.file): $(.cloud-config.netcfg.file)
$(.incus.instance.config.file): $(.incus.env.file)
$(.incus.instance.config.file): $(incus.env.mk) $(network.env.mk) $(node.env.mk) $(cluster.env.mk)
$(.incus.instance.config.file): $(.kpt.manifests.dir)
$(.incus.instance.config.file): | $(.incus.dir)/
$(.incus.instance.config.file): | $(.incus.nocloud.dir)/
$(.incus.instance.config.file): | $(.incus.shared.dir)/
$(.incus.instance.config.file): | $(.incus.kubeconfig.dir)/
$(.incus.instance.config.file):
	: "[+] Rendering instance config (envsubst via yq) ...";
	yq eval '( ... | select(tag=="!!str") ) |= envsubst(ne,nu)' $(.incus.instance.config.template) > $(@)

define .incus.env.file.content
: "[i] Setting root user environment variables"
USER=root
HOME=/root
: "[i] Generating RKE2LAB environment variables"
RKE2LAB_ROOT=/srv/host
RKE2LAB_ENV_FILE=/srv/host/environment
RKE2LAB_SCRIPTS_DIR=/srv/host/scripts.d
RKE2LAB_SYSTEMD_DIR=/srv/host/system.d
RKE2LAB_CONFIG_DIR=/srv/host/config.d
RKE2LAB_MANIFESTS_DIR=/srv/host/manifests.d
RKE2LAB_SHARED_DIR=/srv/host/share.d
RKE2LAB_KUBECONFIG_DIR=/srv/host/kubeconfig.d
RKE2LAB_DEBUG=false
RKE2LAB_NODE_TYPE=$(NODE_TYPE)
RKE2LAB_CLUSTER_NAME=$(CLUSTER_NAME)
RKE2LAB_CLUSTER_TOKEN=$(CLUSTER_TOKEN)
RKE2LAB_CLUSTER_DOMAIN=$(CLUSTER_DOMAIN)
RKE2LAB_NODE_NAME=$(NODE_NAME)
RKE2LAB_NODE_ROLE=$(NODE_ROLE)
RKE2LAB_NODE_TYPE=$(NODE_TYPE)
RKE2LAB_NODE_ROLE=$(NODE_ROLE)
RKE2LAB_CLUSTER_ID=$(CLUSTER_ID)
RKE2LAB_NODE_ID=$(NODE_ID)
RKE2LAB_NODE_HOST_INETADDR=$(NETWORK_NODE_HOST_INETADDR)
RKE2LAB_NODE_VIP_INETADDR=$(NETWORK_NODE_VIP_INETADDR)
RKE2LAB_NODE_NETWORK_CIDR=$(NETWORK_NODE_CIDR)
RKE2LAB_NODE_GATEWAY_INETADDR=$(NETWORK_NODE_GATEWAY_INETADDR)
RKE2LAB_VIP_INTERFACE=$(NETWORK_VIP_INTERFACE)
RKE2LAB_CLUSTER_VIP_CIDR=$(NETWORK_VIP_CIDR)
RKE2LAB_CLUSTER_VIP_GATEWAY_INETADDR=$(NETWORK_VIP_GATEWAY_INETADDR)
RKE2LAB_CLUSTER_CIDR=$(NETWORK_CLUSTER_CIDR)
RKE2LAB_CLUSTER_LB_CIDR=$(NETWORK_CLUSTER_LB_CIDR)
RKE2LAB_CLUSTER_LB_GATEWAY_INETADDR=$(NETWORK_CLUSTER_LB_GATEWAY_INETADDR)
RKE2LAB_CLUSTER_POD_CIDR=$(NETWORK_CLUSTER_POD_CIDR)
RKE2LAB_CLUSTER_SERVICE_CIDR=$(NETWORK_CLUSTER_SERVICE_CIDR)
RKE2LAB_LAN_LB_POOL=$(NETWORK_LAN_LB_POOL)
RKE2LAB_NODE_LAN_INTERFACE=$(NETWORK_NODE_LAN_INTERFACE)
RKE2LAB_NODE_WAN_INTERFACE=$(NETWORK_NODE_WAN_INTERFACE)
RKE2LAB_CLUSTER_GATEWAY_INETADDR=$(NETWORK_CLUSTER_GATEWAY_INETADDR)
: "[i] RKE2 environment variables"
RKE2_SERVER_MANIFESTS_DIR=/var/lib/rancher/rke2/server/manifests
: "[i] containerd environment variables"
CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
CONTAINERD_NAMESPACE=k8s.io
CONTAINERD_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/containerd/config.toml
: "[i] cri environment variables"
CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
: "[i] etcdctl environment variables"
ETCDCTL_API=3
ETCDCTL_CERT=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt
ETCDCTL_KEY=/var/lib/rancher/rke2/server/tls/etcd/server-client.key
ETCDCTL_CACERT=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt
ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
ETCDCTL_WRITE_OUT=table
ETCDCTL_DIAL_TIMEOUT=10s
ETCDCTL_COMMAND_TIMEOUT=30s
: "[i] kubectl environment variables"
KUBECTL_OUTPUT=yaml
KUBECTL_EXTERNAL_DIFF=delta
KREW_ROOT=/var/lib/rancher/rke2/krew
: "[i] helm environment variables"
CILIUM_CLI_MODE=kubernetes
CILIUM_CLI_CONTEXT=default
HUBBLE_SERVER=localhost:4245
HUBBLE_TLS=false
: "[i] helm environment variables"
HELM_DATA_HOME=/var/lib/rancher/rke2/helm
HELM_CONFIG_HOME=/etc/rancher/rke2/helm
HELM_CACHE_HOME=/var/cache/rancher/rke2/helm
HELM_REPOSITORY_CONFIG=/etc/rancher/rke2/helm/repositories.yaml
HELM_REPOSITORY_CACHE=/var/cache/rancher/rke2/helm/repository
HELM_PLUGINS=/var/lib/rancher/rke2/helm/plugins
: "[i] kpt environment variables"
KRM_FN_RUNTIME=nerdctl
endef

$(.incus.env.file): $(incus.env.mk) $(network.env.mk) $(node.env.mk) $(cluster.env.mk)
$(.incus.env.file): | $(.incus.dir)/
$(.incus.env.file):
	: "[+] Generating RKE2LAB environment file (bind-mount target) ...";
	$(file >$(@),$(.incus.env.file.content))

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
	: "[+] Switching to project $(RKE2_CLUSTER_NAME)"
	incus project switch $(.incus.project.name) || true

remove-project@incus: cleanup-project-instances@incus ## Remove entire RKE2 project (destructive) (@codebase)
remove-project@incus: cleanup-project-images@incus
remove-project@incus: cleanup-project-networks@incus
remove-project@incus: cleanup-project-profiles@incus
remove-project@incus: cleanup-project-volumes@incus
remove-project@incus:
	: "[+] Deleting project $(RKE2_CLUSTER_NAME)"
	incus project delete $(.incus.project.name) || true
	: "[+] Cleaning up local runtime directory..."
	rm -rf $(.incus.dir) 2>/dev/null || true

cleanup-orphaned-networks@incus: ## Clean up orphaned RKE2 networks in default project
	: "[+] Cleaning up orphaned RKE2-related networks in default project..."
	incus network list --project=default --format=csv -c n,u | \
		grep ',0$$' | cut -d, -f1 | \
		grep -E '(rke2|vmnet-br|lan-br)' | \
		xargs -r -n1 incus network delete --project=default 2>/dev/null || true
	: "[+] Cleaning up orphaned RKE2 profiles in default project..."
	incus profile list --project=default --format=csv -c n | \
		grep -E '($(.incus.project.name)' | \
		xargs -r -n1 incus profile delete --project=default 2>/dev/null || true
	: "[+] Orphaned resource cleanup complete"

# =============================================================================
# METAPROGRAMMING: CLEANUP TARGET GENERATION  
# =============================================================================

# Generate cleanup targets for each resource type
$(eval $(call define-cleanup-target,instances,list,yq -r eval '.[].name',incus delete -f --project=$(.incus.project.name)))
$(eval $(call define-cleanup-target,images,image list,yq -r eval '.[].fingerprint',incus image delete --project=$(.incus.project.name)))
$(eval $(call define-cleanup-target,networks,network list,yq -r eval '.[].name',echo incus network delete --project=$(.incus.project.name)))
$(eval $(call define-cleanup-target,profiles,profile list,yq -r '.[] | select(.name != "default") | .name',incus profile delete --project=$(.incus.project.name)))

define VOLUME_YQ
.[] | 
  with( select( .type | test("snapshot") | not and .type == "custom" ); .del=.name ) | 
  with( select( .type | test("snapshot") | not and .type != "custom" ); .del=( .type + "/" + .name ) ) |
  select( .type | test("snapshot") | not ) |
  .del
endef

cleanup-project-volumes@incus: cleanup-project-volumes-snapshots@incus
cleanup-project-volumes@incus: export YQ_EXPR := $(VOLUME_YQ)
cleanup-project-volumes@incus: 
	: "destructive: delete all snapshots then volumes in each storage pool (project rke2)"
	incus storage volume list --project=$(.incus.project.name) --format=yaml default |
		yq -r --from-file=<(echo "$$YQ_EXPR") |
	    xargs -r -n1 incus storage volume delete --project=$(.incus.project.name) default || true

define SNAPSHOT_YQ
.[] |
  with( select( .type | test("snapshot") ); .del=.name) |
  select( .type | test("snapshot") ) |
  .del
endef

cleanup-project-volumes-snapshots@incus: export YQ_EXPR := $(SNAPSHOT_YQ)
cleanup-project-volumes-snapshots@incus: 
	: "destructive: delete all snapshots in each storage pool (project rke2)"
	incus storage volume list --project=$(.incus.project.name) --format=yaml default |
		yq -r --from-file=<(echo "$$YQ_EXPR") |
	    xargs -r -n1 incus storage volume snapshot delete --project=$(.incus.project.name) default || true

$(.incus.project.marker.file): $(.incus.preseed.file)
$(.incus.project.marker.file): | $(.incus.dir)/
$(.incus.project.marker.file):
	: "[+] Ensuring preseed configuration is applied..."
	incus admin init --preseed < $(.incus.preseed.file) || true
	: "[+] Creating incus project $(.incus.project.name) if not exists..."
	incus project create $(.incus.project.name) || true
	: "[+] Ensuring profile $(NODE_PROFILE_NAME) exists in project $(.incus.project.name) (no default project dependency)"
	if ! incus profile show --project=$(.incus.project.name) $(NODE_PROFILE_NAME) >/dev/null 2>&1; then \
		incus profile create --project=$(.incus.project.name) $(NODE_PROFILE_NAME); \
		incus profile device add --project=$(.incus.project.name) $(NODE_PROFILE_NAME) root disk path=/ pool=default; \
		incus profile device add --project=$(.incus.project.name) $(NODE_PROFILE_NAME) lan0 nic nictype=bridged parent=lan-br name=lan0; \
		incus profile device add --project=$(.incus.project.name) $(NODE_PROFILE_NAME) vmnet0 nic network=vmnet-br name=vmnet0; \
	fi
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
	echo "VIP Gateway: $(RKE2_CLUSTER_VIP_GATEWAY_INETADDR) ($(RKE2_CLUSTER_VIP_NETWORK_CIDR))"
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
	if incus info $(node.name) --project=$(.incus.project.name) >/dev/null 2>&1; then
		: "Container network interfaces:";
		incus exec $(node.name) --project=$(.incus.project.name) -- ip -o addr show lan0 2>/dev/null || echo "  lan0: not available";
		incus exec $(node.name) --project=$(.incus.project.name) -- ip -o addr show vmnet0 2>/dev/null || echo "  vmnet0: not available";
		: "";
		: "Connectivity test:";
		incus exec $(node.name) --project=$(.incus.project.name) -- ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "  Internet: OK" || echo "  Internet: FAILED";
	else
		: "Container $(node.name) not found or not running";
	fi

#-----------------------------
# Image Management Targets
#-----------------------------

.PHONY: image@incus

image@incus: $(.incus.image.marker.file) ## Aggregate image build/import marker (@codebase)

$(.incus.image.marker.file): $(.incus.image.build.files)
$(.incus.image.marker.file): | switch-project@incus
$(.incus.image.marker.file): | $(.incus.dir)/
$(.incus.image.marker.file): | $(.incus.dir)/kube/
$(.incus.image.marker.file): | $(.incus.dir)/logs/
$(.incus.image.marker.file): | $(.incus.dir)/shared/
$(.incus.image.marker.file):
	: "[+] Importing image for instance $(node.name) into rke2 project $(.incus.project.name)..."
	incus image delete --project=$(.incus.project.name) $(.incus.image.name) 2>/dev/null || true
	incus image import \
	  --project=$(.incus.project.name) \
	  --alias=$(.incus.image.name) \
	   $(.incus.image.build.files)
	$(SUDO) touch $@
	$(SUDO) chown $(USER):$(USER) $@

$(call register-distrobuilder-targets,$(.incus.image.build.files))
# ($(.incus.image.name)) TSKEY export removed; image build uses TSKEY_CLIENT directly (@codebase)
# Ensure tmpfs-backed runtime before building
.PHONY: ensure-image-tmpfs@incus
ensure-image-tmpfs@incus:
	$(SUDO) mkdir -p $(.incus.image.dir)
	if findmnt -rno FSTYPE --target $(.incus.image.dir) 2>/dev/null | grep -q '^tmpfs$$'; then \
		: "[✓] tmpfs already mounted at $(.incus.image.dir)"; \
	else \
		: "[!] $(.incus.image.dir) not on tmpfs; mounting tmpfs..."; \
		$(SUDO) mount -t tmpfs -o size=4G tmpfs $(.incus.image.dir); \
	fi
	$(SUDO) mkdir -p $(.incus.image.build.dir) $(.incus.image.pack.dir)

$(.incus.image.dir)/:
	$(SUDO) mkdir -p $(.incus.image.dir)

# Local build target that always uses local filesystem (never virtiofs)
# This is an internal target that creates the actual image files with robust cleanup
$(.incus.image.build.files)&: $(.incus.distrobuilder.file) | ensure-image-tmpfs@incus $(.incus.image.dir)/ verify-context@incus switch-project@incus
	: "[+] Building image locally using native filesystem (not virtiofs)"
	$(SUDO) mkdir -p $(.incus.dir) $(.incus.image.dir) $(.incus.image.build.dir) $(.incus.image.pack.dir)
	: "[+] Building filesystem first, then packing into Incus image"
	DIST_CFG=$(realpath $(.incus.distrobuilder.file))
	$(SUDO) distrobuilder build-dir "$$DIST_CFG"  "$(.incus.image.build.dir)" --disable-overlay
	: "[+] Creating pack config in runtime workspace (without debootstrap options)"
	PACK_CFG="$(.incus.image.pack.config)"
	sed '/^options:/,/^ *variant: "buildd"/d' "$$DIST_CFG" | $(SUDO) tee "$$PACK_CFG" >/dev/null
	: "[+] Packing filesystem into Incus image format"
	$(SUDO) distrobuilder pack-incus "$$PACK_CFG" "$(.incus.image.build.dir)" $(.incus.image.dir) --debug
	: "[+] Rebuilding squashfs explicitly (verbose) fixing up the built image"
	$(SUDO) rm -f $(.incus.image.dir)/rootfs.squashfs
	$(SUDO) mksquashfs $(.incus.image.build.dir) $(.incus.image.dir)/rootfs.squashfs $(.incus.mksquashfs.opts)
	$(SUDO) rm -fr $(.incus.image.build.dir)
	$(SUDO) chown -R $(USER):$(USER) $(.incus.image.dir)

# Helper phony target for remote build delegation
.PHONY: distrobuilder@incus
distrobuilder@incus: $(.incus.image.build.files)
	: "[✓] Image build completed (files: $(.incus.image.build.files))"

# Runtime reset target (clears tmpfs workspace by remounting)
.PHONY: reset-runtime@incus
reset-runtime@incus: ## Clear Incus runtime tmpfs workspace
	: "[+] Resetting Incus runtime tmpfs at $(.incus.image.dir)"s
	if findmnt -rno FSTYPE --target $(.incus.image.dir) 2>/dev/null | grep -q '^tmpfs$$'; then \
		$(SUDO) umount $(.incus.image.dir) || true; \
	fi
	$(SUDO) mkdir -p $(.incus.image.dir)
	$(SUDO) mount -t tmpfs tmpfs $(.incus.image.dir)
	$(SUDO) mkdir -p $(.incus.image.dir) $(.incus.image.build.dir) $(.incus.image.pack.dir)
	: "[✓] Runtime tmpfs reset and ready"

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
# Instance configuration
create@incus: $(.incus.instance.config.file)
create@incus: $(.incus.instance.config.marker.file)
create@incus: $(.incus.ghcr.secret.manifest)
# Runtime directories (order-only)
create@incus: | $(.incus.dir)/
create@incus: | $(.incus.nocloud.dir)/
create@incus: | $(kpt.manifests.dir)/
create@incus: | switch-project@incus
create@incus:  ## Create instance configuration and setup (@codebase)d
	: "[+] Ensuring Incus instance $(node.name) in project rke2...";
	if ! incus info $(node.name) --project=$(.incus.project.name) >/dev/null 2>&1; then
		: "[!] Instance $(node.name) missing; creating";
		rm -f $(.incus.instance.config.marker.file);
		incus init $(.incus.image.name) $(node.name) --project=$(.incus.project.name) < $(.incus.instance.config.file);
	else
		: "[✓] Instance $(node.name) already exists";
	fi

# Image ensure target (build + import if missing)
.PHONY: ensure-image@incus
ensure-image@incus:
	: "[+] Ensuring image $(.incus.image.name) exists in project rke2...";
	if ! incus image show $(.incus.image.name) --project=$(.incus.project.name) >/dev/null 2>&1; then
		echo "[e] Image $(.incus.image.name) missing";
		exit 1;
	fi
	: "[i] VIP interface defined in profile - no separate device addition needed"
	touch $(.incus.instance.config.marker.file)

# Helper target to rebuild marker safely (expands original dependency chain)

## Grouped prerequisites for init marker (instance first init)
$(.incus.instance.config.marker.file).init: $(.incus.image.marker.file)
$(.incus.instance.config.marker.file).init: $(.incus.instance.config.file)
$(.incus.instance.config.marker.file).init: $(.incus.env.file)
$(.incus.instance.config.marker.file).init: $(kpt.manifests.dir)
$(.incus.instance.config.marker.file).init: $(.cloud-config.metadata.file)
$(.incus.instance.config.marker.file).init: $(.cloud-config.userdata.file)
$(.incus.instance.config.marker.file).init: $(.cloud-config.netcfg.file)
$(.incus.instance.config.marker.file).init: | $(.incus.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.shared.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.kubeconfig.dir)/
$(.incus.instance.config.marker.file).init: | $(.incus.logs.dir)/
$(.incus.instance.config.marker.file).init: ## Create Incus instance for the first time (@codebase)
	: "[+] Initializing instance $(node.name) in project rke2..."
	incus delete -f $(node.name) --project=$(.incus.project.name) || true
	incus init $(.incus.image.name) $(node.name) --project=$(.incus.project.name) < $(.incus.instance.config.file)
	: "[i] Interfaces: lan0 (macvlan) + vmnet0 (Incus bridge)"

$(.incus.instance.config.marker.file): $(.incus.instance.config.marker.file).init
$(.incus.instance.config.marker.file): | $(.incus.dir)/ 
$(.incus.instance.config.marker.file): ## Ensure incus dir exists before cloud-init cleanup (@codebase)
	: "[+] Ensuring clean cloud-init state for fresh network configuration..."
	: incus exec $(node.name) -- rm -rf /var/lib/cloud/instance /var/lib/cloud/instances /var/lib/cloud/data /var/lib/cloud/sem || true
	: incus exec $(node.name) -- rm -rf /run/cloud-init /run/systemd/network/10-netplan-* || true
	touch $@

start@incus: create@incus
start@incus: $(.incus.env.file)
start@incus: | zfs.allow 
start@incus: ## Start the Incus instance
	: "[+] Starting instance $(node.name)..."
	if $$( incus info $(node.name) --project=$(.incus.project.name) 2>/dev/null |
		    yq -r '.Status == "RUNNING"' ); then
			: "[!] Instance $(node.name) already running; skipping start"
	else
		incus start $(node.name) --project=$(.incus.project.name)
	fi
	
shell@incus: ## Open interactive shell in the instance
	: "[+] Opening a shell in instance $(node.name)...";
	if incus info $(node.name) --project=$(.incus.project.name) >/dev/null 2>&1; then
		echo "✓ Instance $(node.name) is available";
		incus exec $(node.name) --project=$(.incus.project.name) -- zsh;
	else
		echo "✗ Instance $(node.name) not found or not running";
		echo "Use 'make start' to start the instance first";
		exit 1;
	fi

stop@incus: ## Stop the running instance
	: "[+] Stopping instance $(node.name) if running..."
	incus stop $(node.name) || true

delete@incus: ## Delete the instance (keeps configuration)
	: "[+] Removing instance $(node.name)..."
	incus delete -f $(node.name) || true
	rm -f $(.incus.instance.config.marker.file) || true

.PHONY: remove-member@etcd
remove-member@etcd: nodeName = $(node.name)
remove-member@etcd: ## Remove etcd member for peer/server nodes from cluster
	@if [ "$(nodeName)" != "master" ] && [ "$(NODE_TYPE)" = "server" ]; then
		: "[+] Removing etcd member for $(nodeName)..."
		if incus info master --project=$(.incus.project.name) >/dev/null 2>&1; then
			NODE_INETADDR="10.80.$$(( $(cluster.id) * 8 )).$$(( 10 + $(NODEID) ))"
			MEMBER_ID=$$(incus exec master --project=$(.incus.project.name) -- etcdctl member list --write-out=simple | grep "$$NODE_INETADDR" | awk '{print $$1}' | tr -d ',' || true)
			if [ -n "$$MEMBER_ID" ]; then
				: "[+] Found etcd member $$MEMBER_ID for $(nodeName) at $$NODE_INETADDR"
				incus exec master --project=$(.incus.project.name) -- etcdctl member remove $$MEMBER_ID || true
				: "[✓] Removed etcd member $$MEMBER_ID"
			else
				: "[i] No etcd member found for $(nodeName) at $$NODE_INETADDR"
			fi
		else
			: "[!] Master node not running, cannot remove etcd member"
		fi
	else
		: "[i] Skipping etcd member removal for $(nodeName) (master or non-server node)"
	fi

clean@incus: remove-member@etcd
clean@incus: delete@incus 
clean@incus: projectName = $(.incus.project.name)
clean@incus: nodeName = $(node.name)
clean@incus: ## Remove instance, profiles, storage volumes, and runtime directories
	: "[+] Removing $(nodeName) if exists..."
	incus profile delete $(projectName)-$(nodeName) --project=$(.incus.project.name) || true
	incus profile delete $(projectName)-$(nodeName) --project default || true
	# All networks (LAN/WAN/VIP) are macvlan (no Incus-managed networks to delete)
	# Remove persistent storage volume to ensure clean cloud-init state
	incus storage volume delete default containers/$(nodeName) || true
	: "[+] Cleaning up run directory..."
	rm -fr $(.incus.dir)

clean-all@incus: projectName = $(.incus.project.name)
clean-all@incus: ## Clean all cluster nodes and shared resources (destructive)
	: "[+] Cleaning all nodes (master peers workers)...";
	for name in master peer1 peer2 peer3 worker1 worker2; do \
		echo "[+] Cleaning node $${name}..."; \
		incus delete $${name} --project=$(.incus.project.name) --force 2>/dev/null || true; \
		incus delete $${name} --project=default --force 2>/dev/null || true; \
		incus profile delete $(projectName)-$${name} --project=$(.incus.project.name) 2>/dev/null || true; \
		incus profile delete $(projectName)-$${name} --project=default 2>/dev/null || true; \
		incus storage volume delete default containers/$${name} 2>/dev/null || true; \
	done; \
	: "[+] Removing entire local run directory..."; \
	rm -rf $(.incus.dir) 2>/dev/null || true; \
	: "[+] Cleaning shared cluster resources..."; \
	: "[+] Cleaning up Incus-managed networks..."; \
	incus network list --project=$(.incus.project.name) --format=csv -c n,t | grep ',bridge$$' | cut -d, -f1 | xargs -r -n1 incus network delete --project=$(.incus.project.name) 2>/dev/null || true; \
	: "[+] Cleaning up shared profiles..."; \
	incus profile list --project=$(.incus.project.name) --format=csv -c n | grep -v '^default$$' | xargs -r -n1 incus profile delete --project=$(.incus.project.name) 2>/dev/null || true; \
	: "[+] All cluster resources cleaned up"

#-----------------------------
# ZFS Permissions Target
#-----------------------------

.PHONY: zfs.allow

zfs.allow: $(.incus.zfs.allow.marker.file) ## Ensure ZFS permissions are set for Incus on tank dataset

$(.incus.zfs.allow.marker.file):| $(.incus.zfs.allow.marker.dir)/
$(.incus.zfs.allow.marker.file):
	: "[+] Allowing ZFS permissions for tank..."
	$(SUDO) zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	$(SUDO) zfs allow -e @allperms tank
	touch $@

endif
