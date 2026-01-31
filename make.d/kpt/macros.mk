# kpt-macros.mk - KPT helper macros (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/kpt/macros.mk
make.d/kpt/macros.mk := make.d/kpt/macros.mk

# Require a binary to be present, otherwise exit with an error (@codebase)
define .kpt.require-bin
	if ! command -v $(1) >/dev/null 2>&1; then
		echo "[kpt] Missing required command $(1)";
		exit 1;
	fi
endef

# Utility macros for kustomization.yaml generation (@codebase)
define .kpt.yaml.comma-join =
$(subst $(space),$1,$(strip $2))
endef

define .kpt.yaml.rangeOf =
[ $(call .kpt.yaml.comma-join,$(comma)$(newline),$(foreach value,$(1),"$(value)")) ]
endef 

define .kustomization.yaml.file.content =
$(warning generating kustomization.yaml content for $(1))
apiVersion: kustomize.config.k8s.io/v1beta1
kind: kustomization.yaml
resources: $(call .kpt.yaml.rangeOf,$(1))
endef

define .cluster.kustomize.content = 
	apiVersion: kustomize.config.k8s.io/v1beta1
	kind: kustomization.yaml
	resources:
	- catalog
	- overlays
endef

define .cluster.overlays.kustomize.content = 
	apiVersion: kustomize.config.k8s.io/v1beta1
	kind: kustomization.yaml
	resources:
	- ../catalog
endef

# Resource categorization helpers (@codebase)
define .kpt.toFilePath =
(
	(.metadata.annotations["kpt.dev/package-layer"] // "default") + "/" + 
	(.metadata.annotations["kpt.dev/package-name"] // "unknown") + "/" + 
	("$(strip $(1))-" +  (.kind | downcase) + "-" + (
		.metadata.name
		| downcase
		| sub(":"; "-")
		| sub("/"; "-")
	)) +
	".yml"
)
endef

define .kpt.isOwnedByPackage =
.metadata.annotations."kpt.dev/package-name" == "$(pkg)"
endef

endif
