---
phase: 12-task-surface-redesign
plan: 05
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-03, d-01, d-04, d-09, d-10, b-9]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01, 12-03]
  provides:
    - "macos:install (internal aggregator -- NEW; D-09)"
    - "macos:apply-defaults (internal aggregator; renamed from macos:defaults)"
    - "macos:apply-defaults:{dock,finder,input,screenshots,security} (internal sub-tasks; renamed in lockstep per B-9)"
    - "macos:install-shell (internal sub-target; renamed from macos:shell)"
    - "macos:validate (internal mark; name unchanged)"
    - "Taskfile.yml install: body collapses macos:defaults + macos:shell -> macos:install (D-09 / Pattern 7)"
  affects: [taskfiles/macos.yml, Taskfile.yml, docs/MACHINES.md]
tech_stack:
  added: []
  patterns:
    - "internal-mark pattern (D-01) applied to 9 macos tasks (new aggregator + 8 existing)"
    - "aggregator creation pattern (D-09 / Pattern 3) -- new macos:install fingerprint mirrors identity:install (5-element shape)"
    - "verb-first sub-target rename pattern (D-10) -- defaults -> apply-defaults; shell -> install-shell"
    - "B-9 lockstep sub-task rename -- literal task names defaults:<concern> renamed to apply-defaults:<concern>"
    - "callers-first commit discipline (D-04) -- Taskfile.yml install body updated in the same commit as the callees were renamed"
    - "single-commit shape (no two-commit split needed) -- all callees + their caller live inside the same scoped change"
key_files:
  created: []
  modified:
    - taskfiles/macos.yml
    - Taskfile.yml
    - docs/MACHINES.md
decisions:
  - "Applied D-09 by CREATING macos:install (no existing aggregator inside taskfiles/macos.yml); placed at the top of the tasks: block before apply-defaults aggregator -- aggregator-before-sub-target ordering matches Pattern 3 fingerprint"
  - "Applied D-10 + D-01 to defaults aggregator: defaults -> apply-defaults + internal: true (macOS uses apply- for non-install actions)"
  - "Applied B-9 lockstep rename: five literal task names (defaults:dock/finder/input/screenshots/security) renamed to apply-defaults:<concern>; parent's cmds: block sibling refs updated in lockstep"
  - "Applied D-10 + D-01 to shell sub-target: shell -> install-shell + internal: true (shell registration IS an install action)"
  - "Applied D-01 to validate (kept name; marked internal)"
  - "Applied Pattern 7 recommendation: Taskfile.yml install: body collapses the two consecutive calls (macos:defaults + macos:shell) to single - task: macos:install"
  - "Updated docs/MACHINES.md atium-section bullet: task macos:defaults -> task macos:apply-defaults"
  - "Single commit (476dac4) rather than two: callee renames + caller updates ship together. The aggregator's cmds: refs are short-form (apply-defaults / install-shell) which resolve to the renamed sibling keys defined in the same file; the cross-file caller (Taskfile.yml install body) references macos:install (the new aggregator) which is also defined in this commit. No intermediate state where any caller points at a non-existent callee."
  - "Header banner comment updated for both apply-defaults parent (one-line note) and install-shell (one-line note); install aggregator comment block added explaining D-09 / replaces two-call pattern; Dependencies sub-block at file head updated to reference macos:apply-defaults:<concern> + macos:install-shell"
metrics:
  duration: ~5 minutes
  tasks_completed: 1/1
  commits: 1
  files_created: 0
  files_modified: 3
  completed_date: 2026-05-18
---

# Phase 12 Plan 05: macos namespace rename + new macos:install aggregator Summary

Created the new `macos:install` aggregator (D-09; the first aggregator inside `taskfiles/macos.yml`) and renamed the entire `macos:` namespace per D-10 (sub-targets gain verb-first names: `defaults` -> `apply-defaults`, `shell` -> `install-shell`) + D-01 (per-component install / apply-defaults / install-shell / validate all marked `internal: true`) + B-9 (lockstep rename of the five literal-named `defaults:<concern>` sub-tasks to `apply-defaults:<concern>`). The `Taskfile.yml` install body collapses the two consecutive calls (`macos:defaults` + `macos:shell`) to a single `- task: macos:install` call per Pattern 7. Public `macos:*` surface now contains zero rows; the operator-facing macos install path runs entirely through the root `task install` aggregator.

## What changed

### Commits (1)

| # | Commit  | Type | Description                                                                                                |
|---|---------|------|------------------------------------------------------------------------------------------------------------|
| 1 | 476dac4 | feat | add macos:install aggregator + rename macos:defaults family -> apply-defaults + macos:shell -> install-shell |

