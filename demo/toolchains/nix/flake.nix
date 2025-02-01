{
  description = "buck2 toolchains flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [];
          config = {};
        };
        inherit (nixpkgs) lib;
        buck2BuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.cacert
          pkgs.gnused
          pkgs.git
          pkgs.nix
        ] ++ lib.optionals pkgs.stdenv.isDarwin [
          pkgs.stdenv.cc.bintools
          pkgs.darwin.cctools
        ];

        defaultPATH = lib.makeBinPath [ pkgs.bash pkgs.coreutils ];

        # produce a .env file that can be sourced
        stdEnv = pkgs.writeText "std.env" ''
          PATH='${ defaultPATH }:'"''${PATH}"
        '';
      in
      {
        apps.dockerBuild =
          { program = "${self.packages.${system}.dockerImage}"; type = "app"; };

        packages = {
          stdBash = pkgs.bash;

          dockerImage =
            let
              inherit (pkgs) dockerTools;
              inherit (self.packages.${system}) bash cxx python;
            in
            dockerTools.streamNixShellImage {
              name = "nix-build";
              drv = pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; }
                {
                  PATH = pkgs.lib.makeBinPath [ pkgs.bash pkgs.coreutils ];
                  nativeBuildInputs = [ bash cxx python stdEnv ];
                };
              tag = "latest";
            };

          inherit stdEnv;
          inherit (pkgs) gnused;

          bash = pkgs.writeShellScriptBin "bash" ''
            export PATH='${ lib.makeBinPath buck2BuildInputs }'
            exec "$BASH" "$@"
          '';

          cxx = pkgs.stdenv.mkDerivation
            {
              name = "buck2-cxx";
              dontUnpack = true;
              dontCheck = true;
              nativeBuildInputs = [ pkgs.makeWrapper ];
              buildPhase = ''
                function capture_env() {
                    # variables to export, all variables with names beginning with one of these are exported
                    local -ar vars=(
                        NIX_CC_WRAPPER_TARGET_HOST_
                        NIX_CFLAGS_COMPILE
                        NIX_DONT_SET_RPATH
                        NIX_ENFORCE_NO_NATIVE
                        NIX_HARDENING_ENABLE
                        NIX_IGNORE_LD_THROUGH_GCC
                        NIX_LDFLAGS
                        NIX_NO_SELF_RPATH
                    )
                    for prefix in "''${vars[@]}"; do
                        for v in $( eval 'echo "''${!'"$prefix"'@}"' ); do
                            echo "--set"
                            echo "$v"
                            echo "''${!v}"
                        done
                    done
                }

                mkdir -p "$out/bin"

                for tool in ar nm objcopy ranlib strip; do
                    ln -st "$out/bin" "$NIX_CC/bin/$tool"
                done

                mapfile -t < <(capture_env)

                makeWrapper "$NIX_CC/bin/$CC" "$out/bin/cc" "''${MAPFILE[@]}"
                makeWrapper "$NIX_CC/bin/$CXX" "$out/bin/c++" "''${MAPFILE[@]}"
              '';
            };
          python = pkgs.python3;
        };
      });
}
