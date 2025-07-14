# Makefile for Incus RKE2 Cluster
#-----------------------------
# Shell, Project, and Run Directory Variables
#-----------------------------
SHELL := /bin/bash -exuo pipefail
export PATH := /run/wrappers/bin:$(PATH)

empty :=
colon := :
space := $(empty) $(empty)

# Project and Instance Names
CLUSTER_NAME := $(LIMA_HOSTNAME)
IMAGE_NAME := master-control-node
INSTANCE_NAME := $(IMAGE_NAME)
INSTANCE_HOSTNAME := $(IMAGE_NAME)
INSTANCE_FQDN := $(CLU)-$(INSTANCE_HOSTNAME).$(LIMA_DN)

# Directories
SECRETS_DIR := $(PWD)/.secrets.d
RUN_DIR := $(PWD)/.run.d
SHARED_DIR := $(PWD)/.shared.d
KUBECONFIG_DIR := $(PWD)/kubeconfig.d
LOGS_DIR := $(PWD)/.logs.d

# Config Paths
DISTROBUILDER_FILE := $(PWD)/distrobuilder.yaml
PROJECT_MARKER_FILE := $(RUN_DIR)/project
BUILD_MARKER_FILES := $(RUN_DIR)/incus.tar.xz $(RUN_DIR)/rootfs.squashfs
IMAGE_MARKER_FILE := $(RUN_DIR)/image
INSTANCE_MARKER_FILE := $(RUN_DIR)/instance
ZFS_ALLOW_MARKER_FILE := $(RUN_DIR)/zfs.allow
INSTANCE_CONFIG_FILENAME := incus-instance.master.yaml
INSTANCE_CONFIG_FILE := $(RUN_DIR)/incus-$(INSTANCE_NAME)-config.yaml
CLOUD_CONFIG_FILENAME := cloud-config.master.yaml
CLOUD_CONFIG_FILE := $(RUN_DIR)/$(CLOUD_CONFIG_FILENAME)
METADATA_FILENAME := meta-data
METADATA_FILE := $(RUN_DIR)/$(METADATA_FILENAME)
DISTRIBUILDER_LOGFILE := $(LOGS_DIR)/distrobuilder.log
PRESEED_FILENAME := incus-preseed.yaml
PRESEED_FILE := $(RUN_DIR)/${PRESEED_FILENAME}

#-----------------------------
# Cluster Environment Variables
#-----------------------------

.PHONY: print-cluster-env

CLUSTER_ENV_FILE := $(RUN_DIR)/cluster-env.mk

-include $(CLUSTER_ENV_FILE)

$(CLUSTER_ENV_FILE): _hwaddr = $(shell cat /sys/class/net/enp0s1/address)
$(CLUSTER_ENV_FILE): _hwaddr_words = $(subst $(colon),$(space),$(_hwaddr))
$(CLUSTER_ENV_FILE): _hwaddr_words_network_words = $(wordlist 4,5,$(_hwaddr_words))
$(CLUSTER_ENV_FILE): _hwaddr_words_network_part = $(subst $(space),$(colon),$(_hwaddr_words_network_words))

$(CLUSTER_ENV_FILE): CLUSTER_NAME ?= "unamed-cluster"
$(CLUSTER_ENV_FILE): CLUSTER_SUBNET ?= $(call _CLUSTER_SUBNET,$(CLUSTER_NAME))
$(CLUSTER_ENV_FILE): NAME = $(CLUSTER_NAME)
$(CLUSTER_ENV_FILE): SUBNET = $(CLUSTER_SUBNET)
$(CLUSTER_ENV_FILE): SUPERNET = 172.31.0.0/16
$(CLUSTER_ENV_FILE): NODES_CIDR = 172.31.$(CLUSTER_SUBNET).1/28
$(CLUSTER_ENV_FILE): LOADBALANCERS_CIDR = 172.31.$(CLUSTER_SUBNET).128/25
$(CLUSTER_ENV_FILE): PODS_CIDR = 10.$(CLUSTER_SUBNET).0.0/17
$(CLUSTER_ENV_FILE): SERVICES_CIDR = 10.$(CLUSTER_SUBNET).128.0/17
$(CLUSTER_ENV_FILE): NODE_HWADDR =  10:66:6a:$(_hwaddr_words_network_part):0$(CLUSTER_SUBNET)

$(CLUSTER_ENV_FILE): | $(RUN_DIR)/
$(CLUSTER_ENV_FILE):
	@: Defined environment variables for cluster $(CLUSTER_NAME) $(NODES_CIDR) $(file > $@,$(CLUSTER_ENV))

