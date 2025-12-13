#!/usr/bin/env -S bash -exu -o pipefail

echo "=== RKE2 Network Debug at $(date) ==="

echo "=== Interface Status ==="
ip addr show || true

echo "=== Route Table ==="
ip route show || true

echo "=== NetworkD Status ==="
systemctl status systemd-networkd --no-pager || true

echo "=== NetworkD Configuration ==="
networkctl list || true
networkctl status vmnet0 || true

echo "=== Wait-Online Status ==="
systemctl status systemd-networkd-wait-online --no-pager || true

echo "=== Boot Analysis ==="
systemd-analyze blame | head -10 || true

echo "=== Network Wait Analysis ==="
systemd-analyze critical-chain systemd-networkd-wait-online.service || true

echo "=== End Debug at $(date) ==="
