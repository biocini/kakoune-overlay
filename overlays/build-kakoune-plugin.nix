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
  ...
}:

stdenvNoCC.mkDerivation (
  {
    name = "kakplugin-${pname}-${version}";
    inherit
      pname
      version
      src
      meta
      ;

    dontBuild = true;
    dontConfigure = true;

    # Tool deps: inspectable by wrapKakoune for PATH injection.
    propagatedBuildInputs = toolDeps;

    # Plugin deps: stored as names, resolved at wrapKakoune time against
    # the full kakounePlugins set to avoid evaluation-order issues.
    passthru = {
      pluginDeps = pluginDeps;
    };

    # Copies the full source tree, not just .kak files. Some plugins include
    # support scripts (shell, python, lua) referenced by their .kak files.
    # This is intentionally broader than upstream's find-based approach.
    installPhase = ''
      runHook preInstall

      target=$out/share/kak/autoload/plugins/${pname}
      mkdir -p $out/share/kak/autoload/plugins
      cp -r . $target

      runHook postInstall
    '';
  }
  // builtins.removeAttrs args [
    "pname"
    "version"
    "src"
    "toolDeps"
    "pluginDeps"
    "meta"
  ]
)
