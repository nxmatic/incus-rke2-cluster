# incus.mk - Incus Infrastructure Management (@codebase)
# This file contains all Incus-specific targets for project, image, and instance management  
# Included by main Makefile after RKE2 variables are defined

# Incus command invocation with timeout (defined here, removed from make.mk)
INCUS_TIMEOUT ?= 30
INCUS ?= $(REMOTE_EXEC) timeout $(INCUS_TIMEOUT) incus

#-----------------------------
# Dependency Check Target
#-----------------------------

.PHONY: deps@incus
deps@incus: ## Check availability of remote incus and required tools
	@echo "[+] Checking remote Incus dependencies via $(REMOTE_EXEC) ..."; \
	ERR=0; \
	for cmd in incus yq ipcalc timeout; do \
		if $(REMOTE_EXEC) command -v $$cmd >/dev/null 2>&1; then \
			echo "  ✓ $$cmd"; \
		else \
			echo "  ✗ $$cmd (missing)"; ERR=1; \
		fi; \
	done; \
	if [ "$$ERR" = "1" ]; then echo "[!] Some dependencies missing"; exit 1; else echo "[+] All dependencies present"; fi

# Use advanced metaprogramming for enhanced functionality
-include advanced-targets.mk

#-----------------------------
# Preseed Rendering Targets
#-----------------------------

.PHONY: preseed@incus

preseed@incus: $(INCUS_PRESSED_FILE)
preseed@incus:
	: "[+] Applying incus preseed ..."
	$(INCUS) admin init --preseed < $(INCUS_PRESSED_FILE)

$(INCUS_PRESSED_FILE): $(INCUS_PRESSED_FILENAME) | $(INCUS_DIR)/
$(INCUS_PRESSED_FILE):
	: "[+] Generating preseed file (pure envsubst via yq) ..."
	yq eval '( .. | select(tag=="!!str") ) |= envsubst(ne,nu)' $(INCUS_PRESSED_FILENAME) > $@

#-----------------------------
# Project Management Targets
#-----------------------------

.PHONY: switch-project@incus remove-project@incus
.PHONY: cleanup-instances@incus cleanup-images@incus cleanup-networks@incus cleanup-profiles@incus cleanup-volumes@incus remove-project-rke2@incus

switch-project@incus: preseed@incus ## Switch to RKE2 project and ensure images are available
switch-project@incus: $(INCUS_CREATE_PROJECT_MARKER_FILE)
switch-project@incus:
	: [+] Switching to project $(CLUSTER_NAME)
	$(INCUS) project switch rke2 || true
	: [+] Ensuring image $(RKE2_IMAGE_NAME) is available in project rke2
	$(INCUS) image show $(RKE2_IMAGE_NAME) --project=rke2 >/dev/null 2>&1 || \
	  $(INCUS) image import --project=rke2 --alias=$(RKE2_IMAGE_NAME) --reuse $(INCUS_IMAGE_BUILD_FILES)

remove-project@incus: cleanup-project-instances@incus ## Remove entire RKE2 project (destructive)
remove-project@incus: cleanup-project-images@incus
remove-project@incus: cleanup-project-networks@incus
remove-project@incus: cleanup-project-profiles@incus
remove-project@incus: cleanup-project-volumes@incus
remove-project@incus:
	: [+] Deleting project $(CLUSTER_NAME)
	$(INCUS) project delete rke2 || true

cleanup-project-instances@incus: ## destructive: delete all instances in project rke2
	$(INCUS) list --project=rke2 --format=yaml | yq -r eval '.[].name' | \
	  xargs -r -n1 $(INCUS) delete -f --project rke2

cleanup-project-images@incus: ## destructive: delete all images (fingerprints) in project rke2
	$(INCUS) image list --project=rke2 --format=yaml | yq -r eval '.[].fingerprint' | \
	  xargs -r -n1 $(INCUS) image delete --project rke2

cleanup-project-networks@incus: ## destructive: delete all networks in project rke2
	$(INCUS) network list --project=rke2 --format=yaml | yq -r eval '.[].name' | \
	  xargs -r -n1 echo $(INCUS) network delete --project rke2

cleanup-project-profiles@incus: ## destructive: delete all non-default profiles in project rke2
	$(INCUS) profile list --project=rke2 --format=yaml | yq -r '.[].name | select(. != "default")' | \
	  xargs -r -n1 $(INCUS) profile delete --project rke2

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
	$(INCUS) storage volume list --project=rke2 --format=yaml default | \
		yq -r --from-file=<(echo "$$YQ_EXPR") | \
	    xargs -r -n1 $(INCUS) storage volume delete --project=rke2 default

