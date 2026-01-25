#!/usr/bin/env -S bash -exu -o pipefail

: "Activate flox environment"
source <(flox activate --dir /var/lib/rancher/rke2)

: "Link committed RKE2 manifests from RKE2LAB_MANIFESTS_DIR into RKE2 server manifests directory"
MANIFESTS_DIR=/var/lib/rancher/rke2/server/manifests

: ln -fs $RKE2LAB_MANIFESTS_DIR/ha         $MANIFESTS_DIR
: ln -fs $RKE2LAB_MANIFESTS_DIR/networking $MANIFESTS_DIR
: ln -fs $RKE2LAB_MANIFESTS_DIR/replication/replicator $MANIFESTS_DIR
: ln -fs $RKE2LAB_MANIFESTS_DIR/storage    $MANIFESTS_DIR

: "Ensure RKE2 systemd units are visible to systemd"
SRC_UNIT_DIR="/usr/local/lib/systemd/system"
DEST_UNIT_DIR="/etc/systemd/system"

log() {
	printf '[rke2-install-post] %s\n' "$*"
}

if [[ ! -d "$SRC_UNIT_DIR" ]]; then
	log "source unit dir missing: $SRC_UNIT_DIR"
	exit 0
fi

mkdir -p "$DEST_UNIT_DIR"

found=0
for unit in "$SRC_UNIT_DIR"/rke2-*.service; do
	[[ -f "$unit" ]] || continue
	found=1
	base=$(basename "$unit")
	dest="$DEST_UNIT_DIR/$base"
	ln -sf "$unit" "$dest"
	log "linked $base"
done

if [[ $found -eq 0 ]]; then
	log "no rke2 unit files found in $SRC_UNIT_DIR"
fi

systemctl daemon-reload
log "daemon-reload complete"
