#!/usr/bin/env -S bash -exuo pipefail

source <(flox activate --dir /var/lib/rancher/rke2)

log() {
  echo "[rke2-openebs-ready] $*"
}

wait_for_storageclass() {
  local sc="${1:?storageclass name required}" timeout="${2:-300}" interval="${3:-5}"
  local start end
  start="$(date +%s)"
  end=$((start + timeout))
  while ! kubectl get storageclass "${sc}" >/dev/null 2>&1; do
    if (( $(date +%s) >= end )); then
      log "StorageClass ${sc} not ready after ${timeout}s"
      kubectl get storageclass || true
      return 1
    fi
    log "Waiting for StorageClass ${sc}..."
    sleep "${interval}"
  done
  log "StorageClass ${sc} detected"
  kubectl get storageclass "${sc}"
}

log "Waiting for OpenEBS components..."

kubectl wait --for=condition=Available deployments --selector=app=openebs-zfs-controller --namespace=openebs --timeout=300s
kubectl wait --for=condition=Ready pods --selector=app=openebs-zfs-node --namespace=openebs --timeout=300s
kubectl wait --for=condition=established crd/zfsvolumes.zfs.openebs.io crd/zfssnapshots.zfs.openebs.io crd/zfsnodes.zfs.openebs.io --namespace=openebs --timeout=300s
wait_for_storageclass openebs-zfs 300 5

log "OpenEBS ZFS is ready"
