#!/usr/bin/env -S bash -exu -o pipefail
mount --make-shared /
mount --make-shared -t bpf bpf /sys/fs/bpf
mount --make-shared /run
