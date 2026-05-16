---
phase: 08-validation-cutover-readiness
verified: 2026-05-16T23:45:00Z
status: human_needed
score: 12/12 must-haves verified (3 operationally pending; 0 engineering gaps)
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/11
  gaps_closed:
    - "CR-01: install/cutover-gate.zsh fresh-machine path now returns 0 (was return 1); bootstrap.zsh:112 completes cleanly on a clean Mac per docs/CUTOVER.md step 2 prose"
    - "CR-02: taskfiles/claude.yml plugin selectors aligned on `.id` across status (line 133), install body (line 156), and validate body (line 290); marketplace selector at line 125 correctly remains `.name` because it targets a marketplace object, not a plugin object"
    - "CR-03: taskfiles/claude.yml:246-263 replaced the silent `exit 0` after `cross \"claude CLI missing\"` with an rc accumulator (rc=0 init, rc=1 on each missing CLI, `exit \"$rc\"` at end of cmds[0]); same pattern applied to jq branch"
    - "CR-04: taskfiles/links.yml configs: status block (line 247) now includes the ghostty inline-ternary entry mirroring the claude: pattern; partial-state regression class closed"
  gaps_remaining: []
  regressions: []
  also_fixed_warnings:
    - "WR-01: claude.yml deps unified on leading-colon form `:manifest:resolve` at lines 88, 116, 194"
    - "WR-02: CUTOVER.md step 6 prose now matches code (only claude:validate emits the sentinel; other validates return check when feature-off)"
    - "WR-03: links.yml case statement gained a `*) ... ;;` catch-all (lines 540-549) that errors on unknown $mode"
    - "WR-04: Taskfile.yml validate aggregator refactored to single-pass (mktemp -d + tee + PIPESTATUS[0] + trap cleanup); double-run footgun eliminated"
human_verification:
  - test: "Cut over personal-laptop per docs/CUTOVER.md § Fresh-machine verification end-to-end; update docs/CUTOVER.md row from `planning` -> `soaking` -> after 7 days `cut-over`; commit"
    expected: "personal-laptop row shows status `cut-over` with days-on-v2 >= 7 and a real last-validate-pass date; commit references personal-laptop cutover"
    why_human: "Closes CUTV-04 / CUTV-05 for personal-laptop. Requires real-machine install + 7-day calendar wait that cannot live inside an agent invocation. Plan 08-06 Task 1 is `autonomous: false` and operator-driven per design. CONFIRMED by user pre-verification: tasks 1-5 of plan 08-06 are operationally pending, NOT engineering gaps."
  - test: "Cut over server-1 via SSH per docs/CUTOVER.md (validates server feature-gate matrix: claude-marketplace=false → claude row shows n/a in summary table; GUI features off → only macos-security defaults run)"
    expected: "server-1 row shows status `cut-over`, days-on-v2 >= 7, last-validate-pass populated; commit references server-1 cutover"
    why_human: "Closes CUTV-04 / CUTV-05 for server-1. Requires SSH access + 7-day soak. Plan 08-06 Task 2 is `autonomous: false`. CONFIRMED operationally pending."
  - test: "Cut over server-2 via SSH per docs/CUTOVER.md (mirrors server-1 manifest; 7-day soak independent of server-1)"
    expected: "server-2 row shows status `cut-over`, days-on-v2 >= 7, last-validate-pass populated; commit references server-2 cutover"
    why_human: "Closes CUTV-04 / CUTV-05 for server-2. Requires SSH access + 7-day soak. Plan 08-06 Task 3 is `autonomous: false`. CONFIRMED operationally pending."
  - test: "Cut over work-laptop per docs/CUTOVER.md (last in deliberate order — smallest disruption window; manifest analogous to personal-laptop with work-flavored cask subset)"
    expected: "work-laptop row shows status `cut-over`, days-on-v2 >= 7, last-validate-pass populated; commit references work-laptop cutover"
    why_human: "Closes CUTV-04 / CUTV-05 for work-laptop. Requires real-machine install + 7-day soak. Plan 08-06 Task 4 is `autonomous: false`. CONFIRMED operationally pending."
  - test: "After all four rows show cut-over and days-on-v2 >= 7, archive v1 per docs/MIGRATION.md § Archiving v1: rename `dotfiles-v1 -> dotfiles-v1.archive` on each machine (NEVER delete per CUTV-06), push `git push origin master:archive/v1`, update CUTOVER.md table rows to `archived`"
    expected: "All four CUTOVER.md rows show status `archived`; `git ls-remote origin 'refs/heads/archive/v1'` returns a ref; v1 local clones renamed (not deleted)"
    why_human: "Closes CUTV-06. Cross-machine + cross-repo manual git operation; Plan 08-06 Task 5 is `autonomous: false`. CONFIRMED operationally pending."
  - test: "After WR-04 single-pass refactor, run `task validate` on personal-laptop (or server-1 to exercise the n/a sentinel path) and confirm: (a) each component prints output ONCE not twice (b) the summary table renders correctly with check/cross/n/a (c) on server-1 the claude row shows `n/a` (d) `task validate` exit code is 0 when all validates pass and non-zero when any fails"
    expected: "Single-pass output; correct summary; server-1 claude=n/a; exit code reflects rc"
    why_human: "WR-04 changes runtime control flow (single-pass vs double-pass) and uses `eval` for dynamic shell-var naming (`rc_${component}`). Validating this end-to-end requires running task validate on a real machine — the per-component cache dir, the trap-driven cleanup, and the PIPESTATUS[0] capture have not been exercised in CI. Plan 08-06 deferred verification scope includes this per the gsd-code-fixer note in 08-REVIEW-FIX.md."
