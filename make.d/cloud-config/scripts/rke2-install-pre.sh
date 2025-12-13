#!/usr/bin/env -S bash -exu -o pipefail

: "Generate /etc/rancher/rke2/environment from init process early"
mkdir -p /etc/rancher/rke2
cat <<EoE > /etc/rancher/rke2/environment
$( cat /proc/1/environ | tr '\0' '\n' )
EoE
set -a
source /etc/rancher/rke2/environment
set +a

LIBRARY_DIR="/var/lib/rancher/rke2"
: "Configure direnv to use flox"
direnv:config:generate() {
  mkdir -p "/root/.config/direnv/lib"
  curl -o \
    "/root/.config/direnv/lib/flox.sh" \
    "https://raw.githubusercontent.com/flox/flox-direnv/v1.1.0/direnv.rc"
  cat <<EoConfig | cut -c 3- > "/root/.config/direnv/direnv.toml"
  [whitelist]
  prefix= [ "/home", "/root", "/var/lib/cloud/seed/nocloud", "/var/lib/rancher/rke2", ]
EoConfig
}
direnv:config:generate

: "Preload the nocloud environment"
nocloud:env:generate() {
  local FLOX_ENV_DIR="/var/lib/cloud/seed/nocloud"
  echo "${FLOX_ENV_DIR}"
  [[ -d "${FLOX_ENV_DIR}/.flox" ]] && return 0
  mkdir -p "${FLOX_ENV_DIR}"
  flox init \
    --dir="${FLOX_ENV_DIR}"
  flox install \
    --dir="${FLOX_ENV_DIR}" \
    dasel git gh yq-go
}
source <( flox activate --dir="$( nocloud:env:generate )" )

cat > /var/lib/cloud/seed/nocloud/.envrc <<'EoEnvrc'
  log_status "Loading nocloud environment variables"

  # Variables are loaded directly in flox profile-common.sh
  # Just activate flox environment
  [[ "$FLOX_ENV_PROJECT" != "$PWD" ]] &&
    use flox
EoEnvrc
dasel -r toml -w yaml \
  < /var/lib/cloud/seed/nocloud/.flox/env/manifest.toml |
  yq eval '.profile = { "common": "source /var/lib/cloud/seed/nocloud/.flox/env/profile-common.sh" }' - |
  dasel --pretty -r yaml -w toml | tee /tmp/manifest.toml.$ &&
  mv /tmp/manifest.toml.$ \
    /var/lib/cloud/seed/nocloud/.flox/env/manifest.toml
cat <<'EoFloxCommonProfile' | cut -c 3- | tee /var/lib/cloud/seed/nocloud/.flox/env/profile-common.sh
  : "Load environment variables from /etc/rancher/rke2/environment"
  set -a

  : "Source RKE2 environment file if available"
  [[ -f /etc/rancher/rke2/environment ]] && source /etc/rancher/rke2/environment

  if command -v ip >/dev/null; then
    CLUSTER_GATEWAY=$( ip route show default 2>/dev/null | 
                        awk '/default via/ { print $3; exit }' || 
                        true )
  fi

  set +a
EoFloxCommonProfile
source <( env FLOX_ACTIVATE_TRACE=1 flox activate --dir=/var/lib/cloud/seed/nocloud )

: "GitHub authentication setup"
gh auth login --with-token <<EoF
${CLUSTER_GITHUB_TOKEN}
EoF
gh auth setup-git --hostname "${CLUSTER_GITHUB_HOST:-github.com}"\

: "Initialize the flox environment for RKE2"
[[ ! -d /var/lib/rancher/rke2/.flox ]] &&
  flox init --dir=/var/lib/rancher/rke2

flox install \
  --dir=/var/lib/rancher/rke2 \
  ceph-client cilium-cli etcdctl helmfile \
  kubernetes-helm kubectl # override

: "Install kpt v1 in isolated group to avoid dependency conflicts"
flox install \
  --dir=/var/lib/rancher/rke2 \
  kpt

: "Include cloud environment in RKE2 flox environment and configure groups"
dasel -r toml -w yaml \
  < /var/lib/rancher/rke2/.flox/env/manifest.toml |
  yq eval '.include = {"environments": [{"dir": "/var/lib/cloud/seed/nocloud"}]}' - |
  yq eval '.install += {"nerdctl": {"pkg-path": "nerdctl", "version": "1.7.5", "pkg-group": "containerd-tools", "systems": ["aarch64-linux"]}}' - |
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
  yq eval '.profile = {"common": "source /var/lib/rancher/rke2/.flox/env/profile-common.sh"}' - |
  dasel --pretty -r yaml -w toml | tee /tmp/manifest.toml.$ &&
  mv /tmp/manifest.toml.$ \
    /var/lib/rancher/rke2/.flox/env/manifest.toml
  cat <<'EoFloxCommonProfile' | cut -c 3- | tee /var/lib/rancher/rke2/.flox/env/profile-common.sh
  : "Load environment variables from /etc/rancher/rke2/environment"
  set -a
  
  : "Source RKE2 environment file \(generated from Incus instance config\)"
  [[ -f /etc/rancher/rke2/environment ]] && source /etc/rancher/rke2/environment

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
source <( flox activate --dir /var/lib/rancher/rke2 )

: "Initialize krew and install plugins"
KREW_ROOT="/var/lib/rancher/rke2/krew"
mkdir -p "$KREW_ROOT"

: "Install krew plugins using krew directly"
for plugin in ctx ns; do
  krew install "$plugin" || true
done
