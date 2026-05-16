---
phase: "07"
plan: "03"
subsystem: claude
tags: [taskfile, claude, gsd, sentinel, marketplace, idempotency]
dependency_graph:
  requires: [07-02]
  provides: [taskfiles/claude.yml, Taskfile.yml include flip, claude/README.md]
  affects: [task install, task claude:install, task claude:gsd, task claude:marketplace]
tech_stack:
  added: []
  patterns:
    - status-sentinel idempotency (GSD_SENTINEL touch-file)
    - two-condition marketplace status block
    - task-scoped sh: vars (W-01 pattern)
    - status: [false] for always-rerun aggregators (LINT-03a pattern)
key_files:
  created: []
  modified:
    - taskfiles/claude.yml
    - Taskfile.yml
    - claude/README.md
decisions:
  - "status: [false] used on install/update/status/validate aggregators for LINT-03a compliance (plan claimed comment-only exemption but lint.yml has no comment-based exemption mechanism)"
  - "Marketplace status block comments moved above the block to avoid LINT-02 false-positive on '$VAR' in comment text"
metrics:
  duration: "694s (~11 minutes)"
  completed: "2026-05-16"
  tasks_completed: 3
  files_modified: 3
---

# Phase 7 Plan 03: Claude Task Suite + Include Flip + README Summary

Phase-7 real `taskfiles/claude.yml` delivered with seven tasks, root Taskfile.yml include flipped from stub to real, and claude/README.md updated to document the post-D-02 GSD vs repo ownership split.

## What Was Built

**taskfiles/claude.yml** -- Phase-7 production task suite with seven tasks:

- `install`: Public aggregator gated on `features.claude-marketplace` via `index .MANIFEST.features "claude-marketplace"` (kebab-case index form). `status: [false]` for LINT-03a compliance. Sequences ensure-cli, marketplace, gsd.
- `marketplace`: Internal. Two-condition status block (marketplace list + plugin list jq probes). Task-scoped MARKETPLACES_JSON/PLUGINS_JSON (W-01). Status block uses go-template-rendered literal names with zero shell-var references (W-02/LINT-02 compliant).
- `gsd`: Internal. Sentinel-idempotent via `test -f {{.GSD_SENTINEL}}`. Runs `npx -y get-shit-done-cc@latest --claude --global` only when sentinel is absent; touches sentinel after success (T-07-12 mitigated: touch is AFTER npx).
- `update`: Public aggregator. Explicit refresh path (D-10/D-14) -- NOT in `task install`. `status: [false]`.
- `status`: Public diagnostic. `status: [false]` (always-rerun).
- `validate`: Public diagnostic with GSD sentinel check. `status: [false]`. Composed into root `task validate` in P8.
- `ensure-cli`: Internal gate. Hard-fails with `'task packages:install' first` message when claude or jq missing.

**Taskfile.yml**: Single-line flip from `./taskfiles/claude-stub.yml` to `./taskfiles/claude.yml`. claude-stub.yml preserved on disk for P8 cleanup.

**claude/README.md**: Ownership map (repo vs GSD-managed), symlink shape table (2 file + 8 per-file hook + 3 dir), four task entry points, GSD sentinel instructions, hook reference table, how-to-add-a-hook section.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Rewrite taskfiles/claude.yml with Phase 7 task suite | a0150bb |
| 2 | Flip root Taskfile.yml include from claude-stub to claude.yml | c83d40f |
| 3 | Update claude/README.md with post-D-02 ownership boundaries | afbb7b8 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] LINT-03a: plan's comment-based exemption doesn't exist in lint.yml**
- **Found during:** Task 1 verification (first draft)
- **Issue:** The plan states aggregator tasks carry `# lint-allow: cmds-without-status` on the line above the task name as the lint exemption mechanism. However, `taskfiles/lint.yml`'s LINT-03a check uses `yq` to find tasks with `cmds:` but no `status:` -- there is no code path that reads or acts on the comment. The only actual LINT-03a exemptions are `internal: true` and "all cmds are task: delegations."
- **Fix:** Applied `status: [false]` (always-rerun shape) to all four aggregator tasks: install, update, status, validate. This satisfies LINT-03a structurally (yq sees `has("status")` = true) while preserving always-rerun semantics.
- **Files modified:** taskfiles/claude.yml
- **Commit:** a0150bb

**2. [Rule 2 - LINT-02] Status block comment containing '$VAR' tripped lint**
- **Found during:** Task 1 verification (first draft)
- **Issue:** A comment inside the marketplace task's `status:` block contained the text `$VAR shell-var references`. The LINT-02 check uses `yq '.tasks[] | select(.status) | .status'` which extracts YAML content including comments; the grep for `$[A-Za-z_]` matched the comment text.
- **Fix:** Moved the explanatory comment to above the `status:` block (outside what yq extracts) and removed `$VAR` from the comment text inside the status block.
- **Files modified:** taskfiles/claude.yml
- **Commit:** a0150bb

## Verification Results

- `task --list-all --json -t taskfiles/claude.yml` exits 0 (YAML parses)
- `task --list-all --json` (root) exits 0 after Taskfile.yml flip
- All seven task names defined in taskfiles/claude.yml
- `task lint` claude.yml passes LINT-02 (no shell-var in status blocks) and LINT-03a (all tasks have status: or are internal)
- `Taskfile.yml` include points to real file; no claude-stub.yml reference remains
- W-01: file-level vars block contains only CLAUDE_MARKETPLACES, CLAUDE_PLUGINS, GSD_SENTINEL
- W-02: marketplace status block clean (yq extraction + grep returns zero matches)
- GSD_SENTINEL resolves to `{{.XDG_STATE_HOME}}/dotfiles/gsd-installed` (D-11)
- claude/README.md: 140 lines; ownership map, sentinel reference, feature-gate reference, four entry-point tasks documented

## Known Stubs

None. All plan deliverables are fully implemented.

## Threat Flags

No new security-relevant surfaces beyond those documented in the plan's threat model (T-07-10 through T-07-17).
