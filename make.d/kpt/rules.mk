# rules.mk - KPT package catalog and manifests management (@codebase)

# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/kpt/rules.mk

make.d/kpt/rules.mk := make.d/kpt/rules.mk  # guard to allow safe re-inclusion (@codebase)

-include make.d/make.mk

-include make.d/network/rules.mk

# KPT catalog configuration (@codebase)
.kpt.dir := $(rke2-subtree.dir)/$(cluster.name)
.kpt.upstream.repo := $(realpath $(top-dir))
.kpt.upstream.dir := catalog
.kpt.catalog.dir := $(.kpt.dir)/catalog
.kpt.overlays.dir := $(.kpt.dir)/overlays
.kpt.overlays.Kustomization.file := $(.kpt.overlays.dir)/Kustomization
.kpt.Kustomization.file := $(.kpt.dir)/Kustomization
.kpt.render.dir := $(tmp-dir)/catalog/$(cluster.name)
.kpt.render.cmd := env PATH=$(realpath $(.kpt.catalog.dir)/bin):$(PATH) kpt fn render --allow-exec --truncate-output=false
.kpt.manifests.file := $(.kpt.dir)/manifests.yaml
.kpt.manifests.dir  := $(.kpt.dir)/manifests.d
.kpt.package.aux_files := .gitattributes .krmignore

define .kpt.require-bin
	if ! command -v $(1) >/dev/null 2>&1; then
		echo "[kpt] Missing required command $(1)";
		exit 1;
	fi
endef

# ----------------------------------------------------------------------------
# Catalog Kustomization management (@codebase)
# ----------------------------------------------------------------------------

.PHONY: update-kustomizations@kpt

update-kustomizations@kpt: $(.kpt.render.dir)
update-kustomizations@kpt: ## Update Kustomization files from rendered catalog packages
	: "[kpt] Generating Kustomizations from rendered packages"
	for layer in "$(.kpt.render.dir)"/*/; do
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

$(.kpt.render.dir): $(.network.plan.file)
$(.kpt.render.dir): $(.kpt.catalog.dir)
$(.kpt.render.dir): | $(.kpt.render.dir)/
$(.kpt.render.dir):
	: "Rendering catalog for cluster $(cluster.name) via kpt fn render"
	rm -fr $(.kpt.render.dir)
	env PATH=$(realpath $(.kpt.catalog.dir)/bin):$(PATH) kpt fn render --allow-exec --truncate-output=false "$(.kpt.catalog.dir)" -o "$(@)"

$(.kpt.manifests.file): $(.kpt.Kustomization.file)
$(.kpt.manifests.file): $(.kpt.render.dir)
$(.kpt.manifests.file):
	: "Copying Kustomization files to rendered output"
	rsync -a --include='*/' --include='Kustomization' --exclude='*' "$(.kpt.catalog.dir)/" "$(.kpt.render.dir)/"
	: "Building manifests for cluster $(cluster.name) via kustomize build"
	kustomize build "$(.kpt.render.dir)" > "$@"


# ----------------------------------------------------------------------------
# Resource categorization and reparenting (@codebase)
# ----------------------------------------------------------------------------

$(.kpt.manifests.dir): $(.kpt.manifests.file)
$(.kpt.manifests.dir): | $(.kpt.manifests.dir)/
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

.PHONY: rke2-manifests@kpt clean-rke2-manifests@kpt

rke2-manifests@kpt: prepare@kpt
rke2-manifests@kpt: $(.kpt.manifests.dir)
rke2-manifests@kpt: ## Unwrap rendered manifests into categorized directory structure
	: "[kpt] Unwrapped rendered manifests into $(.kpt.manifests.dir)"

clean-rke2-manifests@kpt: ## Clean categorized manifests directory
	rm -fr $(.kpt.manifests.dir)

# ----------------------------------------------------------------------------

.PHONY: prepare@kpt


prepare@kpt: | $(.kpt.dir)/ $(.kpt.overlays.dir)/
prepare@kpt: update@kpt
prepare@kpt: # Fetch or update the cluster catalog
	: "[kpt] Catalog updated from upstream"

.PHONY: clean-render@kpt
clean-render@kpt: ## Clean rendered temporary directory
	rm -rf "$(.kpt.render.dir)"


update@kpt: | $(.kpt.catalog.dir)
update@kpt: update-guard@kpt
update@kpt: ## Update cluster catalog via kpt pkg get/update
	: "Updating cluster $(cluster.name) catalog via kpt pkg get/update)"
	kpt pkg update "$(.kpt.catalog.dir)@main" --strategy resource-merge

