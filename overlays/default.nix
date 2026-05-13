self: super:
let
  overlays = [
    (import ./pkgs.nix)
    (import ./plugins.nix)
  ];
in
super.lib.composeManyExtensions overlays self super
