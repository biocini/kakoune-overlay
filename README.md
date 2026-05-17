# kakoune-overlay

A Nix flake providing both stable (latest release) and nightly git builds
of Kakoune and its ecosystem, analogous to
[neovim-nightly-overlay](https://github.com/nix-community/neovim-nightly-overlay)
and [emacs-overlay](https://github.com/nix-community/emacs-overlay).

## Quickstart

Add the overlay to your flake:

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
      # pkgs.kakoune        — latest stable release (currently v2026.04.12)
      # pkgs.kakoune-git    — latest master commit
      # pkgs.kakounePlugins.* are updated from upstream git as well
    };
}
```

Or without flakes:

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = "https://github.com/biocini/kakoune-overlay/archive/master.tar.gz";
    }))
  ];
}
```

With home-manager:

```nix
{ pkgs, ... }: {
  programs.kakoune = {
    enable = true;
    package = pkgs.kakoune;
    plugins = with pkgs.kakounePlugins; [
      kakoune-lsp
      kak-tree-sitter
      # additional plugins from the overlay
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

## Contents of the overlay

This overlay consists of two overlays: `pkgs` and `plugins`. You can use both
of them as a whole overlay or only one of them.

### `pkgs` overlay

#### Kakoune editor

This overlay provides two builds of the Kakoune editor:

- **`kakoune`** — built from the latest stable release tag
- **`kakoune-git`** — built from the latest `master` commit

Both are proper wrapper derivations (like nixpkgs' `pkgs.kakoune`),
so `KAKOUNE_RUNTIME` and plugin integration work identically.
The unwrapped variants (`kakoune-unwrapped`, `kakoune-unwrapped-git`)
are also exposed if you need the raw editor derivation.

Companion tools (`kakoune-lsp`, `kak-tree-sitter`) are built from
upstream git and updated automatically.

| Attribute               | Source                                                                       | Description               |
| ----------------------- | ---------------------------------------------------------------------------- | ------------------------- |
| `kakoune`               | [mawww/kakoune](https://github.com/mawww/kakoune) (latest release tag)       | Stable editor             |
| `kakoune-git`           | [mawww/kakoune](https://github.com/mawww/kakoune) (latest `master`)          | Git editor                |
| `kakoune-unwrapped`     | [mawww/kakoune](https://github.com/mawww/kakoune) (latest release tag)       | Stable editor (unwrapped) |
| `kakoune-unwrapped-git` | [mawww/kakoune](https://github.com/mawww/kakoune) (latest `master`)          | Git editor (unwrapped)    |
| `kakoune-lsp`           | [kakoune-lsp/kakoune-lsp](https://github.com/kakoune-lsp/kakoune-lsp)        | LSP client                |
| `kak-tree-sitter`       | [~hadronized/kak-tree-sitter](https://git.sr.ht/~hadronized/kak-tree-sitter) | Tree-sitter integration   |

### `plugins` overlay

#### Kakoune plugins from GitHub

This overlay extends `kakounePlugins` with additional plugins sourced from
GitHub repositories tagged with `topic:kakoune` and `topic:plugin`. Each plugin is built from the
latest git revision using `buildKakounePluginFrom2Nix`.

The plugin set is generated from `repos/plugins/manifest.json` and updated
automatically by CI.

To discover available plugins:

```bash
nix search github:biocini/kakoune-overlay kakounePlugins
# or, with the overlay enabled:
nix search .#legacyPackages.x86_64-linux.kakounePlugins
```

#### Custom plugins

The overlay inherits `buildKakounePluginFrom2Nix` from nixpkgs, which you can
use to define your own plugins:

```nix
let myPlugin = pkgs.kakouneUtils.buildKakounePluginFrom2Nix {
  pname = "my-plugin";
  version = "2024-01-15";
  src = pkgs.fetchFromGitHub {
    owner = "me";
    repo = "my-plugin.kak";
    rev = "abc123...";
    sha256 = "sha256-...";
  };
}; in
pkgs.kakoune.override {
  plugins = with pkgs.kakounePlugins; [ myPlugin kakoune-lsp ];
}
```

## Auto-updates

A GitHub Actions workflow runs every 8 hours to:

1. Update `flake.lock`
2. Refresh source metadata in `repos/core/`
3. Refresh existing plugin metadata in `repos/plugins/manifest.json`
4. Commit and push automatically when changes are detected

**New plugins are never auto-committed.** When the discovery script finds
repos newly tagged with `topic:kakoune+topic:plugin`, a separate
`workflow_dispatch` job opens a PR for human review. Each candidate plugin
is vetted for security issues (outbound network calls, sensitive data
access, obfuscated shell) and checked for hardcoded paths requiring Nix
store rewrites before landing on `master`.

The update workflow mirrors [emacs-overlay's CI pattern](https://github.com/nix-community/emacs-overlay/blob/master/.github/workflows/ci.yml).

## Local development

```bash
nix build .#kakoune              # build stable editor
nix build .#kakoune-git          # build editor from latest master
nix build .#kakoune-lsp          # build LSP client
nix build .#kak-tree-sitter      # build tree-sitter integration
```

### Updating sources locally

```bash
./update core      # refresh kakoune, kakoune-lsp, kak-tree-sitter
./update plugins   # refresh all plugins in repos/plugins/manifest.json
```

### Adding a new plugin

The overlay discovers new plugins automatically from GitHub repos tagged with
`topic:kakoune+topic:plugin`. Run the discovery script locally:

```bash
./repos/plugins/discover   # writes candidates to /tmp/new-plugins.json
```

Or trigger the CI workflow which opens a PR for review:

```bash
gh workflow run new-plugin-pr.yml
```

To add a plugin manually, edit `repos/plugins/manifest.json`:

```json
{
  "my-new-plugin": {
    "fetcher": "github",
    "repo": "github-user/my-repo",
    "branch": "master",
    "rev": "abc123...",
    "sha256": "sha256-...",
    "version": "2024-01-15"
  }
}
```

Run `./update plugins` to refresh all plugin metadata, or use `nix-prefetch-url`
or `nix-prefetch-git` to get the hash manually.

## AI disclosure

This repository was created and is maintained with assistance from AI
systems. The initial architecture, Nix overlay design, and CI workflows
were developed in collaboration with the [pi](https://github.com/earendil-works/pi)
coding agent (Kimi 2.6). Ongoing maintenance — including plugin discovery, security
vetting, dependency auditing, and documentation updates — continues to
involve AI-assisted workflows. Specifically:

- **Plugin discovery** (`repos/plugins/discover`) is automated but new
  plugins are reviewed via a Copilot-assisted PR workflow before landing
  on `master`
- **Security vetting** (`.pi/skills/kakoune-overlay-security/SKILL.md`)
  scans each candidate plugin's `.kak` source for outbound network calls,
  sensitive data access, obfuscated shell, and suspicious repo metadata.
  Plugins flagged with a `FAIL` verdict block manifest updates and open a
  `[SECURITY FAIL]` PR for human review. Audit findings are persisted in
  `docs/security-audit.json` and reused across sessions when upstream source
  has not changed.
- **Build-time path rewrites** (`repos/plugins/overrides.nix`) are
  audited for hardcoded paths that won't resolve from the Nix store
- **Commits** in this repo follow Conventional Commits with a
  `Generated-with` footer indicating whether the work was done via pi
  or GitHub Actions (Copilot-assisted)

All AI-generated changes are subject to human review before merge.

**User responsibility:** The automated security vetting is a tool to
assist maintainer review, not a guarantee of safety. Kakoune plugins
execute shell code with the privileges of your editor session. You are
ultimately responsible for vetting any plugin before installation,
regardless of whether it comes from this overlay, nixpkgs, or upstream
directly.

## Structure

```
.
├── flake.nix              # Flake outputs (overlay, packages, devShells)
├── overlay.nix            # Entry point — imports overlays/
├── overlays/
│   ├── default.nix        # Composes pkgs.nix + plugins.nix
│   ├── pkgs.nix           # Core package overrides
│   └── plugins.nix        # kakounePlugins overlay from manifest.json
├── docs/
│   └── security-audit.json     # Persisted security audit findings
├── repos/
│   ├── core/
│   │   ├── kakoune.json          # Metadata: rev, sha256, version (git)
│   │   ├── kakoune-stable.json   # Metadata: rev, sha256, version (stable)
│   │   ├── kakoune-lsp.json
│   │   ├── kak-tree-sitter.json
│   │   └── update                # Bash updater for core packages
│   └── plugins/
│       ├── manifest.json         # Plugin metadata
│       ├── overrides.nix         # Build-time path rewrites
│       ├── discover              # Discover new plugins from GitHub
│       └── update                # Bash updater for existing plugins
├── .pi/skills/            # Agent skills (security, deps)
├── update                 # Top-level delegator: ./update <repo>
└── .github/workflows/
    ├── update.yml           # CI: matrix update of core + plugins
    └── new-plugin-pr.yml    # CI: propose new plugins via PR
```