### Files modified

- **`taskfiles/macos.yml`** -- 9 task definitions touched + 4 comment-block updates:
  - **NEW** `install:` aggregator (D-09; placed at top of `tasks:` block before `apply-defaults`): `desc:` one-liner, `internal: true`, `platforms: [darwin]`, `deps: [":manifest:resolve"]`, `cmds:` invokes `apply-defaults` then `install-shell`. Carries `# lint-allow: cmds-without-status` marker.
  - `defaults:` -> `apply-defaults:` (aggregator): `internal: true` added after `desc:`; cmds: block sibling refs renamed in lockstep (`- task: defaults:dock` -> `- task: apply-defaults:dock`, etc., 5 lines).
  - `defaults:dock:` -> `apply-defaults:dock:` (literal task key rename; body unchanged -- already `internal: true`).
  - `defaults:finder:` -> `apply-defaults:finder:` (same).
  - `defaults:input:` -> `apply-defaults:input:` (same).
  - `defaults:screenshots:` -> `apply-defaults:screenshots:` (same).
  - `defaults:security:` -> `apply-defaults:security:` (same).
  - `shell:` -> `install-shell:` (sub-target): `internal: true` added after `desc:`; vars/cmds/status blocks unchanged.
  - `validate:` (aggregator; kept name): `internal: true` added after `desc:`; cmds block unchanged.
  - Header banner `Dependencies:` sub-block at file head updated to reference `macos:apply-defaults:<concern>` and `macos:install-shell` (instead of `macos:defaults:<concern>` and `macos:shell`).
  - Status-block-convention comment updated to list current aggregator-style task names (`install, apply-defaults, validate`).
  - Per-concern feature-gate-pattern comment updated to reference `macos:apply-defaults:<concern>`.
  - The five v1 `macos:shell:145` bug-class references stay as-is (they are CONCERNS.md historical identifiers, not current task names).

- **`Taskfile.yml`** (install: body, 2 lines -> 1 line):
  - Removed `- task: macos:defaults` and `- task: macos:shell` (the two consecutive lines per Pattern 7).
  - Inserted `- task: macos:install` in their place (single call to the new aggregator).
  - cmds: list length reduced by one entry; surrounding `- task: claude:install` and `- task: packages:verify` lines unchanged.

- **`docs/MACHINES.md`** (one bullet in atium-section, line 67):
  - `task macos:defaults` -> `task macos:apply-defaults` (D-10 rename surfaces in the operator-facing doc).

### Live verification (post-plan)

```text
$ task --list 2>&1 | grep -cE '^\* macos:'
0

$ task --list-all 2>&1 | grep -cE '^\* macos:'
0  # go-task 3.51.1 hides internal: true tasks from BOTH --list and --list-all
   # (same nuance documented in 12-03 and 12-04 SUMMARYs)

$ task --list-all >/dev/null 2>&1; echo $?
0  # graph-parse gate: every renamed callsite resolves in the compiled task graph

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/macos.yml
- install
- apply-defaults
- apply-defaults:dock
- apply-defaults:finder
- apply-defaults:input
- apply-defaults:screenshots
- apply-defaults:security
- install-shell
- validate

$ grep -cE '^\s+defaults(:|$)' taskfiles/macos.yml
0  # no old defaults key remains

$ grep -cE '^\s+defaults:(dock|finder|input|screenshots|security):' taskfiles/macos.yml
0  # no old defaults:<concern> key remains

$ grep -nE '^\s+(install|apply-defaults|install-shell|validate)(:|$)' taskfiles/macos.yml
111:  install:
129:  apply-defaults:
165:  apply-defaults:dock:
179:  apply-defaults:finder:
193:  apply-defaults:input:
207:  apply-defaults:screenshots:
221:  apply-defaults:security:
236:  install-shell:
272:  validate:

$ grep -nE '^\s+- task: macos:' Taskfile.yml
179:      - task: macos:validate         # inside validate aggregator (unchanged)
200:      - task: macos:install           # NEW: collapses macos:defaults + macos:shell

$ grep -cE '^\s+-\s+task:\s+macos:(defaults|shell)\s*$' Taskfile.yml
0

$ grep -nE 'task macos:' docs/MACHINES.md
67:  `macos-security` defaults concern runs as part of `task macos:apply-defaults`.

$ task validate; echo $?
[...full per-component output, including the validate-aggregator's
  task: macos:validate dispatch hitting the now-internal validate task...]
0

$ git rev-parse --short HEAD
476dac4
```

