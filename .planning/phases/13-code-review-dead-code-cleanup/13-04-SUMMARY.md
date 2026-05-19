---
phase: 13-code-review-dead-code-cleanup
plan: 04
subsystem: code-review
tags: [code-review, duplication, consolidation, shared-helpers, refactor]

requires:
  - phase: 13-code-review-dead-code-cleanup
    plan: 03
    provides: "13-REVIEW.md with 3 MEDIUM dead-code rows closed; 10 duplication rows still open for Plan 13-04 to consolidate or annotate"
provides:
  - "All 10 duplication rows in 13-REVIEW.md annotated with non-empty closed-by column (5 CONSOLIDATE-NEW commits + 2 DEFER markers + 3 KEEP-INLINE rationales + 1 pre-existing LOW defer)"
  - "New shared helper file os/defaults/_apply_verify.zsh (REVW-04 / D-09 extraction; 5 per-concern files now delegate)"
  - "New shared shell function shell/functions/_dotfiles_require_feature.zsh (4 wrapper-function call sites)"
  - "New inline shell function _run_negative_fixture inside taskfiles/test.yml (5 negative-fixture call sites)"
  - "messages.zsh self-bootstrap contract documented; redundant pre-init dance removed from 9 callers + 1 taskfile heredoc"
affects: [13-05-PLAN, 13-06-PLAN]

tech-stack:
  added: []
  patterns:
    - "D-09 rule-of-three honored: every consolidation has 3+ call sites; 2-occurrence patterns kept inline"
    - "Indirect array expansion via zsh `(P)` flag for parameterized helpers (os/defaults/_apply_verify.zsh `arr=(\"${(@P)array_name}\")`)"
    - "Caller-name auto-detection via zsh `${funcstack[2]}` in shell-function helpers (_dotfiles_require_feature)"
    - "DEFER closed-by annotations use the existing `defer: <reason>` shape (matches Plan 13-02 row 14 + Plan 13-03 row precedents)"
    - "KEEP-INLINE closed-by annotations use the `keep: <rationale>` shape per the plan's must_have-truth spec"

key-files:
  created:
    - ".planning/phases/13-code-review-dead-code-cleanup/13-04-SUMMARY.md"
    - "os/defaults/_apply_verify.zsh"
    - "shell/functions/_dotfiles_require_feature.zsh"
  modified:
    - "install/messages.zsh"
    - "bootstrap.zsh"
    - "install/compose-brewfile.zsh"
    - "install/resolver.zsh"
    - "os/defaults/dock.zsh"
    - "os/defaults/finder.zsh"
    - "os/defaults/input.zsh"
    - "os/defaults/screenshots.zsh"
    - "os/defaults/security.zsh"
    - "os/shell-registration.zsh"
    - "taskfiles/macos.yml"
    - "taskfiles/test.yml"
    - "shell/aliases/finder.zsh"
    - "shell/aliases/ghostty.zsh"
    - "taskfiles/shell.yml"
    - ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md"

