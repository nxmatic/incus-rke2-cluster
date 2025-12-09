# Cluster Layer kpt Packages

The packages under `kpt/catalog` act as upstream templates for cluster-scoped components (kube-vip, Cilium overlays, Headscale, etc.). Each package only ships sample setter values in a `*-setters.yaml` file so that downstream/state repositories can create per-cluster copies without leaking real IP ranges or credentials into the upstream tree. Downstream overlays live under `kpt/packagevariants/<cluster>/...`, keeping the intent for each cluster isolated from the shared catalog.

## Workflow

1. **Clone the package per cluster** – In the downstream repo (for example `/var/lib/incus-rke2-cluster`), run:

   ```bash
   kpt pkg get github.com/nxmatic/nix-darwin-home.git/modules/nixos/incus-rke2-cluster/kpt/catalog/mesh/headscale \
     packagevariants/bioskop/cluster/mesh/headscale
   ```

2. **Override setter values** – Edit the package’s `*-setters.yaml` file in the downstream copy and encrypt any secrets with SOPS. Only the downstream repo should contain real VIPs, LAN CIDRs, or node metadata.

3. **Render and commit** – Use `kpt fn render` (or `kpt fn eval`) to materialize the manifests and commit both the rendered output and the updated setters back to the downstream repo so Flux can apply them.

Repeat the same pattern for every cluster-layer package that needs customization (Cilium, kube-vip, Envoy Gateway, etc.). Upstream packages stay opinionated-but-generic, while downstream clones capture cluster-specific intent.
