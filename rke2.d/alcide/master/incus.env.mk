ifndef incus.env.mk
incus.env.mk := rke2.d/alcide/master/incus.env.mk
export INCUS_IMAGE_NAME=control-node
export INCUS_PROJECT_NAME=rke2lab
export INCUS_EGRESS_INTERFACE=vmlan0
export INCUS_RUNTIME_DIR=/net/alcide.lan/private/var/lib/git/nxmatic/rke2lab/.local.d/var/run/distrobuilder/control-node
export INCUS_WORKINGTREE_DIR=/net/alcide.lan/private/var/lib/git/nxmatic/rke2lab
export INCUS_ENV_FILE=/net/alcide.lan/private/var/lib/git/nxmatic/rke2lab/rke2.d/alcide/master/environment
export INCUS_SYSTEMD_DIR=/net/alcide.lan/private/var/lib/git/nxmatic/rke2lab/make.d/incus/systemd
export INCUS_SCRIPTS_DIR=/net/alcide.lan/private/var/lib/git/nxmatic/rke2lab/make.d/incus/scripts
endif
