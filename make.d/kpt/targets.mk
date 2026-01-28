# kpt-targets.mk - KPT phony targets and rules (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/kpt/targets.mk
make.d/kpt/targets.mk := make.d/kpt/targets.mk

# Marker file indicating the rendered catalog is current (@codebase)
.kpt.render.stamp := $(.kpt.render.dir)/.rendered


$(.kpt.catalog.dir): sync@kpt
$(.kpt.catalog.dir): $(.kpt.catalog.dir)/Kptfile
$(.kpt.catalog.dir):  ## Ensure cluster catalog directory exists and is updated
	: "[kpt] Catalog directory ready for cluster $(cluster.name)"

# Setter values injected into runtime/rke2-config/setters.yaml before render
define .kpt.rke2-config.setters.file.content
apiVersion: v1
kind: ConfigMap
metadata:
  # kpt-merge: /rke2-config-setters
  name: rke2-config-setters
  annotations:
    config.kubernetes.io/local-config: "true"
    internal.kpt.dev/function-config: apply-setters
    internal.kpt.dev/upstream-identifier: '|ConfigMap|default|rke2-config-setters'
    description.kpt.dev: Setters for RKE2 config.yaml.d fragments
data:
  cluster-name: $(CLUSTER_NAME)
  node-name: $(NODE_NAME)
  node-kind: $(NODE_KIND)
  cluster-token: $(CLUSTER_TOKEN)
  node-host-inetaddr: $(NETWORK_NODE_HOST_INETADDR)
  cluster-id: "$(CLUSTER_ID)"
  cluster-init: "$(if $(filter master,$(NODE_NAME)),true,false)"
  pod-network-cidr: $(NETWORK_CLUSTER_POD_CIDR)
  service-network-cidr: $(NETWORK_CLUSTER_SERVICE_CIDR)
  node-gateway-inetaddr: $(NETWORK_NODE_GATEWAY_INETADDR)
  cluster-vip-gateway-inetaddr: $(NETWORK_VIP_GATEWAY_INETADDR)
endef

# ----------------------------------------------------------------------------
# Catalog Kustomization management (@codebase)
# ----------------------------------------------------------------------------

.PHONY: update-kustomizations@kpt

update-kustomizations@kpt: $(.kpt.render.stamp)
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

$(.kpt.render.stamp): $(.kpt.catalog.dir)
$(.kpt.render.stamp): $(.kpt.setters.cluster.file)
$(.kpt.render.stamp): $(.kpt.catalog.files)
$(.kpt.render.stamp): | $(dir $(.kpt.render.dir))/
$(.kpt.render.stamp):
	: "Rendering catalog for cluster $(cluster.name) via kpt fn render"
	: "[kpt] Refreshing setters.yaml with current cluster values"
	$(file >$(.kpt.rke2-config.setters.file),$(.kpt.rke2-config.setters.file.content))
	rm -fr "$(.kpt.render.dir)"
	kpt fn render --allow-network --allow-exec --truncate-output=false "$(.kpt.catalog.dir)" -o "$(.kpt.render.dir)"
	touch "$(@)"

$(.kpt.manifests.file): $(.kpt.Kustomization.file)
$(.kpt.manifests.file): $(.kpt.render.stamp)
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
		eval-all 'select(.metadata.namespace != null and .metadata.namespace != "")'\
		"$(manifests.file)"

.PHONY: rke2-manifests@kpt clean-rke2-manifests@kpt

rke2-manifests@kpt: prepare@kpt
rke2-manifests@kpt: $(.kpt.manifests.dir)
rke2-manifests@kpt: ## Unwrap rendered manifests into categorized directory structure
	: "[kpt] Unwrapped rendered manifests into $(.kpt.manifests.dir)"

clean-rke2-manifests@kpt: ## Clean categorized manifests directory
	rm -fr $(.kpt.manifests.dir)

# ----------------------------------------------------------------------------
# Catalog preparation and synchronization (@codebase)
# ----------------------------------------------------------------------------

.PHONY: prepare@kpt clean-render@kpt update@kpt update-guard@kpt sync@kpt

