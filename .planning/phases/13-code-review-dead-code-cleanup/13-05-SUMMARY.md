---
phase: 13-code-review-dead-code-cleanup
plan: 05
subsystem: code-review
tags: [code-review, links, readlink, symlink-target-match, smoke-test, status-blocks]

requires:
  - phase: 13-code-review-dead-code-cleanup
    plan: 04
    provides: "13-REVIEW.md with row 14 (HIGH/correctness, REVW-05) and row 22 (MEDIUM/duplication) carrying defer markers pointing at Plan 13-05; helpers.yml in its post-Phase-12 shape (no _:check-link-target yet); links.yml status blocks using `test -L` existence-only checks across 26 entries"
provides:
  - "taskfiles/links.yml status blocks verify symlink TARGET via inline readlink -f against the manifest-expected source path (26 entries: 5 install-zsh + 13 install-claude + 7 install-configs + 1 configs:ghostty)"
  - "13-REVIEW.md row 14 (HIGH/correctness, REVW-05) closed by a2dcf40"
  - "13-REVIEW.md row 22 (MEDIUM/duplication) closed by a2dcf40 (correctness side; duplication shape preserved per the executable plan)"
  - "13-SMOKE.md authored with the deliberately-corrupted-symlink scenario (SC#4 minimum) at .planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md"
affects: [13-06-PLAN, 14-comment-doc-trim]

tech-stack:
  added: []
  patterns:
    - "Inline readlink -f target-match in status: blocks: `test -L \"<TARGET>\" && [[ \"$(readlink -f \"<TARGET>\")\" == \"<EXPECTED>\" ]]` -- gate-wrapper-preserved for feature-gated entries"
    - "Pre-flight gate-pattern: probe taskfile under /tmp before mass-rewriting the production file; verdict recorded to /tmp/13-05-preflight-verdict.txt and consumed by the subsequent rewrite task"
    - "Smoke-test scenario shape: numbered setup / action / assertion / cleanup steps with operator-fillable results log; self-contained (no PLAN.md re-reading required)"

key-files:
  created:
    - ".planning/phases/13-code-review-dead-code-cleanup/13-05-SUMMARY.md"
    - ".planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md"
  modified:
    - "taskfiles/links.yml"
    - ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md"

key-decisions:
  - "Pre-flight verdict: INLINE path (not HELPER). Probe found go-task 3.51.1 REJECTS `task:` invocations inside `status:` blocks at the schema level with 'invalid keys in command' / 'Incorrect type. Expected \"string\".' (the IDE YAML validator confirmed the same). Status blocks accept only shell-command strings, not task-invocation mappings. The HELPER-path recommendation in the plan was therefore not viable in this go-task version; the plan's INLINE fallback branch was taken without ambiguity. Consequence: helpers.yml WAS NOT MODIFIED in this plan; no `_:check-link-target` helper authored."
  - "Worktree-context safety: `{{.DOTFILEDIR}}` from this worktree resolves to the worktree root path (`.claude/worktrees/agent-ae349dc12c2954f62`), NOT the main repo. Production symlinks point at main-repo paths. Running `task install` from this worktree would re-link production state to point at the worktree -- destructive. The plan's verification step 5 ('run task install on the converged dev machine') was intentionally NOT executed from the worktree; idempotency was verified by `task --dry install` + a manual bash-level reproduction of the exact inline expression against the production .zshenv symlink (with main-repo DOTFILEDIR substitution -- returned EXIT=0; with worktree DOTFILEDIR -- returned EXIT=1, the correct false-positive-prevention behavior). The actual `task install` on the converged dev machine runs after this worktree merges back to main."
  - "Row 22 (the 13-entry duplication side of the REVW-05 defect) closed with the same SHA a2dcf40 as row 14, with an inline note that the duplication SHAPE PERSISTS (per-entry status array). Rationale: go-task `status:` arrays expect independent shell-command strings; the planner's optional aspiration of collapsing the 13 entries to a single for-loop status block was NOT in Plan 13-05's executable task list and would lose per-link diagnostic granularity in go-task's status-eval output. The duplication is a natural consequence of the status: array contract, analogous to Plan 13-04 row 22's keep-inline precedent (which was about manifest.yml CLI-arg-parse duplication; same rationale -- duplication that is the natural shape of the surrounding contract)."
  - "macOS readlink -f canonicalization caveat (T-13-05-03 mitigated): under `/tmp`, readlink -f resolves through the system `/tmp -> /private/tmp` symlink and returns `/private/tmp/...`. Under real `$XDG_CONFIG_HOME` (e.g., `/Users/josh/.config/...`), readlink -f returns the link target verbatim because there is no /tmp-style canonicalization needed. The inline-body fix is therefore correct in production; the 13-SMOKE.md procedure uses real XDG paths, not /tmp, so the canonicalization caveat does not affect the smoke test's assertions."
  - "Pre-flight probe directory at /tmp/13-05-probe -- NOT cleaned up at plan completion. Two cleanup attempts via `rm -rf /tmp/13-05-probe` were blocked by the runtime's fact-forcing destructive-command gate; the probe directory is scratch state in /tmp and will be cleared by macOS /tmp rotation. The pre-flight verdict file `/tmp/13-05-preflight-verdict.txt` remains in /tmp for the next continuation agent if needed (its content is also fully described in the Decisions section above)."

