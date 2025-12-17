# kpt/rules.mk - KPT package catalog and fleet manifests management (@codebase)

# Trace system for kpt operations (@codebase)
ifeq ($(true),$(.trace.kpt))
override kpt.trace = $(warning [kpt] $(1) $(if $(2),($(foreach var,$(2),$(var)=$($(var)))),(no vars)))
kpt.is-trace := $(true)
kpt.if-trace = $(1)
$(call kpt.trace,enabling kpt-level trace)
else
kpt.is-trace := $(false)
kpt.if-trace = $(2)
endif
# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/kpt/rules.mk

-include make.d/make.mk

# KPT catalog configuration (@codebase)


# Fleet render configuration (@codebase)


.kpt.name := $(cluster.name)
.kpt.dir := $(rke2-subtree.dir)/$(.kpt.name)
.kpt.catalog.dir := $(.kpt.dir)/catalog
.kpt.overlays.dir := $(.kpt.dir)/overlays
.kpt.overlays.Kustomization.file := $(.kpt.overlays.dir)/Kustomization
.kpt.Kustomization.file := $(.kpt.dir)/Kustomization
.kpt.render.dir := $(tmp-dir)/fleet/$(.kpt.name)
.kpt.manifests.file := $(.kpt.dir)/manifests.yaml
.kpt.manifests.dir := $(.kpt.dir)/manifests.d

