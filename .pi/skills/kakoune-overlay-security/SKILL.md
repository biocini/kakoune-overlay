---
name: kakoune-overlay-security
description: Perform security review of kakoune plugin source code before merging into the overlay. Scan .kak files for outbound network calls, sensitive data exfiltration, obfuscated shell, writes to sensitive paths, and suspicious repo metadata. Use when vetting newly discovered plugins or reviewing plugin updates for malicious patterns.
---

# Security Vetting for Kakoune Plugins

This skill documents how to perform a security review of kakoune plugin
source code before it is merged into the overlay.

## Threat model

Kakoune plugins execute shell code inside `%sh{}` blocks with the full
privileges of the user's editor session. A malicious plugin can exfiltrate
files, install persistence mechanisms, or callback to remote hosts. The
overlay acts as a distribution channel; we vet plugins at intake to catch
obvious malicious patterns before they reach users.

This is **not** a guarantee of safety. End users are responsible for their
own vetting. This skill is a tool to assist maintainer review.

## What to look for in `.kak` source files

### Outbound network requests to hardcoded destinations

`%sh{}` blocks that invoke `curl`, `wget`, `nc`, `ncat`, or `socat` with a
hardcoded URL or IP address are a red flag for callback/exfiltration.

Legitimate plugins that need network access call **local binaries** (e.g.
`fzf`) and let the user configure endpoints. A bare `curl https://...`
inside a `%sh{}` block is almost never legitimate.

**Grep patterns:**

```bash
# Outbound curl/wget to hardcoded host
grep -E 'curl\s+.*https?://' *.kak
grep -E 'wget\s+.*https?://' *.kak

# Netcat/socat to hardcoded IP or domain
grep -E '(nc|ncat|socat)\s+.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' *.kak
grep -E '(nc|ncat|socat)\s+.*[a-zA-Z0-9-]+\.[a-zA-Z]+' *.kak
```

Ignore matches where the URL is constructed from a kakoune variable (e.g.
`$kak_opt_foo_url`) — those are user-configurable and not hardcoded.

### Sensitive data access forwarded outbound

`%sh{}` blocks that read secrets or sensitive files and pipe them to a
network utility or external process.

**Grep patterns:**

```bash
# Sensitive env vars referenced near a pipe or network tool
grep -E '\$(GITHUB_TOKEN|GH_TOKEN|HOME|USER|SSH_AUTH_SOCK|AWS_|VAULT_).*\|' *.kak
grep -E '\$(GITHUB_TOKEN|GH_TOKEN|HOME|USER|SSH_AUTH_SOCK|AWS_|VAULT_).*(curl|wget|nc|socat)' *.kak

# Reading sensitive files and forwarding
grep -E 'cat\s+.*(\.ssh|\.config|\.gnupg|\.aws|\.vault|id_rsa|id_ed25519)' *.kak
grep -E 'cat\s+.*(\.ssh|\.config|\.gnupg|\.aws|\.vault|id_rsa|id_ed25519).*\|' *.kak
```

### Writes to sensitive locations

`%sh{}` blocks that write to paths outside the plugin's own buffer/session
context — e.g. arbitrary `$HOME` paths, `crontab`, shell rc files, or
systemd units.

**Grep patterns:**

```bash
# Writing to shell rc files or cron
grep -E '(>>|>)\s*~/.(bashrc|zshrc|bash_profile|profile)' *.kak
grep -E 'crontab\s+-l?\s*>' *.kak

# Writing to systemd
grep -E '(systemctl|service)\s+--user' *.kak
grep -E 'mkdir\s+-p\s+.*\.config/systemd' *.kak

# Appending to arbitrary files in $HOME
grep -E '(>>|>)\s*\$HOME/' *.kak
grep -E '(>>|>)\s*~/' *.kak
```

Note: writing to temporary files (`mktemp`) or the plugin's own state
directory is expected and benign.

### Obfuscated shell

Base64-encoded strings passed to `eval` or `sh -c`, hex-escaped commands,
or unusually encoded strings inside `%sh{}`.

**Grep patterns:**

```bash
# Base64 decode piped to shell
grep -E 'echo\s+[A-Za-z0-9+/=]{20,}\s*\|\s*(base64\s+-d|openssl\s+base64)\s*\|\s*(sh|bash|eval)' *.kak

# Hex decode or xxd piped to shell
grep -E '(xxd\s+-r|printf\s+\\x[0-9a-f])' *.kak

# eval with suspiciously long or encoded argument
grep -E 'eval\s+["'"'"']?[A-Za-z0-9+/=]{30,}' *.kak
grep -E 'sh\s+-c\s+["'"'"']?[A-Za-z0-9+/=]{30,}' *.kak
```

