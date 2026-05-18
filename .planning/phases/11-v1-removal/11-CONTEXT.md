# Phase 11: v1 Removal - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Delete every v1 leftover from the repo after Phase 10 proved no live dependency remains, then simplify the v2 surface and retire cutover infrastructure entirely. Concrete deletes (locked by RMV-01..04 and AUDIT.md):

- 8 v1 taskfiles: `taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/brew.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/claude-stub.yml`, `taskfiles/brew-stub.yml`, `taskfiles/links-stub.yml`, `taskfiles/macos.v1.yml.bak`
- The entire `zsh/` tree (38 files: 6 startup files + 24 functions + aliases under `common/` and `personal/` + `configs/` + `styles/` + `theme.zsh`)
- 4 v1 Brewfiles: `install/Brewfile.rb`, `install/Brewfile-personal.rb`, `install/Brewfile-server.rb`, `install/Brewfile-work.rb`
- Cutover infrastructure: `install/cutover-gate.zsh`, `task cutover:ack` (Taskfile.yml lines ~237-311), the `cutover_gate_check` precondition on `install:` (Taskfile.yml lines ~320-328), `bootstrap.zsh` cutover gate sourcing (lines ~105-112), `docs/CUTOVER.md`, `docs/MIGRATION.md` (full delete per D-01)
- The "v1 leftover taskfiles" comment block at Taskfile.yml lines ~22-26

