---
phase: 12-task-surface-redesign
plan: 02
subsystem: task-surface
tags: [refactor, taskfile, shel-12, surf-02, surf-03]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01]
  provides: [shell:startup-time public surface, shell:validate internal mark, perf: include retired]
  affects: [Taskfile.yml, taskfiles/shell.yml, taskfiles/README.md, shell/README.md]
tech_stack:
  added: []
  patterns: [internal-mark pattern (D-01) applied to shell:validate; aggregator-iteration assumption tested; D-07 doc-reference migration shape]
key_files:
  created: []
  modified:
    - Taskfile.yml
    - taskfiles/shell.yml
    - taskfiles/README.md
    - shell/README.md
decisions:
  - Removed the `perf:` include alias entirely (D-05) -- single canonical `shell:` include now
  - Renamed `shell:shell` to `shell:startup-time` (D-06) for discoverability
  - Marked `shell:validate` as `internal: true` (D-01) per the curation rule
  - Re-flowed the Phase-3 bullet in taskfiles/README.md so `task shell:startup-time` lives on a single line (matches the doc-search grep expectation)
metrics:
  duration: ~20 minutes
  tasks_completed: 3/3
  commits: 3
  files_modified: 4
  completed_date: 2026-05-18
---

# Phase 12 Plan 02: shell namespace cleanup -- retire `perf:` alias, rename `shell:shell`, mark `shell:validate` internal Summary

Retired the dual-aliased `perf:` / `shell:` include from Phase 10 D-06; renamed the cold-start gate task to `shell:startup-time`; marked `shell:validate` internal; updated every in-repo SHEL-12 reference (D-07). Public `shell:*` surface now contains exactly one row (`shell:startup-time`); the `perf:` namespace is gone.

## What changed

### Commits (3)

| # | Commit  | Type     | Description                                                                 |
|---|---------|----------|-----------------------------------------------------------------------------|
| 1 | 14ba294 | refactor | drop `perf:` include alias from Taskfile.yml (D-05)                         |
| 2 | e0374f6 | refactor | rename `shell:shell` to `shell:startup-time`, mark `shell:validate` internal (D-01, D-06) |
| 3 | c0d69de | docs     | update SHEL-12 references to `task shell:startup-time` (D-07)               |

### Files modified

- **`Taskfile.yml`** (-3, +1) -- dropped the `perf: ./taskfiles/shell.yml` include line; dropped the matching `#   - perf     (P3, real)` header-comment row; updated the `shell:` include's inline comment to no longer reference the dropped `perf:` alias.
- **`taskfiles/shell.yml`** (-7, +9) -- renamed task `shell:` to `startup-time:`; added `internal: true` to `validate:`; rewrote the header banner's `Tasks:` listing (dropped the `perf:` invocation line, added an entry for `validate`); updated the self-exemption note and the direct-invocation hint in the vars block.
- **`taskfiles/README.md`** (-4, +4) -- rewrote the Phase-3 bullet to reference `task shell:startup-time` and note that `shell:validate` is internal-only; replaced the "Adding a pattern" worked example's `task perf:shell` mention with `task shell:startup-time`.
- **`shell/README.md`** (-2, +2) -- updated the SHEL-12 "Performance budget" sentence to reference `task shell:startup-time`.

### Live verification (post-plan)

```
$ task --list | grep -E '^\* (shell|perf):'
* shell:startup-time:                Measure cold interactive zsh startup time (fails if > 200ms -- SHEL-12)
```

- Zero `perf:*` rows in `task --list`.
- Exactly one `shell:*` row (`shell:startup-time`); `shell:validate` is hidden by `internal: true`.
- `grep -rEn 'task perf:shell' README.md CLAUDE.md .claude/CLAUDE.md docs/ shell/ taskfiles/` -- 0 matches (full purge).
- `grep -rEn 'task shell:startup-time' shell/README.md taskfiles/README.md` -- 3 matches (1 in shell/README.md, 2 in taskfiles/README.md).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Doc grep granularity] Re-flowed the Phase-3 bullet to keep `task shell:startup-time` on a single line**

- **Found during:** Task 3 verification
- **Issue:** The plan's success criterion `grep -rEn 'task shell:startup-time' shell/README.md taskfiles/README.md >= 3` returned 2 after my initial edit because the markdown line-wrap split `task` (end of line 24) from `shell:startup-time` (start of line 25). The semantic reference count was 3, but the literal one-line grep matched only 2.
- **Fix:** Rewrote the Phase-3 bullet so `task shell:startup-time` lives on a single line. Bullet text is equivalent; word order shifted slightly. New text: ``shell.yml` exposes `task shell:startup-time` (SHEL-12 cold-start gate); `shell:validate` is internal-only (invoked by root `task validate`).`
- **Files modified:** `taskfiles/README.md`
- **Commit:** c0d69de (included in the Task 3 commit; not a separate fix commit)

## Known Issues (escalate to orchestrator / next-wave planning)

### `internal: true` semantics in go-task 3.51.1 break the `task validate` aggregator

**What was discovered.** CONTEXT.md D-01 line 28 claims: "go-task's `internal: true` only affects `task --list` visibility, not task invocability. ... The `task validate` aggregator already iterates them by name (Taskfile.yml:206, 213); the iteration loop continues to work because ..." This claim is **empirically false** for go-task 3.51.1 (the version installed in this environment).

