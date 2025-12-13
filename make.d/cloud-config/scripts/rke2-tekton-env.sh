#!/usr/bin/env -S bash -eu -o pipefail
# Populate Tekton setter defaults if not already defined (@codebase)

env_file="/etc/rancher/rke2/environment"
[[ -s "${env_file}" ]] || exit 0

if grep -q '^: "${TEKTON_GIT_USERNAME' "${env_file}"; then
  exit 0
fi

cat <<'EoEnvDefaults' >> "${env_file}"
# Tekton setter defaults derived from cluster bootstrap env
: "${TEKTON_GIT_USERNAME:=${CLUSTER_GITHUB_USERNAME:-x-access-token}}"
: "${TEKTON_GIT_PASSWORD:=${CLUSTER_GITHUB_TOKEN:-}}"
: "${TEKTON_GIT_URL:=https://${CLUSTER_GITHUB_HOST:-github.com}}"
: "${TEKTON_DOCKER_CONFIG_JSON:=${CLUSTER_DOCKER_CONFIG_JSON:-}}"
: "${TEKTON_DOCKER_REGISTRY_URL:=${CLUSTER_DOCKER_REGISTRY_URL:-https://index.docker.io/v1/}}"
EoEnvDefaults
