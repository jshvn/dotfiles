---
phase: 12-task-surface-redesign
plan: 03
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-03, d-01, d-02, d-09, d-10]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01, 12-02]
  provides:
    - "links:install (internal aggregator; renamed from links:all)"
    - "links:install-zsh / install-claude / install-configs (internal sub-targets)"
    - "links:validate (internal mark)"
    - "links:reconcile (internal implementation)"
    - "audit:links (public delegate; first member of audit: namespace)"
    - "taskfiles/audit.yml (new public-diagnostics file)"
  affects: [Taskfile.yml, taskfiles/links.yml, taskfiles/audit.yml]
tech_stack:
  added: []
  patterns:
    - "internal-mark pattern (D-01) applied to 6 tasks across links: namespace"
    - "verb-first sub-target rename pattern (D-10) -- zsh -> install-zsh, etc."
    - "aggregator-as-internal pattern (D-09) -- :install is the convention"
    - "audit: namespace bootstrap (D-02) -- new public delegate over internal implementation"
    - "callers-first commit discipline (Phase 11 D-04) -- Taskfile.yml install body updated in the same commit as the callee rename"
key_files:
  created:
    - taskfiles/audit.yml
  modified:
    - taskfiles/links.yml
    - Taskfile.yml
decisions:
  - "Applied D-09 + D-01 to links:all -> renamed to links:install + marked internal"
  - "Applied D-10 + D-01 to three sub-targets: links:zsh/claude/configs -> links:install-zsh/install-claude/install-configs (all internal)"
  - "Applied D-01 to links:validate (kept name; marked internal)"
  - "Applied D-02 via B-2 final mechanic: links:reconcile stays as internal implementation in taskfiles/links.yml; public surface is audit:links delegate in new taskfiles/audit.yml"
  - "audit: include added at the alphabetical-first position of Taskfile.yml's includes block; header comment Includes: list updated with `audit (P12, real)` row"
metrics:
  duration: ~15 minutes
  tasks_completed: 2/2
  commits: 2
  files_created: 1
  files_modified: 2
  completed_date: 2026-05-18
---

# Phase 12 Plan 03: links namespace rename + audit:links delegate Summary

Renamed the entire `links:` namespace per D-09 (aggregator -> `:install`) + D-10 (sub-targets -> verb-first `install-<target>`) + D-01 (per-component install / validate / reconcile marked internal) and bootstrapped the `audit:` namespace with `audit:links` (B-2 final mechanic: thin delegate in new `taskfiles/audit.yml` over the now-internal `links:reconcile` implementation). Public `links:*` surface now contains zero rows; the operator-facing orphan-detection entrypoint is `task audit:links`. The two commits each leave a green-graph tree (callers-first per Phase 11 D-04).

## What changed

### Commits (2)

| # | Commit  | Type     | Description                                                                                                |
|---|---------|----------|------------------------------------------------------------------------------------------------------------|
| 1 | e898ac4 | refactor | rename links:all -> install + sub-targets to install-<target> + mark internal (D-01, D-09, D-10)            |
| 2 | 52e80ee | refactor | rename links:reconcile -> audit:links via taskfiles/audit.yml delegate (D-02)                              |

### Files modified

- **`taskfiles/links.yml`** -- six task-key edits and one comment-block update:
  - `all:` -> `install:` (aggregator; `internal: true` added; D-09 + D-01).
  - `zsh:` -> `install-zsh:` (`internal: true` added; D-10 + D-01).
  - `claude:` -> `install-claude:` (`internal: true` added; D-10 + D-01).
  - `configs:` -> `install-configs:` (`internal: true` added; D-10 + D-01).
  - `validate:` (kept name; `internal: true` added; D-01).
  - `reconcile:` (kept name; `internal: true` added; D-02 -- public path now via `audit:links`).
  - Aggregator `cmds:` block updated to call the new sibling short names (`install-zsh`, `install-claude`, `install-configs`); `:identity:install` absolute-form ref unchanged.
  - Header comment for the aggregator updated to reference D-09 / D-01.
  - Header comment for `reconcile:` updated with a "Public path: audit:links" note.

