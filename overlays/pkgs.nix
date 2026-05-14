self: super:
let
  inherit (super) lib;

  fetchFromRepo =
    meta:
    if meta.type == "github" then
      super.fetchFromGitHub {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "gitlab" then
      super.fetchFromGitLab {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "git" then
      super.fetchgit {
        inherit (meta) url rev;
        sha256 = meta.sha256;
        fetchSubmodules = meta.fetchSubmodules or false;
        leaveDotGit = meta.leaveDotGit or false;
      }
    else
      throw "Unknown source type '${meta.type}'";

  kakouneMeta = lib.importJSON ../repos/core/kakoune.json;
  kakouneStableMeta = lib.importJSON ../repos/core/kakoune-stable.json;
  kakouneLspMeta = lib.importJSON ../repos/core/kakoune-lsp.json;
  kakTreeSitterMeta = lib.importJSON ../repos/core/kak-tree-sitter.json;

  shortRev = rev: lib.substring 0 7 rev;

in
{
  # Stable: built from the latest release tag
  kakoune-unwrapped = super.kakoune-unwrapped.overrideAttrs (old: {
    version = kakouneStableMeta.version;
    src = fetchFromRepo kakouneStableMeta;
  });

  kakoune = super.wrapKakoune self.kakoune-unwrapped { plugins = [ ]; };

  # Git: built from latest master commit
  kakoune-unwrapped-git = super.kakoune-unwrapped.overrideAttrs (old: {
    version = kakouneMeta.version;
    src = fetchFromRepo kakouneMeta;
    postPatch = ''
      echo "${shortRev kakouneMeta.rev}" > .version
    '';
  });

  kakoune-git = super.wrapKakoune self.kakoune-unwrapped-git { plugins = [ ]; };

  kakoune-lsp = super.kakoune-lsp.overrideAttrs (old: {
    version = kakouneLspMeta.version;
    src = fetchFromRepo kakouneLspMeta;
    cargoHash = null;
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = "${fetchFromRepo kakouneLspMeta}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
  });

  kak-tree-sitter-unwrapped = super.kak-tree-sitter-unwrapped.overrideAttrs (old: {
    version = kakTreeSitterMeta.version;
    src = fetchFromRepo kakTreeSitterMeta;
    cargoHash = null;
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = "${fetchFromRepo kakTreeSitterMeta}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
  });

  kak-tree-sitter = super.kak-tree-sitter.override {
    kak-tree-sitter-unwrapped = self.kak-tree-sitter-unwrapped;
  };
}
