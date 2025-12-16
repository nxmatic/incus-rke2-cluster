SHELL ?= bash
.SHELLFLAGS := -exuo pipefail -c

.ONESHELL:

name ?= bioskop

CLUSTER := $(name)
PACKAGES := $(notdir $(wildcard packages/*))

.PHONY: render update

render:
	@echo "[fleet] Rendering is now handled via 'make render@fleet' from the incus-rke2-cluster root." >&2
	@echo "        Example: make render@fleet FLEET_CLUSTER=$(CLUSTER) FLEET_PACKAGES=\"porch flux-operator\"" >&2
	@exit 1

update:
	for pkg in $(PACKAGES); do
	  : kpt pkg update packages/$$pkg
	done
