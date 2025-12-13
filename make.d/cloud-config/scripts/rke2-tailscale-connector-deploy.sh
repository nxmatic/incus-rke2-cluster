#!/usr/bin/env -S bash -exuo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: rke2-tailscale-connector-deploy <cluster-name> <vip-address> <lb-pool-cidr>" >&2
  exit 64
fi

cluster_name="$1"
vip_address="$2"
lb_pool_cidr="$3"
repo_dir="${CLUSTER_STATE_DIR}"
package_dir="$repo_dir/kpt/catalog/mesh/tailscale"
connector_manifest="$package_dir/03-connector.yaml"

source <(flox activate --dir /var/lib/rancher/rke2)

success=0
for i in $(seq 1 60); do
  if kubectl wait --for condition=established crd/connectors.tailscale.com --timeout=5s; then
    success=1
    break
  fi
  sleep 5
done

if [[ $success -ne 1 ]]; then
  echo "[rke2-tailscale-connector] CRD connectors.tailscale.com not ready after 5m" >&2
  exit 1
fi

kpt fn eval "$package_dir" --image ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2 --match-kind Connector -- \
  cluster-name="$cluster_name" \
  vip-address="$vip_address" \
  lb-pool-cidr="$lb_pool_cidr"

kubectl apply -f "$connector_manifest"
