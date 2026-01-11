#!/usr/bin/env -S bash -exu -o pipefail

# Log all operations
exec > >(logger -t rke2-network-wait) 2>&1

: "=== RKE2 Network Wait at $(date) ==="

# Wait for networkd to be active
while ! systemctl is-active systemd-networkd >/dev/null 2>&1; do
  : "[.] Waiting for systemd-networkd..."
  sleep 2
done

# Wait for interfaces to be configured
for iface in vmnet0 lan0; do
  : "[+] Waiting for interface $iface..."
  timeout=30
  while [ $timeout -gt 0 ]; do
    if ip link show "$iface" >/dev/null 2>&1 && \
       networkctl status "$iface" | grep -q "State: configured\|routable" 2>/dev/null; then
      : "[i] Interface $iface is ready"
      break
    fi
    : "[.] Waiting for $iface (timeout: $timeout)..."
    sleep 1
    timeout=$((timeout - 1))
  done

  if [ $timeout -eq 0 ]; then
    : "[!] Warning: Interface $iface not ready after 30 seconds"
  fi
done

# Brief additional wait for routes to stabilize
: "[+] Allowing routes to stabilize..."
sleep 3

: "=== Final Network Status ==="
ip addr show || true
: "=== Final Routes ==="
ip route show || true

: "=== Network Wait Complete at $(date) ==="
