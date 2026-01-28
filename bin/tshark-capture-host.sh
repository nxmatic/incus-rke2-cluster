#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: tshark-capture-host.sh [remote_host_or_ip] [label] [output_dir] [duration_seconds] [interface]

Arguments:
  remote_host_or_ip Optional. Hostname or IPv4 address to filter. Defaults to "example.com".
  label             Optional. Defaults to "baseline". Used in filenames.
  output_dir        Optional. Defaults to "<repo>/.run.d/tshark".
  duration_seconds  Optional. Defaults to 0 (run until stopped). Uses tshark -a duration when >0.
  interface         Optional. Defaults to "bridge100".

The script starts tshark in the background, writes PCAP+log files, and records the PID.
Requires: dig (BIND utilities) for hostname resolution.
EOF
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_OUTPUT_DIR="${REPO_ROOT}/.run.d/tshark"

remote_target="${1:-example.com}"
label="${2:-baseline}"
output_dir="${3:-$DEFAULT_OUTPUT_DIR}"
duration="${4:-0}"
iface="${5:-bridge100}"

resolve_ipv4() {
  local target="$1"
  if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s' "$target"
    return 0
  fi

  if ! command -v dig >/dev/null 2>&1; then
    echo "dig is required to resolve hostnames" >&2
    exit 1
  fi

  local dig_ip
  dig_ip="$(dig +noall +short "$target" A | head -n1)"
  if [[ -z "$dig_ip" ]]; then
    echo "Failed to resolve IPv4 for $target via dig" >&2
    exit 1
  fi

  printf '%s' "$dig_ip"
}

remote_ip="$(resolve_ipv4 "$remote_target")"

if [[ -z "$remote_ip" ]]; then
  exit 1
fi

mkdir -p "$output_dir"

timestamp() {
  date "+%Y-%m-%dT%H:%M:%S%z"
}

now="$(date +%Y%m%d-%H%M%S)"
pcap="${output_dir}/${now}-${label}-host.pcapng"
log="${output_dir}/${now}-${label}-host.log"
pid_file="${output_dir}/${now}-${label}-host.pid"
default_pid_file="${DEFAULT_OUTPUT_DIR}/${now}-${label}-host.pid"
latest_pid_file="${DEFAULT_OUTPUT_DIR}/latest-host.pid"

bpf="host ${remote_ip} and port 443"

capture_cmd=(sudo tshark -i "$iface" -f "$bpf" -w "$pcap")
if [[ "$duration" -gt 0 ]]; then
  capture_cmd=(sudo tshark -i "$iface" -f "$bpf" -a "duration:${duration}" -w "$pcap")
fi

{
  echo "[$(timestamp)] Starting capture"
  echo "Interface: $iface"
  echo "Remote target: $remote_target"
  echo "Resolved IPv4: $remote_ip"
  echo "Label: $label"
  echo "PCAP: $pcap"
  echo "Command: ${capture_cmd[*]}"
} >>"$log"

"${capture_cmd[@]}" >>"$log" 2>&1 &
cap_pid=$!
echo "$cap_pid" >"$pid_file"
mkdir -p "${DEFAULT_OUTPUT_DIR}"
echo "$cap_pid" >"$default_pid_file"
echo "$cap_pid" >"$latest_pid_file"

echo "[$(timestamp)] Capture PID: $cap_pid" >>"$log"

echo "Capture started in background."
echo "PCAP: $pcap"
echo "Log: $log"
echo "PID: $cap_pid (saved to $pid_file)"
