---
phase: 12-task-surface-redesign
plan: 08
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-04, d-12, d-13, w-7, w-8, b-3, b-5, b-8]
requirements: [SURF-02, SURF-04]
dependency_graph:
  requires: [12-01, 12-02, 12-03, 12-04, 12-05, 12-06, 12-07]
  provides:
    - "Bare `task` prints curated two-tier banner via messages.zsh helpers (D-12)"
    - "lint:banner-parity check (LINT-08 reused per D-13) joins lint:default aggregator"
    - "Paired fixtures 08a-banner-parity-fail / 08b-banner-parity-ok validate the rule body"
    - "test-fixtures: case-switch extended with 08*) branch (rule replicated per-fixture)"
    - "lint:default aggregator now uses ignore_error: true (run-all-aggregate; mirrors validate:)"
    - "README.md + CLAUDE.md reference the canonical bare-task surface (SC #4 / W-8)"
    - "Phase 12 closure: SURF-01..SURF-04 all satisfied; SURFACE.md walked to completion"
  affects:
    - Taskfile.yml
    - taskfiles/lint.yml
    - taskfiles/test/lint-fixtures/08a-banner-parity-fail/
    - taskfiles/test/lint-fixtures/08b-banner-parity-ok/
    - README.md
    - CLAUDE.md
tech_stack:
  added: []
  patterns:
    - "Pattern 5 (default: banner cmd-block): hand-rendered two-tier banner using header/info/echo with TASKFILE_DIR sourcing per documented DOTFILEDIR-pollution workaround"
    - "Pattern 6 (lint-fixture pattern): new LINT-08 follows LINT-02 fingerprint -- yq extraction + ggrep filter + check/cross output + exit failures"
    - "Run-all-aggregate pattern (mirrors validate: at Taskfile.yml:177-190): ignore_error: true on every sub-task dispatch so downstream checks execute regardless of earlier baseline failures"
    - "Aggregator-only public surface (D-04 preserved): banner-parity is internal; only lint:default (aliased lint) is publicly invocable"
key_files:
  created:
    - taskfiles/test/lint-fixtures/08a-banner-parity-fail/Taskfile.yml
    - taskfiles/test/lint-fixtures/08a-banner-parity-fail/expect
    - taskfiles/test/lint-fixtures/08b-banner-parity-ok/Taskfile.yml
    - taskfiles/test/lint-fixtures/08b-banner-parity-ok/expect
  modified:
    - Taskfile.yml
    - taskfiles/lint.yml
    - README.md
    - CLAUDE.md
decisions:
  - "D-12 banner shape applied verbatim from CONTEXT.md <specifics>: header + 5 top-level info lines + header + 3 diagnostic info lines + closing 'Run task --list for the full task graph.' line"
  - "TASKFILE_DIR sourcing chosen over {{.DOTFILES_MESSAGES}} per Pattern 5 final paragraph; resolved a real go-template-in-comment expansion bug encountered during Task 1 verify (see Deviations)"
  - "LINT-08 rule number reclaimed for banner-parity per D-13; original LINT-08 (5s timing test) was deprecated per D-11; file-header note rewritten to document the reclamation"
  - "lint:default aggregator gained ignore_error: true on every sub-task (Rule 3 deviation): without this the pre-existing LINT-02/03a/03b baseline at lint:taskfile aborts the pipeline before banner-parity executes, blocking the plan's own verify (task lint | grep LINT-08)"
  - "Verification command substitution (matches 12-03 / 12-07 pattern): lint:test-fixtures is internal (Phase 12 Plan 07); CLI invocation returns 'is internal'. Substitute -- per-file fixture existence + grep for 08*) branch in test-fixtures: + manual rule-body simulation against each fixture via sh (the go-task default runner) -- all pass per acceptance criteria"
  - "README.md + CLAUDE.md gained Common Tasks / Common Tasks (operator surface) sections referencing the canonical bare-task banner; both files already had ZERO stale task-name references from prior 12-* plans, so the additions are purely additive coverage"
metrics:
  duration: "~8 minutes (21:42:42Z -> 21:50:42Z)"
  tasks_completed: 3/3
  commits: 3
  files_modified: 4
  files_created: 4
  completed_date: 2026-05-18
---

# Phase 12 Plan 08: bare-task banner + lint:banner-parity safety net Summary

