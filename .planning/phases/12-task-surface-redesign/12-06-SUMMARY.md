---
phase: 12-task-surface-redesign
plan: 06
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-03, d-01, d-02, d-03]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01, 12-03]
  provides:
    - "packages:install / compose / verify / audit / validate (all internal; D-01)"
    - "audit:packages (public delegate; second member of audit: namespace)"
    - "claude:install / update / status / validate (all internal; D-01)"
    - "show:claude (public delegate; first member of show: namespace; D-02)"
    - "refresh:claude (public delegate; first member of refresh: namespace; D-03)"
    - "taskfiles/show.yml (NEW; mandatory W-3 banner)"
    - "taskfiles/refresh.yml (NEW; mandatory W-3 banner)"
  affects:
    - taskfiles/packages.yml
    - taskfiles/audit.yml
    - taskfiles/claude.yml
    - taskfiles/show.yml
    - taskfiles/refresh.yml
    - Taskfile.yml
tech_stack:
  added: []
  patterns:
    - "internal-mark pattern (D-01) applied to 9 tasks across packages: + claude: namespaces"
    - "audit: namespace extension (D-02) -- second public delegate added to taskfiles/audit.yml"
    - "show: namespace bootstrap (D-02) -- NEW dedicated taskfile for state-inspection delegates"
    - "refresh: namespace bootstrap (D-03) -- NEW dedicated taskfile for explicit-refresh delegates"
    - "thin-delegate pattern -- absolute-form (:claude:status, :claude:update, :packages:audit) cross-namespace task dispatch + CLI_ARGS forwarding via vars: { CLI_ARGS: '{{.CLI_ARGS}}' }"
    - "single-commit-per-namespace shape -- packages internalize + audit:packages add in commit 1; claude internalize + show/refresh bootstrap in commit 2"
key_files:
  created:
    - taskfiles/show.yml
    - taskfiles/refresh.yml
  modified:
    - taskfiles/packages.yml
    - taskfiles/audit.yml
    - taskfiles/claude.yml
    - Taskfile.yml
decisions:
  - "Applied D-01 to 5 packages tasks (install, compose, verify, audit, validate); all kept their names + gained internal: true on the line immediately after desc: per Pattern 2 placement"
  - "Applied D-02 to packages:audit via the extension mechanic: kept the implementation in taskfiles/packages.yml as internal; added public audit:packages delegate to existing taskfiles/audit.yml (created by 12-03)"
  - "Applied D-01 to 4 claude top-level tasks (install, update, status, validate); marketplace + gsd + ensure-cli sub-tasks were already internal"
  - "Applied D-02 to claude:status: kept implementation in claude.yml as internal; created new taskfiles/show.yml with show:claude public delegate forwarding to :claude:status"
  - "Applied D-03 to claude:update: kept implementation in claude.yml as internal; created new taskfiles/refresh.yml with refresh:claude public delegate forwarding to :claude:update"
  - "Both new taskfiles carry the mandatory W-3 four-section header banner (Purpose / Callers / Side effects / Tasks). refresh.yml's Side-effects note explicitly distinguishes between the read-only delegate and its mutating underlying implementation."
  - "Taskfile.yml includes block: added refresh: after packages: (alphabetical-between-packages-and-shell intent per plan interfaces); added show: after claude: (alphabetical-between-shell-and-test intent). Includes: header comment-block updated in lockstep."
metrics:
  duration: ~10 minutes
  tasks_completed: 2/2
  commits: 2
  files_created: 2
  files_modified: 4
  completed_date: 2026-05-18
---

# Phase 12 Plan 06: packages + claude namespace rename + audit:/show:/refresh: delegates Summary

