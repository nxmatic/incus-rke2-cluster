# network-vars.mk - Network variable derivations (@codebase)
# Self-guarding include for core network variables

ifndef make.d/network/vars.mk
make.d/network/vars.mk := make.d/network/vars.mk

include make.d/cluster/rules.mk
include make.d/node/rules.mk


# Avoid auto-regenerating network include files during clean to prevent ipcalc
# errors while the files are intentionally absent. (@codebase)
ifeq ($(filter clean@network,$(MAKECMDGOALS)),)
-include rke2.d/network/host.mk
-include rke2.d/network/node.mk
-include rke2.d/network/vip.mk
-include rke2.d/network/lb.mk
-include rke2.d/network/lan.mk
endif

# Ensure cluster.id is defined before deriving network variables
ifndef cluster.id
$(error cluster.id is not defined; cannot derive network variables)
endif

# Network directory structure
.network.dir := rke2.d/network
.network.cluster.dir := rke2.d/$(cluster.name)/network
 
# Physical host network allocation parameters
.network.host.super-network.cidr = 10.80.0.0/18
.network.host.cluster.prefix.length = 21
.network.host.node.prefix.length = 23
.network.host.lb.prefix.length = 26
.network.host.vip.prefix.length = 24
.network.host.cluster.third_octet := $(shell expr $(cluster.id) \* 8)
.network.lan.cidr ?= 192.168.1.0/24
.network.vip.vlan.id ?= 100
.network.vip.vlan.name ?= rke2-vlan
.network.lan_bridge_hwaddr_default := $(shell printf '02:00:00:bb:%02x:%02x' $(cluster.id) $(node.id))

# Per-node bridge names (isolated bridges for each node)
# Interface names (macvlan, not bridges)
.network.lan.node.interface = $(node.name)-lan0
.network.wan.node.interface = $(node.name)-vmnet0
.network.cluster.vip.interface = rke2-vip0

# =============================================================================
# DERIVED VARIABLES FOR TEMPLATES
# =============================================================================

# Profile name for Incus
.network.node.profile.name = rke2lab

# Master node IP for peer connections (derived from node 0) using subnet helper (gateway+2 -> .3)
.network.node.master.inetaddr := $(call .network.subnet-host-inetaddr,node,0,2)
.network.cluster_third_octet = $(call multiply,$(.cluster.id),8)
.network.host.cluster.cidr = 10.80.$(.network.cluster_third_octet).0/21
.network.node.base.cidr = 10.80.$(.network.cluster_third_octet).0/23
.network.host.subnets.base.$(.cluster.id) = $(call .network.inetaddr.base3,$(call .network.strip,$(.network.host.split.$(.cluster.id).network)))
.network.cluster.cidr = $(call .network.strip,$(.network.host.split.$(.cluster.id).cidr))
.network.cluster.vip.cidr = $(call .network.strip,$(.network.vip.split.7.cidr))
.network.cluster.vip.gateway = $(call .network.subnet-gateway-inetaddr,vip,7)
.network.cluster.lb.cidr = $(call .network.strip,$(.network.lb.split.1.cidr))
.network.cluster.lb.gateway = $(call .network.subnet-gateway-inetaddr,lb,1)
.network.node.cidr = $(call .network.strip,$(.network.node.split.0.cidr))
.network.node.gateway.inetaddr = $(call .network.subnet-gateway-inetaddr,node,0)
.network.node.host.inetaddr = $(call .network.subnet-host-inetaddr,node,0,$(call plus,9,$(node.id)))
.network.vip.host.inetaddr = $(call .network.subnet-host-inetaddr,vip,7,9)
.network.lan.bridge.macaddr = $(.network.lan_bridge_hwaddr_default)

# LAN slices per documented plan (block 0 = DHCP pool)
# Block 1: 192.168.1.32/27  → alcide static
# Block 2: 192.168.1.64/27  → alcide LB
# Block 4: 192.168.1.128/27 → bioskop static
# Block 6: 192.168.1.192/27 → bioskop LB
ifeq ($(cluster.name),bioskop)
	.network.lan.slice.index := 4
	.network.lan.lb.slice.index := 6
