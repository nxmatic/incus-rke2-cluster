#!/usr/bin/env -S bash -exuo pipefail

# Log all operations
exec > >(logger -t rke2-network-config) 2>&1

: "Load flox environment for yq and other tools"
source <( flox activate --dir /var/lib/cloud/seed/nocloud )

: "=== Stopping dhcpcd for vmnet0 (systemd-networkd will manage it) ==="
# Kill dhcpcd processes for vmnet0 to prevent route conflicts
pkill -f 'dhcpcd.*vmnet0' || true
sleep 1

: "=== Process List Before Network Config ==="
ps -ef

: "=== Applying netplan configuration ==="
ip link set dev lan0 down || true
ip link set dev vmnet0 down || true

netplan apply

: "=== Restarting systemd-networkd to ensure UseRoutes settings take effect ==="
systemctl restart systemd-networkd
sleep 3

: "=== Verifying dhcpcd is not managing vmnet0 ==="
if ps aux | grep -v grep | grep 'dhcpcd.*vmnet0'; then
  echo "[!] Warning: dhcpcd still managing vmnet0, killing again..."
  pkill -f 'dhcpcd.*vmnet0' || true
else
  echo "[i] dhcpcd not managing vmnet0 (correct)"
fi

: "=== Final Network Status ==="
ip addr show
ip route show
systemctl status systemd-networkd --no-pager

: "=== Process List After Network Config ==="
ps -ef
