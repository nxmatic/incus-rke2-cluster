list#!/usr/bin/env bash
# @codebase
# Validate that generated cloud-init configuration & units are correct before image build/deploy.
# Checks:
# 1. No 'contents:' key used in systemd units cloud-config snippets (should be 'content:')
# 2. systemd module is declared in any cloud.cfg.d fragment we manage
# 3. Optional: Warn if cloud-init version below a target minimal version (argument or default)
set -euo pipefail

min_version="${1:-24.1.0}"  # adjust as needed
repo_root="$(git rev-parse --show-toplevel)"
cloud_cfg_dir="$repo_root/modules/nixos/incus-rke2-cluster"

err=0

# 1. Key misuse check
if grep -R "^\s*contents:" -n "$cloud_cfg_dir"/*.yaml "$cloud_cfg_dir"/*.yml 2>/dev/null; then
  echo "ERROR: Found 'contents:' key; use 'content:' in systemd units" >&2
  err=1
else
  echo "OK: No 'contents:' keys detected"
fi

# 2. systemd module presence (look into any file adding cloud_config_modules)
if ! grep -R "cloud_config_modules" -n "$cloud_cfg_dir" | grep -q systemd; then
  echo "ERROR: 'systemd' not found in cloud_config_modules declarations" >&2
  err=1
else
  echo "OK: systemd module declared"
fi

# 3. Version warning (runtime check if cloud-init installed locally)
if command -v cloud-init >/dev/null 2>&1; then
  current_ver=$(cloud-init --version 2>/dev/null | sed -E 's/^cloud-init\s+version\s+([^ ].*)$/\1/' | cut -d' ' -f1)
  if [[ -n "$current_ver" ]]; then
    if printf '%s\n%s\n' "$min_version" "$current_ver" | sort -V | head -1 | grep -qx "$min_version"; then
      echo "OK: cloud-init version ($current_ver) >= minimal ($min_version)"
    else
      echo "WARN: cloud-init version ($current_ver) < minimal target ($min_version)" >&2
    fi
  fi
else
  echo "INFO: cloud-init not installed locally; skipping version check"
fi

exit $err