### postInstall and fixup scripts in meta.nix

If the plugin requires a `postInstall`, `preFixup`, or other build-time
rewrite in `meta.nix`, check that the block:

- Does NOT download or execute remote content (`curl`, `wget`, `fetchurl`)
- Does NOT write to locations outside `$out`
- Performs ONLY path substitution necessary for Nix store correctness

## What is NOT a concern

The following patterns are expected and benign. Do not flag them.

- `%sh{}` blocks calling common Unix utilities: `echo`, `printf`, `sed`,
  `awk`, `grep`, `sort`, `mktemp`, `mkdir`, `rm`, `cat`, `kill`, `sleep`,
  `date`, `bc`, `seq`, `tr`, `cut`, `head`, `tail`, `tee`, `wc`, `test`,
  `find`, `dirname`, `basename`, `pwd`, `cd`

- `%sh{}` blocks calling local tools by bare name without hardcoded remote
  destinations: `git`, `perl`, `python3`, `lua`, `ruby`, `node`, `ctags`,
  `fzf`, `ripgrep`, `fd`, `clangd`, `rust-analyzer`, etc. These are not
  a security concern, but they are tracked as build metadata (`toolDeps`)
  in `meta.nix` by the add-plugin skill so the wrapper can bake them into
  `PATH`.

- The plugin calling `kak -p $kak_session` to send commands back to
  kakoune. This is the standard IPC pattern.

- Reading from the plugin's own source tree or from `$kak_config` for
  configuration files. These are normal plugin behaviors.

## What to look for in repo metadata

These signals are secondary — they warrant extra scrutiny when combined
with primary source findings, but do not alone justify a FAIL.

### Repository age and activity

- Created within 30 days of the manifest version date
- Very few commits (< 5) with no meaningful issue or PR history

### Typosquatting

- Repository name that is a close variant of a well-known plugin:
  `kakoune-lsp2`, `fzf-kak-fork`, `powerline-kak-alt`
- Near-identical source to an existing plugin with a different owner

### Anonymous author

- Account created the same week as the plugin
- No other public repositories
- No identifiable author presence (no profile info, no linked website)

## Verdicts

For each plugin, produce exactly one of:

- **`PASS`** — no concerns found. The PR checklist security item is
  ticked with no additional comment.

- **`WARN`** — something unusual but not definitively malicious. Examples:
  - Very new repo with outbound `curl` to a URL that appears legitimate
    (e.g. a language server download)
  - Unusual but transparent script that writes to `$HOME/.cache`

  Describe what was found and why it warrants human attention. Do not
  block the PR. Annotate the checklist item clearly.

- **`FAIL`** — a pattern consistent with malicious intent. Examples:
  - Exfiltration of `~/.ssh/id_rsa` via `curl`
  - Base64-encoded `eval` payload
  - Writing to `~/.bashrc` or crontab

  Describe the exact file, line, and pattern. The PR title should be
  prefixed with `[SECURITY FAIL]` and the checklist item marked with a
  clear block note.

## Output format

Write findings as a JSON object keyed by plugin normalized name:

```json
{
  "plugin-name": {
    "verdict": "PASS|WARN|FAIL",
    "findings": "Human-readable description of what was found, or empty string if PASS",
    "flagged_lines": [
      {
        "file": "rc.kak",
        "line": 42,
        "pattern": "curl https://evil.example.com"
      }
    ]
  }
}
```

`flagged_lines` is empty for `PASS`. It must contain at least one entry
for `FAIL`.

## Audit database

A committed security audit database lives at `docs/security-audit.json`.
Before reviewing a plugin, check whether it already has an entry. If the
entry is a `PASS` and the upstream source has not changed since
`last_audited`, you may reuse the existing verdict. If the source has
changed, or if there is no entry, perform a fresh review and append the
result to the database.

The database follows the same schema as the output format above, with an
additional `last_audited` field:

```json
{
  "plugin-name": {
    "last_audited": "2026-05-14",
    "verdict": "PASS|WARN|FAIL",
    "findings": "...",
    "flagged_lines": [...]
  }
}
```

Update the database after every review so findings are persistent across
PRs and sessions.

## Tooling constraints

This skill is designed to be used in an environment with only `curl` and
`grep` available. All patterns above are expressed as `grep -E` compatible
regular expressions. No external security scanning tools are required.
