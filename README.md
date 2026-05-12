# kak-overlay

A Nix flake providing nightly git builds of Kakoune and its ecosystem,
analogous to [neovim-overlay](https://github.com/nix-community/neovim-overlay)
and [emacs-overlay](https://github.com/nix-community/emacs-overlay).

## Packages

| Package           | Source                                                                       | Description             |
| ----------------- | ---------------------------------------------------------------------------- | ----------------------- |
| `kakoune`         | [mawww/kakoune](https://github.com/mawww/kakoune)                            | The editor              |
| `kakoune-lsp`     | [kakoune-lsp/kakoune-lsp](https://github.com/kakoune-lsp/kakoune-lsp)        | LSP client              |
| `kak-tree-sitter` | [~hadronized/kak-tree-sitter](https://git.sr.ht/~hadronized/kak-tree-sitter) | Tree-sitter integration |

## Usage

### As an overlay

```nix
{
  inputs.kak-overlay = {
    url = "github:lane-core/kak-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, kak-overlay, ... }:
    let
      pkgs = import nixpkgs {
        overlays = [ kak-overlay.overlays.default ];
      };
    in {
      # pkgs.kakoune, pkgs.kakoune-lsp, pkgs.kak-tree-sitter
      # are now built from the latest git commits
    };
}
```

### With home-manager

```nix
{
  programs.kakoune = {
    enable = true;
    package = pkgs.kakoune;  # uses the overlayed git build
  };

  home.packages = [
    pkgs.kakoune-lsp
    pkgs.kak-tree-sitter
  ];
}
```

## Auto-updates

A GitHub Actions workflow runs daily to update the locked revisions in
`flake.lock`. The workflow commits and pushes automatically when changes
are detected.

## Local development

```bash
nix build .#kakoune        # build editor from latest git
nix build .#kakoune-lsp    # build LSP client
nix build .#kak-tree-sitter # build tree-sitter integration
nix develop                # enter dev shell with all packages
```
