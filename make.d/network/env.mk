# network-env.mk - Network environment exports and plan (@codebase)
# Self-guarding include for env exports and plan generation

ifndef make.d/network/env.mk
make.d/network/env.mk := make.d/network/env.mk

# Layer env export (@codebase)
-include rke2.d/$(cluster.name)/network.env.mk

define .network.env.mk
# Generated network layer environment (cluster $(cluster.name)) - do not edit
export NETWORK_HOST_SUPERNET_CIDR=$(.network.host.supernet.cidr)
export NETWORK_CLUSTER_CIDR=$(.network.cluster.cidr)
export NETWORK_CLUSTER_SERVICE_CIDR=$(.network.cluster.service.cidr)
export NETWORK_CLUSTER_POD_CIDR=$(.network.cluster.pod.cidr)
export NETWORK_NODE_CIDR=$(.network.node.cidr)
export NETWORK_VIP_CIDR=$(.network.cluster.vip.cidr)
export NETWORK_VIP_GATEWAY_INETADDR=$(.network.cluster.vip.gateway)
export NETWORK_CLUSTER_LB_CIDR=$(.network.cluster.lb.cidr)
export NETWORK_CLUSTER_LB_GATEWAY_INETADDR=$(.network.cluster.lb.gateway)
export NETWORK_CLUSTER_GATEWAY_INETADDR=$(.network.cluster.gateway.inetaddr)
export NETWORK_NODE_GATEWAY_INETADDR=$(.network.node.gateway.inetaddr)
export NETWORK_NODE_HOST_INETADDR=$(.network.node.host.inetaddr)
export NETWORK_NODE_VIP_INETADDR=$(.network.node.vip.inetaddr)
export NETWORK_NODE_LAN_MACADDR=$(.network.node.lan.macaddr)
export NETWORK_NODE_WAN_MACADDR=$(.network.node.wan.macaddr)
export NETWORK_LAN_BRIDGE_MACADDR=$(.network.lan.bridge.macaddr)
export NETWORK_NODE_PROFILE_NAME=$(.network.node.profile.name)
export NETWORK_WAN_DHCP_RANGE=$(.network.wan.dhcp.range)
export NETWORK_CLUSTER_NODE_INETADDR_BASE=$(call .network.cidr.to-base-inetaddr,$(.network.host.split.$(.cluster.id).cidr))
export NETWORK_NODE_LAN_INTERFACE=$(.network.node.lan.interface)
export NETWORK_NODE_WAN_INTERFACE=$(.network.node.wan.interface)
export NETWORK_VIP_INTERFACE=$(.network.cluster.vip.interface)
export NETWORK_VIP_VLAN_ID=$(.network.vip.vlan.id)
export NETWORK_VIP_VLAN_NAME=$(.network.vip.vlan.name)
export NETWORK_MASTER_NODE_INETADDR=$(.network.master.node.inetaddr)
export NETWORK_LAN_LB_POOL=$(.network.lan.lb.pool)
export NETWORK_LAN_HEADSCALE_INETADDR=$(.network.lan.lb.headscale)
export NETWORK_LAN_TAILSCALE_INETADDR=$(.network.lan.tailscale.inetaddr)
export NETWORK_NODE_WAN_MACADDR_MASTER=$(call .network.node_wan_mac_for,master)
export NETWORK_NODE_WAN_MACADDR_PEER1=$(call .network.node_wan_mac_for,peer1)
export NETWORK_NODE_WAN_MACADDR_PEER2=$(call .network.node_wan_mac_for,peer2)
export NETWORK_NODE_WAN_MACADDR_PEER3=$(call .network.node_wan_mac_for,peer3)
export NETWORK_NODE_WAN_MACADDR_WORKER1=$(call .network.node_wan_mac_for,worker1)
export NETWORK_NODE_WAN_MACADDR_WORKER2=$(call .network.node_wan_mac_for,worker2)
endef


rke2.d/$(cluster.name)/network.env.mk: $(.network.subnets.mks)

define network.setters.file.content
apiVersion: v1
kind: ConfigMap
metadata:
  name: network-setters
  annotations:
    config.kubernetes.io/local-config: "true"
    internal.kpt.dev/function-config: apply-setters