- Zero `macos:*` rows in `task --list` (every macos task is internal per D-01).
- 9 internal task keys declared inside `taskfiles/macos.yml`: 1 new aggregator (`install`), 1 renamed aggregator (`apply-defaults`), 5 renamed sub-tasks (`apply-defaults:<concern>`), 1 renamed sub-target (`install-shell`), 1 kept-name (`validate`).
- Old keys (`defaults:`, `defaults:dock:`, `defaults:finder:`, `defaults:input:`, `defaults:screenshots:`, `defaults:security:`, `shell:`) all gone from the YAML.
- `Taskfile.yml` install body has exactly one `- task: macos:install` line; zero `- task: macos:defaults` or `- task: macos:shell` lines.
- `docs/MACHINES.md` atium-section bullet now references `task macos:apply-defaults`.
- `task --list-all` exits 0 -- graph-parse gate confirms every renamed callsite resolves: aggregator's sibling refs (`task: apply-defaults` / `task: install-shell`) find the renamed sub-target keys; the cross-file caller (`Taskfile.yml` install body `- task: macos:install`) resolves to the new aggregator.
- `task validate` runs end-to-end with rc=0; the now-internal `macos:validate` is invoked via the `task:`-dispatch aggregator from commit 3cd756d (12-02 Known Issue resolved before 12-03 ran).

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed exactly as written.

### Verification command substitution (informational)

The Plan's automated verify block uses `task --list-all` checks (`grep -cE 'macos:(install|apply-defaults|install-shell|validate)$' >=4` and `apply-defaults:(dock|finder|input|screenshots|security) == 5`). As 12-03 and 12-04 SUMMARYs documented, go-task 3.51.1 hides `internal: true` tasks from `task --list-all` too -- both `--list` and `--list-all` show only public surface. Verification used the same substitute pattern:

1. `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/macos.yml` enumerates the nine internal task keys directly from the YAML (covers the new aggregator + renamed aggregator + 5 renamed sub-concerns + renamed install-shell + kept-name validate).
2. `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- confirms every `task:` ref in the compiled graph resolves (the "graph-parse gate" the Plan explicitly references).
3. `task validate` end-to-end rc=0 -- confirms the now-internal `macos:validate` is invocable via the rewritten aggregator (resolved 12-02 Known Issue).

This is a verification-command nuance, NOT a deviation from the executed work. All Plan acceptance criteria (renamed task keys present in YAML, internal-flag added on the new aggregator + 4 renamed/kept-name tasks, B-9 sub-task renames complete, aggregator cmds: retargeted, callsites updated, lint-green for new edits, graph-parse gate passes) hold.

## Known Issues

None new. The pre-existing `task lint:taskfile` failures documented in 12-02 / 12-03 / 12-04 SUMMARYs remain unchanged:

- LINT-02 failures: `taskfiles/claude.yml`, `taskfiles/identity.yml`, `taskfiles/manifest.yml`, `taskfiles/packages.yml`. **All pre-existing.** `taskfiles/macos.yml` passes LINT-02 cleanly (`✓ LINT-02: taskfiles/macos.yml`).
- LINT-03a failures: 5 manifest.yml task-blocks (`setup`, `show`, `validate`, `test`, `test:add-machine`); 1 shell.yml task (`startup-time`). All pre-existing.
- LINT-03b: 1 doc-mention in `taskfiles/README.md`. Pre-existing (a documentation string, not a real `ln -s` call).

Plan 12-05's single commit introduces zero new lint regressions:

- The new aggregator-style internal `install:` task has the `# lint-allow: cmds-without-status` marker on the line immediately above and `cmds:` is entirely `task:` delegations (LINT-03a auto-exempt).
- The renamed aggregator-style internal `apply-defaults:` task also retains the marker (carried over from the original `defaults:` block) and `cmds:` is entirely `task:` delegations.
- The renamed `validate:` aggregator already had the marker (line 256) -- carried unchanged.
- The five renamed sub-tasks `apply-defaults:<concern>` retain their existing `status:` blocks unchanged (LINT-01 stays green for those; they were already `internal: true`).
- The renamed sub-target `install-shell:` retains its `status:` block unchanged (LINT-01 + LINT-02 still green -- both entries use `{{.BREW_ZSH}}` and `{{.USER_NAME}}` template vars, the canonical structural fix for the v1 `macos:shell:145` bug class).

## Lint Compliance

`task lint` baseline failures unchanged. The Plan 12-05 commit introduces zero new lint regressions; `taskfiles/macos.yml` continues to pass every lint rule (LINT-01..LINT-07).

