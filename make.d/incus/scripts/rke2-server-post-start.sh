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

: "Apply runtime-only secrets from .secrets" # @codebase
RKE2LAB_REPO_ROOT=${RKE2LAB_REPO_ROOT:-/var/lib/rke2lab}
SECRETS_FILE=""
for candidate in \
	"${RKE2LAB_REPO_ROOT}/.secrets" \
	"/srv/host/rke2lab/.secrets" \
	"/srv/host/.secrets"; do
	if [[ -r "${candidate}" ]]; then
		SECRETS_FILE="${candidate}"
		break
	fi
done

if [[ -z "${SECRETS_FILE}" ]]; then
	echo "[rke2-server-post-start] .secrets file not found; skipping runtime secrets" >&2
	exit 0
fi

YQ_BIN="$(command -v yq || command -v yq-go || true)"
if [[ -z "${YQ_BIN}" ]]; then
	echo "[rke2-server-post-start] yq not found; skipping runtime secrets" >&2
	exit 0
fi

if ! "${YQ_BIN}" eval -e '.kubernetes' "${SECRETS_FILE}" >/dev/null 2>&1; then
	echo "[rke2-server-post-start] no kubernetes secrets config in ${SECRETS_FILE}; skipping" >&2
	exit 0
fi

source_namespace="$("${YQ_BIN}" eval -r '.kubernetes.sourceNamespace // "kube-system"' "${SECRETS_FILE}")"

rke2lab::kube:apply_secret() {
	local namespace="$1" name="$2" type="$3" replicate_to="$4"
	shift 4
	local manifest

	manifest=$(
		kubectl -n "${namespace}" create secret generic "${name}" \
			--type="${type}" \
			"$@" \
			--dry-run=client -o yaml
	)

	if [[ -n "${replicate_to}" ]]; then
		manifest=$(printf '%s\n' "${manifest}" | \
			"${YQ_BIN}" eval \
				".metadata.annotations.\"replicator.v1.mittwald.de/replicate-to\" = \"${replicate_to}\"" -)
	fi

	printf '%s\n' "${manifest}" | kubectl apply -f -
}

set +x

: "Tailscale operator OAuth secret"
tailscale_name="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tailscale.name // "operator-oauth"' "${SECRETS_FILE}")"
tailscale_replicate_to="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tailscale.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
tailscale_client_id="$("${YQ_BIN}" eval -r '.tailscale.client.id // ""' "${SECRETS_FILE}")"
tailscale_client_secret="$("${YQ_BIN}" eval -r '.tailscale.client.token // ""' "${SECRETS_FILE}")"
if [[ -n "${tailscale_client_id}" && -n "${tailscale_client_secret}" ]]; then
	rke2lab::kube:apply_secret "${source_namespace}" "${tailscale_name}" "Opaque" "${tailscale_replicate_to}" \
		--from-literal=client_id="${tailscale_client_id}" \
		--from-literal=client_secret="${tailscale_client_secret}"
fi

: "Tekton git auth secret"
tekton_git_name="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tekton.git.name // "tekton-git-auth"' "${SECRETS_FILE}")"
tekton_git_replicate_to="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tekton.git.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
tekton_git_username="$("${YQ_BIN}" eval -r '.tekton.git.username // ""' "${SECRETS_FILE}")"
tekton_git_password="$("${YQ_BIN}" eval -r '.tekton.git.password // ""' "${SECRETS_FILE}")"
if [[ -n "${tekton_git_username}" && -n "${tekton_git_password}" ]]; then
	rke2lab::kube:apply_secret "${source_namespace}" "${tekton_git_name}" "kubernetes.io/basic-auth" "${tekton_git_replicate_to}" \
		--from-literal=username="${tekton_git_username}" \
		--from-literal=password="${tekton_git_password}"
fi

: "Tekton docker registry secret"
tekton_docker_name="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tekton.docker.name // "tekton-docker-config"' "${SECRETS_FILE}")"
tekton_docker_replicate_to="$("${YQ_BIN}" eval -r '.kubernetes.secrets.tekton.docker.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
tekton_docker_config="$("${YQ_BIN}" eval -r '.tekton.docker.configJson // ""' "${SECRETS_FILE}")"
if [[ -n "${tekton_docker_config}" ]]; then
	rke2lab::kube:apply_secret "${source_namespace}" "${tekton_docker_name}" "kubernetes.io/dockerconfigjson" "${tekton_docker_replicate_to}" \
		--from-literal=.dockerconfigjson="${tekton_docker_config}"
fi

: "Porch git https auth secret"
porch_git_name="$("${YQ_BIN}" eval -r '.kubernetes.secrets.porch.git.name // "porch-git-auth"' "${SECRETS_FILE}")"
porch_git_replicate_to="$("${YQ_BIN}" eval -r '.kubernetes.secrets.porch.git.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
porch_git_username="$("${YQ_BIN}" eval -r '.porch.git.username // ""' "${SECRETS_FILE}")"
porch_git_password="$("${YQ_BIN}" eval -r '.porch.git.password // ""' "${SECRETS_FILE}")"
if [[ -n "${porch_git_username}" && -n "${porch_git_password}" ]]; then
	rke2lab::kube:apply_secret "${source_namespace}" "${porch_git_name}" "kubernetes.io/basic-auth" "${porch_git_replicate_to}" \
		--from-literal=username="${porch_git_username}" \
		--from-literal=password="${porch_git_password}"
fi

: "Porch git ssh auth secret"
porch_ssh_name="$("${YQ_BIN}" eval -r '.kubernetes.secrets.porch.ssh.name // "porch-git-ssh"' "${SECRETS_FILE}")"
porch_ssh_replicate_to="$("${YQ_BIN}" eval -r '.kubernetes.secrets.porch.ssh.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
porch_ssh_private_key="$("${YQ_BIN}" eval -r '.porch.ssh.privateKey // ""' "${SECRETS_FILE}")"
porch_ssh_known_hosts="$("${YQ_BIN}" eval -r '.porch.ssh.knownHosts // ""' "${SECRETS_FILE}")"
if [[ -n "${porch_ssh_private_key}" ]]; then
	if [[ -n "${porch_ssh_known_hosts}" ]]; then
		rke2lab::kube:apply_secret "${source_namespace}" "${porch_ssh_name}" "kubernetes.io/ssh-auth" "${porch_ssh_replicate_to}" \
			--from-literal=ssh-privatekey="${porch_ssh_private_key}" \
			--from-literal=known_hosts="${porch_ssh_known_hosts}"
	else
		rke2lab::kube:apply_secret "${source_namespace}" "${porch_ssh_name}" "kubernetes.io/ssh-auth" "${porch_ssh_replicate_to}" \
			--from-literal=ssh-privatekey="${porch_ssh_private_key}"
	fi
fi

set -x