---

# Phase 8: Validation + Cutover Readiness — Verification Report

**Phase Goal:** A composed `task validate`, two-mode `task links:reconcile` (detect + cleanup), install-time orphan warning, and per-machine cutover gate with a documented fresh-machine verification procedure
**Verified:** 2026-05-16T23:45:00Z
**Status:** human_needed (all 12 engineering must-haves verified; 3 operator-driven cutover tasks operationally pending per user direction; 1 single-pass-validate end-to-end smoke test deferred to first real-machine cutover)
**Re-verification:** Yes — after gsd-code-fixer applied 4 CR + 4 WR fixes (commits 30477ac, 7e8f3f3, d226211, 2f52d82, 8adf7de, 27dd68d, 1e4f153, 6acddd4)

## Re-verification Summary

The prior VERIFICATION.md flagged 4 critical-severity gaps (CR-01..CR-04) from 08-REVIEW.md. The fixer ran one iteration and applied all 8 in-scope fixes (4 critical + 4 warning). This re-verification reads the actual codebase at each cited line and confirms:

1. **CR-01 closed.** `install/cutover-gate.zsh:49-51` now `return 0` when the machine file is absent; lines 44-48 add a comment explaining the fresh-machine semantics. The function header at lines 13-21 documents the new contract (return 0 on fresh machine, return 1 only when the machine file exists but ack is missing/malformed/mismatched). `bootstrap.zsh:112` `cutover_gate_check || exit 1` is therefore now safe on a clean Mac. The README and CUTOVER prose match the code.

2. **CR-02 closed.** Plugin selectors are aligned on `.id`:
   - `taskfiles/claude.yml:133` status-block plugin probe — `select(.id == "ecc@ecc")` (CHANGED from `.name`)
   - `taskfiles/claude.yml:156` install body plugin probe — `select(.id == $i)`
   - `taskfiles/claude.yml:290` validate body plugin probe — `select(.id == $i)`
   - The `.name` selector at line 125 correctly remains because it targets the MARKETPLACE object (the `ecc` marketplace, not the `ecc@ecc` plugin) — different jq query against a different list. The fix also added a critical-comment block at lines 127-132 forcing future refactors to keep the three plugin sites in sync.

