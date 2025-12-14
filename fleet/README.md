# RKE2 Fleet Manifests (@codebase)

This branch houses the contents of the `rke2/` rootlet in the monorepo. The layout is intentionally kustomize-first so we can hydrate manifests before syncing them to control-plane nodes.

## Layout

- `packages/<package>/` – raw kpt packages mirrored from `incus-rke2-cluster/kpt/system/**`.
- `rendered/<package>/` – output of `kpt fn render` for each package plus an auto-generated `kustomization.yaml`.
- `overlays/<cluster>/<package>/` – per-cluster overlays referencing the rendered package (patches/variants live here).
- `overlays/<cluster>/kustomization.yaml` – aggregates the packages that should deploy on that cluster.
- `manifests/<cluster>/kpt-XX-<package>.yaml` – rendered YAML ready for Flux or `rke2-manifests-unpack`.

## Workflows

### Sync upstream packages

```
make sync-packages
```

This command re-vendors each package from the upstream repo. Run it whenever the source packages change.

### Render manifests for a cluster

```
make render            # defaults to the "default" cluster in render.sh
./render.sh <cluster>  # explicit cluster name
```

`render.sh` first runs `kpt fn render` for every package (emitting outputs under `rendered/<package>`), then invokes `kustomize build overlays/<cluster>/<package>` to assemble deterministic `kpt-XX-*` files under `manifests/<cluster>`. Commit those outputs to publish an updated state snapshot.

> **Prerequisites**: `kpt fn render` executes containerized functions (apply-setters, render-helm-chart). Ensure a supported container runtime (Docker, nerdctl, or podman) is running and configure `KPT_FN_RUNTIME` if you are not using Docker.

### Cleaning outputs

```
make clean-rendered   # remove rendered package snapshots
make clean-manifests  # drop hydrated YAML
```

Clean rendered packages before re-running `render.sh` if you need to ensure no stale files remain between runs.

## Next steps

- Expand `render.sh` once we onboard additional clusters.
- Introduce package-specific overlays (patches, setters) inside `overlays/<cluster>/<package>`.
- Wire CI to validate that `kustomize build overlays/<cluster>/<package>` matches committed YAML.
