# Phase 14: Comment + Doc Trim - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** 14-comment-doc-trim
**Areas discussed:** Header banner template (TRIM-02), WHY-only inline-comment heuristic (TRIM-01), README / CLAUDE.md / .claude/CLAUDE.md canonical home (TRIM-04), Anti-pattern teaching preservation (TRIM-05)

---

## Area Selection (initial multiSelect)

User was offered 4 candidate areas and selected all 4. Plan breakdown shape and D-08 Class A scope were left as Claude's discretion (not surfaced as gray-area options).

---

## Area 1 — Header banner template (TRIM-02)

### Q1 — Which 3 elements?

| Option | Description | Selected |
|--------|-------------|----------|
| Purpose / Dependencies / Side effects (ROADMAP) | Matches ROADMAP SC#2 verbatim. "Dependencies" = other files/tools/tasks this one requires. | ✓ |
| Purpose / Callers / Side effects (CLAUDE.md) | Matches project-root CLAUDE.md "Conventions Not Captured Above". Caller-focused. | |
| Purpose / Depends on / Called by / Side effects (4 elements) | Both pieces of info matter; combine. 4 not 3; would require amending ROADMAP. | |
| Purpose / Side effects only (2 elements) | Minimal. Deps and callers derivable from code (`includes:`, `task --summary`). | |

**User's choice:** Purpose / Dependencies / Side effects (ROADMAP).
**Notes:** Locked. Resolves a real contradiction between ROADMAP SC#2 and project-root CLAUDE.md "Conventions" line; Plan 14-01 amends CLAUDE.md "callers" → "key dependencies".

### Q2 — Section separator style

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `# === banner ===` (77 chars), header only — no mid-file separators | One header banner per file; no inner section bars. Mid-file structure via go-task keywords. | ✓ |
| Keep `# === banner ===` for header AND mid-file dividers | Header + `# === <section> ===` between logical groups. | |
| Switch to lightweight `# ---` thin rule, header only | Less visual weight. | |
| No separators at all — banner is just `#` comment lines | Most minimal; banner less visually distinct. | |

**User's choice:** Header `# === ===` only; no mid-file separators.
**Notes:** Trade-off accepted: long taskfiles lose visual scan-bars; reader compensates with editor outline view.

### Q3 — Max banner line count

| Option | Description | Selected |
|--------|-------------|----------|
| Hard cap: 10 lines | Tight. Forces each label to one line. | |
| Hard cap: 15 lines | Purpose 2-3 lines, deps 3-4 entries. | |
| Soft cap: aim ~10, allow up to ~20 with rationale | Default tight; outliers justify longer in commit message. | |
| No fixed cap — "as long as it needs to be" but no narrative prose | Qualitative: labels-only, no examples, no anti-pattern explanations. | ✓ |

**User's choice:** No fixed cap; qualitative rule (labels-only, no narrative, no examples, no anti-pattern explainers).
**Notes:** Length falls out of content discipline. Not grep-able for violations; planner uses judgement per file.

---

## Area 2 — WHY-only inline-comment heuristic (TRIM-01)

### Q1 — Keep/cut rule shape

| Option | Description | Selected |
|--------|-------------|----------|
| Three-test rule: KEEP if (a) non-obvious WHY OR (b) live footgun OR (c) cites lint rule | Mechanical and auditable. | ✓ |
| Two-test rule: KEEP only if prevents future break | Stricter; depends on lint suite catching what comments would have warned about. | |
| Density target: cut until each file's commented-to-code ratio is <25% | Numerical instead of qualitative. | |
| Three-test + per-file "no more than 1 anti-pattern explainer block" | Three-test + explicit cap on long teaching blocks. | |

**User's choice:** Three-test rule (a) non-obvious WHY, (b) live footgun, (c) cites lint rule.

### Q2 — `desc:` strings

| Option | Description | Selected |
|--------|-------------|----------|
| One-line `desc:` only; cut multi-line | `desc:` shows in `task --list`; one line keeps operator surface scannable. | |
| Keep multi-line `desc:` when useful for `task --summary`; cut restatement | Apply same three-test rule. | ✓ |
| Drop all `desc:` from internal; one-line on public only | Internal tasks don't appear in operator-facing `--list`. | |
| Out of scope for TRIM-01 — defer | Leaves Phase 12 deferred item un-resolved. | |

**User's choice:** Keep multi-line `desc:` when useful for `task --summary`; cut restatement (three-test rule applies).
**Notes:** Resolves Phase 12 D-Discretion `desc:` deferral.

---

## Area 3 — README / CLAUDE.md / .claude/CLAUDE.md canonical home (TRIM-04)

### Q1 — Canonical home rule

| Option | Description | Selected |
|--------|-------------|----------|
| README humans/onboarding; CLAUDE.md AI rules; .claude/CLAUDE.md pointer | Audience split with .claude/ as a short cross-reference. | |
| README full surface (humans+AI start); CLAUDE.md AI-only extras; .claude/CLAUDE.md deleted | README is single entry. | |
| README humans only; CLAUDE.md canonical for everything; .claude/CLAUDE.md thin pointer | Audience-split; .claude/ becomes ~5 lines. | |
| Audience+topic split: README install/use, CLAUDE.md architecture+rules, .claude/CLAUDE.md Claude-Code-tooling tips | Three audiences, three topics. | |

