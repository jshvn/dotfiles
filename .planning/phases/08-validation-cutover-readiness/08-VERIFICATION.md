---
phase: 08-validation-cutover-readiness
verified: 2026-05-16T22:30:00Z
status: human_needed
score: 8/11 must-haves verified (3 operationally pending; 4 advisory CR findings unresolved)
overrides_applied: 0
gaps:
  - truth: "claude:validate reports `cross` and exits 0 on missing CLI (CR-03); root `task validate` then renders the row green even though the per-component output already printed cross"
    status: failed
    reason: "Reviewer CR-03 — `taskfiles/claude.yml:244` does `exit 0` after `cross \"claude CLI missing\"`. The aggregator captures rc=0 (Taskfile.yml:189-193) and prints check. This silently passes a known-broken state and undermines CUTV-01's check/cross contract (Success Criterion #1)."
    artifacts:
      - path: taskfiles/claude.yml
        issue: "Lines 240-249: both missing-claude and missing-jq paths print cross but do not set rc=1 / exit non-zero."
    missing:
      - "Replace `exit 0` on missing CLI with rc=1 tracking; same for jq branch; aggregate `exit \"$rc\"` at end of the cmds[0] block (or remove the misleading cross-without-failure pattern entirely)."
  - truth: "`task links:configs` status block omits the ghostty link entry (CR-04); on a ghostty=true machine where only the ghostty link is broken but the always-on configs are healthy, `task configs` short-circuits on status and never invokes `configs:ghostty` — the file's own header comment explicitly warns against this exact regression class"
    status: failed
    reason: "Reviewer CR-04 — `taskfiles/links.yml configs:` status block (lines 241-247) lists only the 6 always-on links and omits the ghostty link. go-task semantics: status pass skips the entire cmds block (including the `task: configs:ghostty` delegation). The file's header comment at links.yml:25-30 calls this out as the exact partial-state regression class CR-02 was supposed to close."
    artifacts:
      - path: taskfiles/links.yml
        issue: "Lines 224-247: configs: status block missing inline-ternary entry for `{{.XDG_CONFIG_HOME}}/ghostty/config` mirroring the claude: status pattern at lines 203-216."
    missing:
      - "Add inline-ternary status line `'{{if not (index .MANIFEST.features \"ghostty\")}}true{{else}}test -L \"{{.XDG_CONFIG_HOME}}/ghostty/config\"{{end}}'` to the configs: status block; OR remove the status: block from configs: entirely and rely on per-sub-task idempotency."
  - truth: "marketplace status block uses `.name` selector while install body and validate use `.id` (CR-02); selectors disagree on the same plugin object so the two-condition status idempotency claim at the top of taskfiles/claude.yml is structurally broken"
    status: failed
    reason: "Reviewer CR-02 — claude.yml:127 uses `select(.name == \"ecc@ecc\")` (status block) while claude.yml:150 and claude.yml:277 use `select(.id == $i)`. One selector always fails for the same plugin object; either status never converges (always-re-run, exactly the v1 macos:shell:145 idempotency regression class this phase explicitly closes per its `## Decisions` block) or install/validate always think the plugin is missing."
    artifacts:
      - path: taskfiles/claude.yml
        issue: "Line 127 selector disagrees with lines 150 and 277; the three MUST agree on the same jq field for the same plugin object."
    missing:
      - "Align all three selectors on the same field. Verify against `claude plugin list --json` output shape on a real machine, then use that field consistently in status, install, and validate."
  - truth: "docs/CUTOVER.md fresh-machine procedure step 2 claims `./bootstrap.zsh` exits cleanly on a fresh machine; the actual code in `install/cutover-gate.zsh:35-38` returns 1 when `$XDG_STATE_HOME/dotfiles/machine` is absent and `bootstrap.zsh:112` invokes `cutover_gate_check || exit 1`. The documented procedure cannot complete as written (CR-01)"
    status: failed
    reason: "Reviewer CR-01 — CUTOVER.md step 2 says: 'the cutover-gate is invoked at the end of bootstrap for completeness but exits cleanly because no machine has been selected yet'. The code disagrees: cutover-gate.zsh's first check (lines 35-38) emits `no machine selected` and returns 1; bootstrap.zsh exits 1 BEFORE printing the next-step hint. A clean Mac following the README/CUTOVER procedure literally would error out at step 2."
    artifacts:
      - path: docs/CUTOVER.md
        issue: "Step 2 prose (lines 33-38) contradicts install/cutover-gate.zsh behavior on missing machine file."
      - path: install/cutover-gate.zsh
        issue: "Lines 35-38: missing-machine-file path returns 1 instead of returning 0 (gate not applicable until task setup runs)."
      - path: bootstrap.zsh
        issue: "Line 112: `cutover_gate_check || exit 1` propagates the gate's `return 1` and aborts the bootstrap before the next-step hint prints."
    missing:
      - "Pick one of: (Option B, recommended) Change `cutover-gate.zsh` to `return 0` when the machine file is absent (gate not yet applicable; install: precondition still enforces ack when the machine file exists). The defense-in-depth at `task install` precondition is preserved because `task setup` writes the machine file before the user reaches `task install`. OR (Option A) Update CUTOVER.md step 2 and README.md to say bootstrap exits non-zero on fresh machine and tell users to ignore that exit / re-run after setup+ack."
