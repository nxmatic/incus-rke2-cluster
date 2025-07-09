# Makefile for Incus RKE2 Cluster
# @codebase

SHELL := /bin/bash -x

PROJECT_NAME := $(shell incus project get-current)
IMAGE_NAME := $(shell yq -r '.name' ./config.yaml)
INSTANCE_NAME := $(IMAGE_NAME)


INSTANCE_HOST_DN := $(LIMA_HOST:-none)-$(INSTANCE_NAME)
INSTANCE_HOST_FQDN := $(INSTANCE_HOST_DN).mammoth-skate.ts.net

BUILD_PACKAGES := build-packages.yaml

RUN_DIR := /run/incus/$(PROJECT_NAME)/$(INSTANCE_NAME)
BUILD_MARKER := $(RUN_DIR)/build.image


.PHONY: all build stop remove start clean patch-config patch-cloud-config

all: build start

build: $(BUILD_PACKAGES)
build: $(BUILD_MARKER)

$(BUILD_MARKER):
	: "[+] (Re)building image if not present or build-packages.yaml changed..."
	incus rm -f $(IMAGE_NAME) || true
	incus image delete $(IMAGE_NAME) || true
	env -i -S \
		TSID=$$(cat .secrets.d/tsid) \
		TSKEY=$$(cat .secrets.d/tskey) \
		PATH=$$PATH \
		sudo distrobuilder --debug --disable-overlay \
			build-incus --import-into-incus=$(IMAGE_NAME) $(BUILD_PACKAGES)
	touch $(MARKER)

INSTANCE_CONFIG_FILE := $(RUN_DIR)/config.yaml
CLOUD_CONFIG_FILE := $(RUN_DIR)/cloud-config.yaml

init: build
init: $(INSTANCE_CONFIG_FILE) $(CLOUD_CONFIG_FILE)
init:
	$(if $(TSKEY),,$(error TSKEY must be set))
	$(if $(TSID),,$(error TSID must be set))
	: "[+] Initializing instance $(INSTANCE_NAME)..."
	incus init $(IMAGE_NAME) $(INSTANCE_NAME) < $(INSTANCE_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) cloud-init.user-data - < $(CLOUD_CONFIG_FILE)
	incus config set $(INSTANCE_NAME) environment.CLUSTER_NAME "$(CLUSTER_NAME)"
	incus config set $(INSTANCE_NAME) environment.CLUSTER_ID "$(CLUSTER_ID)"
	incus config set $(INSTANCE_NAME) environment.TSKEY "$(TSKEY)"
	incus config set $(INSTANCE_NAME) environment.TSID "$(TSID)"

INSTANCE_YQ_FILE := $(RUN_DIR)/config.yq

$(INSTANCE_CONFIG_FILE): instance-config.yaml
$(INSTANCE_CONFIG_FILE): $(INSTANCE_YQ_FILE)
$(INSTANCE_CONFIG_FILE): $(RUN_DIR)/
$(INSTANCE_CONFIG_FILE):
	yq eval --from-file=$(INSTANCE_YQ_FILE) instance-config.yaml > $(@)

define INSTANCE_YQ_EXPR
. |
  .name =  "$(INSTANCE_NAME)" |
  .devices["user.metadata"].source = "$(RUN_DIR)/meta-data" |
  .devices["user.user-data"].source = "$(RUN_DIR)/user-data" |
  .devices["secrets.dir"].source = "$(PWD)/.secrets.d" |
  .devices["shared.dir"].source = "$(PWD)/.shared.d" |
  .devices["kubeconfig.dir"].source = "$(PWD)/.kubeconfig.d" |
  .devices["modules.dir"].source = "$(shell realpath /run/booted-system/kernel-modules/lib/modules)" |
  .devices["helm.bin"].source = "$(shell realpath $(PWD)/.flox/run/aarch64-linux.incus.run/bin/helm)"
endef

$(INSTANCE_YQ_FILE): $(RUN_DIR)/
$(INSTANCE_YQ_FILE): 
	: $(file >$(@), $(INSTANCE_YQ_EXPR))

define CLOUD_CONFIG_INLINE
hostname: $(INSTANCE_HOST_DN)
fqdn: $(INSTANCE_HOST_FQDN)
manage_resolv_conf: true
endef

$(CLOUD_CONFIG_FILE): $(RUN_DIR)/
$(CLOUD_CONFIG_FILE): /dev/stdin cloud-config.yaml
$(CLOUD_CONFIG_FILE): export inline=$(CLOUD_CONFIG_INLINE)
$(CLOUD_CONFIG_FILE):
	echo "$${inline}" | yq eval-all . /dev/stdin cloud-config.yaml > $(@)

start: init
start: zfs.allow
start:
	: "[+] Starting instance $(IMAGE_NAME)..."
	incus start $(IMAGE_NAME)

stop:
	: "[+] Stopping instance $(IMAGE_NAME) if running..."
	incus stop $(IMAGE_NAME) || true

remove: stop
	: "[+] Removing instance and image if present..."
	incus rm -f $(INSTANCE_NAME) || true
	incus image delete $(IMAGE_NAME) || true
	rm -fr $(RUN_DIR)
	
clean: remove
	: "[+] Cleaned up all artifacts."

zfs.allow: $(RUN_DIR)/tank

$(RUN_DIR)/tank: $(RUN_DIR)/
$(RUN_DIR)/tank:
	sudo zfs allow -s @allperm allow,clone,create,destroy,mount,promote,receive,rename,rollback,send,share,snapshot tank
	sudo zfs allow -e @allperms tank
	touch $(RUN_DIR)/tank

%/:
	mkdir -p $(@)

.INTERMEDIATE: $(INSTANCE_CONFIG_FILE)
.INTERMEDIATE: $(CLOUD_CONFIG_FILE)
.INTERMEDIATE: $(INSTANCE_YQ_FILE)
