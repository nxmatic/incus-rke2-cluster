# Makefile for Incus RKE2 Cluster
#-----------------------------
# Shell, Project, and Run Directory Variables
#-----------------------------
SHELL := /bin/bash -exo pipefail
export PATH := /run/wrappers/bin:$(PATH)

empty :=
colon := :
space := $(empty) $(empty)

-include .gmsl/gmsl

.gmsl/gmsl:
	: Loading git sub-modules 
	git submodule update --init --recursive

NAME ?= master

# Directories
SECRETS_DIR := .secrets.d
RUN_DIR := .run.d
IMAGE_DIR := $(RUN_DIR)/image
RUN_INSTANCE_DIR := $(RUN_DIR)/$(NAME)
INCUS_DIR := $(RUN_INSTANCE_DIR)/incus
NOCLOUD_DIR := $(RUN_INSTANCE_DIR)/no-cloud
SHARED_DIR := $(RUN_INSTANCE_DIR)/shared
KUBECONFIG_DIR := $(RUN_INSTANCE_DIR)/kube
LOGS_DIR := $(RUN_INSTANCE_DIR)/logs

#-----------------------------
# Cluster Node Environment Variables
#-----------------------------

CLUSTER_NAME ?= $(LIMA_HOSTNAME)
CLUSTER_TOKEN ?= $(CLUSTER_NAME)
CLUSTER_SUPERNET_CIDR := 172.31.0.0/16
CLUSTER_IMAGE_NAME := control-node
CLUSTER_NODE_NAME := $(NAME)

# Derive cluster subnet from cluster name (e.g., bioskop=1, alcide=2)
ifeq (bioskop,$(CLUSTER_NAME))
  CLUSTER_SUBNET := 1
else ifeq (alcide,$(CLUSTER_NAME))
  CLUSTER_SUBNET := 2
else
  $(error Unsupported cluster name: $(CLUSTER_NAME))
endif

# Set node offset based on node type within the cluster
ifeq (master,$(CLUSTER_NODE_NAME))
  NODE_OFFSET := 0
else ifeq (peer1,$(CLUSTER_NODE_NAME))
  NODE_OFFSET := 64
else ifeq (peer2,$(CLUSTER_NODE_NAME))
  NODE_OFFSET := 128
else
  $(error Invalid cluster node name: $(CLUSTER_NODE_NAME))
endif

CLUSTER_VIRTUAL_ADDRESSES_CIDR := 172.31.0.0/24
CLUSTER_NODES_CIDR := 172.31.$(CLUSTER_SUBNET).$(NODE_OFFSET)/26
CLUSTER_LOADBALANCERS_CIDR := 172.31.$(CLUSTER_SUBNET).192/26
CLUSTER_PODS_CIDR := 10.42.0.0/16
CLUSTER_SERVICES_CIDR := 10.43.0.0/16
CLUSTER_DOMAIN := cluster.local
## Precomputed offset helpers (reduce repeated $(shell) echo noise while retaining -x tracing elsewhere)
NODE_OFFSET_P1 := $(shell echo $$(( $(NODE_OFFSET) + 1 )))
NODE_OFFSET_P2 := $(shell echo $$(( $(NODE_OFFSET) + 2 )))
CLUSTER_INET_GATEWAY := 172.31.$(CLUSTER_SUBNET).$(NODE_OFFSET_P1)
CLUSTER_INET_VIRTUAL := 172.31.0.$(CLUSTER_SUBNET)
CLUSTER_NODE_INET := 172.31.$(CLUSTER_SUBNET).$(NODE_OFFSET_P2)
# Specific node IP addresses for TLS SANs
CLUSTER_INET_MASTER := 172.31.$(CLUSTER_SUBNET).2
CLUSTER_INET_PEER1 := 172.31.$(CLUSTER_SUBNET).66
CLUSTER_INET_PEER2 := 172.31.$(CLUSTER_SUBNET).130
# ARPA entries based on calculated IPs
CLUSTER_ARPA_GATEWAY := $(NODE_OFFSET_P1).$(CLUSTER_SUBNET).31.172
CLUSTER_ARPA_VIRTUAL := $(CLUSTER_SUBNET).0.31.172
CLUSTER_ARPA_NODE := $(NODE_OFFSET_P2).$(CLUSTER_SUBNET).31.172
# Added explicit ARPA entries for each control-plane node (fix for undefined vars in DNSMASQ_RAW)
CLUSTER_ARPA_MASTER := 2.$(CLUSTER_SUBNET).31.172
CLUSTER_ARPA_PEER1 := 66.$(CLUSTER_SUBNET).31.172
CLUSTER_ARPA_PEER2 := 130.$(CLUSTER_SUBNET).31.172

