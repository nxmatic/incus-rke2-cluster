#!/usr/bin/env bash
# @codebase
# Preflight network diagnostics for Incus RKE2 nodes.
# Performs lightweight checks intended to surface host-level egress
# problems (e.g., stalled nftables state, broken MASQUERADE, BPF pin
# mount issues) BEFORE starting additional control-plane nodes.
#
# Safe to run multiple times; emits structured log lines
# prefixed with [OK] / [WARN] / [ERR].
set -euo pipefail

TARGET_HOSTS=(
  "api.flox.dev:443"
  "ghcr.io:443"
  "registry-1.docker.io:443"
)

TIMEOUT_CONN=3
CURL_BIN="$(command -v curl || true)"
IP_BIN="$(command -v ip || true)"
NFT_BIN="$(command -v nft || true)"
CONNTRACK_BIN="$(command -v conntrack || true)"
JQ_BIN="$(command -v jq || true)"

log() { printf '%s %s\n' "[$1]" "$2"; }
section() { printf '\n## %s ##\n' "$1"; }

section "Environment"
log INFO "HOSTNAME=$(hostname)"
log INFO "DATE=$(date -Is)"

section "Basic Interface State"
if [[ -n $IP_BIN ]]; then
  ip -o -4 addr show wan0 || true
  ip route show || true
else
  log WARN "ip command not found"
fi

section "DNS Resolution"
for hostport in "${TARGET_HOSTS[@]}"; do
  host="${hostport%%:*}"
  if getent hosts "$host" >/dev/null 2>&1; then
    ip_resolved=$(getent hosts "$host" | awk '{print $1}' | paste -sd ',')
    log OK "Resolved $host -> $ip_resolved"
  else
    log ERR "Failed to resolve $host"
  fi
done

section "TCP Connect Tests"
for hostport in "${TARGET_HOSTS[@]}"; do
  host="${hostport%%:*}"; port="${hostport##*:}"
  start=$(date +%s%3N)
  if (echo > /dev/tcp/$host/$port) 2>/dev/null; then
    end=$(date +%s%3N); dur=$(( end - start ))
    log OK "tcp://$host:$port connect ${dur}ms"
  else
    log ERR "tcp://$host:$port connect failed (timeout>${TIMEOUT_CONN}s)"
  fi
done

section "HTTPS Curl Probes"
if [[ -n $CURL_BIN ]]; then
  for hostport in "${TARGET_HOSTS[@]}"; do
    url="https://${hostport}"
    # time_connect + http_code; suppress body
    out=$(curl -4 -ksS --connect-timeout $TIMEOUT_CONN -w 'code=%{http_code} time_connect=%{time_connect}\n' -o /dev/null "$url" || true)
    log INFO "$hostport $out"
  done
else
  log WARN "curl not found"
fi

section "nftables NAT (summary)"
if [[ -n $NFT_BIN ]]; then
  if nft list table ip nat >/dev/null 2>&1; then
    nft -a list table ip nat | awk '/chain postrouting/ {show=1} show{ if ($0 ~ /}/){print;exit} else print }'
  else
    log WARN "No ip nat table"
  fi
else
  log WARN "nft not found"
fi

section "Conntrack Summary"
if [[ -n $CONNTRACK_BIN ]]; then
  for proto in tcp; do
    cnt=$($CONNTRACK_BIN -L 2>/dev/null | grep -c "^$proto" || true)
    log INFO "conntrack $proto entries=$cnt"
  done
else
  log WARN "conntrack tool not found"
fi

section "Optional Remediation"
cat <<'EOT'
If outbound TCP consistently fails while DNS resolution works:
  1. Consider flushing conntrack:  sudo conntrack -F
  2. Verify nft postrouting MASQUERADE rules for cluster subnets
  3. Restart impacted services (rke2-server) only after confirming egress
  4. For shared network mode prefer a single bridge to reduce rule churn
EOT

log OK "Preflight completed"
