# Flox Containerd Shim kpt Package

This package bootstraps Flox Imageless Kubernetes support on self-managed nodes by installing the Flox `containerd` runtime shim through a privileged DaemonSet and publishing the corresponding `RuntimeClass`.

## Components

- **Namespace** `flox-runtime` for installer assets
- **ServiceAccount** for the DaemonSet (no cluster permissions required)
- **DaemonSet** `flox-runtime-installer`
  - Init container installs minimal tooling, then enters the host namespaces via `nsenter`
  - Follows the [manual Flox shim procedure](https://flox.dev/docs/k8s/install/self-managed/#manual-installation): creates a Flox env, installs the right `containerd-shim-flox-*` package, links the shim into `/usr/local/bin`, and appends the runtime block to both `config.toml` and `config.toml.tmpl`
  - Restart logic prefers `rke2-server`/`rke2-agent` before falling back to `containerd`
  - Main container is a pause pod so the DaemonSet can report status without consuming resources
- **RuntimeClass** `flox` with a `nodeSelector` targeting labeled nodes

## Prerequisites

1. Flox CLI already installed on the nodes (per [docs](https://flox.dev/docs/install-flox/install/))
1. `containerd` v1.7+ running on the nodes
1. Nodes register with `flox.dev/enabled=true` (set via RKE2 `node-label` in cloud-config; verify if customizing clusters):

  ```bash
  kubectl get nodes -L flox.dev/enabled
  ```

1. Cluster administrators comfortable granting a privileged DaemonSet that modifies host `/etc/containerd/config.toml`
1. `/usr/local/bin` writable so the shim binary (copied from the Flox environment) can be installed

## Usage

```bash
cd /var/lib/incus-rke2-cluster/kpt/cluster/runtime/flox-containerd-shim
kpt live apply . --reconcile-timeout=3m
kpt live status .
```

Verification:

```bash
kubectl -n flox-runtime get pods -l app.kubernetes.io/name=flox-runtime-installer
kubectl get runtimeclass flox
kubectl get nodes -l flox.dev/enabled=true -o wide
# confirm pods can target the runtime class (create any pod with runtimeClassName=flox)
```

> **Note**: The Flox installer environment restarts `containerd` on each node to activate the shim. Run this during a controlled maintenance window.

## Configuration

The `Kptfile` ships setters you can override via `kpt fn eval`:

- `flox-namespace` (default `flox-runtime`)
- `node-label-key` / `node-label-value` (default `flox.dev/enabled=true`)
- `runtime-class-name` (default `flox`)
- `containerd-config-file` (default `/var/lib/rancher/rke2/agent/etc/containerd/config.toml`)
- `containerd-address` (default `/run/k3s/containerd/containerd.sock`)
- `apk-max-retries` (default `5`)

Example:

```bash
kpt fn eval . --image ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2 -- \
  flox-namespace=flox-system \
  runtime-class-name=flox-v2
```

The manual installation process is idempotent: if the shim env already exists, the DaemonSet reuses it, skips adding duplicate config blocks, and simply refreshes the binary + service restart as needed.

## RuntimeClass Consumers

Any workload that should run via Flox just sets `spec.runtimeClassName: flox`. Keep using the node label (`flox.dev/enabled=true`) in your own `nodeSelector`s or `topologySpreadConstraints` to ensure pods land on prepared nodes.

## Operational Notes

- The DaemonSet forwards `CONTAINERD_CONFIG_FILE` and `CONTAINERD_ADDRESS` into the host namespace so the manual shim steps touch the correct RKE2 paths; adjust the setters if your distro stores `containerd` elsewhere.
- `apk-max-retries` controls how many times the init container retries Alpine package downloads in case the mirrors temporarily fail (each attempt backs off by `attempt*2` seconds).
- The DaemonSet tolerates all taints so it reaches control-plane nodes as well; tighten tolerations if needed.
- For distros that vendor `containerd` (e.g., K3s/RKE2), the DaemonSet updates both the live `config.toml` and the `config.toml.tmpl` template so future restarts keep the shim. If you maintain your own template layering, ensure the Flox block remains present.
- Removing the package will delete the DaemonSet and RuntimeClass but will **not** undo the host-side Flox configuration; follow the Flox uninstall guide to revert.