define INCUS_SNAPSHOT_YQ
.[] |
  with( select( .type | test("snapshot") ); .del=.name) |
  select( .type | test("snapshot") ) |
  .del
endef

cleanup-project-volumes-snapshots@incus: export YQ_EXPR := $(INCUS_SNAPSHOT_YQ)
cleanup-project-volumes-snapshots@incus: 
	: "destructive: delete all snapshots in each storage pool (project rke2)"
	$(INCUS) storage volume list --project=rke2 --format=yaml default | \
		yq -r --from-file=<(echo "$$YQ_EXPR") | \
	    xargs -r -n1 $(INCUS) storage volume snapshot delete --project=rke2 default

$(INCUS_CREATE_PROJECT_MARKER_FILE): | $(INCUS_DIR)/
$(INCUS_CREATE_PROJECT_MARKER_FILE):
	: [+] Creating incus project rke2 if not exists...
	$(INCUS) project create rke2 || true
	: [+] Importing incus profile rke2
	$(INCUS) profile copy --project=default --target-project=rke2 $(RKE2_NODE_PROFILE_NAME) $(RKE2_NODE_PROFILE_NAME) || true
	touch $@

#-----------------------------
# Bridge Management Targets
#-----------------------------

.PHONY: create-vip-bridge create-node-bridges clean-vip-bridge

# Create shared VIP bridge (dedicated target)
create-vip-bridge: $(INCUS_CREATE_PROJECT_MARKER_FILE)
	: [+] Creating shared VIP bridge $(RKE2_CLUSTER_VIP_BRIDGE_NAME)...
	if ! $(INCUS) network show $(RKE2_CLUSTER_VIP_BRIDGE_NAME) --project=rke2 >/dev/null 2>&1; then \
		echo "[+] Creating bridge $(RKE2_CLUSTER_VIP_BRIDGE_NAME) with CIDR $(RKE2_CLUSTER_VIP_BRIDGE_CIDR)"; \
		$(INCUS) network create $(RKE2_CLUSTER_VIP_BRIDGE_NAME) --project=rke2 \
			ipv4.address=$(RKE2_CLUSTER_VIP_BRIDGE_GATEWAY_IP)/$(RKE2_CLUSTER_VIP_BRIDGE_PREFIX_LENGTH) \
			ipv4.nat=false \
			ipv6.address=none \
			dns.mode=none; \
	else \
		echo "[i] Bridge $(RKE2_CLUSTER_VIP_BRIDGE_NAME) already exists"; \
	fi

# Create per-node bridges (dedicated targets)
create-node-bridges: $(INCUS_CREATE_PROJECT_MARKER_FILE)
	: [+] Creating node bridges for $(RKE2_NODE_NAME)...
	if ! $(INCUS) network show $(RKE2_NODE_WAN_BRIDGE_NAME) --project=rke2 >/dev/null 2>&1; then \
		echo "[+] Creating WAN bridge $(RKE2_NODE_WAN_BRIDGE_NAME) with CIDR $(RKE2_NODE_NETWORK_CIDR)"; \
		$(INCUS) network create $(RKE2_NODE_WAN_BRIDGE_NAME) --project=rke2 \
			ipv4.address=$(RKE2_NODE_GATEWAY_IP)/$(RKE2_NODE_PREFIX_LENGTH) \
			ipv4.nat=true \
			ipv6.address=none \
			dns.mode=none; \
	else \
		echo "[i] WAN bridge $(RKE2_NODE_WAN_BRIDGE_NAME) already exists"; \
	fi
	if ! $(INCUS) network show $(RKE2_NODE_LAN_BRIDGE_NAME) --project=rke2 >/dev/null 2>&1; then \
		echo "[+] Creating LAN bridge $(RKE2_NODE_LAN_BRIDGE_NAME) as physical passthrough"; \
		$(INCUS) network create $(RKE2_NODE_LAN_BRIDGE_NAME) --project=rke2 --type=physical \
			parent=vmlan0; \
	else \
		echo "[i] LAN bridge $(RKE2_NODE_LAN_BRIDGE_NAME) already exists"; \
	fi

clean-vip-bridge:
	echo "[+] Removing shared VIP bridge $(RKE2_CLUSTER_VIP_BRIDGE_NAME)..."
	$(INCUS) network delete $(RKE2_CLUSTER_VIP_BRIDGE_NAME) --project=rke2 2>/dev/null || true
	echo "[+] VIP bridge removed"