3. **CR-03 closed.** `taskfiles/claude.yml:246-263` replaces the `exit 0` after `cross "claude CLI missing"` with an `rc` accumulator pattern: `rc=0` initialized at line 250; `rc=1` set after each missing-CLI cross at lines 255 (claude) and 261 (jq); `exit "$rc"` at line 263. The aggregator at `Taskfile.yml:204-208` therefore captures the correct non-zero exit and renders `cross  claude` in the summary table.

4. **CR-04 closed.** `taskfiles/links.yml:247` adds the ghostty inline-ternary as the first entry of the `configs:` status block: `'{{if not (index .MANIFEST.features "ghostty")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/ghostty/config"{{end}}'`. On a `ghostty=false` machine the ternary renders `true` (status passes, no work needed); on `ghostty=true` a missing ghostty link causes the status entry to fail, forcing the cmds block to run including `task: configs:ghostty`.

Score improves from **8/11 must-haves verified** (4 CR truths failed) to **12/12 must-haves verified** (all 4 prior gaps closed; one additional WR-04 spot-check routed to human verification because the single-pass aggregator refactor changed runtime control flow). No regressions surfaced; the same observable truths verified in the initial pass still hold after the fix commits.

CUTV-04 / CUTV-05 / CUTV-06 remain `human_needed` per the user's pre-verification direction — these are operator-driven cutover runbook tasks (Plan 08-06 was filed with `autonomous: false` by design; require real-machine installs + 7-day per-machine soak + cross-machine v1 archive). Final phase status is therefore `human_needed`, not `passed`, because the human verification block is non-empty.

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                                                                                                       | Status     | Evidence                                                                                                                                                                              |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Root `task validate` exposes a top-level task with the run-all-aggregate semantics; runs all six per-component validates regardless of failure; prints check/cross/n/a summary; exits non-zero on any fail | VERIFIED   | `Taskfile.yml:138-211` declares the aggregator; lines 193-198 invoke each validate once and capture rc via `PIPESTATUS[0]` into a per-component shell variable; lines 199-210 emit the 6-row summary table |
| 2   | `task validate` re-runs each component, captures stdout, greps for D-06 sentinel `feature disabled -- skipped`, and renders `n/a` for feature-off components                                                | VERIFIED   | `Taskfile.yml:202` greps the per-component cache file for the sentinel; `claude.yml:243` emits the sentinel verbatim                                                                  |
| 3   | `task links:reconcile` (default mode) walks EXPECTED_TARGETS parent dirs, detects orphans, exits non-zero on any orphan; CI-safe (CUTV-02)                                                                  | VERIFIED   | `taskfiles/links.yml:402-550` implements the three-mode dispatch; lines 493-503 are the detect-mode branch exiting 1 on any orphan; bounded scan via `-maxdepth 2` at line 487       |
| 4   | `task links:reconcile -- --remove` is TTY-gated and uses `unlink` (never `rm`); y/N per orphan (CUTV-07)                                                                                                    | VERIFIED   | TTY gate at lines 425-429; y/N prompt with default-N at lines 523-525; `unlink` only at line 529                                                                                      |
| 5   | `task links:reconcile -- --warn-only` always exits 0; emits orphans via warn() to stderr; reserved for install-time invocation                                                                              | VERIFIED   | Lines 504-513: warn-only branch always exits 0 regardless of orphan count                                                                                                             |
| 6   | `task install` runs `task links:reconcile -- --warn-only` as the final step before the success line; non-fatal (CUTV-08)                                                                                    | VERIFIED   | `Taskfile.yml:327-328` wires `links:reconcile` with `CLI_ARGS: "--warn-only"` between `packages:verify` and the `success "install complete"` line                                    |
| 7   | `task cutover:ack -- <machine-name>` validates regex, confirms active-machine match, writes ISO-8601 UTC sentinel to `$XDG_STATE_HOME/dotfiles/cutover-ack`; has NO `cutover_gate_check` precondition (Pitfall 7) | VERIFIED   | `Taskfile.yml:242-288`; preconditions at 251-268 enforce regex + active-machine match; writer at 287; no `cutover_gate_check` reference in the cutover:ack block                     |
| 8   | EXPECTED_TARGETS catalog exists in `taskfiles/links.yml` vars block; feature-gated entries use inline-ternary form; identity symlinks intentionally excluded                                                  | VERIFIED   | `taskfiles/links.yml:82-108`; 26 unique entries (13 claude-gated, 1 ghostty-gated, 12 always-on); identity symlinks owned by identity:validate                                       |
| 9   | docs/CUTOVER.md fresh-machine procedure is mechanically correct so an operator following it literally on a clean Mac reaches a successful `task install`                                                    | VERIFIED   | CR-01 fix landed. `install/cutover-gate.zsh:49-51` returns 0 on missing machine file; bootstrap.zsh:112 succeeds; CUTOVER.md:34-38 prose now matches the code. README.md:29-31 mirrors. Operator following the documented procedure no longer hits the bootstrap-exits-1 trap. |
| 10  | `claude:validate` exits non-zero when claude CLI / jq is missing (so aggregator renders cross and bubbles non-zero exit)                                                                                    | VERIFIED   | CR-03 fix landed. `taskfiles/claude.yml:250-263` replaces `exit 0` with rc-accumulator + `exit "$rc"`; aggregator at Taskfile.yml:204-208 now correctly renders `cross  claude` when either CLI is missing. Documented "all six rows must show check or n/a" contract is preserved. |
| 11  | `taskfiles/claude.yml` marketplace status, install body, and validate use the SAME jq selector field for the same plugin object (two-condition idempotency intact)                                          | VERIFIED   | CR-02 fix landed. Plugin selectors aligned on `.id`: line 133 (status), line 156 (install body), line 290 (validate). Marketplace selector at line 125 is `.name` but targets a different object class (marketplace list, not plugin list) — verified by reading the line-125 jq query (`claude plugin marketplace list --json`) vs line-133 query (`claude plugin list --json`). The two-condition idempotency contract at file header lines 25-30 is structurally intact. |
| 12  | `links:configs` task status block enumerates ALL symlinks the cmds block creates (no partial-state regression on feature-gated entries)                                                                     | VERIFIED   | CR-04 fix landed. `taskfiles/links.yml:247` adds the ghostty inline-ternary entry as the first status-block line, mirroring the `claude:` pattern at lines 204-216. On `ghostty=true` machine with broken ghostty link and healthy always-on links, the status block now fails and the cmds block runs (invoking `task: configs:ghostty`). Partial-state regression class closed. |

