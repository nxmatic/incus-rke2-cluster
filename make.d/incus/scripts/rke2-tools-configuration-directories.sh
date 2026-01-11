#!/usr/bin/env -S bash -exu -o pipefail

: "Create directories for tool configurations"
mkdir -p /var/lib/rancher/rke2/helm/plugins
mkdir -p /etc/rancher/rke2/helm
mkdir -p /var/cache/rancher/rke2/helm/repository
mkdir -p /var/lib/rancher/rke2/krew
