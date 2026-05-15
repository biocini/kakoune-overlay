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
  overrides = import ../repos/plugins/overrides.nix { pkgs = super; };
  compiled = import ../repos/plugins/compiled.nix { pkgs = super; };

  isPluginDep = d: lib.hasPrefix "kakounePlugins." d;

  mkPlugin =
    pname: meta:
    let
      src = fetch.fetchFromManifest pname meta;
      override = overrides.${pname} or { };
      compiledFixup = compiled.${pname} or { };

      toolDeps = builtins.filter (d: !isPluginDep d) (meta.deps or [ ]);
      pluginDepNames = map (d: lib.removePrefix "kakounePlugins." d) (
        builtins.filter isPluginDep (meta.deps or [ ])
      );

      homepage =
        if meta.fetcher == "github" then
          "https://github.com/${meta.repo}/"
        else if meta.fetcher == "gitlab" then
          "https://gitlab.com/${meta.repo}/"
        else if meta.fetcher == "codeberg" then
          "https://codeberg.org/${meta.repo}/"
        else if meta.fetcher == "sourcehut" then
          let
            parts = lib.splitString "/" meta.repo;
          in
          "https://git.sr.ht/~${builtins.elemAt parts 0}/${builtins.elemAt parts 1}/"
        else if meta.fetcher == "git" then
          meta.repo
        else
          "";
      rustPlugins = [
        "parinfer-rust"
        "kakoune-lsp"
        "hop-kak"
      ];
      isRustPlugin = builtins.elem pname rustPlugins;
    in
    if compiled ? ${pname} then
      # Plugin has a complex nixpkgs build — override src + inject deps.
      super.kakounePlugins.${pname}.overrideAttrs (
        old:
        {
          version = meta.version;
          name = "kakplugin-${pname}-${meta.version}";
          inherit src;
          propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ (map (d: super.${d}) toolDeps);
          passthru = (old.passthru or { }) // {
            pluginDeps = pluginDepNames;
          };
        }
        // (lib.optionalAttrs isRustPlugin {
          cargoHash = null;
          cargoDeps = super.rustPlatform.importCargoLock {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
        })
        // compiledFixup
      )
    else
      self.kakouneUtils.buildKakounePlugin {
        inherit pname src;
        version = meta.version;
        deps = meta.deps or [ ];
        meta = {
          inherit homepage;
        }
        // lib.optionalAttrs (meta ? description && meta.description != "") {
          description = meta.description;
        }
        // lib.optionalAttrs (meta ? license && meta.license != "") {
          license = meta.license;
        };
        postInstall = override.postInstall or "";
      };

in
{
  kakounePlugins = super.kakounePlugins // (lib.mapAttrs mkPlugin manifest);
}