**Score:** 12/12 truths verified. All 4 prior gaps (truths 9-12) are now VERIFIED with codebase evidence at the cited line numbers.

### Required Artifacts

| Artifact                              | Expected                                                                                                          | Status     | Details                                                                                                                                |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `Taskfile.yml`                        | new top-level `validate:` aggregator + `cutover:ack:` task + `links:reconcile --warn-only` in install pipeline    | VERIFIED   | `validate:` lines 138-211 (single-pass refactor per WR-04); `cutover:ack:` lines 242-288; install pipeline insertion 327-328          |
| `taskfiles/links.yml`                 | EXPECTED_TARGETS var + rewritten links:validate (shell-block, failures counter, exits non-zero on broken links) + new `reconcile:` task with three modes + ghostty in configs: status (CR-04) | VERIFIED   | EXPECTED_TARGETS line 82; links:validate lines 279-377; reconcile: lines 403-550; configs: status with ghostty entry at line 247    |
| `taskfiles/claude.yml`                | D-06 sentinel `feature disabled -- skipped` emitted on `claude-marketplace=false`; rc-accumulator (CR-03); aligned plugin selectors (CR-02); leading-colon deps (WR-01) | VERIFIED   | Sentinel at line 243; rc accumulator + exit "$rc" at lines 250-263; plugin selectors aligned on `.id` at lines 133, 156, 290; deps `":manifest:resolve"` at 88, 116, 194 |
| `install/cutover-gate.zsh`            | (preexisting; modified in P8 for CR-01) — fresh-machine path returns 0; reader contract `<machine> <ts>` line on line 63 | VERIFIED   | Lines 44-51 implement the fresh-machine return-0 path with comment block documenting the contract; lines 63-72 unchanged from prior reader logic; header comment at lines 13-21 documents the new contract |
| `bootstrap.zsh`                       | Source cutover-gate + invoke `cutover_gate_check || exit 1` (line 112) — relies on CR-01 fix to not abort on fresh | VERIFIED   | Line 112 unchanged; CR-01 fixed the gate to return 0 on fresh, so this line is now safe                                              |
| `docs/CUTOVER.md`                     | H1 + Fresh-machine verification (8 numbered steps with matching prose) + Per-machine state table (4 rows × 6 cols) | VERIFIED   | Step 2 prose at lines 31-38 now matches code (CR-01); step 6 prose at lines 66-76 now matches code (WR-02 — only claude:validate emits sentinel); 4 machine rows present |
| `docs/MACHINES.md`                    | H1 + per-machine H2 (4 sections) + deference line per section; no tables                                          | VERIFIED   | 4 H2 sections present; no markdown tables (`grep -c '^|'` == 0)                                                                       |
| `docs/MIGRATION.md`                   | H1 + 7 concept H2s + Rollback + Archiving v1; per-concept path-mapping tables                                     | VERIFIED   | All 9 H2 sections present; 38 table rows                                                                                              |
| `README.md`                           | Full replacement: H1 `# dotfiles` + What This Is + Fresh Machine Setup (5 commands incl. cutover:ack) + Where to Add Things + Documentation; CR-01 prose alignment | VERIFIED   | All four H2 sections present; 5-command fenced block confirmed at lines 33-39; CR-01 alignment at lines 26-31 (bootstrap completes cleanly on fresh machine; task install precondition is the hard-fail gate) |