human_verification:
  - test: "Cut over personal-laptop per docs/CUTOVER.md § Fresh-machine verification end-to-end (engineering verifier already ran task install + task validate on personal-laptop during D-03); update docs/CUTOVER.md row from `planning` -> `soaking` -> after 7 days `cut-over`; commit"
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
  - test: "After CR-01..CR-04 are resolved (either fixed or documented as accepted deviations), re-run `task install` on personal-laptop and visually confirm: (a) bootstrap.zsh prints next-step hint on fresh machine without exiting 1, (b) `task validate` shows check or n/a for all 6 components, (c) `task install` end-to-end completes with orphan-warn step printing before the success line"
    expected: "Bootstrap completes on fresh machine; full install pipeline runs to success line; aggregator summary shows green/n/a for all 6 components"
    why_human: "End-to-end install behavior on a fresh machine cannot be programmatically simulated from this worktree (worktree-vs-live DOTFILEDIR mismatch documented in 08-01-SUMMARY); needs operator drive on a real target machine after CR-01..CR-04 land."
---

# Phase 8: Validation + Cutover Readiness — Verification Report

**Phase Goal:** A composed `task validate`, two-mode `task links:reconcile` (detect + cleanup), install-time orphan warning, and per-machine cutover gate with a documented fresh-machine verification procedure
**Verified:** 2026-05-16T22:30:00Z
**Status:** human_needed (engineering substantially complete; 4 advisory CR findings demand resolution before production cutover; CUTV-04/05/06 operationally pending per user direction)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                                                                                                       | Status            | Evidence                                                                                                                                                                              |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Root `task validate` exposes a top-level task with the run-all-aggregate semantics; runs all six per-component validates regardless of failure; prints check/cross/n/a summary; exits non-zero on any fail | VERIFIED          | `task --list` shows `validate:`; `Taskfile.yml:138-199` declares the aggregator with 6 per-entry `ignore_error: true` lines and a summary block; live `task validate` prints `── Validation Summary ──` with 6 rows |
| 2   | `task validate` re-runs each component, captures stdout, greps for D-06 sentinel `feature disabled -- skipped`, and renders `n/a` for feature-off components                                                | VERIFIED          | `Taskfile.yml:190-196` greps for sentinel and emits `info "n/a ..."`; claude.yml:237 emits the sentinel verbatim                                                                       |
| 3   | `task links:reconcile` (default mode) walks EXPECTED_TARGETS parent dirs, detects orphans, exits non-zero on any orphan; CI-safe (CUTV-02)                                                                  | VERIFIED          | Live run: `task links:reconcile` exit 201 with WARN orphans printed; `taskfiles/links.yml:397-534` implements three-mode dispatch                                                     |
| 4   | `task links:reconcile -- --remove` is TTY-gated and uses `unlink` (never `rm`); y/N per orphan (CUTV-07)                                                                                                    | VERIFIED          | Live run: `echo '' \| task links:reconcile -- --remove` exit 201 with `requires an interactive TTY` error; `grep -c 'rm -rf' taskfiles/links.yml` = 0; `unlink` used in remove branch |
| 5   | `task links:reconcile -- --warn-only` always exits 0; emits orphans via warn() to stderr; reserved for install-time invocation                                                                              | VERIFIED          | Live run: exit 0 with WARN lines; `Taskfile.yml:315-316` wires it into the install pipeline between packages:verify and the success line                                              |
| 6   | `task install` runs `task links:reconcile -- --warn-only` as the final step before the success line; non-fatal (CUTV-08)                                                                                    | VERIFIED          | `Taskfile.yml:315-316` confirms the wiring; D-11 non-fatal-mode contract preserved (--warn-only swallows non-zero exit internally)                                                    |
| 7   | `task cutover:ack -- <machine-name>` validates regex, confirms active-machine match, writes ISO-8601 UTC sentinel to `$XDG_STATE_HOME/dotfiles/cutover-ack`; has NO `cutover_gate_check` precondition (Pitfall 7) | VERIFIED          | Live: exit 201 for no-arg / bad-name / mismatch; exit 0 for valid match; sentinel file present `personal-laptop 2026-05-16T22:11:31Z`; `awk` extraction confirms no `cutover_gate_check` in cutover:ack block |
| 8   | EXPECTED_TARGETS catalog exists in `taskfiles/links.yml` vars block; feature-gated entries use inline-ternary form; identity symlinks intentionally excluded                                                  | VERIFIED          | `taskfiles/links.yml:82-108` declares 26 unique entries (claude-gated × 13, ghostty-gated × 1, always-on × 12); identity symlinks owned by identity:validate                          |
| 9   | docs/CUTOVER.md fresh-machine procedure is mechanically correct so an operator following it literally on a clean Mac reaches a successful `task install`                                                    | FAILED (CR-01)    | CUTOVER.md:33-38 claims bootstrap "exits cleanly" on fresh machine; install/cutover-gate.zsh:35-38 returns 1 when machine file absent; bootstrap.zsh:112 `\|\| exit 1` aborts the script. README.md inherits the same defect at line 24-36. |
| 10  | `claude:validate` exits non-zero when claude CLI / jq is missing (so aggregator renders cross and bubbles non-zero exit)                                                                                    | FAILED (CR-03)    | `taskfiles/claude.yml:244` does `exit 0` after `cross "claude CLI missing"`; aggregator at `Taskfile.yml:192-193` captures rc=0 and renders check; documented "all six rows must show check" contract is violated when CLI is missing |
| 11  | `taskfiles/claude.yml` marketplace status, install body, and validate use the SAME jq selector field for the same plugin object (two-condition idempotency intact)                                          | FAILED (CR-02)    | Line 127 `select(.name == "ecc@ecc")` vs lines 150, 277 `select(.id == $i)`. One always fails for the same object. The two-condition idempotency claim at file header lines 25-30 is structurally broken. |
| 12  | `links:configs` task status block enumerates ALL symlinks the cmds block creates (no partial-state regression on feature-gated entries)                                                                     | FAILED (CR-04)    | `taskfiles/links.yml:241-247` status block lists 6 always-on entries; cmds block has 7 entries (6 + `task: configs:ghostty`). On healthy-always-on + broken-ghostty state, status pass skips the cmds block and `configs:ghostty` is never invoked. File header at lines 25-30 explicitly warns against this exact regression class. |

