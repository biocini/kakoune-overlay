{
  lib,
  symlinkJoin,
  makeWrapper,
}:

self: super:
let
  resolvePluginDep =
    kakounePlugins: p: name:
    if kakounePlugins ? ${name} then
      kakounePlugins.${name}
    else
      throw "kakoune plugin '${p.pname or "<unknown>"}': unknown plugin dependency '${name}' in passthru.pluginDeps";

  # Recursively expand plugin cross-deps to a fixed point.
  expandPlugins =
    kakounePlugins: plugins:
    let
      names = map (p: p.pname) plugins;
      newDeps = lib.concatMap (
        p:
        map (name: resolvePluginDep kakounePlugins p name) (
          builtins.filter (name: !builtins.elem name names) (p.passthru.pluginDeps or [ ])
        )
      ) plugins;
    in
    if newDeps == [ ] then plugins else expandPlugins kakounePlugins (lib.unique (plugins ++ newDeps));

  wrapKakouneFn =
    kakounePlugins: kakoune-unwrapped:
    {
      plugins ? [ ],
      ...
    }:
    let
      allPlugins = expandPlugins kakounePlugins (lib.unique plugins);

      # Collect tool deps from the full transitive plugin closure.
      runtimeDeps = lib.unique (lib.concatMap (p: p.propagatedBuildInputs or [ ]) allPlugins);

      pathPrefix = lib.makeBinPath runtimeDeps;
    in
    symlinkJoin {
      name = "kakoune-with-packages-${kakoune-unwrapped.version}";

      paths = [ kakoune-unwrapped ] ++ allPlugins;

      nativeBuildInputs = [ makeWrapper ];

      postBuild = lib.optionalString (runtimeDeps != [ ]) ''
        wrapProgram $out/bin/kak \
          --prefix PATH : ${pathPrefix}
      '';

      passthru = {
        plugins = allPlugins;
        inherit runtimeDeps;
        unwrapped = kakoune-unwrapped;
      };
    };

in
{
  wrapKakoune = kakoune-unwrapped: args: wrapKakouneFn self.kakounePlugins kakoune-unwrapped args;
}
