#!/usr/bin/env -S bash -exu -o pipefail

# Log all operations
exec > >(logger -t rke2-route-cleanup) 2>&1

echo "=== RKE2 Route Cleanup at $(date) ==="

echo "=== Routes Before Cleanup ==="
ip route show || true

# Remove default route from vmnet0 if it exists
# vmnet0 should NEVER have a default route - it's cluster-internal only
if ip route show default dev vmnet0 >/dev/null 2>&1; then
  echo "[+] Removing unwanted default route from vmnet0 (cluster-internal interface)"
  ip route del default dev vmnet0 || true
else
  echo "[i] No default route on vmnet0 (correct)"
fi

# Verify lan0 has the default route
if ! ip route show default dev lan0 >/dev/null 2>&1; then
  echo "[!] Warning: No default route via lan0 found (should be primary internet gateway)"
  echo "[+] Current routes:"
  ip route show
else
  echo "[i] Default route via lan0 is properly configured (primary internet)"
fi

echo "=== Routes After Cleanup ==="
ip route show || true

echo "=== Route Cleanup Complete at $(date) ==="
