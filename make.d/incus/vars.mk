# incus-vars.mk - Incus variables and paths (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/incus/vars.mk

make.d/incus/vars.mk := make.d/incus/vars.mk

.incus.project.name = rke2lab
.incus.image.name = control-node
.incus.dir = rke2.d
.incus.instance.dir = rke2.d/$(cluster.name)/$(node.name)
# Local build/artifact workspace lives under .local.d/var/lib (tmpfs-backed) to avoid repo pollution and NFS issues (@codebase)
.incus.image.dir = $(var-dir)/lib/distrobuilder/$(.incus.image.name)
# rootfs is the primary distrobuilder output; rootfs.clone is used for pack-incus input
.incus.image.build.dir = $(.incus.image.dir)/rootfs
.incus.image.build.files = $(.incus.image.dir)/incus.tar.xz $(.incus.image.dir)/rootfs.squashfs
.incus.image.pack.config = $(.incus.image.dir)/pack.yaml
.incus.mksquashfs.opts = -comp xz -b 1048576 -noappend -info -progress
	
# should be kept outside of ZFS
.incus.nocloud.dir = $(.incus.instance.dir)
.incus.env.file = $(.incus.instance.dir)/environment
.incus.systemd.dir = $(make-dir)/incus/systemd
.incus.scripts.dir = $(make-dir)/incus/scripts
.incus.kubeconfig.dir = $(var-dir)/kube
.incus.shared.dir = $(local-dir)/share
.incus.private.dir = $(local-dir)/var/private
.incus.secrets.template = $(top-dir)/.secrets
.incus.secrets.file = $(.incus.private.dir)/secrets.yaml

# Incus image / config artifacts  
.incus.preseed.filename = incus-preseed.yaml
.incus.preseed.file = $(.incus.instance.dir)/preseed.yaml
.incus.distrobuilder.file = $(make-dir)/incus/incus-distrobuilder.yaml
.incus.distrobuilder.file.abs = $(abspath $(.incus.distrobuilder.file))
.incus.distrobuilder.log.file = $(.incus.image.dir)/distrobuilder.log

# Incus marker files (timestamps to track state changes)
.incus.image.marker.file = $(.incus.image.dir).tstamp
.incus.project.marker.file = $(.incus.dir)/incus-project.tstamp

.incus.instance.config.marker.file = $(.incus.instance.dir).tstamp
.incus.instance.config.filename = incus-instance-config.yaml
.incus.instance.config.template = $(make-dir)/incus/$(.incus.instance.config.filename)
.incus.instance.config.file = $(.incus.instance.dir)/$(.incus.instance.config.filename)

.incus.cleanup.pre.cmd =

# Primary/secondary host interfaces (macvlan parents)
.incus.lima.lan.interface = vmlan0
.incus.lima.wan.interface = vmwan0
.incus.lima.primary.interface = $(.incus.lima.lan.interface)
.incus.lima.secondary.interface = $(.incus.lima.wan.interface)
.incus.egress.interface = $(.incus.lima.primary.interface)

# Cluster inet address discovery helpers (IP unwrapping via yq)
.incus.inetaddr.yq.expr = .[].state.network.vmnet0.addresses[] | select(.family == "inet") | .address

# Cluster master token template (retained for compatibility)
.cluster.master.inetaddr = $(call .network.subnet-host-inetaddr,node,0,10)

define .incus.cluster.token.content :=
# Bootstrap server points at the master primary IP (@codebase)
server: https://$(.cluster.master.inetaddr):9345
token: $(cluster.token)
endef

.incus.zfs.allow.marker.file = rke2.d/zfs-allow-tank.marker
.incus.zfs.allow.marker.dir = $(dir $(.incus.zfs.allow.marker.file))

endif
