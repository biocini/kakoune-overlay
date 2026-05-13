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

  # ── Dependencies via PATH ─────────────────────────────────────────────

  # ── Dependencies with custom substitution ─────────────────────────────

  # ── Placeholder: to be filled in ──────────────────────────────────────
}
