# Adding Dependencies to Kakoune Plugins

This skill documents how to research and add external dependencies for
plugins in the kakoune-overlay.

## When to use

Use when a newly-discovered plugin (or an existing one) calls external
tools in `%sh{...}` blocks, compiles its own binary, or otherwise needs
packages from nixpkgs.

## Workflow

### 1. Discover which plugins need dependencies

For each new plugin in `repos/plugins/manifest.json`, check its source
code for external tool usage:

```bash
# Quick check: grep for %sh blocks mentioning common tools
curl -sL "https://github.com/$owner/$repo/raw/$branch/$repo.kak" | \
  grep -E '%sh\{|\bfzf\b|\bgit\b|\blua\b|\bpython\b|\bnode\b'
```

Also read the README for documented dependencies.

### 2. Check if plugin already exists in nixpkgs

```bash
nix-search kakounePlugins 2>/dev/null | grep "$plugin_name"
```

If it exists, **do not** create a custom derivation. The overlay will
automatically use `overrideAttrs` to update nixpkgs' version. Only add
to `repos/plugins/overrides.nix` if there are _additional_ dependencies
not covered by nixpkgs' existing override.

### 3. Edit `repos/plugins/overrides.nix`

Use the plugin's **normalized name** (as it appears in the manifest keys):

```nix
{ pkgs }:
{
  # No dependencies (explicitly vetted)
  byline = { deps = []; };

  # Symlink binaries into share/kak/bin/
  fzf = { deps = [ pkgs.fzf ]; };

  # Dependencies + custom postInstall for substituteInPlace
  powerline = {
    deps = [ pkgs.git ];
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/powerline/rc/modules/git.kak \
        --replace ' git ' ' ${pkgs.git}/bin/git '
    '';
  };
}
```

**Entry types:**

| Form                                     | Effect                                                                         |
| ---------------------------------------- | ------------------------------------------------------------------------------ |
| `{ deps = []; }`                         | Vetted: no external deps                                                       |
| `{ deps = [ pkgs.X ]; }`                 | Symlinks useful binaries from `X/bin/` into `$out/share/kak/bin/`, adds to `propagatedBuildInputs` (noise like `idle`, `pydoc`, `*-config` is filtered) |
| `{ deps = [...]; postInstall = "..."; }` | Same as above, plus custom `postInstall` script appended after symlink step    |

### 4. Verify the build

```bash
nix flake check --all-systems
nix build --impure --expr 'with (import <nixpkgs> { overlays = [ (import ./overlay.nix) ]; }); kakounePlugins.$plugin_name'
ls -la result/share/kak/bin/  # verify symlinks
```

### 5. Commit

Include the plugin name in the commit subject and list researched deps
in the body.

## Rules

- **Always prefer nixpkgs' existing overrides.** The overlay's
  `mkPlugin` checks `builtins.hasAttr name super.kakounePlugins` and
  uses `overrideAttrs` when a plugin already exists in nixpkgs.
- **Use normalized names** matching `repos/plugins/manifest.json` keys.
- **Empty `deps` means "vetted, no deps."** Don't omit the entry;
  explicitly mark it as `{ deps = []; }` to signal the plugin has been
  reviewed.
- **Rare case — compiled plugins:** If a plugin builds its own binary
  (e.g. a Rust crate or C program), it may need a full custom
  derivation. Consider adding it as a top-level package in
  `overlays/pkgs.nix` instead of in the plugin overlay.
