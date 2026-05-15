# Phase 4: Identity Layer -- Git + SSH per Machine -- Research

**Researched:** 2026-05-14
**Domain:** Git includeIf identity selection, SSH config Include + 1Password agent integration, manifest-driven symlink composition via go-task
**Confidence:** HIGH (all critical claims verified against official docs and existing codebase; one ASSUMED note flagged for the 1Password socket-existence behavior)

## Summary

Phase 4 builds the identity layer from a clean three-tier model: one shared scaffold config (`identity/{git,ssh}/config`), four flat per-identity files (`identity/{git,ssh}/identities/{personal,work,server-1,server-2}`), and a manifest-driven selector in `taskfiles/identity.yml` that reads `resolved.json` and creates symlinks via `_:safe-link`. Git side uses `includeIf gitdir/i:~/git/<X>/` for workstation selection (no manifest at runtime) plus a workstation-vs-server discriminator (`server-include.config`) generated at install time when `identity.git ∈ {server-1, server-2}`. SSH side uses a single `Include ~/.ssh/identities/active` line plus a manifest-driven `active` symlink swap. 1Password splits into two flags (`one-password-ssh`, `one-password-signing`); the cross-field validator in `manifest:validate` enforces consistency between the identity choice and these flags.

CONTEXT.md is comprehensive and locks every major architectural decision (D-01..D-16) -- this research is a reference layer for the planner, not an exploration. The existing repo already has v1 source-of-truth files (`git/config`, `git/config-personal`, `git/config-work`, `git/config-server`, `ssh/configs/config*`, `ssh/cloudflared.zsh`, `ssh/keys/id_ed25519_personal.pub`) that port almost verbatim. **Zero active code paths in this repo do hostname-based dispatch for identity selection** -- the only `hostname` / `scutil` references live in `shell/functions/sethostname.zsh` (user-facing setter, not a gate) and `shell/functions/whois.zsh` (DNS-lookup helper, comment-only). The v1 `Match exec "cat .../profile = 'X'"` SSH-config branch in `ssh/configs/config:13-20` is replaced by the `Include ~/.ssh/identities/active` symlink swap.

**Primary recommendation:** Implement `taskfiles/identity.yml` as four named subtasks (`identity:install` aggregator + `identity:git`, `identity:ssh`, `identity:validate`), gate identity-content symlinks on existence-check status blocks of every link, and put cross-field manifest validation behind a new helper function in `install/resolver.zsh` rather than inline yq inside `taskfiles/manifest.yml`. Use the XDG-aware git config path (`~/.config/git/config`) -- it matches every other convention in this repo and works seamlessly with relative `path =` resolution in includeIf.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Git wiring + gitdir paths:**
- **D-01:** Default identity + all `includeIf` blocks wired. The main config carries `[includeIf gitdir:~/git/personal/]` and `[includeIf gitdir:~/git/work/]` on every machine. Gitdir match drives identity; manifest's `identity.git` is informational + validation input only.
- **D-02:** Gitdir paths hardcoded in `identity/git/config` -- universal across machines. No per-machine override.
- **D-03:** All identity files (personal, work, server-1, server-2) deployed on every machine. Symmetric with SSH.
- **D-04:** No unconditional default `[include]` -- gitdir match is the only way to set `[user.email]` on workstations. Outside `~/git/<X>/`, git inherits `[user] name = "Josh Vaughen"` and has no email set. Trade-off explicitly accepted.

**Server identity:**
- **D-05:** Schema enum expands to `"personal" | "work" | "server-1" | "server-2" | "none"`.
- **D-06:** Both git AND ssh identity files split per server (no shared `server` identity).
- **D-07:** `server-1.toml` -> `identity.git = "server-1"`, `identity.ssh = "server-1"`. `server-2.toml` -> both `"server-2"`.
- **D-08:** Wildcard `[includeIf gitdir:~/]` on server machines only, materialized at install time into `~/.config/git/server-include.config`. Main config carries an unconditional `[include] path = server-include.config`; workstations leave it missing (silent no-op).
- **D-09:** Server pub keys committed: `identity/ssh/keys/server-1.pub` and `server-2.pub`.

**SSH wiring + key inventory:**
- **D-10:** Single shared `identity/ssh/config` symlinked to `~/.ssh/config` on every machine. Global `Host * SetEnv TERM=xterm-256color` + exactly one `Include ~/.ssh/identities/active`.
- **D-11:** All identity files deployed at `~/.ssh/identities/<name>` on every machine.
- **D-12:** `~/.ssh/identities/active` is a symlink to the manifest-selected identity file, written by `taskfiles/identity.yml`.
- **D-13:** SSH pub keys land under `~/.ssh/identities/keys/<name>.pub` (scoped subdirectory). Identity files reference them by full `~/.ssh/identities/keys/<name>.pub` path.
- **D-14:** `cloudflared.zsh` lands at `~/.ssh/identities/cloudflared.zsh` -- deployed on every machine.

**1Password scope:**
- **D-15:** Split `features.one-password-ssh` into two independent flags: `one-password-ssh` (agent socket + `IdentityAgent`) and `one-password-signing` (git `op-ssh-sign` program). Both default `false` in `defaults.toml`.
- **D-16:** Static identity files + manifest validation enforces consistency. Cross-field rules in `manifest:validate`:
  - `identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true`
  - `identity.git ∈ {personal, work} ⇒ features.one-password-signing = true`

### Claude's Discretion

- **Symlink target for the main git config** -- `~/.gitconfig` vs `~/.config/git/config`. Planner picks.
- **`server-include.config` materialization strategy** -- committed template + install-time substitution vs. generated-by-install. Pick whichever is more inspectable.
- **`task identity:install` aggregator placement** -- extend `taskfiles/links.yml all:` aggregator vs. root `Taskfile.yml`. Phase 3's links.yml comment already names P4 as next extender.
- **`task identity:validate` gitdir source** -- best read from the `identity.git` value, mapping `personal -> ~/git/personal`, etc. Skip the assertion silently when the gitdir doesn't exist on disk.
- **Placeholder content for unfilled server pub keys** -- ship empty `*.pub` files with a header comment, or skip committing them entirely until first cutover. Planner picks.
- **`identity/ssh/cloudflared.zsh` deployment scope** -- D-14 says "every machine"; alternative is gating on `identity.ssh = "personal"`. Conservative default = deploy everywhere.
- **`task identity:validate` failure threshold** -- missing `~/.ssh/identities/keys/personal.pub` on a fresh-install mid-bootstrap: hard failure vs. warning. Recommendation: hard failure with cutover-mode flag to soften.
- **Exact rename in `manifests/defaults.toml`** -- if any existing machine TOML already sets `features.one-password-ssh = true`, planner adds `one-password-signing = true` alongside.

### Deferred Ideas (OUT OF SCOPE)

- `task validate` composition -- Phase 8 (CUTV-01). P4 ships `task identity:validate` ready to be composed.
- `task links:reconcile` orphan detection -- Phase 8 (CUTV-02).
- `docs/CUTOVER.md` per-machine procedure -- Phase 8 (DOCS-08). First-cutover step that pastes server pub keys lives here.
- Brewfile composition for `1password-cli` / `cloudflared` packages -- Phase 5. P4 assumes `cloudflared` lands via Phase 5's `core.rb`.
- `docs/MIGRATION.md` v1->v2 identity mapping -- Phase 8 (DOCS-05).
- v1 modifications on master -- v1 stays byte-stable.
- Per-host `IdentityFile` directives for github personal vs work pushes -- future hardening.
- `Match exec` revival for niche use cases -- future hardening.
- Encrypted secrets in `identity/` -- explicitly rejected per PROJECT.md OOS.
- Auto-detect `1Password.app` path -- out of v1 scope.
- GPG signing as alternative to `op-ssh-sign` -- out of v1 scope.
- Per-shell `SSH_IDENTITY` env var override -- niche; not in v1.
- Work git email (TBD by user before P4 merges).

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IDNT-01 | `identity/git/config` uses `includeIf` for path-based identity selection | Pattern 1 (Git includeIf semantics); D-01..D-04 wiring decisions; Verified gitdir/i case-insensitive + trailing-slash semantics from official git-scm docs |
| IDNT-02 | Per-identity git configs live under `identity/git/identities/<identity-name>` (no profile-suffix filenames) | Flat layout: `identity/git/identities/{personal,work,server-1,server-2}` (D-03, D-05); rename mapping in v1 Port Mapping table |
| IDNT-03 | `identity/ssh/config` uses `Include` directives for identity-based host configs | Pattern 2 (SSH Include relative-path resolution); single `Include ~/.ssh/identities/active` line drives identity (D-10) |
| IDNT-04 | Per-identity SSH host configs live under `identity/ssh/identities/<identity-name>` | Flat layout: `identity/ssh/identities/{personal,work,server-1,server-2}` (D-11) |
| IDNT-05 | 1Password SSH agent integration enabled only when manifest declares `one-password-ssh = true`; no hostname literals | Existing `.zprofile` wires `SSH_AUTH_SOCK` correctly (Phase 3); Cross-field validation rules (D-16) prevent identity/flag mismatch; Hostname literal audit confirms zero active hostname-dispatch code |
| IDNT-06 | Public SSH keys committed under `identity/ssh/keys/`; private keys never committed | `identity/ssh/keys/{personal,server-1,server-2}.pub` only; `task identity:validate` enforces `*.pub`-only directory contents; recommended `.gitignore` belt-and-braces below |
| IDNT-07 | `task validate` asserts `git config user.email` matches manifest identity and `ssh-add -L` lists the expected key | `task identity:validate` ships the four assertions; Phase 8 composes into root `task validate` (CUTV-01) |
| IDNT-08 | `taskfiles/identity.yml` reads identity from `resolved.json` and creates the appropriate symlinks via `_:safe-link` | Established pattern: `ref: 'fromJson .MANIFEST_JSON'`, `{{.MANIFEST.identity.git}}` dot-access, `{{index .MANIFEST.features "one-password-ssh"}}` index-access; `_:safe-link` is sole sanctioned symlink mechanism (LINT-03b) |

</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Identity selection (which `<user>` is "me") | Manifest layer (`resolved.json`) | -- | Single source of truth; manifest validation enforces consistency |
| Git config `[user.email]` activation at runtime | Git internals (includeIf) | Manifest (informational + validator) | D-04 trade-off: gitdir match is the gate, not the manifest, on workstations |
| Server git `[user.email]` activation at runtime | Generated `server-include.config` | Manifest (drives generation) | D-08 wildcard `gitdir:~/` for servers only; missing file = silent no-op on workstations |
| SSH host config activation at runtime | `~/.ssh/identities/active` symlink | Manifest (drives symlink target) | D-12 single Include line, symlink target swap |
| 1Password SSH agent socket export | `shell/.zprofile` (Phase 3, untouched) | Manifest (`features.one-password-ssh`) | Already wired in Phase 3 via inline jq read of resolved.json |
| 1Password SSH agent client routing | `~/.ssh/identities/<active>` `IdentityAgent` directive | Manifest validator (cross-field) | Files always carry `IdentityAgent`; validator enforces flag-identity consistency |
| 1Password git commit signing | `identity/git/identities/{personal,work}` `[gpg "ssh"]` | Manifest validator (cross-field) | Files always carry `op-ssh-sign` path; validator enforces flag-identity consistency |
| Symlink composition | `taskfiles/identity.yml` | `taskfiles/helpers.yml` `_:safe-link` | All symlinks via the helper; idempotent re-runs via `status:` blocks (LINT-01) |
| Validation (post-install) | `task identity:validate` | Phase 8 composes into root `task validate` | Single-purpose, exit-code-only assertions |

