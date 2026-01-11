#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

: "Create working copy of kubeconfig"
: "Ensure kubeconfig dir is provided"
: "${RKE2LAB_KUBECONFIG_DIR:?RKE2LAB_KUBECONFIG_DIR is required}"
KUBECONFIG="${RKE2LAB_KUBECONFIG_DIR}/rke2-${RKE2LAB_CLUSTER_NAME}.yaml"

mkdir -p $( dirname "$KUBECONFIG" )
cp /etc/rancher/rke2/rke2.yaml "$KUBECONFIG"
chmod 644 "$KUBECONFIG"

: "Apply modifications to working copy"
yq --inplace --from-file=<(cat <<EoE
.clusters[0].cluster.name = "${RKE2LAB_CLUSTER_NAME}" |
.clusters[0].cluster.server = "https://${NETWORK_CLUSTER_VIP_GATEWAY_IP}:6443" |
.clusters[0].name = "${RKE2LAB_CLUSTER_NAME}" |
.contexts[0].context.cluster = "${RKE2LAB_CLUSTER_NAME}" |
.contexts[0].context.namespace = "kube-system" |
.contexts[0].context.user = "${RKE2LAB_CLUSTER_NAME}" |
.contexts[0].name = "${RKE2LAB_CLUSTER_NAME}" |
.users[0].name = "${RKE2LAB_CLUSTER_NAME}" |
.current-context = "${RKE2LAB_CLUSTER_NAME}"
EoE
) "$KUBECONFIG"
