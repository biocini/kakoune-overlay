# kakoune-overlay

A Nix flake providing nightly git builds of Kakoune and its ecosystem,
analogous to [neovim-nightly-overlay](https://github.com/nix-community/neovim-nightly-overlay)
and [emacs-overlay](https://github.com/nix-community/emacs-overlay).

## Quickstart

### With flakes

```nix
{
  inputs.kakoune-overlay = {
    url = "github:biocini/kakoune-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, kakoune-overlay, ... }:
    let
      pkgs = import nixpkgs {
        overlays = [ kakoune-overlay.overlays.default ];
      };
    in {
      # pkgs.kakoune is now built from the latest git commit
      # pkgs.kakounePlugins.* are updated from upstream git as well
    };
}
```

### Without flakes

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = "https://github.com/biocini/kakoune-overlay/archive/master.tar.gz";
    }))
  ];
}
```

### With home-manager

```nix
{ pkgs, ... }: {
  programs.kakoune = {
    enable = true;
    package = pkgs.kakoune;
    config = {
      colorScheme = "default";
    };
    plugins = with pkgs.kakounePlugins; [
      kakoune-lsp
      kak-tree-sitter
      # any other plugins from the overlay
    ];
  };
}
```

## Binary cache

Build artifacts are pushed to Cachix. Add the following to your Nix
configuration to avoid building from source:

```nix
nix.settings = {
  substituters = [ "https://kakoune-overlay.cachix.org" ];
  trusted-public-keys = [
    "kakoune-overlay.cachix.org-1:wvzi0bQFg1NEkPF1eaU3atZD/4soGx1IG6sensUdvxY="
  ];
};
```

Or use the flake directly — the `nixConfig` in `flake.nix` already declares
these settings, so `nix build` will prompt you to accept them.

## Packages

### Core

| Package           | Source                                                                       | Description             |
| ----------------- | ---------------------------------------------------------------------------- | ----------------------- |
| `kakoune`         | [mawww/kakoune](https://github.com/mawww/kakoune)                            | The editor              |
| `kakoune-lsp`     | [kakoune-lsp/kakoune-lsp](https://github.com/kakoune-lsp/kakoune-lsp)        | LSP client              |
| `kak-tree-sitter` | [~hadronized/kak-tree-sitter](https://git.sr.ht/~hadronized/kak-tree-sitter) | Tree-sitter integration |

### Plugins

This overlay extends `kakounePlugins` with **72 additional plugins** sourced
from GitHub repositories tagged with `topic:kakoune` and `topic:plugin`,
filtered to those updated within the last two years. Each plugin is built
from the latest git revision using `buildKakounePluginFrom2Nix`.

A sampling of available plugins:

- `kakounePlugins.popup` — popup windows
- `kakounePlugins.kaktree` — file tree sidebar
- `kakounePlugins.peneira` — fuzzy finder framework
- `kakounePlugins.kakoune-smooth-scroll` — smooth scrolling
- `kakounePlugins.kakoune-focus` — focus mode
- `kakounePlugins.kakoune-git-mode` — git workflow helpers
- `kakounePlugins.powerline-kak` — powerline status bar
- `kakounePlugins.smarttab` — smart tab behavior

The full list is generated from `repos/plugins/manifest.json`.

## Structure

```
.
├── flake.nix              # Flake outputs (overlay, packages, devShells)
├── overlay.nix            # Entry point — imports overlays/
├── overlays/
│   ├── default.nix        # Composes pkgs.nix + plugins.nix
│   ├── pkgs.nix           # Core package overrides
│   └── plugins.nix        # kakounePlugins overlay from manifest.json
├── repos/
│   ├── core/
│   │   ├── kakoune.json          # Metadata: rev, sha256, version
│   │   ├── kakoune-lsp.json
│   │   ├── kak-tree-sitter.json
│   │   └── update                # Bash updater for core packages
│   └── plugins/
│       ├── manifest.json         # Plugin metadata (72 plugins)
│       └── update                # Bash updater for plugins
├── update                 # Top-level delegator: ./update <repo>
└── .github/workflows/
    └── update.yml         # CI: matrix update of core + plugins
```

## Auto-updates

A GitHub Actions workflow runs every 8 hours to:

1. Update `flake.lock`
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
or `nix-prefetch-git` to get the hash manually.
