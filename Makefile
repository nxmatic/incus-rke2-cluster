SHELL ?= bash
.SHELLFLAGS := -euo pipefail -c

PACKAGES := porch porch-resources replicator flux-operator tekton-pipelines traefik cilium
CLUSTER ?= default

.PHONY: render sync-packages clean-manifests clean-rendered

render:
	./render.sh $(CLUSTER)

sync-packages:
	@for pkg in $(PACKAGES); do \
		rs="/private/var/lib/git/nxmatic/incus-rke2-cluster/kpt/system/$${pkg}"; \
		[[ -d "$$rs" ]] || { echo "missing $$rs" >&2; exit 1; }; \
		rsync -a --delete --exclude='.git' --exclude='.gitignore' "$$rs/" "packages/$$pkg/"; \
	done

clean-manifests:
	rm -rf manifests

clean-rendered:
	rm -rf rendered