else ifeq ($(cluster.name),alcide)
	.network.lan.slice.index := 1
	.network.lan.lb.slice.index := 2
else ifeq ($(cluster.name),nikopol)
	.network.lan.slice.index := 3
	.network.lan.lb.slice.index := 5
else
	.network.lan.slice.index := 7
	.network.lan.lb.slice.index := 7
endif

.network.lan.lb.cidr = $(call .network.strip,$(.network.lan.split.$(.network.lan.lb.slice.index).cidr))
.network.lan.lb.headscale = $(call .network.subnet-host-inetaddr,lan,$(.network.lan.lb.slice.index),0)
.network.lan.headscale.inetaddr = $(.network.lan.lb.headscale)
.network.lan.tailscale.inetaddr = $(call .network.subnet-host-inetaddr,lan,$(.network.lan.lb.slice.index),1)

# Deterministic LAN static addressing for nodes: offset from minaddr to avoid headscale/tailscale
.network.lan.node.inetaddr = $(call .network.subnet-host-inetaddr,lan,$(.network.lan.slice.index),$(call plus,2,$(node.id)))
.network.lan.node.prefix = $(.network.lan.split.prefix)
.network.lan.gateway := 192.168.1.254

# Cluster WAN network (Incus bridge with Lima VM as gateway)
# Lima VM has .1 IP on the bridge and provides routing/NAT to uplink
# Cluster allocation: 10.80.(RKE2_CLUSTER_ID * 8).0/21
.network.cluster.gateway.inetaddr = $(call .network.subnet-gateway-inetaddr,host,$(.cluster.id))

# =============================================================================
# MAC ADDRESS GENERATION FOR STATIC DHCP LEASES
# =============================================================================

# Generate deterministic MAC address for node's WAN interface
# Format: 52:54:00:CC:TT:NN where:
#   52:54:00 = QEMU/KVM reserved prefix (locally administered)
#   CC = cluster ID in hex (00-ff, zero-padded)
#   TT = node type: 00=server, 01=agent
#   NN = node ID in hex (00-ff, zero-padded)
# Example: master (cluster 1, server, ID 0) = 52:54:00:01:00:00
# Note: Keep numeric printf for consistent zero-padding under .ONESHELL
.network.node_type_num_for = $(if $(filter server,$(call get-node-attr,$(1),1)),0,1)
.network.node_id_for = $(call get-node-attr,$(1),3)
.network.node_wan_mac_for = $(shell printf "52:54:00:%02x:%02x:%02x" $(cluster.id) $(call .network.node_type_num_for,$(1)) $(call .network.node_id_for,$(1)))
.network.node_type_num := $(if $(filter server,$(node.kind)),0,1)

.network.wan.dhcp.range = 10.80.$(.network.cluster_third_octet).2-10.80.$(.network.cluster_third_octet).9,10.80.$(.network.cluster_third_octet).31-10.80.$(call plus,$(.network.cluster_third_octet),7).254
.network.wan.node.macaddr := $(shell printf "52:54:00:%02x:%02x:%02x" $(cluster.id) $(.network.node_type_num) $(node.id))

# Generate deterministic MAC address for node's LAN interface (macvlan)
# Format: 10:66:6a:4c:CC:NN where:
#   10:66:6a:4c = Custom prefix for LAN interfaces
#   CC = cluster ID in hex (00-07, zero-padded)
#   NN = node ID in hex (00-ff, zero-padded)
# Example: master (cluster 2, ID 0) = 10:66:6a:4c:02:00

.network.lan.node.macaddr := $(shell printf "10:66:6a:4c:%02x:%02x" $(cluster.id) $(node.id))


# RKE2 pod/service CIDRs derived from cluster id (default /16 blocks)
.network.cluster.pod.cidr = $(cluster.pod.cidr)
.network.cluster.service.cidr = $(cluster.service.cidr)

endif
