{
  description = "Kakoune overlay — nightly git builds of kakoune and its ecosystem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      overlays.default = import ./overlay.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          overlayed = pkgs.extend self.overlays.default;
        in
        {
          inherit (overlayed)
            kakoune
            kakoune-unwrapped
            kakoune-lsp
            kak-tree-sitter
            kak-tree-sitter-unwrapped
            ;
        }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = builtins.attrValues self.packages.${system};
        };
      });
    };
}
