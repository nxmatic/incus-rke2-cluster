#!/usr/bin/env -S bash -exu -o pipefail

source <(flox activate --dir /var/lib/rancher/rke2)

: "Wait for server is ready"
until kubectl get --raw /readyz &>/dev/null; do
 : "Waiting for API server..."; sleep 5; 
done

: "Restrict rke2 kubeconfig permissions"
chmod g-w /etc/rancher/rke2/rke2.yaml

: "Normalize node labels for scheduling" # @codebase
control_plane_nodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane=true -o name 2>/dev/null || true)
if [[ -n "${control_plane_nodes}" ]]; then
	while read -r node; do
		[[ -z "${node}" ]] && continue
		kubectl label --overwrite "${node}" \
			role=control-plane \
			type=server \
			node-type=rke2-server
	done <<< "${control_plane_nodes}"
fi
