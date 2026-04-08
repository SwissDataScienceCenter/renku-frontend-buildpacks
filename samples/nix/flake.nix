{
  description = "A simple flake for testing the CNB nix buildpack";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.default = pkgs.buildEnv {
          name = "cns-nix-env";
          paths = [
            pkgs.cowsay
            pkgs.fortune
          ];
        };
      }
    );
}