### Key Link Verification

| From                                          | To                                                          | Via                                              | Status   | Details                                                                                                          |
| --------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------ | -------- | ---------------------------------------------------------------------------------------------------------------- |
| Taskfile.yml validate:                        | `:manifest:validate / :identity:validate / :links:validate / :macos:validate / :packages:validate / :claude:validate` | single-pass for-loop with `tee` + `PIPESTATUS[0]` capture | WIRED    | Lines 193-198 invoke each validate once and capture exit code; lines 199-210 read the cache files for summary rendering |
| Taskfile.yml validate: summary block          | `install/messages.zsh`                                      | `source '{{.TASKFILE_DIR}}/install/messages.zsh'` | WIRED    | Line 180 sources directly via TASKFILE_DIR (DOTFILEDIR pollution workaround documented in 08-02-SUMMARY)         |
| Taskfile.yml install:                         | `:links:reconcile` (warn-only mode)                         | `task: links:reconcile` with `CLI_ARGS: --warn-only` | WIRED    | Lines 327-328; non-fatal because reconcile internally exits 0 in --warn-only                                     |
| Taskfile.yml cutover:ack:                     | `$XDG_STATE_HOME/dotfiles/cutover-ack`                      | `printf '%s %s\n' "${CLI_ARGS_ENV}" "$ts"`       | WIRED    | Line 287 writes sentinel; reader (install/cutover-gate.zsh:63) parses it cleanly                                 |
| bootstrap.zsh                                 | `install/cutover-gate.zsh::cutover_gate_check`              | `source` + `cutover_gate_check || exit 1`         | WIRED    | Lines 111-112; gate now returns 0 on fresh machine (CR-01), so bootstrap reaches next-step hint at lines 117-124 |
| taskfiles/links.yml reconcile:                | `{{.EXPECTED_TARGETS}}`                                     | `while IFS= read -r line` consumer loop          | WIRED    | Lines 438-441 enumerate the catalog; orphan walk bounded to parent dirs of EXPECTED_TARGETS entries              |
| taskfiles/links.yml validate:                 | `{{.EXPECTED_TARGETS}}`                                     | `while IFS= read -r target` consumer loop        | WIRED    | Lines 346-375 iterate the catalog with three-condition symlink check + failures counter + `exit "$failures"`     |
| taskfiles/links.yml configs:                  | `configs:ghostty` sub-task                                  | `task: configs:ghostty` in cmds + ghostty status entry at line 247 | WIRED    | CR-04 fix ensures partial-state regression cannot short-circuit the cmds block; both feature-on and feature-off paths covered by the inline-ternary |
| taskfiles/claude.yml marketplace:             | plugin install via `claude plugin install`                   | jq selector `.id == $i`                          | WIRED    | Selector aligned with status-block selector at line 133 (CR-02); two-condition idempotency contract intact      |
| docs/CUTOVER.md                               | `docs/SECURITY.md`, `docs/MANIFEST.md`, `docs/MIGRATION.md` | inline references in numbered procedure          | WIRED    | All three cross-references present; step 2 -> SECURITY, step 3 -> MANIFEST, step 8 -> MIGRATION                  |
| README.md                                     | 6 sibling docs                                              | Documentation bullet list                        | WIRED    | All six paths present at lines 62-67: MANIFEST, SECURITY, CUTOVER, MIGRATION, MACHINES, .claude/CLAUDE.md         |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `task validate` summary | `rc_${component}`, cache file per component | each `task ${component}:validate` invocation; PIPESTATUS[0] capture; tempfile in `mktemp -d` cache dir | YES — single-pass design at Taskfile.yml:193-198 actually runs each validate and captures real rc + real stdout per component | FLOWING |
| `task links:reconcile` orphan walk | `orphans[]` | `find $parent_dir -maxdepth 2 -type l` + EXPECTED_TARGETS membership check | YES — bounded scan of real parent directories derived from EXPECTED_TARGETS | FLOWING |
| `task cutover:ack` sentinel | `${CLI_ARGS_ENV}`, `$ts` | env var + `date -u +ISO-8601` | YES — Taskfile.yml:287 writes a real sentinel file consumed by install/cutover-gate.zsh:63 | FLOWING |
| `claude:validate` D-06 sentinel | feature flag `claude-marketplace` | `index .MANIFEST.features "claude-marketplace"` resolved at task-graph build time | YES — sentinel emitted on `claude-marketplace=false` per the inline `{{if}}` gate at claude.yml:242-245 | FLOWING |
| `cutover_gate_check` machine-file path | `$machine_file` | `${XDG_STATE_HOME}/dotfiles/machine` | YES — line 49 reads the path; line 52 reads the active machine name from the file when present | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| `claude:validate` exits non-zero on missing CLI (CR-03 fix) | Read taskfiles/claude.yml:250-263 | `rc=0` init; `rc=1` on each missing CLI; `exit "$rc"` at end of cmds[0] | PASS |
| Marketplace plugin selectors aligned (CR-02 fix) | Read taskfiles/claude.yml:133, 156, 290 | All three use `.id` selector for plugin object; line 125 uses `.name` but targets the marketplace object (different list) | PASS |
| `configs:` status block includes ghostty (CR-04 fix) | Read taskfiles/links.yml:247 | Ghostty inline-ternary entry present as first status-block line: `{{if not (index .MANIFEST.features "ghostty")}}true{{else}}test -L ...{{end}}` | PASS |
| `cutover-gate.zsh` returns 0 on missing machine file (CR-01 fix) | Read install/cutover-gate.zsh:49-51 | `if [[ ! -f "$machine_file" ]]; then return 0; fi` | PASS |
| Bootstrap completes cleanly on fresh machine | Read bootstrap.zsh:111-124 | `cutover_gate_check || exit 1` at line 112; gate returns 0 on fresh; next-step hint at lines 117-124 prints | PASS |
| README + CUTOVER prose match code | Read README.md:26-31 + docs/CUTOVER.md:31-38 | Both now state that bootstrap completes cleanly on fresh machine; task install precondition is what hard-fails when ack is missing | PASS |
| WR-01 — claude.yml deps unified | Read taskfiles/claude.yml:88, 116, 194 | All three use `":manifest:resolve"` leading-colon form | PASS |
| WR-02 — CUTOVER.md step 6 prose matches code | Read docs/CUTOVER.md:66-76 | "Currently only `claude:validate` emits the `feature disabled -- skipped` sentinel substring..." | PASS |
| WR-03 — links:reconcile case statement has catch-all | Read taskfiles/links.yml:540-549 | `*) error "..."; exit 1 ;;` branch present | PASS |
| WR-04 — validate aggregator is single-pass | Read Taskfile.yml:158-211 | mktemp -d + tee + PIPESTATUS[0] + `trap 'rm -rf "$cache_dir"' EXIT`; no `ignore_error: true` references; each validate runs once | PASS |
| No standalone `{{end}}` cmds entries in links.yml (lint hygiene from prior pass) | Read taskfiles/links.yml | Still 0 — confirmed by inspection | PASS |
| No `rm -rf` in links.yml outside trap cleanup (security) | Read taskfiles/links.yml | Only `unlink` is used for orphan removal at line 529; no `rm -rf` against orphans | PASS |

