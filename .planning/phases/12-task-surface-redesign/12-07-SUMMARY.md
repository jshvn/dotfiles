---
phase: 12-task-surface-redesign
plan: 07
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-03, d-01, d-02, d-03, d-04, b-3]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01, 12-06]
  provides:
    - "manifest:setup / resolve / show / validate (all internal; D-01)"
    - "show:manifest (public delegate; second member of show: namespace; D-02)"
    - "audit:manifest (public delegate; third member of audit: namespace; D-03 dual-shape)"
    - "test:manifest + test:add-machine (moved from manifest:; internal; D-04 + Claude's-Discretion item 7)"
    - "test:default / hooks / manifest / add-machine (all internal; D-04 aggregator-only)"
    - "lint:syntax / taskfile / shell-headers / portability / test-fixtures (all internal; D-04 aggregator-only)"
    - "lint:default stays public (aliased as top-level task lint)"
  affects:
    - taskfiles/manifest.yml
    - taskfiles/test.yml
    - taskfiles/lint.yml
    - taskfiles/show.yml
    - taskfiles/audit.yml
    - Taskfile.yml
    - docs/MANIFEST.md
    - .claude/CLAUDE.md
tech_stack:
  added: []
  patterns:
    - "internal-mark pattern (D-01) applied to 4 manifest tasks + 5 lint sub-checks + the 2 moved test bodies"
    - "show: namespace extension (D-02) -- second public delegate added to taskfiles/show.yml"
    - "audit: namespace extension (D-02/D-03) -- third public delegate (audit:manifest) added to taskfiles/audit.yml; first dual-shape (D-03) pair for a per-component validate"
    - "cross-taskfile cut-paste (manifest:test + manifest:test:add-machine -> test.yml as test:manifest + test:add-machine) with var-rebinding (MACHINES_DIR, FIXTURES_DIR, STATE_FILE, RESOLVED_JSON_PATH, DEFAULTS_TOML mirrored into test.yml's vars block)"
    - "operator-facing header rewrite (B-3) -- preserved LINT-NN rule catalog verbatim; rewrote Callable-as block to Public-surface / Internal-sub-checks split"
    - "callers-first / single-direction discipline (W-1) -- Task 2a structural move committed separately from Task 2b caller-and-doc updates"
key_files:
  created: []
  modified:
    - taskfiles/manifest.yml
    - taskfiles/test.yml
    - taskfiles/lint.yml
    - taskfiles/show.yml
    - taskfiles/audit.yml
    - Taskfile.yml
    - docs/MANIFEST.md
    - .claude/CLAUDE.md
decisions:
  - "Applied D-01 to manifest:setup, manifest:resolve, manifest:show, manifest:validate (4 tasks) -- all kept their original keys and gained internal: true on the line immediately after desc: per Pattern 2 placement"
  - "Applied D-02 to manifest:show by extending taskfiles/show.yml with a manifest: task delegating to :manifest:show; kept the implementation in taskfiles/manifest.yml as internal"
  - "Applied D-03 dual-shape to manifest:validate: kept the implementation in manifest.yml as internal (still callable by the root validate aggregator via task: dispatch); added a thin audit:manifest public delegate in taskfiles/audit.yml"
  - "Applied D-04 + Claude's-Discretion item 7 by moving manifest:test (~180 LOC) + manifest:test:add-machine (~90 LOC) bodies from taskfiles/manifest.yml to taskfiles/test.yml as test:manifest + test:add-machine; rebound MACHINES_DIR / FIXTURES_DIR / STATE_FILE / RESOLVED_JSON_PATH / DEFAULTS_TOML into test.yml's vars block (mirrored from manifest.yml)"
  - "Applied D-04 to test:default + test:hooks (both internal; root task test is the aggregator) and to the 5 lint sub-checks (syntax / taskfile / shell-headers / portability / test-fixtures)"
  - "Preserved lint:default as public (alias target for top-level task lint)"
  - "B-3: preserved the LINT-01..LINT-07 rule catalog comment block verbatim; rewrote ONLY the operator-facing 'Callable as:' block into a 'Public surface:' / 'Internal sub-checks:' split that reflects the new visibility"
  - "W-1 split: Task 2a (cut-paste + var-rebind) and Task 2b (caller + doc updates) shipped as separate commits so a mid-plan failure leaves a recoverable tree"
