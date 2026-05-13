# Plugin dependency overrides for plugins NOT in nixpkgs.
#
# Plugins that already exist in nixpkgs with custom overrides are handled
# by the overlay automatically (src is updated, nixpkgs' build logic is
# preserved). This file is ONLY for plugins discovered by the update
# script that are NOT in nixpkgs and need external dependencies.
#
# Each entry maps a normalized plugin name to one of:
#
#   { deps = [ <nixpkg> ]; bins = [ "<bin>" ]; }
#     → listed binaries are symlinked into $out/share/kak/bin/
#     → deps are also added to propagatedBuildInputs
#
#   { deps = [ <nixpkg> ]; bins = [ "<bin>" ]; postInstall = "..."; }
#     → same as above, plus custom postInstall script
#
#   { deps = []; }
#     → explicitly vetted: no additional dependencies
#
# Missing plugins are treated as deps = [] (no dependencies).
#
# IMPORTANT: bins must list the exact executable names the plugin calls
# by bare name in its %sh{...} blocks.  These are determined by reading
# the plugin source, NOT guessed from the package name.

{ pkgs }:
{
  # ── Explicitly vetted (no deps) ───────────────────────────────────────
  popup = {
    deps = [ ];
  };
  match = {
    deps = [ ];
  };
  kak-duras = {
    deps = [ ];
  };
  giallo = {
    deps = [ ];
  };
  kakeidoscope = {
    deps = [ ];
  };
  kakounicode = {
    deps = [ ];
  };
  kakoune-focus = {
    deps = [ ];
  };
  yummy = {
    deps = [ ];
  };
  highlighters = {
    deps = [ ];
  };
  eak = {
    deps = [ ];
  };
  kalolo = {
    deps = [ ];
  };
  kakoune-themes = {
    deps = [ ];
  };
  objetiva = {
    deps = [ ];
  };

  # ── Dependencies with explicit binary whitelist ───────────────────────

  # 2026-04-13 — smooth scroll with optional python animator
  kakoune-smooth-scroll = {
    deps = [ pkgs.python3 ];
    bins = [ "python3" ];
  };

  # 2026-02-06 — git command mode (calls git in %sh)
  kakoune-git-mode = {
    deps = [ pkgs.git ];
    bins = [ "git" ];
  };

  # 2025-12-16 — hexdump buffer commands (calls xxd in %sh)
  xxd = {
    deps = [ pkgs.xxd ];
    bins = [ "xxd" ];
  };

  # 2025-12-12 — Lean 4 language support (calls python for abbreviations)
  lean4 = {
    deps = [ pkgs.python3 ];
    bins = [ "python3" ];
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/lean4/lean4.kak \
        --replace '$kak_config/lean4-replace-abbreviations.py' "$out/share/kak/autoload/plugins/lean4/lean4-replace-abbreviations.py"
    '';
  };

  # 2025-12-04 — lua execution provider for Kakoune
  luar = {
    deps = [ pkgs.lua ];
    bins = [ "lua" ];
  };

  # 2025-01-31 — GDB debugging integration (calls gdb, perl, socat)
  kakoune-gdb = {
    deps = [
      pkgs.gdb
      pkgs.perl
      pkgs.socat
    ];
    bins = [
      "gdb"
      "perl"
      "socat"
    ];
  };

  # 2025-07-24 — tag sidebar (calls ctags, readtags, awk)
  tagbar = {
    deps = [ pkgs.universal-ctags ];
    bins = [
      "ctags"
      "readtags"
    ];
  };

  # 2025-07-24 — keyboard layout switching (calls perl)
  langmap = {
    deps = [ pkgs.perl ];
    bins = [ "perl" ];
  };

  # 2025-08-15 — file tree sidebar (calls perl)
  kaktree = {
    deps = [ pkgs.perl ];
    bins = [ "perl" ];
  };
}
