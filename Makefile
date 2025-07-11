# Makefile for Incus RKE2 Cluster
#-----------------------------
# Shell, Project, and Run Directory Variables
#-----------------------------
SHELL := /bin/bash -exuo pipefail
export PATH := /run/wrappers/bin:$(PATH)

# Project and Instance Names
PROJECT_NAME := $(shell incus project get-current)
IMAGE_NAME := master-control-node
INSTANCE_NAME := $(IMAGE_NAME)
INSTANCE_HOSTNAME := $(LIMA_HOSTNAME)-$(IMAGE_NAME)
INSTANCE_FQDN := $(INSTANCE_HOSTNAME).$(LIMA_DN)

# Run directory and all derived paths
SECRETS_DIR := $(PWD)/.secrets.d
RUN_DIR := /run/incus/$(PROJECT_NAME)/$(INSTANCE_NAME)
BUILD_MARKER_FILE := $(RUN_DIR)/build
INIT_MARKER_FILE := $(RUN_DIR)/init
ZFS_ALLOW_MARKER_FILE := $(RUN_DIR)/zfs.allow
INSTANCE_CONFIG_FILENAME := instance-config.yaml
INSTANCE_CONFIG_FILE := $(RUN_DIR)/$(INSTANCE_CONFIG_FILENAME)
CLOUD_CONFIG_FILENAME := cloud-config.yaml
CLOUD_CONFIG_FILE := $(RUN_DIR)/$(CLOUD_CONFIG_FILENAME)
METADATA_FILENAME := meta-data
METADATA_FILE := $(RUN_DIR)/$(METADATA_FILENAME)
SHARED_DIR := $(PWD)/.shared.d
KUBECONFIG_DIR := $(PWD)/.kubeconfig.d

BUILD_PACKAGES_FILE := build-packages.yaml

#-----------------------------
# Main Targets
#-----------------------------
.PHONY: all build init start stop remove clean
#.INTERMEDIATE: $(INSTANCE_CONFIG_FILE)

all: build start

#-----------------------------
# Build Targets
#-----------------------------

build: $(BUILD_MARKER_FILE)

$(BUILD_MARKER_FILE): $(BUILD_PACKAGES_FILE)
$(BUILD_MARKER_FILE): | $(RUN_DIR)/
$(BUILD_MARKER_FILE):
	: [+] Building instance $(INSTANCE_NAME)...
	env -i -S \
    	TSID=$(file <$(SECRETS_DIR)/tsid) \
    	TSKEY=$(file <$(SECRETS_DIR)/tskey) \
    	PATH=$$PATH \
    	sudo distrobuilder --debug --disable-overlay \
      		build-incus --import-into-incus=${IMAGE_NAME} $(BUILD_PACKAGES_FILE) 2>&1 | \
			tee -a distrobuilder.log
	touch $@


#-----------------------------
# Instance Lifecycle Targets
#-----------------------------
init: $(INIT_MARKER_FILE)

$(INIT_MARKER_FILE): $(BUILD_MARKER_FILE) $(METADATA_FILE) $(INSTANCE_CONFIG_FILE) $(CLOUD_CONFIG_FILE)
$(INIT_MARKER_FILE): | $(SHARED_DIR)/ $(KUBECONFIG_DIR)/
$(INIT_MARKER_FILE):
	$(if $(TSKEY),,$(error TSKEY must be set))
	$(if $(TSID),,$(error TSID must be set))
	: "[+] Initializing instance $(INSTANCE_NAME)..."
	incus init $(IMAGE_NAME) $(INSTANCE_NAME) < $(INSTANCE_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) cloud-init.user-data - < $(CLOUD_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) environment.CLUSTER_NAME "$(CLUSTER_NAME)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_ID "$(CLUSTER_ID)"
	incus config set $(INSTANCE_NAME) environment.TSKEY "$(TSKEY)"
	incus config set $(INSTANCE_NAME) environment.TSID "$(TSID)"
	touch $@

start: init zfs.allow
start:
	: "[+] Starting instance $(INSTANCE_NAME)..."
	incus start $(IMAGE_NAME) $(INSTANCE_NAME)

shell:
	: "[+] Opening a shell in instance $(INSTANCE_NAME)..."
	incus exec $(INSTANCE_NAME) -- bash

stop:
	: "[+] Stopping instance $(INSTANCE_NAME) if running..."
	incus stop $(INSTANCE_NAME) || true

remove: stop
	: "[+] Removing instance and image if present..."
	incus rm -f $(INSTANCE_NAME) || true
	incus image delete $(IMAGE_NAME) || true
	rm -fr $(RUN_DIR)

clean: remove
	: "[+] Cleaned up all artifacts."

#-----------------------------
# ZFS Permissions Target
#-----------------------------
zfs.allow: $(ZFS_ALLOW_MARKER_FILE)

$(ZFS_ALLOW_MARKER_FILE):| $(RUN_DIR)/
	: "[+] Allowing ZFS permissions for tank..."
	sudo zfs allow -s @allperms allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	sudo zfs allow -e @allperms tank
	touch $@

#-----------------------------
# Generate cloud-config.yaml using yq for YAML correctness
#-----------------------------
define INSTANCE_YQ
. |
	.name =  "$(INSTANCE_NAME)" |
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
	: "[+] Generating meta-data file for instance $(INSTANCE_NAME)..."
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
	: "[+] Generating cloud-config.yaml for instance $(INSTANCE_NAME)..."
	yq eval --from-file=<(echo "$$CLOUD_CONFIG_YQ") \
        $(CLOUD_CONFIG_FILENAME) > $@

#-----------------------------
# Create necessary directories
#-----------------------------
%/:
	mkdir -p $(@)

