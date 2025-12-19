#!/usr/bin/env -S bash -euo pipefail

# Derive cluster networking setters from generated subnet env files and patch the ResourceList on stdin.

echo "cwd=$(pwd)" > /tmp/cwd

input=$(cat)

cluster_id=$(yq eval-all -r -N '.items[] |
                                select(.kind=="ConfigMap" and .metadata.name=="cluster-setters") |
								.data."cluster-id"' - <<< "$input")
if [[ -z "$cluster_id" ]]; then
  echo "cluster-id missing in cluster-setters" >&2
  exit 1
fi

declare -A dirs keys cidrs bases addrs

dirs["catalog"]="$(dirname -- "$0")/.."
dirs["env"]="${dirs["catalog"]}/../make.d"
[[ ! -f "${dirs["env"]}/vip.subnets.env" ]] && {
  dirs["env"]="${dirs["catalog"]}/../rke2-subtree/bioskop/make.d"
}
source "${dirs["env"]}/vip.subnets.env"
source "${dirs["env"]}/lb.subnets.env"
source "${dirs["env"]}/host.subnets.env"

keys["vip"]="VIP_SUBNETS_NETWORK_${cluster_id}"
keys["lb"]="LB_SUBNETS_NETWORK_${cluster_id}"
keys["host"]="HOST_SUBNETS_NETWORK_${cluster_id}"

cidrs["vip"]=${!keys["vip"]:-}
cidrs["lb"]=${!keys["lb"]:-}
cidrs["host"]=${!keys["host"]:-}

if [[ -z "${cidrs["vip"]}" ]]; then
  echo "missing env ${keys["vip"]}" >&2
  exit 1
fi
if [[ -z "${cidrs["lb"]}" ]]; then
  echo "missing env ${keys["lb"]}" >&2
  exit 1
fi
if [[ -z "${cidrs["host"]}" ]]; then
  echo "missing env ${keys["host"]}" >&2
  exit 1
fi

# Compute node VIP (.10) and gateway (.1) from the CIDRs.
net_base() {
  local cidr="$1"
  printf '%s' "${cidr%%/*}"
}

slice_ip() {
  local ip="$1" octet="$2" last_octet
  IFS='.' read -r o1 o2 o3 _ <<< "$ip"
  last_octet="$octet"
  printf '%s.%s.%s.%s' "$o1" "$o2" "$o3" "$last_octet"
}

bases["vip"]=$(net_base "${cidrs["vip"]}")
bases["host"]=$(net_base "${cidrs["host"]}")

addrs["node_vip"]=$(slice_ip "${bases["vip"]}" 10)
addrs["gateway"]=$(slice_ip "${bases["host"]}" 1)

export VIP_CIDR="${cidrs["vip"]}"
export LB_CIDR="${cidrs["lb"]}"
export NODE_VIP_IP="${addrs["node_vip"]}"
export NODE_GATEWAY_IP="${addrs["gateway"]}"

yq eval '
  with(.items[] | select(.kind == "ConfigMap" and .metadata.name == "kube-vip-setters");
    .data."cluster-vip-address" = env(NODE_VIP_IP)
  ) |
  with(.items[] | select(.kind == "ConfigMap" and .metadata.name == "tailscale-setters");
    .data."vip-address" = env(NODE_VIP_IP) |
    .data."lb-pool-cidr" = env(LB_CIDR)
  ) |
  with(.items[] | select(.kind == "ConfigMap" and .metadata.name == "cilium-setters");
    .data."vip-pool-cidr" = env(VIP_CIDR) |
    .data."lb-pool-cidr" = env(LB_CIDR) |
    .data."node-gateway-ip" = env(NODE_GATEWAY_IP)
  )' - <<< "$input"
