---
phase: 01-manifest-engine-repository-skeleton
plan: 01
subsystem: testing
tags: [manifest, toml, fixtures, deep-merge, golden-output, yq, jq]

# Dependency graph
requires: []
provides:
  - Six positive golden-output fixtures covering MFST-05 merge cases (map-over-map, list-replace, scalar-override, nested-table, missing-keys, extra_packages concat)
  - Two negative fixtures covering MFST-08 schema-validation paths (missing meta.description, platform.os != darwin) — exercise T-MAN-01
  - manifests/test/README.md documenting fixture layout and `task manifest:test` invocation
affects: [01-02-resolver, 01-03-taskfile-manifest-test, 01-04-skeleton]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Golden-output test fixtures as the executable specification (D-08)"
    - "Per-fixture directory = three files (defaults.toml, machine.toml, expected.json); negative fixtures hold only machine.toml"
    - "Two-pass extra_packages dedupe documented inline in fixture 06 expected.json (machine values first, then defaults-only values, deduped)"

key-files:
  created:
    - manifests/test/fixtures/01-map-over-map/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/02-list-replace/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/03-scalar-override/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/04-nested-table/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/05-missing-keys/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/06-extra-packages-concat/{defaults.toml,machine.toml,expected.json}
    - manifests/test/fixtures/_invalid-missing-desc/machine.toml
    - manifests/test/fixtures/_invalid-bad-os/machine.toml
    - manifests/test/README.md
  modified: []

key-decisions:
  - "Encoded D-06 merge semantics (machine-wins, sibling preservation, array replace, extra_packages union dedupe) verbatim in hand-computed expected.json files — fixtures are the spec, not the resolver."
  - "Fixture 04 was authored exactly per RESEARCH §4.1 nested-table row and the plan's <interfaces> reference shape: shared='machine-value', siblings preserved at every level, [a.b.c.d.f] machine-only branch."
  - "Negative fixtures intentionally omit a sibling expected.json — their pass condition is non-zero exit from manifest:validate (asserted by Plan 03)."

patterns-established:
  - "Pattern: minimal fixture TOML — only keys relevant to the merge case under test; no full manifests"
  - "Pattern: single-line `# fixture NN -- <case>` comment header on every TOML; JSON has no comments"
  - "Pattern: README at manifests/test/ documents both production invocation (`task manifest:test`) and Phase-1 invocation (`task -t taskfiles/manifest.yml manifest:test`)"

requirements-completed: [MFST-03, MFST-05, MFST-08]

# Metrics
duration: 4 min
completed: 2026-05-13
---

# Phase 01 Plan 01: Test Fixtures Summary

**Hand-computed golden-output fixtures encoding the D-06 deep-merge rules (six positive merge cases + two negative validation cases) as the executable specification for the resolver and `task manifest:test` driver.**

## Performance

- **Duration:** 4 min (267s)
- **Started:** 2026-05-13T21:45:09Z
- **Completed:** 2026-05-13T21:49:36Z
- **Tasks:** 2
- **Files modified:** 21 (18 positive fixture files + 2 negative fixtures + 1 README)

## Accomplishments

- Twenty fixture files and one README authored under `manifests/test/`, covering all six merge cases enumerated in MFST-05 and both negative validation paths called out by MFST-08.
- All 14 TOML inputs parse cleanly through `yq -p toml`; all six `expected.json` files parse cleanly through `jq`.
- Per-fixture jq invariants from the plan's `<acceptance_criteria>` all pass (map-over-map sibling preservation, bundles wholesale replace, machine scalar override, four-level nested sibling preservation, missing-key preservation in both directions, extra_packages union-dedupe with machine-first ordering).
- Two negative fixtures (`_invalid-missing-desc`, `_invalid-bad-os`) ready as the test surface for T-MAN-01 (malformed-manifest rejection) — assertions deferred to Plan 03 per the threat-register disposition.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author six positive merge-case fixtures** — `12c9f4b` (test)
2. **Task 2: Author two negative fixtures plus manifests/test/README.md** — `6338308` (test)

