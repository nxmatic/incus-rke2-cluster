#!/usr/bin/env bash
# @codebase
# diagnostics-cilium-egress.sh
# Collects a focused snapshot of Cilium / egress state from an Incus RKE2 cluster node.
# Designed to be run from the host (where you can ssh to the lima VM and incus exec into containers).
#
# Usage:
#   scripts/diagnostics-cilium-egress.sh            # default node: master
#   NODE=peer1 scripts/diagnostics-cilium-egress.sh # override node name
#   OUTPUT=diag.txt scripts/diagnostics-cilium-egress.sh
#
# Requirements:
#   - ssh host alias "lima-nerd-nixos" must work (adjust HOST if different)
#   - incus CLI available on that host
#   - kubectl & cilium CLIs available inside the target container
#
# What it gathers:
#   - Environment (selected variables)
#   - Presence & contents of rendered Cilium manifest template
#   - HelmChartConfig & ConfigMap values for Cilium
#   - Cilium status key lines & agent config flags
#   - Interface & MTU info
#   - kube-proxy presence
#   - Basic egress curl to flox API (HTTPS test)
#   - Optional conntrack snapshot (if conntrack binary present)
#
# NOTE: This does NOT modify the cluster; purely read-only (except launching a temporary test pod if needed in the future).

set -euo pipefail

HOST=${HOST:-lima-nerd-nixos}
NODE=${NODE:-master}
OUT=${OUTPUT:-/dev/stdout}
TS=$(date -u +%Y%m%dT%H%M%SZ)
TMPDIR=$(mktemp -d)

log() { printf '[diag:%s] %s\n' "$TS" "$*" >&2; }

run_node() {
  # Run a single command inside the Incus container
  ssh "$HOST" incus exec "$NODE" -- bash -c "$1" 2>&1 || true
}

{
  echo "=== diagnostics-cilium-egress ($TS) node=$NODE ==="
  echo "-- environment (filtered) --"
  run_node "env | grep -E '^(CILIUM_PROFILE|CLUSTER_|RKE2_|PATH=)'"

  echo "-- profile selector script exists? --"
  run_node "ls -l /usr/local/sbin/rke2-cilium-profile-select || echo missing"

  echo "-- manifests dir listing --"
  run_node "ls -1 /var/lib/rancher/rke2/server/manifests 2>/dev/null || echo 'manifests dir missing'"

  echo "-- rendered cilium config head --"
  run_node "grep -m1 selected-cilium-profile /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml.tmpl || echo 'annotation-missing'; head -n 40 /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml.tmpl 2>/dev/null || echo 'config-tmpl-missing'"

  echo "-- helmchartconfig rke2-cilium (valuesContent snippet) --"
  run_node "kubectl -n kube-system get helmchartconfig rke2-cilium -o jsonpath='{.spec.valuesContent}' | sed 's/^/  /' || echo 'helmchartconfig-missing'"
  echo
  echo "-- cilium configmap key flags --"
  run_node "kubectl -n kube-system get cm cilium-config -o yaml 2>/dev/null | grep -E 'enable-l7-proxy|masquerade|bpf-masquerade|tunnel' || echo 'cilium-configmap-missing'"

  echo "-- kube-proxy pod(s) --"
  run_node "kubectl -n kube-system get pods -l k8s-app=kube-proxy -o wide || true"

  echo "-- cilium status (key lines) --"
  run_node "cilium status | egrep -i 'KubeProxyReplacement|Masquerading|Cilium:|IPAM:|DatapathMode|Routing:|L7' || true"

  echo "-- cilium agent runtime config (subset) --"
  run_node "cilium config view 2>/dev/null | egrep -i 'enable-l7|masquerade|kube-proxy-replacement|tunnel|mode' || true"

  echo "-- interfaces + MTU (lan0,wan0,cilium_*,vxlan*) --"
  run_node "ip -o link show | egrep -i 'lan0|wan0|cilium|vxlan' || true"

  echo "-- routes for pod/service CIDRs --"
  run_node "ip route | egrep '10\.42\.|10\.43\.' || true"

  echo "-- egress HTTPS test (flox API) --"
  run_node "timeout 12s curl -vk --connect-timeout 5 'https://api.flox.dev/api/v1/catalog/search?page=0&pageSize=1&search_term=flox&system=aarch64-linux' >/dev/null 2>&1 && echo 'curl: success' || echo 'curl: failed ($?)'"

  echo "-- conntrack snapshot for port 443 (if present) --"
  run_node "which conntrack >/dev/null 2>&1 && conntrack -L -p tcp --dport 443 2>/dev/null | head -n 30 || echo 'conntrack tool not available'"

  echo "-- systemd pre-start ordering evidence --"
  run_node "systemctl cat rke2-server.service 2>/dev/null | grep -n 'ExecStartPre' || echo 'systemctl-cat-unavailable'"

  echo "-- done --"
} >"$OUT"

log "Diagnostics complete. Output -> $OUT"

# If writing to a file, keep a copy in temp for convenience
if [[ "$OUT" != /dev/stdout ]]; then
  cp "$OUT" "$TMPDIR/diag.txt" || true
  log "Temp copy: $TMPDIR/diag.txt"
fi
