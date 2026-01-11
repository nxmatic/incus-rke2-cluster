# openebs-zfs setters configmap (example, update env.mk path/vars as needed)

ifndef make.d/kpt/setters.mk

make.d/kpt/setters.mk := make.d/kpt/setters.mk

-include $(cluster.env.mk)
-include $(network.env.mk)

$(.kpt.catalog.dir)/Kptfile: $(.kpt.setters.cluster.file)
$(.kpt.catalog.dir)/Kptfile: export YQ_EXPR = $(.kpt.catalog.kptfile.yqExpr)
$(.kpt.catalog.dir)/Kptfile: ## Ensure Kptfile includes setters mutator
	: "[kpt] Ensuring Kptfile exists in catalog directory"
	yq --inplace eval "$$YQ_EXPR" "$@"

define .kpt.catalog.kptfile.yqExpr
( . + [
    {
      "image": " ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2",
      "configPath": "$(.kpt.cluster.setters.file)"
    }
  ] | unique )
endef

# Cluster setters configmap for rke2 cluster

.kpt.setters.cluster.file :=  $(.kpt.catalog.dir)/configmap-cluster-setters.yaml

$(call register-kpt-cluster-setters-targets,$(.kpt.setters.cluster.file))

# Main cluster setters configmap depends on env.mk for up-to-date values
$(.kpt.setters.cluster.file): $(cluster.env.mk)
$(.kpt.setters.cluster.file): $(network.env.mk)
$(.kpt.setters.cluster.file): $(.kpt.catalog.dir)/Kptfile
$(.kpt.setters.cluster.file): export YQ_EXPR = $(.kpt.cluster.setters.content)
$(.kpt.setters.cluster.file):
	yq -i eval "${YQ_EXPR}" $(@)

define .kpt.cluster.setters.content
with(.data;
  .cluster-name = env(CLUSTER_NAME) |
  .cluster-id = env(CLUSTER_ID) |
  .cluster-domain = env(CLUSTER_DOMAIN) |
  .cluster-env = env(CLUSTER_ENV) |
  .cluster-network-cidr = env(NETWORK_CLUSTER_CIDR) |
  .host-supernet-cidr = env(NETWORK_HOST_SUPERNET_CIDR) |
  .node-network-cidr = env(NETWORK_NODE_CIDR) |
  .vip-pool-cidr = env(NETWORK_VIP_CIDR) |
  .lb-pool-cidr = env(NETWORK_CLUSTER_LB_CIDR) |
  .cluster-gateway-inet = env(NETWORK_CLUSTER_GATEWAY_INETADDR) |
  .node-vip-inet = env(NETWORK_NODE_VIP_INETADDR) |
  .node-gateway-ip = env(NETWORK_NODE_GATEWAY_INETADDR) |
  .node-host-ip = env(NETWORK_NODE_HOST_INETADDR) |
  .lan-bridge-hwaddr = env(NETWORK_LAN_BRIDGE_MACADDR) |
  .cluster-node-inet-base = env(NETWORK_CLUSTER_NODE_INETADDR_BASE) |
  .pod-network-cidr = env(NETWORK_CLUSTER_POD_CIDR) |
  .service-network-cidr = env(NETWORK_CLUSTER_SERVICE_CIDR) |
  .cluster-vip-gateway-ip = env(NETWORK_VIP_GATEWAY_INETADDR) |
  .cluster-lb-gateway-ip = env(NETWORK_CLUSTER_LB_GATEWAY_INETADDR) |
  .node-lan-macaddr = env(NETWORK_NODE_LAN_MACADDR) |
  .node-wan-macaddr = env(NETWORK_NODE_WAN_MACADDR) |
  .node-profile-name = env(NETWORK_NODE_PROFILE_NAME) |
  .wan-dhcp-range = env(NETWORK_WAN_DHCP_RANGE) |
  .node-lan-interface = env(NETWORK_NODE_LAN_INTERFACE) |
  .node-wan-interface = env(NETWORK_NODE_WAN_INTERFACE) |
  .vip-interface = env(NETWORK_VIP_INTERFACE) |
  .vip-vlan-id = env(NETWORK_VIP_VLAN_ID) |
  .vip-vlan-name = env(NETWORK_VIP_VLAN_NAME) |
  .master-node-inetaddr = env(NETWORK_MASTER_NODE_INETADDR) |
  .lan-lb-pool = env(NETWORK_LAN_LB_POOL) |
  .lan-headscale-inetaddr = env(NETWORK_LAN_HEADSCALE_INETADDR) |
  .lan-tailscale-inetaddr = env(NETWORK_LAN_TAILSCALE_INETADDR) |
  .node-wan-macaddr-master = env(NETWORK_NODE_WAN_MACADDR_MASTER) |
  .node-wan-macaddr-peer1 = env(NETWORK_NODE_WAN_MACADDR_PEER1) |
  .node-wan-macaddr-peer2 = env(NETWORK_NODE_WAN_MACADDR_PEER2) |
  .node-wan-macaddr-peer3 = env(NETWORK_NODE_WAN_MACADDR_PEER3) |
  .node-wan-macaddr-worker1 = env(NETWORK_NODE_WAN_MACADDR_WORKER1) |
  .node-wan-macaddr-worker2 = env(NETWORK_NODE_WAN_MACADDR_WORKER2)
)
endef

endif # make.d/kpt/setters.mk
