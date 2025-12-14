SHELL ?= bash
.SHELLFLAGS := -exuo pipefail -c

.ONESHELL:

name ?= bioskop

CLUSTER := $(name)
PACKAGES := $(notdir $(wildcard packages/*))

.PHONY: render update

render: update
render:
	./render.sh $(CLUSTER) $(PACKAGES)

update:
	for pkg in $(PACKAGES); do
	  : kpt pkg update packages/$$pkg
	done