define CLUSTER_ENV
CLUSTER_NAME=$(NAME)
CLUSTER_SUBNET=$(SUBNET)
CLUSTER_NODES_CIDR=$(NODES_CIDR)
CLUSTER_LOADBALANCERS_CIDR=$(LOADBALANCERS_CIDR)
CLUSTER_PODS_CIDR=$(PODS_CIDR)
CLUSTER_SERVICES_CIDR=$(SERVICES_CIDR)
CLUSTER_NODE_HWADDR=$(NODE_HWADDR)
endef
print-cluster-env: $(eval include $(CLUSTER_ENV_FILE))
print-cluster-env:
	@: CLUSTER_NAME=$(CLUSTER_NAME)
	@: CLUSTER_SUBNET=$(CLUSTER_SUBNET)
	@: CLUSTER_NODES_CIDR=$(CLUSTER_NODES_CIDR)
	@: CLUSTER_LOADBALANCERS_CIDR=$(CLUSTER_LOADBALANCERS_CIDR)
	@: CLUSTER_PODS_CIDR=$(CLUSTER_PODS_CIDR)
	@: CLUSTER_SERVICES_CIDR=$(CLUSTER_SERVICES_CIDR)
	@: CLUSTER_NODE_HWADDR=$(CLUSTER_NODE_HWADDR)

define _CLUSTER_SUBNET
ifeq ($(strip $(1)),bioskop)
1
else ifeq ($(strip $(1)),alcide)
2
else
$$(error CLUSTER_NAME='$(1)' must be set to alcide or bioskop)
endif
endef

#-----------------------------

.PHONY: all start stop delete clean shell

all: start

#-----------------------------
# Preseed Rendering Targets
#-----------------------------

.PHONY: preseed

preseed: $(PRESEED_FILE)

define DNSMASQ_RAW
log-debug
log-dhcp
log-facility=daemon
dumpfile=/var/log/incus/dnsmasq.rke2-br.pcap
dumpmask=0x5000
endef

define PRESEED_YQ
. |
  .networks[0].config."raw.dnsmasq" = "$(DNSMASQ_RAW)" |
  .networks[0].config."ipv4.address" = "$(CLUSTER_NODES_CIDR)"
endef

$(PRESEED_FILE): $(PRESEED_FILENAME) | $(RUN_DIR)/
$(PRESEED_FILE): export PRESEED_YQ := $(PRESEED_YQ)
$(PRESEED_FILE):
	@: [+] Generating preseed file ...
	yq eval --from-file=<(echo "$$PRESEED_YQ") $(PRESEED_FILENAME) > $@
	incus admin init --preseed < $(PRESEED_FILE)

#-----------------------------
# Project Management Target
#-----------------------------

.PHONY: project

project: preseed
project: $(PROJECT_MARKER_FILE) | $(RUN_DIR)/
project:
	@: [+] Switching to project $(CLUSTER_NAME)
	incus project switch rke2

$(PROJECT_MARKER_FILE): | $(RUN_DIR)/
	@: [+] Creating incus project rke2 if not exists...
	incus project create rke2 || true
	@: [+] Importing incus profile rke2
	incus profile show rke2 --project default | \
	  incus profile create rke2 --project rke2 || true
	touch $@

#-----------------------------
# Main Targets
#-----------------------------
MAIN_TARGETS := image instance start stop delete clean shell

$(MAIN_TARGETS): preseed project


.PHONY: $(MAIN_TARGETS)

image: $(IMAGE_MARKER_FILE)

$(IMAGE_MARKER_FILE): $(BUILD_MARKER_FILES)
$(IMAGE_MARKER_FILE): | $(RUN_DIR)/
$(IMAGE_MARKER_FILE):
	@: [+] Importing image for instance $(INSTANCE_NAME)...
	incus image import $(^) --alias $(IMAGE_NAME) --reuse
	touch $@

$(BUILD_MARKER_FILES): $(DISTRIBUILDER_FILE) | $(RUN_DIR)/ $(LOGS_DIR)/
$(BUILD_MARKER_FILES): $(SECRETS_DIR)/tsid $(SECRETS_DIR)/tskey
$(BUILD_MARKER_FILES)&:
	$(if $(TSKEY),,$(error TSKEY must be set))
	$(if $(TSID),,$(error TSID must be set))
	@: [+] Building instance $(INSTANCE_NAME)...
	env -i -S \
		TSID=$(file <$(SECRETS_DIR)/tsid) \
		TSKEY=$(file <$(SECRETS_DIR)/tskey) \
		PATH=$$PATH \
		  sudo distrobuilder --debug --disable-overlay \
			  build-incus $(DISTROBUILDER_FILE) 2>&1 | \
			tee $(DISTRIBUILDER_LOGFILE)
	mv incus.tar.xz rootfs.squashfs $(RUN_DIR)/

#-----------------------------
# Lifecycle Targets
#-----------------------------

.PHONY: instance start shell stop delete clean

instance: $(INSTANCE_MARKER_FILE)