CLUSTER_ENV_FILE := $(INCUS_DIR)/cluster-env.mk

-include $(CLUSTER_ENV_FILE)

$(CLUSTER_ENV_FILE): _hwaddr = $(shell cat /sys/class/net/enp0s1/address)
$(CLUSTER_ENV_FILE): _hwaddr_words = $(subst $(colon),$(space),$(_hwaddr))
$(CLUSTER_ENV_FILE): _hwaddr_words_network_words = $(wordlist 4,5,$(_hwaddr_words))
$(CLUSTER_ENV_FILE): _hwaddr_words_network_part = $(subst $(space),$(colon),$(_hwaddr_words_network_words))

$(CLUSTER_ENV_FILE): NAME ?= master
$(CLUSTER_ENV_FILE): TOKEN := $(CLUSTER_TOKEN)
$(CLUSTER_ENV_FILE): DN := ${NAME}-$(CLUSTER_IMAGE_NAME)
$(CLUSTER_ENV_FILE): FQDN := $(CLUSTER_NAME)-$(DN).$(LIMA_DN)
$(CLUSTER_ENV_FILE): HWADDR =  10:66:6a:$(_hwaddr_words_network_part):0$(CLUSTER_SUBNET)

$(CLUSTER_ENV_FILE): | $(INCUS_DIR)/
$(CLUSTER_ENV_FILE):
	@: Defined environment variables for cluster $(CLUSTER_NAME) $(NODES_CIDR) $(file > $@,$(CLUSTER_ENV))

INCUS_INET_YQ_EXPR := .[].state.network.eth0.addresses[] | select(.family == "inet") | .address
define INCUS_INET_CMD
$(shell incus list $(1) --format=yaml | yq eval '$(INCUS_INET_YQ_EXPR)' -)
endef

define RKE2_MASTER_TOKEN_TEMPLATE
server: https://$(CLUSTER_INET_MASTER):9345
token: $(CLUSTER_TOKEN)
endef

define CLUSTER_ENV
CLUSTER_TOKEN := $(TOKEN)
CLUSTER_NODE_NAME := $(NAME)
CLUSTER_NODE_DN := $(DN)
CLUSTER_NODE_FQDN := $(FQDN)
CLUSTER_NODE_HWADDR := $(HWADDR)
CLUSTER_SUBNET := $(CLUSTER_SUBNET)
endef

# Config Paths
INCUS_PRESSED_FILENAME := incus-preseed.tmpl.yaml
INCUS_PRESSED_FILE := $(INCUS_DIR)/preseed.yaml

INCUS_DISTROBUILDER_FILE := ./incus-distrobuilder.yaml
INCUS_DISTROBUILDER_LOGFILE := $(IMAGE_DIR)/distrobuilder.log

INCUS_IMAGE_IMPORT_MARKER_FILE := $(IMAGE_DIR)/import.tstamp
INCUS_IMAGE_BUILD_FILES := $(IMAGE_DIR)/incus.tar.xz $(IMAGE_DIR)/rootfs.squashfs

INCUS_CREATE_PROJECT_MARKER_FILE := $(INCUS_DIR)/create-project.tstamp
INCUS_CONFIG_INSTANCE_MARKER_FILE := $(INCUS_DIR)/init-instance.tstamp

INCUS_INSTANCE_CONFIG_FILENAME := incus-instance-config.tmpl.yaml
INCUS_INSTANCE_CONFIG_FILE := $(INCUS_DIR)/config.yaml
INCUS_ZFS_ALLOW_MARKER_FILE := $(INCUS_DIR)/zfs-allow.tstamp

NOCLOUD_USERDATA_FILE := $(NOCLOUD_DIR)/config.yaml
NOCLOUD_METADATA_FILE := $(NOCLOUD_DIR)/metadata.yaml

#-----------------------------

.PHONY: all start stop delete clean shell

all: start

#-----------------------------
# Preseed Rendering Targets
#-----------------------------

.PHONY: incus-preseed

