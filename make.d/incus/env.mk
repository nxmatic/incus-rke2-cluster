# incus-env.mk - Incus environment exports (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/env.mk

make.d/incus/env.mk := make.d/incus/env.mk

-include $(rke2.env.mk)
-include $(network.env.mk)
-include $(cluster.env.mk)
-include $(node.env.mk)

-include rke2.d/$(cluster.name)/$(node.name)/incus.env.mk

define .incus.env.mk :=
export INCUS_IMAGE_NAME=$(.incus.image.name)
export INCUS_PROJECT_NAME=$(.incus.project.name)
export INCUS_EGRESS_INTERFACE=$(.incus.egress.interface)
export INCUS_RUNTIME_DIR=$(abspath $(.incus.runtime.dir))
export INCUS_WORKINGTREE_DIR=$(abspath $(top-dir))
export INCUS_ENV_FILE=$(abspath $(.incus.env.file))
export INCUS_SHARED_DIR=$(abspath $(.incus.shared.dir))
export INCUS_KUBECONFIG_DIR=$(abspath $(.incus.kubeconfig.dir))
export INCUS_NO_CLOUD_DIR=$(abspath $(.incus.nocloud.dir))
export INCUS_IMAGE_BUILD_DIR=$(abspath $(.incus.image.build.dir))
export INCUS_IMAGE_PACK_CONFIG=$(abspath $(.incus.image.pack.config))
export INCUS_SECRETS_FILE=$(abspath $(.incus.secrets.file))
export INCUS_SYSTEMD_DIR=$(abspath $(.incus.systemd.dir))
export INCUS_SCRIPTS_DIR=$(abspath $(.incus.scripts.dir))
endef

endif
