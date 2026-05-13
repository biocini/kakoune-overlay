# kakoune-overlay

A Nix flake providing nightly git builds of Kakoune and its ecosystem,
analogous to [neovim-nightly-overlay](https://github.com/nix-community/neovim-nightly-overlay)
and [emacs-overlay](https://github.com/nix-community/emacs-overlay).

## Packages

### Core

| Package           | Source                                                                       | Description             |
| ----------------- | ---------------------------------------------------------------------------- | ----------------------- |
| `kakoune`         | [mawww/kakoune](https://github.com/mawww/kakoune)                            | The editor              |
| `kakoune-lsp`     | [kakoune-lsp/kakoune-lsp](https://github.com/kakoune-lsp/kakoune-lsp)        | LSP client              |
| `kak-tree-sitter` | [~hadronized/kak-tree-sitter](https://git.sr.ht/~hadronized/kak-tree-sitter) | Tree-sitter integration |

### Plugins

Plugin sources are tracked in `repos/plugins/manifest.json` and overlayed onto
`kakounePlugins`. Each plugin is built from the latest git revision using
`buildKakounePluginFrom2Nix`.

## Structure

```
.
├── flake.nix              # Flake outputs (overlay, packages, devShells)
├── overlay.nix            # Entry point — imports overlays/
├── overlays/
│   ├── default.nix        # Composes pkgs.nix + plugins.nix
│   ├── pkgs.nix           # Core package overrides (kakoune, lsp, tree-sitter)
│   └── plugins.nix        # kakounePlugins overlay from manifest.json
├── repos/
│   ├── core/
│   │   ├── kakoune.json          # Metadata: rev, sha256, version
│   │   ├── kakoune-lsp.json
│   │   ├── kak-tree-sitter.json
│   │   └── update                # Bash updater for core packages
│   └── plugins/
│       ├── manifest.json         # Plugin metadata
│       └── update                # Bash updater for plugins
├── update                 # Top-level delegator: ./update <repo>
└── .github/workflows/
    └── update.yml         # CI: matrix update of core + plugins
```

## Usage

### As an overlay

```nix
{
  inputs.kakoune-overlay = {
    url = "github:lane-core/kakoune-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, kakoune-overlay, ... }:
    let
      pkgs = import nixpkgs {
        overlays = [ kakoune-overlay.overlays.default ];
      };
    in {
      # pkgs.kakoune, pkgs.kakoune-lsp, pkgs.kak-tree-sitter
      # are now built from the latest git commits
      # pkgs.kakounePlugins.* are also updated from git
    };
}
```

### With home-manager

```nix
{
  programs.kakoune = {
    enable = true;
    package = pkgs.kakoune;
  };

  home.packages = [
    pkgs.kakoune-lsp
    pkgs.kak-tree-sitter
  ];
}
```

## Auto-updates

A GitHub Actions workflow runs every 8 hours to:

1. Update `flake.lock` (nixpkgs and other inputs)
2. Refresh source metadata in `repos/core/` and `repos/plugins/`
3. Commit and push automatically when changes are detected

The workflow mirrors [emacs-overlay's CI pattern](https://github.com/nix-community/emacs-overlay/blob/master/.github/workflows/ci.yml).

## Local development

```bash
nix build .#kakoune              # build editor from latest git
nix build .#kakoune-lsp          # build LSP client
nix build .#kak-tree-sitter      # build tree-sitter integration
nix develop                      # enter dev shell with all packages
```

### Updating sources locally

```bash
./update core      # refresh kakoune, kakoune-lsp, kak-tree-sitter
./update plugins   # refresh all plugins in repos/plugins/manifest.json
```

### Adding a new plugin

Edit `repos/plugins/manifest.json`:

```json
{
  "my-new-plugin": {
    "type": "github",
    "owner": "github-user",
    "repo": "my-repo",
    "rev": "abc123...",
    "sha256": "sha256-...",
    "version": "2024-01-15"
  }
}
```

Run `./update plugins` to refresh all plugin metadata, or use `nix-prefetch-url`
/`nix-prefetch-git` to get the hash manually.
