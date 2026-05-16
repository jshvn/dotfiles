---
phase: 06-os-defaults-macos-configuration
plan: 01
subsystem: infra
tags: [manifest, toml, feature-flags, macos-defaults, schema, resolver]

# Dependency graph
requires:
  - phase: 01-manifest-engine-repository-skeleton
    provides: manifest model (defaults.toml + per-machine TOML deep-merge, resolved.json contract, kebab-case feature keys)
  - phase: 03-shell-layer-flat-content-port
    provides: macos-finder feature flag (P3 D-07; this plan extends its comment to record dual-consumer semantics)
  - phase: 05-packages-layer-brewfile-composition-verification
    provides: textual-amend precedent (D-02) for soft schema migrations like the macos-finder comment expansion
provides:
  - Four new kebab-case macos-* feature keys (macos-dock, macos-input, macos-screenshots, macos-security) in manifests/defaults.toml [features], all defaulting to false
  - macos-finder row comment updated to record D-01 dual-consumer mapping (P3 alias + P6 defaults)
  - macos-security = true on server-1 and server-2 manifests, locking the D-04 server contract (security defaults + shell-registration only; other four macos-* keys absent -> inherited false)
  - Stable schema baseline for Phase 6 Plans 02 (concern scripts) and 03 (taskfiles/macos.yml consumers) to consume without race conditions
affects:
  - 06-02 (concern scripts can rely on the kebab-case feature namespace landing in resolved.json)
  - 06-03 (taskfiles/macos.yml consumers must use `index .MANIFEST.features "<key>"` -- kebab-case requires index form per CLAUDE.md)
  - 06-04 (docs/MANIFEST.md schema reference table + ROADMAP/REQUIREMENTS textual amends will inherit the flat schema established here)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Kebab-case feature keys in [features] block (defaults false; opt-in)"
    - "Server-contract-by-absence: deliberate omission of macos-{dock,finder,input,screenshots} keys on server TOMLs documents the inheritance contract (D-04)"
    - "Inline dual-consumer comment on macos-finder records same-flag-two-consumers semantics (D-01) for future readers"

key-files:
  created: []
  modified:
    - manifests/defaults.toml
    - manifests/machines/server-1.toml
    - manifests/machines/server-2.toml

key-decisions:
  - "D-01 (locked, this plan implements): flat kebab-case feature keys; macos-finder is dual-consumer (P3 alias + P6 defaults) -- single flag drives both surfaces"
  - "D-04 (locked, this plan implements): server-1 and server-2 declare macos-security = true; other four macos-* keys deliberately absent -> inherit false from defaults"
  - "Schema lands in Wave 0 with zero behavior coupling -- Plans 02 and 03 build against a stable feature-flag namespace"

patterns-established:
  - "Schema-only Wave 0 plan: introduces feature-flag namespace before consumers; downstream plans can rely on the keys being resolvable"
  - "Deliberate absence as contract: server TOMLs omit the four GUI-related macos-* keys to document inheritance, with an inline comment naming the absent keys"

requirements-completed: [OSCF-02]

# Metrics
duration: 9 min
completed: 2026-05-15
---

# Phase 06 Plan 01: Manifest Schema Migration -- Four New macos-* Feature Keys Summary

