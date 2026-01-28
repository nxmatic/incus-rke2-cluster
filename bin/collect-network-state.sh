#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: collect-network-state.sh [output_dir] [incus_project]

Arguments:
  output_dir     Optional. Defaults to "<repo>/.run.d/tshark".
  incus_project  Optional. Defaults to "${INCUS_PROJECT:-rke2}".

Environment variables:
  HOST_INTERFACE      Interface name to inspect on the host (default: enp0s3).
  INSTANCE_INTERFACE  Interface name to inspect inside Incus instances (default: wan0; set to lan0 for LAN focus).
  INCUS_PROJECT       Default Incus project name (overridden by argument #3).

The script captures networking state for the current host and every running
Incus instance in the chosen project. Results are written to a single report in
the output directory.
EOF
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_OUTPUT_DIR="${REPO_ROOT}/.run.d/tshark"
DEFAULT_INCUS_PROJECT="${INCUS_PROJECT:-rke2}"

output_dir="${1:-$DEFAULT_OUTPUT_DIR}"
incus_project="${2:-$DEFAULT_INCUS_PROJECT}"

HOST_INTERFACE="${HOST_INTERFACE:-enp0s3}"
INSTANCE_INTERFACE="${INSTANCE_INTERFACE:-wan0}"

mkdir -p "$output_dir"

now="$(date +%Y%m%d-%H%M%S)"
outfile="${output_dir}/${now}-network.txt"

if ! command -v dig >/dev/null 2>&1; then
  echo "[ERROR] dig is required" >&2
  exit 1
fi

INCUS_AVAILABLE=0
if command -v incus >/dev/null 2>&1; then
  INCUS_AVAILABLE=1
fi

HOST_COMMANDS=(
  "hostname|hostname"
  "uname|uname -a"
  "uptime|uptime"
  "dig example.com|dig +noall +short example.com A"
  "ip addr|ip addr show"
  "ip link|ip link show"
  "ip -s link|ip -s link"
  "ip route|ip route show"
  "ip rule|ip rule show"
  "ip neighbor|ip neigh show"
  "sysctl net.ipv4.ip_forward|sysctl net.ipv4.ip_forward"
  "sysctl net.ipv6.conf.all.forwarding|sysctl net.ipv6.conf.all.forwarding"
  "sysctl nf_conntrack stats|sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max"
  "nft list ruleset|sudo nft list ruleset"
  "iptables-save|sudo iptables-save"
  "conntrack -S|sudo conntrack -S"
  "ss -tnp|sudo ss -tnp"
  "ethtool ${HOST_INTERFACE}|sudo ethtool ${HOST_INTERFACE}"
  "ethtool -k ${HOST_INTERFACE}|sudo ethtool -k ${HOST_INTERFACE}"
  "bridge link|sudo bridge link"
  "bridge fdb show|sudo bridge fdb show"
)

if [[ $INCUS_AVAILABLE -eq 1 ]]; then
  HOST_COMMANDS+=(
    "incus project info|incus project show ${incus_project}"
    "incus list|incus list --project ${incus_project} --format yaml"
    "incus network list|incus network list --project ${incus_project} --format yaml"
  )
fi

INSTANCE_COMMANDS=(
  "hostname|hostname"
  "uname|uname -a"
  "uptime|uptime"
  "dig example.com|dig +noall +short example.com A"
  "ip addr|ip addr show"
  "ip link|ip link show"
  "ip -s link|ip -s link"
  "ip route|ip route show"
  "ip rule|ip rule show"
  "ip neighbor|ip neigh show"
  "sysctl net.ipv4.ip_forward|sysctl net.ipv4.ip_forward"
  "sysctl net.ipv6.conf.all.forwarding|sysctl net.ipv6.conf.all.forwarding"
  "sysctl nf_conntrack stats|sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max"
  "nft list ruleset|nft list ruleset"
  "iptables-save|iptables-save"
  "conntrack -S|conntrack -S"
  "ss -tnp|ss -tnp"
  "ethtool ${INSTANCE_INTERFACE}|ethtool ${INSTANCE_INTERFACE}"
  "ethtool -k ${INSTANCE_INTERFACE}|ethtool -k ${INSTANCE_INTERFACE}"
  "bridge link|bridge link"
  "bridge fdb show|bridge fdb show"
)

escape_yaml_string() {
  # Escape backslashes and double quotes for inclusion in YAML double-quoted strings
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

append_command_yaml() {
  local indent="$1"
  local name="$2"
  local cmd="$3"
  local status="$4"
  local output="$5"

  local escaped_cmd
  escaped_cmd="$(escape_yaml_string "$cmd")"

  cat <<EOF >>"$outfile"
${indent}- name: "$name"
${indent}  command: "$escaped_cmd"
${indent}  exit_status: $status
EOF

  if [[ -n "$output" ]]; then
    local formatted_output
    formatted_output="$(printf '%s\n' "$output" | sed "s/^/${indent}    /")"
    cat <<EOF >>"$outfile"
${indent}  output: |-
${formatted_output}
EOF
  else
    cat <<EOF >>"$outfile"
${indent}  output: ""
EOF
  fi
}

run_host_command() {
  local name="$1"
  local cmd="$2"
  local output status
  set +e
  output=$(bash -c "$cmd" 2>&1)
  status=$?
  set -e
  append_command_yaml "    " "$name" "$cmd" "$status" "$output"
}

run_instance_command() {
  local instance="$1"
  local name="$2"
  local cmd="$3"
  local output status
  set +e
  output=$(incus exec "$instance" -- sh -c "$cmd" 2>&1)
  status=$?
  set -e
  append_command_yaml "      " "$name" "$cmd" "$status" "$output"
}

INSTANCE_NAMES=()
if [[ $INCUS_AVAILABLE -eq 1 ]]; then
  mapfile -t INSTANCE_NAMES < <(incus list --project "$incus_project" --format csv -c ns | awk -F, '$2 == "RUNNING" { print $1 }') || true
fi

cat <<EOF >"$outfile"
timestamp: "$(date --iso-8601=seconds || date)"
hostname: "$(hostname)"
output_directory: "$output_dir"
incus_project: "$incus_project"
host_interface: "$HOST_INTERFACE"
instance_interface: "$INSTANCE_INTERFACE"
incus_available: $INCUS_AVAILABLE
host:
  commands:
EOF

for entry in "${HOST_COMMANDS[@]}"; do
  IFS='|' read -r title cmd <<<"$entry"
  run_host_command "$title" "$cmd"
done

if [[ $INCUS_AVAILABLE -eq 1 && ${#INSTANCE_NAMES[@]} -gt 0 ]]; then
  echo "instances:" >>"$outfile"
  for instance in "${INSTANCE_NAMES[@]}"; do
    cat <<EOF >>"$outfile"
  - name: "$instance"
    commands:
EOF
    for entry in "${INSTANCE_COMMANDS[@]}"; do
      IFS='|' read -r title cmd <<<"$entry"
      run_instance_command "$instance" "$title" "$cmd"
    done
  done
else
  echo "instances: []" >>"$outfile"
fi

echo "Network state written to $outfile"
