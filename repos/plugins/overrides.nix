# Plugin build-time overrides for plugins NOT in nixpkgs.
#
# Plugins that already exist in nixpkgs with custom overrides are handled
# by the overlay automatically (src is updated, nixpkgs' build logic is
# preserved).  This file is ONLY for plugins discovered by the update
# script that need build-time path rewrites.
#
# buildKakounePluginFrom2Nix copies .kak files into the store.  It does
# NOT wrap binaries or modify PATH.  Runtime binary dependencies are the
# user's responsibility — they must ensure the required tools are
# available in their login environment (e.g. via home.packages or
# environment.systemPackages).
#
# The ONLY legitimate use of this file is `postInstall` with
# `substituteInPlace` (or equivalent) to rewrite hardcoded paths inside
# .kak files so they resolve correctly from the Nix store.
#
# Example entry:
#
#   my-plugin = {
#     postInstall = ''
#       substituteInPlace $out/share/kak/autoload/plugins/my-plugin/rc.kak \
#         --replace '$kak_config/my-script.py' "$out/share/kak/autoload/plugins/my-plugin/my-script.py"
#     '';
#   };
#
# Missing plugins are treated as no-op (no postInstall).

{ pkgs }:
{
  # 2025-12-12 — Lean 4 language support
  # Rewrites hardcoded $kak_config-relative path to absolute store path.
  lean4 = {
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/lean4/lean4.kak \
        --replace '$kak_config/lean4-replace-abbreviations.py' "$out/share/kak/autoload/plugins/lean4/lean4-replace-abbreviations.py"
    '';
  };
}
