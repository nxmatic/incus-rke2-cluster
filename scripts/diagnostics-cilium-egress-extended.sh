#!/usr/bin/env bash
# @codebase
# diagnostics-cilium-egress-extended.sh
# Extended diagnostics for Cilium egress failures across multi-node RKE2 cluster.
# Collects iptables, ip rules, Cilium policy, proxy state, conntrack & curl traces.
#
# Usage:
#   ./scripts/diagnostics-cilium-egress-extended.sh [--namespace kube-system] [--pod-selector k8s-app=kube-dns] [--curl-host https://example.com]
#
# Artifacts are written under .logs.d/diag-$TS
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
OUT_DIR=".logs.d/diag-${TS}"
mkdir -p "$OUT_DIR"

NAMESPACE="default"
POD_SELECTOR=""
CURL_HOST="https://example.com"
MAX_CT=200

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE=$2; shift 2;;
    --pod-selector) POD_SELECTOR=$2; shift 2;;
    --curl-host) CURL_HOST=$2; shift 2;;
    --help|-h)
      grep -E '^# ' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

log() { echo "[$(date +%H:%M:%S)] $*"; }
run_save() { local f=$1; shift; { echo "+ $*"; "$@"; } &>"$OUT_DIR/$f" || true; }

log "Collecting node-level networking (host)"
run_save host_ip_a ip a
run_save host_ip_route ip route
run_save host_ip_rule ip rule

if command -v iptables &>/dev/null; then
  run_save host_iptables_nat_s iptables -t nat -S
  run_save host_iptables_nat_L iptables -t nat -L -n -v
  run_save host_iptables_filter_s iptables -t filter -S
fi

if command -v conntrack &>/dev/null; then
  run_save host_conntrack_flows conntrack -L || true
  # Sample top 200 entries (to keep size manageable)
  conntrack -L 2>/dev/null | head -n $MAX_CT > "$OUT_DIR/host_conntrack_sample.txt" || true
fi

log "Collecting Cilium pod information"
run_save cilium_pods kubectl -n kube-system get pods -l k8s-app=cilium -o wide
for cpod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}'); do
  run_save cilium_${cpod}_status kubectl -n kube-system exec "$cpod" -- cilium status --verbose
  run_save cilium_${cpod}_config kubectl -n kube-system exec "$cpod" -- cilium config view
  run_save cilium_${cpod}_bpf_lb kubectl -n kube-system exec "$cpod" -- cilium bpf lb list
  run_save cilium_${cpod}_bpf_nat kubectl -n kube-system exec "$cpod" -- cilium bpf nat list || true
  run_save cilium_${cpod}_bpf_ct kubectl -n kube-system exec "$cpod" -- cilium bpf ct list global | head -n 200 || true
  run_save cilium_${cpod}_fqdn kubectl -n kube-system exec "$cpod" -- cilium fqdn cache list || true
  run_save cilium_${cpod}_svc kubectl -n kube-system exec "$cpod" -- cilium service list
  run_save cilium_${cpod}_routes kubectl -n kube-system exec "$cpod" -- ip -4 r
  run_save cilium_${cpod}_ethtool kubectl -n kube-system exec "$cpod" -- ethtool -k cilium_vxlan || true
  # Warning extraction
  grep -Ei 'proxy|l7|warning|error' "$OUT_DIR/cilium_${cpod}_status" > "$OUT_DIR/cilium_${cpod}_status.filtered" || true
done

log "Collecting Cilium policy resources"
run_save cilium_policies kubectl get ciliumnetworkpolicy,clusterciliumnetworkpolicy -A || true
run_save cilium_clusterwide_policies kubectl get clusterciliumnetworkpolicy -A -o yaml || true

log "Testing curl from a chosen workload (if selector provided)"
if [[ -n "$POD_SELECTOR" ]]; then
  POD=$(kubectl -n "$NAMESPACE" get pods -l "$POD_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "$POD" ]]; then
    run_save curl_pod_${POD} kubectl -n "$NAMESPACE" exec "$POD" -- sh -c "curl -v --connect-timeout 5 --max-time 15 $CURL_HOST" || true
  else
    echo "No pod matched selector $POD_SELECTOR in $NAMESPACE" | tee "$OUT_DIR/curl_pod_none.txt"
  fi
fi

log "Capturing envoy presence if any"
run_save host_ps_envoy ps aux | grep -i envoy || true
for cpod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}'); do
  run_save cilium_${cpod}_ps_envoy kubectl -n kube-system exec "$cpod" -- ps aux | grep -i envoy || true
  run_save cilium_${cpod}_proxy_dir kubectl -n kube-system exec "$cpod" -- ls -1 /var/run/cilium/proxy-state 2>/dev/null || true
done

log "Summary synthesis"
{
  echo "DIAG_TS=$TS"
  echo "CURL_HOST=$CURL_HOST"
  echo "POD_SELECTOR=$POD_SELECTOR"
  echo 'CILIUM_L7_FLAGS:'
  grep -H "EnableL7Proxy" "$OUT_DIR"/cilium_*_config 2>/dev/null || true
  echo 'CILIUM_KPR_FLAGS:'
  grep -H "KubeProxyReplacement" "$OUT_DIR"/cilium_*_config 2>/dev/null || true
  echo 'ENVOY_PROCESSES:'
  grep -H envoy "$OUT_DIR"/cilium_*_ps_envoy 2>/dev/null || echo 'none'
} > "$OUT_DIR/SUMMARY.txt"

log "Done. Artifacts in $OUT_DIR"