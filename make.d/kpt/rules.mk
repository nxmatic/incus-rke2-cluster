# kpt/rules.mk - KPT package catalog and fleet manifests management (@codebase)
# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/kpt/rules.mk

-include make.d/make.mk

# KPT catalog configuration (@codebase)

kpt.catalog.system.dir := $(top-dir)/kpt/catalog/system
kpt.catalog.system.packages = $(notdir $(patsubst %/,%,$(dir $(wildcard $(kpt.catalog.system.dir)/*/Kptfile))))

# Fleet render configuration (@codebase)

.fleet.git.remote ?= fleet
.fleet.git.branch ?= rke2-subtree
.fleet.git.subtree.dir ?= $(top-dir)/kpt/fleet

.fleet.cluster.name := $(cluster.NAME)
.fleet.cluster.dir := $(.fleet.git.subtree.dir)/clusters/$(.fleet.cluster.name)
.fleet.cluster.catalog.dir := $(.fleet.cluster.dir)/catalog
.fleet.cluster.overlays.dir := $(.fleet.cluster.dir)/overlays
.fleet.cluster.overlays.Kustomization.file := $(.fleet.cluster.overlays.dir)/Kustomization
.fleet.cluster.Kustomization.file := $(.fleet.cluster.dir)/Kustomization
.fleet.cluster.manifests.file := $(.fleet.cluster.dir)/manifests.yaml

# Render staging directory to avoid mutating the checked-in catalog (@codebase)
.fleet.cluster.render.dir := $(top-dir)/.local.d/var/kpt/$(.fleet.cluster.name)
.fleet.cluster.render.catalog.dir := $(.fleet.cluster.render.dir)/catalog
.fleet.cluster.render.overlays.dir := $(.fleet.cluster.render.dir)/overlays

.fleet.cluster.catalog.names = $(notdir $(patsubst %/,%,$(dir $(wildcard $(.fleet.cluster.catalog.dir)/*/Kptfile))))
.fleet.package.aux_files := .gitattributes .krmignore

define .fleet.require-bin
	@if ! command -v $(1) >/dev/null 2>&1; then
		: "[fleet] Missing required command $(1)"
		exit 1
	fi
endef

# ----------------------------------------------------------------------------
# Catalog Kustomization management (@codebase)
# ----------------------------------------------------------------------------

.PHONY: update-kustomizations@kpt

update-kustomizations@kpt:  ## Update Kustomization files in all catalog packages
	@for layer in $(kpt.catalog.system.dir)/../*/; do
		[ -d "$$layer" ] || continue
		for pkg in "$$layer"/*/; do
			[ -d "$$pkg" ] || continue
			if [ -f "$$pkg/Kptfile" ]; then
				echo "[kpt] Updating Kustomization for package $$(basename $$pkg)"
				resources="$$(cd $$pkg && find . -maxdepth 1 -name '*.yaml' ! -name 'Kustomization' ! -name '*-setters.yaml' ! -name 'render-*.yaml' ! -name 'helmchartconfig.yaml' -type f | sed 's|^\./||' | sort)"
				if [ -n "$$resources" ]; then
					echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$$pkg/Kustomization"
					echo "kind: Kustomization" >> "$$pkg/Kustomization"
					echo "resources:" >> "$$pkg/Kustomization"
					for res in $$resources; do
						echo "  - $$res" >> "$$pkg/Kustomization"
					done
				else
					echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$$pkg/Kustomization"
					echo "kind: Kustomization" >> "$$pkg/Kustomization"
					echo "resources: []" >> "$$pkg/Kustomization"
				fi
			fi
		done
	done

# ----------------------------------------------------------------------------
# Rendering pipeline (@codebase)
# ----------------------------------------------------------------------------

.PHONY: render@kpt check-tools@kpt prepare@kpt

render@kpt: check-tools@kpt prepare@kpt $(.fleet.cluster.overlays.Kustomization.file) $(.fleet.cluster.Kustomization.file)
render@kpt: $(.fleet.cluster.manifests.file)  ## Render catalog via kpt, aggregate via kustomize (@codebase)

$(.fleet.cluster.manifests.file): $(.fleet.cluster.Kustomization.file)
$(.fleet.cluster.manifests.file):
	: "[kpt] Staging catalog for cluster $(.fleet.cluster.name) into $(.fleet.cluster.render.dir)"
	rm -rf "$(.fleet.cluster.render.dir)"
	kpt pkg get "$(.fleet.cluster.dir)" "$(.fleet.cluster.render.dir)"
	: "[kpt] Rendering catalog for cluster $(.fleet.cluster.name) via kpt fn render (staged)"
	kpt fn render --truncate-output=false "$(.fleet.cluster.render.catalog.dir)"
	: "[kpt] Building manifests for cluster $(.fleet.cluster.name) via kustomize build (staged)"
	kustomize build "$(.fleet.cluster.render.dir)" > "$@"

