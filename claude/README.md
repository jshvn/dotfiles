# claude/

Claude Code configuration for this dotfiles repo. All content under `claude/`
is symlinked into `~/.config/claude/` by `task links:all`.

## Ownership Map

Every file in this directory is repo-owned and committed.

| Path | How it gets there |
|------|-------------------|
| `claude/CLAUDE.md` | Committed; symlinked as a file |
| `claude/settings.json` | Committed; symlinked as a file |
| `claude/hooks/post-compact.zsh` | Committed; symlinked as a file |
| `claude/hooks/agent-transparency.zsh` | Committed; symlinked as a file |
| `claude/hooks/secret-scan.zsh` | Committed; symlinked as a file |
| `claude/hooks/block-destructive.zsh` | Committed; symlinked as a file |
| `claude/hooks/no-ai-comments.zsh` | Committed; symlinked as a file |
| `claude/hooks/no-emojis.zsh` | Committed; symlinked as a file |
| `claude/hooks/notify.zsh` | Committed; symlinked as a file |
| `claude/hooks/lib.zsh` | Committed; symlinked as a file |
| `claude/hooks/hooks.json` | Committed; symlinked as a file |
| `claude/agents/` | Committed; symlinked as a directory |
| `claude/commands/` | Committed; symlinked as a directory |
| `claude/skills/` | Committed; symlinked as a directory |

## Symlink Shape

The `taskfiles/links.yml` `claude:` sub-task creates per-file symlinks for
`CLAUDE.md`, `settings.json`, and each file under `hooks/`, plus directory
symlinks for `agents/`, `commands/`, and `skills/`.

| Count | Type | From (repo) | To (live config) |
|-------|------|-------------|------------------|
| 2 | File | `claude/CLAUDE.md`, `claude/settings.json` | `~/.config/claude/{CLAUDE.md,settings.json}` |
| 8 | File | `claude/hooks/{post-compact,agent-transparency,secret-scan,block-destructive,no-ai-comments,no-emojis,notify,lib}.zsh` + `hooks.json` | `~/.config/claude/hooks/*` |
| 3 | Dir | `claude/{agents,commands,skills}` | `~/.config/claude/{agents,commands,skills}` |

## Task Entry Points

| Task | When to run |
|------|-------------|
| `task claude:install` | First-time install + every-run upgrade (called by `task install`) |
| `task claude:status` | Diagnostic: show installed marketplaces and plugins |
| `task claude:validate` | State check: check/cross for all components |

`task claude:install` is gated on `features.claude-marketplace` in
`manifests/defaults.toml`. Machines with `claude-marketplace = false`
(e.g., `manifests/machines/atium.toml`) skip the install step entirely.

There is no separate update path. Every `task install` invocation runs
the internal `claude:upgrade` step (`claude plugin marketplace update`
+ `claude plugin update <id>`) so marketplaces and plugins are always
pulled to latest.

## Hooks

The seven repo-owned hooks plus `lib.zsh` live in `claude/hooks/`. Their
wiring is declared in `claude/settings.json` under the `hooks` block.
`claude/hooks/hooks.json` is kept as a parallel canonical registry, but
`settings.json` is what Claude Code actually reads.

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
2. Add a matching entry to both `claude/settings.json` (the live config)
   and `claude/hooks/hooks.json` (the canonical registry), wiring it to
   the appropriate event and matcher.
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