incus-preseed: $(INCUS_PRESSED_FILE)

define DNSMASQ_RAW
log-debug
log-dhcp
log-facility=daemon
enable-ra
# DNS entry to match etcd certificate SAN
address=/gateway/${CLUSTER_INET_GATEWAY}
address=/kubernetes-api/${CLUSTER_INET_VIRTUAL}
address=/master-control-node/${CLUSTER_INET_MASTER}
address=/peer1-control-node/${CLUSTER_INET_PEER1}
address=/peer2-control-node/${CLUSTER_INET_PEER2}
# Reverse DNS entry for gateway IP to match etcd certificate SAN
ptr-record=${CLUSTER_ARPA_GATEWAY}.in-addr.arpa,gateway
ptr-record=${CLUSTER_ARPA_VIRTUAL}.in-addr.arpa,kubernetes-api
ptr-record=${CLUSTER_ARPA_MASTER}.in-addr.arpa,master-control-node
ptr-record=${CLUSTER_ARPA_PEER1}.in-addr.arpa,peer1-control-node
ptr-record=${CLUSTER_ARPA_PEER2}.in-addr.arpa,peer2-control-node
endef

define INCUS_PRESSED_YQ
. |
  .networks[0].name = "rke2-$(CLUSTER_NODE_NAME)-br" |
  .networks[0].description = "RKE2 network ${CLUSTER_NODE_NAME} bridge" |
  .networks[0].config."raw.dnsmasq" = "$(DNSMASQ_RAW)" |
  .networks[0].config."ipv4.address" = "$(CLUSTER_INET_GATEWAY)/26" |
  .networks[0].config."ipv4.routes" = "$(CLUSTER_INET_VIRTUAL)/32" |
  .profiles[0].name = "rke2-$(CLUSTER_NODE_NAME)" |
  .profiles[0].description = "RKE2 profile for ${CLUSTER_NODE_NAME}" |
  .profiles[0].devices["eth0"].parent = "rke2-$(CLUSTER_NODE_NAME)-br"
endef

$(INCUS_PRESSED_FILE): $(INCUS_PRESSED_FILENAME) | $(INCUS_DIR)/
$(INCUS_PRESSED_FILE): export YQ_EXPR := $(INCUS_PRESSED_YQ)
$(INCUS_PRESSED_FILE):
	@: [+] Generating preseed file ...
	yq eval --from-file=<(echo "$${YQ_EXPR}") $(INCUS_PRESSED_FILENAME) > $@
	incus admin init --preseed < $(INCUS_PRESSED_FILE)

#-----------------------------
# Project Management Target
#-----------------------------

.PHONY: incus-project

incus-project: incus-preseed
incus-project: $(INCUS_CREATE_PROJECT_MARKER_FILE)
incus-project:
	@: [+] Switching to project $(CLUSTER_NAME)
	incus project switch rke2

$(INCUS_CREATE_PROJECT_MARKER_FILE): | $(INCUS_DIR)/
	@: [+] Creating incus project rke2 if not exists...
	incus project create rke2 || true
	@: [+] Importing incus profile rke2
	incus profile show rke2-$(CLUSTER_NODE_NAME) --project default | \
	  incus profile create rke2-$(CLUSTER_NODE_NAME) --project rke2 || true
	touch $@

#-----------------------------
# Main Targets
#-----------------------------
MAIN_TARGETS := start stop delete clean shell

$(MAIN_TARGETS): incus-preseed incus-image incus-project

.PHONY: $(MAIN_TARGETS)

incus-image: $(INCUS_IMAGE_IMPORT_MARKER_FILE)

$(INCUS_IMAGE_IMPORT_MARKER_FILE): $(INCUS_IMAGE_BUILD_FILES)
$(INCUS_IMAGE_IMPORT_MARKER_FILE): | $(IMAGE_DIR)/
$(INCUS_IMAGE_IMPORT_MARKER_FILE):
	@: [+] Importing image for instance $(NODE_NAME)...
	incus image import --alias $(CLUSTER_IMAGE_NAME) --reuse $(^)
	touch $@

