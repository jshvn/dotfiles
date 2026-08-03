# claude/

Claude Code configuration for this dotfiles repo. All content under `claude/`
is symlinked into `~/.config/claude/` by `task links:install`.

**Canonical references:**
- [`../docs/CLAUDE-ADDONS.md`](../docs/CLAUDE-ADDONS.md) -- full operator
  reference for third-party addons + settings.d composition.
- [`../CLAUDE.md`](../CLAUDE.md) -- project instructions (see the Gotchas
  bullets on the source-only repo tree and declarative addons).

## Ownership Map

Every path in this directory is repo-owned, committed, hand-authored source.
The composed `settings.json` is not here: it is built into
`$XDG_STATE_HOME/dotfiles/build/settings.json` and installed from there onto
`~/.config/claude/settings.json` as a real file.

| Path | Role | How it gets there |
|------|------|-------------------|
| `claude/CLAUDE.md` | Source | Committed; symlinked as a file |
| `claude/settings.d/00-base.json` | Source | Permissions + top-level scalars; merged by compose |
| `claude/settings.d/10-hooks.json` | Source | Repo hook wiring; merged by compose |
| `claude/hooks/*.zsh` | Source | Hook scripts; symlinked individually as files |
| `claude/agents/`, `claude/commands/`, `claude/skills/` | Source | Symlinked as directories |

## Symlink Shape

The `taskfiles/links.yml` `claude:` sub-task creates per-file symlinks for
`CLAUDE.md` and each `.zsh` under `hooks/`, plus directory symlinks for
`agents/`, `commands/`, `skills/`. Two paths are deliberately absent: the
`settings.d/` fragments (compose reads them in place) and `settings.json`
(`claude:activate` installs it as a real file, so the CLI's writes land in
the live config rather than in tracked source).

| Type | From (repo) | To (live config) |
|------|-------------|------------------|
| File | `claude/CLAUDE.md` | `~/.config/claude/CLAUDE.md` |
| File | every `claude/hooks/*.zsh`, `lib.zsh` included | `~/.config/claude/hooks/*` |
| Dir | `claude/{agents,commands,skills}` | `~/.config/claude/{agents,commands,skills}` |

## Task Entry Points

| Task | When to run |
|------|-------------|
| `task claude:install` | First-time install + every-run; ensures CLI present, recomposes the settings.json artifact, and installs it live (called by `task install`) |
| `task claude:show` | Diagnostic: show installed marketplaces and plugins |
| `task claude:audit` | Drift detection: live settings.json vs the composed artifact |
| `task claude:validate` | State check: CLI presence + the audit drift check |
| `task claude-addons:install` | Iterate `[claude].addons`, install/upgrade each, drop fragments into `$XDG_STATE_HOME/dotfiles/settings.d/`, recompose |
| `task claude-addons:remove -- <name>` | Run remove.commands, walk file_globs, drop fragment, recompose |
| `task claude-addons:show` | Diagnostic table: Name | Enabled | Installed |
| `task claude-addons:audit` | Drift detection: orphan footprints from non-enabled addons |

`task claude:install` and `task claude-addons:install` are gated on the
`claude-marketplace` feature (declared in `manifests/features.toml`). Machines
that leave `claude-marketplace` out of their `[features] enabled` list skip
both.

## Settings Composition

`task claude:settings-compose` builds
`$XDG_STATE_HOME/dotfiles/build/settings.json` from:

1. **Repo-owned fragments** in `claude/settings.d/`, deep-merged in numeric
   order:
   - `00-base.json` -- permissions, agentPushNotifEnabled, effortLevel
   - `10-hooks.json` -- hook wiring (the canonical declaration)
2. **Machine fragments** in `$XDG_STATE_HOME/dotfiles/settings.d/`, merged
   after the repo's: `99-addon-<name>.json` for each enabled addon with a
   paired fragment.
3. **Preserved CLI-managed keys** read from the live settings.json:
   - `enabledPlugins`
   - `extraKnownMarketplaces`
   - `model` (only when present)
   - `tui` (only when present)
   The first two are written by `claude plugin install`/`claude plugin
   marketplace add`, `model` by the `/model` command, `tui` by the
   fullscreen/inline toggle; none are owned by fragments.

Atomic write (mktemp + mv) into the build path, then `claude:activate`
installs it over `~/.config/claude/settings.json` the same way. Both run at
the end of `task claude:install` and `task claude-addons:install/remove`, so
any drift introduced by third-party installers is overwritten on the next
install.

`task claude:audit` reports drift between the live file and the artifact.

## Hooks

The repo-owned hooks plus `lib.zsh` live in `claude/hooks/`. Their
wiring is declared in `claude/settings.d/10-hooks.json` and merged into the
composed artifact. Edit `10-hooks.json`, never the live `settings.json`.

| Hook | Event | Behavior |
|------|-------|----------|
| `post-compact.zsh` | SessionStart (compact) | Re-injects git context after compaction |
| `agent-transparency.zsh` | PreToolUse (Agent) | Logs subagent dispatch decisions |
| `secret-scan.zsh` | PreToolUse (Write/Edit/Bash) | Blocks writes/commands containing secrets |
| `block-destructive.zsh` | PreToolUse (Bash) | Blocks destructive shell commands |
| `no-ai-comments.zsh` | PostToolUse (Write/Edit/Bash) | Warns on AI attribution |
| `no-emojis.zsh` | PostToolUse (Write/Edit) | Warns on emojis in code files |
| `notify.zsh` | Notification | macOS desktop notification |
| `auto-approve-reads.zsh` | PreToolUse (Bash) | Auto-approves provably read-only Bash commands (skips the prompt) |

All hook scripts declare `set -euo pipefail` and use GNU grep (`ggrep`) per
LINT-04. Exit 0 = pass or warn; exit 2 = block (gate-style hooks).

## How to Add a Repo-Owned Hook

1. Create `claude/hooks/<name>.zsh`. Include a file-header comment block
   naming the hook's purpose, exit-code semantics, and an example
   synthetic-input JSON. Declare `set -euo pipefail`.
2. Add a matching entry to `claude/settings.d/10-hooks.json` wiring it
   to the appropriate event and matcher.
3. Run `task install` to recompose and activate.
4. Add a per-file symlink entry to the `claude:` sub-task in
   `taskfiles/links.yml` and add the corresponding `_:check-link` invocation
   in `links:validate`.
5. If the hook is gate-style (exits 2 on block), add a smoke-test fixture
   to `install/tests/hooks.zsh` (TEST-01).

## How to Add a Third-Party Claude Addon

See [`../docs/CLAUDE-ADDONS.md`](../docs/CLAUDE-ADDONS.md) and
[`../manifests/claude-addons/README.md`](../manifests/claude-addons/README.md).
Short version: write `manifests/claude-addons/<name>.toml` (+ optional
`<name>.fragment.json`), add the name to the machine manifest's
`[claude].addons` array, run `task install`.

## Feature Gate Reference

The `claude-marketplace` flag (declared in `manifests/features.toml`) controls
whether `task claude:install` and `task claude-addons:install` run at all.
Machines that list `claude-marketplace` in their `[features] disabled` array
skip the Claude install path entirely. Consuming tasks use the index form for
kebab-case feature keys:

```
{{if index .MANIFEST.features "claude-marketplace"}}
```

See `manifests/features.toml` and `taskfiles/claude.yml` /
`taskfiles/claude-addons.yml` for the canonical implementations.
