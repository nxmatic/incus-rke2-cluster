#!/usr/bin/env -S bash -exu -o pipefail


: "Load RKE2 environment" # @codebase
RKE2LAB_ROOT=${RKE2LAB_ROOT:-/srv/host}
RKE2LAB_ENV_FILE=${RKE2LAB_ENV_FILE:-${RKE2LAB_ROOT}/environment}
[[ ! -r "${RKE2LAB_ENV_FILE}" ]] && {
  echo "[common-profile] missing environment file: ${RKE2LAB_ENV_FILE}" >&2
  exit 1
}

set -a
source "${RKE2LAB_ENV_FILE}"
set +a

: "Set flox target system for this host"
RKE2_FLOX_SYSTEM="$(uname -m)-linux"
export RKE2_FLOX_SYSTEM

: "Configure direnv to use flox"
direnv:config:generate() {
  mkdir -p "/root/.config/direnv/lib"
  curl -o \
    "/root/.config/direnv/lib/flox.sh" \
    "https://raw.githubusercontent.com/flox/flox-direnv/v1.1.0/direnv.rc"
  cat <<EoConfig | cut -c 3- > "/root/.config/direnv/direnv.toml"
  [whitelist]
  prefix= [ "/home", "/root", "/var/lib/cloud", "/var/lib/rancher/rke2", "${RKE2LAB_ROOT}" ]
EoConfig
}
direnv:config:generate

: "Preload manifest tools in a temporary flox env"
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

flox config --set disable_metrics true
flox init --dir="${TMPDIR}"
flox install --dir="${TMPDIR}" dasel yq-go
source <( flox activate --dir="${TMPDIR}" )

: "Preload the nocloud environment"
nocloud:env:activate() {
  local FLOX_ENV_DIR="/var/lib/cloud"
  if [[ -d "${FLOX_ENV_DIR}/.flox" ]]; then
	source <( flox activate --dir="${FLOX_ENV_DIR}" )
	return
  fi

  : "Initialize flox environment for nocloud"
  mkdir -p "${FLOX_ENV_DIR}"
  flox init --dir="${FLOX_ENV_DIR}"
  flox install --dir="${FLOX_ENV_DIR}" dasel yq-go

  : "Include common profile in manifest and activate flox environment"
  cat <<'EoFloxCommonProfile' | cut -c 3- | tee "${FLOX_ENV_DIR}/.flox/env/profile-common.sh"

  rke2lab::shell:indirect() {
    local var="$1" value=""

    set +u
    if [[ -n "${BASH_VERSION:-}" ]]; then
      value="${!var-}"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
      # shellcheck disable=SC2296
      value="${(P)var:-}"
    else
      echo "ERROR: Unsupported shell for secret loading" >&2
      set -u
      return 1
    fi
    set -u

    printf '%s\n' "${value}"
  }

  rke2lab::secret:value() {
    local var="$1" key="$2" val

    val="$( rke2lab::shell:indirect "${var}" )"

    if [[ -z "$val" ]]; then
      val=$( "${FLOX_ENV}/bin/yq" -r "${key}" "${RKE2LAB_ROOT}/secrets" 2>/dev/null )
    fi
    
    [[ -z "$val" ]] && return  
    export "$var=$val"
  }
  
  RKE2LAB_ROOT=${RKE2LAB_ROOT:-/srv/host}
  RKE2LAB_ENV_FILE=${RKE2LAB_ENV_FILE:-${RKE2LAB_ROOT}/environment}

  set -a
  
  : "Source RKE2 environment file"
  source "${RKE2LAB_ENV_FILE}"

  : "Load RKE2-specific dynamic environment variables"
  ARCH="$(dpkg --print-architecture)"

  : "Backfill secrets from ${RKE2LAB_ROOT}/secrets if not already set (local yq wrapper)"
  rke2lab::secret:value GITHUB_USERNAME '.github.username'
  rke2lab::secret:value GITHUB_PAT '.github.token'
  rke2lab::secret:value DOCKER_CONFIG_JSON '.docker.configJson'	
  rke2lab::secret:value TEKTON_GIT_USERNAME '.tekton.git.username'
  rke2lab::secret:value TEKTON_GIT_PASSWORD '.tekton.git.password'
  rke2lab::secret:value TEKTON_DOCKER_CONFIG_JSON '.tekton.docker.configJson'
  rke2lab::secret:value TEKTON_DOCKER_REGISTRY_URL '.tekton.docker.registryUrl'	
  rke2lab::secret:value TSKEY_CLIENT_ID '.tailscale.client.id'
  rke2lab::secret:value TSKEY_CLIENT_TOKEN '.tailscale.client.token'
  rke2lab::secret:value TSKEY_API_ID '.tailscale.api.id'
  rke2lab::secret:value TSKEY_API_TOKEN '.tailscale.api.token'	
  rke2lab::secret:value TSKEY_OAUTH_ID '.tailscale.oauth.id' 
  rke2lab::secret:value TSKEY_OAUTH_TOKEN '.tailscale.oauth.token' 

  : "Determine default gateway IP for cluster networking"
  CLUSTER_GATEWAY=$( ip route show default 2>/dev/null | 
                      awk '/default via/ { print $3; exit }' || 
                      true )

  set +a
EoFloxCommonProfile

  dasel -r toml -w yaml < "${FLOX_ENV_DIR}/.flox/env/manifest.toml" |
    yq eval '.options = {"systems": [env(RKE2_FLOX_SYSTEM)]}' - |
    yq eval '.profile = { "common": "source ${FLOX_ENV_PROJECT}/.flox/env/profile-common.sh" }' - |
    dasel --pretty -r yaml -w toml | tee /tmp/manifest.toml.$$ &&
    mv /tmp/manifest.toml.$$ "${FLOX_ENV_DIR}/.flox/env/manifest.toml"
  source <( flox activate --dir="${FLOX_ENV_DIR}" )

  : "Install GitHub CLI in nocloud flox environment"
  flox install --dir="${FLOX_ENV_DIR}" git gh@2.86

  : "Generate nocloud envrc to load environment variables"
  cat > /var/lib/cloud/.envrc <<'EoEnvrc'
  log_status "Loading nocloud environment variables"

  [[ "$FLOX_ENV_PROJECT" != "$PWD" ]] &&
    use flox
EoEnvrc
  ln -sf /var/lib/cloud/.envrc /var/lib/cloud/seed/nocloud/.envrc
}

