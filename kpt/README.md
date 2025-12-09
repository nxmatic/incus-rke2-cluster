# kpt Layout Overview

This tree is split into three concerns:

- **`kpt/catalog`** – immutable, reusable packages grouped by domain (`ha/`, `mesh/`, `networking/`, etc.). Each package ships only sample setters so downstream repos can `kpt pkg get` them safely.
- **`kpt/packagevariants`** – per-cluster compositions. Each cluster directory (for example `bioskop/`) tracks shared setters, deployment order, and a manifest (`packages.yaml`) listing which catalog packages should be cloned into the downstream repository.
- **`kpt/system`** – shared infrastructure packages (Porch, replicator, Tekton, etc.) that bootstrap the management plane itself.

Typical workflow:

1. `kpt pkg get kpt/catalog/<category>/<package> packagevariants/<cluster>/cluster/<category>/<package>` inside the downstream/state repo.
2. Update the downstream copy’s `*-setters.yaml` with real values (encrypt secrets with SOPS).
3. Run `kpt fn render` and commit the rendered manifests so Flux/Porch can reconcile them.

See `kpt/catalog/README.md` for catalog-specific details and `kpt/packagevariants/bioskop/DEPLOYMENT-ORDER.md` for an end-to-end example that ties the packages together.