- **`taskfiles/audit.yml`** (NEW) -- public diagnostics namespace per D-02. Mandatory W-3 header banner (Purpose / Callers / Side effects / Tasks list). Single task `links:` whose `cmds:` invokes `:links:reconcile` with forwarded `CLI_ARGS`. Self-contained `vars:` block resolves `DOTFILEDIR` via `sh: dirname "{{.TASKFILE_DIR}}"`. `# lint-allow: cmds-without-status` marker present.

- **`Taskfile.yml`** -- three edits:
  - Header `Includes:` comment-block: added `#   - audit    (P12, real)` row (alphabetical first).
  - `includes:` block: added `  audit:    ./taskfiles/audit.yml` line as the alphabetical-first entry.
  - `install:` body (cmds: block):
    - `- task: links:all` -> `- task: links:install` (Plan callers-first; Commit 1).
    - `- task: links:reconcile` -> `- task: audit:links` (Plan callers-first; Commit 2). The `vars: { CLI_ARGS: "--warn-only" }` line below is unchanged -- the `audit:links` delegate forwards `CLI_ARGS` to `:links:reconcile`.

### Live verification (post-plan)

```text
$ task --list | grep -E '^\* (audit|links):'
* audit:links:                       Audit symlink drift (detect orphans); -- --remove for interactive cleanup

$ task --list-all >/dev/null 2>&1; echo $?
0

$ task validate; echo $?
[...per-component check/cross output...]
0

$ git rev-parse --short HEAD~1
e898ac4
$ git rev-parse --short HEAD
52e80ee
```

- Exactly one row prefixed `audit:` or `links:` in `task --list` (the `audit:links` delegate).
- Zero `links:install`, `links:install-zsh`, `links:install-claude`, `links:install-configs`, `links:validate`, `links:reconcile` rows in `task --list` (all `internal: true`).
- `task --list-all` exits 0 -- every renamed callsite resolves in the compiled task graph (graph-parse gate per Plan verification block).
- `task validate` runs end-to-end with rc=0; the now-internal `links:validate` is invoked via the rewritten `task:`-dispatch aggregator from commit 3cd756d (cf. 12-02 Known Issues).
- `task install` body's two changed lines (`links:install`, `audit:links`) match the Plan's "AFTER" target.

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed as written.

### Verification command substitution (informational)

The Plan's automated-verification snippet uses `task --list-all` to confirm "the renamed internals". In go-task 3.51.1 (this environment's installed version) `task --list-all` does NOT include `internal: true` tasks in its output -- both `--list` and `--list-all` show only public surface. The verification was performed by:

1. Reading `taskfiles/links.yml` via `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)'` to confirm the six internal tasks (`install`, `install-zsh`, `install-claude`, `install-configs`, `validate`, `reconcile`) are present with `internal: true`.
2. Running `task --list-all >/dev/null 2>&1; echo $?` -- exit 0 confirms every `task: <name>` ref in the compiled graph resolves (the "graph-parse gate" the Plan explicitly references).
3. Running `task validate` end-to-end and seeing the `links` row check off, confirming the internal `links:validate` is invocable via the rewritten aggregator.

This is documented as a verification-command nuance, NOT a deviation from the executed work. All Plan acceptance criteria (renamed task keys present in YAML, internal-flag added, callsites updated, lint-green) hold.

## Known Issues

None new. The pre-existing `task lint:taskfile` failures documented in 12-02-SUMMARY (LINT-02 in claude.yml/identity.yml/manifest.yml/packages.yml; LINT-03a in five manifest.yml tasks + the `startup-time` task in shell.yml; LINT-03b for a doc-string mention in taskfiles/README.md) remain unchanged. No new lint regressions introduced by the rename pass:

- `taskfiles/links.yml` continues to pass LINT-02 (`✓ LINT-02: taskfiles/links.yml`).
- `taskfiles/audit.yml` passes LINT-02 cleanly (`✓ LINT-02: taskfiles/audit.yml`).
- New aggregator task `links:install` has the `# lint-allow: cmds-without-status` marker on the line above and `cmds:` are entirely `task:` delegations (LINT-03a auto-exempt).
- New delegate task `audit:links` has the `# lint-allow: cmds-without-status` marker and `cmds:` is a single `task:` delegation.

