---
phase: 08-validation-cutover-readiness
fixed_at: 2026-05-16T00:00:00Z
review_path: .planning/phases/08-validation-cutover-readiness/08-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 8: Code Review Fix Report

**Fixed at:** 2026-05-16
**Source review:** .planning/phases/08-validation-cutover-readiness/08-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (4 critical + 4 warning; info skipped per fix_scope)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: bootstrap.zsh exits 1 on fresh machine; documented procedure cannot complete

**Files modified:** `install/cutover-gate.zsh`, `README.md`
**Commit:** 30477ac
**Applied fix:** Option B (code matches docs). Changed `cutover_gate_check` so a missing `$XDG_STATE_HOME/dotfiles/machine` file returns 0 instead of `error "no machine selected"` + `return 1`. Updated the function header comment to document the fresh-machine semantics: the gate's purpose is to protect existing v1 installs being cut over, not to fail bootstrap on a clean Mac; enforcement still fires on `task install` via the precondition once `task setup` has written the machine file. Also tightened the README "Fresh Machine Setup" prose to reflect that `bootstrap.zsh` itself completes cleanly on a fresh machine and `task install`'s precondition is what hard-fails when the ack sentinel is missing.

### CR-02: marketplace status block tests .name; install/validate test .id

**Files modified:** `taskfiles/claude.yml`
**Commit:** 7e8f3f3
**Applied fix:** Changed the `marketplace:` task's status-block plugin selector from `.name == "ecc@ecc"` to `.id == "ecc@ecc"` so the status check, install body (line 150), and validate body (line 277) all use `.id` consistently. Added an inline comment flagging the cross-reference between the three sites so a future refactor cannot silently desynchronize them. Preserves the two-condition idempotency contract from the file header (D-12 / CLDE-04).

### CR-03: claude:validate exits 0 on missing CLI, root aggregator renders green

**Files modified:** `taskfiles/claude.yml`
**Commit:** d226211
**Applied fix:** Replaced the bare `exit 0` after `cross "claude CLI missing"` with an `rc` accumulator (`rc=0` initialization, `rc=1` on each missing CLI), and added `exit "$rc"` at the end of the cmds[0] block. Same pattern applied to the `jq` check below it (which was previously not setting any failure flag either). Aggregator now correctly renders the claude row as cross when either CLI is missing.

### CR-04: configs: status block omits ghostty, short-circuits ghostty:configs

**Files modified:** `taskfiles/links.yml`
**Commit:** 2f52d82
**Applied fix:** Added a gated inline-ternary entry to the `configs:` status block mirroring the `claude:` pattern at lines 204-216: `'{{if not (index .MANIFEST.features "ghostty")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/ghostty/config"{{end}}'`. On a `ghostty=false` machine the ternary renders `true` (status passes, no work needed); on a `ghostty=true` machine the ternary renders the `test -L` check, so a broken ghostty link forces the cmds block to run and `task: configs:ghostty` is invoked. Closes the partial-state regression class the file's own header warns about.

### WR-01: claude.yml uses bare `manifest:resolve` in three deps; only validate uses leading-colon form

**Files modified:** `taskfiles/claude.yml`
**Commit:** 8adf7de
**Applied fix:** Converted three deps entries to the leading-colon form for namespace consistency with the existing `validate:` declaration and with `links.yml`'s five-occurrence pattern:
- `install:` -- `deps: [":manifest:resolve"]`
- `marketplace:` -- `deps: ["ensure-cli", ":manifest:resolve"]`
- `update:` -- `deps: ["ensure-cli", ":manifest:resolve"]`

Local sibling deps (`ensure-cli`) intentionally retain the bare form since they reference tasks within the same included file. Root-taskfile bare references (Taskfile.yml:141, 294) also retain the bare form per the review's "no change required" note -- root is unambiguous by definition.

### WR-02: CUTOVER.md framing implies symmetric n/a; only claude:validate emits the sentinel

**Files modified:** `docs/CUTOVER.md`
**Commit:** 27dd68d
**Applied fix:** Rewrote step 6 prose to (a) require all six rows to show `check` OR `n/a`, (b) state explicitly that ONLY `claude:validate` emits the `feature disabled -- skipped` sentinel substring rendered as `n/a`, and (c) clarify that the other per-component validates return `check` when their feature flags are off because they internally no-op feature-gated work rather than emitting a separate skip marker. Both forms are documented as passing. Reflects the actual codebase behavior surveyed by the reviewer's grep.

### WR-03: links:reconcile case statement has no default branch

**Files modified:** `taskfiles/links.yml`
**Commit:** 1e4f153
**Applied fix:** Added an explicit `*) ... ;;` catch-all to the mode-dispatch case statement that prints `error "links:reconcile: internal bug -- unknown mode '$mode'"` and exits 1. The defensive comment in the new branch documents that the three valid modes (detect, warn, remove) are exhaustive given the initialization + the two case mutators, and that this branch surfaces a future flag-parsing bug or refactor mistake as a hard error rather than a silent no-op.

### WR-04: validate: aggregator runs each per-component validate twice

**Files modified:** `Taskfile.yml`
**Commit:** 6acddd4
**Applied fix:** Refactored the aggregator from two phases (six `task: <component>:validate` calls with `ignore_error: true` for visible output, then a for-loop with six `$(task ...)` captures) to a single-pass design. Each validate runs ONCE; output is teed via `tee` to terminal AND a per-component cache file under `mktemp -d`. Exit codes are captured via `${PIPESTATUS[0]}` into per-component shell variables (`rc_manifest`, `rc_identity`, ...). The summary block reads the cache file for sentinel detection (`feature disabled -- skipped`) and the exit-code variable for check/cross decision. A `trap 'rm -rf "$cache_dir"' EXIT` guarantees cleanup even on catastrophic validate failure. Also updated the task-level comment block to document the new design and eliminate the now-stale `ignore_error: true` reference.

**Note (logic verification):** WR-04 changes runtime control flow (single-pass vs double-pass) and shell-variable naming via `eval`. Recommend the human verifier run `task validate` on a real machine (personal-laptop or server-1) and confirm: (1) each component prints output once not twice, (2) the summary table renders correctly, (3) on server-1 the claude row shows `n/a`, and (4) exit code is 0 when all validates pass and non-zero when any fails.

## Skipped Issues

None -- all 8 in-scope findings were successfully fixed.

---

_Fixed: 2026-05-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