: "Activate the nocloud environment"
nocloud:env:activate

: "Bootstrap /srv/host/secrets from flox-loaded env vars" # @codebase
SECRETS_FILE="${RKE2LAB_ROOT}/secrets"
mkdir -p "$(dirname "${SECRETS_FILE}")"
[[ -s "${SECRETS_FILE}" ]] || printf '%s\n' '{}' > "${SECRETS_FILE}"

secret:file:update() {
  local key="$1" var="$2" val

  set +u
  val="${!var-}"
  set -u

  [[ -z "${val}" ]] && return 0
  export "${var}=${val}"
  yq eval -i ".${key} = strenv(${var})" "${SECRETS_FILE}"
}

secret:file:update 'github.username' GITHUB_USERNAME
secret:file:update 'github.token' GITHUB_PAT
secret:file:update 'docker.configJson' DOCKER_CONFIG_JSON
secret:file:update 'tekton.git.username' TEKTON_GIT_USERNAME
secret:file:update 'tekton.git.password' TEKTON_GIT_PASSWORD
secret:file:update 'tekton.docker.configJson' TEKTON_DOCKER_CONFIG_JSON
secret:file:update 'tekton.docker.registryUrl' TEKTON_DOCKER_REGISTRY_URL
secret:file:update 'tailscale.client.id' TSKEY_CLIENT_ID
secret:file:update 'tailscale.client.token' TSKEY_CLIENT_TOKEN
secret:file:update 'tailscale.api.id' TSKEY_API_ID
secret:file:update 'tailscale.api.token' TSKEY_API_TOKEN

chmod 0600 "${SECRETS_FILE}"
unset secret:file:update

: "GitHub authentication setup"
gh auth login --with-token <<EoF
${GITHUB_PAT}
EoF
gh auth setup-git --hostname "${GITHUB_HOST:-github.com}"\

: "Configure ghcr registry access for containerd" # @codebase
CONTAINERD_REG_FILE="/etc/rancher/rke2/registries.yaml"
if [[ ! -f "${CONTAINERD_REG_FILE}" ]]; then
  : "[rke2-install-pre] registries.yaml not present; creating"
  mkdir -p "$(dirname "${CONTAINERD_REG_FILE}")"
  cat >"${CONTAINERD_REG_FILE}" <<EoF | cut -c 3- 
  mirrors:
    ghcr.io:
      endpoint:
        - https://ghcr.io
  configs:
    "ghcr.io":
      auth:
        username: ${GITHUB_USERNAME}
        password: ${GITHUB_PAT}
EoF
  chmod 0644 "${CONTAINERD_REG_FILE}"
fi


: "Initialize the flox environment for RKE2"
[[ ! -d /var/lib/rancher/rke2/.flox ]] &&
  flox init --dir=/var/lib/rancher/rke2

