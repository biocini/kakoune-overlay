self: super:
let
  inherit (super) lib;

  fetch = import ./fetch.nix {
    inherit (super)
      lib
      fetchFromGitHub
      fetchFromGitLab
      fetchgit
      fetchFromCodeberg
      fetchFromSourcehut
      ;
  };

  manifest = lib.importJSON ../repos/plugins/manifest.json;
  pluginMeta = import ../repos/plugins/meta.nix { pkgs = super; };

  resolveToolDep =
    pname: d:
    if super ? ${d} then
      super.${d}
    else
      throw "kakoune plugin '${pname}': unknown tool dependency '${d}'";

  knownMetaKeys = [
    "delegated"
    "isRust"
    "toolDeps"
    "pluginDeps"
  ];

  mkPlugin =
    pname: srcMeta:
    let
      src = fetch.fetchFromManifest pname srcMeta;
      buildMeta = pluginMeta.${pname} or { };

      delegated = buildMeta.delegated or false;
      isRust = buildMeta.isRust or false;
      toolDepNames = buildMeta.toolDeps or [ ];
      pluginDepNames = buildMeta.pluginDeps or [ ];
      toolDeps = map (resolveToolDep pname) toolDepNames;

      extraMeta = lib.filterAttrs (n: v: !builtins.elem n knownMetaKeys) buildMeta;

      homepage =
        if srcMeta.fetcher == "github" then
          "https://github.com/${srcMeta.repo}/"
        else if srcMeta.fetcher == "gitlab" then
          "https://gitlab.com/${srcMeta.repo}/"
        else if srcMeta.fetcher == "codeberg" then
          "https://codeberg.org/${srcMeta.repo}/"
        else if srcMeta.fetcher == "sourcehut" then
          let
            parts = lib.splitString "/" srcMeta.repo;
          in
          "https://git.sr.ht/~${builtins.elemAt parts 0}/${builtins.elemAt parts 1}/"
        else if srcMeta.fetcher == "git" then
          srcMeta.repo
        else
          "";
    in
    if delegated then
      # Plugin has a complex nixpkgs build — override src + inject deps.
      super.kakounePlugins.${pname}.overrideAttrs (
        old:
        {
          version = srcMeta.version;
          name = "kakplugin-${pname}-${srcMeta.version}";
          inherit src;
          propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ toolDeps;
          passthru = (old.passthru or { }) // {
            pluginDeps = pluginDepNames;
          };
        }
        // (lib.optionalAttrs isRust {
          cargoHash = null;
          cargoDeps = super.rustPlatform.importCargoLock {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
        })
        // extraMeta
      )
    else
      buildKakounePlugin (
        {
          inherit pname src;
          version = srcMeta.version;
          inherit toolDeps;
          pluginDeps = pluginDepNames;
          meta = {
            inherit homepage;
          }
          // lib.optionalAttrs (srcMeta ? description && srcMeta.description != "") {
            description = srcMeta.description;
          }
          // lib.optionalAttrs (srcMeta ? license && srcMeta.license != "") {
            license = srcMeta.license;
          };
        }
        // extraMeta
      );

  buildKakounePlugin = import ./build-kakoune-plugin.nix {
    inherit (super) lib stdenvNoCC;
    pkgs = super;
  };

in
{
  kakounePlugins = super.kakounePlugins // (lib.mapAttrs mkPlugin manifest);
}