# Bridge setup marker depends on both VIP and node bridge creation
$(INCUS_BRIDGE_SETUP_MARKER_FILE): create-vip-bridge create-node-bridges | $(INCUS_DIR)/
	touch $@

#-----------------------------
# Network Diagnostics Targets
#-----------------------------

.PHONY: show-network@incus diagnostics@incus network-status@incus

show-network@incus: preseed@incus ## Show network configuration summary
show-network@incus:
	echo "[i] Network Configuration Summary"
	echo "=================================="
	echo "Host LAN parent: $(LIMA_LAN_INTERFACE) -> container lan0 (macvlan)"
	echo "Host WAN parent: $(LIMA_WAN_INTERFACE) -> container wan0 (macvlan)"
	echo "VIP Bridge: $(RKE2_CLUSTER_VIP_BRIDGE_NAME) ($(RKE2_CLUSTER_VIP_BRIDGE_CIDR)) -> container vip0"
	echo "Mode: Dual macvlan + shared VIP bridge"
	echo ""
	echo "[i] Host interface state:"
	echo "  $(LIMA_LAN_INTERFACE): $$(ip link show $(LIMA_LAN_INTERFACE) | grep -o 'state [A-Z]*' || echo 'unknown state')"
	echo "  $(LIMA_WAN_INTERFACE): $$(ip link show $(LIMA_WAN_INTERFACE) | grep -o 'state [A-Z]*' || echo 'unknown state')"
	echo ""
	echo "[i] IP assignments:"
	echo "  $(LIMA_LAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_LAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"
	echo "  $(LIMA_WAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_WAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"
	echo ""
	echo "(Container macvlan interfaces visible after instance start)"

diagnostics@incus: ## Show host network diagnostics
	echo "[i] Host Network Diagnostics"
	echo "============================"
	echo "Parent interfaces: $(LIMA_LAN_INTERFACE), $(LIMA_WAN_INTERFACE)"
	echo "Host MACs:"
	echo "  $(LIMA_LAN_INTERFACE): $$(cat /sys/class/net/$(LIMA_LAN_INTERFACE)/address 2>/dev/null || echo 'n/a')"
	echo "  $(LIMA_WAN_INTERFACE): $$(cat /sys/class/net/$(LIMA_WAN_INTERFACE)/address 2>/dev/null || echo 'n/a')"
	echo ""
	echo "Host IP assignments:"
	echo "  $(LIMA_LAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_LAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"
	echo "  $(LIMA_WAN_INTERFACE) IPv4: $$(ip -o -4 addr show $(LIMA_WAN_INTERFACE) | awk '{print $$4}' || echo '<none>')"

network-status@incus: ## Show container network status
	echo "[i] Container Network Status"
	echo "============================"
	echo "Container: $(RKE2_NODE_NAME)"
	if $(INCUS) info $(RKE2_NODE_NAME) --project=rke2 >/dev/null 2>&1; then \
		echo "Container network interfaces:"; \
		$(INCUS) exec $(RKE2_NODE_NAME) --project=rke2 -- ip -o addr show lan0 2>/dev/null || echo "  lan0: not available"; \
		$(INCUS) exec $(RKE2_NODE_NAME) --project=rke2 -- ip -o addr show wan0 2>/dev/null || echo "  wan0: not available"; \
		$(INCUS) exec $(RKE2_NODE_NAME) --project=rke2 -- ip -o addr show vip0 2>/dev/null || echo "  vip0: not available"; \
		echo ""; \
		echo "Connectivity test:"; \
		$(INCUS) exec $(RKE2_NODE_NAME) --project=rke2 -- ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "  Internet: OK" || echo "  Internet: FAILED"; \
	else \
		echo "Container $(RKE2_NODE_NAME) not found or not running"; \
	fi

#-----------------------------
# Image Management Targets
#-----------------------------

.PHONY: image@incus

image@incus: $(INCUS_IMAGE_IMPORT_MARKER_FILE)

$(INCUS_IMAGE_IMPORT_MARKER_FILE): $(INCUS_IMAGE_BUILD_FILES)
$(INCUS_IMAGE_IMPORT_MARKER_FILE): | $(IMAGE_DIR)/
$(INCUS_IMAGE_IMPORT_MARKER_FILE):
	: [+] Importing image for instance $(RKE2_NODE_NAME)...
	$(INCUS) image import --alias $(RKE2_IMAGE_NAME) --reuse $(^)
	touch $@

