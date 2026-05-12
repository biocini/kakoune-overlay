{
  description = "Kakoune overlay — nightly git builds of kakoune, kakoune-lsp, kak-tree-sitter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    kakoune-src = {
      url = "github:mawww/kakoune";
      flake = false;
    };

    kakoune-lsp-src = {
      url = "github:kakoune-lsp/kakoune-lsp";
      flake = false;
    };

    kak-tree-sitter-src = {
      url = "sourcehut:~hadronized/kak-tree-sitter";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      kakoune-src,
      kakoune-lsp-src,
      kak-tree-sitter-src,
    }:
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
      overlays.default = import ./overlay.nix {
        inherit kakoune-src kakoune-lsp-src kak-tree-sitter-src;
      };

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
