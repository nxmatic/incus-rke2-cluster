# kpt/rules.mk - KPT package catalog and manifests management (@codebase)

# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/kpt/rules.mk

-include make.d/make.mk

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

# KPT catalog configuration (@codebase)

.kpt.dir := $(rke2-subtree.dir)/$(cluster.name)
.kpt.catalog.dir := $(.kpt.dir)/catalog
.kpt.overlays.dir := $(.kpt.dir)/overlays
.kpt.overlays.Kustomization.file := $(.kpt.overlays.dir)/Kustomization
.kpt.Kustomization.file := $(.kpt.dir)/Kustomization
.kpt.render.dir := $(tmp-dir)/catalog/$(cluster.name)
.kpt.local.render.dir := $(rke2-subtree.dir)/$(cluster.name)/.local.d
.kpt.manifests.file := $(.kpt.dir)/manifests.yaml
.kpt.manifests.dir := $(.kpt.dir)/manifests.d

.kpt.package.aux_files := .gitattributes .krmignore

export CLUSTER_MANIFESTS_DIR := $(realpath $(.kpt.manifests.dir))

define .kpt.require-bin
	if ! command -v $(1) >/dev/null 2>&1; then
		echo "[fleet] Missing required command $(1)";
		exit 1;
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

$(.kpt.render.dir): clean-render@kpt
$(.kpt.render.dir):
	$(call kpt.trace,Rendering catalog for cluster $(cluster.name) via kpt fn render)
	kpt fn render --truncate-output=false "$(.kpt.catalog.dir)" -o "$(@)"

.FORCE: $(.kpt.render.dir)

$(.kpt.manifests.file): check-tools@kpt
$(.kpt.manifests.file): prepare@kpt
$(.kpt.manifests.file): $(.kpt.Kustomization.file)
$(.kpt.manifests.file): $(.kpt.render.dir)
$(.kpt.manifests.file):
	$(call kpt.trace,Copying Kustomization files to rendered output)
	rsync -a --include='*/' --include='Kustomization' --exclude='*' "$(.kpt.catalog.dir)/" "$(.kpt.render.dir)/"
	$(call kpt.trace,Building manifests for cluster $(cluster.name) via kustomize build)
	kustomize build "$(.kpt.render.dir)" > "$@"


# ----------------------------------------------------------------------------
# Resource categorization and reparenting (@codebase)
# ----------------------------------------------------------------------------

$(.kpt.manifests.dir): $(.kpt.manifests.file)
$(.kpt.manifests.dir): $(.kpt.manifests.dir)/
$(.kpt.manifests.dir): manifests.file = ../manifests.yaml
$(.kpt.manifests.dir): 
	cd $(.kpt.manifests.dir)
	yq --split-exp='$(call .kpt.toFilePath,00)' \
		eval-all 'select(.kind == "CustomResourceDefinition")' \
		"$(manifests.file)"
	: 'Extracting cluster-scoped resources for package $(pkg)'
	yq --split-exp='$(call .kpt.toFilePath,01)' \
		eval-all 'select(.kind != "CustomResourceDefinition" and
					     (.metadata.namespace == null or .metadata.namespace == ""))' \
		"$(manifests.file)"
	: 'Extracting namespace-scoped resources for package $(pkg)'
	yq --split-exp='$(call .kpt.toFilePath,02)' \
		eval-all 'select(.metadata.namespace != null and .metadata.namespace != "")' \
		"$(manifests.file)"

define .kpt.toFilePath =
((.metadata.annotations["kpt.dev/package-layer"] // "default") + "/" + (.metadata.annotations["kpt.dev/package-name"] // "unknown") + "/" + "$(strip $(1))-" + (.kind | downcase) + "-" + (.metadata.name | downcase) + ".yml")
endef

define .kpt.isOwnedByPackage =
.metadata.annotations."kpt.dev/package-name" == "$(pkg)"
endef

unwrap@kpt: $(.kpt.manifests.dir)
unwrap@kpt: ## Unwrap rendered manifests into categorized directory structure
	: "[kpt] Unwrapped rendered manifests into categorized directories"

clean-manifests@kpt: ## Clean categorized manifests directory
	rm -fr $(.kpt.manifests.dir)

# ----------------------------------------------------------------------------

check-tools@kpt: # Ensure required CLI tools are available
	$(call .kpt.require-bin,kpt)
	$(call .kpt.require-bin,kustomize)
	$(call .kpt.require-bin,yq)
	$(call kpt.trace,Rendering cluster $(cluster.name))

prepare@kpt: $(.kpt.dir)/
prepare@kpt: $(.kpt.overlays.dir)/
prepare@kpt: clean-render@kpt update@kpt
prepare@kpt: # Fetch or update the cluster catalog
	: "[kpt] Catalog updated from upstream"

.PHONY: clean-render@kpt
clean-render@kpt: ## Clean rendered temporary directory
	rm -rf "$(.kpt.render.dir)"

.PHONY: render-pkg@kpt
render-pkg@kpt: ## Development target: render a specific package to .local.d for inspection. Usage: make render-pkg@kpt PKG=system/porch
	@: "[kpt] Rendering package $(PKG) to .local.d for inspection"
	@mkdir -p "$(.kpt.local.render.dir)"
	kpt fn render "$(rke2-subtree.dir)/$(cluster.name)/catalog/$(PKG)" -o "$(.kpt.local.render.dir)/$(PKG)" --truncate-output=false

.PHONY: clean-local-render@kpt
clean-local-render@kpt: ## Clean local development render directory
	rm -rf "$(.kpt.local.render.dir)"

update@kpt: ## Update cluster catalog via kpt pkg get/update
	$(call kpt.trace,Updating cluster $(cluster.name) catalog via kpt pkg get/update)
	if git diff --quiet -- kpt/catalog rke2-subtree/bioskop/catalog &&
	   git diff --cached --quiet -- kpt/catalog rke2-subtree/bioskop/catalog &&
	   ! git ls-files --others --exclude-standard -- kpt/catalog rke2-subtree/bioskop/catalog | grep -q .; then
		if [[ ! -d "$(.kpt.catalog.dir)" ]]; then
			kpt pkg get "$(realpath $(top-dir)).git/kpt/catalog" "$(.kpt.catalog.dir)"
		else
			kpt pkg update "$(.kpt.catalog.dir)@main" --strategy resource-merge
		fi
	else
		echo "[kpt] ERROR: kpt/catalog or rke2-subtree/bioskop/catalog has uncommitted changes"
		echo "[kpt] Commit or discard changes before running update@kpt"
		exit 1
	fi

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
	: "[kpt] Writing overlays Kustomization for cluster $(cluster.name)"
	echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$(1)"
	echo "kind: Kustomization" >> "$(1)"
	echo "resources:" >> "$(1)"
	echo "  - ../catalog" >> "$(1)"
endef

define .cluster.kustomize = 
	: "[kpt] Writing cluster Kustomization for $(cluster.name)"
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
