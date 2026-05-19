---
phase: 13-code-review-dead-code-cleanup
verified: 2026-05-18T19:00:00Z
status: passed
score: 4/4
requirement_ids: [REVW-01, REVW-02, REVW-03, REVW-04, REVW-05, REVW-06]
re_verification: false
verifier_notes:
  - "Independent audit at 13-REVIEW-AUDIT.md surfaced 3 Critical / 9 Warning / 7 Info issues including regressions from Phase 13's own consolidation work. Per workflow this is advisory and does NOT block phase completion. Captured below as Audit Findings for Phase 13.1 gap-closure consideration or Phase 14 routing."
audit_findings:
  critical: 3
  warning: 9
  info: 7
  source: ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW-AUDIT.md"
  disposition: "advisory - candidate Phase 13.1 gap-closure or Phase 14 routing; not blocking"
---

# Phase 13: code-review-dead-code-cleanup - Verification Report

**Phase Goal:** A repo-wide code review run by language-aware reviewers produces a HIGH/MEDIUM/LOW finding list; HIGH is fixed in this phase, dead code is removed, duplicated logic is consolidated, and the `links:*` target-match status-block bug is fixed before Phase 14 touches `links.yml`.

**Verified:** 2026-05-18
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth (Success Criterion) | Status | Evidence |
|---|---------------------------|--------|----------|
| 1 | 13-REVIEW.md exists with six-column shape; language-aware reviewers (zsh, taskfile, TOML, aux) covered the surface | VERIFIED | File present at `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md`; header line 11 declares `\| file:line \| severity \| category \| finding \| remediation \| closed by \|`; line 4 enumerates surfaces "zsh (D-01), YAML (D-02), TOML (D-03), aux (D-04)"; 37 finding rows distributed 2 HIGH / 18 MEDIUM / 17 LOW per `13-01-SUMMARY.md` Findings Volume table |
| 2 | Every HIGH row annotated with closing SHA; every MEDIUM/LOW row carries fix-now SHA or defer-with-rationale; none blank | VERIFIED | `grep -cE '^\|.*\|[[:space:]]*\|[[:space:]]*$' 13-REVIEW.md` returns 0 (no blank `closed by` cells). HIGH row 13 closed by `d5b21a0`; HIGH row 14 closed by `a2dcf40`. All MEDIUM/LOW rows carry either short-SHA or `defer: Phase 14 TRIM-NN` annotation (verified per 13-06-SUMMARY closure statistics table) |
| 3 | Dead code is removed: dropped symbols return zero `git grep` hits post-commit; removal commits list the dropped symbols | VERIFIED | Plan 13-03 SUMMARY documents three Class-B dead-code removals with grep evidence: (a) `motd` feature flag (commit `edbbabd`) - `_dotfiles_feature motd` returns 0 hits; (b) `commit-task1.yml` exemption (commit `cdbab32`) - `commit-task` returns 0 hits; (c) `.zprofile` Linux else-branch (commit `ebccf47`) - `linuxbrew` returns 0 hits. Each commit subject names the dropped symbol. Class-A `shell/functions/motd.zsh` correctly preserved |
| 4 | `links:*` status blocks verify symlink TARGET via `readlink -f` (not just `test -L`); `13-SMOKE.md` exists documenting deliberately-corrupted-symlink test | VERIFIED | `grep -c "readlink -f" taskfiles/links.yml` returns 35 occurrences. Status blocks in `install-zsh` (lines 160-164), `install-claude` (250-262), `install-configs` (297-303), and `configs:ghostty` (324) all use the pattern `test -L "<T>" && [[ "$(readlink -f "<T>")" == "<E>" ]]`. `13-SMOKE.md` exists with Scenario 1 (deliberately-corrupted symlink under `$XDG_CONFIG_HOME/eza/theme.yaml` - decoy point, `task install`, restore assertion, idempotency re-check, cleanup) |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` | Six-column classified finding spine (D-14 house style) | VERIFIED | 37 rows; header at line 11; sorted by severity desc; zero blank `closed by` cells |
| `.planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md` | Deliberately-corrupted-symlink smoke procedure | VERIFIED | 96 lines; Scenario 1 fully specified; uses `readlink -f` against `$XDG_CONFIG_HOME/eza/theme.yaml` symlink; operator results log section present |
| `13-01-SUMMARY.md` through `13-06-SUMMARY.md` | One SUMMARY per plan with closure annotations | VERIFIED | All six files present; each carries `requirements-completed` frontmatter and per-commit closure tables |
| `taskfiles/links.yml` (modified) | Status blocks verify target via `readlink -f` | VERIFIED | Direct inspection of lines 160-164, 250-262, 297-303, 324 confirms the inline `test -L && [[ readlink -f == expected ]]` pattern across 26 install-style status entries |
| `os/defaults/_apply_verify.zsh` | New shared helper extracting `apply_X`/`verify_X` patterns (REVW-04) | VERIFIED | Created in Plan 13-04 (commit `5462d78`); 5 per-concern files delegate |
| `shell/functions/_dotfiles_require_feature.zsh` | New helper for wrapper-function feature-gate guard (REVW-04) | VERIFIED | Created in Plan 13-04 (commit `be4d90a`); 4 wrapper call sites migrated |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `13-REVIEW.md` rows | closing commits | `closed by` column annotations | WIRED | Plan 13-06 annotation batch commit `12f6c61` populated 21 cells in one docs commit |
| `taskfiles/links.yml install-zsh` status block | manifest-expected source paths | inline `readlink -f == "{{.DOTFILEDIR}}/shell/..."` | WIRED | 5 entries: zshenv/zprofile/zshrc/zlogin/zlogout (lines 160-164) |
| `taskfiles/links.yml install-claude` status block | manifest-expected source paths | inline `readlink -f` with `claude-marketplace` feature gate wrapper | WIRED | 13 entries (lines 250-262), gated on `{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}...{{end}}` |
| `taskfiles/links.yml install-configs` status block | manifest-expected source paths | inline `readlink -f`; ghostty entry gated on `ghostty` feature | WIRED | 7 entries (lines 297-303) |
| `taskfiles/links.yml configs:ghostty` status block | manifest-expected source path | inline `readlink -f` gated on `ghostty` feature | WIRED | 1 entry (line 324) |
| `os/defaults/{dock,finder,input,screenshots,security}.zsh` | `_apply_defaults` / `_verify_defaults` helpers | sourced from `_apply_verify.zsh` | WIRED | All 5 per-concern files delegate per Plan 13-04 commit `5462d78` |
| `shell/aliases/{finder,ghostty}.zsh` wrappers | `_dotfiles_require_feature` helper | call-site collapse | WIRED | 4 call sites collapsed (Plan 13-04 commit `be4d90a`) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REVW-01 | Plan 13-01 | Code review pass producing classified finding list | SATISFIED | `13-REVIEW.md` published with 37 rows; SUMMARY 13-01 commit `ff5546e` |
| REVW-02 | Plan 13-02 (+ closure in 13-06) | HIGH-severity findings fixed in-phase | SATISFIED | 2 HIGH rows closed by `d5b21a0` (alias eager-expansion) and `a2dcf40` (links target-match); MEDIUM/LOW also closed-or-deferred per 13-06 |
| REVW-03 | Plan 13-03 | Dead code removed with grep evidence | SATISFIED | 3 dead-code rows closed: motd flag (`edbbabd`), commit-task1.yml exemption (`cdbab32`), .zprofile Linux branch (`ebccf47`); each with 0-hit `git grep` evidence in 13-03-SUMMARY |
| REVW-04 | Plan 13-04 | Duplication consolidation | SATISFIED | 5 MEDIUM duplication rows closed via new helpers (`_apply_verify.zsh`, `_dotfiles_require_feature.zsh`, `_run_negative_fixture` inline fn, messages.zsh self-bootstrap migration, taskfiles/shell.yml tuple-loop); 2 deferred with rationale; 3 KEEP-INLINE per D-09 rule-of-three |
| REVW-05 | Plan 13-05 | links:* target-match fix | SATISFIED | `taskfiles/links.yml` 26 inline `readlink -f` upgrades (commit `a2dcf40`); 13-SMOKE.md authored with deliberately-corrupted-symlink scenario |
| REVW-06 | Plan 13-06 | MEDIUM/LOW triage with fix-now or defer-with-rationale | SATISFIED | 17 MEDIUM/LOW rows fixed in-phase; 4 LOW rows deferred to Phase 14 TRIM-01/02/05 with explicit rationale; zero D-11(b) needs-new-infra defers (ROADMAP unmodified) |

### Anti-Patterns Found

None blocking. No `TBD`/`FIXME`/`XXX` debt markers in scope. Scattered `# Phase N` / `# D-NN` / `# CR-NN` / `# RESEARCH §X.Y` annotation noise is captured as REVIEW row 49 with explicit `defer: Phase 14 TRIM-01 + TRIM-05` (intentional carry-forward to Phase 14 grep-gate per SC#5 of that phase).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 13-REVIEW.md closure invariant: zero blank `closed by` cells | `grep -cE '^\|.*\|[[:space:]]*\|[[:space:]]*$' 13-REVIEW.md` | `0` | PASS |
| 13-REVIEW.md contains expected HIGH row count | `grep -cE '^\|.*\| HIGH \|' 13-REVIEW.md` | `2` | PASS |
| taskfiles/links.yml uses readlink -f in status blocks | `grep -c "readlink -f" taskfiles/links.yml` | `35` (covers 26 status-block entries + helper-task definitions at lines 420, 532) | PASS |
| 13-SMOKE.md present | direct file read | 96 lines; Scenario 1 fully specified | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| n/a | Phase 13 ships no `scripts/*/tests/probe-*.sh`; PLAN/SUMMARY artifacts do not declare probe paths | n/a | SKIPPED (no probes declared) |

