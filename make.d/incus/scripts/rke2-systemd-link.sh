#!/usr/bin/env -S bash -exu -o pipefail

RKE2LAB_ROOT=${RKE2LAB_ROOT:-/.rke2lab}
RKE2LAB_SYSTEMD_DIR=${RKE2LAB_SYSTEMD_DIR:-${RKE2LAB_ROOT}/system.d}

LOG_FILE="/var/log/rke2-systemd-link.log"

log() {
  printf '[systemd-link] %s\n' "$*" | tee -a "${LOG_FILE}"
}

# Wait for the bind-mount to appear and contain files (up to 30s)
for i in {1..30}; do
  if [[ -d "${RKE2LAB_SYSTEMD_DIR}" && $(find "${RKE2LAB_SYSTEMD_DIR}" -type f | wc -l) -gt 0 ]]; then
    break
  fi
  log "waiting for ${RKE2LAB_SYSTEMD_DIR} to be populated (attempt ${i}/30)";
  sleep 1
done

if [[ ! -d "${RKE2LAB_SYSTEMD_DIR}" ]]; then
  log "systemd directory not found: ${RKE2LAB_SYSTEMD_DIR}"
  exit 1
fi

mkdir -p /etc/systemd/system

source <( find "${RKE2LAB_SYSTEMD_DIR}" -type f -name '*.service' |
          xargs -I{} echo systemctl link {} )
log "linked systemd service units from ${RKE2LAB_SYSTEMD_DIR}"

source <( find "${RKE2LAB_SYSTEMD_DIR}" -mindepth 1 -type d -name '*.d' |
		  xargs -I{} echo ln -fs {} /etc/systemd/system/ )
log "linked systemd override directories from ${RKE2LAB_SYSTEMD_DIR}"

systemctl daemon-reload
log "daemon-reload complete"