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
    buildKakounePluginFrom2Nix {
      pname = name;
      version = meta.version;
      src = fetchFromRepo name meta;
      meta.homepage =
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
    };

  # Plugins that are simple overrides from git
  gitPlugins = lib.mapAttrs mkPlugin manifest;

in
{
  kakounePlugins = super.kakounePlugins // gitPlugins;
}