### Human Verification Required

Phase 13 introduces no UI/UX or external-service surface; however the SC#4 deliverable `13-SMOKE.md` is by design a human-executable procedure:

#### 1. links:* target-match smoke (13-SMOKE.md Scenario 1)

**Test:** Follow steps 1-8 in `13-SMOKE.md` Scenario 1: deliberately corrupt `$XDG_CONFIG_HOME/eza/theme.yaml` to point at `/tmp/13-smoke-decoy-target`, run `task install`, verify the symlink is repaired, then run `task install` a second time and verify idempotent no-op on the `links:install-configs` sub-task.
**Expected:** Step 6 `readlink -f` returns a path ending in `$DOTFILEDIR/configs/eza/theme.yaml`; step 7 second `task install` produces no "running command" output for `links:install-configs`.
**Why human:** Touches the operator's live `$XDG_CONFIG_HOME` symlinks on the converged dev machine; Plan 13-05 SUMMARY explicitly notes the test was NOT executed from the worktree (would corrupt production state by re-linking to the worktree path). The smoke procedure must run from the main checkout after merge.
**Source:** Authored deliberately by Plan 13-05 per SC#4 of ROADMAP; not a verifier-discovered gap.

This is the only human-required check; Plan 13-05's bash-level reproduction of the inline expression against the production `.zshenv` symlink (documented in 13-05-SUMMARY "Idempotency Verification" block) already proves the status-block logic is correct at the expression level. The SMOKE.md run is end-to-end confirmation.