check-tools@kpt:
	$(call .fleet.require-bin,kpt)
	$(call .fleet.require-bin,kustomize)
	: "[kpt] Rendering cluster $(.fleet.cluster.name)"

prepare@kpt:
	: "[kpt] Preparing cluster $(.fleet.cluster.name) catalog via kpt pkg get/update"
	mkdir -p "$(.fleet.cluster.dir)"
	if [[ ! -d "$(.fleet.cluster.catalog.dir)" ]]; then
		kpt pkg get "$(realpath $(top-dir)).git/kpt/catalog" "$(.fleet.cluster.catalog.dir)"
	else
		kpt pkg update "$(.fleet.cluster.catalog.dir)@main"
	fi
	rm -f "$(.fleet.cluster.manifests.file)"
	mkdir -p "$(.fleet.cluster.overlays.dir)"
	mkdir -p "$(.fleet.cluster.render.dir)"

define .yaml.comma-join =
$(subst $(space),$1,$(strip $2))
endef

define .yaml.rangeOf =
[ $(call .yaml.comma-join,$(comma)$(newline),$(foreach value,$(1),"$(value)")) ]
endef 

define .Kustomization.file.content =
$(warning generating Kustomization content for $(1))
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: $(call .yaml.rangeOf,$(1))
endef

define .cluster.overlays.kustomize = 
	: "[kpt] Writing overlays Kustomization for cluster $(.fleet.cluster.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - ../catalog" >> "$(1)"
endef

define .cluster.kustomize = 
	: "[kpt] Writing cluster Kustomization for $(.fleet.cluster.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - catalog" >> "$(1)"
	echo "  - overlays" >> "$(1)"
endef

$(.fleet.cluster.overlays.Kustomization.file):
	$(call .cluster.overlays.kustomize,$@)

$(.fleet.cluster.Kustomization.file): $(.fleet.cluster.overlays.Kustomization.file)
$(.fleet.cluster.Kustomization.file):
	$(call .cluster.kustomize,$@)

# Catalog packages and Kustomizations are now managed in the fetched catalog directory

# ----------------------------------------------------------------------------
# Fleet subtree synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: remote@kpt finalize-merge@kpt check-clean@kpt pull@kpt push@kpt

remote@kpt:
	@if ! git remote get-url "$(.fleet.git.remote)" >/dev/null 2>&1; then
		git remote add "$(.fleet.git.remote)" git@github.com:nxmatic/fleet-manifests.git
	fi

finalize-merge@kpt:
	@if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		if git diff --name-only --diff-filter=U | grep -q .; then
			echo "Merge in progress with unresolved conflicts; resolve before continuing." >&2
			exit 1
		fi
		: "Completing pending fleet subtree merge..."
		GIT_MERGE_AUTOEDIT=no git commit --no-edit --quiet
	fi

check-clean@kpt:
	@if ! git diff --quiet -- "$(.fleet.git.subtree.dir)"; then
		echo "Uncommitted changes detected inside $(.fleet.git.subtree.dir)." >&2
		exit 1
	fi
	untracked="$$(git ls-files --others --exclude-standard -- "$(_.fleet.git.subtree.dir)")"
	if [ -n "$$untracked" ]; then
		echo "Untracked files detected inside $(.fleet.git.subtree.dir)." >&2
		echo "Files:" >&2
		echo "$$untracked" >&2
		exit 1
	fi

pull@kpt: remote@kpt finalize-merge@kpt check-clean@kpt
	git fetch --prune "$(.fleet.git.remote)" "$(.fleet.git.branch)"
	git subtree pull --prefix="$(.fleet.git.subtree.dir)" "$(.fleet.git.remote)" "$(.fleet.git.branch)" --squash

push@kpt: remote@kpt check-clean@kpt
	@split_sha="$$(git subtree split --prefix="$(_.fleet.git.subtree.dir)" HEAD)"
	remote_sha="$$(git ls-remote --heads "$(_.fleet.git.remote)" "$(_.fleet.git.branch)" | awk '{print $$1}')" || true
	if [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then
		: "No new fleet revisions to push; skipping."
	else
		git subtree push --prefix="$(.fleet.git.subtree.dir)" "$(.fleet.git.remote)" "$(.fleet.git.branch)"
	fi

endif # make.d/kpt/rules.mk guard