**Score:** 8/12 truths verified. Truths 9-12 correspond to the four CRITICAL review findings (CR-01..CR-04). Per user direction the workflow does not block on the advisory review — but goal-backward verification cannot pretend the failures are not in the codebase. They are listed as `gaps_found` with concrete fix paths.

### Required Artifacts

| Artifact                              | Expected                                                                                                          | Status                  | Details                                                                                                                                |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `Taskfile.yml`                        | new top-level `validate:` aggregator + `cutover:ack:` task + `links:reconcile --warn-only` in install pipeline    | VERIFIED                | `validate:` lines 138-199; `cutover:ack:` lines 230-276; install pipeline insertion 315-316                                            |
| `taskfiles/links.yml`                 | EXPECTED_TARGETS var + rewritten links:validate (shell-block, failures counter, exits non-zero on broken links) + new `reconcile:` task with three modes | VERIFIED                | EXPECTED_TARGETS line 82; links:validate lines 272-371; reconcile: lines 397-534                                                       |
| `taskfiles/claude.yml`                | D-06 sentinel `feature disabled -- skipped` emitted on `claude-marketplace=false`                                 | VERIFIED                | Line 237 emits sentinel; per-cmds-entry short-circuit at lines 257, 273, 284                                                           |
| `docs/CUTOVER.md`                     | H1 + Fresh-machine verification (8 numbered steps) + Per-machine state table (4 rows × 6 cols)                    | VERIFIED (with CR-01)   | Heading structure correct; 4 machine rows present; status vocabulary documented; **step 2 prose is factually wrong per CR-01**         |
| `docs/MACHINES.md`                    | H1 + per-machine H2 (4 sections) + deference line per section; no tables                                          | VERIFIED                | 4 H2 sections present; `grep -c '^\|' docs/MACHINES.md` = 0                                                                            |
| `docs/MIGRATION.md`                   | H1 + 7 concept H2s + Rollback + Archiving v1; per-concept path-mapping tables                                     | VERIFIED                | All 9 H2 sections present; `grep -c '^\|' docs/MIGRATION.md` = 38 (well above min 7)                                                   |
| `README.md`                           | Full replacement: H1 `# dotfiles` + What This Is + Fresh Machine Setup (5 commands incl. cutover:ack) + Where to Add Things + Documentation | VERIFIED (inherits CR-01) | All four H2 sections present; 5-command fenced block confirmed; **inherits CR-01 from CUTOVER.md prose** because README points users at CUTOVER for the full procedure |
| `install/cutover-gate.zsh`            | (preexisting; not modified in P8) — reader contract `<machine> <ts>` line                                          | VERIFIED                | Line 50 reader contract intact; cutover:ack writer matches the contract; sentinel parses cleanly                                       |

