#!/usr/bin/env -S bash -exu -o pipefail

: "Load RKE2 environment for kubectl and tooling"
source <(flox activate --dir /var/lib/rancher/rke2)

log() {
  echo "[rke2-layer-secrets] $*"
}

usage() {
  echo "Usage: $(basename "$0") <layer>" >&2
  echo "Layers: runtime | mesh | cicd" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

layer="${1%/}"

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
  log ".secrets file not found; skipping layer secrets"
  exit 0
fi

if ! yq eval -e '.kubernetes' "${SECRETS_FILE}" >/dev/null 2>&1; then
  log "no kubernetes secrets config in ${SECRETS_FILE}; skipping"
  exit 0
fi

source_namespace="kube-system"

rke2lab::kube:apply_secret() {
  local namespace="$1" name="$2" type="$3" replicate_to="$4"
  shift 4
  local manifest

  kubectl get namespace "${namespace}" >/dev/null 2>&1 || kubectl create namespace "${namespace}" >/dev/null

  manifest=$(
    kubectl -n "${namespace}" create secret generic "${name}" \
      --type="${type}" \
      "$@" \
      --dry-run=client -o yaml
  )

  if [[ -n "${replicate_to}" ]]; then
    manifest=$(printf '%s\n' "${manifest}" | \
      yq eval \
        ".metadata.annotations.\"replicator.v1.mittwald.de/replicate-to\" = \"${replicate_to}\"" -)
  fi

  printf '%s\n' "${manifest}" | kubectl apply -f -
}

set +x

case "${layer}" in
  mesh)
    tailscale_name="$(yq eval -r '.kubernetes.secrets.tailscale.name // "operator-oauth"' "${SECRETS_FILE}")"
    tailscale_replicate_to="$(yq eval -r '.kubernetes.secrets.tailscale.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
    tailscale_oauth_id="$(yq eval -r '.tailscale.oauth.id // ""' "${SECRETS_FILE}")"
    tailscale_oauth_token="$(yq eval -r '.tailscale.oauth.token // ""' "${SECRETS_FILE}")"

    if [[ -z "${tailscale_oauth_id}" || -z "${tailscale_oauth_token}" ]]; then
      tailscale_oauth_id="$(yq eval -r '.tailscale.client.id // ""' "${SECRETS_FILE}")"
      tailscale_oauth_token="$(yq eval -r '.tailscale.client.token // ""' "${SECRETS_FILE}")"
    fi

    if [[ -n "${tailscale_oauth_id}" && -n "${tailscale_oauth_token}" ]]; then
      rke2lab::kube:apply_secret "${source_namespace}" "${tailscale_name}" "Opaque" "${tailscale_replicate_to}" \
        --from-literal=client_id="${tailscale_oauth_id}" \
        --from-literal=client_secret="${tailscale_oauth_token}"
    fi
    ;;
  cicd)
    tekton_git_name="$(yq eval -r '.kubernetes.secrets.tekton.git.name // "tekton-git-auth"' "${SECRETS_FILE}")"
    tekton_git_replicate_to="$(yq eval -r '.kubernetes.secrets.tekton.git.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
    tekton_git_username="$(yq eval -r '.tekton.git.username // ""' "${SECRETS_FILE}")"
    tekton_git_password="$(yq eval -r '.tekton.git.password // ""' "${SECRETS_FILE}")"
    if [[ -n "${tekton_git_username}" && -n "${tekton_git_password}" ]]; then
      rke2lab::kube:apply_secret "${source_namespace}" "${tekton_git_name}" "kubernetes.io/basic-auth" "${tekton_git_replicate_to}" \
        --from-literal=username="${tekton_git_username}" \
        --from-literal=password="${tekton_git_password}"
    fi

    tekton_docker_name="$(yq eval -r '.kubernetes.secrets.tekton.docker.name // "tekton-docker-config"' "${SECRETS_FILE}")"
    tekton_docker_replicate_to="$(yq eval -r '.kubernetes.secrets.tekton.docker.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
    tekton_docker_config="$(yq eval -r '.tekton.docker.configJson // ""' "${SECRETS_FILE}")"
    if [[ -n "${tekton_docker_config}" ]]; then
      rke2lab::kube:apply_secret "${source_namespace}" "${tekton_docker_name}" "kubernetes.io/dockerconfigjson" "${tekton_docker_replicate_to}" \
        --from-literal=.dockerconfigjson="${tekton_docker_config}"
    fi
    ;;
  runtime|gitops)
    porch_git_name="$(yq eval -r '.kubernetes.secrets.porch.git.name // "porch-git-auth"' "${SECRETS_FILE}")"
    porch_git_replicate_to="$(yq eval -r '.kubernetes.secrets.porch.git.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
    porch_git_username="$(yq eval -r '.porch.git.username // ""' "${SECRETS_FILE}")"
    porch_git_password="$(yq eval -r '.porch.git.password // ""' "${SECRETS_FILE}")"
    if [[ -n "${porch_git_username}" && -n "${porch_git_password}" ]]; then
      rke2lab::kube:apply_secret "${source_namespace}" "${porch_git_name}" "kubernetes.io/basic-auth" "${porch_git_replicate_to}" \
        --from-literal=username="${porch_git_username}" \
        --from-literal=password="${porch_git_password}"
    fi

    porch_ssh_name="$(yq eval -r '.kubernetes.secrets.porch.ssh.name // "porch-git-ssh"' "${SECRETS_FILE}")"
    porch_ssh_replicate_to="$(yq eval -r '.kubernetes.secrets.porch.ssh.replicateTo // [] | join(",")' "${SECRETS_FILE}")"
    porch_ssh_private_key="$(yq eval -r '.porch.ssh.privateKey // ""' "${SECRETS_FILE}")"
    porch_ssh_known_hosts="$(yq eval -r '.porch.ssh.knownHosts // ""' "${SECRETS_FILE}")"
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
    ;;
  *)
    log "Unknown layer '${layer}'"
    usage
    exit 1
    ;;
esac

set -x