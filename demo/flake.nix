{
  description = "buck2 + nix demo";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:matthewbauer/flake-compat/support-fetching-file-type-flakes";
      flake = false;
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {};
        overlays = [];
      };
    in
    {
      devShells = rec {
        default = buck2;
        buck2 = pkgs.mkShellNoCC {
          name = "buck2-shell";
          env.NATIVELINK_URL = "grpc://x1:50051";
          packages = [
            pkgs.buck2
            pkgs.nix
          ];

          shellHook = ''export PS1="\n[buck2-shell:\w]$ \0"'';
        };
      };
    });

}
