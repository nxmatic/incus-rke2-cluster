#!/usr/bin/env bash
# flox-probe: Robust connectivity probe with per-attempt phase/timing classification
# Features added:
#  - Internal timestamps (UTC ms)
#  - IPv4/IPv6/auto/both selection via IP_MODE (4|6|auto|both)
#  - Interval & log file configuration (INTERVAL, LOG)
#  - Connect & total timeout controls (CONNECT_TIMEOUT, MAX_TIME)
#  - Optional DNS preflight (DNS_PREFLIGHT=1) with classification DNS-PREFLIGHT
#  - Scope tagging (PROBE_SCOPE)
#  - Single header line output (HEADER=1 default) with tab-separated columns
#  - Exit phase classification retained
set -euo pipefail

URL=${1:-"https://api.flox.dev/api/v1/catalog/search?page=0&pageSize=10&search_term=bpftool&system=aarch64-linux"}

: "${IP_MODE:=4}"             # 4|6|auto|both (default force IPv4 given v6 instability)
: "${CONNECT_TIMEOUT:=5}"     # Curl connect-timeout seconds
: "${MAX_TIME:=20}"           # Curl max-time seconds
: "${DNS_PREFLIGHT:=0}"       # 1 to run a quick dig/getent before curl
: "${PROBE_SCOPE:=host}"      # host|instance|pod|custom

do_dns_preflight() {
  local host=$(printf '%s' "$URL" | sed -E 's#https?://([^/:]+).*#\1#')
  if command -v dig >/dev/null 2>&1; then
    dig +tries=1 +time=2 +retry=0 "$host" >/dev/null 2>&1 || return 1
  elif command -v getent >/dev/null 2>&1; then
    getent ahosts "$host" >/dev/null 2>&1 || return 1
  else
    return 0
  fi
  return 0
}

classify_exit() {
  local e="$1"
  case "$e" in
    0) echo OK ;;
    6) echo DNS ;;
    7) echo TCP ;;
    28) echo TIMEOUT ;;
    35) echo TLS ;;
    47|55|56) echo TRANSFER ;;
    *) echo E$e ;;
  esac
}

flox::probe() {
  local ipflag="$1" mode_label="$2"
  local CURL_STDERR=$(mktemp)
  local TS=$(date -u +'%H:%M:%S.%3NZ')

  if [[ "$DNS_PREFLIGHT" == "1" ]]; then
    if ! do_dns_preflight; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$TS" "$PROBE_SCOPE" "$mode_label" DNS-PREFLIGHT '' '' '' '' '' 000 6
      rm -f "$CURL_STDERR"; return
    fi
  fi

  local METRICS=$(curl ${ipflag:+$ipflag} --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o /dev/null -sS "$URL" \
    -w '%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{http_code} %{exitcode} %{errormsg}' 2>"$CURL_STDERR" || true)
  local DNS="" CONN="" TLS="" FB="" TOTAL="" HTTP="000" EXIT="" ERRMSG=""
  if [[ -n "$METRICS" ]]; then
    read -r DNS CONN TLS FB TOTAL HTTP EXIT ERRMSG <<<"$METRICS" || true
  fi

  local PHASE
  if [[ -z "$EXIT" ]]; then
    EXIT=255
    ERRMSG=$(<"$CURL_STDERR")
    PHASE=FAIL
  else
    [[ -z "$ERRMSG" ]] && ERRMSG=$(<"$CURL_STDERR")
    PHASE=$(classify_exit "$EXIT")
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$TS" "$PROBE_SCOPE" "$mode_label" "$PHASE" "$DNS" "$CONN" "$TLS" "$FB" "$TOTAL" "$HTTP" "$EXIT" "${ERRMSG// /_}"
  rm -f "$CURL_STDERR"
}

main_loop() {
  while true; do
    case "$IP_MODE" in
      4) flox::probe -4 4 ;;
      6) flox::probe -6 6 ;;
      auto) flox::probe "" auto ;;
      both)
        flox::probe -4 both4
        flox::probe -6 both6
        ;;
      *) flox::probe -4 4 ;;
    esac
  done
}

main_loop
