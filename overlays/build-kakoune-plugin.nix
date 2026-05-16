{
  lib,
  stdenvNoCC,
  pkgs,
}:

args@{
  pname,
  version,
  src,
  toolDeps ? [ ],
  pluginDeps ? [ ],
  meta ? { },
  isRust ? false,
  ...
}:

let
  stdenv = if isRust then pkgs.stdenv else stdenvNoCC;
  cargoDeps =
    if isRust then
      pkgs.rustPlatform.importCargoLock {
        lockFile = "${src}/Cargo.lock";
        allowBuiltinFetchGit = true;
      }
    else
      null;
in

stdenv.mkDerivation (
  {
    name = "kakplugin-${pname}-${version}";
    inherit
      pname
      version
      src
      meta
      ;

    dontBuild = !isRust;
    dontConfigure = !isRust;

    nativeBuildInputs = lib.optionals isRust [
      pkgs.rustPlatform.cargoSetupHook
      pkgs.cargo
      pkgs.rustc
    ];

    # Tool deps: inspectable by wrapKakoune for PATH injection.
    propagatedBuildInputs = toolDeps;

    # Plugin deps: stored as names, resolved at wrapKakoune time against
    # the full kakounePlugins set to avoid evaluation-order issues.
    passthru = {
      pluginDeps = pluginDeps;
    };

    buildPhase = lib.optionalString isRust ''
      runHook preBuild
      cargo build --release
      runHook postBuild
    '';

    # Copies the full source tree, not just .kak files. Some plugins include
    # support scripts (shell, python, lua) referenced by their .kak files.
    # This is intentionally broader than upstream's find-based approach.
    installPhase = ''
      runHook preInstall

      target=$out/share/kak/autoload/plugins/${pname}
      mkdir -p $out/share/kak/autoload/plugins
      cp -r . $target

      ${lib.optionalString isRust ''
        mkdir -p $out/bin
        find target/release -maxdepth 1 -type f \
          -not -name '*.d' \
          -not -name '.cargo-lock' \
          -not -name '.fingerprint' \
          -exec cp {} $out/bin/ \;
      ''}

      runHook postInstall
    '';
  }
  // lib.optionalAttrs isRust { inherit cargoDeps; }
  // builtins.removeAttrs args [
    "pname"
    "version"
    "src"
    "toolDeps"
    "pluginDeps"
    "meta"
    "isRust"
  ]
)
