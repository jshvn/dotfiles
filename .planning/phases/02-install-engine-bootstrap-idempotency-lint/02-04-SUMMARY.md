---
plan: 02-04
status: complete
completed: 2026-05-13
phase: 02-install-engine-bootstrap-idempotency-lint
---

# Plan 02-04 Summary: Cutover-Gate + Taskfile.yml Rewrite + Bootstrap Wire-Up

## What was built

Three deliverables that establish the v2 cutover-ack gate as a
defense-in-depth contract per D-07/D-09 and unify `task install` as the
canonical install entry per D-10:

1. **`install/cutover-gate.zsh`** — sourced library exporting
   `cutover_gate_check()`. Reads `$XDG_STATE_HOME/dotfiles/machine` and
   `cutover-ack` (single-line: `<machine-name> <ISO-8601-timestamp>`),
   returns 0 on valid sentinel and 1 on missing/malformed/mismatched.
   Library style per D-14: no execute bit, no `set -euo pipefail`.
   Double-source guard via `DOTFILES_CUTOVER_GATE_LOADED`. The emit_error
   helper prints an actionable block referencing `task cutover:ack -- <name>`
   and `docs/CUTOVER.md`. Verified across all four cases.

2. **`Taskfile.yml`** rewritten per RESEARCH §4.1:
   - Drops `update:` (D-10 — `task install` IS `task update`).
   - Drops `validate:` (deferred to Phase 8).
   - Drops `clean:` (out of P2 scope; v1 leftover).
   - Drops profile-suffixed includes; manifests replace the profile model.
   - Includes block wires `manifest` (P1, real) + `lint` (P2, real) +
     four stub taskfiles (`links/brew/claude/macos`) shipped by Plan 02-02.
   - `install` task has `preconditions:` sourcing the gate library and
     calling `cutover_gate_check`. Read-only tasks (`lint:*`,
     `manifest:show`, etc.) remain ungated per D-09.
   - `install` task has `deps: [manifest:manifest:resolve]` — the doubled
     `manifest:` prefix is a P1 nomenclature wart out of P2 scope to fix.

3. **`bootstrap.zsh`** — replaces Plan 02-03's `TODO(Plan 02-04)` marker
   with `source ${DOTFILEDIR}/install/cutover-gate.zsh` +
   `cutover_gate_check || exit 1`. Placement: after the brew/task/yq
   installs (so tools are available on a not-yet-cut-over machine) and
   before the next-step hint print.

## Key files created

- `install/cutover-gate.zsh` (sourced library; 74 lines)

## Key files modified

- `Taskfile.yml` — full rewrite (97 lines, down from 170)
- `bootstrap.zsh` — TODO marker replaced with live source + gate call
- `taskfiles/lint.yml` — inline fix: `DOTFILEDIR: sh:dirname` over
  `{{.TASKFILE_DIR}}` instead of the broken `dirname-twice realpath`
  pattern. The broken pattern (shipped by Plan 02-01, originally copied
  from manifest.yml) stomped the parent Taskfile.yml DOTFILEDIR var
  on include merge, breaking the cutover-gate sourcing path.

## Verification

| Check | Result |
|-------|--------|
| `zsh -n install/cutover-gate.zsh` | OK |
| `zsh -n bootstrap.zsh` | OK |
| `task --list-all --json` parses | OK (exit 0) |
| `task --list-all` shows `update` | NOT PRESENT (D-10) |
| `task --list-all` shows `install` | PRESENT |
| Cutover gate: valid ack | returns 0 |
| Cutover gate: missing ack | returns 1 with actionable error |
| Cutover gate: malformed ack | returns 1 with actionable error |
| Cutover gate: mismatched machine | returns 1 with actionable error |
| Cutover gate: double-source idempotent | yes |
| `task install` precondition with valid ack | gate passes |
| `task install` with missing ack | exits non-zero, gate fires |
| `task lint:*` without ack | runs (NOT gated per D-09) |
| `task manifest:manifest:show` without ack | runs (NOT gated per D-09) |
| `./bootstrap.zsh` with no ack | exits 1 with actionable refs |
| `./bootstrap.zsh` with valid ack | exits 0; prints next-step hint |

## Notable deviations

1. **Inline fix to `taskfiles/lint.yml`** — Plan 02-01's DOTFILEDIR
   sh-block used `dirname dirname realpath` which produces wrong paths
   under go-task vars-evaluation context. Switched to
   `dirname "{{.TASKFILE_DIR}}"`. The same fix should be applied to
   P1's `taskfiles/manifest.yml` in P1 follow-up work.

2. **`deps: [manifest:manifest:resolve]`** instead of the spec's
   `deps: [manifest:resolve]`. The actual reachable task name is the
   doubled form because P1's manifest.yml names its tasks
   `manifest:resolve:` and the includes block prefixes with `manifest:`.

3. **`{{.TASKFILE_DIR}}` instead of `{{.DOTFILEDIR}}`** in the
   precondition sh: block. P1's manifest.yml DOTFILEDIR sh-var stomps
   the parent's DOTFILEDIR on include merge; using `{{.TASKFILE_DIR}}`
   directly bypasses that.

4. **LINT-08 DEPRECATED per D-11.** No timing test ships; LINT-01's
   structural status: contract (enforced by Plan 02-01) is the
   idempotency guarantee.

## Carry-forward (out of P2 scope)

- `taskfiles/manifest.yml` has the same broken DOTFILEDIR pattern; its
  load-time `MANIFEST_JSON` warning prints `/resolved.json missing or
  empty` because XDG_STATE_HOME also resolves empty in its include
  context. The gate itself is unaffected (it uses zsh shell-env
  XDG_STATE_HOME with `:-` fallback in the cutover-gate function body).
- v1 leftover taskfiles (`common.yml`, `profile.yml`, `brew.yml`,
  `claude.yml`, `links.yml`, `macos.yml`, `profile-tasks.yml`) remain
  on disk and fail Plan 02-01's lint:taskfile checks. They are NOT
  included by v2 Taskfile.yml. Phases 3 / 5 / 6 / 7 remove them as each
  replaces the corresponding component.

## Self-Check: PASSED

All success criteria from the plan met. Gate fires correctly at both
enforcement points (bootstrap.zsh AND task install preconditions) per
D-09 defense-in-depth. Read-only tasks remain ungated per D-09.
