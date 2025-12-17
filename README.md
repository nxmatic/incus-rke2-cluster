# RKE2 Fleet Manifests (@codebase)

This branch houses the contents of the `rke2/` rootlet in the monorepo. The layout is intentionally kustomize-first so we can hydrate manifests before syncing them to control-plane nodes.

## Layout

- `packages/<package>/` – raw kpt packages mirrored from `incus-rke2-cluster/kpt/system/**`.
- `clusters/<cluster>/packages/<package>/` – output of `kpt fn render` for each package plus an auto-generated `kustomization.yaml`.
- `clusters/<cluster>/packages/kustomization.yaml` – aggregates rendered packages so overlays can import them as a single unit.
- `clusters/<cluster>/overlays/` – per-cluster overlays referencing the rendered packages (patches/variants live here).
- `clusters/<cluster>/manifests.yaml` – final hydrated YAML produced by `kustomize build`.

## Workflows

### Sync upstream packages

```
make sync-packages
```

This command re-vendors each package from the upstream repo. Run it whenever the source packages change.

### Render manifests for a cluster

```
make render@fleet [FLEET_CLUSTER=bioskop] [FLEET_PACKAGES="porch flux-operator"]
```

`render@fleet` runs `kpt fn render` for each package (writing outputs beneath `clusters/<cluster>/packages/<package>`) and finishes with `kustomize build clusters/<cluster>` to produce `clusters/<cluster>/manifests.yaml`. Commit those artifacts to publish an updated state snapshot.

> **Prerequisites**: `kpt fn render` executes containerized functions (apply-setters, render-helm-chart). Ensure a supported container runtime (Docker, nerdctl, or podman) is running and configure `KPT_FN_RUNTIME` if you are not using Docker.

### Cleaning outputs

```
rm -rf clusters/<cluster>/packages
rm -f clusters/<cluster>/manifests.yaml
```

Remove the rendered packages before re-running `make render@fleet` if you need to ensure no stale files remain between runs.

## Next steps

- Expand `render@fleet` once we onboard additional clusters.
- Introduce package-specific overlays (patches, setters) inside `overlays/<cluster>/<package>`.
- Wire CI to validate that `kustomize build overlays/<cluster>/<package>` matches committed YAML.