### Probe Execution

No probe scripts declared in the phase plans or success criteria; phase used live `task` invocations as the empirical verification mechanism, exercised in the initial verification pass. The re-verification is read-only against the modified files. Step 7c not applicable.

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                                                                                                                                              | Status                  | Evidence                                                                                                                       |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| CUTV-01     | 08-02       | `task validate` composes all per-component validate tasks with check/cross output                                                                                                                                       | SATISFIED               | Aggregator implemented in Taskfile.yml:138-211 (single-pass per WR-04); check/cross/n/a output via messages.zsh; CR-03 fix ensures missing-CLI rows render cross |
| CUTV-02     | 08-01, 08-03 | `task links:reconcile` (default mode) detects orphans and exits non-zero                                                                                                                                                | SATISFIED               | Lines 493-503 of taskfiles/links.yml; detect-mode branch exits 1 on any orphan                                                |
| CUTV-03     | 08-04       | `docs/CUTOVER.md` tracks per-machine cutover state with verification steps                                                                                                                                              | SATISFIED               | Per-machine state table present with 4 rows; status vocabulary documented; CR-01 prose fix aligns step 2 with code            |
| CUTV-04     | 08-06       | All four target machines installable from v2 with 100% `task validate` pass                                                                                                                                             | OPERATIONALLY PENDING   | Plan 08-06 Task 1-4 are `autonomous: false`; require real-machine installs + 7-day soak per machine; routed to human verification |
| CUTV-05     | 08-06       | Each machine runs v2 for at least 7 days without falling back to v1 before being declared cut over                                                                                                                       | OPERATIONALLY PENDING   | Calendar-driven 7-day soak per machine; cannot run inside an agent invocation; routed to human verification                    |
| CUTV-06     | 08-06       | Old repo archived (not deleted) after final per-machine cutover                                                                                                                                                          | OPERATIONALLY PENDING   | Cross-machine + cross-repo manual git operation; depends on CUTV-04/05 completion across all four machines; routed to human verification |
| CUTV-07     | 08-03       | `task links:reconcile -- --remove` enters interactive cleanup mode; y/N per orphan; never silent                                                                                                                         | SATISFIED               | TTY gate at links.yml:425-429; y/N prompt with default-N at lines 523-525; `unlink` only at line 529                          |
| CUTV-08     | 08-03       | `task install` runs `task links:reconcile` in detect-only mode at the end and warns (non-fatal) if orphans exist                                                                                                         | SATISFIED               | Taskfile.yml:327-328 wires `links:reconcile --warn-only` after packages:verify; non-fatal because warn-only exits 0 internally |
| DOCS-01     | 08-05       | Top-level `README.md` explains the manifest model, machine setup flow, and where to add things                                                                                                                          | SATISFIED               | README.md fully replaced; all four H2 sections present; CR-01 prose fix at lines 26-31 aligns the fresh-machine block with code |
| DOCS-05     | 08-05       | `docs/MIGRATION.md` records v1-to-v2 mapping and cutover plan                                                                                                                                                            | SATISFIED               | All 7 concept H2s + Rollback + Archiving v1 present; 38 table rows                                                             |
| DOCS-06     | 08-04       | `docs/MACHINES.md` documents each machine's purpose, identity, and special config                                                                                                                                       | SATISFIED               | Four H2 sections; per-machine deference line to TOML                                                                           |
| DOCS-08     | 08-04       | `docs/CUTOVER.md` includes a per-machine fresh-install verification procedure                                                                                                                                            | SATISFIED               | 8 numbered steps present; step 2 prose (CR-01) and step 6 prose (WR-02) both now match code behavior                          |