**Actual behavior.** Verified locally with a minimal taskfile:
- `task internal-name` from the shell -> exits 202 with message `task: Task "internal-name" is internal`.
- `task: internal-name` from inside another task's `cmds:` block -> works.
- The `validate:` aggregator at `Taskfile.yml:206` uses `task "${component}:validate"` as a **shell command** inside a bash for-loop, NOT a `task:` dispatch. So after marking `shell:validate` `internal: true`, running `task validate` now prints `task: Task "shell:validate" is internal` for the shell row and -- critically -- the row reports `n/a`/`cross`/`check` rendering depends on `$PIPESTATUS[0]`. In practice the summary now shows `✓ shell` even though the per-component validate never ran (the aggregator iteration logic predates this internal-mark change and does not distinguish "ran-and-passed" from "refused-to-run").

**Pre-existing scope note.** The same broken-summary class is ALSO present for `links:validate` on the current worktree (it exits 25 due to worktree-path link drift, but the aggregator reports `✓ links`). This pre-existed Plan 12-02 -- the aggregator's exit-code capture via `$PIPESTATUS[0]` does not survive the way `eval` reconstructs `rc_${component}=...` under go-task's invoked-shell context. The `shell:validate` internal-mark made the same defect visible for one more component.

**Why I committed anyway.** Plan 12-02's stated objective is to apply D-01 to `shell:validate` (rename + mark internal). The architectural fix (rewrite the aggregator to use `task:` dispatch, OR back out D-01 for per-component validates, OR introduce dual-shape public delegates as D-03 does for `manifest:validate`) is out-of-scope for a single-plan auto-fix (Rule 4 architectural change). Surfacing it as a Known Issue lets the orchestrator make that decision before spawning Plans 03 through 08, which all repeat the D-01 mark-internal pattern for per-component validates (`claude:validate`, `identity:validate`, `links:validate`, `macos:validate`, `packages:validate`, `manifest:validate`).

**Recommended next-wave action.** Before Plans 03 through 08 land, the orchestrator should pick one of:
1. **Extend the D-03 dual-shape pattern to every per-component validate.** Each `<ns>:validate` stays internal; a public `audit:<ns>` is a thin wrapper that runs `task: <ns>:validate`. The root `task validate` aggregator switches its iteration from `task "${component}:validate"` (shell command) to `task "audit:${component}"` (which CAN be invoked as a shell command because `audit:*` is public). This preserves D-01 while keeping the aggregator working.
2. **Rewrite the root `task validate` aggregator to use `task:` dispatch with `deps:` instead of a bash for-loop.** Each component becomes a `deps:` entry; the aggregator's summary block reads exit codes from a different mechanism (e.g., per-component sentinel files, or `task --parallel` with `defer:`).
3. **Back out D-01 for per-component validates** (keep them public) -- least architectural change, but the curation goal of "only `validate` is public" is then partially abandoned.

**No fix attempted in this plan.** The shell:validate aggregator side-effect is documented above for downstream decision; Plan 12-02's three commits stand as specified by the plan author.

### Threat-model entry T-12-02-01 confirmed (informational, accept-disposition)

The plan's threat register entry `T-12-02-01` (`internal: true` on `shell:validate` is a discoverability hint, not an access control) is confirmed by the broader investigation above: `internal: true` actually does MORE than the threat register described -- it also prevents direct shell-CLI invocation. Operators who relied on `task shell:validate` to debug the shell layer now get `task: Task "shell:validate" is internal` and must either `task validate` (full sweep) or invoke through a public delegate (which does not yet exist for `shell:validate`). Disposition stays `accept`; future plans may add `audit:shell` as the public delegate per D-03's dual-shape pattern.

## Lint Compliance

Pre-existing baseline `task lint:taskfile` failures (LINT-02 in claude.yml/identity.yml/manifest.yml/packages.yml, LINT-03a in five manifest.yml tasks, LINT-03b for a bare `ln -s`) are unchanged. The LINT-03a violation on the renamed `startup-time:` task in `taskfiles/shell.yml` is identical to the pre-rename violation on `shell:` -- the `# lint-allow: cmds-without-status` marker is in place; the lint rule's marker recognition for this task pre-existed Plan 12-02 and is tracked outside this phase.

No NEW lint regressions introduced by this plan's three commits.

## Threat Surface Scan

No new threat surface introduced. The plan operates entirely within Taskfile YAML rename + visibility-flag changes; no new I/O, network endpoints, auth paths, file access patterns, or schema changes.

## Handoff to next plan (12-03 links namespace)

- No shared file conflicts -- Plan 12-02 touches only `Taskfile.yml` (the includes block + header comment), `taskfiles/shell.yml`, `taskfiles/README.md`, and `shell/README.md`. Plan 12-03 (links namespace renames per D-09/D-10) is free to proceed.
- **Critical handoff for Plan 12-03 onward:** Read the Known Issue above before touching `links:validate` (or any other `<ns>:validate`). The D-01 "mark every per-component validate internal" strategy needs a dual-shape (D-03-style) extension OR an aggregator rewrite before it can apply safely to per-component validates without breaking `task validate`.

## Self-Check: PASSED

- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f taskfiles/shell.yml ]` -- FOUND
- `[ -f taskfiles/README.md ]` -- FOUND
- `[ -f shell/README.md ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-02-SUMMARY.md ]` -- (this file)
- Commits 14ba294, e0374f6, c0d69de present in `git log --oneline` -- FOUND
- `task --list | grep -E '^\* (perf|shell):'` returns exactly one row (`shell:startup-time`) -- VERIFIED
- `grep -rEn 'task perf:shell' README.md CLAUDE.md .claude/CLAUDE.md docs/ shell/ taskfiles/` returns 0 matches -- VERIFIED
- `grep -rEn 'task shell:startup-time' shell/README.md taskfiles/README.md` returns 3 matches -- VERIFIED