key-decisions:
  - "Row 20 collapsed to a self-bootstrap CALL-SITE-MIGRATION (not a new helper extraction): messages.zsh already used `${DOTFILES_MESSAGES_LOADED:-}` (set-u-safe via the `:-` default expansion), so the 9 callers' pre-init dance was redundant. Strengthened messages.zsh's header with an explicit `set -u contract` block; removed the dance from all 9 callers + 1 taskfile heredoc. Smaller diff than a new install/load-messages.zsh helper, and the contract is now self-documented at the helper's own header."
  - "Row 21 helper signature accepts an optional 3rd arg `scope_flag` so security.zsh's per-host plist family (SECURITY_DEFAULTS_CURRENTHOST) uses the same helper as the global-scope family. The `(currentHost)` suffix in check / cross messages is auto-appended by the helper when scope_flag is set, matching the prior inline output byte-for-byte."
  - "Row 22 deferred to Plan 13-05 (REVW-05). The 13-entry duplication is the DUPLICATION SIDE of the test -L target-match bug (row 14 is the CORRECTNESS SIDE, also deferred to 13-05). Per the phase plan-breakdown table (13-CONTEXT.md §D-05), REVW-05 closure is Plan 13-05's job; the readlink -f fix that closes row 14 will collapse the 13-entry block AT THE SAME TIME. Closing row 22 in Plan 13-04 would require duplicating Plan 13-05's planned refactor."
  - "Row 23 KEEP-INLINE per D-09 rule-of-three: only 2 sites. The REVIEW row itself flags 'Borderline rule-of-three; only 2 sites'; D-09 explicitly keeps 2-occurrence patterns inline."
  - "Row 24 KEEP-INLINE per the row's own alternative remediation. The 4 sites of Homebrew prefix detection cannot share a sourced helper because .zshenv does not export DOTFILEDIR -- .zprofile + identity/ssh/cloudflared.zsh + bootstrap.zsh (pre-DOTFILEDIR-resolution) + Taskfile.yml-vars (sh: block) each run in a context where the helper file's path is unknown. The 4 shapes also return subtly different artifacts (brew-binary path vs prefix). The REVIEW row's second-option remediation (CLAUDE.md sanctioned literal pattern) is the accepted resolution; CLAUDE.md already documents this rule under 'Detect the Homebrew prefix by uname -m'."
  - "Row 27 LOCAL-LOOP-REFACTOR (no new shared helper): 4 sites within a single task body collapsed to a tuple-pair `for` loop. No helper extracted because the pattern has only one consumer; keeping the loop adjacent to its use site preserves locality. Output text is byte-identical to prior."
  - "Row 28 KEEP-INLINE per D-09: 2 comment-block sites, not 2 executable-logic sites. The root-cause DOTFILEDIR-leak fix is architectural (renaming the fallback var across 8 taskfile includes) and defers to Phase 14 TRIM-04 or a future-phase entry per D-11(b)."
  - "Row 48 (LOW) DEFER per the row's own opt-in routing: `defer: Phase 14 TRIM-02 || Plan 13-04 -- defer unless Plan 13-04 has spare cycles`. Plan 13-04 prioritized MEDIUM-severity rows; the re-grepped actual count is 4 sites (the row's '6 sites' overcounted), and per-site contexts are mixed (1 YAML sh: var-resolution + 3 cmd heredocs) making a single helper signature awkward."
  - "No new helpers added to taskfiles/helpers.yml in this plan. Every consolidation landed in a more-specific landing site: install/messages.zsh comment-only update, os/defaults/_apply_verify.zsh (file-local helper for the os/defaults/* family), shell/functions/_dotfiles_require_feature.zsh (file-local helper for the shell/aliases/* wrapper-function pattern), and an inline function inside taskfiles/test.yml (file-local helper for the 5 negative-fixture blocks). The plan's `verify` block's `internal: true` baseline-scoped check therefore trivially passes (empty diff against /tmp/13-04-helpers-baseline.txt)."

requirements-completed: [REVW-04, REVW-06]

duration: ~35min
completed: 2026-05-18
---

# Phase 13 Plan 04: Duplication Consolidation Summary

**Five MEDIUM duplication rows in 13-REVIEW.md closed via shared-helper extractions (rows 20, 21, 25, 26, 27); two rows deferred to Plan 13-05 / Phase 14; three rows annotated KEEP-INLINE per D-09 rule-of-three or architectural infeasibility. The 5 new helpers landed in their most-specific locations (install/messages.zsh self-bootstrap contract, os/defaults/_apply_verify.zsh, shell/functions/_dotfiles_require_feature.zsh, inline function in taskfiles/test.yml, local loop in taskfiles/shell.yml). Every duplication row in 13-REVIEW.md now carries a non-empty `closed by` column; green tree after every commit.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-18 (worktree spawn, post wave-3)
- **Completed:** 2026-05-18 (Self-Check completion)
- **Tasks:** 2 (Task 1 inventory + grep verification + helper baseline; Task 2 per-row consolidation + REVIEW.md annotation)
- **Files modified:** 16 source + planning files (2 created helpers + 14 modified + 1 REVIEW.md annotation)
- **Commits:** 6 (5 source consolidations + 1 docs annotation)

## Consolidation Manifest (Task 1 output)

