{
  description = "headplane overlay with aarch64-linux";

  inputs = {
    flake-commons.url = "github:nxmatic/nix-flake-commons/develop";
    nixpkgs.follows = "flake-commons/nixpkgs";
    headplane.url = "github:tale/headplane";
    headplane.inputs.flake-utils.follows = "flake-utils";
    headplane.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.follows = "flake-commons/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    headplane,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachSystem [
      "aarch64-darwin"
      "aarch64-linux"
    ] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in {
      packages = {
        headplane = pkgs.headplane;
        headplane-agent = pkgs.headplane-agent;
        headplane-nixos-docs = pkgs.headplane-nixos-docs;
        headplane-ssh-wasm = pkgs.headplane-ssh-wasm;
        headscale = pkgs.headscale;
      };
      defaultPackage = pkgs.headplane;
    })
    // {
      overlays.default = headplane.overlays.default;
    };
}
