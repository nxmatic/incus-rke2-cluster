#!/usr/bin/env bash
# @codebase
# Build Debian trixie image (directory layout) using distrobuilder.
# Produces build/trixie-image rootfs directory.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root/modules/nixos/rke2lab"

out_dir="build/trixie-image"
mkdir -p build

if ! command -v distrobuilder >/dev/null 2>&1; then
  echo "ERROR: distrobuilder not found in PATH" >&2
  exit 1
fi

echo "==> Validating cloud-init related config"
./validate-cloudinit.sh

echo "==> Building image definition incus-distrobuilder.yaml -> $out_dir"
distrobuilder build-dir incus-distrobuilder.yaml "$out_dir" --disable-overlay

echo "==> Build complete. To launch test instance (example):"
cat <<'EOT'
# (Adjust storage pool / profiles as needed)
incus image import build/trixie-image/meta.tar.xz build/trixie-image/rootfs.squashfs --alias rke2-trixie-test
incus launch rke2-trixie-test rke2-test-1 --profile default
# Inspect cloud-init & networking
incus exec rke2-test-1 -- cloud-init --version
incus exec rke2-test-1 -- grep -n '^cloud_config_modules' /etc/cloud/cloud.cfg
incus exec rke2-test-1 -- systemctl status systemd-networkd --no-pager
EOT
