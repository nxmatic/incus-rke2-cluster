# fleet/rules.mk - Fleet manifests subtree helpers (@codebase)
# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/fleet/rules.mk

-include make.d/make.mk

FLEET_DIR ?= fleet
FLEET_REMOTE ?= fleet
FLEET_BRANCH ?= rke2-subtree

# Fleet render configuration (@codebase)
fleet.root := $(abspath $(FLEET_DIR))
fleet.packages_root := $(fleet.root)/packages
FLEET_CLUSTER ?= $(cluster.NAME)
FLEET_PACKAGES ?= $(notdir $(wildcard $(fleet.packages_root)/*))
fleet.cluster_packages_dir = $(fleet.root)/clusters/$(FLEET_CLUSTER)/packages
fleet.cluster_kustomization = $(fleet.cluster_packages_dir)/kustomization.yaml
fleet.manifests_file = $(fleet.root)/clusters/$(FLEET_CLUSTER)/manifests.yaml
fleet.package_render_markers = $(foreach pkg,$(FLEET_PACKAGES),$(fleet.cluster_packages_dir)/$(pkg)/.rendered)

define fleet.require-bin
	@if ! command -v $(1) >/dev/null 2>&1; then
		: "[fleet] Missing required command $(1)"
		exit 1
	fi
endef

# ----------------------------------------------------------------------------
# Rendering pipeline (@codebase)
# ----------------------------------------------------------------------------

.PHONY: render@fleet check-tools@fleet prepare@fleet

render@fleet: check-tools@fleet prepare@fleet $(fleet.manifests_file) ## Render Fleet packages via kpt fn render + kustomize (@codebase)
	: "[fleet] wrote manifests to $(fleet.manifests_file)"

check-tools@fleet:
	$(call fleet.require-bin,kpt)
	$(call fleet.require-bin,kustomize)
	if [ -z "$(strip $(FLEET_PACKAGES))" ]; then
		echo "[fleet] No packages discovered under $(fleet.packages_root)" >&2
		exit 1
	fi
	: "[fleet] Rendering cluster $(FLEET_CLUSTER) (packages: $(FLEET_PACKAGES))"

prepare@fleet:
	rm -rf "$(fleet.cluster_packages_dir)"
	mkdir -p "$(fleet.cluster_packages_dir)"
	rm -f "$(fleet.manifests_file)"

$(fleet.manifests_file): $(fleet.cluster_kustomization)
	kustomize build "$(fleet.root)/clusters/$(FLEET_CLUSTER)" > "$@"

$(fleet.cluster_kustomization): $(fleet.package_render_markers)
	{
		echo "apiVersion: kustomize.config.k8s.io/v1beta1"
		echo "kind: Kustomization"
		if [ -n "$(strip $(FLEET_PACKAGES))" ]; then
			echo "resources:"
			for pkg in $(FLEET_PACKAGES); do
				echo "  - ./$$pkg"
			done
		else
			echo "resources: []"
		fi
	} > "$@"

$(fleet.cluster_packages_dir)/%/.rendered: $(fleet.packages_root)/%
	rm -rf "$(dir $@)"
	if [ ! -d "$<" ]; then
		echo "[fleet] Package $* missing at $<" >&2
		exit 1
	fi
	: "[fleet] kpt fn render $*"
	kpt fn render "$<" -o "$(dir $@)"
	(
		cd "$(dir $@)"
		resources="$$(find . -type f -name '*.yaml' ! -name 'kustomization.yaml' | LC_ALL=C sort)"
		{
			echo "apiVersion: kustomize.config.k8s.io/v1beta1"
			echo "kind: Kustomization"
			if [ -n "$$resources" ]; then
				echo "resources:"
				printf '%s\n' "$$resources" | while IFS= read -r res; do
					res="$${res#./}"
					echo "  - $$res"
				done
			else
				echo "resources: []"
			fi
		} > kustomization.yaml
	)
	touch "$@"

# ----------------------------------------------------------------------------
# Fleet subtree synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: fleet-remote fleet-finalize-merge fleet-check-clean fleet-pull fleet-push

fleet-remote:
	@if ! git remote get-url "$(FLEET_REMOTE)" >/dev/null 2>&1; then
		git remote add "$(FLEET_REMOTE)" git@github.com:nxmatic/fleet-manifests.git
	fi

fleet-finalize-merge:
	@if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		if git diff --name-only --diff-filter=U | grep -q .; then
			echo "Merge in progress with unresolved conflicts; resolve before continuing." >&2
			exit 1
		fi
		: "Completing pending fleet subtree merge..."
		GIT_MERGE_AUTOEDIT=no git commit --no-edit --quiet
	fi

fleet-check-clean:
	@if ! git diff --quiet -- "$(FLEET_DIR)"; then
		echo "Uncommitted changes detected inside $(FLEET_DIR)." >&2
		exit 1
	fi
	untracked="$$(git ls-files --others --exclude-standard -- "$(FLEET_DIR)")"
	if [ -n "$$untracked" ]; then
		echo "Untracked files detected inside $(FLEET_DIR)." >&2
		echo "Files:" >&2
		echo "$$untracked" >&2
		exit 1
	fi

fleet-pull: fleet-remote fleet-finalize-merge fleet-check-clean
	git fetch --prune "$(FLEET_REMOTE)" "$(FLEET_BRANCH)"
	git subtree pull --prefix="$(FLEET_DIR)" "$(FLEET_REMOTE)" "$(FLEET_BRANCH)" --squash

fleet-push: fleet-remote fleet-check-clean
	@split_sha="$$(git subtree split --prefix="$(FLEET_DIR)" HEAD)"
	remote_sha="$$(git ls-remote --heads "$(FLEET_REMOTE)" "$(FLEET_BRANCH)" | awk '{print $$1}')" || true
	if [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then
		: "No new fleet revisions to push; skipping."
	else
		git subtree push --prefix="$(FLEET_DIR)" "$(FLEET_REMOTE)" "$(FLEET_BRANCH)"
	fi

endif # make.d/fleet/rules.mk guard
