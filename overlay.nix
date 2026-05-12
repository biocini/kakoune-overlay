{
  kakoune-src,
  kakoune-lsp-src,
  kak-tree-sitter-src,
}:

final: prev:
let
  shortRev = src: builtins.substring 0 7 (src.rev or "unknown");
in
{
  # ── Kakoune editor ────────────────────────────────────────────────────

  kakoune-unwrapped = prev.kakoune-unwrapped.overrideAttrs (old: {
    version = "git-${shortRev kakoune-src}";
    src = kakoune-src;
    postPatch = ''
      echo "${shortRev kakoune-src}" > .version
    '';
  });

  # nixpkgs already defines kakoune = wrapKakoune kakoune-unwrapped { plugins = []; }.
  # It automatically picks up the overridden kakoune-unwrapped above.
  # Do NOT redefine it: wrapKakoune produces a symlinkJoin without .version,
  # which breaks any downstream code that wraps it again.

  # ── Kakoune LSP ───────────────────────────────────────────────────────

  kakoune-lsp = prev.rustPlatform.buildRustPackage {
    pname = "kakoune-lsp";
    version = "git-${shortRev kakoune-lsp-src}";
    src = kakoune-lsp-src;

    cargoLock = {
      lockFile = "${kakoune-lsp-src}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };

    meta = prev.kakoune-lsp.meta // {
      description = "Kakoune Language Server Protocol Client (git)";
    };
  };

  # Alias for convenience — nixpkgs provides both names
  kak-lsp = final.kakoune-lsp;

  # ── Kakoune Tree-sitter ───────────────────────────────────────────────

  kak-tree-sitter-unwrapped = prev.rustPlatform.buildRustPackage {
    pname = "kak-tree-sitter-unwrapped";
    version = "git-${shortRev kak-tree-sitter-src}";
    src = kak-tree-sitter-src;

    cargoLock = {
      lockFile = "${kak-tree-sitter-src}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };

    meta = prev.kak-tree-sitter-unwrapped.meta // {
      description = "Tree-sitter integration for Kakoune (git)";
    };
  };

  kak-tree-sitter = prev.kak-tree-sitter.override {
    kak-tree-sitter-unwrapped = final.kak-tree-sitter-unwrapped;
  };
}