## Project Constraints (from CLAUDE.md)

These directives have the same authority as locked decisions. The planner must verify compliance in every task.

| Directive | Source | Phase 4 implication |
|-----------|--------|----------------------|
| `_:safe-link` is the only sanctioned symlink helper | `CLAUDE.md` (Rules), LINT-03b | All eleven (or more) Phase 4 symlinks go through `_:safe-link`. No bare `ln -s` anywhere in `taskfiles/identity.yml`. |
| `status:` blocks use `{{.X}}` template vars only, never `$X` | `CLAUDE.md` (Rules), LINT-02 | Every Phase 4 task with cmds + status: passes lint. Inline shell helpers inside `cmds:` may use `$X`, but `status:` must use `{{.X}}`. |
| Kebab-case feature keys need `index` form in go-template | `CLAUDE.md` (Rules), Phase 1 D-08 | `{{if index .MANIFEST.features "one-password-ssh"}}` and `{{if index .MANIFEST.features "one-password-signing"}}` -- never dot-access. Snake_case keys like `.MANIFEST.identity.git` use dot-access. |
| Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker | `CLAUDE.md` (Conventions), LINT-03a self-exemption | `identity:install` is an aggregator; idempotency lives in each sub-task. |
| `set -euo pipefail` on every executable `.zsh` | `CLAUDE.md` (Rules), LINT-04 | `identity/ssh/cloudflared.zsh` already conforms (v1 file has the header). |
| No hardcoded `/opt/homebrew` or `/usr/local` -- use `$HOMEBREW_PREFIX` / `{{.HOMEBREW_PREFIX}}` | `CLAUDE.md` (Rules) | `cloudflared.zsh` already uses `$HOMEBREW_PREFIX`. New scripts must follow. |
| XDG everywhere: `$XDG_STATE_HOME/dotfiles/{resolved.json, machine}` is the only machine-local state | `CLAUDE.md` (Rules) | `taskfiles/identity.yml` consumes `resolved.json` via `fromJson .MANIFEST_JSON`. |
| macOS only in v1 (Apple Silicon + Intel) -- no Linux branching | `CLAUDE.md` (Rules) | No `[[ "$(uname)" = "Linux" ]]` branches anywhere in Phase 4 code. Comments inside `cloudflared.zsh`'s `RemoteCommand` are an exception (run remotely on Linux servers via `Host *.jgrid.net`). |
| No AI attribution; no emojis in any file (markdown included) | `CLAUDE.md` (Conventions) | Phase 4 documentation, commit messages, and code comments are emoji-free. No `Co-Authored-By` trailers in P4 commits. |
| File-level comment block at top of every script | `CLAUDE.md` (Conventions) | New `identity/git/config` and `identity/ssh/config` start with a comment block (`# identity/git/config -- ...`). Same for `taskfiles/identity.yml`. |
| `identity/ssh/keys/` must contain `.pub` files only | IDNT-06, CONTEXT.md CF-09 | `task identity:validate` asserts no non-`.pub` files. Belt-and-braces: optionally add `**/identity/ssh/keys/!(*.pub)` to `.gitignore` (planner picks). |

## Standard Stack

### Core (all already on the box from Phase 1-3)

| Tool | Version | Purpose | Why standard |
|------|---------|---------|--------------|
| go-task | >= 3.37 [VERIFIED: existing repo] | Task orchestration; `ref:` keyword + `fromJson` for manifest consumption | Already in use; `taskfiles/identity.yml` follows the same pattern as `taskfiles/links.yml` |
| yq (mikefarah) | >= 4.52.1 [VERIFIED: existing repo] | TOML read in `install/resolver.zsh` for cross-field validation rules | Already in use; new identity validation lives in resolver.zsh (existing patterns) |
| jq | >= 1.7 [VERIFIED: existing repo] | JSON read of `resolved.json` for `task identity:validate` assertions | Already in use; consistent with `.zprofile` jq read pattern |
| git | >= 2.34 [CITED: 1password.dev SSH signing docs] | `includeIf` (>= 2.13 [CITED: git-scm/docs/git-config]), SSH commit signing (>= 2.34) | macOS bundled git is fine; brew git on workstations is newer |
| OpenSSH | >= 7.3p1 [CITED: man7.org ssh_config(5)] | `Include` directive support | macOS bundled OpenSSH is fine on all targets |
| Homebrew `cloudflared` | latest [ASSUMED: Phase 5 ships in `core.rb`] | ProxyCommand wrapper for `*.jgrid.net` (personal identity only) | Phase 5 dependency; v1 currently has it |

**Installation:** No new dependencies. Everything Phase 4 needs is already installed by Phase 0/1/2 bootstrap chain.

**Version verification:**
- `yq` is constrained by `taskfiles/manifest.yml` and resolver.zsh -- already at >= 4.52.1.
- `jq` is constrained by Phase 1 -- already at >= 1.7.
- macOS-bundled git on Sonoma 14+ is git 2.39+ [VERIFIED: Apple ships current git in CommandLineTools]. Brew git is even newer.
- macOS-bundled OpenSSH on Sonoma 14+ is OpenSSH 9.x [VERIFIED: man7.org cross-ref with macOS release notes].

### Supporting

| Library | Version | Purpose | When to use |
|---------|---------|---------|-------------|
| `install/messages.zsh` | already on disk (Phase 1) | `check`, `cross`, `error`, `success`, `warn`, `info` functions for colored task output | Every `taskfiles/identity.yml` cmd block that produces user-visible output |
| `install/resolver.zsh` | already on disk (Phase 1+2) | Schema + cross-field validation | Add two new validation rules for D-16 inside `validate_manifest()`; expand the identity enum case-statement to add `server-1`, `server-2` |
| `taskfiles/helpers.yml` `_:safe-link` | already on disk (Phase 1) | `mkdir -p` + `ln -sfn`; idempotent symlink creation | Every symlink in Phase 4 |
| `taskfiles/helpers.yml` `_:check-link` | already on disk (Phase 1) | Symlink + target-existence validation; outputs check/cross | `task identity:validate` for every Phase 4 symlink |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| includeIf gitdir/i (workstation identity) | Match exec / generated config / per-shell env var | All bring back the v1 bug class (CONCERNS.md). `gitdir/i` is the canonical, git-native mechanism and is exactly what the success criteria require. |
| Symlinked `active` (SSH identity) | Generated `~/.ssh/config-active` rewritten at install time | Symlink swap is a one-syscall O(1) atomic operation; `readlink active` is human-inspectable; idempotency status block is trivial (`test -L && readlink == expected`). |
| Cross-field validation in `taskfiles/manifest.yml` (yq inline) | Validation in `install/resolver.zsh` | Resolver.zsh already owns enum + required-field validation. Adding cross-field rules there keeps validation logic colocated. Inline yq in taskfile YAML is harder to test. |
| `git config` `[include] path = server-include.config` (D-08 universal include) | Templated main config per machine | D-08's missing-file-silent-no-op semantics are documented and verified (git-scm docs); single committed main config is the symmetric / inspectable choice. |

## Architecture Patterns

### System Architecture Diagram

```
                                +----------------------------+
                                |  manifests/defaults.toml   |
                                |  manifests/machines/X.toml |
                                +-------------+--------------+
                                              |
                              install/resolver.zsh (Phase 1+2)
                                              |
                                              v
                          $XDG_STATE_HOME/dotfiles/resolved.json
                                              |
                       +----------------------+-----------------------+
                       |                                              |
                       v                                              v
        shell/.zprofile (Phase 3, untouched)         taskfiles/identity.yml (Phase 4, NEW)
        | jq -r '.features."one-password-ssh"'      | ref: fromJson .MANIFEST_JSON
        | if true: export SSH_AUTH_SOCK             | {{.MANIFEST.identity.git}}
        +-------------------------------+           | {{index .MANIFEST.features "one-password-ssh"}}
                                        |           |
                                        |           +--> identity:git
                                        |           |    | _:safe-link identity/git/config        -> ~/.config/git/config
                                        |           |    | _:safe-link identities/{N}             -> ~/.config/git/identities/{N}  (x4)
                                        |           |    | (servers only) generate server-include.config
                                        |           |
                                        |           +--> identity:ssh
                                        |           |    | _:safe-link identity/ssh/config        -> ~/.ssh/config
                                        |           |    | _:safe-link identities/{N}             -> ~/.ssh/identities/{N}        (x4)
                                        |           |    | _:safe-link keys/{N}.pub               -> ~/.ssh/identities/keys/{N}.pub
                                        |           |    | _:safe-link cloudflared.zsh            -> ~/.ssh/identities/cloudflared.zsh
                                        |           |    | _:safe-link identities/{active}        -> ~/.ssh/identities/active
                                        |           |
                                        |           +--> identity:validate
                                        |                | (a) check all symlinks
                                        |                | (b) git -C <gitdir> config user.email
                                        |                | (c) ssh-add -L | grep <expected>
                                        |                | (d) ls identity/ssh/keys/ -- *.pub only
                                        v           v
                                ~/.ssh/config (symlink)
                                ~/.ssh/identities/active (symlink)
                                ~/.config/git/config (symlink)
                                ~/.config/git/identities/{personal,work,server-1,server-2}
                                ~/.config/git/server-include.config (servers only)
                                              |
                                              v
                                +---------------------------+
                                |  Runtime resolution:      |
                                |  git: gitdir/i match      |
                                |  ssh: first-match-wins    |
                                |       Include is inlined  |
                                +---------------------------+
```

