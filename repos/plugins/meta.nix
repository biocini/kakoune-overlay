# Build metadata for kakoune plugins.
#
# The manifest (manifest.json) is purely source metadata: what to fetch.
# This file is purely build metadata: what to do with it.
#
# Each entry is an attribute set. Plugins that need nothing beyond the
# default buildKakounePlugin behavior are not listed.
#
# Known keys:
#   delegated   bool   — use nixpkgs' derivation (overrideAttrs) instead of
#                        buildKakounePlugin
#   isRust      bool   — build the Rust binary via cargo build --release
#   toolDeps    [str]  — runtime tool dependencies (e.g. "fzf", "git")
#   pluginDeps  [str]  — other kakoune plugin dependencies (by pname)
#
# Any other attributes are passed through:
#   - for delegated plugins: merged into overrideAttrs
#   - for non-delegated plugins: merged into buildKakounePlugin / mkDerivation

{ pkgs }:
{
  # Rust binaries — delegated to nixpkgs, inject cargo handling
  parinfer-rust = {
    delegated = true;
    isRust = true;
  };
  kakoune-lsp = {
    delegated = true;
    isRust = true;
  };
  hop-kak = {
    delegated = true;
    isRust = true;
  };

  # Rust binaries — non-delegated, built by overlay
  kak-dap = {
    isRust = true;
  };
  kakpipe = {
    isRust = true;
  };
  popup-kak = {
    isRust = true;
    toolDeps = [ "tmux" ];
  };

  # Compiled binaries — delegate to nixpkgs
  kak-ansi = {
    delegated = true;
  };
  rep = {
    delegated = true;
  };

  # Delegated with path substitutions from nixpkgs
  fzf-kak = {
    delegated = true;
    toolDeps = [ "fzf" ];
  };
  powerline-kak = {
    delegated = true;
    toolDeps = [ "git" ];
  };
  quickscope-kak = {
    delegated = true;
  };
  kak-plumb = {
    delegated = true;
    toolDeps = [ "plan9port" ];
  };

  # Delegated with fixup
  kakoune-rainbow = {
    delegated = true;
    toolDeps = [ "guile" ];
    pluginDeps = [ "connect-kak" ];
    preFixup = ''
      mkdir -p $out/bin
      mv $out/share/kak/autoload/plugins/kakoune-rainbow/bin/kak-rainbow.scm $out/bin
      substituteInPlace $out/bin/kak-rainbow.scm \
        --replace '/usr/bin/env -S guile' '${pkgs.guile}/bin/guile'
      substituteInPlace $out/share/kak/autoload/plugins/kakoune-rainbow/rainbow.kak \
        --replace '%sh{dirname "$kak_source"}' "'$out'"
    '';
  };

  # Pure .kak plugins with deps
  connect-kak = {
    toolDeps = [ "socat" ];
    pluginDeps = [ "prelude-kak" ];
  };
  kakoune-comefrom = {
    toolDeps = [ "attr" ];
  };
  pandoc-kak = {
    toolDeps = [ "pandoc" ];
  };
  wiki-kak = {
    toolDeps = [ "xdg-utils" ];
  };

  # Non-nixpkgs plugin with path rewrite (was in overrides.nix)
  lean4-kak = {
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/lean4-kak/lean4.kak \
        --replace '$kak_config/lean4-replace-abbreviations.py' \
          "$out/share/kak/autoload/plugins/lean4-kak/lean4-replace-abbreviations.py"
    '';
  };
}
