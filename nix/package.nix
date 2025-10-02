{ lib
, stdenv
, cmake
, ninja
, pkg-config
, qt6
, logosLiblogosSrc
, logosCppSdkSrc
}:

let
  qtDeps = [
    qt6.qtbase
    qt6.qtremoteobjects
  ];
  qtPrefixPath = lib.concatStringsSep ";" (map (pkg: "${pkg}") qtDeps);
in
stdenv.mkDerivation {
  pname = "logos-simple-module";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        base = toString ../.;
        pathStr = toString path;
        relPath = lib.removePrefix (base + "/") pathStr;
        keepVendor = lib.hasPrefix "vendor/logos-liblogos" relPath
          || lib.hasPrefix "vendor/logos-cpp-sdk" relPath;
      in
        lib.cleanSourceFilter path type || keepVendor;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = qtDeps;

  cmakeBuildType = "Release";

  dontWrapQtApps = true;

  postUnpack = ''
    echo "Replacing vendor dependencies with flake inputs"
    rm -rf source/vendor/logos-liblogos source/vendor/logos-cpp-sdk
    mkdir -p source/vendor
    cp -r ${logosLiblogosSrc} source/vendor/logos-liblogos
    cp -r ${logosCppSdkSrc} source/vendor/logos-cpp-sdk
    chmod -R u+w source/vendor/logos-liblogos source/vendor/logos-cpp-sdk
  '';

  cmakeFlags = [
    "-GNinja"
    "-DLOGOS_SIMPLE_MODULE_USE_VENDOR=ON"
  ];

  CMAKE_PREFIX_PATH = qtPrefixPath;
  QT_DIR = qtPrefixPath;

  meta = with lib; {
    description = "Simple Logos module plugin";
    platforms = platforms.unix;
  };
}
