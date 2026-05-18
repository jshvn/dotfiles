# Phase 11: v1 Removal - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 11-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** 11-v1-removal
**Areas discussed:** MIGRATION.md fate, Plan breakdown, RMV-07 verification, Stray v1/cutover refs

---

## MIGRATION.md fate

| Option | Description | Selected |
|--------|-------------|----------|
| Delete outright | v1 is gone; soak/rollback is retired; PROJECT.md + AUDIT.md retain the historical record. No live operator needs this doc. Cleanest, smallest v2 surface. | ✓ |
| Trim cutover sections only | Delete Rollback + Archiving v1 + cutover-fallback prose from "What This Is"; keep the 8 v1→v2 mapping sections. ~80-100 lines removed; remainder serves as v1→v2 reference for AI agents and future contributors. | |
| Rewrite as single-page summary | Replace contents with a concise "what changed from v1" reference (~30-50 lines): profile→manifest, antigen→antidote, zsh/→shell/, Brewfile-by-profile→bundles, the macos:shell:145 fix. Drops cutover + rollback entirely. | |

**User's choice:** Delete outright
**Notes:** Closes Phase 9's AUDIT-05 deferred decision. Bounds Phase 14 TRIM-03 (no MIGRATION.md to trim).

### Follow-up: v1→v2 record after MIGRATION.md is gone

| Option | Description | Selected |
|--------|-------------|----------|
| Nothing more | AUDIT.md is the canonical v1→v2 record (every dropped/ported task documented with rationale and v2 owner). PROJECT.md retains milestone narrative. Repo history holds the rest. No new doc. | ✓ |
| Brief note in README.md | Add 2-3 lines under README.md's Documentation section pointing future contributors to AUDIT.md as the v1→v2 reference. | |
| Brief note in PROJECT.md | Append a one-paragraph "v1 is gone; AUDIT.md is the record" line to PROJECT.md's Current Milestone section so the planning index points to AUDIT.md. | |

**User's choice:** Nothing more
**Notes:** AUDIT.md is the canonical record; no new doc.

---

## Plan breakdown

| Option | Description | Selected |
|--------|-------------|----------|
| Single plan | All RMV-01..07 in one plan, multiple commits inside. Mirrors Phase 10's shape. Tight dependency ordering is easier to reason about in one plan. ~10-15 commits. | ✓ |
| Split into 2 plans | Plan A: file deletes (RMV-01/02/03). Plan B: cutover retirement + simplification + verification (RMV-04/05/06/07). Reviewable in halves; the dependency ordering risk lives only in Plan B. | |
| Split per RMV requirement | Seven small plans, one per RMV-01..07. Smallest reviewable units. Adds plan-tracking overhead and more cross-plan ordering coordination. | |

**User's choice:** Single plan
**Notes:** Same shape as Phase 10. Dependency ordering across commits is easier inside one plan.

### Follow-up: Sequencing within the single plan

| Option | Description | Selected |
|--------|-------------|----------|
| Callers-first | Order: (1) Taskfile.yml simplify + bootstrap.zsh edit, (2) cutover-gate.zsh delete, (3) v1 taskfiles + zsh/ + Brewfiles delete, (4) docs delete, (5) README.md edit, (6) stray-refs scrub, (7) verification. Every commit leaves a green tree. | ✓ |
| Group by RMV requirement | Order commits to match RMV-01 → RMV-02 → RMV-04 → RMV-05 → RMV-06. Risk: delete-gate-file before simplify-callers leaves one broken commit. | |
| Planner discretion | Lock the green-tree-per-commit constraint and trust the planner to pick the order. | |

**User's choice:** Callers-first
**Notes:** Every commit must leave the tree green. `task lint:taskfile` passes throughout.

---

## RMV-07 verification

| Option | Description | Selected |
|--------|-------------|----------|
| Re-run Phase 10 smoke + grep | Adapt `10-SMOKE.md` to an `11-SMOKE.md` that runs the same startup-chain assertions on personal-laptop after deletion, plus the `git grep` proof. No real rebuild; matches Phase 10's bar. | |
| Real fresh-machine install | Actually rebuild a machine (or document a clean-VM walk) to prove the cutover-step-free pipeline. Strongest evidence; meaningful overhead. | |
| Steady-state on personal-laptop only | Just confirm `task install` is a clean no-op on personal-laptop after the simplification + the grep gate passes. Smallest verification surface. Skips startup-chain re-validation since Phase 10 already proved it. | ✓ |

**User's choice:** Steady-state on personal-laptop only
**Notes:** Phase 10 already proved startup-chain (PORT-01/02/03). Phase 11 verification only needs to prove the simplification did not regress steady-state.