prepare@kpt: | $(.kpt.dir)/ $(.kpt.overlays.dir)/
prepare@kpt: update@kpt
prepare@kpt: # Fetch or update the cluster catalog
	: "[kpt] Catalog updated from upstream"

clean-render@kpt: ## Clean rendered temporary directory
	rm -rf "$(.kpt.render.dir)"

update@kpt: | $(.kpt.catalog.dir)
update@kpt: sync@kpt
update@kpt: ## Update cluster catalog via kpt pkg get/update
	: "[kpt] Catalog sync complete for cluster $(cluster.name)"

update-guard@kpt: ## Guard target to ensure catalog directory exists
	: "Ensuring catalog directory exists for cluster $(cluster.name)"
	if "$(.kpt.allow.dirty)"; then \
		echo "[kpt] Dirty catalog allowed via .kpt.allow.dirty=1; skipping clean check"; \
		exit 0; \
	fi
	if ! git diff --quiet -- catalog $(.kpt.catalog.dir) || \
	   ! git diff --cached --quiet -- catalog $(rke2.git.subtree.dir) || \
	   git ls-files --others --exclude-standard -- catalog $(rke2.git.subtree.dir) | grep -q .; then
		echo "[kpt] ERROR: catalog or $(.kpt.catalog.dir) has uncommitted changes"
		echo "[kpt] Commit or discard changes before running update@kpt (or set .kpt.allow.dirty=true to bypass)"
		exit 1
	fi

sync@kpt: update-guard@kpt ## Fetch or update cluster catalog depending on presence
sync@kpt: | $(.kpt.dir)/
sync@kpt:
	@if [ -d "$(.kpt.catalog.dir)" ]; then
		echo "[kpt] Updating existing catalog $(.kpt.catalog.dir)"
		cd "$(.kpt.catalog.dir)"
		kpt pkg update --strategy resource-merge
	else
		echo "[kpt] Fetching catalog into $(.kpt.catalog.dir)"
		kpt pkg get "$(.kpt.upstream.repo).git/${.kpt.upstream.dir}" "$(.kpt.dir)"
	fi


# --- Kustomization file generation (@codebase) ------------------------------------

$(.kpt.overlays.Kustomization.file): | $(dir $(.kpt.overlays.Kustomization.file))/
$(.kpt.overlays.Kustomization.file):
	$(file >$(@), $(.cluster.overlays.kustomize.content))

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
	if ! git remote get-url "$(rke2.git.remote)" >/dev/null 2>&1; then
		git remote add "$(rke2.git.remote)" git@github.com:nxmatic/rke2-manifests.git
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
	if ! git diff --quiet -- "$(rke2.git.subtree.dir)"; then
		echo "Uncommitted changes detected inside $(rke2.git.subtree.dir)." >&2
		exit 1
	fi
	untracked="$$(git ls-files --others --exclude-standard -- "$(rke2.git.subtree.dir)")"
	if [ -n "$$untracked" ]; then
		echo "Untracked files detected inside $(rke2.git.subtree.dir)." >&2
		echo "Files:" >&2
		echo "$$untracked" >&2
		exit 1
	fi

pull@kpt: remote@kpt finalize-merge@kpt check-clean@kpt
pull@kpt: ## Pull latest rke2 subtree changes from remote repository
	: "Pulling latest rke2 subtree changes from remote repository"
	git fetch --prune "$(rke2.git.remote)" "$(rke2.git.branch)"
	git subtree pull --prefix="$(rke2.git.subtree.dir)" "$(rke2.git.remote)" "$(rke2.git.branch)" --squash

push@kpt: remote@kpt check-clean@kpt
push@kpt: ## Push updated rke2 subtree to remote repository
	: "Pushing updated rke2 subtree to remote repository"
	split_sha=$$(
		git subtree split --prefix="$(rke2.git.subtree.dir)" HEAD 2>/dev/null ||
		git rev-parse --verify "$(rke2.git.branch)" 2>/dev/null ||
		true
	)
	remote_sha=$$(
		git ls-remote --heads "$(rke2.git.remote)" "$(rke2.git.branch)" |
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
	git subtree push --prefix="$(rke2.git.subtree.dir)"
	  "$(rke2.git.remote)" "$(rke2.git.branch)"

endif
