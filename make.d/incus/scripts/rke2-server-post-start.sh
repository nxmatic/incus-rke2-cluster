#!/usr/bin/env -S bash -exu -o pipefail

source <(flox activate --dir /var/lib/rancher/rke2)

: "Wait for server is ready"
until kubectl get --raw /readyz &>/dev/null; do
 : "Waiting for API server..."; sleep 5; 
done

: "Restrict rke2 kubeconfig permissions"
chmod g-w /etc/rancher/rke2/rke2.yaml