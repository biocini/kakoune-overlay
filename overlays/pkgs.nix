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

  kakouneMeta = lib.importJSON ../repos/core/kakoune.json;
  kakouneStableMeta = lib.importJSON ../repos/core/kakoune-stable.json;
  kakTreeSitterMeta = lib.importJSON ../repos/core/kak-tree-sitter.json;

  shortRev = rev: lib.substring 0 7 rev;

in
{
  # Stable: built from the latest release tag
  kakoune-unwrapped = super.kakoune-unwrapped.overrideAttrs (old: {
    version = kakouneStableMeta.version;
    src = fetch.fetchFromManifest "kakoune" kakouneStableMeta;
  });

  kakoune = self.wrapKakoune self.kakoune-unwrapped { plugins = [ ]; };

  # Git: built from latest master commit
  kakoune-unwrapped-git = super.kakoune-unwrapped.overrideAttrs (old: {
    version = kakouneMeta.version;
    src = fetch.fetchFromManifest "kakoune-git" kakouneMeta;
    postPatch = ''
      echo "${shortRev kakouneMeta.rev}" > .version
    '';
  });

  kakoune-git = self.wrapKakoune self.kakoune-unwrapped-git { plugins = [ ]; };

  kak-tree-sitter-unwrapped =
    let
      src = fetch.fetchFromManifest "kak-tree-sitter" kakTreeSitterMeta;
    in
    super.kak-tree-sitter-unwrapped.overrideAttrs (old: {
      version = kakTreeSitterMeta.version;
      inherit src;
      cargoHash = null;
      cargoDeps = super.rustPlatform.importCargoLock {
        lockFile = "${src}/Cargo.lock";
        allowBuiltinFetchGit = true;
      };
    });

  kak-tree-sitter = super.kak-tree-sitter.override {
    kak-tree-sitter-unwrapped = self.kak-tree-sitter-unwrapped;
  };
}