$(INCUS_IMAGE_BUILD_FILES): $(INCUS_DISTROBUILDER_FILE) | $(IMAGE_DIR)/
$(INCUS_IMAGE_BUILD_FILES): $(SECRETS_DIR)/tsid $(SECRETS_DIR)/tskey
$(INCUS_IMAGE_BUILD_FILES)&:
	$(if $(TSKEY),,$(error TSKEY must be set))
	$(if $(TSID),,$(error TSID must be set))
	@: [+] Building instance $(NODE_NAME)...
	env -i -S \
		TSID=$(file <$(SECRETS_DIR)/tsid) \
		TSKEY=$(file <$(SECRETS_DIR)/tskey) \
		PATH=$$PATH \
		  sudo distrobuilder --debug --disable-overlay \
			  build-incus $(INCUS_DISTROBUILDER_FILE) 2>&1 | \
			tee $(INCUS_DISTROBUILDER_LOGFILE)
	mv incus.tar.xz rootfs.squashfs $(IMAGE_DIR)/

#-----------------------------
# Lifecycle Targets
#-----------------------------

.PHONY: instance start shell stop delete clean

instance: $(INCUS_CONFIG_INSTANCE_MARKER_FILE)

$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: $(INCUS_IMAGE_IMPORT_MARKER_FILE) $(INCUS_CREATE_PROJECT_MARKER_FILE)
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: $(INCUS_INSTANCE_CONFIG_FILE)
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init: | $(INCUS_DIR)/ $(SHARED_DIR)/ $(KUBECONFIG_DIR)/ $(LOGS_DIR)/
$(INCUS_CONFIG_INSTANCE_MARKER_FILE).init:
	@: "[+] Initializing instance $(CLUSTER_NODE_NAME)..."
	incus init $(CLUSTER_IMAGE_NAME) $(CLUSTER_NODE_NAME) < $(INCUS_INSTANCE_CONFIG_FILE)