**Added macos-dock/macos-input/macos-screenshots/macos-security to defaults.toml [features] as kebab-case false-defaults, enabled macos-security on both server TOMLs (D-04), and updated the macos-finder row comment to record D-01 dual-consumer semantics.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-05-16T04:08:00Z (approx; wave start)
- **Completed:** 2026-05-16T04:17:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Locked the Phase 6 feature-flag namespace as flat kebab-case keys (`macos-dock`, `macos-input`, `macos-screenshots`, `macos-security`) in `manifests/defaults.toml [features]`, all defaulting to `false` per D-01 (opt-in feature flags).
- Recorded D-01 dual-consumer mapping inline on the existing `macos-finder` row -- a reader of `defaults.toml` now sees `shell/aliases/finder.zsh (P3) + os/defaults/finder.zsh (P6)` cross-phase semantics without grepping.
- Locked the D-04 server contract: `server-1.toml` and `server-2.toml` now declare `macos-security = true`, with the other four `macos-*` keys deliberately absent (inherited as `false`). The deliberate absence is documented via an inline comment naming the absent keys.
- Confirmed via direct resolver invocation that all four declared machines resolve the macos-* contract correctly: laptops resolve all five `true`; servers resolve `macos-security = true` and the other four `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add four new macos-* keys to manifests/defaults.toml + update macos-finder comment** - `a72d800` (feat)
2. **Task 2: Add macos-security = true to both server TOMLs and regenerate resolved.json** - `820fd8a` (feat)

**Plan metadata:** _final SUMMARY commit recorded in this commit_

## Files Created/Modified

- `manifests/defaults.toml` -- `[features]` block grew four kebab-case keys (`macos-dock = false`, `macos-input = false`, `macos-screenshots = false`, `macos-security = false`); existing `macos-finder` row comment expanded to record D-01 dual-consumer mapping (P3 alias + P6 defaults).
- `manifests/machines/server-1.toml` -- `[features]` block gained `macos-security = true` (D-04) with an inline comment naming the four absent (inherited-false) keys.
- `manifests/machines/server-2.toml` -- identical edit to server-1.

## Decisions Made

- **D-01 implementation choice (locked in CONTEXT):** flat kebab-case keys, single source of truth for both alias-gate (P3) and defaults-gate (P6) consumers of `macos-finder`. Already locked in CONTEXT -- this plan implements the schema landing.
- **D-04 implementation choice (locked in CONTEXT):** servers declare `macos-security = true` only; the other four `macos-*` keys are deliberately absent and inherit `false`. Inline comment documents which keys are absent so a future reader cannot mistake the absence for an oversight.
- **No textual amends to ROADMAP / REQUIREMENTS / docs/MANIFEST.md in this plan.** Those amends are deferred to a later Phase 6 plan (per the plan's `<output>` section explicitly scoping this plan to the three TOML files).

## Deviations from Plan

None - plan executed exactly as written.

A brief false-alarm investigation occurred during Task 2 verification when an interactive synthetic-resolution test against `server-1` (rewriting the active-machine state file and re-running `task manifest:resolve`) initially appeared to show server-1 resolving all macos-* keys as `true`. Root cause: `task manifest:resolve` has a status-block mtime cache (`taskfiles/manifest.yml:164-168`) that only re-invokes the resolver when the manifest TOMLs are newer than `resolved.json`. Re-running with `--stdout` bypassed the cache and confirmed the resolver produces the correct D-04 contract for both servers. The active machine's `resolved.json` was restored to `personal-laptop` state with all five `macos-*` keys present. This is not a deviation: the resolver's behavior is correct (cached output matches the inputs at the time of caching); the test methodology had to be adjusted to use `--stdout` for ad-hoc cross-machine verification.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Hand-offs to subsequent Phase 6 plans:

- **Plan 02 (concern scripts):** can rely on the kebab-case feature namespace (`macos-dock`, `macos-finder`, `macos-input`, `macos-screenshots`, `macos-security`) being present in every active machine's `resolved.json`.
- **Plan 03 (`taskfiles/macos.yml` consumers):** every gate uses the kebab-case `index` form, e.g. `{{if index .MANIFEST.features "macos-dock"}}` -- dot access is invalid for kebab-case keys per CLAUDE.md.
- **Plan 04 (docs/MANIFEST.md + ROADMAP + REQUIREMENTS textual amends):** the schema is now landed; the documentation table can flip the four "machine-set (not in defaults.toml)" rows to `false` and add the dual-consumer note on `macos-finder`.

No blockers. Schema is stable; resolver round-trip verified across all four declared machines.

## Self-Check: PASSED

Files verified to exist with the expected content:

- `manifests/defaults.toml` -- contains all five `macos-*` keys plus dual-consumer comment on `macos-finder`
- `manifests/machines/server-1.toml` -- contains `macos-security = true` with deliberate-absence comment
- `manifests/machines/server-2.toml` -- identical to server-1

Commits verified present:

- `a72d800` -- Task 1 (defaults.toml edit)
- `820fd8a` -- Task 2 (server TOMLs edit)

End-to-end verification (all 5 plan-level checks):

1. `grep -c '^macos-' manifests/defaults.toml` returns 5 -- PASS
2. `grep -c '^macos-security = true'` on both server TOMLs returns 2 -- PASS
3. `grep -cE '^macos-(dock|finder|input|screenshots) = '` on both server TOMLs returns 0 -- PASS
4. `task manifest:resolve && task manifest:validate` succeeds; `resolved.json` has all five `macos-*` keys as booleans -- PASS
5. `git status` outside `manifests/` and `.planning/` is empty -- PASS

Cross-machine resolver spot-check (via `zsh install/resolver.zsh --machine <name> --stdout`):

- server-1: `macos-security=true`, others `false` -- contract satisfied
- server-2: `macos-security=true`, others `false` -- contract satisfied
- personal-laptop: all five `true` -- preserves existing laptop contract
- work-laptop: all five `true` -- preserves existing laptop contract

---
*Phase: 06-os-defaults-macos-configuration*
*Completed: 2026-05-15*