requirements-completed: [REVW-05, REVW-06]

duration: ~20min
completed: 2026-05-18
---

# Phase 13 Plan 05: links:* Target-Match Fix + 13-SMOKE.md Summary

**26 install-style status entries in `taskfiles/links.yml` now verify the symlink TARGET via inline `readlink -f` against the manifest-expected source (closes REVW-05 row 14 HIGH/correctness and row 22 MEDIUM/duplication). 13-SMOKE.md authored with the deliberately-corrupted-symlink Scenario 1 per SC#4. Pre-flight probe verdict was INLINE (go-task 3.51.1 rejects `task:` invocations inside `status:` blocks at schema level), so the HELPER path was skipped and `taskfiles/helpers.yml` is unchanged.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-18 (worktree spawn, post wave-4)
- **Completed:** 2026-05-18 (Self-Check completion)
- **Tasks:** 3 (Task 1 pre-flight probe; Task 2 inline rewrite + REVIEW.md annotation; Task 3 13-SMOKE.md authoring)
- **Files modified:** 3 (links.yml + 13-REVIEW.md + 13-SMOKE.md)
- **Commits:** 3 (1 fix + 2 docs)
- **Helper added:** NO (HELPER path not viable -- see Decision 1)

## Pre-flight Verdict

| Probe | Result | Action |
|-------|--------|--------|
| `task --version` >= 3.37 | 3.51.1 (PASS) | Both paths' minimum-version gate satisfied |
| `task:` mapping inside `status:` array works for `internal: true` helpers | **REJECTED** -- go-task errors with "invalid keys in command"; IDE schema validator errors with "Incorrect type. Expected \"string\"." | Take **INLINE** path; helpers.yml not modified |
| Inline `test -L X && [[ "$(readlink -f X)" == "Y" ]]` works | PASS under real XDG paths (returns exit 0 on match, exit 1 on mismatch) | Plan rewrite uses this shape verbatim |

Verdict recorded at `/tmp/13-05-preflight-verdict.txt` (per plan Task 1 step 6).

## Status-Entry Upgrade Counts

| Task | Entries Upgraded | Pattern |
|------|------------------|---------|
| `install-zsh` | 5 | Non-gated: `test -L "<T>" && [[ "$(readlink -f "<T>")" == "<E>" ]]` (one per zshenv/zprofile/zshrc/zlogin/zlogout) |
| `install-claude` | 13 | Feature-gated wrapper preserved: `{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}<inline expr>{{end}}` |
| `install-configs` | 7 | Mixed: ghostty entry gated on `ghostty`; 6 always-on entries unconditional |
| `configs:ghostty` | 1 | Gated on `ghostty` (isolated sub-task) |
| **Total** | **26** | (the /etc/zshenv grep -qF line in install-zsh stays unchanged -- not a symlink check) |

## REVIEW.md Row Closure

| Row | File | Severity | Category | Closed by | Notes |
|-----|------|----------|----------|-----------|-------|
| 14 | taskfiles/links.yml:155-160 | HIGH | correctness | `a2dcf40` | The 27-entry test -L bug; correctness side fixed by inline readlink -f rewrite |
| 22 | taskfiles/links.yml:240-252 | MEDIUM | duplication | `a2dcf40` | Duplication side of the same defect; correctness fix landed; per-entry duplication SHAPE PRESERVED (see Decision 3) |

After this plan: 0 HIGH rows have empty `closed by` column (verified by grep).

## Per-Commit List

| SHA | Type | Files Touched | Rows Closed |
|-----|------|---------------|-------------|
| `a2dcf40` | fix(13-05) | `taskfiles/links.yml` (+41 -26) | row 14 (correctness), row 22 (correctness side) |
| `46e77ea` | docs(13-05) | `.planning/.../13-REVIEW.md` (+2 -2) | annotation only |
| `156f91d` | docs(13-05) | `.planning/.../13-SMOKE.md` (new, +96 lines) | SC#4 deliverable |

## Accomplishments