$(INCUS_CONFIG_INSTANCE_MARKER_FILE): $(INCUS_CONFIG_INSTANCE_MARKER_FILE).init
$(INCUS_CONFIG_INSTANCE_MARKER_FILE):
	@: "[+] Configuring instance $(CLUSTER_NODE_NAME)..."	
	incus config set $(CLUSTER_NODE_NAME) environment.INSTALL_RKE2_TYPE "server"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_NAME "$(CLUSTER_NAME)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_DOMAIN "$(CLUSTER_DOMAIN)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_INET_VIRTUAL "$(CLUSTER_INET_VIRTUAL)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_NODE_NAME "$(CLUSTER_NODE_NAME)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_SUBNET "$(CLUSTER_SUBNET)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_VIRTUAL_ADDRESSES_CIDR "$(CLUSTER_VIRTUAL_ADDRESSES_CIDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_NODES_CIDR "$(CLUSTER_NODES_CIDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_LOADBALANCERS_CIDR "$(CLUSTER_LOADBALANCERS_CIDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_NODE_HWADDR "$(CLUSTER_NODE_HWADDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_PODS_CIDR "$(CLUSTER_PODS_CIDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_SERVICES_CIDR "$(CLUSTER_SERVICES_CIDR)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_NODE_INET "$(CLUSTER_NODE_INET)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_INET_MASTER "$(CLUSTER_INET_MASTER)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_INET_PEER1 "$(CLUSTER_INET_PEER1)"
	incus config set $(CLUSTER_NODE_NAME) environment.CLUSTER_INET_PEER2 "$(CLUSTER_INET_PEER2)"
	incus config set $(CLUSTER_NODE_NAME) environment.TSKEY "$(TSKEY)"
	incus config set $(CLUSTER_NODE_NAME) environment.TSID "$(TSID)"
	
	# Fixed previously line-wrapped 'ipv4.address' token that broke make parsing
	incus config device set $(CLUSTER_NODE_NAME) eth0 parent=rke2-$(CLUSTER_NODE_NAME)-br hwaddr=$(CLUSTER_NODE_HWADDR) ipv4.address=$(CLUSTER_NODE_INET)

	touch $@

## Token device & external file removed; unified token provisioning via write_files patch

start: instance zfs.allow validate-userdata
start:
	@: "[+] Starting instance $(CLUSTER_NODE_NAME)..."
	incus start $(CLUSTER_NODE_NAME)

shell:
	@: "[+] Opening a shell in instance $(CLUSTER_NODE_NAME)..."
	incus exec $(CLUSTER_NODE_NAME) -- zsh

stop:
	@: "[+] Stopping instance $(CLUSTER_NODE_NAME) if running..."
	incus stop $(CLUSTER_NODE_NAME) || true

delete:
	@: "[+] Removing instance $(CLUSTER_NODE_NAME)..."
	incus delete -f $(CLUSTER_NODE_NAME) || true
	rm -f $(INCUS_CONFIG_INSTANCE_MARKER_FILE) || true

clean: delete
clean:
	@: [+] Removing $(CLUSTER_NODE_NAME) if exists...
	incus profile delete rke2-$(CLUSTER_NODE_NAME) --project rke2 || true
	incus profile delete rke2-$(CLUSTER_NODE_NAME) --project default || true
	incus network delete rke2-$(CLUSTER_NODE_NAME)-br || true
	@: [+] Cleaning up run directory...
	rm -fr $(RUN_INSTANCE_DIR)

clean-all: 
	$(MAKE) NAME=master clean
	$(MAKE) NAME=peer1 clean
	$(MAKE) NAME=peer2 clean
	
#-----------------------------
# ZFS Permissions Target
#-----------------------------
zfs.allow: $(ZFS_ALLOW_MARKER_FILE)

$(ZFS_ALLOW_MARKER_FILE):| $(RUN_DIR)/
	@: "[+] Allowing ZFS permissions for tank..."
	sudo zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	sudo zfs allow -e @allperms tank
	touch $@

#-----------------------------
# Generate $(INCUS_INSTANCE_CONFIG_FILE) using yq for YAML correctness
#-----------------------------
define INCUS_INSTANCE_CONFIG_YQ
. |
	.name =  "$(CLUSTER_NODE_NAME)" |
	.profiles = [ "rke2-$(CLUSTER_NODE_NAME)" ] |
	.devices["eth0"].parent = "rke2-$(CLUSTER_NODE_NAME)-br" |
	.devices["eth0"].hwaddr = "$(CLUSTER_NODE_HWADDR)" |
	.devices["secrets.dir"].source = "$(PWD)/$(RUN_SECRETS_DIR)" |
	.devices["logs.dir"].source = "$(PWD)/$(LOGS_DIR)" |
	.devices["shared.dir"].source = "$(PWD)/$(SHARED_DIR)" |
	.devices["kubeconfig.dir"].source = "$(PWD)/$(KUBECONFIG_DIR)" |
	.devices["user.metadata"].source = "$(PWD)/$(NOCLOUD_METADATA_FILE)" |
	.devices["user.user-data"].source = "$(PWD)/$(NOCLOUD_USERDATA_FILE)"
endef

$(INCUS_INSTANCE_CONFIG_FILE): $(INCUS_INSTANCE_CONFIG_FILENAME)
$(INCUS_INSTANCE_CONFIG_FILE): $(NOCLOUD_METADATA_FILE) $(NOCLOUD_USERDATA_FILE)
$(INCUS_INSTANCE_CONFIG_FILE): export YQ_EXPR := $(INCUS_INSTANCE_CONFIG_YQ)
$(INCUS_INSTANCE_CONFIG_FILE):
	yq eval --from-file=<(echo "$$YQ_EXPR") $(INCUS_INSTANCE_CONFIG_FILENAME) > $(@)

#-----------------------------
# Generate meta-data file
#-----------------------------

define METADATA_INLINE :=
instance-id: $(CLUSTER_NODE_NAME)
local-hostname: $(CLUSTER_NODE_DN)
endef

$(NOCLOUD_METADATA_FILE): | $(NOCLOUD_DIR)/
$(NOCLOUD_METADATA_FILE): export METADATA_INLINE := $(METADATA_INLINE)
$(NOCLOUD_METADATA_FILE):
	@: "[+] Generating meta-data file for instance $(NODE_NAME)..."
	echo "$$METADATA_INLINE" > $(@)

#-----------------------------
# Generate cloud-config.yaml using yq for YAML correctness
#-----------------------------
## Removed TLS_SAN_CONTENT (we build multi-line list directly in TLS SAN patch)

define NOCLOUD_USERDATA_MERGE_YQ
select(fileIndex == 0) as $$common |
  select(fileIndex == 1) as $$server |
  select(fileIndex == 2) as $$node |
  ($$common * $$server * $$node) as $$merged |
  $$merged |
  .write_files = ($$common.write_files + $$server.write_files + $$node.write_files) |
  .runcmd = (($$common.runcmd // []) + ($$server.runcmd // []) + ($$node.runcmd // [])) |
  .name = "$(CLUSTER_NODE_NAME)" |
  .hostname = "$(CLUSTER_NODE_DN)" |
  .fqdn = "$(CLUSTER_NODE_FQDN)"
endef

define NOCLOUD_USERDATA_TLS_SAN_YQ
(.write_files[] | select(.path == "/etc/rancher/rke2/config.yaml.d/tls-san.yaml") | .content) |= (
	from_yaml |
	."tls-san" = [
		"localhost",
		"gateway",
		"0.0.0.0",
		"127.0.0.1",
		"$(CLUSTER_INET_VIRTUAL)",
		"$(CLUSTER_INET_MASTER)",
		"$(CLUSTER_INET_PEER1)",
		"$(CLUSTER_INET_PEER2)"
	] |
	to_yaml
)
endef

define NOCLOUD_USERDATA_CLUSTER_INIT_YQ
(.write_files[] | select(.path == "/etc/rancher/rke2/config.yaml.d/cluster-init.yaml") | .content) |= (
	from_yaml |
	."cluster-init" = $(if $(filter master,$(CLUSTER_NODE_NAME)),true,false) |
	to_yaml
)
endef

define NOCLOUD_USERDATA_ADVERTISE_ADDR_YQ
(.write_files[] | select(.path == "/etc/rancher/rke2/config.yaml.d/advertise-address.yaml") | .content) |= (
	from_yaml |
	."advertise-address" = "$(CLUSTER_NODE_INET)" |
	to_yaml
)
endef

define NOCLOUD_USERDATA_TOKEN_YQ
# Ensure token.yaml contains only the token key (remove any server key)
(.write_files[] | select(.path == "/etc/rancher/rke2/config.yaml.d/token.yaml") | .content) |= (
  from_yaml |
  .token = "$(CLUSTER_TOKEN)" |
  del(.server) |
  to_yaml
)
endef

ifeq ($(CLUSTER_NODE_NAME),master)
define NOCLOUD_USERDATA_SERVER_YQ
.
endef
else
define NOCLOUD_USERDATA_SERVER_YQ
# Add/replace server.yaml fragment pointing to virtual IP (LB)
.
| (.write_files = [ .write_files[] | select(.path != "/etc/rancher/rke2/config.yaml.d/server.yaml") ])
| (.write_files += [{"path": "/etc/rancher/rke2/config.yaml.d/server.yaml", "content": "server: https://$(CLUSTER_INET_VIRTUAL):9345\n"}])
endef
endif

define NOCLOUD_USERDATA_CONTROL_PLANE_LB_YQ
(.write_files[] | select(.path == "/var/lib/rancher/rke2/server/manifests/control-plane-lb.yaml") | .content) |= (from_yaml |
	.metadata.annotations."io.cilium/lb-ipam-ips" = "$(CLUSTER_INET_VIRTUAL)" |
	.metadata.annotations."service.cilium.io/ippool" = "virtual-addresses" |
	.spec.type = "LoadBalancer" |
	.spec.loadBalancerIP = "$(CLUSTER_INET_VIRTUAL)" |
	.spec.ports = [ {"name":"kube-apiserver","port":6443,"protocol":"TCP","targetPort":6443} ] |
	.spec.selector = {"component":"kube-apiserver","tier":"control-plane"} |
	to_yaml )
endef

$(NOCLOUD_USERDATA_FILE): cloud-config.common.yaml cloud-config.server.yaml cloud-config.$(CLUSTER_NODE_NAME).yaml
$(NOCLOUD_USERDATA_FILE): | $(NOCLOUD_DIR)/
$(NOCLOUD_USERDATA_FILE): export YQ_MERGE_EXPR := $(NOCLOUD_USERDATA_MERGE_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_TLS_SAN_EXPR := $(NOCLOUD_USERDATA_TLS_SAN_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_CLUSTER_INIT_EXPR := $(NOCLOUD_USERDATA_CLUSTER_INIT_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_ADVERTISE_ADDR_EXPR := $(NOCLOUD_USERDATA_ADVERTISE_ADDR_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_TOKEN_EXPR := $(NOCLOUD_USERDATA_TOKEN_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_SERVER_EXPR := $(NOCLOUD_USERDATA_SERVER_YQ)
$(NOCLOUD_USERDATA_FILE): export YQ_CONTROL_PLANE_LB_EXPR := $(NOCLOUD_USERDATA_CONTROL_PLANE_LB_YQ)
$(NOCLOUD_USERDATA_FILE): NOCLOUD_USERDATA_TMP := $(NOCLOUD_USERDATA_FILE).tmp
$(NOCLOUD_USERDATA_FILE):
	@: "[+] Generating cloud-config.yaml for instance $(CLUSTER_NODE_NAME)..."
	yq eval-all --prettyPrint --from-file=<(echo "$$YQ_MERGE_EXPR") $(^) > $(NOCLOUD_USERDATA_TMP)
	# Patch specific write_files entries safely using yq -i (multiple passes for clarity)
	# Apply per-file patch expressions via yq (each expression returns the root document)
	# Apply patch expressions sequentially for clarity and resilience
	yq -i --from-file=<(echo "$$YQ_TLS_SAN_EXPR") $(NOCLOUD_USERDATA_TMP)
	yq -i --from-file=<(echo "$$YQ_CLUSTER_INIT_EXPR") $(NOCLOUD_USERDATA_TMP)
	yq -i --from-file=<(echo "$$YQ_ADVERTISE_ADDR_EXPR") $(NOCLOUD_USERDATA_TMP)
	yq -i --from-file=<(echo "$$YQ_TOKEN_EXPR") $(NOCLOUD_USERDATA_TMP)
	yq -i --from-file=<(echo "$$YQ_SERVER_EXPR") $(NOCLOUD_USERDATA_TMP)
	yq -i --from-file=<(echo "$$YQ_CONTROL_PLANE_LB_EXPR") $(NOCLOUD_USERDATA_TMP)
	# Move to final location
	# Ensure #cloud-config header (cloud-init requires this for write_files to apply)
	{ echo '#cloud-config'; echo; cat $(NOCLOUD_USERDATA_TMP); } > $@.hdr && mv $@.hdr $@
	# Structural validation: ensure write_files key exists
	@if ! grep -q '^write_files:' $@; then echo '[ERROR] write_files key missing in $@'; exit 1; fi
	@if ! grep -q '^#cloud-config' $@; then echo '[ERROR] Missing #cloud-config header'; exit 1; fi
	@if ! grep -q '/var/lib/rancher/rke2/server/manifests/control-plane-lb.yaml' $@; then echo '[ERROR] Missing control-plane-lb manifest'; exit 1; fi
	@if ! grep -q '/etc/rancher/rke2/config.yaml.d/tls-san.yaml' $@; then echo '[ERROR] Missing tls-san fragment'; exit 1; fi
	@if ! grep -q '/etc/rancher/rke2/config.yaml.d/token.yaml' $@; then echo '[ERROR] Missing token fragment'; exit 1; fi
	@if [ "$(CLUSTER_NODE_NAME)" != "master" ]; then grep -q '/etc/rancher/rke2/config.yaml.d/server.yaml' $@ || { echo '[ERROR] Missing server fragment for peer node'; exit 1; }; fi
	# Token deterministic from CLUSTER_TOKEN; server.yaml present only on peers

.PHONY: validate-userdata-structure
validate-userdata-structure: $(NOCLOUD_USERDATA_FILE)
	@echo "[+] Extended structural validation"
	@if [ $$(grep -c '^  - path:' $(NOCLOUD_USERDATA_FILE)) -lt 5 ]; then echo '[ERROR] Too few write_files entries'; exit 1; fi
	@echo '[OK] Extended structural validation passed.'

#-----------------------------
# Hardening / Validation Targets
#-----------------------------
.PHONY: validate-userdata
validate-userdata: $(NOCLOUD_USERDATA_FILE)
	@: "[+] Validating rendered cloud-config for unresolved placeholders..."
	@if grep -q '\${[A-Z0-9_]\+}' $(NOCLOUD_USERDATA_FILE); then \
		echo "[ERROR] Unresolved placeholders found in $(NOCLOUD_USERDATA_FILE):"; \
		grep -n '\${[A-Z0-9_]\+}' $(NOCLOUD_USERDATA_FILE); \
		exit 1; \
	else \
		echo "[OK] No unresolved placeholders detected."; \
	fi

#-----------------------------
# Create necessary directories
#-----------------------------
%/:
	mkdir -p $(@)

