---
phase: "07"
plan: "06"
subsystem: links
tags: [links, symlinks, claude, configs, taskfiles]
dependency_graph:
  requires: [07-02, 07-03, 07-05]
  provides: [links:claude, links:configs, links:all-extended, links:validate-strict]
  affects: [taskfiles/links.yml, task-install-callgraph]
tech_stack:
  added: []
  patterns:
    - go-template feature gating via index .MANIFEST.features in cmds: and status: blocks
    - conditional no-op status pattern for feature-gated tasks on servers
    - strict-mode _:check-link with SOURCE for readlink -f equality verification
key_files:
  created: []
  modified:
    - taskfiles/links.yml
decisions:
  - Retrofit existing P3/P4 validate: entries with SOURCE arg for uniform strict-mode coverage
  - Ghostty status block uses conditional no-op shape; other 6 configs entries use plain test -L
  - validate: deps: not added (diagnostic task always reruns; no status: by design)
metrics:
  duration: "10m"
  completed: "2026-05-16"
  tasks_completed: 3
  files_modified: 1
---

# Phase 7 Plan 6: Links Integration Summary

`taskfiles/links.yml` extended with `claude:` and `configs:` sub-tasks that deploy 20 new symlinks via `_:safe-link`, wired into the `all:` aggregator and a strict-mode `validate:` task covering all 26 P3+P4+P7 symlinks with SOURCE-passing `_:check-link` calls.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add claude: sub-task | 8bbf28c | taskfiles/links.yml |
| 2 | Add configs: sub-task | 7487a50 | taskfiles/links.yml |
| 3 | Extend all: aggregator + validate: | f111729 | taskfiles/links.yml |

## What Was Built

### Task 1: `claude:` sub-task

Added after `antidote:`, before `validate:`. Deploys 13 symlinks:

- 2 file symlinks: `claude/CLAUDE.md`, `claude/settings.json`
- 3 directory symlinks: `claude/agents`, `claude/commands`, `claude/skills`
- 8 hook file symlinks: `post-compact.zsh`, `agent-transparency.zsh`, `secret-scan.zsh`, `block-destructive.zsh`, `no-ai-comments.zsh`, `no-emojis.zsh`, `notify.zsh`, `lib.zsh`

Gate: `{{if index .MANIFEST.features "claude-marketplace"}}` wraps the entire cmds: body. Servers with `claude-marketplace = false` skip the body. The status: block uses the conditional no-op pattern so server status checks also pass without requiring the symlinks to exist.

### Task 2: `configs:` sub-task

Added after `claude:`, before `validate:`. Deploys 7 symlinks:

- ghostty/config (gated on `features.ghostty`)
- glow/glow.yml, glow/glow_style.json (always-on)
- trippy/trippy.toml (always-on)
- tlrc/config.toml (always-on; renamed from v1 `tlrc.toml`)
- conda/condarc (always-on)
- eza/theme.yaml (always-on; renamed from v1 `eza_style.yaml`)

motd intentionally absent per D-08 (runtime read from `${DOTFILEDIR}/configs/motd/`).

### Task 3: `all:` + `validate:` extensions

`all:` aggregator gained `task: claude` and `task: configs` entries, making these sub-tasks part of the `task install` call graph.

`validate:` retrofitted and extended:
- Existing 6 P3/P4 entries (zsh x5, antidote x1) gained SOURCE args for strict-mode verification
- 13 new claude entries added, each wrapped in `{{if index .MANIFEST.features "claude-marketplace"}}`
- 6 always-on configs entries added with SOURCE
- 1 ghostty entry added wrapped in `{{if index .MANIFEST.features "ghostty"}}`
- Total: 26 `_:check-link` invocations, all passing SOURCE

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all symlink entries are wired to real source files delivered by Plans 02/03/05.

## Threat Flags

None — all new network surface is nil (symlinks only; no new network endpoints, auth paths, or schema changes).

## Self-Check: PASSED

- taskfiles/links.yml modified: FOUND
- Commit 8bbf28c (Task 1): FOUND
- Commit 7487a50 (Task 2): FOUND
- Commit f111729 (Task 3): FOUND
- 26 _:safe-link invocations: CONFIRMED
- 26 _:check-link invocations: CONFIRMED
- YAML parses: CONFIRMED (`task --list-all --json` exits 0)
- LINT-02 on links.yml: PASSED (green checkmark in task lint output)