### Key Link Verification

| From                                          | To                                                          | Via                                              | Status   | Details                                                                                                          |
| --------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------ | -------- | ---------------------------------------------------------------------------------------------------------------- |
| Taskfile.yml validate:                        | `:manifest:validate / :identity:validate / :links:validate / :macos:validate / :packages:validate / :claude:validate` | 6 `task:` entries with `ignore_error: true`      | WIRED    | Lines 151-162 of Taskfile.yml dispatch all six per-component validates                                          |
| Taskfile.yml validate: summary block          | `install/messages.zsh`                                      | `source '{{.TASKFILE_DIR}}/install/messages.zsh'` | WIRED    | Line 178 sources directly via TASKFILE_DIR (DOTFILEDIR pollution workaround documented in 08-02-SUMMARY)        |
| Taskfile.yml install:                         | `:links:reconcile` (warn-only mode)                         | `task: links:reconcile` with `CLI_ARGS: --warn-only` | WIRED    | Lines 315-316; non-fatal because reconcile internally exits 0 in --warn-only                                    |
| Taskfile.yml cutover:ack:                     | `$XDG_STATE_HOME/dotfiles/cutover-ack`                      | `printf '%s %s\n' "${CLI_ARGS_ENV}" "$ts"`       | WIRED    | Line 275 writes sentinel; reader (install/cutover-gate.zsh:50) parses it cleanly                                |
| taskfiles/links.yml reconcile:                | `{{.EXPECTED_TARGETS}}`                                     | `while IFS= read -r line` consumer loop          | WIRED    | Lines 432-435 enumerate the catalog; orphan walk bounded to parent dirs of EXPECTED_TARGETS entries             |
| taskfiles/links.yml validate:                 | `{{.EXPECTED_TARGETS}}`                                     | `while IFS= read -r target` consumer loop        | WIRED    | Lines 340-369 iterate the catalog with three-condition symlink check + failures counter + `exit "$failures"`     |
| docs/CUTOVER.md                               | `docs/SECURITY.md`, `docs/MANIFEST.md`, `docs/MIGRATION.md` | inline references in numbered procedure          | WIRED    | All three cross-references present; step 2 -> SECURITY, step 3 -> MANIFEST, step 8 -> MIGRATION                |
| README.md                                     | 6 sibling docs                                              | Documentation bullet list                        | WIRED    | All six paths present: MANIFEST, SECURITY, CUTOVER, MIGRATION, MACHINES, .claude/CLAUDE.md                       |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `task validate` summary | `output`, `rc` per component | re-invocation of each `task ${component}:validate` | YES — captures actual exit codes and stdout from real validate tasks | FLOWING |
| `task links:reconcile` orphan walk | `orphans[]` | `find $parent_dir -maxdepth 2 -type l` + EXPECTED_TARGETS membership check | YES — live run on this worktree found 2 actual orphans under `~/.config/claude/hooks/` (worktree artifact) | FLOWING |
| `task cutover:ack` sentinel | `${CLI_ARGS_ENV}`, `$ts` | env var + `date -u +ISO-8601` | YES — sentinel file confirmed at `~/.local/state/dotfiles/cutover-ack` with valid `personal-laptop 2026-05-16T22:11:31Z` | FLOWING |
| `claude:validate` D-06 sentinel | feature flag `claude-marketplace` | `index .MANIFEST.features "claude-marketplace"` resolved at task-graph build time | YES — sentinel emitted on server-1 manifest swap per 08-02-SUMMARY | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Aggregator runs all 6 validates with run-all semantics | `task validate` | Summary table prints 6 rows (manifest, identity, links, macos, packages, claude); link fail does not abort the loop; rc 1 from summary block | PASS |
| Reconcile default mode exits non-zero on orphan | `task links:reconcile` | exit 201 with WARN orphan lines printed | PASS |
| Reconcile warn-only mode exits 0 even with orphan present | `task links:reconcile -- --warn-only` | exit 0; WARN lines printed to stderr | PASS |
| Reconcile remove mode TTY-gates | `echo '' \| task links:reconcile -- --remove` | exit 201; "requires an interactive TTY" error | PASS |
| cutover:ack rejects missing arg | `task cutover:ack` | exit 201 with precondition error | PASS |
| cutover:ack rejects invalid regex | `task cutover:ack -- "BAD NAME"` | exit 201 | PASS |
| cutover:ack rejects active-machine mismatch | `task cutover:ack -- _nonexistent-machine` | exit 201 | PASS |
| cutover:ack writes sentinel for valid match | (sentinel already present from prior run) | `personal-laptop 2026-05-16T22:11:31Z` parses correctly via `read -r ack_machine ack_ts` | PASS |
| Top-level tasks exposed | `task --list \| grep -E '^* (validate\|cutover:ack\|links:reconcile)'` | All three present | PASS |
| No standalone `{{end}}` cmds entries in links.yml (lint hygiene) | `grep -cE "^[[:space:]]*-[[:space:]]*'\{\{end\}\}'\$" taskfiles/links.yml` | 0 | PASS |
| No `rm -rf` in links.yml (security) | `grep -cE 'rm -rf' taskfiles/links.yml` | 0 | PASS |
| No unsafe `parent_dirs=($(...))` pattern (security) | `grep -cE 'parent_dirs=\(\$\(' taskfiles/links.yml` | 0 | PASS |