Total declared requirements for Phase 8: 12 — all 12 are mapped to plan frontmatter and all 12 are present in REQUIREMENTS.md against this phase. Zero orphaned requirements; zero unmapped requirements. **All 9 SATISFIED requirements are codebase-verified; the 3 OPERATIONALLY PENDING requirements are deferred to operator-driven cutover runbook execution per user direction.**

### Anti-Patterns Found

| File                      | Line     | Pattern                                                                                                                                                                                                                                       | Severity   | Impact                                                                                                                                                                                                                                                                                                              |
| ------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (none)                    | -        | All prior CR-level and WR-level anti-patterns from the initial verification pass have been closed by the fixer in this iteration. No new anti-patterns introduced. | INFO       | The fixer's iteration applied all 8 in-scope review findings; the WR-04 single-pass refactor (which changes runtime control flow and uses `eval` for dynamic shell-var naming) is the only fix that warrants end-to-end behavioral confirmation on a real machine — routed to human verification.                  |

### Human Verification Required

See `human_verification` block in frontmatter. **Six items total**, unchanged in count and scope from the initial verification pass:

- **Five items (CUTV-04 / CUTV-05 / CUTV-06)** are the deferred operator-driven cutover runbook tasks. Plan 08-06 was filed with `autonomous: false` by design; tasks 1-5 are operationally pending per the user's pre-verification direction. These cannot be executed inside an agent invocation because they require real-machine installs across four target machines + a 7-day soak per machine + a multi-machine v1 archive operation. They will be closed by the operator manually after the calendar-driven soak windows elapse.

