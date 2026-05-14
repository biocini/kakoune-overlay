self: super:
let
  inherit (super)
    lib
    fetchFromGitHub
    fetchFromGitLab
    fetchgit
    ;
  inherit (super.kakouneUtils) buildKakounePluginFrom2Nix;

  manifest = lib.importJSON ../repos/plugins/manifest.json;
  overrides = import ../repos/plugins/overrides.nix { pkgs = super; };

  # Nixpkgs plugins whose stale hooks need clearing when src is updated.
  nixpkgsFixups = {
    kakoune-rainbow = {
      preFixup = "";
    };
  };

  # Map our normalized plugin names to nixpkgs' names where they differ.
  # Normalization is just `tr '.' '-'`, so most .kak repos already match
  # nixpkgs (e.g. fzf.kak -> fzf-kak).  Only discrepancies where the
  # upstream repo name differs from nixpkgs need entries here.
  nameMap = {
    kakoune-buffers = "kak-buffers";
  };

  fetchFromRepo =
    name: meta:
    if meta.type == "github" then
      fetchFromGitHub {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "gitlab" then
      fetchFromGitLab {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "git" then
      fetchgit {
        inherit (meta) url rev;
        sha256 = meta.sha256;
        fetchSubmodules = meta.fetchSubmodules or false;
        leaveDotGit = meta.leaveDotGit or false;
      }
    else
      throw "Unknown source type '${meta.type}' for plugin ${name}";

  mkPlugin =
    name: meta:
    let
      newSrc = fetchFromRepo name meta;
      override = overrides.${name} or { };
      customPostInstall = override.postInstall or "";

      nixpkgsName = nameMap.${name} or name;
      inNixpkgs = builtins.hasAttr nixpkgsName super.kakounePlugins;

      homepage =
        meta.homepage or (
          if meta.type == "github" then
            "https://github.com/${meta.owner}/${meta.repo}/"
          else if meta.type == "gitlab" then
            "https://gitlab.com/${meta.owner}/${meta.repo}/"
          else if meta.type == "git" then
            meta.url
          else
            ""
        );
    in
    if inNixpkgs then
      # Plugin exists in nixpkgs: override src and version only.
      # Nixpkgs' own overrides (preFixup, buildInputs, etc.) are preserved.
      super.kakounePlugins.${nixpkgsName}.overrideAttrs (
        old:
        {
          version = meta.version;
          src = newSrc;
          meta =
            (old.meta or { })
            // {
              inherit homepage;
            }
            // lib.optionalAttrs (meta ? description && meta.description != "") {
              description = meta.description;
            }
            // lib.optionalAttrs (meta ? license && meta.license != "") {
              license = meta.license;
            };
        }
        // (nixpkgsFixups.${nixpkgsName} or { })
      )
    else
      # New plugin: build from scratch.  Only postInstall path rewrites
      # are supported here — runtime binary deps are the user's
      # responsibility via their Nix environment.
      buildKakounePluginFrom2Nix {
        pname = name;
        version = meta.version;
        src = newSrc;
        meta = {
          inherit homepage;
        }
        // lib.optionalAttrs (meta ? description && meta.description != "") {
          description = meta.description;
        }
        // lib.optionalAttrs (meta ? license && meta.license != "") {
          license = meta.license;
        };
        postInstall = customPostInstall;
      };

  gitPlugins = lib.mapAttrs mkPlugin manifest;

  # For plugins that exist in nixpkgs under a different name, also
  # override the nixpkgs name so users can reference either.
  nixpkgsOverrides = lib.mapAttrs' (
    ourName: nixpkgsName: lib.nameValuePair nixpkgsName gitPlugins.${ourName}
  ) nameMap;

in
{
  kakounePlugins = super.kakounePlugins // gitPlugins // nixpkgsOverrides;
}