### Probe Execution

No probe scripts declared in the phase plans or success criteria; phase used live `task` invocations as the empirical verification mechanism, which the spot-checks above exercised directly. Step 7c not applicable.

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                                                                                                                                              | Status                  | Evidence                                                                                                                       |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| CUTV-01     | 08-02       | `task validate` composes all per-component validate tasks with check/cross output                                                                                                                                       | SATISFIED               | Aggregator implemented in Taskfile.yml:138-199; live run confirms 6-row summary table; check/cross output via messages.zsh    |
| CUTV-02     | 08-01, 08-03 | `task links:reconcile` (default mode) detects orphans and exits non-zero                                                                                                                                                | SATISFIED               | Live: `task links:reconcile` exit 201 on orphan; EXPECTED_TARGETS catalog at links.yml:82                                     |
| CUTV-03     | 08-04       | `docs/CUTOVER.md` tracks per-machine cutover state with verification steps                                                                                                                                              | SATISFIED               | Per-machine state table present with 4 rows; status vocabulary documented                                                      |
| CUTV-04     | 08-06       | All four target machines installable from v2 with 100% `task validate` pass                                                                                                                                             | OPERATIONALLY PENDING   | Plan 08-06 Task 1-4 are `autonomous: false`; require real-machine installs + 7-day soak per machine; routed to human verification |
| CUTV-05     | 08-06       | Each machine runs v2 for at least 7 days without falling back to v1 before being declared cut over                                                                                                                       | OPERATIONALLY PENDING   | Calendar-driven 7-day soak per machine; cannot run inside an agent invocation; routed to human verification                    |
| CUTV-06     | 08-06       | Old repo archived (not deleted) after final per-machine cutover                                                                                                                                                          | OPERATIONALLY PENDING   | Cross-machine + cross-repo manual git operation; depends on CUTV-04/05 completion across all four machines; routed to human verification |
| CUTV-07     | 08-03       | `task links:reconcile -- --remove` enters interactive cleanup mode; y/N per orphan; never silent                                                                                                                         | SATISFIED               | TTY gate at links.yml:419-424; y/N prompt with default-N at lines 517-518; `unlink` only at line 523                          |
| CUTV-08     | 08-03       | `task install` runs `task links:reconcile` in detect-only mode at the end and warns (non-fatal) if orphans exist                                                                                                         | SATISFIED               | Taskfile.yml:315-316 wires `links:reconcile --warn-only` after packages:verify; non-fatal because warn-only mode exits 0 internally |
| DOCS-01     | 08-05       | Top-level `README.md` explains the manifest model, machine setup flow, and where to add things                                                                                                                          | SATISFIED (w/ CR-01)    | README.md fully replaced; all four H2 sections present; **fresh-machine procedure inherits CR-01 prose defect** via the CUTOVER.md cross-reference |
| DOCS-05     | 08-05       | `docs/MIGRATION.md` records v1-to-v2 mapping and cutover plan                                                                                                                                                            | SATISFIED               | All 7 concept H2s + Rollback + Archiving v1 present; 38 table rows                                                             |
| DOCS-06     | 08-04       | `docs/MACHINES.md` documents each machine's purpose, identity, and special config                                                                                                                                       | SATISFIED               | Four H2 sections; per-machine deference line to TOML                                                                           |
| DOCS-08     | 08-04       | `docs/CUTOVER.md` includes a per-machine fresh-install verification procedure                                                                                                                                            | SATISFIED (w/ CR-01)    | 8 numbered steps present; **step 2 prose is factually wrong per CR-01** but the structural requirement (procedure exists) is met |

