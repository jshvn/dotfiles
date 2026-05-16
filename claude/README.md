# claude/

Claude Code configuration for this dotfiles repo. All content under `claude/`
is symlinked into `~/.config/claude/` by `task links:all` (Phase 6). The
directory is split into two ownership tiers: files hand-authored in this repo
and runtime artifacts deployed by the GSD installer.

## Ownership Map

| Path | Owner | How it gets there |
|------|-------|-------------------|
| `claude/CLAUDE.md` | Repo | Committed; symlinked as a file |
| `claude/settings.json` | Repo | Committed; symlinked as a file |
| `claude/hooks/post-compact.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/agent-transparency.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/secret-scan.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/block-destructive.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/no-ai-comments.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/no-emojis.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/notify.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/lib.zsh` | Repo | Committed; symlinked as a file |
| `claude/hooks/hooks.json` | Repo | Committed; symlinked as a file |
| `claude/hooks/gsd-*` | GSD-managed | Written at runtime by `npx get-shit-done-cc` |
| `claude/agents/gsd-*.md` | GSD-managed | Written at runtime by `npx get-shit-done-cc` |
| `claude/commands/gsd-*` | GSD-managed | Written at runtime by `npx get-shit-done-cc` |
| `claude/skills/gsd-*/` | GSD-managed | Written at runtime by `npx get-shit-done-cc` |
| `claude/agents/` | Dir symlink | Repo dir; GSD writes through at install time |
| `claude/commands/` | Dir symlink | Repo dir; GSD writes through at install time |
| `claude/skills/` | Dir symlink | Repo dir; GSD writes through at install time |

GSD-managed paths are excluded from git via `.gitignore` (the four patterns at
the bottom of `.gitignore` prevent runtime artifacts from being committed by
accident):

```
claude/agents/gsd-*.md
claude/commands/gsd-*
claude/skills/gsd-*/
claude/hooks/gsd-*
```

## Symlink Shape (D-01)

The `taskfiles/links.yml` `claude:` sub-task creates 13 symlinks:

| Count | Type | From (repo) | To (live config) |
|-------|------|-------------|-----------------|
| 2 | File | `claude/CLAUDE.md`, `claude/settings.json` | `~/.config/claude/{CLAUDE.md,settings.json}` |
| 8 | File | `claude/hooks/{post-compact,agent-transparency,secret-scan,block-destructive,no-ai-comments,no-emojis,notify,lib}.zsh` + `hooks.json` | `~/.config/claude/hooks/*` |
| 3 | Dir | `claude/{agents,commands,skills}` | `~/.config/claude/{agents,commands,skills}` |

Hooks use per-file symlinks (not a directory symlink) because GSD writes peer
`gsd-*` files into `~/.config/claude/hooks/` at install time. Per-file
symlinks let the repo own its named files while GSD writes beside them in the
same live directory.

## Task Entry Points

| Task | When to run |
|------|-------------|
| `task claude:install` | Initial install (idempotent; re-run is safe) |
| `task claude:update` | Explicit refresh of marketplaces, plugins, and GSD |
| `task claude:status` | Diagnostic: show installed marketplaces and plugins |
| `task claude:validate` | State check: check/cross for all components |

`task claude:install` is gated on `features.claude-marketplace` in
`manifests/defaults.toml`. Machines with `claude-marketplace = false`
(e.g., `manifests/machines/server-1.toml`) skip the install step entirely.

`task claude:update` is NOT in the `task install` call graph. It is an
explicit refresh command -- run it when you want fresh GSD artifacts,
updated marketplace indexes, or updated plugins.

## GSD Sentinel (CLDE-03)

`task claude:gsd` installs `get-shit-done-cc` via:

```
npx -y get-shit-done-cc@latest --claude --global
```

Idempotency is gated on a presence sentinel at:

```
$XDG_STATE_HOME/dotfiles/gsd-installed
```

`npx` runs only when the sentinel is absent. After a successful install, the
sentinel is touched. To force a re-install without running a full
`task claude:update`, delete the sentinel manually:

```
rm -f "$XDG_STATE_HOME/dotfiles/gsd-installed"
task claude:gsd
```

## Hooks

The seven repo-owned hooks plus `lib.zsh` live in `claude/hooks/`. Their
wiring is declared in `claude/hooks/hooks.json` (canonical hook registry).

| Hook | Event | Behavior |
|------|-------|----------|
| `post-compact.zsh` | SessionStart (compact) | Re-injects git context after compaction |
| `agent-transparency.zsh` | PreToolUse (Agent) | Logs subagent dispatch decisions |
| `secret-scan.zsh` | PreToolUse (Write/Edit) | Blocks writes containing secrets |
| `block-destructive.zsh` | PreToolUse (Bash) | Blocks destructive shell commands |
| `no-ai-comments.zsh` | PostToolUse (Write/Edit/Bash) | Warns on AI attribution |
| `no-emojis.zsh` | PostToolUse (Write/Edit) | Warns on emojis in code files |
| `notify.zsh` | Notification | macOS desktop notification |

All hook scripts declare `set -euo pipefail` and use GNU grep (`ggrep`) per
LINT-04 and CLDE-02. Exit 0 = pass or warn; exit 2 = block (gate-style hooks).

## How to Add a Hook

1. Create `claude/hooks/<name>.zsh`. Include a file-header comment block
   naming the hook's purpose, exit-code semantics, and an example
   synthetic-input JSON. Declare `set -euo pipefail`.
2. Add a matching entry to `claude/hooks/hooks.json` (event, matcher, command
   path using `$XDG_CONFIG_HOME/claude/hooks/<name>.zsh`).
3. Add a per-file symlink entry to the `claude:` sub-task in
   `taskfiles/links.yml` and add the corresponding `_:check-link` invocation
   in `links:validate`.
4. If the hook is gate-style (exits 2 on block), add a smoke-test fixture
   to `install/test-hooks.zsh` (TEST-01).

## Feature Gate Reference

The `features.claude-marketplace` flag in `manifests/defaults.toml` (default
`true`) controls whether `task claude:install` runs at all. Machines that set
`claude-marketplace = false` in their machine TOML skip the Claude install
step entirely. Consuming tasks use the index form for kebab-case feature keys:

```
{{if index .MANIFEST.features "claude-marketplace"}}
```

See `manifests/defaults.toml` and `taskfiles/claude.yml` for the canonical
implementation.
