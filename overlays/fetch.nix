{
  lib,
  fetchFromGitHub,
  fetchFromGitLab,
  fetchgit,
  fetchFromCodeberg,
  fetchFromSourcehut,
}:

let
  fetchFromManifest =
    pname: meta:
    let
      fetcher = meta.fetcher or (throw "fetchFromManifest: missing fetcher for ${pname}");

      isGit = fetcher == "git";

      parts = if !isGit then lib.splitString "/" meta.repo else [ ];
      owner = if !isGit then builtins.elemAt parts 0 else null;
      repo = if !isGit then builtins.elemAt parts 1 else null;
    in
    if fetcher == "github" then
      fetchFromGitHub {
        inherit owner repo;
        inherit (meta) rev sha256;
      }
    else if fetcher == "gitlab" then
      fetchFromGitLab {
        inherit owner repo;
        inherit (meta) rev sha256;
      }
    else if fetcher == "codeberg" then
      fetchFromCodeberg {
        inherit owner repo;
        inherit (meta) rev sha256;
      }
    else if fetcher == "sourcehut" then
      if meta.leaveDotGit or false then
        fetchgit {
          url = "https://git.sr.ht/~${owner}/${repo}";
          inherit (meta) rev sha256;
          leaveDotGit = true;
        }
      else
        fetchFromSourcehut {
          owner = "~" + owner;
          inherit repo;
          inherit (meta) rev sha256;
        }
    else if fetcher == "git" then
      fetchgit {
        url = meta.repo;
        inherit (meta) rev sha256;
        leaveDotGit = meta.leaveDotGit or false;
      }
    else
      throw "Unknown fetcher '${fetcher}' for ${pname}";

  homepageFromManifest =
    meta:
    let
      fetcher = meta.fetcher or "";
    in
    if fetcher == "github" then
      "https://github.com/${meta.repo}/"
    else if fetcher == "gitlab" then
      "https://gitlab.com/${meta.repo}/"
    else if fetcher == "codeberg" then
      "https://codeberg.org/${meta.repo}/"
    else if fetcher == "sourcehut" then
      let
        parts = lib.splitString "/" meta.repo;
      in
      "https://git.sr.ht/~${builtins.elemAt parts 0}/${builtins.elemAt parts 1}/"
    else if fetcher == "git" then
      meta.repo
    else
      "";
in
{
  inherit fetchFromManifest homepageFromManifest;
}