Total declared requirements for Phase 8: 12 — all 12 are mapped to plan frontmatter and all 12 are present in REQUIREMENTS.md against this phase. Zero orphaned requirements; zero unmapped requirements.

### Anti-Patterns Found

| File                      | Line     | Pattern                                                                                                                                                                                                                                       | Severity   | Impact                                                                                                                                                                                                                                                                                                              |
| ------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `taskfiles/claude.yml`    | 240-245  | `cross` printed then `exit 0` on missing CLI                                                                                                                                                                                                  | BLOCKER    | CR-03: silent-pass on known-broken state; aggregator renders green; CUTV-01 contract violated. Same pattern at lines 248-250 for jq.                                                                                                                                                                                |
| `taskfiles/claude.yml`    | 125-127, 150, 277 | jq `select` field disagreement across status/install/validate paths                                                                                                                                                                            | BLOCKER    | CR-02: structural idempotency regression; the v1 `macos:shell:145` re-run-forever bug class. Either status always fails (always re-run) OR install always reinstalls (line 150 thinks plugin missing).                                                                                                                |
| `taskfiles/links.yml`     | 241-247  | `configs:` status block enumerates only 6 of 7 sibling links; ghostty entry missing                                                                                                                                                            | BLOCKER    | CR-04: partial-state regression that the file's own header comment at lines 25-30 explicitly warns against; on a ghostty=true machine with healthy always-on links and broken ghostty link, `task: configs:ghostty` is never invoked because status short-circuits the cmds block.                                  |
| `docs/CUTOVER.md`         | 33-38    | Step 2 prose claims bootstrap "exits cleanly" when machine file is absent                                                                                                                                                                      | BLOCKER    | CR-01: contradicts install/cutover-gate.zsh:35-38 (returns 1) and bootstrap.zsh:112 (`\|\| exit 1`). README.md:24-36 inherits the defect. A user following the documented 5-step procedure on a clean Mac literally cannot proceed past step 2.                                                                       |
| `taskfiles/claude.yml`    | 88, 116, 188 | Bare `deps: [manifest:resolve]` while line 227 uses `:manifest:resolve`                                                                                                                                                                       | WARNING    | WR-01: mixed-form deps in the same included taskfile; bare form works today by namespace-fall-through but is a portability hazard if go-task tightens namespace resolution. Documented carry-forward debt in 08-02-SUMMARY decisions; not introduced by this phase but visible to phase verifiers.                  |
| `docs/CUTOVER.md`         | 70-72    | "e.g., claude" wording implies all components emit the D-06 sentinel; only claude:validate does                                                                                                                                                 | WARNING    | WR-02: doc framing leads operators to expect symmetric "feature off -> n/a" behavior across all rows; reality is that only claude:validate emits the sentinel. Not a blocker — the other validates correctly return rc=0 when feature-off via internal no-op.                                                       |
| `taskfiles/links.yml`     | 487-534  | `case "$mode" in` block has no `*) ... ;;` catch-all                                                                                                                                                                                          | WARNING    | WR-03: defensive-coding hygiene. Today all paths to `$mode` set one of three values, so unreachable; future flag-parsing bug or new mode would fall through silently. Low-priority polish.                                                                                                                          |
| `Taskfile.yml`            | 150-199  | validate aggregator double-runs each per-component validate (once via `task:` dispatch, once via re-invocation inside summary for-loop)                                                                                                       | WARNING    | WR-04: documented as accepted in the comment block (lines 164-169); milliseconds per component; relies on per-component validate idempotency that has no enforcing test. Not a blocker for v1.                                                                                                                       |

