# kubernetes-replicator kpt Package

This package vendors the mittwald kubernetes-replicator Helm chart via `render-helm-chart`. The root copy only ships sample values inside `replicator-setters.yaml`; create a per-cluster clone and override the setters before rendering.

## Usage

1. `kpt pkg get` this folder into the target cluster path of your downstream/state repo.
2. Edit `replicator-setters.yaml` (or replace it entirely) to choose the namespace, release name, and chart version required for that cluster.
3. Run `kpt fn render` and commit the rendered resources to the downstream repo so Flux (or your GitOps agent) applies them at bootstrap.
