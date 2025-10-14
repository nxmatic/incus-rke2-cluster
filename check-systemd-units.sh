#!/bin/bash
# Script to check systemd unit placement on master node

echo "=== Checking Cloud-Init Generated Systemd Units ==="

echo "1. Unit files in /etc/systemd/system/:"
ls -la /etc/systemd/system/rke2-* /etc/systemd/system/zfs-early-umount.service 2>/dev/null || echo "No RKE2 unit files found in /etc/systemd/system/"

echo -e "\n2. Enabled service symlinks in multi-user.target.wants/:"
ls -la /etc/systemd/system/multi-user.target.wants/rke2-* /etc/systemd/system/multi-user.target.wants/zfs-early-umount.service 2>/dev/null || echo "No RKE2 service symlinks found"

echo -e "\n3. Masked services:"
ls -la /etc/systemd/system/systemd-networkd-wait-online.service 2>/dev/null || echo "systemd-networkd-wait-online.service mask status unknown"

echo -e "\n4. Service status for our custom services:"
for service in rke2-network-config rke2-network-debug rke2-network-wait rke2-install rke2-remount-shared zfs-early-umount; do
    echo "--- $service.service ---"
    systemctl status $service.service --no-pager -l || echo "Service $service.service not found or failed"
    echo
done

echo -e "\n5. Check if systemd-networkd-wait-online is properly masked:"
systemctl status systemd-networkd-wait-online.service --no-pager || echo "systemd-networkd-wait-online.service is masked or inactive"

echo -e "\n6. Show systemd unit search paths:"
systemctl show --property=UnitPath

echo -e "\n7. Cloud-init logs related to systemd:"
journalctl -u cloud-init --no-pager | grep -i systemd | tail -10 || echo "No cloud-init systemd logs found"

echo -e "\n8. Check if units were created by cloud-init:"
grep -r "rke2-" /var/log/cloud-init* 2>/dev/null | grep -i "systemd\|unit" | head -5 || echo "No cloud-init unit creation logs found"