: "Include cloud environment in RKE2 flox environment and configure groups"
dasel -r toml -w yaml \
  < /var/lib/rancher/rke2/.flox/env/manifest.toml |
  yq eval '.options = {"systems": [env(RKE2_FLOX_SYSTEM)]}' - |
  yq eval '.include = {"environments": [{"dir": "/var/lib/cloud"}]}' - |
  yq eval '.install += {"etcdctl": {"pkg-path": "etcdctl", "pkg-group": "etcd-tools"}}' - |	
  yq eval '.install += {"ceph-client": {"pkg-path": "ceph-client", "pkg-group": "ceph-tools"}}' - |
  yq eval '.install += {"cilium-cli": {"pkg-path": "cilium-cli", "pkg-group": "cilium-tools"}}' - |	
  yq eval '.install += {"helmfile": {"pkg-path": "helmfile", "pkg-group": "helm-tools"}}' - |
  yq eval '.install += {"kubernetes-helm": {"pkg-path": "kubernetes-helm", "pkg-group": "helm-tools"}}' - |	
  yq eval '.install += {"zfs": {"pkg-path": "zfs", "pkg-group": "linux"}}' - |
  yq eval '.install += {"nerdctl": {"pkg-path": "nerdctl", "version": "1.7.5", "pkg-group": "containerd-tools"}}' - |
  yq eval '.install += {"tektoncd-cli": {"pkg-path": "tektoncd-cli", "pkg-group": "tekton-tools"}}' - |	
  yq eval '.install += {"kubectl": {"pkg-path": "kubectl", "pkg-group": "kubectl-tools"}}' - |
  yq eval '.install += {"krew": {"pkg-path": "krew", "pkg-group": "kubectl-tools"}}' - |
  yq eval '.install += {"kubectl-ai": {"pkg-path": "kubectl-ai", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-ktop": {"pkg-path": "kubectl-ktop", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-neat": {"pkg-path": "kubectl-neat", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-tree": {"pkg-path": "kubectl-tree", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-graph": {"pkg-path": "kubectl-graph", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-doctor": {"pkg-path": "kubectl-doctor", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-explore": {"pkg-path": "kubectl-explore", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-rook-ceph": {"pkg-path": "kubectl-rook-ceph", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"kubectl-view-secret": {"pkg-path": "kubectl-view-secret", "pkg-group": "kubectl-plugins"}}' - |
  yq eval '.install += {"tubekit": {"pkg-path": "tubekit", "pkg-group": "kubectl-tools"}}' - |
  yq eval '.install += {"yq-go": {"pkg-path": "yq-go", "pkg-group": "yaml-tools"}}' - |
  yq eval '.install += {"kpt": {"pkg-path": "kpt", "version": "1.0.0-beta.55", "pkg-group": "kpt-tools"}}' - |
  yq eval '.install += {"delta": {"pkg-path": "delta", "pkg-group": "diff-tools"}}' - |
  yq eval '.install += {"direnv": {"pkg-path": "direnv", "pkg-group": "direnv-tools"}}' - |
  yq eval '.install += {"xstow": {"pkg-path": "xstow", "pkg-group": "stow-tools"}}' - |
  yq eval '.profile = {"common": "source /var/lib/rancher/rke2/.flox/env/profile-common.sh"}' - |
  dasel --pretty -r yaml -w toml | tee /tmp/manifest.toml.$$ &&
  mv /tmp/manifest.toml.$$ \
    /var/lib/rancher/rke2/.flox/env/manifest.toml
  cat <<'EoFloxCommonProfile' | cut -c 3- | tee /var/lib/rancher/rke2/.flox/env/profile-common.sh
  : "Load nocloud environment from the common profile"
  source "/var/lib/cloud/.flox/env/profile-common.sh" 
 
   : "Create kubectl symlinks for the tekton cli"
  ln -sf "$(command -v tkn)" /usr/local/bin/kubectl-tkn || true

  set -a
  : "Load RKE2-specific dynamic environment variables"
  ARCH="$(dpkg --print-architecture)"
  [[ -r /etc/rancher/rke2/rke2.yaml ]] &&
    KUBECONFIG="/etc/rancher/rke2/rke2.yaml"

  : "Default cache for kubectl/kpt"
  KUBECACHEDIR="${KUBECACHEDIR:-${FLOX_RUNTIME_DIR:-/run/user/0}/kube-cache}"
  mkdir -p "${KUBECACHEDIR}"

  : "Set KREW_ROOT if not already set"
  KREW_ROOT="${KREW_ROOT:-/var/lib/rancher/rke2/krew}"

  : "Update PATH with RKE2 tools"
  PATH="/var/lib/rancher/rke2/bin:$PATH:${KREW_ROOT}/bin"
  set +a
EoFloxCommonProfile

: "Load the RKE2 envrc"
source <( flox activate --dir="/var/lib/rancher/rke2" )

: "Initialize krew and install plugins"
KREW_ROOT="/var/lib/rancher/rke2/krew"
mkdir -p "$KREW_ROOT"

: "Install krew plugins using krew directly"
for plugin in ctx ns; do
  krew install "$plugin" || true
done
