#!/usr/bin/env bash
# @codebase
# analyze-cilium-sysdump.sh
# Summarize and diff two Cilium sysdumps for egress / routing / NAT diagnostics.
#
# Usage:
#   scripts/analyze-cilium-sysdump.sh --before path/to/before.zip --after path/to/after.zip
#   scripts/analyze-cilium-sysdump.sh --only path/to/sysdump.zip   # single summary
#
# Output: Human readable report to stdout.
#
# Focus Areas:
#   - Runtime config deltas (masquerade, kube-proxy replacement, tunneling, L7 proxy)
#   - Routing table (main + table 2004) changes
#   - IPCache additions/removals (node + pod CIDRs)
#   - Endpoint count & failed regenerations
#   - Service/LB map deltas
#   - BPF ct global stats (UNREPLIED growth)
#   - MTU/interface differences (lan0, wan0, cilium_host, vxlan.*)
#   - Presence/absence of BPF NAT map vs iptables MASQUERADE
#
# Requirements:
#   - unzip, grep, awk, sed, diff
#
set -euo pipefail

BEFORE=""; AFTER=""; ONLY="";
while [[ $# -gt 0 ]]; do
  case "$1" in
    --before) BEFORE=$2; shift 2;;
    --after) AFTER=$2; shift 2;;
    --only) ONLY=$2; shift 2;;
    -h|--help) sed -n '1,60p' "$0"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "$ONLY" && -z "$BEFORE" ]]; then
  echo "Error: provide --only zip OR --before and --after" >&2; exit 1
fi
if [[ -n "$ONLY" && ( -n "$BEFORE" || -n "$AFTER" ) ]]; then
  echo "Error: use either --only or the pair --before/--after" >&2; exit 1
fi
if [[ -n "$BEFORE" && -z "$AFTER" ]]; then
  echo "Error: --after required with --before" >&2; exit 1
fi

workdir=$(mktemp -d)
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

extract_zip() {
  local zip=$1
  local out=$2
  mkdir -p "$out"
  unzip -qq "$zip" -d "$out"
  # Find the agent subdir (cilium-bugtool-cilium-*)
  local agent
  agent=$(find "$out" -maxdepth 3 -type d -name 'cilium-bugtool-cilium-*' | head -n1)
  if [[ -z "$agent" ]]; then
    echo "ERR:no_agent_dir"; return 1
  fi
  echo "$agent/cmd"
}