$(INCUS_IMAGE_BUILD_FILES): $(INCUS_DISTROBUILDER_FILE) | $(IMAGE_DIR)/
$(INCUS_IMAGE_BUILD_FILES): export TSID := $(TSID)
$(INCUS_IMAGE_BUILD_FILES): export TSKEY := $(TSKEY_CLIENT)
$(INCUS_IMAGE_BUILD_FILES)&:
	: [+] Building instance $(RKE2_NODE_NAME)...
	$(SUDO) distrobuilder --debug --disable-overlay \
		build-incus $(INCUS_DISTROBUILDER_FILE) 2>&1 | \
		tee $(INCUS_DISTROBUILDER_LOGFILE)
	mv incus.tar.xz rootfs.squashfs $(IMAGE_DIR)/

#-----------------------------
# Instance Lifecycle Targets
#-----------------------------

.PHONY: instance@incus start@incus shell@incus stop@incus delete@incus clean@incus

instance@incus: $(INCUS_CONFIG_INSTANCE_MARKER_FILE) ## Create instance configuration and setup

$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: $(INCUS_IMAGE_IMPORT_MARKER_FILE) $(INCUS_BRIDGE_SETUP_MARKER_FILE)
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: $(CLUSTER_ENV_FILE)
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: | $(INCUS_DIR)/ $(SHARED_DIR)/ $(KUBECONFIG_DIR)/ $(LOGS_DIR)/
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init:
	: "[+] Initializing instance $(RKE2_NODE_NAME)..."
	$(INCUS) init $(RKE2_IMAGE_NAME) $(RKE2_NODE_NAME) < $(INCUS_INSTANCE_CONFIG_FILE)
	: "[+] Attaching VIP bridge $(RKE2_CLUSTER_VIP_BRIDGE_NAME) to instance $(RKE2_NODE_NAME)..."
	$(INCUS) config device add $(RKE2_NODE_NAME) vip0 nic \
		network=$(RKE2_CLUSTER_VIP_BRIDGE_NAME) \
		name=vip0
	: "[+] Attaching WAN bridge $(RKE2_NODE_WAN_BRIDGE_NAME) to instance $(RKE2_NODE_NAME)..."
	$(INCUS) config device add $(RKE2_NODE_NAME) wan0 nic \
		network=$(RKE2_NODE_WAN_BRIDGE_NAME) \
		name=wan0
	: "[+] Attaching LAN bridge $(RKE2_NODE_LAN_BRIDGE_NAME) to instance $(RKE2_NODE_NAME)..."
	$(INCUS) config device add $(RKE2_NODE_NAME) lan0 nic \
		network=$(RKE2_NODE_LAN_BRIDGE_NAME) \
		name=lan0

$(INCUS_CONFIG_INSTANCE_MARKER_FILE): $(INCUS_CONFIG_INSTANCE_MARKER_FILE).init
$(INCUS_CONFIG_INSTANCE_MARKER_FILE):
	: "[+] Ensuring clean cloud-init state for fresh network configuration..."
	$(INCUS) exec $(RKE2_NODE_NAME) -- rm -rf /var/lib/cloud/instance /var/lib/cloud/instances /var/lib/cloud/data /var/lib/cloud/sem || true
	$(INCUS) exec $(RKE2_NODE_NAME) -- rm -rf /run/cloud-init /run/systemd/network/10-netplan-* || true
	
	touch $@

start@incus: instance@incus zfs.allow ## Start the Incus instance
start@incus:
	$(call trace,Entering target: start@incus)
	$(call trace-var,RKE2_NODE_NAME)
	$(call trace-incus,Starting instance $(RKE2_NODE_NAME))
	echo "[+] Starting instance $(RKE2_NODE_NAME)..."; \
	if $(INCUS) start $(RKE2_NODE_NAME); then \
		echo "✓ Instance $(RKE2_NODE_NAME) started successfully"; \
	else \
		echo "✗ Failed to start instance $(RKE2_NODE_NAME)"; \
		exit 1; \
	fi
	$(call trace,Completed target: start@incus)

shell@incus: ## Open interactive shell in the instance
	echo "[+] Opening a shell in instance $(RKE2_NODE_NAME)..."; \
	if $(INCUS) info $(RKE2_NODE_NAME) --project=rke2 >/dev/null 2>&1; then \
		echo "✓ Instance $(RKE2_NODE_NAME) is available"; \
		$(INCUS) exec $(RKE2_NODE_NAME) --project=rke2 -- zsh; \
	else \
		echo "✗ Instance $(RKE2_NODE_NAME) not found or not running"; \
		echo "Use 'make start' to start the instance first"; \
		exit 1; \
	fi