## Files Created/Modified

- `manifests/test/fixtures/01-map-over-map/{defaults,machine}.toml,expected.json` — deep-merge of sibling-only `[features]` tables
- `manifests/test/fixtures/02-list-replace/{defaults,machine}.toml,expected.json` — machine `bundles` array wholesale-replaces defaults
- `manifests/test/fixtures/03-scalar-override/{defaults,machine}.toml,expected.json` — `meta.description` machine wins
- `manifests/test/fixtures/04-nested-table/{defaults,machine}.toml,expected.json` — `[a.b.c.d.{e,f}]` siblings preserved at every level
- `manifests/test/fixtures/05-missing-keys/{defaults,machine}.toml,expected.json` — `[only_in_defaults]` and `[only_in_machine]` both preserved
- `manifests/test/fixtures/06-extra-packages-concat/{defaults,machine}.toml,expected.json` — union dedupe `["docker-desktop","jq","yq"]`
- `manifests/test/fixtures/_invalid-missing-desc/machine.toml` — full required-field set minus `meta.description`
- `manifests/test/fixtures/_invalid-bad-os/machine.toml` — full required-field set with `platform.os = "linux"`
- `manifests/test/README.md` — 15-line fixture layout doc with `task manifest:test` invocation

## Decisions Made

- **Fixture 04 expected.json encodes `[a.b.c.d.e]` as a deep-merge of both sides** (`deep_nested=true` from defaults, `deep_nested_override="yes"` from machine) — verified against RESEARCH §4.1 row 4 and the plan's `<interfaces>` reference shape.
- **Fixture 06 expected.json preserves machine-first ordering verbatim** (`["docker-desktop","jq","yq"]`) — matches RESEARCH §5 pass-2 semantics. The plan's acceptance criterion uses sort-equality (`| sort == [...]`) but the file is authored in the canonical machine-first order so the union-dedupe assertion exercises ordering too.
- **Negative fixtures include the full required-field set on the non-failing axes** (e.g., `_invalid-missing-desc` has every other D-03 field present; `_invalid-bad-os` has `meta.description`). This isolates the validator's failure to exactly one cause per fixture — critical for Plan 03's stderr-substring assertions.

## Deviations from Plan

None — plan executed exactly as written. The plan's `<verify>` automated commands invoke `yq '.' <file>` (which defaults to YAML mode in yq v4); I used `yq -p toml '.' <file>` for TOML files because the plan's text explicitly says "parses cleanly through yq" — TOML parsing requires `-p toml` in yq v4.53.2. This is verification methodology, not a fixture deviation; all acceptance criteria themselves passed unchanged.

## Issues Encountered

- **README initially 16 lines, exceeded the ≤15-line acceptance criterion.** Tightened the closing two-line "Phase-1 invocation" block into a single sentence with inline code, dropping to 15 lines. All required literal strings (`task manifest:test`, `fixtures`, `defaults.toml`) preserved.

## User Setup Required

None — fixtures are pure data; no external services or environment configuration.

## Next Phase Readiness

- **Plan 02 (resolver) has a stable, complete test target.** All six positive fixtures encode the D-06 merge contract; the resolver must reproduce the `expected.json` outputs exactly (after `jq -S` key-sort normalization).
- **Plan 03 (taskfile manifest:test driver) has the negative test surface ready.** Both `_invalid-*` fixtures encode a single failure axis each, so Plan 03's stderr-substring assertions can target one cause per case.
- **No fixture additions expected during downstream implementation.** If a resolver bug surfaces during Plan 02 that isn't covered by the six existing cases, that's a fixture gap to file as a Plan-02 deviation rather than a Plan-01 omission.

## Self-Check: PASSED

All 21 plan output files verified present on disk; both task commits (`12c9f4b`, `6338308`) verified in `git log`.

---
*Phase: 01-manifest-engine-repository-skeleton*
*Completed: 2026-05-13*
