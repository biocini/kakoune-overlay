---
name: kakoune-overlay-add-plugin
description: Add a new kakoune plugin to the overlay. Takes a repository URL, fetches source metadata, audits for runtime dependencies, performs a mandatory security review, and generates the manifest.json and meta.nix entries. Supports GitHub, GitLab, Codeberg, Sourcehut, and plain git URLs.
---

# Adding a New Kakoune Plugin to the Overlay

This skill walks through adding a single new plugin to `repos/plugins/manifest.json`
and, if needed, `repos/plugins/meta.nix`.

## Input

A single repository URL, e.g. `https://github.com/owner/repo`.

## Step 1: Parse the input URL

Determine the fetcher type from the URL:

| URL pattern               | fetcher     | repo value                   |
| ------------------------- | ----------- | ---------------------------- |
| `github.com/owner/repo`   | `github`    | `owner/repo`                 |
| `gitlab.com/owner/repo`   | `gitlab`    | `owner/repo`                 |
| `codeberg.org/owner/repo` | `codeberg`  | `owner/repo`                 |
| `git.sr.ht/~owner/repo`   | `sourcehut` | `owner/repo` (strip the `~`) |
| anything else             | `git`       | the full URL                 |

Strip `.git` suffix if present. Strip trailing slashes.

## Step 2: Determine the pname

Normalize the repository name: replace `.` with `-`. This is the **candidate pname**.

Before using it, check:

1. **Nixpkgs collision**: Does `super.kakounePlugins.<pname>` exist in nixpkgs?

   ```bash
   nix eval --json 'nixpkgs#kakounePlugins' 2>/dev/null | jq -r 'keys[]' | grep -x "<pname>"
   ```

   If it exists, the manifest key **must** match the nixpkgs attribute name.
   If the normalized name differs from the nixpkgs name, use the nixpkgs name
   and note the discrepancy for the user.

2. **Existing manifest collision**: Does the pname already exist in `repos/plugins/manifest.json`?
   ```bash
   jq -r 'keys[]' repos/plugins/manifest.json | grep -x "<pname>"
   ```
   If it exists, stop and report that the plugin is already in the overlay.

## Step 3: Fetch source metadata

Determine the default branch and latest commit, then prefetch.

### For GitHub

Default branch:

```bash
curl -sL "https://api.github.com/repos/$owner/$repo" | jq -r '.default_branch'
```

Prefetch (gives `rev`, `sha256`, and `date`):

```bash
nix-prefetch-git --quiet "https://github.com/$owner/$repo" --rev "refs/heads/$branch"
```

Alternative (atom feed, no token needed, consistent with `./update`):

```bash
curl -sL "https://github.com/$owner/$repo/commits/$branch.atom" | \
  grep -oP '<id>tag:github.com,2008:Grit::Commit/\K[0-9a-f]{40}' | head -1
```

### For other forges

Use `nix-prefetch-git` with the repository URL and discover the default branch
via the forge API or by cloning briefly:

```bash
nix-prefetch-git --quiet "$url" --rev "refs/heads/$branch"
```

### Extract version

From the `nix-prefetch-git` output, take the `date` field and format it as
`YYYY-MM-DD` for the `version` field.

**Critical:** The `sha256` field from `nix-prefetch-git` is **base32**.
Use that value directly. Do NOT use the `hash` field (SRI format) — SRI hashes
will cause "invalid SRI hash" build failures in this repo.

## Step 4: Fetch description and license

### For GitHub

```bash
curl -sL "https://api.github.com/repos/$owner/$repo" | jq -r '.description, .license.spdx_id'
```

Include `description` in the manifest if non-empty and not `null`.
Include `license` only if it is a valid SPDX identifier (not `null`, `NOASSERTION`, or empty).

### For other forges

Fetch the repository info page or API and extract description and license
when available. Omit fields that cannot be determined reliably.

## Step 5: Generate the manifest entry

Construct the JSON entry. Example:

```json
{
  "fzf-kak": {
    "fetcher": "github",
    "repo": "andreyorst/fzf.kak",
    "branch": "master",
    "rev": "b2a8841716121f187b142585491658d554c1112e",
    "sha256": "03n74s9mfrl17cdy5h131bxa3n29n9dfrg6qwp2d17qc3b7ixv82",
    "version": "2026-05-06",
    "description": "FZF for Kakoune",
    "license": "MIT"
  }
}
```

For `sourcehut` or `git` fetchers where `leaveDotGit` is needed, add:

```json
"leaveDotGit": true
```

**Present the entry to the user for review before writing.**

## Step 6: Audit for runtime deps

Fetch the plugin source (at the resolved `rev`) and scan its `.kak` files.

### Tool deps

Binaries invoked in `%sh{}` blocks:

```bash
grep -rhoP '%sh\{[^}]*\b(curl|wget|fzf|git|perl|python3?|lua|ruby|node|pandoc|socat|guile|clang-format|rustfmt|gopls|clangd|rust-analyzer|fd|rg|bat|delta|jq|yq|tmux|kitty|alacritty|wezterm|foot|xdotool|xclip|xsel|wl-copy|wl-paste|pbcopy|pbpaste)\b' *.kak
```

Cross-reference detected binaries against nixpkgs package names.
Common mappings:

