{
  description = "Zig project flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs =
    { zig2nix, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        env = zig2nix.outputs.zig-env.${system} { };
      in
      with builtins;
      with env.pkgs.lib;
      rec {
        packages.foreign = env.package (
          {
            src = cleanSource ./.;

            nativeBuildInputs = with env.pkgs; [ ];

            buildInputs = with env.pkgs; [ ];

            zigPreferMusl = true;

            zigDisableWrap = true;
          }
          // optionalAttrs (!pathExists ./build.zig.zon) {
            pname = "zix";
            version = "1.0.0";
          }
        );

        packages.default = packages.foreign.overrideAttrs (attrs: {
          zigPreferMusl = false;

          zigWrapperBins = with env.pkgs; [ ];

          zigWrapperLibs = with env.pkgs; [ ];
        });

        apps.bundle = {
          type = "app";
          program = "${packages.foreign}/bin/default";
        };

        # nix run .
        apps.default = env.app [ ] "zig build run -- \"$@\"";

        # nix run .#build
        apps.build = env.app [ ] "zig build \"$@\"";

        # nix run .#test
        apps.test = env.app [ ] "zig build test -- \"$@\"";

        # nix run .#docs
        apps.docs = env.app [ ] "zig build docs -- \"$@\"";

        # nix run .#zig2nix
        apps.zig2nix = env.app [ ] "zig2nix \"$@\"";

        # nix develop
        devShells.default = env.mkShell {
          # Packages required for compiling, linking and running
          # Libraries added here will be automatically added to the LD_LIBRARY_PATH and PKG_CONFIG_PATH
          nativeBuildInputs = with env.pkgs; [ ];
        };
      }
    ));
}