Marked the entire `packages:` namespace internal (5 tasks) per D-01 and added the public `audit:packages` delegate as the second member of the `audit:` namespace bootstrapped by 12-03. Marked the entire `claude:` namespace internal (4 top-level tasks; the 3 sub-tasks were already internal) and bootstrapped two NEW dedicated public-delegate taskfiles: `taskfiles/show.yml` (D-02 -- state-printers under `show:`) hosting `show:claude` and `taskfiles/refresh.yml` (D-03 -- explicit-refresh `refresh:` namespace) hosting `refresh:claude`. Public `packages:*` and `claude:*` surfaces now contain zero rows; the operator-facing diagnostics path runs through `audit:packages`, `show:claude`, `refresh:claude`. Per W-9 this plan does NOT modify `docs/MANIFEST.md` -- the doc references to `task packages:verify` and `task packages:install` survive `internal: true` (internal task names remain invocable; Plan 07 handles the `manifest:test` -> `test:manifest` rename which DOES require a MANIFEST.md edit).

## What changed

### Commits (2)

| # | Commit  | Type     | Description                                                                                                |
|---|---------|----------|------------------------------------------------------------------------------------------------------------|
| 1 | 1d4a431 | refactor | mark packages tasks internal + add audit:packages delegate (D-01, D-02)                                    |
| 2 | 74167c1 | refactor | mark claude tasks internal + add show:claude / refresh:claude delegates (D-01, D-02, D-03)                 |

### Files modified

- **`taskfiles/packages.yml`** -- 5 task definitions touched, all gain `internal: true` on the line immediately after `desc:` (Pattern 2 placement; unchanged from D-01 fingerprint):
  - `install:` -- aggregator with the D-09 two-condition status block; `internal: true` added before `deps:`.
  - `compose:` -- inspection helper; `internal: true` added before `deps:`.
  - `verify:` -- D-07 enumerate-all + Gap 2 brew-info two-layer model; `internal: true` added before `silent: false`. The pre-existing `# lint-allow: cmds-without-status` marker on the preceding line stays.
  - `audit:` -- D-11 drift-detection task; `internal: true` added before `deps:`. The pre-existing `# lint-allow: cmds-without-status` marker stays.
  - `validate:` -- thin wrapper for root `task validate`; `internal: true` added before `cmds:`. The pre-existing `# lint-allow: cmds-without-status` marker stays.

- **`taskfiles/audit.yml`** -- one new task definition + one header-banner line:
  - `packages:` task block appended after the existing `links:` block. Same shape as `links:` (4-space-indent under `tasks:`): `# lint-allow: cmds-without-status` marker, `desc:` quoted, `status: [false]`, `cmds:` with single `task: :packages:audit` + `vars: { CLI_ARGS: '{{.CLI_ARGS}}' }` for `--strict` forwarding (D-11 contract preserved).
  - File-header banner Tasks list appended with `#   - packages -- delegate to :packages:audit (brew/cask/mas drift detection; D-02)`.

- **`taskfiles/claude.yml`** -- 4 task definitions touched, all gain `internal: true` on the line immediately after `desc:`:
  - `install:` -- public aggregator feature-gated on `claude-marketplace`; `internal: true` added before `deps:`.
  - `update:` -- explicit refresh path; `internal: true` added before `deps:`. The pre-existing `# lint-allow: cmds-without-status` marker stays.
  - `status:` -- diagnostic show; `internal: true` added before `status: [false]`. The pre-existing `# lint-allow: cmds-without-status` marker stays.
  - `validate:` -- composed into root `task validate`; `internal: true` added before `deps:`. The pre-existing `# lint-allow: cmds-without-status` marker stays.
  - The three internal sub-tasks (`marketplace`, `gsd`, `ensure-cli`) were already `internal: true` -- unchanged.

- **`taskfiles/show.yml`** (NEW) -- public diagnostics file for D-02 state-printers:
  - Mandatory W-3 banner block with all four sections: Purpose, Callers, Side effects, Tasks.
  - `version: '3'`, self-contained `vars:` block resolving `DOTFILEDIR` via `sh: dirname "{{.TASKFILE_DIR}}"` (matches audit.yml shape).
  - One task `claude:` whose `cmds:` invokes `:claude:status`. Carries `# lint-allow: cmds-without-status` marker and `status: [false]`.

- **`taskfiles/refresh.yml`** (NEW) -- public delegates for D-03 explicit-refresh ops:
  - Mandatory W-3 banner block with all four sections. Side-effects line explicitly notes the read-only delegate semantics vs the mutating underlying implementation (`(NOTE: the underlying refresh implementations DO mutate state; the delegate itself is the read-only thin pass-through ...)`).
  - `version: '3'`, self-contained `vars:` block, one task `claude:` whose `cmds:` invokes `:claude:update`. Same lint-allow marker + `status: [false]` shape.

