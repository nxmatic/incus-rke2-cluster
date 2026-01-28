ifndef cloud-config.env.mk
cloud-config.env.mk := rke2.d/alcide/master/cloud-config.env.mk

export CLOUDCONFIG_METADATA_FILE := /net/alcide.local/private/var/lib/git/nxmatic/rke2lab/rke2.d/alcide/master/meta-data
export CLOUDCONFIG_USERDATA_FILE := /net/alcide.local/private/var/lib/git/nxmatic/rke2lab/rke2.d/alcide/master/user-data
export CLOUDCONFIG_NETCFG_FILE := /net/alcide.local/private/var/lib/git/nxmatic/rke2lab/rke2.d/alcide/master/network-config

endif
