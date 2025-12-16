# fleet/rules.mk - Fleet manifests subtree helpers (@codebase)
# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/fleet/rules.mk

-include make.d/make.mk

# Fleet render configuration (@codebase)

system.packages.dir := $(top-dir)/kpt/system
system.packages.names = $(notdir $(patsubst %/,%,$(dir $(wildcard $(system.packages.dir)/*/Kptfile))))

.fleet.git.remote ?= fleet
.fleet.git.branch ?= rke2-subtree
.fleet.git.subtree.dir ?= $(top-dir)/fleet

.fleet.cluster.name := $(cluster.NAME)
.fleet.cluster.dir := $(.fleet.git.subtree.dir)/clusters/$(.fleet.cluster.name)
.fleet.cluster.packages.dir := $(.fleet.cluster.dir)/packages
.fleet.cluster.packages.Kustomization.file := $(.fleet.cluster.packages.dir)/Kustomization
.fleet.cluster.overlays.dir := $(.fleet.cluster.dir)/overlays
.fleet.cluster.overlays.Kustomization.file := $(.fleet.cluster.overlays.dir)/Kustomization
.fleet.cluster.Kustomization.file := $(.fleet.cluster.dir)/Kustomization
.fleet.cluster.manifests.file := $(.fleet.cluster.dir)/manifests.yaml

.fleet.packages.source.dir := $(top-dir)/kpt/catalog/system
.fleet.cluster.packages.names = $(notdir $(patsubst %/,%,$(dir $(wildcard $(.fleet.cluster.packages.dir)/*/Kptfile))))
.fleet.cluster.packages.rendered.kustomizations = $(foreach pkg,$(.fleet.cluster.packages.names),$(.fleet.cluster.packages.dir)/$(pkg)/Kustomization)
.fleet.package.aux_files := .gitattributes .krmignore

define .fleet.require-bin
	@if ! command -v $(1) >/dev/null 2>&1; then
		: "[fleet] Missing required command $(1)"
		exit 1
	fi
endef

# ----------------------------------------------------------------------------
# Rendering pipeline (@codebase)
# ----------------------------------------------------------------------------

.PHONY: render@fleet check-tools@fleet prepare@fleet

render@fleet: check-tools@fleet prepare@fleet
render@fleet: $(.fleet.cluster.manifests.file)
render@fleet:  ## Render Fleet packages via kpt fn render + kustomize (@codebase)
	: "[fleet] wrote manifests to $(.fleet.cluster.manifests.file)"

check-tools@fleet:
	$(call .fleet.require-bin,kpt)
	$(call .fleet.require-bin,kustomize)
	: "[fleet] Rendering cluster $(.fleet.cluster.name)"

prepare@fleet: git.repo := https://github.com/nxmatic/incus-rke2-cluster.git
prepare@fleet:
	: "[fleet] Preparing cluster $(.fleet.cluster.name) packages via kpt pkg get"
	mkdir -p "$(.fleet.cluster.dir)"
	if [[ ! -d "$(.fleet.cluster.packages.dir)" ]]; then
	  kpt pkg get "$(git.repo)/kpt/catalog/system" "$(.fleet.cluster.packages.dir)"
	else
	  : "[fleet] Cluster packages already exist; use 'kpt pkg update' to refresh"
	fi
	rm -f "$(.fleet.cluster.manifests.file)"
	mkdir -p "$(.fleet.cluster.overlays.dir)"

$(.fleet.cluster.manifests.file): $(.fleet.cluster.Kustomization.file)
$(.fleet.cluster.manifests.file):
	kustomize build "$(.fleet.cluster.dir)" > "$@"

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

define .packages.kustomize = 
	: "[fleet] Writing packages Kustomization for cluster $(.fleet.cluster.name)"
	echo "$(call .Kustomization.file.content,$(.fleet.cluster.packages.names))" > "$(1)"
endef

define .cluster.overlays.kustomize = 
	: "[fleet] Writing overlays Kustomization for cluster $(.fleet.cluster.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - ../packages" >> "$(1)"
endef

define .cluster.kustomize = 
	: "[fleet] Writing cluster Kustomization for $(.fleet.cluster.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - packages" >> "$(1)"
	echo "  - overlays" >> "$(1)"
endef

$(.fleet.cluster.packages.Kustomization.file): $(.fleet.cluster.packages.rendered.kustomizations)
$(.fleet.cluster.packages.Kustomization.file):
	$(call .packages.kustomize,$@)

$(.fleet.cluster.overlays.Kustomization.file): $(.fleet.cluster.packages.Kustomization.file)
$(.fleet.cluster.overlays.Kustomization.file):
	$(call .cluster.overlays.kustomize,$@)

$(.fleet.cluster.Kustomization.file): $(.fleet.cluster.packages.Kustomization.file) $(.fleet.cluster.overlays.Kustomization.file)
$(.fleet.cluster.Kustomization.file):
	$(call .cluster.kustomize,$@)

define .package.resources =
$(warning gathering resources for package $(1))
$(notdir $(wildcard $(1)/*.yaml))
endef

define .package.kustomize =
	: "[fleet] Writing Kustomization for package '$(notdir $(1))'"
	echo "$(call .Kustomization.file.content,$(call .package.resources,$(1)))" > "$(2)"
endef

$(.fleet.cluster.packages.rendered.kustomizations): $(.fleet.cluster.packages.dir)/Kptfile
$(.fleet.cluster.packages.rendered.kustomizations):
	: "[fleet] Rendering all packages for cluster $(.fleet.cluster.name)"
	kpt fn render --truncate-output=false "$(.fleet.cluster.packages.dir)"
	$(foreach pkg,$(.fleet.cluster.packages.names),$(call .package.kustomize,$(.fleet.cluster.packages.dir)/$(pkg),$(.fleet.cluster.packages.dir)/$(pkg)/Kustomization)$(newline))

# ----------------------------------------------------------------------------
# Fleet subtree synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: remote@fleet finalize-merge@fleet check-clean@fleet pull@fleet push@fleet

remote@fleet:
	@if ! git remote get-url "$(.fleet.git.remote)" >/dev/null 2>&1; then
		git remote add "$(.fleet.git.remote)" git@github.com:nxmatic/fleet-manifests.git
	fi

finalize-merge@fleet:
	@if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		if git diff --name-only --diff-filter=U | grep -q .; then
			echo "Merge in progress with unresolved conflicts; resolve before continuing." >&2
			exit 1
		fi
		: "Completing pending fleet subtree merge..."
		GIT_MERGE_AUTOEDIT=no git commit --no-edit --quiet
	fi

check-clean@fleet:
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

pull@fleet: remote@fleet finalize-merge@fleet check-clean@fleet
	git fetch --prune "$(.fleet.git.remote)" "$(.fleet.git.branch)"
	git subtree pull --prefix="$(.fleet.git.subtree.dir)" "$(.fleet.git.remote)" "$(.fleet.git.branch)" --squash

push@fleet: remote@fleet check-clean@fleet
	@split_sha="$$(git subtree split --prefix="$(_.fleet.git.subtree.dir)" HEAD)"
	remote_sha="$$(git ls-remote --heads "$(_.fleet.git.remote)" "$(_.fleet.git.branch)" | awk '{print $$1}')" || true
	if [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then
		: "No new fleet revisions to push; skipping."
	else
		git subtree push --prefix="$(.fleet.git.subtree.dir)" "$(.fleet.git.remote)" "$(.fleet.git.branch)"
	fi

endif # make.d/fleet/rules.mk guard