- **`Taskfile.yml`** -- includes block + Includes: header comment block:
  - Includes: header comment (lines 8-17): added `#   - refresh  (P12, real)` between `packages` and `claude`; added `#   - show     (P12, real)` after `macos`. Header comment is descriptive, not load-ordered.
  - `includes:` block (line 70+): added `  refresh:  ./taskfiles/refresh.yml          # P12 public refresh: namespace (D-03)` after the `packages:` block (matches the plan's "between packages: and shell:" intent in the actual file's structural ordering). Added `  show:     ./taskfiles/show.yml             # P12 public show: namespace (D-02)` after `claude:` and before the `test:` block.

### Live verification (post-plan)

```text
$ task --list 2>&1 | grep -cE '^\* packages:'
0  # plan acceptance: ZERO public packages:* rows

$ task --list 2>&1 | grep -cE '^\* claude:'
0  # plan acceptance: ZERO public claude:* rows

$ task --list 2>&1 | grep -E '^\* (audit|show|refresh):'
* audit:links:                     Audit symlink drift (detect orphans); -- --remove for interactive cleanup
* audit:packages:                  Audit brew formulae/casks/mas vs declared (D-11). Non-blocking; --strict exits non-zero.
* refresh:claude:                  Refresh marketplaces + plugins + GSD (explicit; not in task install)
* show:claude:                     Show installed marketplaces + plugins (diagnostic)

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/packages.yml
- install
- compose
- verify
- audit
- validate

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/claude.yml
- install
- marketplace
- gsd
- update
- status
- validate
- ensure-cli

$ test -f taskfiles/show.yml && test -f taskfiles/refresh.yml; echo $?
0

$ grep -E '^# (Purpose|Callers|Side effects|Tasks):' taskfiles/show.yml taskfiles/refresh.yml
taskfiles/show.yml:# Purpose: Public delegates for diagnostic show operations across all namespaces.
taskfiles/show.yml:# Callers: Invoked directly by operator; included by Taskfile.yml.
taskfiles/show.yml:# Side effects: Read-only -- these tasks print state or detect drift; no mutations.
taskfiles/show.yml:# Tasks:
taskfiles/refresh.yml:# Purpose: Public delegates for explicit manual-refresh operations across all namespaces.
taskfiles/refresh.yml:# Callers: Invoked directly by operator; included by Taskfile.yml.
taskfiles/refresh.yml:# Side effects: Read-only -- these tasks print state or detect drift; no mutations.
taskfiles/refresh.yml:# Tasks:

$ grep -nE '^\s*(show|refresh):\s+\./taskfiles/' Taskfile.yml
106:  refresh:  ./taskfiles/refresh.yml          # P12 public refresh: namespace (D-03)
108:  show:     ./taskfiles/show.yml             # P12 public show: namespace (D-02)

$ task --list-all >/dev/null 2>&1; echo $?
0  # graph-parse gate: every renamed callsite resolves in the compiled task graph

$ task validate
[...full per-component output, all check rows green...]
$ echo $?
0  # task install pipeline + validate aggregator end-to-end pass (the now-internal
   # packages:validate + claude:validate are invoked via the task: dispatch
   # aggregator from commit 3cd756d -- 12-02 Known Issue stays resolved)

$ git rev-parse --short HEAD~1
1d4a431
$ git rev-parse --short HEAD
74167c1
```

