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
      fetcher =
        if meta ? fetcher then meta.fetcher else throw "fetchFromManifest: missing fetcher for ${pname}";

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
in
{
  inherit fetchFromManifest;
}
