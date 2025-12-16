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
.fleet.cluster.packages.dir := $(.fleet.git.subtree.dir)/clusters/$(.fleet.cluster.name)/packages
.fleet.cluster.Kustomization.file := $(.fleet.cluster.packages.dir)/Kustomization
.fleet.cluster.manifests.file := $(.fleet.git.subtree.dir)/clusters/$(.fleet.cluster.name)/manifests.yaml

.fleet.packages.dir := $(.fleet.git.subtree.dir)/packages

.fleet.packages.names = $(notdir $(patsubst %/,%,$(dir $(wildcard $(.fleet.packages.dir)/*/Kptfile))))
.fleet.packages.rendered.paths = $(foreach pkg,$(.fleet.packages.names),$(.fleet.cluster.packages.dir)/$(pkg))
.fleet.packages.tstamps = $(foreach path,$(.fleet.packages.rendered.paths),$(path)/.tstamp)
.fleet.packages.rendered.kustomizations = $(foreach pkg,$(.fleet.packages.names),$(.fleet.cluster.packages.dir)/$(pkg)/Kustomization)
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
	: "[fleet] Rendering cluster $(.fleet.cluster.name) (packages: $(.fleet.packages.names))"

prepare@fleet: git.repo := https://github.com/nxmatic/incus-rke2-cluster.git
prepare@fleet:
	: "[fleet] Preparing packages $(system.packages.names) for cluster $(.fleet.cluster.name)"
	if [[ ! -d "$(.fleet.packages.dir)" ]]; then
	  kpt pkg get "$(git.repo)/kpt/catalog/system" "$(.fleet.git.subtree.dir)"
	  mv $(.fleet.git.subtree.dir)/system "$(.fleet.packages.dir)"
	else
	  kpt pkg update "$(.fleet.packages.dir)"
	fi
	rm -f "$(.fleet.cluster.manifests.file)"
	rm -rf "$(.fleet.cluster.packages.dir)"
	mkdir -p "$(.fleet.cluster.packages.dir)"

$(.fleet.cluster.manifests.file): $(.fleet.cluster.Kustomization.file) 
$(.fleet.cluster.manifests.file): $(.fleet.packages.tstamps)
$(.fleet.cluster.manifests.file):
	kustomize build "$(.fleet.git.subtree.dir)/clusters/$(.fleet.cluster.name)" > "$@"

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

define .cluster.kustomize = 
	: "[fleet] Writing Kustomization for cluster $(.fleet.cluster.name)"
	echo "$(call .Kustomization.file.content,$(.fleet.packages.names))" > "$(1)"
endef

$(.fleet.cluster.Kustomization.file): $(.fleet.packages.rendered.kustomizations)
$(.fleet.cluster.Kustomization.file): 
	$(call .cluster.kustomize,$@)

$(.fleet.packages.tstamps): $(.fleet.cluster.packages.dir)/%/.tstamp: $(.fleet.packages.dir)/%
	src="$(.fleet.packages.dir)/$*"
	dst="$(@D)"
	: "[fleet] kpt fn render  $${src} to $${dst}"
	rm -fr "$${dst}"
	kpt fn render --truncate-output=false "$${src}" -o "$${dst}"
	for aux in $(.fleet.package.aux_files); do
		if [ -f "$${src}/$$aux" ]; then
			cp "$${src}/$$aux" "$${dst}/$$aux"
		fi
	done
	touch "$@"


define .package.resources =
$(warning gathering resources for package $(1))
$(notdir $(wildcard $(1)/*.yaml))
endef

define .package.kustomize =
	: "[fleet] Writing Kustomization for package '$(1)'"
	echo "$(call .Kustomization.file.content,$(call .package.resources,$(1)))" > "$(2)"
endef

$(.fleet.packages.rendered.kustomizations): $(.fleet.cluster.packages.dir)/%/Kustomization: $(.fleet.cluster.packages.dir)/%/.tstamp
	$(call .package.kustomize,$(@D),$(@))

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