- `rg` → `ripgrep`
- `fd` → `fd`
- `fzf` → `fzf`
- `bat` → `bat`
- `git` → skip (too universal)
- `python3` → skip (too universal)

**Present detected tool deps to the user.** Not all detected binaries should
become deps — some are optional, some are too universal. Let the user decide.

### Plugin deps

Other kakoune plugins required:

```bash
grep -rhoP 'require-module\s+\K\S+' *.kak
grep -rhoP 'source\s+.*?/plugins/\K[^/]+' *.kak
```

Cross-reference against `repos/plugins/manifest.json` keys. Present matches
to the user.

### Path rewrites

Hardcoded paths that may need `postInstall` fixups:

```bash
grep -rE '\$kak_config|~/\.' *.kak
```

If found, note that a `postInstall` entry in `meta.nix` may be needed.

## Step 7: Check if the plugin is delegated

If `super.kakounePlugins.<pname>` exists in nixpkgs:

- Set `delegated = true;` in the `meta.nix` entry.
- Check if the repository root contains `Cargo.toml`. If so, add `isRust = true;`.
- Note that the plugin's existing nixpkgs build logic will be preserved via
  `overrideAttrs`.

## Step 8: Security review (mandatory)

Run the `.pi/skills/kakoune-overlay-security/SKILL.md` skill against the
plugin source. **This is not optional — every new plugin must be vetted.**

A `FAIL` verdict **blocks addition**. Do not proceed to write files if the
security review fails. Report the findings to the user and stop.

A `WARN` verdict should be noted in the PR description but does not block
addition.

## Step 9: Generate meta.nix entry (if needed)

If the plugin has any of the following, generate a `meta.nix` entry:

- `toolDeps`
- `pluginDeps`
- `delegated = true`
- `isRust = true`
- `postInstall` or other fixup needed

Example entries:

```nix
# Delegated plugin with tool deps
fzf-kak = {
  delegated = true;
  toolDeps = [ "fzf" ];
};

# Non-delegated plugin with deps
connect-kak = {
  toolDeps = [ "socat" ];
  pluginDeps = [ "prelude-kak" ];
};

# Non-delegated plugin with path rewrite
lean4-kak = {
  postInstall = ''
    substituteInPlace $out/share/kak/autoload/plugins/lean4-kak/lean4.kak \
      --replace '$kak_config/lean4-replace-abbreviations.py' \
        "$out/share/kak/autoload/plugins/lean4-kak/lean4-replace-abbreviations.py"
  '';
};
```

**Present the entry to the user for review before writing.**

If the plugin needs nothing extra, explicitly state: **No `meta.nix` entry needed.**

## Step 10: Write the files

After user confirmation:

1. Add the entry to `repos/plugins/manifest.json`. Maintain **sorted key order**.
   Use `jq -S` to ensure sorting:

   ```bash
   jq -S '. + {"<pname>": <entry>}' repos/plugins/manifest.json > /tmp/manifest.json.new
   mv /tmp/manifest.json.new repos/plugins/manifest.json
   ```

2. If needed, add the entry to `repos/plugins/meta.nix`. Insert it in
   alphabetical order within the appropriate section or near related plugins.

3. Run verification:
   ```bash
   nix flake check --all-systems
   ```

## Step 11: Commit

Follow the Conventional Commits format with a mandatory `Generated-with:` footer.

### Subject line

```
feat(plugins): add <pname>
```

- `type`: `feat` for new plugins
- `scope`: `plugins`
- `summary`: imperative mood, `<= 72` characters, no trailing period

### Body (two-paragraph style)

For substantial additions, use two paragraphs separated by a blank line.
Omit the body entirely for trivial or self-evident changes.

- **First paragraph:** Name the user and describe the design direction they
  provided. Attribute the intellectual direction to the user personally, not
  as an impersonal requirements specification.
  Example: `The user requested adding the fzf-kak plugin to the overlay to
provide fuzzy file finding integration.`

- **Second paragraph:** Describe the implementation — files modified or created,
  metadata fetched, deps audited, security review performed, and any trade-offs
  or decisions made along the way.

### Footer (mandatory)

Always include the signed footer. Call `get_current_model` to discover the
active model identifier:

```
Generated-with: <agent-name> (<provider>/<model-id>) via pi
```

### Full example

```
feat(plugins): add fzf-kak

The user requested adding the fzf-kak plugin to the overlay to provide fuzzy
file finding integration inside Kakoune.

Fetched source metadata via nix-prefetch-git, audited %sh{} blocks for
tool deps (fzf), ran the security vetting skill (PASS), and added the
manifest entry with no meta.nix changes required.

Generated-with: Nina (anthropic/claude-sonnet-4) via pi
```

Draft multi-line messages with the `write` tool to a temp file, then stage and commit:

```bash
git add .
git commit -F /tmp/msg.txt
```

Do not push. Only commit.

## Important rules

- **Always present the manifest entry and meta.nix entry for review before writing.**
  Never auto-commit.
- **The sha256 must be base32**, not SRI. Using SRI will cause build failures.
- **The pname must match the nixpkgs attribute name** if the plugin exists in nixpkgs.
- **Run the security skill on every new plugin.** A `FAIL` verdict blocks the addition.
- **Manifest keys must be sorted.** Use `jq -S` or equivalent when writing.
- **Do not add plugins to `meta.nix` unless they need non-default behavior.**
  Most pure `.kak` plugins don't need an entry.
