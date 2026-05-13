# Plugin dependency overrides for plugins NOT in nixpkgs.
#
# Plugins that already exist in nixpkgs with custom overrides are handled
# by the overlay automatically (src is updated, nixpkgs' build logic is
# preserved). This file is ONLY for plugins discovered by the update
# script that are NOT in nixpkgs and need external dependencies.
#
# Each entry maps a normalized plugin name to one of:
#
#   { deps = [ <nixpkg> ]; }
#     → dependencies symlinked into $out/share/kak/bin/
#     → also added to propagatedBuildInputs
#
#   { deps = [ <nixpkg> ]; postInstall = "..."; }
#     → same as above, plus custom postInstall script
#
#   { deps = []; }
#     → explicitly vetted: no additional dependencies
#
# Missing plugins are treated as deps = [] (no dependencies).

{ pkgs }:
{
  # ── Explicitly vetted (no deps) ───────────────────────────────────────
  popup = {
    deps = [ ];
  };

  # 2026-05-09 — pure Kakoune script (surround / object motion)
  match = {
    deps = [ ];
  };

  # 2026-04-29 — pure Kakoune script (alternative surround)
  kak-duras = {
    deps = [ ];
  };

  # 2026-04-21 — color theme
  giallo = {
    deps = [ ];
  };

  # 2026-04-18 — color theme (kaleidoscope)
  kakeidoscope = {
    deps = [ ];
  };

  # 2026-04-13 — Unicode insertion utility
  kakounicode = {
    deps = [ ];
  };

  # 2026-04-13 — focus mode (dim inactive text)
  kakoune-focus = {
    deps = [ ];
  };

  # 2026-04-12 — yank-ring / history utility
  yummy = {
    deps = [ ];
  };

  # 2026-04-04 — highlighter management helpers
  highlighters = {
    deps = [ ];
  };

  # 2026-03-31 — easy-motion-like navigation (pure kak)
  eak = {
    deps = [ ];
  };

  # 2026-03-28 — color theme
  kalolo = {
    deps = [ ];
  };

  # 2026-03-02 — curated color themes collection
  kakoune-themes = {
    deps = [ ];
  };

  # 2026-01-24 — text objects plugin (requires luar for lua command)
  # No external binaries; lua interpreter provided by luar plugin
  objetiva = {
    deps = [ ];
  };

  # ── Dependencies via PATH ─────────────────────────────────────────────

  # 2026-04-13 — smooth scroll with optional python animator
  kakoune-smooth-scroll = {
    deps = [ pkgs.python3 ];
  };

  # 2026-02-06 — git command mode (calls git in %sh)
  kakoune-git-mode = {
    deps = [ pkgs.git ];
  };

  # 2025-12-16 — hexdump buffer commands (calls xxd in %sh)
  xxd = {
    deps = [ pkgs.xxd ];
  };

  # 2025-12-12 — Lean 4 language support (calls python for abbreviations)
  lean4 = {
    deps = [ pkgs.python3 ];
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/lean4/lean4.kak \
        --replace '$kak_config/lean4-replace-abbreviations.py' "$out/share/kak/autoload/plugins/lean4/lean4-replace-abbreviations.py"
    '';
  };

  # 2025-12-04 — lua execution provider for Kakoune
  # Provides the `lua` Kakoune command used by objetiva, peneira, etc.
  luar = {
    deps = [ pkgs.lua ];
  };

  # 2025-01-31 — GDB debugging integration (calls gdb, perl, socat)
  kakoune-gdb = {
    deps = [ pkgs.gdb pkgs.perl pkgs.socat ];
  };

  # 2025-07-24 — tag sidebar (calls ctags, readtags, awk)
  tagbar = {
    deps = [ pkgs.universal-ctags ];
  };

  # 2025-07-24 — keyboard layout switching (calls perl)
  langmap = {
    deps = [ pkgs.perl ];
  };

  # 2025-08-15 — file tree sidebar (calls perl)
  kaktree = {
    deps = [ pkgs.perl ];
  };
}
