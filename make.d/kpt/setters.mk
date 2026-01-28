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
  cluster-node-name: $(NODE_NAME)
  cluster-node-kind: $(NODE_KIND)
  cluster-flox-enabled: $(CLUSTER_FLOX_ENABLED)
  cluster-cidr: $(NETWORK_CLUSTER_CIDR)
  cluster-lb-cidr: $(NETWORK_CLUSTER_LB_CIDR)
  cluster-vip-cidr: $(NETWORK_VIP_CIDR)
  cluster-host-cidr: $(NETWORK_HOST_CIDR)
  cluster-node-cidr: $(NETWORK_NODE_CIDR)
  cluster-gateway-inetaddr: $(NETWORK_CLUSTER_GATEWAY_INETADDR)
  cluster-node-vip-inetaddr: $(NETWORK_VIP_HOST_INETADDR)
  cluster-node-gateway-inetaddr: $(NETWORK_NODE_GATEWAY_INETADDR)
  cluster-node-host-inetaddr: $(NETWORK_NODE_HOST_INETADDR)
  cluster-node-inetaddr-base: $(NETWORK_CLUSTER_NODE_INETADDR_BASE)
  cluster-pod-cider: $(NETWORK_CLUSTER_POD_CIDR)
  cluster-service-cidr: $(NETWORK_CLUSTER_SERVICE_CIDR)
  cluster-vip-gateway-inetaddr: $(NETWORK_VIP_GATEWAY_INETADDR)
  cluster-lb-gateway-inetaddr: $(NETWORK_CLUSTER_LB_GATEWAY_INETADDR)
  cluster-node-lan-macaddr: $(NETWORK_LAN_HOST_MACADDR)
  cluster-node-wan-macaddr: $(NETWORK_WAN_HOST_MACADDR)
  cluster-node-profile-name: $(NETWORK_NODE_PROFILE_NAME)
  cluster-wan-dhcp-range: $(NETWORK_WAN_DHCP_RANGE)
  cluster-node-lan-interface: $(NETWORK_LAN_INTERFACE)
  cluster-node-wan-interface: $(NETWORK_WAN_INTERFACE)
  cluster-vip-interface: $(NETWORK_VIP_INTERFACE)
  cluster-vip-vlan-id: $(NETWORK_VIP_VLAN_ID)
  cluster-vip-vlan-name: $(NETWORK_VIP_VLAN_NAME)
  cluster-master-node-inetaddr: $(NETWORK_NODE_MASTER_INETADDR)
  cluster-lan-lb-cidr: $(NETWORK_LAN_LB_CIDR)
  cluster-lan-bridge-macaddr: $(NETWORK_LAN_BRIDGE_MACADDR)
  cluster-lan-host-inetaddr: $(NETWORK_LAN_HOST_INETADDR)
  cluster-lan-headscale-inetaddr: $(NETWORK_LAN_HEADSCALE_INETADDR)
  cluster-lan-tailscale-inetaddr: $(NETWORK_LAN_TAILSCALE_INETADDR)
  cluster-node-wan-macaddr-master: $(NETWORK_WAN_HOST_MACADDR_MASTER)
  cluster-node-wan-macaddr-peer1: $(NETWORK_WAN_HOST_MACADDR_PEER1)
  cluster-node-wan-macaddr-peer2: $(NETWORK_WAN_HOST_MACADDR_PEER2)
  cluster-node-wan-macaddr-peer3: $(NETWORK_WAN_HOST_MACADDR_PEER3)
  cluster-node-wan-macaddr-worker1: $(NETWORK_WAN_HOST_MACADDR_WORKER1)
  cluster-node-wan-macaddr-worker2: $(NETWORK_WAN_HOST_MACADDR_WORKER2)
  cluster-zfs-pool-name: tank
  cluster-kubelet-dir: /var/lib/kubelet
endef # .kpt.cluster.setters.file.content

endif # make.d/kpt/setters.mk