stop@incus: ## Stop the running instance
	: "[+] Stopping instance $(RKE2_NODE_NAME) if running..."
	$(INCUS) stop $(RKE2_NODE_NAME) || true

delete@incus: ## Delete the instance (keeps configuration)
	: "[+] Removing instance $(RKE2_NODE_NAME)..."
	$(INCUS) delete -f $(RKE2_NODE_NAME) || true
	rm -f $(INCUS_CONFIG_INSTANCE_MARKER_FILE) || true

clean@incus: delete@incus ## Clean instance and all associated resources
clean@incus: remove-hosts@tailscale
clean@incus:
	: [+] Removing $(RKE2_NODE_NAME) if exists...
	$(INCUS) profile delete rke2-$(RKE2_NODE_NAME) --project=rke2 || true
	$(INCUS) profile delete rke2-$(RKE2_NODE_NAME) --project default || true
	# Remove current bridge pair (per-node bridges only)
	$(INCUS) network delete $(RKE2_NODE_LAN_BRIDGE_NAME) 2>/dev/null || true
	$(INCUS) network delete $(RKE2_NODE_WAN_BRIDGE_NAME) 2>/dev/null || true
	# NOTE: Shared VIP bridge (rke2-vip) is NOT removed here - it's shared across all control-plane nodes
	# VIP bridge cleanup happens only in clean-all or when manually cleaning the entire cluster
	# Remove persistent storage volume to ensure clean cloud-init state
	$(INCUS) storage volume delete default containers/$(RKE2_NODE_NAME) || true
	: [+] Cleaning up run directory...
	rm -fr $(RUN_INSTANCE_DIR)

clean-all@incus: ## Clean all cluster nodes and shared resources (destructive)
	$(MAKE) NAME=master clean@incus
	$(MAKE) NAME=peer1 clean@incus
	$(MAKE) NAME=peer2 clean@incus
	# Clean up shared resources after all nodes are removed
	echo "[+] Cleaning up shared cluster resources..."
	$(INCUS) network delete $(RKE2_CLUSTER_VIP_BRIDGE_NAME) --project=rke2 2>/dev/null || true
	echo "[+] All cluster resources cleaned up"

#-----------------------------
# ZFS Permissions Target
#-----------------------------

.PHONY: zfs.allow

zfs.allow: $(INCUS_ZFS_ALLOW_MARKER_FILE)

$(INCUS_ZFS_ALLOW_MARKER_FILE):| $(RUN_DIR)/
	: "[+] Allowing ZFS permissions for tank..."
	$(SUDO) zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	$(SUDO) zfs allow -e @allperms tank
	touch $@

#-----------------------------
# Tailscale Device Cleanup Target
#-----------------------------

.PHONY: remove-hosts@tailscale

define TAILSCALE_RM_HOSTS_SCRIPT
curl -fsSL -H "Authorization: Bearer $${TSKEY}" https://api.tailscale.com/api/v2/tailnet/-/devices |
	yq -p json eval --from-file=<(echo "$${YQ_EXPR}") |
	xargs -I{} curl -fsS -X DELETE -H "Authorization: Bearer $${TSKEY}" "https://api.tailscale.com/api/v2/device/{}"
endef

define TAILSCALE_RM_HOSTS_YQ_EXPR
.devices[] | 
  select( .hostname | 
          test("^$(CLUSTER_NAME)-(tailscale-operator|controlplane)") ) |
	.id
endef

remove-hosts@tailscale: export TSID := $(TSID)
remove-hosts@tailscale: export TSKEY := $(TSKEY_API)
remove-hosts@tailscale: export HOST := $(CLUSTER_NAME)
remove-hosts@tailscale: export SCRIPT := $(TAILSCALE_RM_HOSTS_SCRIPT)
remove-hosts@tailscale: export YQ_EXPR := $(TAILSCALE_RM_HOSTS_YQ_EXPR)
remove-hosts@tailscale: export NODE := $(NAME)
remove-hosts@tailscale:
	: "[+] Querying Tailscale devices with key $${TSKEY},prefix $${HOST}, yq-expr $${YQ_EXPR} ..."
	( [[ $$NODE == "master" ]] && eval "$$SCRIPT" ) || true