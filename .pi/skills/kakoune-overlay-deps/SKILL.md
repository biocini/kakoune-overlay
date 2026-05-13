---
name: kakoune-overlay-deps
description: Add build-time path rewrites (postInstall + substituteInPlace) for kakoune plugins whose .kak files contain hardcoded paths that won't resolve from the Nix store. Use when reviewing a new plugin or fixing a plugin that fails to find its bundled scripts/assets after installation.
---

# Adding Build-Time Overrides to Kakoune Plugins

This skill documents how to add build-time path rewrites for plugins
in the kakoune-overlay.

## When to use

Use when a plugin contains **hardcoded paths** inside its `.kak` files
that won't resolve correctly from the Nix store after installation.

Common patterns that need rewriting:

- `$kak_config/some-script.py` — path relative to user config, won't exist post-install
- `~/.config/kak/...` — user home path, invalid in the store
- Paths relative to the plugin's source directory that won't exist post-install

## What NOT to track here

**Runtime binary dependencies are NOT handled by this overlay.**

Plugins that call external tools by bare name in `%sh{...}` blocks
(e.g. `%sh{ git status }`, `%sh{ fzf }`) do NOT need entries in this
file. Those binaries must be available in the user's login
environment (via `home.packages`, `environment.systemPackages`, etc.).

This is consistent with how nixpkgs itself handles `kakounePlugins` —
no plugin derivation in nixpkgs specifies runtime binary deps.

## Workflow

### 1. Check if the plugin has hardcoded paths

Read the plugin's main `.kak` file(s) and look for paths that assume a
specific filesystem layout:

```bash
curl -sL "https://raw.githubusercontent.com/$owner/$repo/$branch/$plugin.kak" | \
  grep -E '\$kak_config|~/|\.\./'
```

### 2. Check if the referenced file ships with the plugin

If the path points to a file that is part of the plugin repo (e.g.
`$kak_config/lean4-replace-abbreviations.py` ships in the plugin's
`lean4/` directory), it can be rewritten to the Nix store path at
build time.

### 3. Edit `repos/plugins/overrides.nix`

Use the plugin's **normalized name** (as it appears in
`repos/plugins/manifest.json` keys):

```nix
{ _pkgs }:
{
  my-plugin = {
    postInstall = ''
      substituteInPlace $out/share/kak/autoload/plugins/my-plugin/rc.kak \
        --replace '$kak_config/my-script.py' "$out/share/kak/autoload/plugins/my-plugin/my-script.py"
    '';
  };
}
```

### 4. Verify the build

```bash
nix build --impure --expr 'with (import <nixpkgs> { overlays = [ (import ./overlay.nix) ]; }); kakounePlugins.$plugin_name'
grep -n 'my-script.py' result/share/kak/autoload/plugins/$plugin_name/*.kak
```

Confirm the path has been rewritten to a Nix store path.

### 5. Commit

Include the plugin name in the commit subject and explain what path was
rewritten.

## Rules

- **Only `postInstall` with `substituteInPlace` (or equivalent) is
  supported.** Do not add `deps`, `bins`, or any other fields.
- **Use normalized names** matching `repos/plugins/manifest.json` keys.
- **Missing plugins are treated as no-op.** Only add entries when a
  path rewrite is actually needed.
- **Always prefer nixpkgs' existing overrides.** The overlay's
  `mkPlugin` checks `builtins.hasAttr name super.kakounePlugins` and
  uses `overrideAttrs` when a plugin already exists in nixpkgs.