- **REVW-05 closed end-to-end**: every links:* install-style status entry now verifies BOTH that the path is a symlink AND that its resolved target matches the manifest-expected source path. Corrupted symlinks (wrong target) now correctly force re-link instead of false-positive skipping.
- **REVW-06 (green tree after every commit) honored**: `task lint && task test` exit 0 after each of the three commits (LINT-05 portability hints in `os/shell-registration.zsh` and `os/defaults/_apply_verify.zsh` are pre-existing, non-blocking by lint-suite design).
- **SC#4 deliverable authored**: 13-SMOKE.md exists with the deliberately-corrupted-symlink procedure; operator can execute end-to-end without consulting PLAN.md or REVIEW.md.
- **Pre-flight gate-pattern proven**: probe-taskfile-under-/tmp-before-mass-rewrite caught the HELPER-path infeasibility before any production edits, saving a likely revert cycle.
- **Worktree-context safety preserved**: `task install` was NOT executed from the worktree (would corrupt production state by re-linking to the worktree path). Idempotency was verified by `task --dry install` + manual bash-level expression evaluation against the production `.zshenv` symlink (main-repo DOTFILEDIR substitution: EXIT=0; worktree DOTFILEDIR substitution: EXIT=1).

## Idempotency Verification (without running task install from the worktree)

Manual reproduction of the exact status block expression against the production `.zshenv` symlink:

```
$ ls -la ~/.config/zsh/.zshenv
lrwxr-xr-x  ...  /Users/josh/.config/zsh/.zshenv -> /Users/josh/Git/personal/dotfiles/shell/.zshenv

$ bash -c 'test -L "$HOME/.config/zsh/.zshenv" && \
  [[ "$(readlink -f "$HOME/.config/zsh/.zshenv")" == \
     "/Users/josh/Git/personal/dotfiles/shell/.zshenv" ]]'
$ echo $?
0   # Match -> status returns 0 -> cmds: skipped -> task install no-op on converged machine
```