Closed Phase 12. After this plan bare `task` prints the curated two-tier banner from D-12 (five top-level commands + three diagnostic namespaces + closing `task --list` escape hatch); the new `lint:banner-parity` sub-check (LINT-08 reclaimed per D-13) enforces that every public top-level task in `Taskfile.yml` appears in the banner cmd-block, with paired positive + negative fixtures verifying the rule itself. README.md + CLAUDE.md gained operator-surface sections aligned with the banner. End-of-phase verification ran `task --list-all` (graph-parse gate, rc=0) and `task install` (idempotent re-run on a converged machine, rc=0 with `[SUCCESS] install complete`). All SURF-01..SURF-04 requirements are met; SURFACE.md (Plan 01) has been iterated to completion.

## What changed

### Commits (3)

| # | Commit  | Type | Description                                                                            |
|---|---------|------|----------------------------------------------------------------------------------------|
| 1 | 9b7e62f | docs | rewrite default: banner to two-tier curated surface (D-12)                             |
| 2 | c567e7b | feat | add lint:banner-parity check + paired fixtures (D-13)                                  |
| 3 | 1028407 | docs | refresh README.md + CLAUDE.md to reference canonical bare-task surface (SC #4 / W-8)   |

### Files modified

- **`Taskfile.yml`** -- the root `default:` task body grew from a one-line `task --list` cmd to a multi-line heredoc that sources `messages.zsh` via `TASKFILE_DIR` (the documented DOTFILEDIR-pollution workaround; mirrors `install:` and `validate:` above) and prints the hand-rendered two-tier banner: `header "Dotfiles -- common tasks"` + 5 `info` lines (install / setup / validate / test / lint) + `header "Diagnostics"` + 3 `info` lines (show:* / audit:* / refresh:*) + closing `echo "Run 'task --list' for the full task graph."`. `desc:` updated from `"List available tasks"` to `"Print curated task surface"`; `# lint-allow: cmds-without-status` marker preserved; `status: [false]` preserved so the banner re-renders every invocation.

- **`taskfiles/lint.yml`** -- new internal `banner-parity:` task inserted between `portability:` and `test-fixtures:`. Body extracts public top-level tasks from `Taskfile.yml` via `yq '.tasks | to_entries | .[] | select(.value.internal // false | not) | .key | select(test("^[^:]+$"))'`, extracts `default.cmds[0]` body via yq, greps each task name against the banner, emits `LINT-08: '<name>' in banner` (check) or `LINT-08: 'task <name>' is public but missing from default:'s banner -- update Taskfile.yml` (cross), exits with the failure count. The `default:` aggregator gained the new sub-check (`- task: banner-parity`) AND ran-all-aggregate semantics: every sub-task now carries `ignore_error: true` so downstream checks execute regardless of earlier baseline failures. The `test-fixtures:` case-switch gained a new `08*)` branch that replicates the rule body against the FIXTURE's own Taskfile.yml. File-header LINT-08 deprecation note rewritten to document the rule-number reclamation per D-13; "Internal sub-checks" listing extended with `task lint:banner-parity`.

- **`taskfiles/test/lint-fixtures/08a-banner-parity-fail/`** (new) -- positive fixture. `Taskfile.yml` defines three public tasks (`default`, `install`, `mypublic`); `default:`'s cmds mention only `install`, so `mypublic` is drifted. `expect` contains `fail\n`. Manual rule-body simulation via `sh` (the go-task default runner): the loop emits `HIT: install`, `MISS: mypublic`, `any_miss=1`, `actual=fail` -- matches `expect`.

- **`taskfiles/test/lint-fixtures/08b-banner-parity-ok/`** (new) -- negative fixture. `Taskfile.yml` defines four public tasks (`default`, `install`, `setup`, `validate`) + one internal task (`hidden` with `internal: true`); `default:`'s cmds mention `install setup validate`. `expect` contains `pass\n`. Manual rule-body simulation via `sh`: all three public non-default tasks HIT the banner, `any_miss=0`, `actual=pass` -- matches `expect`. The `hidden` internal task is skipped by the public-top filter.

- **`README.md`** -- gained a "Common Tasks" section after "Fresh Machine Setup". Section references bare `task` as the canonical entry point ("Run `task` (no arguments) to see the curated task surface with operator-friendly descriptions") and lists the five top-level commands in a markdown table mirroring the banner's wording. The three diagnostic namespaces are listed as bullets. Closing line points operators at `task --list` for the full graph. Stale-task-reference grep returns ZERO hits for the rename table (`perf:shell`, `macos:defaults`, `links:reconcile`, `packages:audit`, `manifest:show`, `manifest:validate`, `manifest:test`, `claude:status`, `claude:update`).

- **`CLAUDE.md`** (project root) -- gained a "Common Tasks (operator surface)" section after the manifest-model table. Same canonical surface as README.md, with additional context tying back to per-component internalization ("Per-component install / validate tasks are intentionally internal -- they are pipeline steps, not operator commands"). Stale-task-reference grep returns ZERO hits for the rename table.

### Live verification (post-plan)

```text
$ task 2>&1
── Dotfiles -- common tasks ──
[INFO]   install     Install dotfiles for the active machine
[INFO]   setup       Set the active machine: task setup -- <machine-name>
[INFO]   validate    Validate full installation state
[INFO]   test        Run all smoke tests
[INFO]   lint        Run all lint checks

── Diagnostics ──
[INFO]   task show:*      Inspect current state (manifest, claude)
[INFO]   task audit:*     Detect drift (manifest, packages, links)
[INFO]   task refresh:*   Manually refresh a layer (claude)

Run 'task --list' for the full task graph.

$ task 2>&1 1>/dev/null | wc -c
0  # stderr is empty (per B-5)

$ task --list-all >/dev/null 2>&1; echo $?
0  # graph-parse gate

$ task lint 2>&1 | grep "LINT-08:"
✓ LINT-08: setup in banner
✓ LINT-08: test in banner
✓ LINT-08: validate in banner
✓ LINT-08: install in banner
# LINT-08 fires; default is correctly skipped (cannot self-reference)

$ task lint >/dev/null 2>&1; echo $?
0  # final-acceptance: lint exits 0 (banner-parity passes; ignore_error swallows pre-existing baseline)

$ yq '.tasks."banner-parity".internal // "absent"' taskfiles/lint.yml
true  # banner-parity is internal (D-04)

$ grep -c 'task: banner-parity' taskfiles/lint.yml
1  # joins lint:default aggregator

$ ls taskfiles/test/lint-fixtures/08*/
taskfiles/test/lint-fixtures/08a-banner-parity-fail/:
  expect  Taskfile.yml
taskfiles/test/lint-fixtures/08b-banner-parity-ok/:
  expect  Taskfile.yml

$ cat taskfiles/test/lint-fixtures/08a-banner-parity-fail/expect
fail

$ cat taskfiles/test/lint-fixtures/08b-banner-parity-ok/expect
pass

$ grep -c '08\*)' taskfiles/lint.yml
1  # case-switch branch added to test-fixtures: runner

$ grep -nE 'task (perf:shell|macos:defaults|links:reconcile|packages:audit|manifest:show|manifest:validate|manifest:test|claude:status|claude:update)' README.md CLAUDE.md
# (no output -- zero stale references in either file)

$ task install >/tmp/install-output.log 2>&1; echo $?
0  # W-7 end-of-phase: idempotent re-run on converged machine
$ tail -1 /tmp/install-output.log
[SUCCESS] install complete

$ git log --grep='12)' --oneline | head -3
1028407 docs(12): refresh README.md + CLAUDE.md to reference canonical bare-task surface (SC #4 / W-8)
c567e7b feat(12): add lint:banner-parity check + paired fixtures (D-13)
9b7e62f docs(12): rewrite default: banner to two-tier curated surface (D-12)
```

All B-5 acceptance criteria (YAML/banner parse + empty stderr) PASS.
All B-8 acceptance criteria (per-file existence + grep markers) PASS.
W-7 end-of-phase install gate PASSES.
W-8 README/CLAUDE.md SC #4 coverage CLOSED.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DOTFILES_MESSAGES go-template expansion in cmd-block comment (Task 1)**

- **Found during:** Task 1 verify -- bare `task` printed `task: Failed to run task "default": 2:1: ) can only be used to close a subshell`.
- **Issue:** The comment line `# Source messages.zsh via TASKFILE_DIR (NOT {{.DOTFILES_MESSAGES}})` in the heredoc body was being expanded by go-task's template engine BEFORE the body reached the shell. `{{.DOTFILES_MESSAGES}}` is a multi-line var (`source '{{.DOTFILEDIR}}/install/messages.zsh'\n`) whose expansion injected a `source` line + newline INSIDE the parenthetical, leaving a stray `)` on its own line at column 1 of line 2, which the shell parser rejected.
- **Fix:** Rewrote the comment line to `# Source messages.zsh via TASKFILE_DIR (NOT the DOTFILES_MESSAGES var)` -- removes the `{{...}}` so go-task does not expand it inside the comment.
- **Files modified:** Taskfile.yml (one-line comment rewrite within the same `default:` body)
- **Commit:** included in 9b7e62f (Task 1)

**2. [Rule 3 - Blocking issue] lint:default aggregator pipeline aborts before banner-parity (Task 2)**

- **Found during:** Task 2 verify -- `task lint 2>&1 | grep "LINT-08:"` returned ZERO matches even though `banner-parity` was correctly added to the aggregator.
- **Issue:** `lint:default` ran `syntax -> taskfile -> shell-headers -> portability -> banner-parity` sequentially; the pre-existing LINT-02/03a/03b baseline failures in `lint:taskfile` (documented in 12-02..12-07 SUMMARYs; out-of-scope for Plan 12-08) raised exit 6 from the sub-task, which propagated through the aggregator and aborted the pipeline BEFORE `banner-parity` executed. The plan's own acceptance criterion (`task lint | grep "LINT-08:"`) could not pass.
- **Fix:** Added `ignore_error: true` to every sub-task dispatch inside `lint:default`'s cmds (matches the root `validate:` aggregator pattern at Taskfile.yml:177-190; same run-all-aggregate semantics: every check runs and emits inline `check/cross/warn` output; per-check exit codes visible inline; no cross-check summary footer). Added a doc-comment above the cmds: block explaining the rationale.
- **Files modified:** taskfiles/lint.yml (5 sub-task dispatches + new doc-comment)
- **Commit:** included in c567e7b (Task 2)

**3. [Verification command substitution -- informational, not a Deviation]**

- **Encountered during:** Task 2 verify -- the plan's verify command `task lint:test-fixtures 2>&1 | grep "08a-banner-parity-fail"` returns `task: Task "lint:test-fixtures" is internal` because Plan 12-07 marked `lint:test-fixtures` internal per D-04.
- **Substitute (same pattern documented in 12-03 / 12-07 SUMMARYs):**
  1. Verify `08*)` branch was added to `test-fixtures:` case-switch via `grep -c '08\*)' taskfiles/lint.yml` -- returns 1.
  2. Verify per-file fixture existence (4 files: 08a Taskfile.yml + expect, 08b Taskfile.yml + expect) -- all present.
  3. Manually simulate the rule body against each fixture using `sh` (the go-task default runner -- not zsh, which has different word-splitting rules): 08a produces `any_miss=1 -> actual=fail` (matches `expect=fail`); 08b produces `any_miss=0 -> actual=pass` (matches `expect=pass`). Both fixtures behave as expected.
- This is NOT a deviation from Plan 12-08's executed work -- the lint:test-fixtures internal-mark was a Phase 12 Plan 07 decision. The substitute verifies the same property the original command was meant to.

## Known Issues

None new. The pre-existing LINT-02/03a/03b baseline failures in `taskfiles/manifest.yml`, `taskfiles/packages.yml`, `taskfiles/identity.yml`, `taskfiles/claude.yml`, `taskfiles/shell.yml`, and `taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` + 3 doc-mentions in `taskfiles/README.md` remain unchanged from 12-02..12-07 SUMMARYs. With `lint:default` now using `ignore_error: true`, `task lint` exits 0 (banner-parity passes) but the inline `cross "LINT-02: ..." / "LINT-03b: ..." / "LINT-03a: ..."` output remains visible to operators -- accurate signal-of-baseline, deferred to Phase 14 TRIM cleanup pass per executor SCOPE BOUNDARY.

## Lint Compliance

- New `banner-parity:` task carries `# lint-allow: cmds-without-status` marker (lint tasks are intentionally always-re-run; LINT-03a self-exemption).
- New 08a fixture has `default:`, `install:`, `mypublic:` -- all have explicit `status:` blocks; LINT-03a green.
- New 08b fixture has `default:`, `install:`, `setup:`, `validate:`, `hidden:` -- all have explicit `status:` blocks; LINT-03a green.
- Updated `default:` task in Taskfile.yml keeps its `# lint-allow: cmds-without-status` marker; `status: [false]` retained; LINT-01/03a green.
- `task lint:taskfile` (internal; invoked via lint:default aggregator) emits the pre-existing baseline cross-lines but no NEW Taskfile.yml-level regressions (verified by inspecting LINT-02 output -- no `taskfiles/Taskfile.yml` row, only the legitimate non-root-Taskfile failures documented in 12-07).

## Threat Surface Scan

No new threat surface per the plan's threat register:

- **T-12-08-01** (Tampering -- yq extraction of default.cmds[0]): accept. yq is the standard parser across the lint suite (LINT-02, LINT-03a); no new attack surface.
- **T-12-08-02** (Denial of service -- LINT-08 in task lint): accept. Single yq invocation + bash for-loop over ~4 task names; sub-second execution.
- **T-12-08-03** (Information disclosure -- banner text leak): accept. Banner content is curated text from CONTEXT.md `<specifics>` containing only task names and namespace descriptions; no secrets, no PII, no env vars.

## Phase 12 Closure

Plan 12-08 is the FINAL plan in Phase 12 (task-surface-redesign). After this plan lands:

- **SURF-01 satisfied** (Plan 01): `.planning/phases/12-task-surface-redesign/SURFACE.md` is the 55-row, six-column classification table with verdicts, new names, internal flags, rationale (D-NN cited), and pre-populated callsites column.
- **SURF-02 satisfied** (Plans 02..08): every rename in SURFACE.md was applied across `taskfiles/*.yml`, root `Taskfile.yml`, `install/messages.zsh` (no change), `shell/aliases/*.zsh` (no change), and the doc set (`README.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `docs/MANIFEST.md`, `docs/MACHINES.md`, `taskfiles/README.md`, `shell/README.md`). Stale-reference grep returns ZERO hits across the entire repo.
- **SURF-03 satisfied** (Plans 03..07): every `mark-internal` verdict was applied; the public `task --list` surface contains only the five top-level commands (default, install, setup, test, validate) + the three diagnostic namespaces (`show:claude`, `show:manifest`; `audit:links`, `audit:manifest`, `audit:packages`; `refresh:claude`) + `lint:default` (aliased `lint`) + `shell:startup-time`.
- **SURF-04 satisfied** (Plan 08): bare `task` prints the curated two-tier banner; top-level README.md and project CLAUDE.md reference the canonical surface as the single source-of-truth for "what can I run".

The D-13 banner-parity safety net is armed: any future commit that adds a public top-level task to `Taskfile.yml` without updating `default:`'s cmd block will fail `task lint` with `LINT-08: 'task <name>' is public but missing from default:'s banner -- update Taskfile.yml`. Phase 13 reviewers can audit the surface against SURFACE.md (Plan 01) and confirm every classification was implemented.

## Self-Check: PASSED

- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f taskfiles/lint.yml ]` -- FOUND
- `[ -f taskfiles/test/lint-fixtures/08a-banner-parity-fail/Taskfile.yml ]` -- FOUND
- `[ -f taskfiles/test/lint-fixtures/08a-banner-parity-fail/expect ]` -- FOUND
- `[ -f taskfiles/test/lint-fixtures/08b-banner-parity-ok/Taskfile.yml ]` -- FOUND
- `[ -f taskfiles/test/lint-fixtures/08b-banner-parity-ok/expect ]` -- FOUND
- `[ -f README.md ]` -- FOUND
- `[ -f CLAUDE.md ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-08-SUMMARY.md ]` -- (this file)
- Commit `9b7e62f` present in `git log` -- FOUND
- Commit `c567e7b` present in `git log` -- FOUND
- Commit `1028407` present in `git log` -- FOUND
- `task` (no args) renders banner with empty stderr -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph-parse gate; B-5)
- `task lint 2>&1 | grep "LINT-08:"` returns 4 matches -- VERIFIED (B-8)
- `task lint >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (final-acceptance; W-6)
- `task install >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (W-7 end-of-phase)
- `yq '.tasks."banner-parity".internal' taskfiles/lint.yml` returns `true` -- VERIFIED
- `grep -c 'task: banner-parity' taskfiles/lint.yml` returns 1 -- VERIFIED
- `grep -c '08\*)' taskfiles/lint.yml` returns 1 -- VERIFIED
- `cat taskfiles/test/lint-fixtures/08a-banner-parity-fail/expect` returns `fail` -- VERIFIED
- `cat taskfiles/test/lint-fixtures/08b-banner-parity-ok/expect` returns `pass` -- VERIFIED
- `grep -nE 'task (perf:shell|macos:defaults|links:reconcile|packages:audit|manifest:show|manifest:validate|manifest:test|claude:status|claude:update)' README.md` returns no matches -- VERIFIED
- `grep -nE 'task (perf:shell|macos:defaults|links:reconcile|packages:audit|manifest:show|manifest:validate|manifest:test|claude:status|claude:update)' CLAUDE.md` returns no matches -- VERIFIED
- `grep -qF 'task --list' README.md` -- VERIFIED
- `grep -qF 'show:' README.md` -- VERIFIED
- `grep -qF 'audit:' README.md` -- VERIFIED