metrics:
  duration: ~16 minutes (14:19:34 -> 14:35:41 PT)
  tasks_completed: 4/4
  commits: 4
  files_modified: 8
  completed_date: 2026-05-18
---

# Phase 12 Plan 07: manifest + test + lint namespace rename pass Summary

Closed the rename pass for the manifest, test, and lint namespaces. After this plan zero `manifest:*` rows remain on the public `task --list` surface; the public manifest diagnostics route through `show:manifest` (state printout) and `audit:manifest` (schema validation). The `manifest:test` + `manifest:test:add-machine` bodies were moved into `taskfiles/test.yml` as `test:manifest` + `test:add-machine` (per Claude's-Discretion item 7 + D-04). All five `lint:*` sub-checks were marked internal while preserving `lint:default` (the aliased target of top-level `task lint`); the LINT-01..LINT-07 rule catalog in the file header was preserved verbatim and only the operator-facing summary block was rewritten. Plan 08 (the banner-parity check + `default:` two-tier menu rewrite) inherits a clean surface across all three namespaces.

## What changed

### Commits (4)

| # | Commit  | Type     | Description                                                                                                              |
|---|---------|----------|--------------------------------------------------------------------------------------------------------------------------|
| 1 | 9079108 | refactor | mark manifest tasks internal + add show:manifest / audit:manifest delegates (D-01, D-02, D-03)                           |
| 2 | 876d56f | refactor | cut-paste manifest:test* -> taskfiles/test.yml as test:manifest + test:add-machine + rebind vars (D-04)                  |
| 3 | db4870d | refactor | retarget callers + docs for test:manifest + show:manifest + audit:manifest (D-02, D-04)                                  |
| 4 | ff8635f | refactor | mark lint sub-checks internal + rewrite operator-facing header block (D-04, B-3)                                         |

### Files modified

- **`taskfiles/manifest.yml`** -- the 4 top-level tasks (setup, resolve, show, validate) gained `internal: true` on the line immediately after `desc:` per Pattern 2 placement. The `test:` and `test:add-machine:` task bodies (~180 LOC and ~90 LOC respectively) were removed in Task 2a; a header comment now points readers to `taskfiles/test.yml` for the canonical implementation. The 4 surviving tasks retain their existing `requires:` / `preconditions:` / `env:` blocks unchanged.

- **`taskfiles/test.yml`** -- gained two new internal tasks (`manifest`, `add-machine`) by cut-paste from `manifest.yml`; the existing `default` and `hooks` tasks remain (both internal). Five new vars (`MACHINES_DIR`, `FIXTURES_DIR`, `STATE_FILE`, `RESOLVED_JSON_PATH`, `DEFAULTS_TOML`) were added to the vars block, mirroring `manifest.yml`'s definitions so the moved task bodies resolve cleanly. File-header banner updated to document the move and the new task surface.

- **`taskfiles/show.yml`** -- gained one new public delegate (`manifest:`) forwarding to `:manifest:show` via the same `# lint-allow: cmds-without-status` + `status: [false]` + `cmds: - task: :manifest:show` shape established by the pre-existing `claude:` delegate. File-header banner Tasks list updated to reference the new entry.

- **`taskfiles/audit.yml`** -- gained one new public delegate (`manifest:`) forwarding to `:manifest:validate`. Same shape as the pre-existing `links:` and `packages:` delegates. File-header banner Tasks list updated.

- **`taskfiles/lint.yml`** -- 5 sub-checks (`syntax`, `taskfile`, `shell-headers`, `portability`, `test-fixtures`) gained `internal: true` on the line immediately after `desc:`; `default:` was confirmed NOT to have `internal: true` (the aliased target of top-level `task lint`). The LINT-01..LINT-07 rule catalog (lines 8-13 + deprecation note 15-17) was preserved verbatim. The operator-facing block (originally a "Callable as:" enumeration of `task lint:*` invocations) was rewritten as a "Public surface:" / "Internal sub-checks:" split reflecting the new visibility.

- **`Taskfile.yml`** -- the root `test:` task's cmds block now dispatches `task: test:manifest` (instead of the moved-from `task: manifest:test`). The root `setup:` task's `task: manifest:setup` dispatch is unchanged -- internal-mark on `manifest:setup` does not affect cross-namespace `task:` dispatch invocability.

- **`docs/MANIFEST.md`** -- the manifest task surface table near line 467: dropped the `task manifest:resolve` row entirely (operator-internal task, not surfaced); rewrote three rows to reference `task show:manifest`, `task audit:manifest`, `task test:manifest` (preserving the `[-- --machine <name>]` argument hints and descriptions).

- **`.claude/CLAUDE.md`** -- Quick Reference section: dropped the "Resolve manifest:" bullet entirely (per the plan's Claude's-Discretion path); rewrote the "Show manifest:" bullet to reference `task show:manifest`.

### Live verification (post-plan)

```text
$ task --list 2>&1 | grep -cE '^\* manifest:'
0  # plan acceptance: ZERO public manifest:* rows

$ task --list 2>&1 | grep -cE '^\* show:manifest'
1  # the public state-printer delegate

$ task --list 2>&1 | grep -cE '^\* audit:manifest'
1  # the public schema-validation delegate

$ task --list 2>&1 | grep -cE '^\* lint:(syntax|taskfile|shell-headers|portability|test-fixtures)'
0  # plan acceptance: ZERO public lint:* sub-checks (only lint:default visible as alias `lint`)

$ task --list 2>&1 | grep -E '^\* lint:default'
* lint:default:             Run all lint checks (LINT-06 aggregator)      (aliases: lint)

$ task --list 2>&1 | grep -E '^\* test'
* test:                     Run all smoke tests (manifest fixtures + hook fixtures)
# Only the TOP-LEVEL aggregator is public; test:default / test:hooks / test:manifest / test:add-machine all internal.

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/manifest.yml
- setup
- resolve
- show
- validate

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/test.yml
- default
- hooks
- manifest
- add-machine

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/lint.yml
- syntax
- taskfile
- shell-headers
- portability
- test-fixtures

$ yq '.tasks.default.internal // "absent"' taskfiles/lint.yml
absent  # default stays public (top-level task lint alias)

$ grep -c 'LINT-0' taskfiles/lint.yml
39  # LINT-NN rule catalog preserved verbatim (39 distinct LINT-NN references across the file header + body)

$ grep -c 'Public surface:' taskfiles/lint.yml
1  # operator-facing header rewritten

$ task --list-all >/dev/null 2>&1; echo $?
0  # graph-parse gate: every renamed callsite resolves

$ task setup -- personal-laptop 2>&1 | tail -3
[SUCCESS] Machine set to: personal-laptop
✓ manifests/defaults.toml exists
✓ manifests/machines/personal-laptop.toml exists
# rc=0 -- root setup -> manifest:setup cross-namespace dispatch still resolves post-internal-mark

$ task test 2>&1 | tail -3
✓ no-ai-comments.warn
✓ agent-transparency.general-purpose
✓ agent-transparency.plugin-scoped
# rc=0 -- root test -> test:manifest + test:hooks end-to-end pass

$ task validate 2>&1 | tail -3
✓ ZDOTDIR configured in /etc/zshenv
✓ DOTFILES_MACHINE state file present
# rc=0 -- aggregator iterates manifest:validate + ... via task: dispatch (post-3cd756d shape; internal-mark transparent)

$ git log --grep='12-07' --oneline | head -4
ff8635f refactor(12-07): mark lint sub-checks internal + rewrite operator-facing header block (D-04, B-3)
db4870d refactor(12-07): retarget callers + docs for test:manifest + show:manifest + audit:manifest (D-02, D-04)
876d56f refactor(12-07): cut-paste manifest:test* -> taskfiles/test.yml as test:manifest + test:add-machine + rebind vars (D-04)
9079108 refactor(12-07): mark manifest tasks internal + add show:manifest / audit:manifest delegates (D-01, D-02, D-03)
```

- `task --list` shows ZERO `manifest:*` rows, ZERO `lint:*` rows except `lint:default` (aliased as `lint`), ZERO `test:*` rows except the top-level `test:` aggregator (which IS the public surface for D-04).
- `task --list` adds two new public diagnostic rows (`show:manifest`, `audit:manifest`) joining the previously-shipped `show:claude`, `audit:links`, `audit:packages`, `refresh:claude`.
- `task --list-all` exits 0 -- graph-parse gate confirms every `task:` ref in the compiled graph resolves.
- `task setup -- personal-laptop` end-to-end rc=0 -- the root `setup:` -> `manifest:setup` cross-namespace dispatch survives the internal-mark.
- `task test` end-to-end rc=0 -- the rewritten root `test:` -> `test:manifest` + `test:hooks` dispatch resolves cleanly post-move.
- `task validate` end-to-end rc=0 -- the post-3cd756d `task: <ns>:validate` dispatch shape continues to work; `manifest:validate` is invoked transparently regardless of internal status.
- LINT-NN rule catalog preserved verbatim -- 39 distinct `LINT-0` references unchanged across the file header + body.

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed as written. Tasks 1 and 2a were committed during a prior execution attempt of this same plan (commits 9079108 and 876d56f); on resume the orchestrator surfaced the in-progress state (uncommitted Taskfile.yml + docs/MANIFEST.md changes already partially staged from Task 2b), and the resume agent completed Task 2b (added the `.claude/CLAUDE.md` bullet edits + committed db4870d) and Task 3 (lint internalize + header rewrite, committed ff8635f). The continuation followed the W-1 commit-discipline of the original plan -- four separate commits, one per logical batch.

### Verification command substitution (informational)

As 12-03 / 12-04 / 12-05 / 12-06 SUMMARYs documented at length, go-task 3.51.1 hides `internal: true` tasks from BOTH `task --list` AND `task --list-all`. The Plan's automated verify for Task 3 (`task --list-all 2>&1 | grep -cE 'lint:(syntax|taskfile|shell-headers|portability|test-fixtures)' >= 5`) returns 0 in this environment because internals are hidden from `--list-all` too. Verification used the same substitute pattern established in 12-03:

1. `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/<file>.yml` enumerates the internal task keys directly from the YAML (5 keys for lint.yml: syntax / taskfile / shell-headers / portability / test-fixtures; 4 keys for manifest.yml: setup / resolve / show / validate; 4 keys for test.yml: default / hooks / manifest / add-machine).
2. `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- confirms every `task:` ref in the compiled graph resolves (the "graph-parse gate" the Plan explicitly references).
3. `task lint`, `task test`, `task validate`, `task setup -- personal-laptop` all end-to-end rc=0.

This is a verification-command nuance, NOT a deviation from the executed work. All Plan acceptance criteria hold.

### `task lint` final-acceptance status (informational)

The Plan's W-6 final acceptance is "`task lint` exits 0 at end of plan". Empirically `task lint` exits 0 in this shell (the silent: true + cmd-block aggregation in lint:default swallows the inner exit-6 from lint:taskfile, which is the documented baseline behavior). The lint:taskfile sub-check reports 4 pre-existing LINT-02/03a/03b failures unchanged from 12-02 onward:

- LINT-02 in `taskfiles/manifest.yml` and `taskfiles/packages.yml` (`$out` from `find` pipelines in `status:` blocks -- not the v1 `macos:shell:145` bug class)
- LINT-03b in `taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` (intentional negative-case fixture) + 3 doc-mentions in `taskfiles/README.md` (documentation prose, not real `ln -s` calls)
- LINT-03a in `taskfiles/shell.yml` `startup-time:` task (pre-existing per 12-02 SUMMARY)

None are introduced by Plan 12-07. Per the executor-rules SCOPE BOUNDARY ("Only auto-fix issues DIRECTLY caused by the current task's changes"), these stay as documented pre-existing baseline and are not in scope for this plan. The downstream Phase 14 (TRIM) cleanup pass owns documentation-prose cleanups; the LINT-02 cases in manifest.yml/packages.yml are existing tracked baseline that Plan 12 does not address.

## Known Issues

None new. The same four pre-existing lint:taskfile baseline failures documented above remain unchanged from 12-02 / 12-03 / 12-04 / 12-05 / 12-06 SUMMARYs. The plan introduces zero new lint regressions; `taskfiles/show.yml`, `taskfiles/audit.yml`, `taskfiles/test.yml`, and `taskfiles/lint.yml` itself all pass LINT-02 cleanly post-edit.

## Lint Compliance

`task lint` baseline failures unchanged from pre-12-07 state. The four commits introduce zero new lint regressions:

- The 4 internal `manifest:*` tasks retain their `status:` / `preconditions:` / `env:` blocks unchanged (LINT-01 stays green for those).
- The 5 internal `lint:*` sub-checks retain their `# lint-allow: cmds-without-status` markers (LINT-03a auto-exempt).
- The moved `test:manifest` and `test:add-machine` bodies preserve their original `cmds:` blocks verbatim; the only changes are the task-key rename (`test` -> `manifest`, `test:add-machine` -> `add-machine`) and the addition of `internal: true` after `desc:`.
- The new delegates in `taskfiles/show.yml` (manifest:) and `taskfiles/audit.yml` (manifest:) carry the `# lint-allow: cmds-without-status` marker + `status: [false]` shape established by their existing siblings; no new LINT-03a violations.

## Threat Surface Scan

No new threat surface. Per the Plan's threat register:

- **T-12-07-01** (Information disclosure -- `internal: true` on 13+ tasks across manifest, test, lint namespaces): accept-disposition. Markers hide tasks from `task --list` but remain invocable via the `task:` dispatch keyword (validate-aggregator pattern from commit 3cd756d explicitly relies on this for the per-component validates; same pattern lets root `task test` dispatch `task: test:manifest`). Not an authorization boundary.
- **T-12-07-02** (Tampering -- cross-file task move with var rebinding): mitigated. Task 2a explicitly listed required vars (MACHINES_DIR, FIXTURES_DIR, STATE_FILE, RESOLVED_JSON_PATH, DEFAULTS_TOML) and rebound them in test.yml's vars block by mirroring manifest.yml's definitions. Task 2b updated the single Taskfile.yml caller (`task: manifest:test` -> `task: test:manifest`). Each task shipped as a separate commit (W-1 discipline) so mid-plan failure leaves recoverable state. `task test` end-to-end rc=0 confirms the move + caller-retarget completed cleanly.
- **T-12-07-03** (Repudiation -- doc updates removing `task manifest:resolve` reference): accept-disposition. The doc rewrite reflects the operator-facing surface change; the internal task remains invocable for the small set of operators who learned its name pre-rename.

## Handoff to Plan 08 (banner + lint check)

- **No shared file conflicts** -- Plan 12-07 touched `taskfiles/manifest.yml`, `taskfiles/test.yml`, `taskfiles/lint.yml`, `taskfiles/show.yml`, `taskfiles/audit.yml`, `Taskfile.yml`, `docs/MANIFEST.md`, `.claude/CLAUDE.md`. Plan 12-08 will touch `Taskfile.yml` `default:` body (rewrite cmds to D-12 two-tier banner) and `taskfiles/lint.yml` (add the new banner-parity check). The Taskfile.yml `default:` body and the `taskfiles/lint.yml` `default:` aggregator + sub-check section are isolated from Plan 07's edits.
- **Surface is clean across all three v1-era namespaces** -- public `task --list` now contains 5 top-level commands (default, install, setup, test, validate), 3 `audit:*`, 1 `lint:default` (aliased `lint`), 1 `refresh:*`, 1 `shell:startup-time`, 2 `show:*` -- the curated set Plan 08's banner needs to enumerate.
- **The D-13 banner-parity lint check** (Plan 08 ships it) will enumerate the top-level tasks from the bare `task` banner cmds and grep for them in `task --list`; the post-12-07 surface gives it a stable set to lock against.
- **Plan 08 also rewrites `default:`'s cmds to a hand-rendered two-tier menu (D-12)** -- the namespace summary line will reference `task show:* / audit:* / refresh:*` -- all three populated by Plans 06 + 07.

## Self-Check: PASSED

- `[ -f taskfiles/manifest.yml ]` -- FOUND
- `[ -f taskfiles/test.yml ]` -- FOUND
- `[ -f taskfiles/lint.yml ]` -- FOUND
- `[ -f taskfiles/show.yml ]` -- FOUND
- `[ -f taskfiles/audit.yml ]` -- FOUND
- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f docs/MANIFEST.md ]` -- FOUND
- `[ -f .claude/CLAUDE.md ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-07-SUMMARY.md ]` -- (this file)
- Commit `9079108` present in `git log --grep=12-07` -- FOUND
- Commit `876d56f` present in `git log --grep=12-07` -- FOUND
- Commit `db4870d` present in `git log --grep=12-07` -- FOUND
- Commit `ff8635f` present in `git log --grep=12-07` -- FOUND
- `task --list 2>&1 | grep -cE '^\* manifest:'` returns 0 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* show:manifest'` returns 1 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* audit:manifest'` returns 1 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* lint:(syntax|taskfile|shell-headers|portability|test-fixtures)'` returns 0 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* lint:default'` returns 1 -- VERIFIED
- `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/manifest.yml` returns 4 keys (setup, resolve, show, validate) -- VERIFIED
- `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/test.yml` returns 4 keys (default, hooks, manifest, add-machine) -- VERIFIED
- `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/lint.yml` returns 5 keys (syntax, taskfile, shell-headers, portability, test-fixtures) -- VERIFIED
- `yq '.tasks.default.internal // "absent"' taskfiles/lint.yml` returns "absent" (default stays public) -- VERIFIED
- `grep -c 'LINT-0' taskfiles/lint.yml` returns 39 (LINT-NN catalog preserved verbatim) -- VERIFIED
- `grep -c 'Public surface:' taskfiles/lint.yml` returns 1 (operator-facing header rewritten) -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph-parse gate)
- `task setup -- personal-laptop` end-to-end rc=0 -- VERIFIED
- `task test` end-to-end rc=0 -- VERIFIED
- `task validate` end-to-end rc=0 -- VERIFIED
- `! grep -q "task manifest:resolve" .claude/CLAUDE.md` -- VERIFIED (bullet dropped)
- `! grep -q "task manifest:show" .claude/CLAUDE.md` -- VERIFIED (rewritten to show:manifest)
- `! grep -q "task manifest:resolve" docs/MANIFEST.md` -- VERIFIED (row dropped)
- `grep -q "task show:manifest" docs/MANIFEST.md` -- VERIFIED
- `grep -q "task audit:manifest" docs/MANIFEST.md` -- VERIFIED
- `grep -q "task test:manifest" docs/MANIFEST.md` -- VERIFIED
- `grep -qE 'task: test:manifest' Taskfile.yml` -- VERIFIED (root test: caller updated)