Then simplify: every operational v1 reference is scrubbed (SC#5 grep gate); operator-facing docs are rewritten to match post-cutover reality; `task install` on the active machine succeeds without any cutover-ack step. The per-machine 7-day-soak model is retired.

Zero net-new features. Phase 12 (Task Surface Redesign) is the next phase and depends on Phase 11 leaving a clean v2-only surface.

</domain>

<decisions>
## Implementation Decisions

### MIGRATION.md disposition (AUDIT-05 deferred decision)

- **D-01 (MIGRATION.md delete outright):** `docs/MIGRATION.md` is deleted as part of this phase, not trimmed or rewritten. v1 is gone; the soak / rollback model is retired; PROJECT.md retains the milestone narrative. No operator needs MIGRATION.md after v1 is removed. This closes Phase 9's AUDIT-05 deferred decision and bounds Phase 14 TRIM-03 (which now has no MIGRATION.md to trim).
- **D-02 (AUDIT.md is the v1→v2 record):** No replacement doc is created. `.planning/phases/09-v1-drop-audit/AUDIT.md` is the canonical v1→v2 mapping for future contributors and AI agents (every dropped/ported task documented with rationale and v2 owner). No README.md note pointing to AUDIT.md, no PROJECT.md addendum. Repo history holds the rest.

### Plan breakdown and sequencing

- **D-03 (single plan):** All of RMV-01..07 is implemented in a single plan, multiple commits. Mirrors Phase 10's shape (one plan for the whole phase). Tight dependency ordering between deletes is easier to reason about in one plan than coordinated across plans. Expected commit count: ~10-15.
- **D-04 (callers-first, green-tree-per-commit):** Every commit in the sequence MUST leave the tree green (`task lint:taskfile` passes, `task install` is still invokable). Suggested order, planner can re-order intra-step as long as the green-tree invariant holds:
  1. Taskfile.yml simplify: drop the `cutover:ack` task body (lines ~237-311), drop the `cutover_gate_check` precondition from `install:` (lines ~320-328), remove the "v1 leftover taskfiles" comment block (lines ~22-26); commit at green tree.
  2. `bootstrap.zsh` edit: drop the "Step 4: cutover-ack gate" block (lines ~105-112). Adjust the step-numbering comment for "Step 5: next-step hint" if needed.
  3. `install/cutover-gate.zsh` delete (no callers remain after steps 1-2).
  4. 8 v1 taskfiles delete (none are included in root Taskfile.yml — independent).
  5. `zsh/` tree delete (no v2 code sources from `zsh/` after Phase 10's smoke).
  6. 4 v1 Brewfiles delete (composed-Brewfile pipeline never reads from `install/Brewfile*`).
  7. `docs/CUTOVER.md` delete + `docs/MIGRATION.md` delete.
  8. README.md fresh-install rewrite (drop `task cutover:ack` line + adjust the prose around it).
  9. Stray-refs rewrite pass (D-06, D-07, D-08).
  10. Verification (D-05): `11-VERIFICATION.md` capture.

  Steps 4-6 are independent of each other; planner can reorder or batch. Steps 1-2 MUST precede step 3 (callers before the gate file). Step 9 MUST precede step 10 (the grep gate is part of the verification).

### RMV-07 verification

- **D-05 (steady-state + grep gate; no fresh-machine install):** Verification bar is the smaller of the two Phase 10 considered. Captured in `.planning/phases/11-v1-removal/11-VERIFICATION.md` with two sections:
  1. **Steady-state `task install` no-op on personal-laptop:** terminal output capture showing the simplified `install:` task graph runs through `links:all → packages:install → claude:install → macos:defaults → macos:shell → packages:verify → links:reconcile --warn-only`, every sub-task hits its status block (no work), exit 0, no `cutover:ack` step ever invoked. Total elapsed time recorded for the operator.
  2. **SC#5 grep gate:** `git grep -E '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover'` excluding `.planning/` and `.claude/` returns ONLY references the operator has deliberately kept (zero is the goal; any retained refs are explicitly listed with rationale in 11-VERIFICATION.md). Run BEFORE the verification commit so the report itself does not show in the grep output.

  No real fresh-machine install. Phase 10 already proved the startup-chain works (PORT-01/02/03 via 10-SMOKE.md); Phase 11's verification only needs to prove the simplification did not regress the steady-state pipeline.

### Stray v1/cutover references (SC#5 scrub)

- **D-06 (pattern-citation comments → living exemplar):** 5 files cite `install/cutover-gate.zsh` as the LINT-05 pattern exemplar in header comments: `os/defaults/dock.zsh`, `os/defaults/finder.zsh`, `os/defaults/input.zsh`, `os/defaults/screenshots.zsh`, `os/defaults/security.zsh`, plus `os/shell-registration.zsh` (6 files total per the live grep). Rewrite each to cite a still-living example — `install/compose-brewfile.zsh` is the preferred replacement because it is the canonical "dedicated .zsh helper sourced by a taskfile cmd block" pattern in v2 (matches the LINT-05 shape the original citation was teaching). Preserves pedagogical intent; satisfies SC#5.
- **D-07 (SSH key notes — "at cutover time" → "at first install"):** 4 `identity/ssh/*` files reference key generation "at cutover time": `identity/ssh/identities/server-1`, `identity/ssh/identities/server-2`, `identity/ssh/keys/server-1.pub`, `identity/ssh/keys/server-2.pub`. Rewrite to "generated locally at first install" (or equivalent wording — planner picks the exact phrasing; intent is to preserve the operator-runbook hint that the server key is created on the server, not committed to the repo). Removes the cutover-rhetoric residue without losing the runbook detail.
- **D-08 (operator-facing doc drift — rewrite, not minimal):** Three doc files have cutover phrasing that drifts after retirement:
  - `docs/SECURITY.md:16` — mentions the cutover-ack gate as a security boundary. Rewrite the surrounding sentence to drop the cutover-ack mention; the security boundary is now bootstrap.zsh's HTTPS-only trust chain + the manifest model itself.
  - `taskfiles/lint.yml:24` — comment cites the cutover-ack gate. Drop the citation.
  - `taskfiles/README.md:29` — describes v1 leftover taskfiles as alive for the cutover window. Drop the section entirely (after Phase 11 there are no v1 leftover taskfiles).
  Same green-tree-per-commit discipline as the rest of the plan; these can land as a single "doc drift" commit late in the sequence (suggested step 9).

### README.md fresh-install rewrite

- **D-09 (drop the cutover line + adjust prose; minimal-edit):** `README.md:26-37` currently has `task cutover:ack -- <machine-name>` between `task setup` and `task install` in the fresh-install steps. Drop that line; rewrite the surrounding prose (which says `task cutover:ack` is required and that `bootstrap.zsh` won't fail without it) to match the new reality (`task install` runs after `task setup` with no acknowledgment step). Also remove the `docs/CUTOVER.md` bullet from the Documentation section (line 64). No broader Quick Reference rewrite — Phase 14 TRIM-04 dedupes README.md against CLAUDE.md.

### Claude's Discretion

- Exact commit count and intra-step grouping (e.g., whether the 8 v1 taskfile deletes are one commit or eight). Recommendation: one commit per RMV requirement boundary where possible (RMV-01 = one commit, RMV-02 = one commit, etc.), but Brewfile + zsh/ + taskfile deletes can be split or batched at planner discretion.
- Whether `bootstrap.zsh` "Step 4" comment numbering is renumbered to "Step 4: next-step hint" or left at "Step 5" with a gap. Renumber for cleanliness recommended.
- Exact wording of the SSH-key rewrite per D-07 (e.g., "generated locally at first install" vs "generated on first machine provisioning" vs "generated on the server"). Any phrasing that drops "cutover" and preserves the operator-runbook intent is acceptable.
- Exact wording of the LINT-05 pattern-citation rewrite per D-06. `install/compose-brewfile.zsh` is the recommended exemplar; planner may pick `install/resolver.zsh` if a different LINT-05 shape applies better in a given file.
- Whether the `11-VERIFICATION.md` steady-state capture is the full terminal output or a summarized one-line-per-subtask render. Full capture is recommended for auditability; summarized is acceptable if the verification doc would otherwise be unwieldy.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase inputs (the gating artifacts)

- `.planning/phases/09-v1-drop-audit/AUDIT.md` — the keep/drop classification. Phase 11 deletes every file/asset/tree row marked `keep/drop = drop` whose v2 owner now carries the behavior (or whose behavior was intentionally retired). The "Install Assets" and "zsh/ Tree" sections enumerate the Brewfile + zsh/ deletes; the "Taskfiles" section enumerates the 8 v1 taskfile deletes; the "Docs" section frames the install/README.md cleanup (which is Phase 14 TRIM-03 scope, not Phase 11).
- `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` — D-09 "behavior-equivalent on the same machine" is the verification bar D-05 inherits.
- `.planning/phases/10-v1-drop-remediation/10-VERIFICATION.md` — Phase 10's gate. RMV-07's "no PORT item outstanding" precondition is satisfied by Phase 10's 9/9 must-haves pass. Phase 11 does not re-validate startup chain — Phase 10 already did.
- `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` — the smoke-procedure template. D-05's steady-state-on-personal-laptop section adopts the same operator-output capture shape.

### Project specs (locked decisions that bound the phase)

- `.planning/ROADMAP.md` §"Phase 11: v1 Removal" — goal, depends-on Phase 10, requirements RMV-01..07, six success criteria. SC#1 names the 8 taskfiles to delete; SC#2 names the zsh/ tree and Brewfiles; SC#3 names the cutover infra including `docs/MIGRATION.md`'s cutover sections; SC#4 names the Taskfile.yml comment block to remove; SC#5 is the grep gate; SC#6 is the verification.
- `.planning/REQUIREMENTS.md` §"Removal (v1 deletion)" — RMV-01 through RMV-07 exact text.
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" — "v1 removal" bullet at line 19 calls out exactly the deletes Phase 11 implements; the per-machine 7-day-soak retirement is explicit.

### v2 surface to be modified (the targets)

- `Taskfile.yml:22-26` — the "v1 leftover taskfiles" comment block (RMV-05 / SC#4).
- `Taskfile.yml:237-311` — the `cutover:ack` task body (RMV-04).
- `Taskfile.yml:319-328` — the `install:` task's `cutover_gate_check` precondition (RMV-04 / RMV-05).
- `bootstrap.zsh:105-112` — "Step 4: cutover-ack gate" block (RMV-04).
- `README.md:26-37` — fresh-install procedure with `task cutover:ack` (D-09 / RMV-06).
- `README.md:64` — Documentation bullet pointing at `docs/CUTOVER.md` (D-09).
- `docs/SECURITY.md:16` — cutover-ack-gate mention (D-08).
- `taskfiles/lint.yml:24` — cutover-ack-gate comment (D-08).
- `taskfiles/README.md:29` — "v1 leftover taskfiles ... alive for the cutover window" section (D-08).
- `os/defaults/dock.zsh:34`, `os/defaults/finder.zsh:40`, `os/defaults/input.zsh:39`, `os/defaults/screenshots.zsh:43`, `os/defaults/security.zsh:54`, `os/shell-registration.zsh:54` — LINT-05 pattern citations pointing at `install/cutover-gate.zsh` (D-06).
- `identity/ssh/identities/server-1:6`, `identity/ssh/identities/server-2:6`, `identity/ssh/keys/server-1.pub:1`, `identity/ssh/keys/server-2.pub:1` — "generated at cutover time" notes (D-07).

### v2 deletion targets (the files that go away)

- `taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/brew.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/claude-stub.yml`, `taskfiles/brew-stub.yml`, `taskfiles/links-stub.yml`, `taskfiles/macos.v1.yml.bak` — RMV-01.
- `zsh/` tree (entire directory) — RMV-02.
- `install/Brewfile.rb`, `install/Brewfile-personal.rb`, `install/Brewfile-server.rb`, `install/Brewfile-work.rb` — RMV-03.
- `install/cutover-gate.zsh` — RMV-04.
- `docs/CUTOVER.md` — RMV-04 / SC#3.
- `docs/MIGRATION.md` — D-01 (extends SC#3's "or is itself removed" branch).

### Convention docs (rules every implementation must follow)

- `CLAUDE.md` (project root) §"Rules" — LINT-02 (template vars `{{.X}}` in status blocks, never shell vars `$X`); LINT-04 (`set -euo pipefail` on every executable .zsh); LINT-03b (no bare `ln -s` outside helpers.yml); LINT-05 (prefer dedicated .zsh helpers over inline cmd blocks — the pattern D-06's rewrite preserves).
- `.claude/CLAUDE.md` §"Conventions" — no AI attribution in commits or source; no emojis in any file (markdown included); file-level comment block at top of every script; errors to stderr.

### Codebase maps (for context)

- `.planning/codebase/STRUCTURE.md` — current v1+v2 layout. Phase 11 deletes the entire v1 half.
- `.planning/codebase/CONCERNS.md` — known v1 bugs; every concern row whose root cause is a v1 file is fully resolved when Phase 11 deletes that file.
- `.planning/codebase/ARCHITECTURE.md` — five-layer model; cutover infrastructure spans the bootstrap and install-engine layers, which are simplified after retirement.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- Phase 10's PORT-01/02 work landed the new `links:zdotdir` step (in `taskfiles/links.yml`) and the new `shell:validate` task (in `taskfiles/shell.yml`) that own the behaviors v1's `common.yml` `zdotdir:` and `validate:` tasks used to own. Phase 11 deletes `common.yml` confident those behaviors live in their v2 owners.
- `task lint:taskfile` (LINT-01) is the green-tree gate per D-04 — it structurally checks every install task has a `status:` block. After Taskfile.yml simplification it must still pass; the `cutover:ack` task's removal does not affect lint (it had `status: [false]` declared explicitly).
- `install/messages.zsh` is the only `install/*.zsh` consumed by every taskfile cmd block; deleting `install/cutover-gate.zsh` (the only other operational install/*.zsh after Phase 10) does not affect any caller other than the two D-04 step-1 edits.
- `git grep -E '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover'` is the SC#5 cross-reference primitive — already proven in the discussion to find the exact 12-15 hits Phase 11 must address. The verification doc captures the post-cleanup output of the same command.

### Established Patterns

- Phase 10's commit shape: one logical unit per commit, each commit leaves a green tree, summary commits hold context. Phase 11 follows the same shape (D-03 / D-04).
- The "delete the source-of-truth file last" pattern: callers are simplified before the called file is deleted (D-04 ordering). Same pattern Phase 6 used when dropping `taskfiles/macos.v1.yml.bak` from active include but parking the file (Phase 11 now does the final delete).
- `docs/CUTOVER.md`'s deletion is locked by Phase 9's audit row (the cutover-gate paragraph was tagged "v2 owner = docs/CUTOVER.md" as a *transient* owner pending Phase 11 retirement). Phase 11 closes that loop.

### Integration Points

- Phase 12 (Task Surface Redesign) depends on Phase 11 leaving a clean v2-only surface. After Phase 11, `task --list` no longer surfaces `cutover:ack`; Phase 12's classification table can ignore it. The `taskfiles/README.md:29` "v1 leftover taskfiles ... alive for the cutover window" section's removal (D-08) is the integration point — Phase 12's task-surface audit reads from `taskfiles/README.md` as the README starting point.
- Phase 14 (Comment + Doc Trim) is bounded by D-01 (no MIGRATION.md to trim) and D-08 (no cutover phrasing to scrub from docs/SECURITY.md / taskfiles/lint.yml / taskfiles/README.md — Phase 11 already did it). Phase 14 TRIM-03 reduces to: `docs/` directory review with `MIGRATION.md` and `CUTOVER.md` already gone, plus whatever per-file header banner trimming TRIM-02 requires.
- `bootstrap.zsh` is the operator's first touchpoint; the "Step 4: cutover-ack gate" removal is operator-visible (the next-step hint appears immediately after yq check, no gate ever fires). This matches PROJECT.md's "single declarative manifest per machine" core value.

</code_context>

<specifics>
## Specific Ideas

- The `cutover:ack` task at `Taskfile.yml:237-311` carries ~75 lines of comment + code; removing it simplifies the file significantly. The summary line in the doc-string at lines 240-262 explains the chicken-and-egg avoidance — that historical context lives in Phase 8's planning artifacts (`.planning/phases/08-validation-cutover-readiness/`); no need to preserve it in Taskfile.yml comments after the task is deleted.
- The "Step 4: cutover-ack gate" block in `bootstrap.zsh:105-112` is exactly the lines to delete. The next-step hint at line 114+ is operator-facing and stays. Renumber the remaining step comment from "Step 5" to "Step 4" for cleanliness (Claude's discretion per D-decisions).
- The LINT-05 pattern citation in `os/defaults/security.zsh:54` (and the other 4 sibling files) reads "(matches install/compose-brewfile.zsh + install/cutover-gate.zsh pattern)". The minimal D-06 rewrite is to drop the `+ install/cutover-gate.zsh` clause, leaving `install/compose-brewfile.zsh` as the live exemplar. Done.
- The SC#5 grep gate as the verification primitive: the exact command from the success criterion is `git grep -E '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover'`. After D-08, the only remaining matches outside `.planning/` and `.claude/` should be the 4 D-07 rewrites (which still mention git history "v1" in the file-header comment) — Claude's discretion on whether to keep "v1" in those headers or rewrite further. D-08's "rewrite each to current reality" intent suggests scrubbing those too if the rewrite reads naturally without them.
- AUDIT.md is NOT modified by Phase 11. AUDIT.md is a historical record of the audit (Phase 9 deliverable); it does not need a Phase 11 closeout annotation (D-decisions confirmed: AUDIT.md is the canonical v1→v2 record as-is).

</specifics>

<deferred>
## Deferred Ideas

- README.md broader Quick Reference rewrite: deferred to Phase 14 TRIM-04 (deduping README.md against CLAUDE.md). Phase 11 only drops the `task cutover:ack` line and adjusts immediately-surrounding prose per D-09.
- AUDIT.md Phase 11 closeout annotation (e.g., a "physically realized" column or footer): rejected (D-02). The keep/drop rationale plus the implementation commit history is sufficient record.
- Backing up the `zsh/` tree to a separate git branch before deletion: not discussed; git history already preserves the deleted tree (any commit before this phase has it). Not needed.
- VM-based fresh-install verification: rejected for Phase 11 (D-05). If a real Mac rebuild post-Phase-11 surfaces a regression the steady-state + grep gate missed, that becomes the trigger to add VM-based pre-merge verification in v2.2.
- `install/README.md` Brewfile-bullets trimming and "wait for Phase 5" sub-fragment removal: deferred to Phase 14 TRIM-03 per AUDIT.md rows for install/README.md:29-34 and :51-54. Phase 11 leaves install/README.md untouched.
- Renaming the LINT-05 pattern-citation exemplar from `install/compose-brewfile.zsh` to something different (e.g., a hypothetical `install/helpers.zsh`): not in scope; if a future phase creates a more canonical exemplar, the citations can be updated then. Phase 11's rewrite uses the file that exists today.

</deferred>

---

*Phase: 11-v1-removal*
*Context gathered: 2026-05-17*