collect_summary() {
  local cmdDir=$1
  local tag=$2
  local out=$3
  # Allow non-zero commands inside summary without aborting whole script
  set +e
  {
    echo "### SUMMARY:$tag" || true
    echo "-- runtime config (filtered) --" || true
    [[ -f $cmdDir/cilium-dbg-config--a.md ]] && grep -E '^(EnableBPFMasquerade|EnableIPv4Masquerade|KubeProxyReplacement|EnableL7Proxy|DatapathMode|Routing|EnableBGPControlPlane|EnableL2Announcements|EnableIPv6|TunnelProtocol?)' "$cmdDir"/cilium-dbg-config--a.md || true

    echo "-- status key lines --" || true
    [[ -f $cmdDir/cilium-dbg-status---verbose.md ]] && egrep -i 'KubeProxyReplacement|Masquerading|Cilium:|IPAM:' "$cmdDir"/cilium-dbg-status---verbose.md || true

    echo "-- endpoint count --" || true
    local epfile="$cmdDir"/cilium-dbg-endpoint-list.md
    if [[ -f $epfile ]]; then
      local epcount
      epcount=$(grep -E '^Endpoint' -n "$epfile" | wc -l | awk '{print $1}')
      echo "endpoints_total=$epcount" || true
      grep -i 'policy.*fail' "$epfile" || true
    fi

    echo "-- ipcaches (first 25) --" || true
    [[ -f $cmdDir/cilium-dbg-bpf-ipcache-list.md ]] && head -n 25 "$cmdDir"/cilium-dbg-bpf-ipcache-list.md || true

    echo "-- routes (main, filtered pods/services) --" || true
    [[ -f $cmdDir/ip--4-r.md ]] && grep -E '10\.42\.|10\.43\.' "$cmdDir"/ip--4-r.md || true
    echo "-- table 2004 --" || true
    [[ -f $cmdDir/ip--4-route-show-table-2004.md ]] && cat "$cmdDir"/ip--4-route-show-table-2004.md || true

    echo "-- interfaces (MTU subset) --" || true
  [[ -f $cmdDir/ip-a.md ]] && grep -E 'mtu' "$cmdDir"/ip-a.md | grep -E 'lan0|wan0|cilium|vxlan' || true

    echo "-- services (first 15) --" || true
    [[ -f $cmdDir/cilium-dbg-service-list.md ]] && head -n 17 "$cmdDir"/cilium-dbg-service-list.md || true

    echo "-- bpf ct stats sample --" || true
    [[ -f $cmdDir/cilium-dbg-bpf-ct-list-global--time-diff.md ]] && head -n 40 "$cmdDir"/cilium-dbg-bpf-ct-list-global--time-diff.md || true

    echo "-- lb frontends/backends counts --" || true
    # Count real entries (skip header line). Provide 0 if file missing.
    for f in cilium-dbg-bpf-lb-list---frontends.md cilium-dbg-bpf-lb-list---backends.md; do
      if [[ -f $cmdDir/$f ]]; then
        local count
        count=$(grep -v '^SERVICE ADDRESS' "$cmdDir/$f" | grep -v '^ID   ' | grep -E '^[0-9A-Fa-f.:]+|^[0-9]+\s' || true | wc -l | awk '{print $1}')
        echo "$f: $count"
      else
        echo "$f: missing"
      fi
    done

    # Emit warning if L7 proxy enabled while kube-proxy replacement disabled (often unintended in minimal profile)
    if [[ -f $cmdDir/cilium-dbg-config--a.md ]]; then
      local l7 enabledKPR
      l7=$(grep -E '^EnableL7Proxy' "$cmdDir/cilium-dbg-config--a.md" | awk '{print $3}' || true)
      enabledKPR=$(grep -E '^KubeProxyReplacement' "$cmdDir/cilium-dbg-config--a.md" | awk '{print $3}' || true)
      if [[ "$l7" == "true" || "$l7" == "True" ]] && ([[ "$enabledKPR" == "false" ]] || [[ -z "$enabledKPR" ]]); then
        echo "WARNING: EnableL7Proxy=true while KubeProxyReplacement is disabled. Verify this is intentional for the selected profile." >&2
        echo "L7ProxyWarning: EnableL7Proxy=true & KubeProxyReplacement=false" || true
      fi
    fi

    echo "-- NAT map presence --" || true
    if [[ -f $cmdDir/cilium-dbg-bpf-nat-list.md ]] && grep -qi 'Unable to open' "$cmdDir"/cilium-dbg-bpf-nat-list.md 2>/dev/null; then
      echo 'bpf-nat-map:absent_or_disabled' || true
    else
      [[ -f $cmdDir/cilium-dbg-bpf-nat-list.md ]] && head -n 5 "$cmdDir"/cilium-dbg-bpf-nat-list.md || echo 'nat-map:missing'
    fi

    echo "-- fqdn cache (first 10) --" || true
    [[ -f $cmdDir/cilium-dbg-fqdn-cache-list.md ]] && head -n 12 "$cmdDir"/cilium-dbg-fqdn-cache-list.md || true
  } > "$out"
  set -e
  [[ ${DEBUG:-0} -eq 1 ]] && echo "[debug] wrote $(wc -l < "$out") lines to $out" >&2 || true
}

if [[ -n "$ONLY" ]]; then
  cmdDir=$(extract_zip "$ONLY" "$workdir/only")
  collect_summary "$cmdDir" "ONLY" "$workdir/only.summary"
  if [[ ! -s $workdir/only.summary ]]; then
    echo "WARNING: summary empty (possible missing files)" >&2
  fi
  cat "$workdir/only.summary"
  exit 0
