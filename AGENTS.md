# Agent guidance for kakoune-overlay

## Commit format

Use Conventional Commits with a two-paragraph body:

```
type(scope): summary

First paragraph: what changed and why — the user's direction.
Second paragraph: how it was realized — implementation choices.

Generated-with: <agent name> (<provider>/<model-id>) via pi
```

Draft multi-line messages with the `write` tool to a temp file, then `git commit -F /tmp/msg.txt`. Never use `echo` or heredocs.

## JSON manifest hash format

All `repos/**/*.json` files use **base32 `sha256`** (the default output of `nix-prefetch-url` and `nix-prefetch-git`). Do **not** convert to SRI `hash` format — `fetchFromGitHub`/`fetchgit` in this repo are invoked with `sha256 = meta.sha256`, and SRI hashes will cause "invalid SRI hash" build failures.

## Update scripts

The `./update` script is the canonical entry point. It delegates to `repos/<repo>/update` and auto-commits if changes are detected. Always use it rather than running per-repo scripts directly.

Per-repo updaters fetch latest commits via **GitHub Atom feeds** (`.../commits/<branch>.atom`) instead of the REST API. This avoids rate limits entirely and does not require `GITHUB_TOKEN`.

## Plugin name normalization

When adding plugins to `repos/plugins/manifest.json`, normalize the key as:

1. Strip `.kak` suffix from repo name
2. Replace `.` with `-`

Example: `auto-pairs.kak` → `auto-pairs`; `powerline.kak` → `powerline`.

This convention must be consistent between the manifest and any bootstrap scripts.

## Verification

Before declaring changes complete, run `nix flake check --all-systems`.

## Nix file editing

Use `edit` for any change to an existing file. Use `write` only for new files. Never use `cat`, `echo`, heredocs, or `sed -i` to modify files.