### Follow-up: Verification artifact location

| Option | Description | Selected |
|--------|-------------|----------|
| 11-VERIFICATION.md | Single doc with two sections: `task install` no-op confirmation, and `git grep` output. Replaces the smoke-procedure pattern; matches the lower verification bar. | ✓ |
| Append to AUDIT.md | Add a Phase 11 closeout section to AUDIT.md documenting which keep/drop rows were physically realized. | |
| Inline in plan SUMMARY | Capture verification evidence in `11-01-SUMMARY.md` rather than a separate doc. | |

**User's choice:** 11-VERIFICATION.md

---

## Stray v1/cutover refs

### Pattern-citation comments in os/defaults and os/shell-registration

| Option | Description | Selected |
|--------|-------------|----------|
| Rewrite to a living exemplar | Change the 5-6 pattern-citation comments from `install/cutover-gate.zsh` to a still-living example (e.g., `install/compose-brewfile.zsh`). Preserves the pedagogical intent; satisfies SC#5. | ✓ |
| Delete the citations | Strip the "see also: install/cutover-gate.zsh" sentences from the file headers entirely. Minimal edit; loses the pattern-shape pointer. | |
| Keep with rewrite note | Update the citations to read "(pattern previously exemplified by the now-deleted install/cutover-gate.zsh)". Preserves history; arguably operational v1 reference — may fail SC#5 strict reading. | |

**User's choice:** Rewrite to a living exemplar
**Notes:** `install/compose-brewfile.zsh` is the recommended replacement exemplar — it matches the LINT-05 "dedicated .zsh helper sourced by a taskfile cmd block" pattern the original citation was teaching.

### SSH key notes ("generated at cutover time")

| Option | Description | Selected |
|--------|-------------|----------|
| Rewrite "at cutover" to "at first install" | Replace "generated at cutover time" with "generated locally at first install" (or "on first machine provisioning"). Preserves operator guidance; removes cutover residue. | ✓ |
| Keep as-is | "Cutover" reads naturally as "the moment a machine first comes online" even after the v1 cutover model is retired. May fail the SC#5 grep gate. | |
| Delete the notes entirely | Strip the "generated at cutover time" comments from all four files. Runbook lives elsewhere. | |

**User's choice:** Rewrite "at cutover" to "at first install"
**Notes:** Exact phrasing is Claude's discretion — any wording that drops "cutover" and preserves the runbook intent is acceptable.

### Operator-facing doc rewrites (docs/SECURITY.md, taskfiles/lint.yml, taskfiles/README.md)

| Option | Description | Selected |
|--------|-------------|----------|
| Rewrite each to current reality | Touch each file: SECURITY.md (remove cutover-ack mention), lint.yml (drop the cutover comment), taskfiles/README.md (drop the "v1 leftover taskfiles" section). | ✓ |
| Minimal touch — just remove cutover phrasing | Strip the cutover sentences only; leave surrounding prose intact. Smaller diff; some surrounding sentences may read oddly. | |
| Defer broader doc cleanup to Phase 14 | Just do the SC#5 grep-gate minimum here; leave full coherence pass for Phase 14. | |

**User's choice:** Rewrite each to current reality
**Notes:** Same green-tree-per-commit discipline; lands as a single "doc drift" commit late in the sequence.

---

## Claude's Discretion

- Exact commit count and intra-step grouping (e.g., whether the 8 v1 taskfile deletes are one commit or eight).
- Whether `bootstrap.zsh` step-numbering comment is renumbered after the cutover gate block is removed.
- Exact wording of the SSH-key rewrite (D-07).
- Exact wording of the LINT-05 pattern-citation rewrite (D-06); `install/compose-brewfile.zsh` recommended but planner may pick `install/resolver.zsh` if a different LINT-05 shape applies better.
- Whether the `11-VERIFICATION.md` steady-state capture is full terminal output or summarized one-line-per-subtask render.

## Deferred Ideas

- README.md broader Quick Reference rewrite — deferred to Phase 14 TRIM-04 (deduping README.md against CLAUDE.md).
- AUDIT.md Phase 11 closeout annotation — rejected; AUDIT.md stands as-is as the historical record.
- Backing up the `zsh/` tree to a separate git branch before deletion — not needed; git history preserves it.
- VM-based fresh-install verification — rejected for Phase 11; revisit in v2.2 if a real Mac rebuild surfaces a regression.
- `install/README.md` Brewfile-bullet trimming and "wait for Phase 5" sub-fragment removal — deferred to Phase 14 TRIM-03 per AUDIT.md rows.
- Renaming the LINT-05 pattern-citation exemplar — out of scope; use the file that exists today.