## Threat Surface Scan

No new threat surface. Per the Plan's threat register:

- **T-12-05-01** (Tampering -- sibling resolution in `apply-defaults` cmds: block): mitigate-disposition. B-9 empirically confirmed (via `taskfiles/macos.yml:142,156,170,184,198` in the original file) that the five sub-task keys are LITERAL task names, NOT nested under the `defaults:` parent. Renamed in lockstep with the parent + the parent's cmds: block. No go-task sibling-resolution risk.
- **T-12-05-02** (Information disclosure -- `internal: true` on 4 macos tasks): accept-disposition. Markers hide tasks from `task --list` but remain invocable via the `task:` dispatch keyword (the validate-aggregator pattern from commit 3cd756d explicitly relies on this for `task: macos:validate`). Not an authorization boundary; same as 12-03 / 12-04 threat-register stance.

## Handoff to Plan 06 (packages + claude)

- **No shared file conflicts** -- Plan 12-05 touched `taskfiles/macos.yml`, `Taskfile.yml` (install body), and `docs/MACHINES.md`. Plan 12-06 modifies `taskfiles/packages.yml`, `taskfiles/claude.yml`, and extends `taskfiles/audit.yml`. No overlap.
- **Taskfile.yml install body is now stable for the rest of Phase 12** -- the four `- task: <ns>:install` lines (`links:install`, `packages:install`, `claude:install`, `macos:install`) all point at the canonical D-09 `:install` aggregator pattern. Plan 12-06's packages + claude work touches the callees inside those taskfiles but does NOT change the Taskfile.yml install body callsite (`packages:install` and `claude:install` keep their names; only their internal: flag and sub-task surface are touched).
- **`audit:` namespace is ready for extension** -- Plan 12-03 created `taskfiles/audit.yml` with the single `audit:links` delegate; Plan 12-06 can add `audit:packages` as a new task entry in the same file (the file shape is intentionally minimal in 12-03 to leave room for additional audit delegates).
- **`show:` and `refresh:` namespaces are NEW for Plan 12-06** -- the audit: namespace was bootstrapped by 12-03 as a new public namespace; 12-06 introduces `show:claude` and `refresh:claude` as additional D-02 / D-03 public delegates. Plan 12-06 will decide whether to create dedicated `taskfiles/show.yml` / `taskfiles/refresh.yml` or to define `show:claude` / `refresh:claude` inside `taskfiles/claude.yml` (then expose via the include alias -- the include-alias-as-namespace pattern). Recommendation: dedicated files mirror the audit: bootstrap; the operator surface separation (audit / show / refresh / test) reads more cleanly.

## Self-Check: PASSED

- `[ -f taskfiles/macos.yml ]` -- FOUND
- `[ -f Taskfile.yml ]` -- FOUND
- `[ -f docs/MACHINES.md ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-05-SUMMARY.md ]` -- (this file)
- Commit `476dac4` present in `git log --oneline -5` -- FOUND
- `task --list 2>&1 | grep -cE '^\* macos:'` returns 0 -- VERIFIED
- `grep -cE '^\s+defaults(:|$)' taskfiles/macos.yml` returns 0 -- VERIFIED (no old defaults key remains)
- `grep -cE '^\s+defaults:(dock|finder|input|screenshots|security):' taskfiles/macos.yml` returns 0 -- VERIFIED
- `grep -nE '^\s+(install|apply-defaults|install-shell|validate)(:|$)' taskfiles/macos.yml` shows 10 new/renamed keys -- VERIFIED
- `yq '.tasks.install.internal' taskfiles/macos.yml` returns true -- VERIFIED
- `yq '.tasks["apply-defaults"].internal' taskfiles/macos.yml` returns true -- VERIFIED
- `yq '.tasks["install-shell"].internal' taskfiles/macos.yml` returns true -- VERIFIED
- `yq '.tasks.validate.internal' taskfiles/macos.yml` returns true -- VERIFIED
- `yq '.tasks["apply-defaults:dock"].internal' taskfiles/macos.yml` returns true -- VERIFIED (and same for finder/input/screenshots/security)
- `grep -nE '^\s+- task: macos:install' Taskfile.yml` matches -- VERIFIED
- `grep -cE '^\s+-\s+task:\s+macos:(defaults|shell)\s*$' Taskfile.yml` returns 0 -- VERIFIED
- `grep -n 'task macos:apply-defaults' docs/MACHINES.md` matches line 67 -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph-parse gate)
- `task validate` end-to-end rc=0 -- VERIFIED (now-internal `macos:validate` invoked via task: dispatch aggregator)
