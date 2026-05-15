self: super:
let
  overlays = [
    (import ./wrap-kakoune.nix { inherit (super) lib symlinkJoin makeWrapper; })
    (import ./plugins.nix)
    (import ./pkgs.nix)
  ];
in
super.lib.composeManyExtensions overlays self super
