{
  lib,
  stdenv,
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

stdenv.mkDerivation ({
  name = "kakplugin-${pname}-${version}";
  inherit pname version src meta;

  dontBuild = true;
  dontConfigure = true;

  # Tool deps: inspectable by wrapKakoune for PATH injection.
  propagatedBuildInputs = toolDeps;

  # Plugin deps: stored as names, resolved at wrapKakoune time against
  # the full kakounePlugins set to avoid evaluation-order issues.
  passthru = {
    pluginDeps = pluginDeps;
  };

  installPhase = ''
    runHook preInstall

    target=$out/share/kak/autoload/plugins/${pname}
    mkdir -p $out/share/kak/autoload/plugins
    cp -r . $target

    runHook postInstall
  '';
} // builtins.removeAttrs args [ "pname" "version" "src" "toolDeps" "pluginDeps" "meta" ])
