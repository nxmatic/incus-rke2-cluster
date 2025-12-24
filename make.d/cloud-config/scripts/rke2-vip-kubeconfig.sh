#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

: "Create working copy of kubeconfig"
KUBECONFIG="/.kubeconfig.d/rke2-${CLUSTER_NAME}.yaml"

mkdir -p $( dirname "$KUBECONFIG" )
cp /etc/rancher/rke2/rke2.yaml "$KUBECONFIG"
chmod 644 "$KUBECONFIG"

: "Apply modifications to working copy"
yq --inplace --from-file=<(cat <<EoE
.clusters[0].cluster.name = "${CLUSTER_NAME}" |
.clusters[0].cluster.server = "https://${NETWORK_CLUSTER_VIP_GATEWAY_IP}:6443" |
.clusters[0].name = "${CLUSTER_NAME}" |
.contexts[0].context.cluster = "${CLUSTER_NAME}" |
.contexts[0].context.namespace = "kube-system" |
.contexts[0].context.user = "${CLUSTER_NAME}" |
.contexts[0].name = "${CLUSTER_NAME}" |
.users[0].name = "${CLUSTER_NAME}" |
.current-context = "${CLUSTER_NAME}"
EoE
) "$KUBECONFIG"