The 12-02 Known Issue (D-01 mark-internal breaks the legacy bash-for-loop aggregator iteration) is resolved before this plan ran: commit 3cd756d rewrote the root `task validate` aggregator to dispatch via go-task's `task:` keyword + `ignore_error: true`, which bypasses the CLI-level `internal:` gate. This unblocked applying D-01 to `links:validate` in Plan 12-03 without re-introducing the broken-summary class.

## Lint Compliance

`task lint` baseline failures unchanged. The two commits introduce zero new lint regressions.

`task lint:taskfile` baseline (unchanged from 12-02-SUMMARY):

- LINT-02 failures: `taskfiles/claude.yml`, `taskfiles/identity.yml`, `taskfiles/manifest.yml`, `taskfiles/packages.yml`.
- LINT-03a failures: 5 manifest.yml task-blocks (`setup`, `show`, `validate`, `test`, `test:add-machine`); 1 shell.yml task (`startup-time`). All pre-existing.
- LINT-03b: 1 doc-mention in `taskfiles/README.md`. Pre-existing (a documentation string, not a real `ln -s` call).

## Threat Surface Scan

No new threat surface. Per the Plan's threat register:

- **T-12-03-01** (`internal: true` on six links: tasks): accept-disposition; documented as a visibility hint, NOT a defense-in-depth boundary. `internal: true` does prevent direct CLI-level invocation (cf. 12-02-SUMMARY "Actual behavior" finding) but does NOT prevent same-process `task:` dispatch from inside another task. The new `audit:links` public delegate explicitly relies on this behavior to call `task: :links:reconcile`.
- **T-12-03-02** (cross-namespace `task: :links:reconcile` from `audit:links`): accept-disposition; absolute-form leading-colon is the standard go-task cross-namespace call, well-established in `taskfiles/identity.yml` and `taskfiles/links.yml`'s aggregator's `:identity:install` ref.

## Handoff to next plan (12-04 identity namespace)

- No shared file conflicts -- Plan 12-04 modifies `taskfiles/identity.yml` exclusively; Plan 12-03 touched `taskfiles/links.yml`, `taskfiles/audit.yml` (new), and `Taskfile.yml`. The `Taskfile.yml` install body's identity-related lines (`- task: :identity:install` reference is in links.yml's aggregator, NOT the install body; the install body invokes `identity:install` only transitively via `links:install`'s aggregator cmds) -- no direct callsite collision.
- Plan 12-04 can follow the exact callers-first commit shape established here:
  1. Edit `taskfiles/identity.yml` to rename `git:`/`ssh:`/`one-password-agent:` to `install-git:`/`install-ssh:`/`install-one-password-agent:` with `internal: true`; mark `install:` and `validate:` internal.
  2. Update the aggregator `cmds:` block inside `taskfiles/identity.yml` to call the new sibling short names.
  3. No `Taskfile.yml` install-body line touches identity directly (`identity:install` is invoked from `links:install`'s aggregator cmds via `task: :identity:install`, already absolute-form; that ref stays unchanged because `identity:install` retains its name). 
- The `audit:` namespace established here can be extended in later plans (e.g., Plan 12-05 may add `audit:packages`; Plan 12-07 may add `audit:manifest`) by adding additional tasks to `taskfiles/audit.yml` -- the file is intentionally minimal in 12-03 to leave the surface uncluttered for later additions.

## Self-Check: PASSED

- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f taskfiles/links.yml ]` -- FOUND
- `[ -f taskfiles/audit.yml ]` -- FOUND (created)
- `[ -f .planning/phases/12-task-surface-redesign/12-03-SUMMARY.md ]` -- (this file)
- Commit `e898ac4` present in `git log --oneline -5` -- FOUND
- Commit `52e80ee` present in `git log --oneline -5` -- FOUND
- `task --list 2>&1 | grep -cE '^\* audit:links'` returns 1 -- VERIFIED
- `task --list 2>&1 | grep -cE '^\* links:reconcile'` returns 0 -- VERIFIED
- `grep -nE '^\s*audit:\s+\./taskfiles/audit\.yml' Taskfile.yml` matches -- VERIFIED
- `grep -n 'task: audit:links' Taskfile.yml` matches -- VERIFIED
- `grep -n 'task: links:install$' Taskfile.yml` matches -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph parse gate)
- `task validate` end-to-end rc=0 -- VERIFIED (now-internal `links:validate` invoked via task: dispatch aggregator)
