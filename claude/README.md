# claude

Claude Code integration: project-level `CLAUDE.md`, machine-level
`settings.json`, and the per-purpose subdirectories `hooks/`, `agents/`,
`commands/`, `skills/`. Sourced by `task claude:install` once Phase 7
(CLDE-01) ships the real task body. The hooks enforce repo-wide rules at
commit/edit time (no secrets in source, no AI attribution in commits, no
emojis in non-markdown files, agent-transparency logging). Phase 7 owns
the install task plus runtime smoke tests (TEST-01).

## Key subdirectories

- `hooks/` -- Repo-wide commit/edit-time guards. Four hook scripts:
  `secret-scan.zsh` (blocks committing `.env`-style files and API
  tokens), `no-emojis.zsh` (warns on emojis -- the project rule extends
  to markdown too), `no-ai-comments.zsh` (warns on AI-attribution
  trailers and source-code attribution markers),
  `agent-transparency.zsh` (logs subagent dispatch decisions). All
  hook scripts must pass `shellcheck` clean and declare `set -euo
  pipefail` per CLDE-02 + LINT-04. Runtime synthetic-input smoke tests
  land in Phase 7 (TEST-01).
- `agents/` -- Subagent role-files. Each agent declares its purpose,
  tool allowlist, and optional model preference in frontmatter.
  Selection happens per-task; the orchestrator chooses based on the
  user's request.
- `commands/` -- Slash commands available in Claude Code (`/gsd-*`,
  custom workflow commands). Each command is a markdown file with
  frontmatter (tool allowlist, model preference) plus the prompt body.
- `skills/` -- Per-domain skill files surfaced when the active task
  matches the skill's triggers.
- `CLAUDE.md` -- Project-level instructions Claude Code reads on every
  session. Currently still references v1's `DOTFILES_PROFILE`; Plan
  03-08 retires those references in favour of the manifest model.
- `settings.json` -- Per-user Claude Code settings (model preferences,
  hook timeouts, etc.).

## Adding a pattern

- **A new hook.** Create `claude/hooks/<name>.zsh`. Start with shebang
  plus `set -euo pipefail` (LINT-04). Add a file-header comment block
  naming purpose, exit-code semantics (0 for pass/warn, 2 for block),
  and an example synthetic-input JSON the hook handles. Add a matching
  entry to `claude/hooks/hooks.json` declaring the events (PreToolUse,
  PostToolUse, PreCommit, etc.). Phase 7 (TEST-01) auto-extends the
  `task test:hooks` smoke suite to pipe synthetic JSON through the new
  hook and assert exit code + stderr pattern.
- **A new agent.** Create `claude/agents/<name>.md` with frontmatter
  (`description`, `tools`, optional `model`). Agent definitions are
  picked up by Claude Code on session start; no registration step.
- **A new slash command.** Create `claude/commands/<name>.md` (or
  `claude/commands/<namespace>/<name>.md`) with the prompt body in
  the file body. Frontmatter declares the tool allowlist and model
  preference.

## Phase ownership

Plan 03-07 writes this README to close the DOCS-02 contract for
`claude/`. Phase 7 owns the install path (CLDE-01..CLDE-04), the hook
smoke tests (TEST-01), and the `task claude:install` /
`task claude:gsd` / `task claude:marketplace` task implementations.
The taskfile is still a stub (`../taskfiles/claude-stub.yml`) at the
end of Phase 3; the real `taskfiles/claude.yml` lands with Phase 7.

## References

- `CLAUDE.md` -- project-level Claude instructions (currently stale;
  Plan 03-08 cleans up the v1 profile references).
- `../.planning/REQUIREMENTS.md` -- CLDE-01..CLDE-04, TEST-01,
  TEST-02, DOCS-02 traceability.
- `../.planning/ROADMAP.md` Phase 7 -- the claude install + tool
  configs + smoke tests phase.

Satisfies DOCS-02 for claude/.