fi

beforeCmd=$(extract_zip "$BEFORE" "$workdir/before")
afterCmd=$(extract_zip "$AFTER" "$workdir/after")
collect_summary "$beforeCmd" BEFORE "$workdir/before.summary"
collect_summary "$afterCmd" AFTER  "$workdir/after.summary"

# Produce comparison
echo '### DIFF: runtime config flags' 
# Narrow diff to lines with key toggles
grep -E 'EnableBPFMasquerade|EnableIPv4Masquerade|KubeProxyReplacement|EnableL7Proxy|DatapathMode|EnableBGPControlPlane|EnableL2Announcements' "$beforeCmd"/cilium-dbg-config--a.md > "$workdir/b.config"
grep -E 'EnableBPFMasquerade|EnableIPv4Masquerade|KubeProxyReplacement|EnableL7Proxy|DatapathMode|EnableBGPControlPlane|EnableL2Announcements' "$afterCmd"/cilium-dbg-config--a.md  > "$workdir/a.config"
(diff -u "$workdir/b.config" "$workdir/a.config" || true)

echo '### DIFF: routes (main filtered)'
grep -E '10\.42\.|10\.43\.' "$beforeCmd"/ip--4-r.md > "$workdir/b.routes" || true
grep -E '10\.42\.|10\.43\.' "$afterCmd"/ip--4-r.md  > "$workdir/a.routes" || true
(diff -u "$workdir/b.routes" "$workdir/a.routes" || true)

echo '### DIFF: table 2004'
(diff -u "$beforeCmd"/ip--4-route-show-table-2004.md "$afterCmd"/ip--4-route-show-table-2004.md || true)

echo '### DIFF: ipcache (first 120 lines)'
head -n 120 "$beforeCmd"/cilium-dbg-bpf-ipcache-list.md > "$workdir/b.ipc" || true
head -n 120 "$afterCmd"/cilium-dbg-bpf-ipcache-list.md  > "$workdir/a.ipc" || true
(diff -u "$workdir/b.ipc" "$workdir/a.ipc" || true)

echo '### DIFF: endpoint list header section'
head -n 80 "$beforeCmd"/cilium-dbg-endpoint-list.md > "$workdir/b.ep" || true
head -n 80 "$afterCmd"/cilium-dbg-endpoint-list.md  > "$workdir/a.ep" || true
(diff -u "$workdir/b.ep" "$workdir/a.ep" || true)

echo '### DIFF: lb frontends'
if [[ ! -s "$beforeCmd"/cilium-dbg-bpf-lb-list---frontends.md && ! -s "$afterCmd"/cilium-dbg-bpf-lb-list---frontends.md ]]; then
  echo '(no frontends files present)' 
fi
(diff -u "$beforeCmd"/cilium-dbg-bpf-lb-list---frontends.md "$afterCmd"/cilium-dbg-bpf-lb-list---frontends.md || true)

echo '### DIFF: lb backends'
if [[ ! -s "$beforeCmd"/cilium-dbg-bpf-lb-list---backends.md && ! -s "$afterCmd"/cilium-dbg-bpf-lb-list---backends.md ]]; then
  echo '(no backends files present)' 
fi
(diff -u "$beforeCmd"/cilium-dbg-bpf-lb-list---backends.md "$afterCmd"/cilium-dbg-bpf-lb-list---backends.md || true)

echo '### BEFORE SUMMARY' 
if [[ ! -s $workdir/before.summary ]]; then
  echo "WARNING: BEFORE summary empty" >&2
fi
cat "$workdir/before.summary"

echo '### AFTER SUMMARY' 
if [[ ! -s $workdir/after.summary ]]; then
  echo "WARNING: AFTER summary empty" >&2
fi
cat "$workdir/after.summary"
