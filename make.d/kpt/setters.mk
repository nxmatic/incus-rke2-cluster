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
(.pipeline.mutators // []) as $m |
.pipeline.mutators = (
  $m + [
    {
      "image": "ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2",
      "configPath": "$(.kpt.cluster.setters.file)"
    }
  ] | unique
)
endef

# Cluster setters configmap for rke2 cluster

.kpt.setters.cluster.file :=  $(.kpt.catalog.dir)/configmap-cluster-setters.yaml

$(call register-kpt-cluster-setters-targets,$(.kpt.setters.cluster.file))

# Main cluster setters configmap depends on env.mk for up-to-date values
$(.kpt.setters.cluster.file): $(cluster.env.mk)
$(.kpt.setters.cluster.file): $(network.env.mk)
$(.kpt.setters.cluster.file): $(.kpt.catalog.dir)/Kptfile
$(.kpt.setters.cluster.file):
	$(file >$(@),$(.kpt.cluster.setters.file.content))

define .kpt.cluster.setters.file.content
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-setters
  annotations:
    config.kubernetes.io/local-config: "true"
    internal.kpt.dev/function-config: apply-setters
    description.kpt.dev: Shared cluster identity/network setters (consumed by catalog bundles)
    internal.kpt.dev/upstream-identifier: '|ConfigMap|default|cluster-setters'
data:
  cluster-name: $(CLUSTER_NAME)
  cluster-env: $(CLUSTER_ENV)
  cluster-id: $(CLUSTER_ID)
  cluster-domain: $(CLUSTER_DOMAIN)
  cluster-network-cidr: $(NETWORK_CLUSTER_CIDR)
  host-supernet-cidr: $(NETWORK_HOST_SUPERNET_CIDR)
  node-network-cidr: $(NETWORK_NODE_CIDR)
  vip-pool-cidr: $(NETWORK_VIP_CIDR)
  lb-pool-cidr: $(NETWORK_CLUSTER_LB_CIDR)
  cluster-gateway-inet: $(NETWORK_CLUSTER_GATEWAY_INETADDR)
  node-vip-inet: $(NETWORK_NODE_VIP_INETADDR)
  node-gateway-inetaddr: $(NETWORK_NODE_GATEWAY_INETADDR)
  node-host-inetaddr: $(NETWORK_NODE_HOST_INETADDR)
  lan-bridge-hwaddr: $(NETWORK_LAN_BRIDGE_MACADDR)
  cluster-node-inet-base: $(NETWORK_CLUSTER_NODE_INETADDR_BASE)
  pod-network-cidr: $(NETWORK_CLUSTER_POD_CIDR)
  service-network-cidr: $(NETWORK_CLUSTER_SERVICE_CIDR)
  cluster-vip-gateway-inetaddr: $(NETWORK_VIP_GATEWAY_INETADDR)
  cluster-lb-gateway-inetaddr: $(NETWORK_CLUSTER_LB_GATEWAY_INETADDR)
  node-lan-macaddr: $(NETWORK_NODE_LAN_MACADDR)
  node-wan-macaddr: $(NETWORK_NODE_WAN_MACADDR)
  node-profile-name: $(NETWORK_NODE_PROFILE_NAME)
  wan-dhcp-range: $(NETWORK_WAN_DHCP_RANGE)
  node-lan-interface: $(NETWORK_NODE_LAN_INTERFACE)
  node-wan-interface: $(NETWORK_NODE_WAN_INTERFACE)
  vip-interface: $(NETWORK_VIP_INTERFACE)
  vip-vlan-id: $(NETWORK_VIP_VLAN_ID)
  vip-vlan-name: $(NETWORK_VIP_VLAN_NAME)
  master-node-inetaddr: $(NETWORK_MASTER_NODE_INETADDR)
  lan-lb-pool: $(NETWORK_LAN_LB_POOL)
  lan-headscale-inetaddr: $(NETWORK_LAN_HEADSCALE_INETADDR)
  lan-tailscale-inetaddr: $(NETWORK_LAN_TAILSCALE_INETADDR)
  node-wan-macaddr-master: $(NETWORK_NODE_WAN_MACADDR_MASTER)
  node-wan-macaddr-peer1: $(NETWORK_NODE_WAN_MACADDR_PEER1)
  node-wan-macaddr-peer2: $(NETWORK_NODE_WAN_MACADDR_PEER2)
  node-wan-macaddr-peer3: $(NETWORK_NODE_WAN_MACADDR_PEER3)
  node-wan-macaddr-worker1: $(NETWORK_NODE_WAN_MACADDR_WORKER1)
  node-wan-macaddr-worker2: $(NETWORK_NODE_WAN_MACADDR_WORKER2)
endef

endif # make.d/kpt/setters.mk
