# Agent guidance for kakoune-overlay

## Commit format

Use Conventional Commits with a structured body and mandatory agent attribution footer.

### Subject line

- **type** REQUIRED — `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `perf`
- **scope** OPTIONAL — short noun for the affected area (e.g. `plugins`, `deps`)
- **summary** REQUIRED — imperative mood, `<= 72` characters, no trailing period

### Body

- **Optional** for trivial or self-evident changes
- **Use the two-paragraph style** when the work is substantial enough to warrant further breakdown
- When present, write **two paragraphs** separated by a blank line:
  - **First paragraph:** Name the user and describe the design direction they provided. Attribute the intellectual direction to the user personally, not as an impersonal requirements specification.
  - **Second paragraph:** The implementation — concrete steps taken, files modified or created, tools used, key code changes, and any trade-offs or decisions made along the way.

### Footer

- **Mandatory** — always include the signed footer
- Format: `Generated-with: <agent-name> (<provider>/<model-id>) via pi`
- Call `get_current_model` to discover the active model for the footer

### Example

```
feat(plugins): add fzf-kak

The user requested adding the fzf-kak plugin to the overlay to provide fuzzy
file finding integration inside Kakoune.

Fetched source metadata via nix-prefetch-git, audited %sh{} blocks for
tool deps (fzf), ran the security vetting skill (PASS), and added the
manifest entry with no meta.nix changes required.

Generated-with: Nina (anthropic/claude-sonnet-4) via pi
```

Draft multi-line messages with the `write` tool to a temp file, then `git commit -F /tmp/msg.txt`. Never use `echo` or heredocs.

## JSON manifest hash format

All `repos/**/*.json` files use **base32 `sha256`** (the default output of `nix-prefetch-url` and `nix-prefetch-git`). Do **not** convert to SRI `hash` format — `fetchFromGitHub`/`fetchgit` in this repo are invoked with `sha256 = meta.sha256`, and SRI hashes will cause "invalid SRI hash" build failures.

## Update scripts

The `./update` script is the canonical entry point for refreshing
**existing** plugins. It delegates to `repos/<repo>/update` and
auto-commits if changes are detected.

**New plugin discovery is separate.** Use `repos/plugins/discover` to find
repos newly tagged with `topic:kakoune+topic:plugin`. It writes candidates
to `/tmp/new-plugins.json` and prints normalized names to stdout. Never
commit discovered plugins directly — they must go through the PR review
workflow (`new-plugin-pr.yml`).

Per-repo updaters fetch latest commits via **GitHub Atom feeds**
(`.../commits/<branch>.atom`) instead of the REST API. This avoids rate
limits entirely and does not require `GITHUB_TOKEN`.

## Plugin name normalization

Plugin names in `repos/plugins/manifest.json` are derived directly from
the upstream repository name with one transformation: replace `.` with `-`.
No suffixes are stripped.

Example: `auto-pairs.kak` → `auto-pairs-kak`; `powerline.kak` → `powerline-kak`.

**Nixpkgs carve-out:** For plugins that already exist in nixpkgs, the
manifest key must match the nixpkgs attribute name (`kakounePlugins.<name>`),
even when that differs from the normalized repository name.

Example: the repo `Delapouite/kakoune-buffers` normalizes to `kakoune-buffers`,
but nixpkgs exposes it as `kakounePlugins.kak-buffers`, so the manifest key
must be `kak-buffers`.

## Manifest schema (`manifest.json`)

The manifest contains one entry per plugin. All fields are required unless
marked optional.

| Field         | Required | Description                                                                                                                                                                    |
| ------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fetcher`     | yes      | One of `github`, `gitlab`, `codeberg`, `sourcehut`, `git`                                                                                                                      |
| `repo`        | yes      | Repository path in fetcher-native format (e.g. `owner/repo`)                                                                                                                   |
| `branch`      | yes      | Default branch name                                                                                                                                                            |
| `rev`         | yes      | Full git revision to fetch                                                                                                                                                     |
| `sha256`      | yes      | base32 hash of the fetched archive                                                                                                                                             |
| `version`     | yes      | ISO date of the revision (`YYYY-MM-DD`)                                                                                                                                        |
| `description` | no       | Short description (used for `meta.description`)                                                                                                                                |
| `license`     | no       | SPDX identifier (used for `meta.license`)                                                                                                                                      |
| `leaveDotGit` | no       | For `sourcehut` and `git` fetchers only. Retains `.git` directory in the fetched source. Required by some build systems that read git metadata at build time. Default `false`. |

Update and discovery scripts must preserve `leaveDotGit` when refreshing an
existing entry.

## Build metadata (`meta.nix`)

Plugin build metadata lives in `repos/plugins/meta.nix`. The manifest
(`manifest.json`) is purely source metadata (what to fetch); `meta.nix` is
purely build metadata (what to do with it).

Entries are only needed when a plugin requires non-default behavior:

- **`delegated = true;`** — the plugin exists in nixpkgs with a custom
  derivation. The overlay uses `overrideAttrs` to update src/version and
  inject deps, preserving nixpkgs' build logic.
- **`isRust = true;`** — for delegated Rust plugins: injects `cargoDeps`
  handling.
- **`toolDeps = [ "fzf" ];`** — runtime tool dependencies added to
  `propagatedBuildInputs`.
- **`pluginDeps = [ "prelude-kak" ];`** — other kakoune plugin dependencies
  (by manifest key), resolved at wrap time.
- Any other attributes are passed through to `overrideAttrs` (delegated) or
  `buildKakounePlugin` / `mkDerivation` (non-delegated).

Plugins that need nothing extra are not listed in `meta.nix`.

## Formatting

Run `nix fmt` **before** `nix flake check`. The formatter (`nixfmt-rfc-style`)
is declared in `flake.nix` and applies to all `.nix` files. Do not stage
files for commit until formatting is clean and `nix flake check --all-systems`
passes.

## Verification

Before declaring local changes complete, run `nix fmt` then
`nix flake check --all-systems`.

For PRs opened by the new-plugin workflow, CI runs `nix flake check`
automatically — do not run it manually in the workflow.

## Nix file editing

Use `edit` for any change to an existing file. Use `write` only for new files. Never use `cat`, `echo`, heredocs, or `sed -i` to modify files.