$(INSTANCE_MARKER_FILE): $(IMAGE_MARKER_FILE) $(METADATA_FILE) $(INSTANCE_CONFIG_FILE) $(CLOUD_CONFIG_FILE)
$(INSTANCE_MARKER_FILE): | $(SHARED_DIR)/ $(KUBECONFIG_DIR)/
$(INSTANCE_MARKER_FILE):
	@: "[+] Initializing instance $(INSTANCE_NAME)..."
	incus init $(IMAGE_NAME) $(INSTANCE_NAME) < $(INSTANCE_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) cloud-init.user-data - < $(CLOUD_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) environment.CLUSTER_NAME "$(CLUSTER_NAME)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_SUBNET "$(CLUSTER_SUBNET)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_NODES_CIDR "$(CLUSTER_NODES_CIDR)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_LOADBALANCERS_CIDR "$(CLUSTER_LOADBALANCERS_CIDR)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_NODE_HWADDR "$(CLUSTER_NODE_HWADDR)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_PODS_CIDR "$(CLUSTER_PODS_CIDR)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_SERVICES_CIDR "$(CLUSTER_SERVICES_CIDR)"
	incus config set $(INSTANCE_NAME) environment.TSKEY "$(TSKEY)"
	incus config set $(INSTANCE_NAME) environment.TSID "$(TSID)"
	incus config device set $(INSTANCE_NAME) eth0 hwaddr "$(CLUSTER_NODE_HWADDR)"
	touch $@

start: instance zfs.allow
start:
	@: "[+] Starting instance $(INSTANCE_NAME)..."
	incus start $(IMAGE_NAME) $(INSTANCE_NAME)

shell:
	@: "[+] Opening a shell in instance $(INSTANCE_NAME)..."
	incus exec $(INSTANCE_NAME) -- bash

stop:
	@: "[+] Stopping instance $(INSTANCE_NAME) if running..."
	incus stop $(INSTANCE_NAME) || true

delete:
	@: "[+] Removing instance $(INSTANCE_NAME)..."
	incus delete -f $(INSTANCE_NAME) || true
	rm -f $(INSTANCE_CONFIG_FILE)$(CLOUD_CONFIG_FILE) $(INSTANCE_MARKER_FILE)

clean: stop
	@: [+] Removing instance and image if present...

	incus rm -f $(INSTANCE_NAME) || true
	incus image delete $(IMAGE_NAME) || true
	incus project switch default || true
	incus project delete rke2 || true
	@: [+] Cleaning up run directory...

	rm -fr $(RUN_DIR)

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
# Generate $(INSTANCE_CONFIG_FILE) using yq for YAML correctness
#-----------------------------
define INSTANCE_YQ
. |
	.name =  "$(INSTANCE_NAME)" |
	.devices["eth0"].hwaddr = "$(CLUSTER_NODE_HWADDR)" |
	.devices["user.metadata"].source = "$(METADATA_FILE)" |
	.devices["user.user-data"].source = "$(CLOUD_CONFIG_FILE)" |
	.devices["secrets.dir"].source = "$(SECRETS_DIR)" |
	.devices["shared.dir"].source = "$(SHARED_DIR)" |
	.devices["kubeconfig.dir"].source = "$(KUBECONFIG_DIR)" |
	.devices["helm.bin"].source = "$(PWD)/$(HELM_BIN)"
endef

$(INSTANCE_CONFIG_FILE): $(INSTANCE_CONFIG_FILENAME)
$(INSTANCE_CONFIG_FILE): export INSTANCE_YQ := $(INSTANCE_YQ)
$(INSTANCE_CONFIG_FILE):
$(INSTANCE_CONFIG_FILE):
	yq eval --from-file=<(echo "$$INSTANCE_YQ") $(INSTANCE_CONFIG_FILENAME) > $(@)

#-----------------------------
# Generate meta-data file
#-----------------------------

define METADATA_INLINE :=
instance-id: $(INSTANCE_NAME)
local-hostname: $(INSTANCE_HOSTNAME)
endef

$(METADATA_FILE): | $(RUN_DIR)/
$(METADATA_FILE): export METADATA_INLINE := $(METADATA_INLINE)
$(METADATA_FILE):
	@: "[+] Generating meta-data file for instance $(INSTANCE_NAME)..."
	echo "$$METADATA_INLINE" > $(@)

#-----------------------------
# Generate cloud-config.yaml using yq for YAML correctness
#-----------------------------
define CLOUD_CONFIG_YQ
.hostname = "$(INSTANCE_HOSTNAME)" |
.fqdn = "$(INSTANCE_FQDN)"
endef

$(CLOUD_CONFIG_FILE): $(CLOUD_CONFIG_FILENAME) | $(RUN_DIR)/
$(CLOUD_CONFIG_FILE): export CLOUD_CONFIG_YQ := $(CLOUD_CONFIG_YQ)
$(CLOUD_CONFIG_FILE):
	@: "[+] Generating cloud-config.yaml for instance $(INSTANCE_NAME)..."
	yq eval --prettyPrint --from-file=<(echo "$$CLOUD_CONFIG_YQ") \
		$(CLOUD_CONFIG_FILENAME) > $@

#-----------------------------
# Create necessary directories
#-----------------------------
%/:
	mkdir -p $(@)

