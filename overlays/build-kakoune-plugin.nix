{
  lib,
  stdenv,
  pkgs,
}:

{
  pname,
  version,
  src,
  deps ? [ ],
  meta ? { },
  postInstall ? "",
}:

let
  isPluginDep = d: lib.hasPrefix "kakounePlugins." d;

  resolveToolDep =
    d:
    if pkgs ? ${d} then
      pkgs.${d}
    else
      throw "buildKakounePlugin: unknown tool dependency '${d}' for plugin '${pname}'";

  toolDeps = map resolveToolDep (builtins.filter (d: !isPluginDep d) deps);

  pluginDepNames = map (d: lib.removePrefix "kakounePlugins." d) (builtins.filter isPluginDep deps);
in
stdenv.mkDerivation {
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
    pluginDeps = pluginDepNames;
  };

  installPhase = ''
    runHook preInstall

    target=$out/share/kak/autoload/plugins/${pname}
    mkdir -p $out/share/kak/autoload/plugins
    cp -r . $target

    runHook postInstall
  '';

  inherit postInstall;
}
