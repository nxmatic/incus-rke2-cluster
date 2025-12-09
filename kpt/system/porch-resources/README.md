# Porch Resources kpt Package

This package bootstraps namespaces, repositories, and PackageVariants consumed by Porch. The upstream copy only carries placeholder setters in `porch-resources-setters.yaml`; create a per-cluster clone in the downstream/state repository and override them there.

## Workflow

1. `kpt pkg get` this package into `packagevariants/<name>/system/porch-resources` (or similar) inside the downstream repo.
2. Update `porch-resources-setters.yaml` with the cluster’s SSH keys, network ranges, and state-repo metadata (encrypt edits with SOPS in the downstream repo).
3. Run `kpt fn render` and commit the rendered manifests alongside the other cluster assets so Flux can apply them after bootstrap.