**User's choice:** README humans only; CLAUDE.md canonical for everything; `.claude/CLAUDE.md` = thin pointer.

### Q2 — Pointer depth for .claude/CLAUDE.md

| Option | Description | Selected |
|--------|-------------|----------|
| 5-10 lines: pointer + 5-command surface + "see CLAUDE.md" | Minimum viable. | |
| 20-30 lines: pointer + surface + "don't do" list + link | Covers most-likely first-strike questions. | |
| Delete `.claude/CLAUDE.md` entirely — Claude Code auto-loads root CLAUDE.md | Verify in research; eliminates duplication. | ✓ |
| Keep both as canonical — use `@CLAUDE.md` include in `.claude/CLAUDE.md` | Depends on include support. | |

**User's choice:** Delete `.claude/CLAUDE.md` entirely.
**Notes:** Planner's research step verifies Claude Code's project-CLAUDE.md auto-discovery picks up root CLAUDE.md (well-known convention; session evidence already shows both files loaded). Fallback if research surfaces issues: "5-10 line thin pointer" shape from option 1.

---

## Area 4 — Anti-pattern teaching preservation (TRIM-05)

### Q1 — Where does the teaching live?

| Option | Description | Selected |
|--------|-------------|----------|
| Rely on CLAUDE.md Rules + git history; delete in-code references | All real rules already in CLAUDE.md; in-code annotations were Phase-history breadcrumbs. | ✓ |
| Migrate orphan teaching into per-namespace READMEs | Each subsystem absorbs its own lessons; more files to keep in sync. | |
| Create one new `docs/CONVENTIONS.md` | Single dedicated doc; risk of junk-drawer. | |
| Keep 1-line citation in code + strip long explainer | Hybrid; aligns with TRIM-01 three-test rule (c). | |

**User's choice:** Rely on CLAUDE.md Rules + git history; delete in-code references.
**Notes:** 1-line lint-rule citations in code remain allowed under TRIM-01 three-test rule (c) — they survive even though the multi-line explainer is stripped. The two decisions are consistent.

### Q2 — Verify CLAUDE.md coverage before stripping?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — build `14-TEACHING-INVENTORY.md` as prereq; gap-fill CLAUDE.md before strip | Lowest risk; extra plan step. | ✓ |
| No — trust CLAUDE.md is comprehensive; delete without inventory | Faster; risk of missed lesson. | |
| Spot-check long teaching blocks only; accept short annotations as noise | Middle ground. | |
| Skip verification — git blame is enough | Most aggressive. | |

**User's choice:** Build `14-TEACHING-INVENTORY.md` as Plan 14-01 prereq; gap-fill CLAUDE.md before strip.
**Notes:** Two-step process is locked: (1) inventory + gap-fill → (2) strip. Inventory columns: `file:line | snippet | lesson encoded | covered by CLAUDE.md §X | NEEDS-ADD?`. The SC#5 grep gate is the final assertion at the close of Plan 14-03.

---

## Claude's Discretion

The following were intentionally NOT surfaced as gray areas (planner picks per recommendations in CONTEXT.md `<decisions>` → "Claude's Discretion"):

- **Plan breakdown shape** — recommendation: 3 grouped plans (14-01 inventory + gap-fill; 14-02 trim pass; 14-03 dedup + final gate). Per-requirement (5 plans) acceptable.
- **D-08 Class A scope** — recommendation: include in TRIM-02 banner pass (consistency); skip TRIM-01 (most files have minimal comments anyway).
- **`14-METRICS.md` table shape** — recommendation: per-file rows with `file | code_lines | comments_pre | comments_post | delta | %_reduction` + aggregate row.
- **Trim ordering** (TRIM-01 first vs TRIM-02 first vs interleaved) — recommendation: per-file (banner + inline comments together, lint after each file).
- **Whether to update LINT-08 fixtures to match new banner shape** — recommendation: yes, sub-commit within Plan 14-02.
- **`.claude/CLAUDE.md` deletion fallback** — recommendation: only fall back to the "5-10 line thin pointer" shape if D-07 research surfaces unexpected Claude Code behavior.

---

## Deferred Ideas

- Function-content audit for `shell/functions/*` + `shell/aliases/*` — REQUIREMENTS.md "Future Requirements"; past v2.1.
- Linux support — REQUIREMENTS.md "Future Requirements".
- Starship prompt swap — REQUIREMENTS.md "Future Requirements".
- Net-new lint rule for banner content vocabulary — defer per Phase 13 D-11(b) (needs-new-infra).
- Helper extraction for the 4-site "read first line + trim edges" idiom (Phase 13 REVIEW row 48) — Plan 14-02 optional spare-cycle work; otherwise defers.
- DOTFILEDIR-leak architectural fix (Phase 13 REVIEW row 28) — needs-new-infra-grade; defers.
- Automated drift gate for "README.md vs CLAUDE.md must not duplicate" — defer per Phase 13 D-11(b).
- Per-tool config docs (`configs/<tool>/README.md`) — if TRIM-03 surfaces a gap, defer to a per-tool documentation pass.
- Full Claude-Code-loads-root-CLAUDE.md verification beyond a planner doc-spike — if D-07 spike surfaces ambiguity.