| REVIEW.md row | Pattern signature | Occurrences | Verdict | Landing |
|---------------|-------------------|------------:|---------|---------|
| 20 | messages.zsh source-block pre-init dance | 9 sites | CONSOLIDATE-NEW (CALL-SITE-MIGRATION using existing self-guard) | install/messages.zsh contract strengthened; dance removed in 8 .zsh callers + 1 taskfile heredoc |
| 21 | os/defaults `apply_<X>` / `verify_<X>` tuple loops | 5 sites | CONSOLIDATE-NEW | os/defaults/_apply_verify.zsh (new file) |
| 22 | links.yml install-claude.status 13-line block | 13 sites | DEFER to Plan 13-05 | n/a (REVW-05 collapses row 14 + row 22 simultaneously) |
| 23 | manifest.yml CLI-arg parse | 2 sites | KEEP-INLINE | n/a (D-09 rule-of-three; row itself flags "Borderline") |
| 24 | Homebrew prefix detection | 4 sites | KEEP-INLINE | n/a (sanctioned literal pattern per CLAUDE.md; consolidation architecturally infeasible) |
| 25 | test.yml negative-fixture blocks | 5 sites | CONSOLIDATE-NEW | taskfiles/test.yml inline `_run_negative_fixture` function |
| 26 | wrapper-function feature-gate guard | 4 sites | CONSOLIDATE-NEW | shell/functions/_dotfiles_require_feature.zsh (new file) |
| 27 | XDG-dir check in shell:validate | 4 sites (1 task body) | LOCAL-LOOP-REFACTOR | taskfiles/shell.yml local tuple-pair `for` loop |
| 28 | Taskfile.yml workaround comment blocks | 2 sites | KEEP-INLINE | n/a (D-09; root-cause fix is architectural -- defers to Phase 14) |
| 48 | head -n1 + sed trim idiom (LOW) | 4 sites (REVIEW claimed 6; re-grepped count is 4) | DEFER to Phase 14 TRIM-02 | n/a (per the row's own opt-in routing) |
| 41 | 11 interactive functions arg-validation pattern (LOW) | already-deferred | DEFER to Phase 14 TRIM-02 | n/a (closed-by column populated with deferral rationale matching the remediation column) |

**Baseline capture:** `/tmp/13-04-helpers-baseline.txt` captured the pre-edit `taskfiles/helpers.yml` task-key set (5 entries: check-command, check-dir, check-file, check-link, safe-link). Post-edit diff is empty -- no new tasks added to helpers.yml in this plan.

## Per-Commit Summary

| Commit | Type | Subject | REVIEW.md rows closed | Files touched |
|--------|------|---------|------------------------|----------------|
| `852a763` | refactor(13-04) | self-bootstrap messages.zsh under set -u | row 20 | install/messages.zsh, bootstrap.zsh, install/compose-brewfile.zsh, install/resolver.zsh, os/defaults/dock.zsh, os/defaults/finder.zsh, os/defaults/input.zsh, os/defaults/screenshots.zsh, os/defaults/security.zsh, os/shell-registration.zsh, taskfiles/macos.yml |
| `5462d78` | refactor(13-04) | extract _apply_defaults / _verify_defaults helpers | row 21 | os/defaults/_apply_verify.zsh (new), os/defaults/dock.zsh, os/defaults/finder.zsh, os/defaults/input.zsh, os/defaults/screenshots.zsh, os/defaults/security.zsh |
| `12af5b9` | refactor(13-04) | extract _run_negative_fixture helper in test:manifest | row 25 | taskfiles/test.yml |
| `be4d90a` | refactor(13-04) | extract _dotfiles_require_feature wrapper helper | row 26 | shell/functions/_dotfiles_require_feature.zsh (new), shell/aliases/finder.zsh, shell/aliases/ghostty.zsh |
| `784b812` | refactor(13-04) | collapse 4 XDG-dir check blocks into tuple-pair loop | row 27 | taskfiles/shell.yml |
| `f4ca720` | docs(13-04) | annotate REVIEW.md closed by columns for all 10 duplication rows | rows 20, 21, 22, 23, 24, 25, 26, 27, 28, 41, 48 (annotation) | .planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md |

## Counts

| Metric | Count |
|--------|-------|
| New helpers added (per landing) | helpers.yml: 0; install/messages.zsh: 0 functions added (contract-only update); os/defaults/_apply_verify.zsh: 2 functions (_apply_defaults, _verify_defaults); shell/functions/_dotfiles_require_feature.zsh: 1 function; taskfiles/test.yml inline: 1 function |
| Call sites migrated to new / strengthened helpers | row 20: 10 (9 .zsh + 1 taskfile heredoc); row 21: 10 (apply_X x 5 + verify_X x 5); row 25: 5 (negative-fixture calls); row 26: 4 (wrapper-function guards); row 27: 4 (XDG-dir checks) -- total 33 call sites |
| Patterns kept inline per rule-of-three | 3 (rows 23, 28: 2 occurrences; row 24: architecturally infeasible) |
| Patterns deferred | 3 (rows 22, 41, 48) |
| Pre-existing helper migrations (CALL-SITE-MIGRATION) | 1 (row 20 -- uses the pre-existing self-guard in messages.zsh) |

## Verification (green-tree gate after every commit)

| Commit | task lint | task test | task --dry install |
|--------|-----------|-----------|--------------------|
| `852a763` | exit 0 | exit 0 (11/11 manifest fixtures + 9/9 hook smokes) | exit 0 |
| `5462d78` | exit 0 | exit 0 | exit 0 |
| `12af5b9` | exit 0 | exit 0 (5 _invalid-* checks emit byte-identical pass text) | exit 0 |
| `be4d90a` | exit 0 | exit 0 | exit 0 |
| `784b812` | exit 0 | exit 0; `task validate` emits 4 XDG check lines verbatim | exit 0 |
| `f4ca720` | exit 0 | exit 0 | n/a (docs-only) |

Closure-gate verification:
- `grep -cE '^\\|.*\\| duplication \\|.*\\|[[:space:]]*\\|[[:space:]]*$' 13-REVIEW.md` returns 0 (every duplication row has a non-empty `closed by` column).
- helpers.yml task-key diff against /tmp/13-04-helpers-baseline.txt is empty -- no new helpers added to helpers.yml in this plan, so the `internal: true` baseline-scoped check trivially passes.

End-to-end smoke evidence:
- Row 20: every refactored caller sources cleanly under `set -euo pipefail` and exposes the same public surface as before.
- Row 21: every per-concern file (`dock`, `finder`, `input`, `screenshots`, `security`) sources cleanly and exposes `apply_<X>` + `verify_<X>` entry points. `verify_dock` invoked against the host emits 6/6 check lines with text identical to the prior inline implementation.
- Row 25: `task test`'s 5 `_invalid-*` lines emit identical pass-line text to the prior hand-rolled blocks.
- Row 26: standalone smoke test confirms feature-on / feature-off / explicit-fn-name semantics; stderr message text matches the prior hand-rolled form byte-for-byte.
- Row 27: `task validate` emits the 4 XDG check lines verbatim.

## Accomplishments

- **5 MEDIUM duplication rows closed** via per-row consolidation commits with byte-identical post-refactor output.
- **REVIEW.md closure check passes**: `grep -cE '^\\|.*\\| duplication \\|.*\\|[[:space:]]*\\|[[:space:]]*$' 13-REVIEW.md` returns 0.
- **D-09 rule-of-three honored** in both directions: every CONSOLIDATE-NEW row has 3+ call sites (Row 20: 9-10, Row 21: 5+5, Row 25: 5, Row 26: 4, Row 27: 4 within one body); KEEP-INLINE rows (23, 28) have exactly 2 sites; Row 24 is architecturally infeasible despite 4 sites and is documented per CLAUDE.md's existing sanctioned-pattern rule.
- **Anti-scope-creep discipline observed**: only the 10 duplication rows on the REVIEW were touched. The LINT-05 warnings for `defaults read` / `defaults write` / `dscl` / `pbcopy` in the per-concern files surfaced during baseline runs but are non-blocking (LINT-05 is by-design `exit 0`) and pre-date this plan; they were NOT modified.
- **Green-tree gate held after every commit**: `task lint && task test` exit 0 after each of the 6 commits. `task --dry install` exits 0 after each install-chain-touching commit.

## Deferred Items (within this plan)

- **Row 22** (links.yml install-claude.status 13-line block) -- DEFER to Plan 13-05. Reason: the 13 lines are the duplication side of the test -L target-match bug (row 14); per the phase plan-breakdown table (13-CONTEXT.md §D-05) REVW-05 closure routes to Plan 13-05, which will collapse row 14 and row 22 simultaneously with the readlink -f fix.
- **Row 48** (head -n1 + sed trim idiom, LOW) -- DEFER to Phase 14 TRIM-02. Reason: explicitly routed by the row itself (`defer ... unless Plan 13-04 has spare cycles`); LOW-severity; per-site contexts mixed (1 YAML sh: + 3 cmd heredocs); shared-helper extraction value marginal.
- **Row 41** (11 interactive functions arg-validation, LOW) -- already-marked DEFER in the remediation column; closed-by column populated with the matching deferral rationale.

## Files Created / Modified

### Created
- `.planning/phases/13-code-review-dead-code-cleanup/13-04-SUMMARY.md` (this file)
- `os/defaults/_apply_verify.zsh` (new shared helper -- 2 functions: `_apply_defaults`, `_verify_defaults`)
- `shell/functions/_dotfiles_require_feature.zsh` (new shared helper -- 1 function: `_dotfiles_require_feature`)

### Modified
- `install/messages.zsh` -- header comment strengthened with explicit `set -u contract` block (no function changes)
- `bootstrap.zsh` -- pre-init dance removed; bare `source` per the new contract
- `install/compose-brewfile.zsh` -- pre-init dance removed
- `install/resolver.zsh` -- pre-init dance removed
- `os/defaults/dock.zsh` -- delegates to `_apply_defaults` / `_verify_defaults`; pre-init dance removed
- `os/defaults/finder.zsh` -- delegates to helpers; pre-init dance removed
- `os/defaults/input.zsh` -- delegates to helpers (no killall); pre-init dance removed
- `os/defaults/screenshots.zsh` -- mkdir prelude preserved; delegates to helpers; pre-init dance removed
- `os/defaults/security.zsh` -- guest-account logic preserved inline; both tuple-array loops delegate to helpers with the -currentHost scope flag for the per-host plist family; pre-init dance removed
- `os/shell-registration.zsh` -- pre-init dance removed
- `taskfiles/macos.yml` -- pre-init dance removed from the `macos:validate` cmd heredoc
- `taskfiles/test.yml` -- 5 hand-rolled negative-fixture blocks collapsed to `_run_negative_fixture` calls
- `shell/aliases/finder.zsh` -- 3 wrapper-function guards collapsed to `_dotfiles_require_feature` calls
- `shell/aliases/ghostty.zsh` -- 1 wrapper-function guard collapsed
- `taskfiles/shell.yml` -- 4 XDG-dir check blocks collapsed to tuple-pair `for` loop
- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` -- all 10 duplication rows + row 41 carry non-empty `closed by` columns

## Decisions Made

(See `key-decisions` in the frontmatter for the structured list; expanded narrative below for the architectural / interpretive ones.)

1. **Row 20 self-bootstrap collapse rather than new helper extraction.** Initially scoped as "extend messages.zsh with self-bootstrap guard so callers can source it under set -u" per the REVIEW remediation. On inspection, messages.zsh's `[[ -n "${DOTFILES_MESSAGES_LOADED:-}" ]] && return 0` line at line 20 ALREADY uses the set-u-safe `:-` default expansion. The 9 callers' pre-init dance (`: "${DOTFILES_MESSAGES_LOADED:=}"` + bare-ref check) was redundant. Smaller-diff path: strengthen the messages.zsh header with an explicit `set -u contract` block making the implicit safety contract auditable, then remove the dance in every caller. This is a CALL-SITE-MIGRATION using a pre-existing helper (per the plan's verdict taxonomy), not a CONSOLIDATE-NEW extraction.
2. **Row 21 helper signature -- optional 3rd arg `scope_flag`.** The 5 sites split into 4 "global plist" callers (dock, finder, input, screenshots) + 1 "two-array-plus-guest-account" caller (security). security's `SECURITY_DEFAULTS_CURRENTHOST` array needs `defaults -currentHost write/read` instead of bare `defaults`. Adding an optional 3rd arg to both `_apply_defaults` and `_verify_defaults` keeps a single helper file (avoids forking into `_apply_defaults_global` + `_apply_defaults_currenthost`) and supports a future per-host plist concern without further helper-file changes. The check / cross message text auto-appends `(currentHost)` when `scope_flag` is set, matching the prior inline output byte-for-byte.
3. **Row 21 indirect-array expansion via zsh `(P)` flag** -- `arr=("${(@P)array_name}")` reads an array whose name is held in `$array_name`. Equivalent to bash `${!array_name[@]}` for arrays. This is zsh-specific (not POSIX), which is appropriate because every os/defaults/<concern>.zsh file already uses zsh-specific `typeset -ga` 1-indexed arrays and is invoked under `zsh -c` from macos.yml.
4. **Row 26 helper picks up caller name via `${funcstack[2]}`** -- zsh's `funcstack` array reflects the active call chain; `funcstack[1]` is the helper itself, `funcstack[2]` is the immediate caller. The wrapper-function call site collapses to a single arg: `_dotfiles_require_feature <feature> || return 1`; the stderr-message function name is auto-detected. Explicit 2nd arg overrides the implicit lookup for atypical call sites.
5. **Row 27 LOCAL-LOOP-REFACTOR vs. shared helper.** The 4 sites all live inside ONE task body; there is no second consumer that would benefit from a shared helper. A local `for` loop iterating a tuple-pair array keeps the loop adjacent to the data, preserves locality, and avoids cross-file indirection that a same-file-only helper would introduce. The plan's CONSOLIDATE-NEW vocabulary covers new helpers landing in helpers.yml / messages.zsh; the LOCAL-LOOP-REFACTOR verdict introduced here addresses the within-one-task-body case the plan's <action> block did not explicitly enumerate.
6. **Row 28 KEEP-INLINE with architectural-fix rationale.** The REVIEW row's remediation is conceptually one of two things: (a) consolidate the 2 comment blocks (rule-of-three-positive only for comments, not executable logic) or (b) fix the root-cause DOTFILEDIR-pollution that the comments justify (architectural -- requires renaming `DOTFILEDIR` -> `_LOCAL_DOTFILEDIR` in 8 included taskfiles, with downstream consumer updates). Path (b) is a Rule-4 architectural change; path (a) addresses only the symptom. Plan 13-04 selects neither: the 2 comment blocks are KEEP-INLINE per D-09 (2 occurrences); the architectural fix defers to Phase 14 TRIM-04 or a future-phase needs-new-infra entry per D-11(b).
7. **No new entries in taskfiles/helpers.yml.** The plan's `<action>` block enumerated `taskfiles/helpers.yml` as the landing site for taskfile-shared helpers. In practice every Plan 13-04 helper landed in a more-specific location: per-family helper files (os/defaults/_apply_verify.zsh, shell/functions/_dotfiles_require_feature.zsh), inline functions inside the consuming taskfile (taskfiles/test.yml), or contract documentation in an existing file (install/messages.zsh). helpers.yml hosts cross-cutting helpers reused across taskfiles (`_:safe-link`, `_:check-*`); none of Plan 13-04's helpers cross taskfile boundaries (the closest -- `_run_negative_fixture` -- is used exclusively by `test:manifest`). The plan's verify-block check (`internal: true` on every NEW helper in helpers.yml, scoped via baseline diff) therefore trivially passes (empty diff against `/tmp/13-04-helpers-baseline.txt`).

## Deviations from Plan

### Auto-fixed Issues

None -- no Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations triggered. All work matched the plan's prescribed CONSOLIDATE-NEW / CALL-SITE-MIGRATION / KEEP-INLINE / DEFER-with-rationale shapes. The Rule-4 architectural concern for Row 28 (DOTFILEDIR-leak rename across 8 taskfiles) was correctly recognized and documented as a defer rather than attempted in-scope.

### Adaptations (not deviations, documented in Decisions Made)

- Row 20 implemented as CALL-SITE-MIGRATION (using pre-existing self-guard) rather than CONSOLIDATE-NEW (adding a new install/load-messages.zsh). Smaller diff; same closure outcome.
- Row 27 implemented as LOCAL-LOOP-REFACTOR (no new shared helper) rather than CONSOLIDATE-NEW. Within-one-task-body single-consumer case; helper extraction would add cross-line indirection without a second consumer.
- New helpers landed in per-family files (os/defaults/_apply_verify.zsh, shell/functions/_dotfiles_require_feature.zsh) and an inline taskfile function rather than `taskfiles/helpers.yml`. None of the new helpers are cross-taskfile reusable; placing them in helpers.yml would force them into the cross-cutting `_:` namespace without justification.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** All 10 duplication rows in REVIEW.md carry non-empty `closed by` columns; green tree at every step; D-09 rule-of-three honored in both directions.

## Issues Encountered

None. Both `task lint && task test && task --dry install` exited 0 after every commit. The pre-existing LINT-05 portability warnings (`pbcopy`, `dscl`, `defaults read`, `defaults write`) in `shell/functions/{pubkey,sethostname}.zsh`, `os/shell-registration.zsh`, and `os/defaults/*.zsh` continue to warn but are LINT-05-by-design-`exit 0` and pre-date this plan. The post-Row 21 `defaults read` / `defaults write` LINT-05 warnings come from the per-concern files (now thin wrappers) AND from `_apply_verify.zsh` (where the `defaults` invocations live after extraction); the warning count is unchanged in spirit (the same number of `defaults` invocations exist, just relocated).

A short helper-design exploration around zsh `(P)` flag (initial smoke test passed an array directly to `${(@P)X}` instead of the array's NAME string) was caught immediately by the smoke test and resolved by passing a name variable -- this is the correct (P)-flag contract. The Row 21 helper signature receives the array name as `$1` (a string), then performs the `(P)` lookup internally, which is the intended use.

## User Setup Required

None. All edits are source-side; no operator action required. The new helpers are sourced automatically (os/defaults/_apply_verify.zsh by each per-concern file; shell/functions/_dotfiles_require_feature.zsh by .zshrc's function-glob loop, same mechanism as `_dotfiles_feature`).

## Next Phase Readiness

- **Plan 13-05 (links target-match fix) ready to start**: REVIEW.md row 14 still carries `defer: Plan 13-05 (REVW-05)`, AND row 22 (the duplication side of the same bug) now also carries a Plan-13-05 defer. The readlink -f fix should collapse both rows simultaneously per the phase plan-breakdown table (13-CONTEXT.md §D-05); Plan 13-05's commit should update both rows' `closed by` columns from the defer markers to the fixing commit's short-SHA.
- **Plan 13-06 (MEDIUM/LOW triage) inherits a smaller backlog**: the duplication category is now fully annotated. MEDIUM/LOW rows in the clarity / correctness / dead-code categories remain for Plan 13-06 to triage with "fix now" or "defer with rationale" per D-11.
- **Phase 14 (TRIM-NN) inherits documented deferrals from Plan 13-04**: rows 28, 41, 48 each carry an explicit Phase-14 / needs-new-infra defer rationale Phase 14 can route directly to TRIM-02 (Row 48 + Row 41) and TRIM-04 (Row 28's DOTFILEDIR-leak comment cleanup, or a parent needs-new-infra entry per D-11(b)).

## Known Stubs

None. All edits replace duplication with consolidation or document explicit defer reasoning; no placeholder data or empty-state stubs introduced.

## Threat Flags

None. The consolidations only REROUTE existing logic to shared helpers; no new network endpoint, auth path, file-access pattern, or schema change. The Row 21 helper preserves the screenshots.zsh anti-(e)-flag-code-exec-sink contract (narrow `${value/\$HOME/$HOME}` substitution only); the Row 26 helper inherits the existing `_dotfiles_feature` cache contract; the Row 25 inline function preserves the prior CR-01 EXIT-trap cleanup ordering.

## Self-Check: PASSED

Verified before writing this section:

- `os/defaults/_apply_verify.zsh` exists and defines `_apply_defaults` + `_verify_defaults` (smoke-sourced under `set -euo pipefail`; both functions present in `typeset -f` output).
- `shell/functions/_dotfiles_require_feature.zsh` exists and defines `_dotfiles_require_feature`.
- `install/messages.zsh` contains the `set -u contract` header comment block.
- `taskfiles/test.yml` contains the inline `_run_negative_fixture` function plus 5 call lines.
- `taskfiles/shell.yml` contains the `xdg_pairs` tuple array + `for pair in ...` loop.
- `shell/aliases/finder.zsh` calls `_dotfiles_require_feature macos-finder || return 1` in each wrapper.
- `shell/aliases/ghostty.zsh` calls `_dotfiles_require_feature ghostty || return 1` in `g()`.
- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` has zero rows matching `^\\|.*\\| duplication \\|.*\\|[[:space:]]*\\|[[:space:]]*$`.
- All 6 commits (`852a763`, `5462d78`, `12af5b9`, `be4d90a`, `784b812`, `f4ca720`) exist in `git log --oneline 05dcca4..HEAD` in chronological order matching the plan's iteration order.
- `task lint && task test` exit 0 after each of the 6 commits; `task --dry install` exits 0 after each install-chain-touching commit.
- No modifications to STATE.md or ROADMAP.md (orchestrator owns those -- verified by `git diff --name-only` against the wave-4 base showing only the 16 expected files).

---

*Phase: 13-code-review-dead-code-cleanup*
*Completed: 2026-05-18*
