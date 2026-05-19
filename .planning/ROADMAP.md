# Roadmap: Dotfiles v2 Refactor

## Milestones

- Shipped **v1.0 MVP** — Phases 1-8 (2026-05-16)
- Shipped **v2.1 Cleanup** — Phases 9-14 (2026-05-19)
- Planning **v2.2** — see `/gsd-new-milestone`

## Phases

<details>
<summary>Shipped v1.0 MVP (Phases 1-8) — 2026-05-16</summary>

- [x] Phase 1: Manifest Engine + Repository Skeleton (4/4 plans)
- [x] Phase 2: Install Engine — Bootstrap, Idempotency, Lint (6/6 plans)
- [x] Phase 3: Shell Layer — Flat Content Port (5/5 plans)
- [x] Phase 4: Identity Layer — Git + SSH per Machine (7/7 plans)
- [x] Phase 5: Packages Layer — Brewfile Composition + Verification (8/8 plans)
- [x] Phase 6: OS Defaults — macOS Configuration (4/4 plans)
- [x] Phase 7: Claude + Tool Configs + Smoke Tests (6/6 plans) — completed 2026-05-16
- [x] Phase 8: Validation + Cutover Readiness (6/6 plans) — completed 2026-05-16

</details>

<details>
<summary>Shipped v2.1 Cleanup (Phases 9-14) — 2026-05-19</summary>

- [x] Phase 9: v1-Drop Audit (5/5 plans) — completed 2026-05-17
- [x] Phase 10: v1-Drop Remediation (1/1 plan) — completed 2026-05-18
- [x] Phase 11: v1 Removal (1/1 plan) — completed 2026-05-18
- [x] Phase 12: Task Surface Redesign (8/8 plans) — completed 2026-05-18
- [x] Phase 13: Code Review + Dead-Code Cleanup (6/6 plans) — completed 2026-05-19
- [x] Phase 14: Comment + Doc Trim (3/3 plans) — completed 2026-05-19

Full details: `.planning/milestones/v2.1-ROADMAP.md`. Audit: `.planning/milestones/v2.1-MILESTONE-AUDIT.md`.

</details>

### v2.2 (planning)

To be defined via `/gsd-new-milestone`. Open items carried into v2.2:

- Three diagnosed-but-not-fixed bugs from v2.1 (closed at milestone boundary without separate fix): `manifest-namespace-double-prefix`, `resolver-warn-fallback-broken`, `validate-git-empty-useremail-after-install`. See `.planning/debug/` and the deferred section of `v2.1-MILESTONE-AUDIT.md`. Revisit if they still surface in v2.2 use.

## Progress

| Milestone | Phases | Plans | Status   | Shipped    |
|-----------|--------|-------|----------|------------|
| v1.0 MVP  | 1-8    | 46/46 | Complete | 2026-05-16 |
| v2.1 Cleanup | 9-14 | 24/24 | Complete | 2026-05-19 |