update-guard@kpt: ## Guard target to ensure catalog directory exists
	: "Ensuring catalog directory exists for cluster $(cluster.name)"
	if ! git diff --quiet -- catalog $(.kpt.catalog.dir) ||
	   ! git diff --cached --quiet -- catalog $(rke2-subtree.git.subtree.dir) ||
	   git ls-files --others --exclude-standard -- catalog $(rke2-subtree.git.subtree.dir) | grep -q .; then
		echo "[kpt] ERROR: catalog or rke2-subtree/bioskop/catalog has uncommitted changes"
		echo "[kpt] Commit or discard changes before running update@kpt"
		exit 1
	fi

$(.kpt.catalog.dir): ## Ensure cluster catalog directory exists and is updated
	: "[kpt] Ensuring cluster catalog directory is updated"
	kpt pkg get "$(.kpt.upstream.repo).git/${.kpt.upstream.dir}" "$(.kpt.dir)"

# --- Kustomization file generation (@codebase) ------------------------------------

define .Kustomization.file.content =
$(warning generating Kustomization content for $(1))
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: $(call .kpt.yaml.rangeOf,$(1))
endef

define .kpt.yaml.comma-join =
$(subst $(space),$1,$(strip $2))
endef

define .kpt.yaml.rangeOf =
[ $(call .kpt.yaml.comma-join,$(comma)$(newline),$(foreach value,$(1),"$(value)")) ]
endef 

define .cluster.kustomize.content = 
	apiVersion: kustomize.config.k8s.io/v1beta1
	kind: Kustomization
	resources:
	- catalog
	- overlays
endef

$(.kpt.overlays.Kustomization.file): | $(dir $(.kpt.overlays.Kustomization.file))/
$(.kpt.overlays.Kustomization.file):
	$(file >$(@), $(.cluster.overlays.kustomize.content))

define .cluster.overlays.kustomize.content = 
	apiVersion: kustomize.config.k8s.io/v1beta1
	kind: Kustomization
	resources:
	- ../catalog
endef

$(.kpt.Kustomization.file): $(.kpt.overlays.Kustomization.file)
$(.kpt.Kustomization.file): $(.kpt.overlays.dir)/
$(.kpt.Kustomization.file):
	$(file >$(@), $(.cluster.kustomize.content))

# ----------------------------------------------------------------------------
# rke2 subtree synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: remote@kpt finalize-merge@kpt check-clean@kpt pull@kpt push@kpt

remote@kpt: ## Ensure rke2 subtree remote is configured
	: "Ensuring rke2 subtree remote is configured"
	if ! git remote get-url "$(rke2-subtree.git.remote)" >/dev/null 2>&1; then
		git remote add "$(rke2-subtree.git.remote)" git@github.com:nxmatic/rke2-manifests.git
	fi

finalize-merge@kpt: ## Finalize any pending rke2 subtree merge
	if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		if git diff --name-only --diff-filter=U | grep -q .; then
			echo "Merge in progress with unresolved conflicts; resolve before continuing." >&2
			exit 1
		fi
		: "Completing pending rke2 subtree merge..."
		GIT_MERGE_AUTOEDIT=no git commit --no-edit --quiet
	fi

check-clean@kpt: ## Ensure no uncommitted changes exist in rke2 subtree
	if ! git diff --quiet -- "$(rke2-subtree.git.subtree.dir)"; then
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
pull@kpt: ## Pull latest rke2 subtree changes from remote repository
	: "Pulling latest rke2 subtree changes from remote repository"
	git fetch --prune "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)"
	git subtree pull --prefix="$(rke2-subtree.git.subtree.dir)" "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)" --squash

push@kpt: remote@kpt check-clean@kpt
push@kpt: ## Push updated rke2 subtree to remote repository
	: "Pushing updated rke2 subtree to remote repository"
	split_sha=$$(
		git subtree split --prefix="$(rke2-subtree.git.subtree.dir)" HEAD 2>/dev/null ||
		git rev-parse --verify "$(rke2-subtree.git.branch)" 2>/dev/null ||
		true
	)
	remote_sha=$$(
		git ls-remote --heads "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)" |
		awk '{print $$1}' ||
		true
	)
	if [ -z "$$split_sha" ]; then
		echo "No rke2 subtree revisions found to push." >&2
		exit 0
	elif [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then
		: "No new rke2 revisions to push; skipping."

	fi
	: "Pushing rke2 subtree updates to remote repository"
	git subtree push --prefix="$(rke2-subtree.git.subtree.dir)" \
	  "$(rke2-subtree.git.remote)" "$(rke2-subtree.git.branch)"

endif # make.d/kpt/rules.mk guard