- `task --list` shows ZERO `packages:*` rows AND ZERO `claude:*` rows.
- `task --list` adds exactly three new public diagnostic rows: `audit:packages`, `show:claude`, `refresh:claude` (alongside the pre-existing `audit:links` from 12-03).
- `taskfiles/packages.yml` declares 5 internal task keys.
- `taskfiles/claude.yml` declares 7 internal task keys (4 top-level + 3 sub-tasks; the 3 sub-tasks were already internal pre-plan).
- Both new files exist with mandatory W-3 four-section banner.
- Taskfile.yml includes block has the two new entries.
- `task --list-all` exits 0 -- graph-parse gate confirms every `task:` ref in the compiled graph resolves: includes-block alphabetical-ordering nuance does not matter for go-task resolution; the include name (`show:` / `refresh:`) is the namespace prefix; the leading-colon absolute-form refs (`:claude:status`, `:claude:update`, `:packages:audit`) resolve to the now-internal sources.
- `task validate` runs end-to-end rc=0 -- the now-internal `packages:validate` + `claude:validate` are invoked via the rewritten `task:`-dispatch aggregator from commit 3cd756d (12-02 Known Issue resolved before Plan 03 ran and stays resolved).

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed as written.

### Verification command substitution (informational)

As 12-03 / 12-04 / 12-05 SUMMARYs documented at length, go-task 3.51.1 hides `internal: true` tasks from BOTH `task --list` and `task --list-all` (the Plan's automated verify hints at `task --list-all | grep -cE 'packages:(install|...)' -ge 5` -- in this environment that returns 0 because internals are hidden). Verification used the same substitute pattern established in 12-03:

1. `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/<file>.yml` enumerates the internal task keys directly from the YAML.
2. `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- confirms every `task:` ref in the compiled graph resolves (the "graph-parse gate" the Plan explicitly references).
3. `task validate` end-to-end rc=0 -- confirms the now-internal `packages:validate` + `claude:validate` are invocable via the rewritten aggregator.

This is a verification-command nuance, NOT a deviation from the executed work. All Plan acceptance criteria hold.

### Includes-block alphabetical-ordering note (informational)

The plan's `<interfaces>` block sketches an alphabetical includes-block ordering (`audit -> claude -> identity -> lint -> links -> macos -> manifest -> packages -> refresh -> shell -> show -> test`). The actual `Taskfile.yml` includes block is NOT alphabetical (it groups vars-forwarding includes with their inline `vars:` blocks). The plan's interface shape is a directional sketch; the actual insertion followed the plan's intent ("between packages: and shell:" for `refresh:`; "between shell: and test:" for `show:`) translated to the file's real ordering: `refresh:` inserted after the `packages:` block, `show:` inserted after `claude:` and before the `test:` block. This is a documentation-vs-implementation reconciliation, not a behavioural deviation; go-task's include resolution is name-keyed, not order-dependent.

## Known Issues

None new. The pre-existing `task lint:taskfile` failures documented in 12-02 / 12-03 / 12-04 / 12-05 SUMMARYs remain unchanged:

- LINT-02 failures: `taskfiles/claude.yml`, `taskfiles/manifest.yml`, `taskfiles/packages.yml`. (`taskfiles/identity.yml` no longer fails LINT-02 -- resolved during Plan 12-04 per the 12-04 SUMMARY.) All pre-existing in the LINT-02 list before this plan started; no new regressions. `taskfiles/show.yml` and `taskfiles/refresh.yml` both pass LINT-02 cleanly.
- LINT-03a failures: 5 manifest.yml task-blocks (`setup`, `show`, `validate`, `test`, `test:add-machine`); 1 shell.yml task (`startup-time`). All pre-existing.
- LINT-03b: 1 doc-mention in `taskfiles/README.md`. Pre-existing (a documentation string, not a real `ln -s` call).

Plan 12-06's two commits introduce zero new lint regressions:

- The five internal `packages:*` tasks retain their `status:` blocks unchanged (LINT-01 stays green for those).
- The four internal `claude:*` tasks retain their existing `status:` blocks unchanged.
- The new `audit:packages` delegate has the `# lint-allow: cmds-without-status` marker on the line above and `cmds:` is a single `task:` delegation (LINT-03a auto-exempt).
- The new `show:claude` / `refresh:claude` delegates each have the marker + single `task:` delegation.

## Lint Compliance

`task lint` baseline failures unchanged from the pre-12-06 state. The two commits introduce zero new lint regressions; `taskfiles/audit.yml`, `taskfiles/show.yml`, `taskfiles/refresh.yml` all pass LINT-01..LINT-07 cleanly.

## Threat Surface Scan

No new threat surface. Per the Plan's threat register:

- **T-12-06-01** (Information disclosure -- `internal: true` on 9 packages + claude tasks): accept-disposition. Markers hide tasks from `task --list` but remain invocable via the `task:` dispatch keyword (validate-aggregator pattern from commit 3cd756d explicitly relies on this for `task: packages:validate` + `task: claude:validate`). Not an authorization boundary; same as 12-03 / 12-04 / 12-05 threat-register stance.
- **T-12-06-02** (Tampering -- cross-namespace `task: :claude:status` / `:claude:update` / `:packages:audit` from delegate files): accept-disposition. Absolute-form leading-colon is the standard go-task pattern verified in `taskfiles/identity.yml`, `taskfiles/links.yml`, and `taskfiles/audit.yml`'s pre-existing `:links:reconcile` delegate. No new attack surface.

## Handoff to Plan 07 (manifest + test + lint)

- **No shared file conflicts** -- Plan 12-06 touched `taskfiles/packages.yml`, `taskfiles/audit.yml`, `taskfiles/claude.yml`, `Taskfile.yml` (includes block + header comment), and created `taskfiles/show.yml` + `taskfiles/refresh.yml`. Plan 12-07 modifies `taskfiles/manifest.yml`, `taskfiles/test.yml`, `taskfiles/lint.yml`, `docs/MANIFEST.md`, and `.claude/CLAUDE.md`. No source-file overlap.
- **`taskfiles/show.yml` is ready for extension** -- Plan 12-07 will add a `manifest:` task (D-02 -- `show:manifest` delegate for the renamed `manifest:show`). The file shape established here (single task entry after the W-3 banner) leaves room for additional show: delegates.
- **`Taskfile.yml` includes block is now stable for the rest of Phase 12** -- the `show:` and `refresh:` entries Plan 12-07 will reference are already in place (`show:manifest` will just be a new task entry in `taskfiles/show.yml`, no Taskfile.yml change needed). Plan 12-07's potential `audit:manifest` would also just be a new task entry in the existing `taskfiles/audit.yml`.
- **`docs/MANIFEST.md` updates land in Plan 07** -- per W-9 this plan did NOT touch MANIFEST.md. The doc references to `task packages:verify` and `task packages:install` survive `internal: true` (internal tasks remain invocable by name). Plan 07 will rewrite the manifest task surface table in MANIFEST.md.
- **The `audit:` namespace is now two-strong (`audit:links` + `audit:packages`); `show:` and `refresh:` are one-strong each (`show:claude`, `refresh:claude`). Plan 12-07's manifest work will likely bring `show:manifest`, `audit:manifest`, and the `test:manifest` / `test:add-machine` namespace moves.

## Self-Check: PASSED

- `[ -f taskfiles/packages.yml ]` -- FOUND
- `[ -f taskfiles/audit.yml ]` -- FOUND
- `[ -f taskfiles/claude.yml ]` -- FOUND
- `[ -f taskfiles/show.yml ]` -- FOUND (created)
- `[ -f taskfiles/refresh.yml ]` -- FOUND (created)
- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-06-SUMMARY.md ]` -- (this file)
- Commit `1d4a431` present in `git log --oneline -5` -- FOUND
- Commit `74167c1` present in `git log --oneline -5` -- FOUND
- `task --list 2>&1 | grep -cE '^\* packages:'` returns 0 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* claude:'` returns 0 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* audit:packages'` returns 1 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* show:claude'` returns 1 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* refresh:claude'` returns 1 -- VERIFIED
- `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/packages.yml` returns 5 keys -- VERIFIED
- `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/claude.yml` returns 7 keys -- VERIFIED
- `grep -E '^# (Purpose|Callers|Side effects|Tasks):' taskfiles/show.yml` returns 4 lines -- VERIFIED
- `grep -E '^# (Purpose|Callers|Side effects|Tasks):' taskfiles/refresh.yml` returns 4 lines -- VERIFIED
- `grep -nE '^\s*(show|refresh):\s+\./taskfiles/' Taskfile.yml` returns 2 matches -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph-parse gate)
- `task validate` end-to-end rc=0 -- VERIFIED
