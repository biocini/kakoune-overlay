# Plugins with non-trivial builds that require nixpkgs' build machinery.
#
# These plugins are NOT built from scratch by buildKakounePlugin. Instead,
# the overlay takes the existing nixpkgs derivation and uses overrideAttrs
# to update src/version and inject deps. This preserves upstream's custom
# build logic (Rust compilation, C compilation, path substitutions, etc.).
#
# Each entry is an attribute set of override fragments merged into the
# overrideAttrs call. An empty set means "just override src/version and
# inject deps — no extra fixups needed."
{ pkgs }:
{
  # Rust binary + .kak wrapper
  parinfer-rust = { };

  # Compiled C binary + custom installPhase
  kak-ansi = { };

  # Compiled binary
  rep = { };

  # Rust binary (kak-lsp)
  kakoune-lsp = { };

  # Rust binary (hop-kak)
  hop-kak = { };

  # Lua script with custom installPhase + lua path substitution
  quickscope-kak = { };

  # Custom derivation with plan9port path substitution
  kak-plumb = { };

  # Guile script + path fixups (binary move, guile path rewrite)
  kakoune-rainbow = {
    preFixup = ''
      mkdir -p $out/bin
      mv $out/share/kak/autoload/plugins/kakoune-rainbow/bin/kak-rainbow.scm $out/bin
      substituteInPlace $out/bin/kak-rainbow.scm \
        --replace '/usr/bin/env -S guile' '${pkgs.guile}/bin/guile'
      substituteInPlace $out/share/kak/autoload/plugins/kakoune-rainbow/rainbow.kak \
        --replace '%sh{dirname "$kak_source"}' "'$out'"
    '';
  };

  # Fzf path substitution (nixpkgs hardcodes fzf/sk path)
  fzf-kak = { };

  # Git path substitution (nixpkgs hardcodes git path)
  powerline-kak = { };
}
