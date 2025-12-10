# Flux Operator kpt Package

This package vendors the upstream Flux Operator Helm chart via the `render-helm-chart` KRM function. The upstream copy only carries example setters so each cluster can customize the release name, namespace, and chart version downstream before rendering.

## Usage

1. Fetch the package into the downstream/state repository:

```@codebase bash
kpt pkg get ../kpt/system/flux-operator ./packagevariants/<cluster>/system/flux-operator
```

1. Update `flux-operator-setters.yaml` (or replace it with a SOPS-encrypted Secret) to match the environment. Typical edits include the namespace, chart version, and release name.
1. Run the render pipeline and commit the rendered manifests so your GitOps agent (Flux, Config Sync, etc.) can apply them:

```@codebase bash
kpt fn render packagevariants/<cluster>/system/flux-operator
```

1. Apply the rendered resources to the cluster. If you want to test changes via Helm directly before committing, the source chart can also be installed with:

```@codebase bash
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace
```

Remember to keep the packaged chart payload (`render-helm-chart.yaml`) in sync with upstream releases whenever the Flux Operator is upgraded.