- **One item (WR-04 single-pass validate)** is a post-fix end-to-end behavioral confirmation. The WR-04 refactor changed `task validate` from a two-phase double-run design to a single-pass design using `mktemp -d` + `tee` + `PIPESTATUS[0]` + `eval`-based dynamic shell-var naming + `trap` cleanup. Re-verification confirmed the YAML/shell code is correct by inspection, but the run-time behavior of the `eval "rc_${component}=\${PIPESTATUS[0]}"` pattern and the `trap 'rm -rf "$cache_dir"' EXIT` cleanup has not been exercised in CI. This is most efficiently validated as part of the first operator-driven cutover (e.g., personal-laptop) per the gsd-code-fixer's note in 08-REVIEW-FIX.md.

### Gaps Summary

**Engineering deliverables present, working, and goal-backward-verified.** All 4 critical review findings (CR-01..CR-04) from the prior verification pass have been closed by the fixer's commits at the cited line numbers. All 4 warning-level findings (WR-01..WR-04) were also resolved in the same iteration. Codebase-evidence-verified score is **12/12 truths VERIFIED, 9/12 requirements SATISFIED, 3/12 OPERATIONALLY PENDING (CUTV-04/05/06)**.

**No engineering gaps remain.** The phase goal as stated in ROADMAP.md ("A composed `task validate`, two-mode `task links:reconcile` (detect + cleanup), install-time orphan warning, and per-machine cutover gate with a documented fresh-machine verification procedure") is verifiably achieved by the codebase as committed.

**Status is `human_needed` not `passed`** because the verification methodology mandates `human_needed` whenever the human_verification block is non-empty, regardless of how many truths are VERIFIED. The 6 human-verification items here are entirely operator-driven (CUTV-04/05/06 cutover runbook for 4 machines + v1 archive operation + one post-fix end-to-end smoke test). These are not engineering gaps — they are tasks deliberately filed as `autonomous: false` in plan 08-06 and confirmed operationally pending by the user at the in-session checkpoint before this re-verification ran.

---

_Re-verified: 2026-05-16T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
_Iteration: 2 (initial verification + post-fix re-verification)_