.kpt.catalog.names = $(notdir $(patsubst %/,%,$(dir $(wildcard $(.kpt.catalog.dir)/*/Kptfile))))
.kpt.package.aux_files := .gitattributes .krmignore

export CLUSTER_MANIFESTS_DIR := $(realpath $(.kpt.manifests.dir))
# List of namespaces to extract from rendered manifests
define .kpt.require-bin
	if ! command -v $(1) >/dev/null 2>&1; then \
		echo "[fleet] Missing required command $(1)"; \
		exit 1; \
	fi
endef

# ----------------------------------------------------------------------------
# Catalog Kustomization management (@codebase)
# ----------------------------------------------------------------------------

.PHONY: update-kustomizations@kpt

update-kustomizations@kpt: check-tools@kpt
update-kustomizations@kpt: render.dir := $(tmp-dir)/catalog
update-kustomizations@kpt: ## Update Kustomization files from rendered catalog packages
	: "[kpt] Staging and rendering catalog to generate Kustomizations"
	rm -fr "$(render.dir)"
	kpt fn render --truncate-output=false "$(.kpt.catalog.dir)" -o "$(render.dir)"
	: "[kpt] Generating Kustomizations from rendered packages"
	for layer in "$(render.dir)"/*/; do
		[ -d "$$layer" ] || continue
		layer_name=$$(basename "$$layer")
		for pkg in "$$layer"/*/; do
			pkg=$$(realpath "$$pkg")
			[ -d "$$pkg" ] || continue
			pkg_name=$$(basename "$$pkg")
			: "[kpt] Generating Kustomization for $$layer_name/$$pkg_name"
			pushd "$$pkg" > /dev/null
			kustomize create \
				--autodetect \
				--recursive \
				--annotations "kpt.dev/package-layer:$$layer_name,kpt.dev/package-name:$$pkg_name"
			popd > /dev/null
			source_pkg="$(.kpt.catalog.dir)/$$layer_name/$$pkg_name"
			: "[kpt] Copying Kustomization back to $$source_pkg"
			cp "$$pkg/kustomization.yaml" "$$source_pkg/Kustomization"
		done
	done

# ----------------------------------------------------------------------------
# Rendering pipeline (@codebase)
# ----------------------------------------------------------------------------

.PHONY: render@kpt check-tools@kpt prepare@kpt

render@kpt: check-tools@kpt prepare@kpt $(.kpt.overlays.Kustomization.file) $(.kpt.Kustomization.file)
render@kpt: $(.kpt.manifests.file)  ## Render catalog via kpt, aggregate via kustomize (@codebase)

$(.kpt.render.dir):
	$(call kpt.trace,Rendering catalog for cluster $(.kpt.name) via kpt fn render)
	rm -rf "$(@)"
	kpt fn render --truncate-output=false "$(.kpt.catalog.dir)" -o "$(@)"

.FORCE: $(.kpt.render.dir)

$(.kpt.manifests.file): $(.kpt.Kustomization.file)
$(.kpt.manifests.file): $(.kpt.render.dir)
$(.kpt.manifests.file):
	$(call kpt.trace,Copying Kustomization files to rendered output)
	rsync -a --include='*/' --include='Kustomization' --exclude='*' "$(.kpt.catalog.dir)/" "$(.kpt.render.dir)/"
	$(call kpt.trace,Building manifests for cluster $(.kpt.name) via kustomize build)
	kustomize build "$(.kpt.render.dir)" > "$@"

.PHONY: clean-render@kpt
clean-render@kpt: ## Clean rendered temporary directory
	rm -rf "$(.kpt.render.dir)"

# ----------------------------------------------------------------------------
# Resource categorization and reparenting (@codebase)
# ----------------------------------------------------------------------------

## Reparent resources by scope: cluster/, namespaces/<ns>/, customresourcedefinitions/

# yq expressions for resource selection (reusable for future patterns)
define .kpt.yq.select.crd =
select(.kind == "CustomResourceDefinition")
endef

define .kpt.yq.select.cluster =
select(.metadata.namespace == null or .metadata.namespace == "") |
select(.kind != "CustomResourceDefinition" and .kind != "Namespace")
endef

define .kpt.yq.select.namespace =
select(.metadata.namespace != null and .metadata.namespace != "") |
select(.kind != "Namespace")
endef

.SECONDEXPANSION:

split-manifests@kpt: $(.kpt.manifests.dir)
split-manifests@kpt: ## Split rendered manifests into categorized directory structure

define .kpt.namespaces =
$(shell yq eval -N -r 'select(.kind == "Namespace") | (.metadata.name|downcase)' "$(.kpt.manifests.file)" 2>/dev/null)
endef

$(.kpt.manifests.dir): check-tools@kpt
$(.kpt.manifests.dir): prepare@kpt
$(.kpt.manifests.dir): $(.kpt.manifests.file)
$(.kpt.manifests.dir): $(.kpt.manifests.dir)/
$(.kpt.manifests.dir): manifest.file = $(realpath $(.kpt.manifests.file))
$(.kpt.manifests.dir): manifest.dir = $(realpath $(.kpt.manifests.dir))
$(.kpt.manifests.dir): $$(foreach ns,$$(.kpt.namespaces),$$(.kpt.manifests.dir)/$$(ns))
$(.kpt.manifests.dir):
	: "[kpt] Extracting CustomResourceDefinitions"
	cd "$(manifest.dir)"
	yq --split-exp='"crd-"+(.metadata.name|downcase)' \
		eval-all 'select(.kind == "CustomResourceDefinition")' "$(manifest.file)" 2>/dev/null
	: "[kpt] Generating namespaces.mk"
	mkdir -p "$(.kpt.dir)/make.d"
	{ \
		echo "# Generated namespace extraction rules"; \
		echo ""; \
		for ns in $$(yq eval -N -r 'select(.kind == "Namespace") | (.metadata.name|downcase)' "$(manifest.file)" 2>/dev/null); do \
			echo "$(.kpt.manifests.dir)/$$ns: $(.kpt.manifests.dir)/"; \
			echo "	: 'Extracting namespace $$ns'"; \
			echo "	mkdir -p \$$(@)"; \
			echo "	cd \$$(@D)"; \
			echo "	yq --split-exp='.metadata.name|downcase' \\"; \
			echo "		eval-all 'select(.kind == \"Namespace\" and .apiVersion == \"v1\" and .metadata.name == \"$$ns\")' \\"; \
			echo "		$(.kpt.manifests.file)"; \
			echo ""; \
			for res in $$(yq eval -N -r "select(.metadata.namespace == \"$$ns\") | (.kind | downcase) + \"-\" + (.metadata.name | downcase)" "$(manifest.file)" 2>/dev/null); do \
				echo "$(.kpt.manifests.dir)/$$ns/$$res.yaml: $(.kpt.manifests.dir)/$$ns"; \
				echo "	: 'Extracting $$res in namespace $$ns'"; \
				echo "	cd \$$(@D)"; \
				echo "	yq --split-exp='(.kind|downcase)+\"-\"+(.metadata.name|downcase)' \\"; \
				echo "		eval-all 'select(.metadata.namespace == \"$$ns\")' \\"; \
				echo "		$(.kpt.manifests.file)"; \
				echo ""; \
			done; \
		done; \
	} > "$(.kpt.dir)/make.d/namespaces.mk"
	: "[kpt] Split rendered manifests into categorized directories"

-include $(.kpt.dir)/make.d/namespaces.mk

# ----------------------------------------------------------------------------

check-tools@kpt: # Ensure required CLI tools are available
	$(call .kpt.require-bin,kpt)
	$(call .kpt.require-bin,kustomize)
	$(call .kpt.require-bin,yq)
	$(call kpt.trace,Rendering cluster $(.kpt.name))

prepare@kpt: # Fetch or update the cluster catalog
	$(call kpt.trace,Preparing cluster $(.kpt.name) catalog via kpt pkg get/update)
	mkdir -p "$(.kpt.dir)"
	if [[ ! -d "$(.kpt.catalog.dir)" ]]; then \
		kpt pkg get "$(realpath $(top-dir)).git/kpt/catalog" "$(.kpt.catalog.dir)"; \
	else \
		kpt pkg update "$(.kpt.catalog.dir)@main"; \
	fi
	rm -f "$(.kpt.manifests.file)"
	mkdir -p "$(.kpt.overlays.dir)"

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
	: "[kpt] Writing overlays Kustomization for cluster $(.kpt.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - ../catalog" >> "$(1)"
endef

define .cluster.kustomize = 
	: "[kpt] Writing cluster Kustomization for $(.kpt.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - catalog" >> "$(1)"
	echo "  - overlays" >> "$(1)"
endef

$(.kpt.overlays.Kustomization.file):
	$(call .cluster.overlays.kustomize,$@)

$(.kpt.Kustomization.file): $(.kpt.overlays.Kustomization.file)
$(.kpt.Kustomization.file):
	$(call .cluster.kustomize,$@)

# Catalog packages and Kustomizations are now managed in the fetched catalog directory

# ----------------------------------------------------------------------------
# Fleet subtree synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: remote@kpt finalize-merge@kpt check-clean@kpt pull@kpt push@kpt

remote@kpt:
	@if ! git remote get-url "$(rke2-subtree.git.remote)" >/dev/null 2>&1; then
		git remote add "$(rke2-subtree.git.remote)" git@github.com:nxmatic/fleet-manifests.git
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
	@if ! git diff --quiet -- "$(rke2-subtree.git.subtree.dir)"; then
		echo "Uncommitted changes detected inside $(rke2-subtree.git.subtree.dir)." >&2
		exit 1
	fi
	untracked="$$(git ls-files --others --exclude-standard -- "$(rke2-subtree.git.subtree.dir)")"
	if [ -n "$$untracked" ]; then
		echo "Untracked files detected inside $(rke2-subtree.git.subtree.dir)." >&2
		echo "Files:" >&2
		echo "$$untracked" >&2
		exit 1
	fi

pull@kpt: remote@kpt finalize-merge@kpt check-clean@kpt
	git fetch --prune "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)"
	git subtree pull --prefix="$(rke2-subtree.git.subtree.dir)" "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)" --squash

push@kpt: remote@kpt check-clean@kpt
	@split_sha="$$(git subtree split --prefix="$(rke2-subtree.git.subtree.dir)" HEAD 2>/dev/null || \
		git rev-parse --verify "$(rke2-subtree.git.branch)" 2>/dev/null || true)"
	remote_sha="$$(git ls-remote --heads "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)" | \
		awk '{print $$1}')" || true
	if [ -z "$$split_sha" ]; then
		echo "No fleet subtree revisions found to push." >&2
		exit 0
	elif [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then
		: "No new fleet revisions to push; skipping."
	else
		git subtree push --prefix="$(rke2-subtree.git.subtree.dir)" \
		  "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)"
	fi

endif # make.d/kpt/rules.mk guard