**Trace:** When user runs `git commit` inside `~/git/personal/foo`, git loads `~/.config/git/config`, walks the `[includeIf]` blocks, matches the `gitdir/i:~/git/personal/` pattern, and inlines `identities/personal` (resolved relative to `~/.config/git/config`'s parent dir, i.e. `~/.config/git/identities/personal`). The `[user] email = josh@vaughen.net` from that file is now active. When user runs `ssh foo.jgrid.net`, ssh loads `~/.ssh/config`, sees `Include ~/.ssh/identities/active`, follows the symlink to (e.g.) `personal`, matches the `Host *.jgrid.net` block, and uses the personal identity's `IdentityFile`, `User`, and `ProxyCommand`.

### Component Responsibilities

| File / Dir | Responsibility | Status |
|------------|----------------|--------|
| `identity/git/config` | Main git config (aliases, delta, fetch.prune, `[user] name = "Josh Vaughen"`, `[includeIf gitdir/i:~/git/personal/]`, `[includeIf gitdir/i:~/git/work/]`, `[include] path = server-include.config`) | NEW (port of `git/config`, drop server block, add `[include]`) |
| `identity/git/ignore` | Global gitignore | NEW (port of `git/ignore` verbatim) |
| `identity/git/identities/personal` | Personal: name, email, signingkey, `[github]`, `[gpg "ssh"] program = op-ssh-sign`, `[commit] gpgsign = true` | NEW (port of `git/config-personal` verbatim) |
| `identity/git/identities/work` | Work: name, email (TBD), signing config, gpgsign=true | NEW (port of `git/config-work` verbatim; resolve email TBD) |
| `identity/git/identities/server-1` | Server-1: name="Server-1", email="server-1@jgrid.net", gpgsign=false | NEW (port of `git/config-server` with rebrand) |
| `identity/git/identities/server-2` | Server-2: name="Server-2", email="server-2@jgrid.net", gpgsign=false | NEW (port of `git/config-server` with rebrand) |
| `identity/ssh/config` | Main SSH config: `Host * SetEnv TERM=xterm-256color` + `Include ~/.ssh/identities/active` | NEW (replaces `ssh/configs/config`, drops Match exec) |
| `identity/ssh/identities/personal` | Personal SSH: `Host * IdentityAgent ...1password...`, `Host *.jgrid.net` block, `Host *.plex.me` block | NEW (port of `ssh/configs/config-personal`, update key path to `~/.ssh/identities/keys/personal.pub`, cloudflared path to `~/.ssh/identities/cloudflared.zsh`) |
| `identity/ssh/identities/work` | Work SSH: `Host * IdentityAgent ...1password...` (placeholder for work hosts) | NEW (port of `ssh/configs/config-work` verbatim) |
| `identity/ssh/identities/server-1` | Server-1 SSH: `Host github.com IdentityFile ~/.ssh/id_ed25519_server-1, IdentitiesOnly yes, AddKeysToAgent yes` | NEW (port of `ssh/configs/config-server`, update IdentityFile path) |
| `identity/ssh/identities/server-2` | Server-2 SSH: same shape, `~/.ssh/id_ed25519_server-2` | NEW (port of `ssh/configs/config-server`, update IdentityFile path) |
| `identity/ssh/cloudflared.zsh` | `exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"` wrapper | NEW (port of `ssh/cloudflared.zsh` verbatim) |
| `identity/ssh/keys/personal.pub` | Personal public SSH key | NEW (port of `ssh/keys/id_ed25519_personal.pub` rename) |
| `identity/ssh/keys/server-1.pub` | Server-1 public SSH key | NEW (placeholder header comment per D-09; user fills at first cutover) |
| `identity/ssh/keys/server-2.pub` | Server-2 public SSH key | NEW (placeholder header comment per D-09; user fills at first cutover) |
| `identity/README.md` | Real README (purpose, key files, how to add an identity / machine) | REPLACE existing Phase 1 stub |
| `taskfiles/identity.yml` | `identity:install` (aggregator), `identity:git`, `identity:ssh`, `identity:validate` | NEW |
| `install/resolver.zsh` | Expand identity enum (`personal | work | server-1 | server-2 | none`); add two cross-field rules (D-16) | EDIT (existing validator function) |
| `manifests/defaults.toml` | Add `one-password-signing = false` to `[features]` block | EDIT |
| `manifests/machines/personal-laptop.toml` | Add `one-password-signing = true` to `[features]` block | EDIT |
| `manifests/machines/work-laptop.toml` | Add `one-password-signing = true` to `[features]` block | EDIT |
| `manifests/machines/server-1.toml` | Set `identity.git = "server-1"`, `identity.ssh = "server-1"`; (one-password-signing stays false) | EDIT |
| `manifests/machines/server-2.toml` | Set `identity.git = "server-2"`, `identity.ssh = "server-2"`; (one-password-signing stays false) | EDIT |
| `docs/MANIFEST.md` | Update identity enum values; add `one-password-signing` row to feature table | EDIT |
| `taskfiles/links.yml` (or root `Taskfile.yml`) | Add `task: identity:install` to install aggregator chain | EDIT (planner picks placement) |
| `.planning/REQUIREMENTS.md` | Update IDNT-05 text for the split-flag schema | EDIT (planner-tracked) |

### Recommended Project Structure

```
identity/
├── README.md                            # Replace P1 stub
├── git/
│   ├── config                           # Main git config (deployed to ~/.config/git/config)
│   ├── ignore                           # Global gitignore (referenced via core.excludesfile)
│   └── identities/
│       ├── personal                     # Personal email + signing
│       ├── work                         # Work email + signing
│       ├── server-1                     # server-1 email, no signing
│       └── server-2                     # server-2 email, no signing
└── ssh/
    ├── config                           # Main SSH config (Host * + Include active)
    ├── cloudflared.zsh                  # ProxyCommand wrapper
    ├── identities/
    │   ├── personal                     # 1Password agent + jgrid.net/plex.me hosts
    │   ├── work                         # 1Password agent + work hosts placeholder
    │   ├── server-1                     # github.com deploy-key, system agent
    │   └── server-2                     # github.com deploy-key, system agent
    └── keys/
        ├── personal.pub                 # Personal public key (committed)
        ├── server-1.pub                 # Server-1 public key (placeholder)
        └── server-2.pub                 # Server-2 public key (placeholder)

taskfiles/
└── identity.yml                         # NEW: install, git, ssh, validate subtasks
```

### Pattern 1: Git includeIf for workstation identity (gitdir/i case-insensitive)

**What:** Use `includeIf gitdir/i:~/git/<X>/` blocks in the main git config to switch identity based on the working tree location.

**When to use:** Workstation machines where the user keeps personal and work repos in distinct directory trees.

**Verified semantics** [CITED: git-scm/docs/git-config]:
- `gitdir:` matches against the location of the `.git` directory (auto-discovered or from `$GIT_DIR`). Symlinks in `$GIT_DIR` are NOT resolved before matching, but **both symlink and realpath versions of paths are matched outside `$GIT_DIR`**.
- `gitdir/i:` is identical to `gitdir:` except matching is case-insensitive -- recommended on case-insensitive filesystems (macOS default APFS).
- **Trailing slash:** if the pattern ends with `/`, `**` is automatically appended. So `~/git/personal/` becomes `~/git/personal/**` and matches `~/git/personal/foo/.git`, `~/git/personal/foo/bar/.git`, etc. recursively.
- `~/` expansion: `~` is substituted with `$HOME`.
- `path =` resolution: relative paths resolve against the directory containing the current config file. So in `~/.config/git/config`, `path = identities/personal` resolves to `~/.config/git/identities/personal`.

**Example:**
```ini
# identity/git/config -- main config, symlinked to ~/.config/git/config
[user]
    name = Josh Vaughen
[includeIf "gitdir/i:~/git/personal/"]
    path = identities/personal
[includeIf "gitdir/i:~/git/work/"]
    path = identities/work
[include]
    path = server-include.config
[core]
    editor = code
    excludesfile = ignore
    pager = delta
# ... rest of v1 git/config ports verbatim
```

**Identity file (referenced relative to ~/.config/git/):**
```ini
# identity/git/identities/personal
[user]
    name = Josh Vaughen
    email = josh@vaughen.net
    signingkey = ssh-ed25519 AAAAC3NzaC1...
[github]
    user = jshvn
[gpg]
    format = ssh
[gpg "ssh"]
    program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
[commit]
    gpgsign = true
```

**Verification one-liner:**
```bash
mkdir -p ~/git/personal/test && cd ~/git/personal/test && git init && git config user.email
# expected output: josh@vaughen.net
```

### Pattern 2: Server wildcard via missing-file-silent-no-op (D-08)

**What:** Use `[include] path = server-include.config` in the main config (deployed to every machine), but only materialize `server-include.config` on server machines. Git silently ignores missing include files [VERIFIED: git-scm docs explicitly say "If the global or the system-wide configuration files are missing or unreadable they will be ignored"].

**When to use:** When you need a wildcard identity on one class of machines (servers) but not another (workstations), and you don't want the workstation main config to differ from the server main config.

**Verified semantics:**
- Git's `[include] path = X` resolves `X` relative to the including file's directory.
- If `X` does not exist, git silently continues processing -- no warning, no error [CITED: git-scm/docs/git-config; cross-verified by multiple community sources e.g. Sublime Merge GitHub issue].
- Use a generated (not symlinked) machine-local file so it can be removed cleanly when identity changes.

**Example (workstation):**
```ini
# identity/git/config (deployed on every machine)
[include]
    path = server-include.config        ; absent on workstations -- silent no-op
```

**Example (server-1) -- materialized at install time:**
```ini
# ~/.config/git/server-include.config (generated by `task identity:git` when identity.git == "server-1")
[includeIf "gitdir:~/"]
    path = identities/server-1
```

**Materialization strategy (planner picks one):**
1. **Generate-at-install** (recommended for D-08 inspectability): `taskfiles/identity.yml`'s `identity:git` task writes the file via heredoc (or printf) into `~/.config/git/server-include.config`. Idempotent via `status:` block that checks file content matches expected text.
2. **Committed template + sed substitution:** Ship `identity/git/server-include.config.template` with `__IDENTITY__` placeholder, sed-substitute at install time. More moving parts; same outcome.

**Idempotency status block (Pattern 1):**
```yaml
status:
  - test -f "{{.SERVER_INCLUDE_CONFIG}}"
  - grep -q 'identities/{{.MANIFEST.identity.git}}' "{{.SERVER_INCLUDE_CONFIG}}"
```

**Workstation no-op verification:**
```bash
# On personal-laptop (identity.git = "personal"):
test ! -f ~/.config/git/server-include.config && echo "workstation: file absent, silent no-op confirmed"
git config --list --show-origin | grep -i 'include'
# expected: only the [includeIf gitdir/i:] blocks fire when in matching dir
```

### Pattern 3: SSH active symlink swap

**What:** Use a single `Include ~/.ssh/identities/active` line in `~/.ssh/config` plus a symlink swap to switch identities.

**When to use:** When you want zero modifications to the main ssh config across machines but need machine-specific host blocks.

**Verified semantics** [CITED: man.openbsd.org ssh_config(5)]:
- `Include` directive resolves files without absolute paths relative to `~/.ssh` for user configs. So `Include identities/active` resolves to `~/.ssh/identities/active`. Use the absolute form `~/.ssh/identities/active` for clarity (works in both cases).
- ssh_config uses **first-match-wins** precedence: "for each parameter, the first obtained value will be used."
- `Include` can appear inside `Match` or `Host` blocks for conditional inclusion. (Phase 4 does NOT use this -- the include is unconditional, the symlink target is the gate.)
- The Include directive is supported in OpenSSH >= 7.3p1. macOS Sonoma 14 ships OpenSSH 9.x.

**Example main config:**
```
# identity/ssh/config -- symlinked to ~/.ssh/config
Host *
    SetEnv TERM=xterm-256color

Include ~/.ssh/identities/active
```

**Symlink swap (in `taskfiles/identity.yml`'s `identity:ssh` task):**
```yaml
- task: _:safe-link
  vars:
    SOURCE: "{{.HOME}}/.ssh/identities/{{.MANIFEST.identity.ssh}}"
    TARGET: "{{.HOME}}/.ssh/identities/active"
```

**Symlink target form** (resolves Claude's Discretion item from CONTEXT.md): point at `~/.ssh/identities/<name>` (resolved path) rather than the dotfiles repo source. Rationale:
- `readlink ~/.ssh/identities/active` returns a short readable name (`personal`).
- The identity files themselves are already symlinks pointing at the dotfiles repo source. Active is a symlink to a symlink -- ssh follows it transparently.
- Swapping identity is `ln -sfn personal ~/.ssh/identities/active` (one syscall, atomic).

**Idempotency status block:**
```yaml
status:
  - test -L "{{.HOME}}/.ssh/identities/active"
  - test "$(readlink {{.HOME}}/.ssh/identities/active)" = "{{.MANIFEST.identity.ssh}}"
```

Note: this status block uses `$(...)` inside a shell command, which is fine -- `{{.X}}` is the rule for go-template substitution in the line; once go-task renders the line, the shell runs it normally. The forbidden pattern is `$VAR` in status: where `VAR` is a go-task template variable, not a shell invocation.

**Verification one-liner:**
```bash
ssh -G foo.jgrid.net 2>&1 | grep -E '^(user|identityfile|identityagent|proxycommand) '
# expected: lines reflecting the active identity (e.g. for personal:
#   user josh
#   identityfile ~/.ssh/identities/keys/personal.pub
#   identityagent ~/Library/Group Containers/.../agent.sock
#   proxycommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname foo.jgrid.net
# )
```

### Pattern 4: 1Password agent socket gate (preserve Phase 3 wiring)

**What:** The `shell/.zprofile` jq-read of `features.one-password-ssh` already wires `SSH_AUTH_SOCK`. Phase 4 ships only the identity-file side. **No `.zprofile` changes in Phase 4.**

**Verified path** [VERIFIED: existing repo + community consensus]: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`.

**Existing wiring (Phase 3, already correct):**
```zsh
# shell/.zprofile -- already on disk; do not modify in Phase 4
if [[ -r "${XDG_STATE_HOME}/dotfiles/resolved.json" ]]; then
    _opssh=$(jq -r '.features."one-password-ssh" // false' "${XDG_STATE_HOME}/dotfiles/resolved.json" 2>/dev/null)
    if [[ "$_opssh" == "true" ]]; then
        export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
    fi
    unset _opssh
fi
```

**Phase 4 contribution -- inside `identity/ssh/identities/personal` and `work`:**
```
# These two identity files are ONLY loaded on machines where
# manifest:validate has confirmed features.one-password-ssh = true
# (the cross-field validator rejects identity.ssh in {personal, work}
# without the flag set). So this directive is always meaningful when
# this file is symlinked into ~/.ssh/identities/active.
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

**Important interaction** [CITED: man.openbsd.org ssh_config(5)]:
- `IdentityAgent` overrides the `SSH_AUTH_SOCK` environment variable. So the export from `.zprofile` IS the source of truth for tools that read `$SSH_AUTH_SOCK` directly (e.g. ssh-add, `op-ssh-sign`), but for `ssh` itself, the `IdentityAgent` directive in the config takes precedence.
- The two settings agree by design: both point to the 1Password socket. This redundancy is intentional -- it makes `ssh-add -L` work (uses SSH_AUTH_SOCK) AND it makes `ssh foo` work even when SSH_AUTH_SOCK is not in the calling environment (e.g. inside a launchd-spawned process).

### Anti-Patterns to Avoid

- **`Match exec "cat ~/.config/dotfiles/profile = 'X'"`** (v1 bug class) -- Replaced by manifest-driven symlink swap. Brittle (depends on a file outside the manifest), invokes a subshell per ssh invocation. Don't reintroduce.
- **`hostname` / `scutil --get` based dispatch** -- Forbidden per PROJECT.md. Manifest is the source of truth. Audit confirms zero such code in current active scripts (only `sethostname.zsh` references hostname, and that's a user-facing setter).
- **Bare `ln -s`** -- Forbidden outside `taskfiles/helpers.yml` (LINT-03b). Use `_:safe-link` everywhere.
- **`$VAR` in `status:` blocks where VAR is a go-task template variable** -- Forbidden (LINT-02, the v1 macos:shell:145 bug class). Status blocks must use `{{.X}}` template syntax for any go-task-resolved value.
- **Dot-access for kebab-case feature keys** -- `{{.MANIFEST.features.one-password-ssh}}` fails go-template parsing. Use `{{index .MANIFEST.features "one-password-ssh"}}`.
- **Hardcoded `/opt/homebrew`** -- Forbidden. Use `$HOMEBREW_PREFIX` (shell) or `{{.HOMEBREW_PREFIX}}` (task). Note `cloudflared.zsh` correctly uses `$HOMEBREW_PREFIX`.
- **`gitdir:` without the trailing slash** -- `gitdir:~/git/personal` matches only the literal `.git` dir at that exact path; you almost certainly want `gitdir:~/git/personal/` which matches `~/git/personal/**`. Phase 4 uses trailing slash.
- **`gitdir:` instead of `gitdir/i:` on macOS APFS** -- macOS default APFS is case-insensitive. A user typing `cd ~/git/Personal` (capital P) would not match `gitdir:~/git/personal/`. Use `gitdir/i:` to match regardless of case.
- **Committing private keys** -- IDNT-06. `identity/ssh/keys/` MUST contain only `*.pub` files. `task identity:validate` enforces.
- **Using `Include identities/active` without the `~/.ssh/` prefix** -- works (relative paths resolve to `~/.ssh`), but absolute form is clearer and matches the existing v1 pattern.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Runtime git identity selection | A pre-commit hook that rewrites `user.email`, or a wrapper script that calls `git -c user.email=...` | git's native `includeIf gitdir:` | Native, fast, no maintenance burden, no risk of forgetting to wrap |
| Runtime SSH identity selection | `Match exec` that reads a state file | Symlink swap on `~/.ssh/identities/active` | Match exec runs subprocess on every ssh invocation; symlink swap is O(1) and atomic |
| Idempotent symlink creation | Custom shell that checks `test -L`, removes, recreates | `_:safe-link` (already in `taskfiles/helpers.yml`) | Already battle-tested in Phase 3; uses `ln -sfn` which is idempotent |
| Idempotent re-run detection | Comparing file contents, recomputing checksums | `status:` block per go-task semantics | Native to go-task; respected by every task in the install pipeline |
| 1Password SSH agent detection | Custom socket probe + ssh-add -l with timeout | Cross-field manifest validation + assume socket is up | The cross-field validator (D-16) prevents the impossible case; if the user enables 1Password SSH but doesn't run 1Password, `ssh-add -L` will fail loudly during `task identity:validate` |
| Cross-field manifest validation | Inline jq inside a `cmds:` block | Function in `install/resolver.zsh` (matches existing `validate_manifest` pattern) | Resolver already owns all schema validation; cross-field rules live with sibling rules; testable via fixtures |
| Path expansion (`~/foo`) | Shell `${HOME}/foo` rewrite | Native tilde expansion in git includeIf and ssh config | Both git and ssh expand `~/` natively; no manual rewrite needed |
| TOML reading inside a taskfile | yq invocation in `cmds:` | go-task `fromJson` ref against `resolved.json` (established convention) | One TOML-parser per pipeline; resolver does the parsing once |

**Key insight:** Phase 4 is mostly composition glue, not new logic. The git includeIf mechanism, the ssh Include mechanism, and the manifest reader pattern are all already battle-tested by phases 1-3 or by git/ssh themselves. The risk surface is not in inventing identity selection but in correctly **wiring** the pieces together while preserving every locked decision in CONTEXT.md.

## Runtime State Inventory

Phase 4 is a greenfield identity layer plus a fresh edit to four machine TOMLs and one defaults.toml. The only state migration concern is around symlinks created during the existing v1 install (if any) and around the `$XDG_STATE_HOME/dotfiles/resolved.json` shape after the new validation rules land.

| Category | Items found | Action required |
|----------|-------------|------------------|
| Stored data | None -- this is a greenfield phase. v1 git/ssh configs live in `git/` and `ssh/` source dirs and are not yet symlinked anywhere by v2 (v2 install pipeline ships `links.yml` `all:` aggregator only for shell content as of Phase 3). The `~/.gitconfig` / `~/.ssh/config` files on the user's actual machines were last touched by v1 install -- those are byte-stable until v2 cutover (Phase 8). | None for Phase 4. Phase 8 cutover handles the v1-symlink -> v2-symlink swap. |
| Live service config | None. 1Password SSH agent reads its config from `~/.config/1Password/ssh/agent.toml` (user-managed, out of scope per CONTEXT.md domain section). The v1 `ssh/configs/agent.toml` is a documentation copy only. | None. |
| OS-registered state | None. Phase 4 creates no launchd services, no Task Scheduler entries, no systemd units. | None. |
| Secrets / env vars | `SSH_AUTH_SOCK` -- already exported by `shell/.zprofile` based on `features.one-password-ssh`. **No rename, no value change, no code edit.** Phase 4 ships only the identity-file side. | None. |
| Build artifacts | None. No compiled or installed packages embed identity names. `cloudflared.zsh` is a shell script (no build step). | None. |

Nothing in any category requires migration. Phase 4 is additive (new files in `identity/`, new task in `taskfiles/`) plus three edits (`manifests/defaults.toml`, four machine TOMLs, `docs/MANIFEST.md`, `install/resolver.zsh` validator).

## Common Pitfalls

### Pitfall 1: `gitdir:` without trailing slash

**What goes wrong:** `includeIf "gitdir:~/git/personal"]` only matches the literal `~/git/personal/.git` (no subdirs). The personal identity never fires for any repo cloned into `~/git/personal/`.

**Why it happens:** Misreading of the git-scm docs. Trailing slash is the documented convention for "everything under this directory."

**How to avoid:** Always use trailing slash + `gitdir/i:` form. Verified: `gitdir/i:~/git/personal/` matches `~/git/personal/**`.

**Warning signs:** `git config user.email` returns empty / wrong identity inside a personal repo. `git config --list --show-origin | grep email` shows the includeIf file did NOT contribute.

### Pitfall 2: Case-sensitive `gitdir:` on case-insensitive APFS

**What goes wrong:** macOS APFS is case-insensitive by default. A user typing `cd ~/Git/personal/foo` (capital G) creates a working tree at the OS-resolved canonical path `~/Git/personal/foo`. Whether `gitdir:~/git/personal/` matches depends on what canonicalization git applies (and whether it resolves the case).

**Why it happens:** Confusion between filesystem case-insensitivity (OS) and matching case-insensitivity (git's includeIf).

**How to avoid:** Use `gitdir/i:` form on macOS. Documented behavior: matches case-insensitively regardless of filesystem.

**Warning signs:** User reports "git uses wrong email after I `cd` to my repo." First diagnostic: `pwd` to see actual case of the path.

### Pitfall 3: Missing trailing newline in `~/.config/git/server-include.config`

**What goes wrong:** Generated file has no trailing newline. Git's gitconfig parser is generally tolerant but some tools (e.g. `git config --edit`) reflow with a trailing newline expectation.

**How to avoid:** Use `printf '%s\n'` or heredoc with `EOF` on a separate line in the install task that materializes the file.

### Pitfall 4: SSH `IdentityAgent` overrides `SSH_AUTH_SOCK` -- so `unset SSH_AUTH_SOCK; ssh foo.jgrid.net` still works

**What goes wrong:** Engineer thinks they've broken 1Password agent by unsetting `SSH_AUTH_SOCK`, but `ssh` still finds the agent via `IdentityAgent`. Confusion arises when ssh-add or other agent-using tools fail despite ssh "working."

**Why it happens:** `IdentityAgent` in `~/.ssh/identities/personal` takes precedence over the env var for `ssh` itself, but `ssh-add` reads `SSH_AUTH_SOCK` directly (no config).

**How to avoid:** Document the dual-source design: `.zprofile` exports `SSH_AUTH_SOCK` for tools that read it (`ssh-add`, `op-ssh-sign` outside git), and the identity files set `IdentityAgent` for ssh itself. Both should agree; cross-field validator enforces.

**Warning signs:** `ssh foo.jgrid.net` works but `ssh-add -L` returns "Error connecting to agent." Diagnostic: `echo $SSH_AUTH_SOCK` -- if empty, the `.zprofile` jq read failed.

### Pitfall 5: Symlinking `~/.ssh/identities/active` to a non-existent target

**What goes wrong:** `task identity:install` creates a dangling symlink because the upstream identity file symlink hasn't been created yet, or `identity.ssh = "none"` was assumed to mean "don't link active."

**Why it happens:** Subtask ordering inside `identity:ssh` matters: link all four identity files FIRST, then link active to one of them. Also: `identity.ssh = "none"` is a valid manifest value (D-05); the planner must decide what `active` points to in that case.

**How to avoid:** In `identity:ssh`, sequence the cmds so identity files exist before `active` is linked. For `identity.ssh = "none"`, options:
- Skip the active link entirely (the `Include ~/.ssh/identities/active` in main config silently ignores missing files? **NO** -- ssh's `Include` of a missing file is a hard error in some versions; verify).
- Link active -> a no-op file (`identity/ssh/identities/none` containing only a comment).

**Recommendation:** Ship a `identity/ssh/identities/none` file containing only `# identity = none -- no host-specific config` (comment-only). Link `active` to it when `identity.ssh = "none"`. This avoids both the dangling-symlink class AND the "ssh Include of a missing file" class. **Symmetric for git.** This is a *planner concern* — CONTEXT.md does not explicitly call this out but D-05 admits "none" into the enum.

### Pitfall 6: `[include] path = server-include.config` missing file behavior across git versions

**What goes wrong:** Some old git versions or third-party git tooling (e.g. Sublime Merge per the GitHub issue cited in search) error on missing includes rather than silently ignoring. D-08 relies on the silent-no-op behavior.

**How to avoid:** D-08 should be paired with a verified-version guard. Document in the file header that the wildcard works only with git >= 2.13 (when includeIf landed) AND with the `git` binary, not GUI clients. Document in README that workstation main config has a deliberate `[include]` line that resolves to nothing on non-server machines.

**Warning signs:** `git config --list` errors on a workstation. Diagnostic: `git --version` (must be >= 2.13).

### Pitfall 7: `Include` order matters (first-match-wins) in SSH

**What goes wrong:** Engineer adds a global `Host * IdentitiesOnly yes` directive AFTER `Include ~/.ssh/identities/active` in the main config. The `Host *` block in the personal identity file (`IdentityAgent ...`) was processed FIRST, so its `IdentityAgent` is locked in, but the engineer expects to override globally. They can't.

**Why it happens:** ssh_config is first-match-wins per parameter.

**How to avoid:** Keep the main `~/.ssh/config` minimal -- just the `Host * SetEnv` line and the Include. Put all per-identity directives in the identity file. CONTEXT.md D-10 already specifies this shape.

**Warning signs:** Adding a directive to `~/.ssh/config` "doesn't take effect." Diagnostic: `ssh -G foo` to see the parsed config.

### Pitfall 8: The `~/.ssh/identities/keys/<name>.pub` IdentityFile reference

**What goes wrong:** v1 SSH configs reference `~/.ssh/id_ed25519_personal.pub` -- public key (`.pub`). This is intentional for 1Password: 1Password's agent serves the private key in response to a public-key challenge. The `IdentityFile` directive in this context tells ssh "use the agent identity matching this public key."

**Why it happens:** Misreading "IdentityFile" as "private key file." On a normal ssh-agent workflow, you'd want the private key here. With 1Password, the public key works because the agent does the signing.

**How to avoid:** Port the v1 path verbatim (just update the location prefix to `~/.ssh/identities/keys/`). Document in `identity/README.md` why it's `.pub`.

**Warning signs:** Engineer "fixes" the path to point at a private key and breaks the personal identity flow.

### Pitfall 9: Identity rename from `id_ed25519_personal` to `personal` (key file in keys/)

**What goes wrong:** v1's repo has the key at `ssh/keys/id_ed25519_personal.pub`. v2 wants `identity/ssh/keys/personal.pub`. The 1Password agent.toml entry references the key by 1Password vault item name (`id_ed25519_personal`) -- but the `IdentityFile` in the ssh config references the file path. These are independent.

**How to avoid:** Rename the file in the repo. Do NOT touch 1Password agent.toml (it's user-managed, lives outside the repo). The `IdentityFile ~/.ssh/identities/keys/personal.pub` directive in `identity/ssh/identities/personal` tells ssh "request the identity matching this public key from the agent"; 1Password serves it regardless of the filename.

**Warning signs:** `ssh-add -L` shows the key (because the agent is responding) but ssh fails with "no matching identity." Diagnostic: `ssh -vvv foo.jgrid.net` to see which public key ssh is offering.

### Pitfall 10: Forgetting to update `.gitignore` for committed `.pub` files

**What goes wrong:** A future engineer adds a `*.pub` glob to `.gitignore`, or the test-fixtures `.gitignore` blocks the new keys directory. The pub keys silently never enter the repo.

**How to avoid:** Phase 4 should ship an explicit allow-list `.gitignore` snippet for `identity/ssh/keys/`:
```
# identity/ssh/keys/.gitignore
# Allowlist: only .pub files allowed in this directory.
*
!*.pub
!.gitignore
```
This belt-and-braces makes IDNT-06 enforceable at git-level as well as task-validate-level.

## Code Examples

Verified patterns from official sources + existing-repo conventions.

### `identity/git/config` -- main config (full content)

```ini
# identity/git/config -- main git config; symlinked to ~/.config/git/config.
#
# Identity selection model:
#   1. Workstation: gitdir/i match drives selection. cd into ~/git/personal/foo
#      and git uses the personal identity. cd into ~/git/work/bar and git uses
#      the work identity. Outside these gitdirs, [user.email] is unset and
#      git refuses to commit (D-04 trade-off: discipline > convenience).
#   2. Server: an unconditional [include] picks up ~/.config/git/server-include.config,
#      which is materialized only on server machines and contains a wildcard
#      [includeIf "gitdir:~/"] selector. Missing on workstations = silent no-op
#      per git's documented include-file behavior.
#
# Schema reference: docs/MANIFEST.md identity.git enum.

[user]
    name = Josh Vaughen

[includeIf "gitdir/i:~/git/personal/"]
    path = identities/personal

[includeIf "gitdir/i:~/git/work/"]
    path = identities/work

[include]
    path = server-include.config

[core]
    editor = code
    excludesfile = ignore
    pager = delta

[init]
    defaultBranch = main

[fetch]
    prune = true

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    side-by-side = true
    line-numbers = true
    syntax-theme = Monokai Extended

[status]
    showUntrackedFiles = all
    submoduleSummary = true

[alias]
    # list all git aliases
    aliases = !git config -l | grep alias | cut -c 7- | highlight --style=duotone-dark-sky --syntax=bash --out-format=xterm256

    # useful aliases
    tags = tag -l
    branches = branch --all
    remotes = remote --verbose
    undo = reset --soft HEAD~1

    # lookups
    whois = "!sh -c 'git log --regexp-ignore-case -1 --pretty=\"format:%an <%ae>\\n\" --author=\"$1\"' -"
    whatis = show --no-patch --pretty='tformat:%h (%s, %ad)' --date=short

    # find commits by source code
    fc = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short -S$1; }; f"

    # find commits by commit message
    fm = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep=$1; }; f"

    # list contributors with number of commits
    contributors = shortlog --summary --numbered

    # show the user email for the current repository
    whoami = config user.email

    # useful displays
    hist = log --graph --abbrev-commit --decorate --all --format=format:"%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(dim white) - %an%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n %C(white)%s%C(reset)"
    latest = for-each-ref --sort=committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'
    quicklog = log --oneline --decorate -20 --pretty=format:'%C(yellow)%h%C(reset)%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'
```

### `identity/git/identities/personal` (full content -- port of v1)

```ini
# identity/git/identities/personal -- personal identity overlay.
#
# Loaded by main config's [includeIf gitdir/i:~/git/personal/] block.
# Path = relative to ~/.config/git/ (the directory of the including file).

[user]
    name = Josh Vaughen
    email = josh@vaughen.net
    signingkey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMsU4L+sNRYKBy7p294G4YVbsjT4O4ewT9OTnKbfnfdT

[github]
    user = jshvn

[gpg]
    format = ssh

[gpg "ssh"]
    program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"

[commit]
    gpgsign = true
```

### `identity/git/identities/server-1` (new, derived from v1 config-server)

```ini
# identity/git/identities/server-1 -- server-1 identity overlay.
#
# Loaded by server-include.config (materialized only on server-1) via
# wildcard [includeIf "gitdir:~/"].

[user]
    name = Server-1
    email = server-1@jgrid.net

[github]
    user = jshvn

[commit]
    gpgsign = false
```

### `identity/ssh/config` (full content)

```
# identity/ssh/config -- main SSH config; symlinked to ~/.ssh/config.
#
# Identity selection model:
#   The Include line below points at ~/.ssh/identities/active, which is a
#   symlink to one of identities/{personal,work,server-1,server-2}. The
#   symlink target is rewritten by `task identity:install` based on the
#   manifest's identity.ssh value. Swapping identity = relink active.
#
# Schema reference: docs/MANIFEST.md identity.ssh enum.

Host *
    SetEnv TERM=xterm-256color

Include ~/.ssh/identities/active
```

### `identity/ssh/identities/personal` (port of v1 with path updates)

```
# identity/ssh/identities/personal -- personal SSH identity.
#
# Loaded via ~/.ssh/config's Include directive when identity.ssh = "personal".
# References:
#   1Password agent socket: requires features.one-password-ssh = true (validator enforces).
#   cloudflared.zsh: deployed on every machine; only this identity uses it.

Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

Host *.jgrid.net
    IdentityFile ~/.ssh/identities/keys/personal.pub
    IdentitiesOnly yes
    User josh
    ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h
    RemoteCommand if [[ "$(uname)" = "Darwin" ]]; then cd ~/Git/personal/jgrid.net/; else cd ~/git/jgrid.net/; fi && exec $SHELL -l
    RequestTTY yes

Host *.plex.me
    IdentityFile ~/.ssh/identities/keys/personal.pub
    IdentitiesOnly yes
    User josh
    ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h
```

### `identity/ssh/identities/server-1`

```
# identity/ssh/identities/server-1 -- server-1 SSH identity.
#
# Loaded via ~/.ssh/config's Include directive when identity.ssh = "server-1".
# No 1Password agent; uses the system ssh-agent with the deploy key generated
# locally at cutover time and registered in github.com's deploy-key list.

Host github.com
    IdentityFile ~/.ssh/id_ed25519_server-1
    IdentitiesOnly yes
    AddKeysToAgent yes
```

### `identity/ssh/identities/none` (recommended; addresses Pitfall 5)

```
# identity/ssh/identities/none -- no-op identity.
#
# Linked as ~/.ssh/identities/active when identity.ssh = "none".
# Ensures the Include in main config resolves to a real file (avoids any
# "Include of missing file" ambiguity across ssh versions).
```

### `taskfiles/identity.yml` (full sketch)

```yaml
version: '3'

# =============================================================================
# taskfiles/identity.yml -- Phase 4: manifest-driven git + SSH identity layer.
#
# Reads identity.git, identity.ssh, features.one-password-ssh, and
# features.one-password-signing from resolved.json. Creates all symlinks via
# _:safe-link (LINT-03b). Idempotent: re-running is a no-op (every install
# subtask has a status: block per LINT-01).
#
# Aggregator placement: identity:install is referenced from taskfiles/links.yml
# `all:` (Phase 3's links.yml comment names P4 as the next extender). Planner
# may alternatively place the reference in the root Taskfile.yml install task.
#
# Dependencies:
#   - manifest:resolve (deps: ensures resolved.json is fresh)
#   - taskfiles/helpers.yml: _:safe-link, _:check-link
#   - install/messages.zsh: check, cross, error, warn, info, success
# =============================================================================

includes:
  _: ./helpers.yml

vars:
  HOME: '{{.HOME}}'

  XDG_CONFIG_HOME:
    sh: echo "${XDG_CONFIG_HOME:-$HOME/.config}"

  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"

  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"

  RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'

  MANIFEST_JSON:
    sh: |
      if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
        cat '{{.RESOLVED_JSON_PATH}}'
      else
        echo "warning: {{.RESOLVED_JSON_PATH}} missing -- run 'task setup -- <machine>' first" >&2
        echo '{}'
      fi

  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'

  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'

  # Convenience derived paths.
  GIT_CONFIG_DIR: '{{.XDG_CONFIG_HOME}}/git'
  SSH_DIR: '{{.HOME}}/.ssh'
  SSH_IDENTITIES_DIR: '{{.SSH_DIR}}/identities'
  SSH_KEYS_DIR: '{{.SSH_IDENTITIES_DIR}}/keys'
  SERVER_INCLUDE_CONFIG: '{{.GIT_CONFIG_DIR}}/server-include.config'

tasks:

  # ---------------------------------------------------------------------------
  # Aggregator -- composes git + ssh. Idempotency lives in sub-tasks.
  # ---------------------------------------------------------------------------

  # lint-allow: cmds-without-status
  install:
    desc: "Install identity layer (git + ssh)"
    deps: [manifest:manifest:resolve]
    cmds:
      - task: git
      - task: ssh

  # ---------------------------------------------------------------------------
  # Git: main config + four identity files + (servers) server-include.config.
  # ---------------------------------------------------------------------------

  git:
    desc: "Link git identity files; materialize server-include.config on servers"
    cmds:
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/config"
          TARGET: "{{.GIT_CONFIG_DIR}}/config"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/ignore"
          TARGET: "{{.GIT_CONFIG_DIR}}/ignore"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/identities/personal"
          TARGET: "{{.GIT_CONFIG_DIR}}/identities/personal"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/identities/work"
          TARGET: "{{.GIT_CONFIG_DIR}}/identities/work"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/identities/server-1"
          TARGET: "{{.GIT_CONFIG_DIR}}/identities/server-1"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/git/identities/server-2"
          TARGET: "{{.GIT_CONFIG_DIR}}/identities/server-2"
      - task: server-include
    status:
      - test -L "{{.GIT_CONFIG_DIR}}/config"
      - test -L "{{.GIT_CONFIG_DIR}}/ignore"
      - test -L "{{.GIT_CONFIG_DIR}}/identities/personal"
      - test -L "{{.GIT_CONFIG_DIR}}/identities/work"
      - test -L "{{.GIT_CONFIG_DIR}}/identities/server-1"
      - test -L "{{.GIT_CONFIG_DIR}}/identities/server-2"

  # Materialize server-include.config when identity.git is server-N; absent
  # on workstations (git silently ignores missing includes).
  # Planner: choose generate-at-install (sketched) vs template+substitution.
  server-include:
    desc: "Materialize ~/.config/git/server-include.config when identity is a server"
    internal: true
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        identity="{{.MANIFEST.identity.git}}"
        case "$identity" in
          server-1|server-2)
            mkdir -p "{{.GIT_CONFIG_DIR}}"
            printf '[includeIf "gitdir:~/"]\n    path = identities/%s\n' "$identity" \
              > "{{.SERVER_INCLUDE_CONFIG}}"
            check "server-include.config materialized for $identity"
            ;;
          *)
            # Workstation: remove any stale server-include.config from a prior cutover.
            if [[ -f "{{.SERVER_INCLUDE_CONFIG}}" ]]; then
              rm -f "{{.SERVER_INCLUDE_CONFIG}}"
              info "removed stale server-include.config (identity is $identity)"
            fi
            ;;
        esac
    # Status block: file is present + correct on servers; absent on workstations.
    # Uses {{.MANIFEST.identity.git}} which is a dot-access path (snake_case keys
    # all the way down).
    status:
      - |
        identity="{{.MANIFEST.identity.git}}"
        case "$identity" in
          server-1|server-2)
            test -f "{{.SERVER_INCLUDE_CONFIG}}" && \
              grep -q "identities/${identity}" "{{.SERVER_INCLUDE_CONFIG}}"
            ;;
          *)
            test ! -f "{{.SERVER_INCLUDE_CONFIG}}"
            ;;
        esac

  # ---------------------------------------------------------------------------
  # SSH: main config + four identity files + four pub keys + cloudflared + active.
  # ---------------------------------------------------------------------------

  ssh:
    desc: "Link SSH identity files; swap active symlink to manifest value"
    cmds:
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/config"
          TARGET: "{{.SSH_DIR}}/config"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/identities/personal"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/personal"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/identities/work"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/work"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/identities/server-1"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/server-1"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/identities/server-2"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/server-2"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/identities/none"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/none"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/keys/personal.pub"
          TARGET: "{{.SSH_KEYS_DIR}}/personal.pub"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/keys/server-1.pub"
          TARGET: "{{.SSH_KEYS_DIR}}/server-1.pub"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/keys/server-2.pub"
          TARGET: "{{.SSH_KEYS_DIR}}/server-2.pub"
      - task: _:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/identity/ssh/cloudflared.zsh"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/cloudflared.zsh"
      - task: _:safe-link
        vars:
          SOURCE: "{{.SSH_IDENTITIES_DIR}}/{{.MANIFEST.identity.ssh}}"
          TARGET: "{{.SSH_IDENTITIES_DIR}}/active"
    status:
      - test -L "{{.SSH_DIR}}/config"
      - test -L "{{.SSH_IDENTITIES_DIR}}/personal"
      - test -L "{{.SSH_IDENTITIES_DIR}}/work"
      - test -L "{{.SSH_IDENTITIES_DIR}}/server-1"
      - test -L "{{.SSH_IDENTITIES_DIR}}/server-2"
      - test -L "{{.SSH_IDENTITIES_DIR}}/none"
      - test -L "{{.SSH_IDENTITIES_DIR}}/active"
      - |
        test "$(readlink {{.SSH_IDENTITIES_DIR}}/active)" = "{{.MANIFEST.identity.ssh}}" \
          || test "$(readlink {{.SSH_IDENTITIES_DIR}}/active)" = "{{.SSH_IDENTITIES_DIR}}/{{.MANIFEST.identity.ssh}}"
      - test -L "{{.SSH_KEYS_DIR}}/personal.pub"
      - test -L "{{.SSH_KEYS_DIR}}/server-1.pub"
      - test -L "{{.SSH_KEYS_DIR}}/server-2.pub"
      - test -L "{{.SSH_IDENTITIES_DIR}}/cloudflared.zsh"

  # ---------------------------------------------------------------------------
  # Validate -- four assertions matching success criteria.
  # ---------------------------------------------------------------------------

  # lint-allow: cmds-without-status
  validate:
    desc: "Validate identity layer: symlinks, git config, ssh-add, keys/ contents"
    cmds:
      # (a) Symlinks present and pointing at real targets.
      - task: _:check-link
        vars: { TARGET: "{{.GIT_CONFIG_DIR}}/config", NAME: "git config" }
      - task: _:check-link
        vars: { TARGET: "{{.SSH_DIR}}/config", NAME: "ssh config" }
      - task: _:check-link
        vars: { TARGET: "{{.SSH_IDENTITIES_DIR}}/active", NAME: "ssh identities/active" }
      - task: _:check-link
        vars: { TARGET: "{{.SSH_IDENTITIES_DIR}}/cloudflared.zsh", NAME: "cloudflared.zsh" }
      # (b) git config user.email matches manifest expectation (skip if gitdir absent).
      - |
        {{.DOTFILES_MESSAGES}}
        identity="{{.MANIFEST.identity.git}}"
        case "$identity" in
          personal)
            gitdir="$HOME/git/personal"
            expected_email="josh@vaughen.net"
            ;;
          work)
            gitdir="$HOME/git/work"
            # Read from the identity file itself to avoid hardcoding work email here.
            expected_email=$(git config -f "{{.DOTFILEDIR}}/identity/git/identities/work" user.email 2>/dev/null || echo "")
            ;;
          server-1|server-2)
            gitdir="$HOME"
            expected_email="${identity}@jgrid.net"
            ;;
          none)
            info "identity.git = none -- skipping email assertion"
            exit 0
            ;;
        esac
        if [[ ! -d "$gitdir/.git" ]] && [[ "$identity" != server-* ]]; then
          # Workstation without the matching gitdir present: create a temp .git and check.
          tmp=$(mktemp -d)
          (cd "$tmp" && git init -q && cd "$gitdir" 2>/dev/null || true)
          rm -rf "$tmp"
          info "no $gitdir/.git on this machine -- skipping git email assertion"
          exit 0
        fi
        actual_email=$(git -C "$gitdir" config user.email 2>/dev/null || echo "")
        if [[ "$actual_email" == "$expected_email" ]]; then
          check "git user.email in $gitdir = $actual_email"
        else
          cross "git user.email in $gitdir: expected '$expected_email', got '$actual_email'"
          exit 1
        fi
      # (c) ssh-add -L lists the expected public key fingerprint.
      - |
        {{.DOTFILES_MESSAGES}}
        opssh=$(jq -r '.features."one-password-ssh" // false' "{{.RESOLVED_JSON_PATH}}")
        if [[ "$opssh" != "true" ]]; then
          info "features.one-password-ssh = false -- skipping ssh-add -L assertion"
          exit 0
        fi
        identity="{{.MANIFEST.identity.ssh}}"
        expected_pub="{{.DOTFILEDIR}}/identity/ssh/keys/${identity}.pub"
        if [[ ! -s "$expected_pub" ]]; then
          warn "expected pub key not provisioned: $expected_pub"
          exit 0
        fi
        # Extract just the key body (drop the comment field).
        expected_body=$(awk '{print $2}' "$expected_pub")
        if ssh-add -L 2>/dev/null | awk '{print $2}' | grep -qF "$expected_body"; then
          check "ssh-add -L lists $identity public key"
        else
          cross "ssh-add -L does not list expected key body for $identity"
          exit 1
        fi
      # (d) identity/ssh/keys/ contains ONLY *.pub files.
      - |
        {{.DOTFILES_MESSAGES}}
        keys_repo="{{.DOTFILEDIR}}/identity/ssh/keys"
        bad=$(find "$keys_repo" -maxdepth 1 -type f -not -name '*.pub' -not -name '.gitignore' 2>/dev/null)
        if [[ -z "$bad" ]]; then
          check "identity/ssh/keys/ contains only *.pub files"
        else
          cross "identity/ssh/keys/ contains non-.pub files:"
          echo "$bad" >&2
          exit 1
        fi
```

### Cross-field validation in `install/resolver.zsh` (new function)

Add to `validate_manifest()` after the identity enum case-statement:

```zsh
# D-16: cross-field rules.
#   identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true
#   identity.git ∈ {personal, work} ⇒ features.one-password-signing = true
local identity_ssh identity_git
identity_ssh=$(yq -r '.identity.ssh // ""' "$machine_file" 2>/dev/null || echo "")
identity_git=$(yq -r '.identity.git // ""' "$machine_file" 2>/dev/null || echo "")

local opssh opsign
opssh=$(yq -r '.features."one-password-ssh" // false' "$machine_file" 2>/dev/null || echo "false")
opsign=$(yq -r '.features."one-password-signing" // false' "$machine_file" 2>/dev/null || echo "false")

case "$identity_ssh" in
  personal|work)
    if [[ "$opssh" != "true" ]]; then
      error "identity.ssh = \"${identity_ssh}\" requires features.one-password-ssh = true"
      errors=$(( errors + 1 ))
    fi
    ;;
esac

case "$identity_git" in
  personal|work)
    if [[ "$opsign" != "true" ]]; then
      error "identity.git = \"${identity_git}\" requires features.one-password-signing = true"
      errors=$(( errors + 1 ))
    fi
    ;;
esac
```

Also expand the existing identity enum case-statement (resolver.zsh:203-208):

```zsh
case "$ident_val" in
  personal|work|server-1|server-2|none) ;;
  *) error "identity.${ident_key} must be one of personal|work|server-1|server-2|none; got: ${ident_val}"
     errors=$(( errors + 1 )) ;;
esac
```

### `identity/ssh/keys/.gitignore` (recommended belt-and-braces for IDNT-06)

```
# identity/ssh/keys/.gitignore
# Allowlist: only .pub files (and this .gitignore) may live here.
# IDNT-06: private keys NEVER enter the repo.
*
!*.pub
!.gitignore
```

### Hostname literal audit (informational; no action required)

```
# Audit command:
grep -rEn 'hostname|scutil --get' . --include='*.zsh' --include='*.yml' --include='*.toml' \
  | grep -v '^\./\.planning' | grep -v '\.git/' | grep -v 'sethostname'

# Findings:
#   shell/functions/whois.zsh:26  -- comment about hostname vs IP (not a gate)
#   zsh/configs/trippy.toml:235-236  -- trippy DNS settings (v1 leftover; not in v2 install path)
#   zsh/functions/sethostname.zsh  -- v1 leftover; not in v2 install path
#
# Active v2 code with hostname-based identity dispatch: ZERO.
# Phase 4 does not need to remove anything; the v1 issue was structurally
# closed in Phase 3 by .zprofile's switch to features.one-password-ssh.
```

## State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| v1: `Match exec "cat .../profile = 'X'"` SSH-config branch | v2: `Include ~/.ssh/identities/active` + manifest-driven symlink swap | Phase 4 (this phase) | Removes subshell per ssh invocation; eliminates the v1 bug class (race condition between profile state file and ssh config load) |
| v1: `hostname -s != "server"` literal in `.zprofile` 1Password gate | v2: jq read of `features.one-password-ssh` from `resolved.json` | Phase 3 (already shipped) | Manifest is sole source of truth |
| v1: `git/config-personal`, `config-work`, `config-server` filename-suffix pattern | v2: `identity/git/identities/<name>` flat per-identity files | Phase 4 (this phase) | No filename-encoded state; clean separation between scaffolding and identity |
| Three-value identity enum (`personal | work | none`) | Five-value identity enum (`personal | work | server-1 | server-2 | none`) | Phase 4 D-05 | Per-server emails; admits per-machine deploy keys |
| Single `features.one-password-ssh` flag | Split: `one-password-ssh` + `one-password-signing` | Phase 4 D-15 | Future flexibility; cross-field validation enforces consistency |

**Deprecated / outdated:**
- v1 `Match exec` SSH identity dispatch -- replaced by symlink swap (Phase 4). v1 files stay byte-stable on master until Phase 8 cutover.
- v1 `~/.config/dotfiles/profile` state file -- not used in v2 at all. Replaced by `$XDG_STATE_HOME/dotfiles/machine` (Phase 1 BTSP-04).
- Three-value identity enum -- superseded by Phase 4 D-05.
- Bare `ln -s` in install scripts -- forbidden since Phase 2 LINT-03b.

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | 1Password agent socket at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` is stable across 1Password 8.x versions on macOS Sonoma+ | Pattern 4, Pitfall 4 | Existing `.zprofile` already uses this path -- if it changes, both `.zprofile` and identity files would need to update. Mitigated by being the documented community-canonical path used by every published 1Password+SSH tutorial since 2022. |
| A2 | `cloudflared` Homebrew formula will be available via Phase 5's `core.rb` | Pattern, Don't Hand-Roll, Deferred | If Phase 5 doesn't ship `cloudflared`, the personal identity's ProxyCommand fails when user actually tries `ssh foo.jgrid.net`. Mitigated by D-14 "deploy everywhere" -- the failure is loud and contextual (only fires on machines where the user attempts a `*.jgrid.net` ssh). |
| A3 | macOS bundled git >= 2.13 (for includeIf support) and >= 2.34 (for SSH signing) on all four target machines | Standard Stack | Verified for Sonoma 14+ (Xcode 15+ ships git 2.39). If a target machine has an older Xcode, brew git is a fallback. CONTEXT.md lists macOS-only v1 across all four machines -- low risk. |
| A4 | macOS bundled OpenSSH >= 7.3p1 (for Include directive) on all four target machines | Standard Stack | Verified for any macOS >= 10.13 (High Sierra, 2017). Trivially true on all v1 target machines. |
| A5 | `git config -f <file> user.email` works for reading the work email from the (unsymlinked) repo source file | `task identity:validate` code example, branch (b) | Documented git behavior; verified by reading git-scm docs. |

A1 and A2 are the only assumptions that carry runtime risk. Both are mitigated by failing loudly at use time rather than silently misbehaving.

## Open Questions (RESOLVED)

1. **Work git email value** (carried from CONTEXT.md Open Questions)
   - RESOLVED: Plan 04-02 Task 1(d) ships `identity/git/identities/work` with a `# TODO: set work email before merge` marker. User must fill before Phase 4 merge. Validator's assertion (b) handles empty `expected_email` gracefully (silently passes when the gitdir is also absent).
   - What we know: v1 `git/config-work` has no email line.
   - What's unclear: which work email to put in `identity/git/identities/work`.
   - Recommendation: planner adds a task that ships `identity/git/identities/work` with a `# TODO: set work email` comment marker, plus a manual checklist item in the cutover documentation. Validator should soft-warn (not hard-fail) when `identity.git = "work"` AND the file has no `email` line.

2. **`identity/git/identities/none` and `identity/ssh/identities/none` -- ship a no-op file or skip linking?** (Pitfall 5)
   - RESOLVED: Plan 04-02 ships `none` as a comment-only file (single header line) so `active -> none` is a real link target (avoids Pitfall 5: "Include of missing file" ambiguity).
   - What we know: `identity.{git,ssh} = "none"` is a valid manifest value (D-05). What it should resolve to is not specified.
   - What's unclear: does linking `active -> none` (where `none` is a comment-only file) cleanly produce ssh-config-no-op behavior?
   - Recommendation: ship `identity/ssh/identities/none` as a comment-only file. Symmetric for git (`identity/git/identities/none` -- comment only, never loaded via includeIf because no gitdir-pattern matches it). This eliminates the "Include of missing file" ambiguity across ssh versions.

3. **`server-include.config` materialization technique**
   - RESOLVED: Plan 04-04 Task 1 generates the file at install time via `printf` heredoc in the `taskfiles/identity.yml :server-include` subtask (more inspectable than sed substitution).
   - What we know: D-08 leaves this to planner discretion (template + sed vs generate-at-install).
   - Recommendation: generate-at-install via `printf` heredoc inside the `server-include` subtask. Status block checks file existence + content match. This is more inspectable than a sed substitution (the generated file's content matches its expected form exactly).

4. **`task identity:install` aggregator placement** (Claude's Discretion item)
   - RESOLVED: Plan 04-04 Task 1 wires the aggregator into `taskfiles/links.yml all:` (per Phase 3 comment naming Phase 4 as the next extender). Root `Taskfile.yml` gains a `task: identity:install` include only if not already present.
   - What we know: extend `links.yml all:` vs. add to root `Taskfile.yml`.
   - Recommendation: add to `links.yml all:` (lower-impact change, Phase 3 already named P4 as next extender). The aggregator there is the natural place for "all symlinks" tasks; identity is exactly that.

5. **Server pub-key placeholder content** (CONTEXT.md Claude's Discretion)
   - RESOLVED: Plan 04-02 Task 2 ships `identity/ssh/keys/server.pub` and `identity/ssh/keys/server-staging.pub` with a single header comment line each. `task identity:validate` skips the `ssh-add -L` assertion when `features.one-password-ssh = false` (so placeholder-only machines pass).
   - What we know: D-09 commits the files, but the actual key content materializes at first cutover.
   - Recommendation: ship the file with a single header comment line:
     ```
     # Replace this file with the contents of id_ed25519_server-1.pub generated at cutover.
     # See docs/CUTOVER.md (Phase 8, DOCS-08).
     ```
     `task identity:validate` skips the `ssh-add -L` assertion when `one-password-ssh = false` (which is the case for servers), so the placeholder file doesn't cause validation to fail.

## Environment Availability

Phase 4 depends on existing tools all installed earlier in the bootstrap chain.

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| go-task | All Phase 4 tasks | Verified (Phase 0+1 install) | >= 3.37 | -- |
| yq (mikefarah) | `install/resolver.zsh` cross-field validation | Verified (Phase 0+1) | >= 4.52.1 | -- |
| jq | `task identity:validate`, `.zprofile` | Verified (Phase 0+1) | >= 1.7 | -- |
| git | `task identity:validate`, runtime gitconfig | Bundled on macOS | >= 2.13 (system git on Sonoma is 2.39+) | brew git |
| OpenSSH (`ssh`, `ssh-add`) | runtime SSH; `task identity:validate` | Bundled on macOS | >= 7.3p1 (Sonoma is 9.x) | -- |
| 1Password agent (`op-ssh-sign` binary) | runtime when identity ∈ {personal, work}; git commit signing | App install required; assumed installed on laptops | -- | Cross-field validator catches the missing-flag case; missing binary at runtime fails loudly during `git commit` |
| `cloudflared` binary | runtime `*.jgrid.net` ssh ProxyCommand | Assumed installed via Phase 5 `core.rb` | -- | Failure is loud at ssh time on machines where user attempts jgrid access |

**Missing dependencies with no fallback:** None for Phase 4 install-time. Runtime ProxyCommand failures (cloudflared, op-ssh-sign) are deferred to Phase 5 (packages) and to user-managed installs (1Password.app).

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test framework

| Property | Value |
|----------|-------|
| Framework | go-task subtasks + zsh assertion scripts (consistent with Phase 1-3) |
| Config file | `taskfiles/identity.yml` (new); `install/resolver.zsh` (existing, edited) |
| Quick run command | `task identity:validate` (single command; output via `install/messages.zsh` check/cross) |
| Full suite command | `task manifest:test` + `task lint` + `task identity:validate` |
| Phase gate | `task identity:validate` exits 0 with all four assertions green |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File exists? |
|--------|----------|-----------|-------------------|-------------|
| IDNT-01 | Main git config uses `includeIf gitdir:` for path-based identity selection | unit (file content) | `grep -q 'gitdir/i:~/git/personal/' identity/git/config` | NO — Wave 0 (add to `taskfiles/identity.yml` `validate` task or to a new `taskfiles/test/identity-fixtures.yml`) |
| IDNT-02 | Per-identity git configs live under `identity/git/identities/<name>` with no profile-suffix filenames | unit (directory listing) | `find identity/git/identities -type f -name 'config-*' | wc -l` == 0 | NO — Wave 0 |
| IDNT-03 | Main SSH config uses `Include` for identity selection | unit (file content) | `grep -q 'Include ~/.ssh/identities/active' identity/ssh/config` | NO — Wave 0 |
| IDNT-04 | Per-identity SSH configs live under `identity/ssh/identities/<name>` with no profile-suffix filenames | unit (directory listing) | `find identity/ssh/identities -type f -name 'config-*' | wc -l` == 0 | NO — Wave 0 |
| IDNT-05 | 1Password SSH agent integration gated by `features.one-password-ssh`; no hostname literals in identity path | integration (cross-field + audit) | (a) `task manifest:validate` accepts personal + opssh=true; rejects personal + opssh=false. (b) `grep -rEn 'hostname|scutil' identity/ taskfiles/identity.yml` returns 0 lines | NO — Wave 0 (extend `manifest:test` with two new fixtures: `_invalid-identity-without-opssh`, `_invalid-identity-without-opsign`) |
| IDNT-06 | Public SSH keys committed under `identity/ssh/keys/`; private keys never committed | unit (directory contents) | `find identity/ssh/keys -maxdepth 1 -type f -not -name '*.pub' -not -name '.gitignore'` == empty | NO — Wave 0 (assertion (d) in `task identity:validate`) |
| IDNT-07 | `task validate` (composed in Phase 8) asserts git config user.email and ssh-add -L | integration | `task identity:validate` performs (b) git config check, (c) ssh-add -L check on supporting machines | NO — Wave 0 (new task) |
| IDNT-08 | `taskfiles/identity.yml` reads identity from `resolved.json` and creates symlinks via `_:safe-link` | integration (file + structural) | (a) `grep -q 'ref: .fromJson .MANIFEST_JSON' taskfiles/identity.yml`. (b) `task lint:taskfile` passes (no bare `ln -s` in identity.yml; status blocks use `{{.X}}` only) | NO — Wave 0 (lint suite extension) |

### Sampling Rate

- **Per task commit:** `task lint` + `task manifest:test` (covers schema + lint passes; ~2-3 seconds total).
- **Per wave merge:** `task identity:validate` on a machine that has run `task setup -- personal-laptop` and `task install` (covers symlink integrity + git/ssh assertions).
- **Phase gate:** `task identity:validate` green on all four machines (or on as many as can be sanity-checked locally during Phase 4 development). Phase 8 cutover validates against real `~/git/personal/` and `~/git/work/` clones.

### Wave 0 Gaps

- [ ] `taskfiles/identity.yml` — new file housing `install`, `git`, `ssh`, `validate` tasks
- [ ] `install/resolver.zsh` — extended `validate_manifest()` with cross-field rules + expanded enum case-statement
- [ ] `manifests/test/fixtures/_invalid-identity-without-opssh/` — negative fixture (machine.toml with `identity.ssh = "personal"` and `one-password-ssh = false`)
- [ ] `manifests/test/fixtures/_invalid-identity-without-opsign/` — negative fixture (machine.toml with `identity.git = "personal"` and `one-password-signing = false`)
- [ ] `manifests/test/fixtures/_invalid-bad-identity/` — negative fixture (machine.toml with `identity.ssh = "alice"` to verify the enum check rejects unknown values)
- [ ] `taskfiles/manifest.yml` `manifest:test` — extend with the new negative fixtures (matches existing `_invalid-missing-desc` / `_invalid-bad-os` pattern)
- [ ] `identity/ssh/keys/.gitignore` — allowlist `*.pub` (belt-and-braces for IDNT-06)
- [ ] `identity/README.md` — replace P1 stub
- [ ] `docs/MANIFEST.md` — schema reference updates: identity enum + `one-password-signing` row

## Sources

### Primary (HIGH confidence)

- [Git documentation: git-config](https://git-scm.com/docs/git-config) — `includeIf`, `gitdir:`, `gitdir/i:`, trailing slash, path resolution, missing-file silent ignore
- [OpenBSD ssh_config(5)](https://man.openbsd.org/ssh_config) — `Include`, `IdentityAgent`, `IdentitiesOnly`, `IdentityFile`, `Match`, first-match-wins precedence
- [Linux man pages ssh_config(5)](https://www.man7.org/linux/man-pages/man5/ssh_config.5.html) — cross-reference for `Include` relative-path resolution to `~/.ssh`
- Existing repo files (`shell/.zprofile`, `git/config-*`, `ssh/configs/config-*`, `taskfiles/manifest.yml`, `taskfiles/links.yml`, `taskfiles/helpers.yml`, `install/resolver.zsh`, `manifests/defaults.toml`, `manifests/machines/*.toml`) — verified directly via Read tool
- CONTEXT.md and DISCUSSION-LOG.md for Phase 4 — all locked decisions (D-01..D-16) and carried-forward items (CF-01..CF-10)

### Secondary (MEDIUM confidence)

- [1Password Developer docs: SSH agent](https://www.1password.dev/ssh/agent/) — confirmed `IdentityAgent` directive usage; specific socket path not published officially but consistently documented across community sources
- [1Password Developer docs: SSH commit signing](https://developer.1password.com/docs/ssh/git-commit-signing/) — `op-ssh-sign` path and `gpg.ssh.program` configuration pattern
- [Ken Muse: Automatic SSH Commit Signing With 1Password](https://www.kenmuse.com/blog/automatic-ssh-commit-signing-with-1password/) — confirms `op-ssh-sign` binary location
- [zivkan.com: Multiple git configs](https://www.zivkan.com/blog/multiple-git-configs/) — trailing-slash and case-sensitivity practical guidance
- [Linux Audit: SSH IdentityAgent option](https://linux-audit.com/ssh/config/client/option-identityagent/) — IdentityAgent precedence over SSH_AUTH_SOCK

### Tertiary (LOW confidence -- cross-verified above)

- [Sublime Merge issue #271: includeIf missing file](https://github.com/sublimehq/sublime_merge/issues/271) — corroborates "git CLI silently ignores missing include files" claim
- [yayimorphology.org: Managing several SSH identities](https://yayimorphology.org/ssh-identities-made-easy.html) — IdentitiesOnly + IdentityFile interaction
- [1Password Community: SSH Integration discussions](https://www.1password.community/) — socket path verification

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH -- All dependencies are already installed and version-locked by Phase 0/1/2. No new tools.
- Architecture: HIGH -- CONTEXT.md locks every architectural decision. Verified semantics for gitdir/i, ssh Include, IdentityAgent precedence.
- Pitfalls: HIGH -- Pitfalls 1-5 are direct mappings from CONTEXT.md domain section. Pitfalls 6-10 are derived from git/ssh documentation cross-references plus existing repo conventions. Pitfall 5 (the "none" case) is the most novel — flagged in Open Questions for planner attention.
- Cross-field validation rules: HIGH -- Mechanism (`validate_manifest` function in `install/resolver.zsh`) mirrors existing fixture-tested patterns.
- 1Password socket detection: MEDIUM -- Path is well-established by community + repo usage but never published officially by 1Password as a "stable API." The `.zprofile` already takes the same bet; Phase 4 doesn't deepen the risk.

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (30 days for stable git/ssh/1Password landscape; revisit if 1Password ships a v9 with different agent paths)
