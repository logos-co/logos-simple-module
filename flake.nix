{
  description = "Logos Simple Module build via Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    logos-core-poc = {
      url = "github:logos-co/logos-core-poc";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, logos-core-poc }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnsupportedSystem = true;
        };
        qt = pkgs.qt6;
        logosCorePath = logos-core-poc;
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "logos-simple-module";
          version = "1.0.0";
          src = self;

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            qt.wrapQtAppsHook
          ];

          buildInputs = [
            qt.qtbase
            qt.qtremoteobjects
            qt.qttools
          ];

          postPatch = ''
            chmod -R u+w .
            export LOGOS_CORE_ROOT=${logosCorePath}
            bash scripts/local.sh
          '';

          configurePhase = ''
            cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$out
          '';

          buildPhase = ''
            cmake --build build
          '';

          installPhase = ''
            mkdir -p $out
            if [ -d build/modules ]; then
              mkdir -p $out/modules
              cp -r build/modules/. $out/modules/
            fi
            if [ -d build/lib ]; then
              mkdir -p $out/lib
              cp -r build/lib/. $out/lib/
            fi
            if [ -d build/bin ]; then
              mkdir -p $out/bin
              cp -r build/bin/. $out/bin/
            fi
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.cmake
            pkgs.pkg-config
            qt.qtbase
            qt.qtremoteobjects
            qt.qttools
            pkgs.git
          ];
          shellHook = ''
            export LOGOS_CORE_ROOT=${logosCorePath}
            if [ -d scripts ]; then
              bash scripts/local.sh
            fi
            echo "LOGOS_CORE_ROOT set to ${logosCorePath}"
            echo "Vendor symlinks refreshed via scripts/local.sh"
          '';
        };
      });
}