The converged-machine no-op contract holds. Iteration loop (T-13-05-03 mitigation in the plan's threat model) was not required: the expression matched the production state on the first try.

## Files Modified

- `taskfiles/links.yml` -- 26 inline readlink -f target-match upgrades; 4 status: blocks rewritten (install-zsh, install-claude, install-configs, configs:ghostty); +41 -26 lines.
- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` -- row 14 + row 22 `closed by` columns populated with `a2dcf40` (+2 -2 lines).
- `.planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md` -- new file, 96 lines, deliberately-corrupted-symlink Scenario 1 + optional placeholders for Scenarios 2 + 3.

(Files NOT modified per the INLINE-path decision: `taskfiles/helpers.yml` -- the HELPER-path recommendation was probe-rejected; no `_:check-link-target` helper authored.)

## Decisions Made

1. **INLINE path taken (not HELPER) per pre-flight probe.** go-task 3.51.1 rejects `task:` invocations inside `status:` arrays at the schema level; status entries must be shell-command strings. The plan's HELPER path was therefore not viable; the INLINE fallback was executed without further branching. `taskfiles/helpers.yml` is unchanged.
2. **Worktree-context safety: `task install` not run from the worktree.** `{{.DOTFILEDIR}}` from the worktree resolves to the worktree path; production symlinks point at main-repo paths; running `task install` here would corrupt production state. Idempotency verified instead via `task --dry install` + manual bash-level expression evaluation against the production `.zshenv` symlink.
3. **Row 22 closed by the same SHA as row 14; per-entry duplication shape PRESERVED.** Rationale: status: arrays expect independent shell-command strings; collapsing the 13 entries to a single for-loop would lose per-link diagnostic granularity in go-task's status output. The duplication is the natural shape of the surrounding contract -- analogous to Plan 13-04 row 22's keep-inline precedent.
4. **macOS readlink -f /tmp canonicalization caveat documented for future debug context.** Probe surfaced this; production paths (`~/.config/...`) are unaffected; 13-SMOKE.md uses real XDG paths so its assertions are not affected by this caveat.
5. **Pre-flight probe directory at `/tmp/13-05-probe` NOT cleaned up.** Two cleanup attempts via `rm -rf /tmp/13-05-probe` were blocked by the runtime's destructive-command gate; the probe directory is scratch state in /tmp and will be cleared by macOS /tmp rotation. The verdict file `/tmp/13-05-preflight-verdict.txt` likewise remains; its content is fully described in this SUMMARY for any continuation agent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree-side `task install` would have corrupted production state.**

- **Found during:** Task 2 step 5 (the plan instructed `task install` on the dev machine to verify idempotency).
- **Issue:** Production symlinks point at main-repo paths (e.g., `/Users/josh/Git/personal/dotfiles/shell/.zshenv`). `{{.DOTFILEDIR}}` from this worktree resolves to the worktree path (`.claude/worktrees/agent-ae349dc12c2954f62`). Running `task install` from the worktree would re-link production state to point at the worktree -- destructive (production shell setup would break the moment the worktree is removed).
- **Fix:** Verified idempotency via `task --dry install` + manual bash-level reproduction of the exact inline expression against the production `.zshenv` symlink (substituting both main-repo and worktree DOTFILEDIR variants). The first returned EXIT=0 (match -> idempotent skip), the second returned EXIT=1 (mismatch -> re-link forced). The plan's idempotency contract is satisfied; the actual `task install` on the dev machine will run from the main checkout after the worktree merges back, where DOTFILEDIR matches production.
- **Files modified:** None (this was a verification-procedure deviation, not a source-code fix). Documented in Decision 2 above.

### Adaptations (not deviations, documented in Decisions)

- **HELPER -> INLINE path branch** per pre-flight verdict (Decision 1). The plan's `<action>` block explicitly branches on `/tmp/13-05-preflight-verdict.txt`; this is the plan's prescribed fallback, not a deviation.
- **Row 22 closed alongside row 14 with duplication-shape-preserved annotation** (Decision 3). The plan's verify-block only mandates row 14 closure; row 22 was a defer from Plan 13-04 that this plan was authorized to inherit and resolve.

---

**Total deviations:** 1 auto-fixed (Rule 3 -- worktree-context safety substituted equivalent verification procedure for the plan's `task install` step).
**Impact on plan:** All three tasks completed; verification gates passed; the worktree-context safety adaptation preserves the plan's idempotency-verification intent without the destructive side effect of running `task install` from a worktree.

## Issues Encountered

- **macOS `/tmp -> /private/tmp` canonicalization caused a probe false-positive.** Pre-flight probe (Task 1) discovered `readlink -f /tmp/foo` returns `/private/tmp/foo` because `/tmp` is a system symlink. Re-probing under `$HOME/.config/...` (real XDG paths) confirmed the production inline expression returns correct exit codes. Documented in Decision 4 above and in the 13-SMOKE.md procedure for the operator.
- **Destructive-command gate blocked probe cleanup.** Two `rm -rf /tmp/13-05-probe` invocations were blocked by the runtime's fact-forcing gate. The probe directory remains in /tmp; documented in Decision 5 above.

## User Setup Required

None. The fix is to status-block logic in `taskfiles/links.yml`; no new packages, no new env vars, no manifest changes. The actual `task install` on the converged dev machine -- which exercises the new status-block logic -- runs after this worktree merges back to main; no operator action is required mid-plan.

## Next Phase Readiness

- **Plan 13-06 ready to start.** All MEDIUM/LOW REVIEW.md rows remain triaged from earlier waves; this plan added closure annotations to two rows (14 + 22). Plan 13-06's scope (fix-now MEDIUM/LOW + defer-rationale for the rest) is unchanged.
- **Phase 14 hand-off intact.** The TRIM-NN defer rows in REVIEW.md continue to point at Phase 14; no rows were re-routed to Phase 14 by this plan.
- **Smoke test runnable.** Operator can execute 13-SMOKE.md Scenario 1 immediately after Phase 13 closes; the procedure is self-contained.

## Self-Check: PASSED

Verified before writing this section:

- `taskfiles/links.yml` contains `readlink -f` in 26 status entries (5 install-zsh + 13 install-claude + 7 install-configs + 1 configs:ghostty), counted by per-task awk extraction; matches the plan's target of 26.
- `13-REVIEW.md` row 14 `closed by` column contains `a2dcf40` (verified by line read).
- `13-REVIEW.md` row 22 `closed by` column contains `a2dcf40` (verified by line read).
- `13-REVIEW.md` has 0 HIGH rows with empty `closed by` column (`grep -cE '^\|.*\| HIGH \|.*\|[[:space:]]*\|[[:space:]]*$'` returns 0).
- `13-SMOKE.md` exists; contains `deliberately-corrupted`, `13-smoke-decoy-target`, `readlink -f` (all three grep checks PASS).
- `task lint && task test` exit 0 after every commit (verified post-Task-2 and post-Task-3).
- `task --dry install` exits 0 post-Task-2.
- `git log --oneline 3938c6f..HEAD` shows exactly the three expected commits in order: `a2dcf40` (fix), `46e77ea` (docs annotation), `156f91d` (docs SMOKE.md).
- No modifications to `STATE.md` or `ROADMAP.md` (orchestrator owns those -- verified by `git diff --name-only` against the wave-4 base).
- No modifications to `taskfiles/helpers.yml` (HELPER path probe-rejected -- verified by `git diff --name-only`).

---

*Phase: 13-code-review-dead-code-cleanup*
*Completed: 2026-05-18*
