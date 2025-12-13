#!/usr/bin/env -S bash -euo pipefail

if [[ "${1:-}" == "version" ]]; then
  echo "20.10.0"
  exit 0
fi

exec nerdctl "$@"