Because the smoke procedure is itself the planned-and-shipped deliverable for SC#4 (and the SC's wording is "13-SMOKE.md exists documenting the deliberately-corrupted-symlink test", which is satisfied by the file's existence), this human item is informational rather than a status-changing gap. Status remains `passed`; the smoke run is recommended after merge.

### Deferred Items

Items not yet met but explicitly addressed in Phase 14 (next milestone phase), per REVIEW.md remediation columns:

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | Row 41 - 11 interactive function arg-validation `if [[ -z "${1}" ]]` duplication | Phase 14 TRIM-02 | REVIEW row 41 `closed by` column: `defer: Phase 14 TRIM-02 - interactive D-08 Class A functions; per-call stderr messages give better UX than a shared helper` |
| 2 | Row 45 - `shell/.zlogout` 51-line comment block over 2-line body | Phase 14 TRIM-01 | REVIEW row 45 `closed by` column: `defer: Phase 14 TRIM-01 - inline-comment density audit` |
| 3 | Row 46 - per-file header banner decoration across theme.zsh and os/defaults/* | Phase 14 TRIM-02 | REVIEW row 46 `closed by` column: `defer: Phase 14 TRIM-02 - per-file header banner slim` |
| 4 | Row 48 - `head -n1 + sed trim` idiom across 4 sites | Phase 14 TRIM-02 | REVIEW row 48 `closed by` column: `defer: Phase 14 TRIM-02 - LOW-severity; per-site contexts mixed (1 YAML sh: + 3 cmd heredocs); shared-helper extraction value marginal` |
| 5 | Row 49 - Planning-history annotation noise (`# Phase N`, `# D-NN`, `# CR-NN`, `# RESEARCH §X.Y`) across taskfiles + zsh scripts | Phase 14 TRIM-01 + TRIM-05 | REVIEW row 49 `closed by` column: `defer: Phase 14 TRIM-01 + TRIM-05 - planning-history annotation grep-gate is exactly Phase 14 SC#5 scope` |

Deferred items do not affect overall status.

---

## Audit Findings (Advisory - Not Blocking)

The independent audit at `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW-AUDIT.md` (dated 2026-05-18; 38 files reviewed) surfaced 19 findings (3 Critical / 9 Warning / 7 Info) that the phase-internal `13-REVIEW.md` did not catch. Per the verification workflow this is advisory and **does not block phase completion**. The findings should drive a Phase 13.1 gap-closure pass or be routed to Phase 14 / a follow-up phase. Recorded here for the planner's reference:

### Critical (3) - candidate for Phase 13.1 gap-closure

- **CR-01** - `os/defaults/_apply_verify.zsh:57-83`: positional-arg-order trap in `_apply_defaults` (empty-string killall sentinel; missing arg silently misroutes `defaults write` to global plist instead of `-currentHost`). Regression introduced by Plan 13-04 row 21 extraction.
- **CR-02** - `taskfiles/links.yml:160-164, 250-262, 297-303, 324`: edge case where `_:safe-link` does NOT validate source existence; a manifest-typo source path can cause `task install` to exit 0 while `links:validate` continues to fail forever. Root-cause fix is in `_:safe-link`, not in the status blocks Plan 13-05 upgraded.
- **CR-03** - `shell/functions/motd.zsh:18-23, 26-28, 92`: nested helper-function cleanup leaks under `set -u` callers; `tput`-empty-result arithmetic aborts on TERM-less contexts. Pre-existing latent bug, not introduced by Phase 13.

### Warning (9) - mix of Phase-13 regressions and pre-existing items

- **WR-01** through **WR-09** span: `_apply_defaults` indirect-array silent fail (`(P)` on unset array - WR-01); missing tuple-stride validation (WR-02); `_dotfiles_require_feature` `$0`-fallback gives file path instead of fn name in doc-vs-behavior mismatch (WR-03); `cheat()` line 8 `echo $result` still unquoted despite e821f8f claim (WR-04 - **this is a phase REGRESSION: REVIEW row 39 was annotated closed but line 8 unquoting persists**); `prettyjson()` unguarded pipe through `highlight` (WR-05); `pubkey()` silent `pbcopy` failure on non-macOS (WR-06); `screenshots.zsh` apply hardcodes path duplicating array value (WR-07); `_verify_defaults` `failed=1` not `failed=$((failed+1))` (WR-08 - **same bug class as REVIEW row 19 which was fixed in `install/test-hooks.zsh` (commit 739ab57) but the fix was NOT propagated to the newly-extracted helper - phase REGRESSION**); `motd()` arithmetic underflow on narrow terminals (WR-09).

### Info (7) - documentation drift and idiom improvements

- IN-01 through IN-07: docstring drift (`screenshots.zsh` still claims `(e)`-flag while code uses narrow substitution); `_dotfiles_require_feature` `Reads:` doc misstatement; `install-claude` 13-line duplication readability (acknowledged in REVIEW row 22 KEEP-INLINE); `compose-brewfile.zsh` IFS-join verbosity; `.zshrc` _zcomp_age=0 silent stat-failure masking; `refresh.yml status: [false]` lacks comment; `manifest.yml setup` missing trailing newline.

### Recommended Disposition

Two of the warnings (WR-04 and WR-08) are explicit phase-regression evidence:

- **WR-04** contradicts `13-REVIEW.md` row 39's `closed by` annotation `e821f8f`. The audit re-read confirms line 8 `echo $result` is still unquoted. A Phase 13.1 follow-up should either (a) extend the fix to line 8 in a follow-up commit or (b) downgrade row 39's annotation.
- **WR-08** is the same `failed=1` -> `failed=$((failed+1))` bug class as REVIEW row 19 - fixed in `test-hooks.zsh` (commit 739ab57) but NOT propagated to the newly extracted `_apply_verify.zsh:114`. The Plan 13-04 extraction introduced the duplicate-of-the-original-bug.

Both items strongly suggest a Phase 13.1 gap-closure pass before Phase 14 begins; alternatively they can be added to Phase 14's scope. The CR-01 and CR-02 critical items should also be considered for Phase 13.1 since they are correctness defects from the phase's own consolidation work.

These findings are recorded here in VERIFICATION.md per the verifier directive that audit findings drive a Phase 13.1 gap-closure decision or Phase 14 routing; they do NOT change the Phase 13 verification status, which remains **passed** against the four ROADMAP success criteria.

---

## Follow-ups

1. **Phase 13.1 gap-closure (recommended):** Address CR-01, CR-02, WR-04, WR-08 regressions introduced by Plan 13-04 / Plan 13-05 consolidation work. Each is a per-commit fix; estimated 1-2 hours of executor time.
2. **Phase 14 routing (alternative):** Roll the audit findings into Phase 14 scope by adding them to the existing TRIM-NN list or creating a new AUDIT-NN sub-namespace within Phase 14.
3. **Smoke run:** Execute `13-SMOKE.md` Scenario 1 from the main checkout after the worktree merges back; record results in the "Operator results log" section of the SMOKE document.

---

## Gaps Summary

No goal-blocking gaps. All four ROADMAP success criteria for Phase 13 verify TRUE against the codebase:

- SC#1 (REVIEW report with six-column shape + language-aware coverage) - VERIFIED
- SC#2 (every row carries non-blank `closed by` annotation) - VERIFIED
- SC#3 (dead code removed with zero `git grep` hits + commits list dropped symbols) - VERIFIED
- SC#4 (`links:*` status blocks use `readlink -f` target-match + `13-SMOKE.md` exists) - VERIFIED

All six requirement IDs (REVW-01 through REVW-06) are SATISFIED with evidence trail through the corresponding plan SUMMARY files.

The independent audit at `13-REVIEW-AUDIT.md` surfaced regressions and latent issues from the phase's own consolidation work that the phase-internal review missed. These are advisory per workflow and recorded above as Audit Findings + Follow-ups. They are strong candidates for a Phase 13.1 gap-closure pass before Phase 14 begins touching `links.yml` and the consolidation helpers - but they do not change the Phase 13 verification status.

---

_Verified: 2026-05-18_
_Verifier: Claude (gsd-verifier)_