data:
  host-supernet-cidr: "$(.network.host.supernet.cidr)"
  cluster-network-cidr: "$(.network.cluster.cidr)"
  node-network-cidr: "$(.network.node.cidr)"
  vip-pool-cidr: "$(.network.cluster.vip.cidr)"
  lb-pool-cidr: "$(.network.cluster.lb.cidr)"
  cluster-gateway-inet: "$(.network.cluster.gateway.inetaddr)"
  node-vip-inet: "$(.network.node.vip.inetaddr)"
  node-gateway-inet: "$(.network.node.gateway.inetaddr)"
  node-host-inet: "$(.network.node.host.inetaddr)"
  lan-bridge-hwaddr: "$(.network.lan.bridge.macaddr)"
  cluster-node-inet-base: "$(.network.host.subnets.base.$(cluster.id))"
  host-subnet-split-network: "$(.network.host.split.network)"
  host-subnet-split-prefix: "$(.network.host.split.prefix)"
  host-subnet-split-count: "$(.network.host.split.count)"
  node-subnet-split-network: "$(.network.node.split.network)"
  node-subnet-split-prefix: "$(.network.node.split.prefix)"
  node-subnet-split-count: "$(.network.node.split.count)"
  vip-subnet-split-network: "$(.network.vip.split.network)"
  vip-subnet-split-prefix: "$(.network.vip.split.prefix)"
  vip-subnet-split-count: "$(.network.vip.split.count)"
  lb-subnet-split-network: "$(.network.lb.split.network)"
  lb-subnet-split-prefix: "$(.network.lb.split.prefix)"
  lb-subnet-split-count: "$(.network.lb.split.count)"
  host-split: |-
    - "$(.network.host.split.0.cidr)"
    - "$(.network.host.split.1.cidr)"
    - "$(.network.host.split.2.cidr)"
    - "$(.network.host.split.3.cidr)"
    - "$(.network.host.split.4.cidr)"
    - "$(.network.host.split.5.cidr)"
    - "$(.network.host.split.6.cidr)"
    - "$(.network.host.split.7.cidr)"
  node-split: |-
    - "$(.network.node.split.0.cidr)"
    - "$(.network.node.split.1.cidr)"
    - "$(.network.node.split.2.cidr)"
    - "$(.network.node.split.3.cidr)"
  vip-split: |-
    - "$(.network.vip.split.0.cidr)"
    - "$(.network.vip.split.1.cidr)"
    - "$(.network.vip.split.2.cidr)"
  lan-lb-pool: "$\(.network.lan.lb.pool)"
  lan-headscale-inetaddr: "$\(.network.lan.lb.headscale)"
    - "$(.network.vip.split.3.cidr)"
    - "$(.network.vip.split.4.cidr)"
    - "$(.network.vip.split.5.cidr)"
    - "$(.network.vip.split.6.cidr)"
    - "$(.network.vip.split.7.cidr)"
  lb-split: |-
    - "$(.network.lb.split.0.cidr)"
    - "$(.network.lb.split.1.cidr)"
    - "$(.network.lb.split.2.cidr)"
    - "$(.network.lb.split.3.cidr)"
    - "$(.network.lb.split.4.cidr)"
    - "$(.network.lb.split.5.cidr)"
    - "$(.network.lb.split.6.cidr)"
    - "$(.network.lb.split.7.cidr)"
  node-wan-macs: |-
    master: "$(NETWORK_NODE_WAN_MACADDR_MASTER)"
    peer1: "$(NETWORK_NODE_WAN_MACADDR_PEER1)"
    peer2: "$(NETWORK_NODE_WAN_MACADDR_PEER2)"
    peer3: "$(NETWORK_NODE_WAN_MACADDR_PEER3)"
    worker1: "$(NETWORK_NODE_WAN_MACADDR_WORKER1)"
    worker2: "$(NETWORK_NODE_WAN_MACADDR_WORKER2)"
  # RKE2 config setter-friendly fields
  pod-network-cidr: "$(.network.cluster.pod.cidr)"
  service-network-cidr: "$(.network.cluster.service.cidr)"
  node-gateway-ip: "$(.network.node.gateway.inetaddr)"
  node-host-ip: "$(.network.node.host.inetaddr)"
  cluster-vip-gateway-ip: "$(.network.cluster.vip.gateway)"
endef

endif