### Human Verification Required

See `human_verification` block in frontmatter. Six items total — five are the deferred operator-driven CUTV-04/05/06 cutover-runbook tasks (Plan 08-06 was filed with `autonomous: false` and tasks 1-5 are operationally pending per user direction at the in-session checkpoint), and one is the post-CR-fix end-to-end validation on a fresh machine.

### Gaps Summary

**Engineering deliverables present and working.** The aggregator, three-mode reconcile, cutover:ack writer, install-pipeline orphan-warn hook, and four cutover-readiness docs all exist, are wired, and produce real data when exercised live. Plans 08-01 through 08-05 ship clean.

**Four CR findings remain.** Per the user's pre-verification note the workflow does not block on the advisory review, but goal-backward verification cannot certify the goal as fully achieved while the codebase contains:

1. **CR-01 (BLOCKER)** — The documented fresh-machine procedure cannot complete as written. CUTOVER.md step 2 and README.md fresh-machine block both assume bootstrap.zsh exits cleanly on a fresh machine; bootstrap.zsh actually exits 1 because cutover-gate.zsh returns 1 when the machine file is absent. **A clean Mac following the docs literally hits a guaranteed bootstrap failure.** This directly contradicts Success Criterion #4 ("fresh-install verification procedure documented in CUTOVER.md") because the procedure as documented is broken. Recommended fix: change cutover-gate.zsh to `return 0` when the machine file is absent (gate not yet applicable; the install: precondition still enforces ack when needed).

2. **CR-02 (BLOCKER)** — Marketplace status vs install/validate jq-selector disagreement. The two-condition idempotency contract documented at claude.yml:25-30 is structurally broken. This is the exact `macos:shell:145` re-run-forever class the phase explicitly closes elsewhere in its `## Decisions` block. Recommended fix: align all three selectors on the same field after verifying `claude plugin list --json` shape on a real machine.

3. **CR-03 (BLOCKER)** — `claude:validate` prints cross then exits 0 when CLI is missing; aggregator renders green. CUTV-01's check/cross contract requires the aggregator's exit code AND its summary row to reflect the actual component state. Recommended fix: use an `rc` accumulator pattern (the same fix the reviewer drafted at REVIEW.md:222-241).

4. **CR-04 (BLOCKER)** — `configs:` status block omits the ghostty entry. On a partial-state machine (ghostty broken, always-on links healthy) the cmds block — and therefore `task: configs:ghostty` — is never invoked. The file's own header comment warns against this exact class. Recommended fix: add an inline-ternary status entry for ghostty mirroring the claude: status pattern at links.yml:204-216.

**CUTV-04, CUTV-05, CUTV-06 are operationally pending, not engineering gaps.** Plan 08-06 was filed with `autonomous: false` by design; the operator runbook requires real-machine installs across four target machines + a 7-day soak per machine + a multi-machine v1 archive operation. The verifier cannot drive this in-session. Routed to `human_verification` per the workflow's `end-of-phase` deferred-items pattern.

---

_Verified: 2026-05-16T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
