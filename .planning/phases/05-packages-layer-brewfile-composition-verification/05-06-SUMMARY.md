---
phase: 05-packages-layer-brewfile-composition-verification
plan: 06
subsystem: docs
tags: [docs, requirements, roadmap, manifest-schema]
requires: []
provides:
  - "REQUIREMENTS.md PKGS-01 corrected (flat layout + minimal bundles)"
  - "REQUIREMENTS.md PKGS-04 corrected (typed sub-table + object shapes)"
  - "ROADMAP.md Phase 5 SC#3 corrected (2-bundle minimum + typed-bucket extras)"
  - "PROJECT.md Active Packages bullet corrected (flat layout + typed extras)"
  - "docs/MANIFEST.md schema reference + Fixture 06 reflect typed-bucket model"
affects:
  - "All future readers (humans + AI agents) of the canonical project docs"
tech-stack:
  added: []
  patterns:
    - "Documentation surgical-replacement (single bullet/cell per edit)"
key-files:
  created:
    - .planning/phases/05-packages-layer-brewfile-composition-verification/05-06-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/PROJECT.md
    - docs/MANIFEST.md
decisions:
  - "Preserved the 'no Brewfile-<profile>.rb' prohibition in ROADMAP SC#3 (D-02 narrative)"
  - "Fixture 06 demonstrates bare-string + object coexistence in formulae to make the new shape concrete"
  - "Backward-compat note for legacy flat-array fixture added to Fixture 06 prose -- existing Phase 1 fixtures still pass under Pass 2 resolver"
metrics:
  duration: "~10 minutes"
  completed: 2026-05-15T18:21:40Z
  tasks_completed: 4
  files_modified: 4
---

# Phase 5 Plan 6: Canonical Docs Corrections Summary

Aligned `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, and `docs/MANIFEST.md` with the typed-bucket + minimal-bundles + flat-layout decisions (D-01, D-02, D-03, D-04, D-06) so canonical docs match what Plans 01-05 actually build.

## Plan Goal

Documentation half of PKGS-01 + PKGS-04. The code-side half is in Plans 01 (bundle files at flat paths) and 02 (typed-bucket TOMLs). Four files had stale text from before D-01/D-02/D-03 were settled; this plan applies surgical replacements at five specific call sites with no other changes.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Update REQUIREMENTS.md PKGS-01 + PKGS-04 text | `8070b94` | `.planning/REQUIREMENTS.md` |
| 2 | Update ROADMAP.md Phase 5 success criterion #3 | `f42c5ad` | `.planning/ROADMAP.md` |
| 3 | Update PROJECT.md Active Packages bullet | `0cad7af` | `.planning/PROJECT.md` |
| 4 | Update docs/MANIFEST.md schema + Fixture 06 | `f00aca0` | `docs/MANIFEST.md` |

## Before/After per File

### `.planning/REQUIREMENTS.md` (PKGS-01, PKGS-04)

**PKGS-01 before:**
> Per-purpose Brewfile bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`) -- named by role, not by profile

**PKGS-01 after:**
> Per-purpose Brewfile bundles in `packages/<purpose>.rb` (flat -- not `packages/brew/`). v1 ships `core` and `gui`; bundles are an as-needed grouping, not a fixed set (per-machine extras carry the bulk).

**PKGS-04 before:**
> Manifest can declare per-machine `extra_packages` (additive, concatenates with bundle contents)

**PKGS-04 after:**
> Manifest can declare per-machine `extra_packages` as a typed sub-table (`formulae`, `casks`, `mas`); each sub-array concat+dedupes with defaults at resolve time. Cask and MAS entries are typed objects (`{name, verify}` for casks; `{id, name}` for MAS).

### `.planning/ROADMAP.md` (Phase 5 SC#3)

**Before:**
> Bundles are named by purpose (`core.rb`, `gui.rb`, `dev.rb`, `ops.rb`, `personal.rb`) -- no `Brewfile-<profile>.rb` files anywhere; a Mac server machine can decline GUI bundles via manifest and its composed Brewfile contains no casks; per-machine `extra_packages` adds a one-off tool without forking a bundle

**After:**
> Bundles are named by purpose (`core.rb`, `gui.rb`, and any future purpose-named additions) -- no `Brewfile-<profile>.rb` files anywhere; per-machine variation lives in `extra_packages` typed sub-table (`formulae`/`casks`/`mas`), not in bundle files; a Mac server machine can decline GUI bundles via manifest and its composed Brewfile contains no casks.

### `.planning/PROJECT.md` (Active Packages bullet)

**Before:**
> Per-purpose bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`) -- named by role, not by profile

**After:**
> Per-purpose bundles in flat `packages/<purpose>.rb` (`core`, `gui`; +any future purpose-named additions). Per-machine variation lives in manifest `extra_packages` typed sub-table (`formulae`/`casks`/`mas`).

### `docs/MANIFEST.md` (Optional-fields table + Fixture 06)

**Optional-fields row before** (single line):
> | `packages.brew.extra_packages` | array of strings | Additive escape hatch; deduplicated union with defaults value |

**Optional-fields rows after** (three lines):
> | `packages.brew.extra_packages.formulae` | array of strings or `{name, verify}` objects | Per-machine formula extras; concat+dedupe across defaults + machine |
> | `packages.brew.extra_packages.casks` | array of `{name, verify}` objects | Per-machine cask extras; `verify` field is MANDATORY per cask (D-04) |
> | `packages.brew.extra_packages.mas` | array of `{id, name}` objects | Per-machine MAS app extras; `name` doubles as the `.app` verify name (D-06) |

**Fixture 06 before:** flat-array example with `extra_packages = ["jq", "yq"]` defaults and `extra_packages = ["docker-desktop", "jq"]` machine -> `["docker-desktop", "jq", "yq"]` deduped union.

**Fixture 06 after:** typed-bucket example -- defaults declares `formulae = ["jq", "yq"]`, `casks = []`, `mas = []`; machine declares `formulae = [{name = "ripgrep", verify = "rg"}]`, `casks = [{name = "docker-desktop", verify = "Docker"}]`. Resolved output shows per-sub-array concat+dedupe, bare-string + object coexistence in `formulae`, machine-only `casks`, empty `mas`. Prose adds backward-compat note for legacy flat-array fixture under Pass 2 resolver.

## Doc/Code Drift Status (post-edit)

| Decision | Doc-side asserts | Code-side delivers (Plans 01-05) | Aligned? |
|----------|------------------|----------------------------------|----------|
| D-01 flat layout | `packages/<purpose>.rb` (no `brew/` subdir) -- REQUIREMENTS PKGS-01, PROJECT, ROADMAP SC#3 | Plan 01 ships flat bundle files | Yes |
| D-02 minimal bundles | v1 ships `core` + `gui`; bundles are as-needed -- REQUIREMENTS PKGS-01, PROJECT, ROADMAP SC#3 | Plan 01 ships exactly two bundles | Yes |
| D-03 typed-bucket extras | sub-table `formulae`/`casks`/`mas` -- REQUIREMENTS PKGS-04, PROJECT, ROADMAP SC#3, MANIFEST.md | Plan 02 ships typed-bucket TOMLs; Plan 03 ships per-sub-array merge in Pass 2 | Yes |
| D-04 cask verify mandatory | `verify` field MANDATORY per cask -- MANIFEST.md casks row | Plan 02 TOMLs include `verify` on every cask object | Yes |
| D-06 MAS shape | `{id, name}` objects; `name` doubles as `.app` verify name -- REQUIREMENTS PKGS-04, MANIFEST.md mas row | Plan 02 TOMLs use the typed shape | Yes |

No doc/code drift remains for the five decisions targeted by this plan.

## Verification

All `<verify>` automated checks for each task passed:

- Task 1: REQUIREMENTS.md grep -- PKGS-01 contains `packages/<purpose>.rb` and no 5-bundle enumeration; PKGS-04 contains `typed sub-table`, `formulae`, `casks`, `mas`, and both object shapes.
- Task 2: ROADMAP.md grep -- SC#3 contains `core.rb`, `gui.rb`, the `Brewfile-` prohibition, and `typed sub-table`; the 5-bundle enumeration is gone.
- Task 3: PROJECT.md grep -- "Per-purpose bundles" line contains `packages/<purpose>.rb` and `typed sub-table`; `packages/brew/` is gone; 5-bundle enumeration is gone.
- Task 4: docs/MANIFEST.md grep -- three new typed-bucket Optional-fields rows present; legacy flat-array Optional-fields row gone; cask row mentions MANDATORY verify; MAS row mentions `name` doubling as `.app` name; Fixture 06 shows per-sub-array concat+dedupe with `formulae`/`casks`/`mas` keys.

Plan-level verification (per `<verification>` block):

1. REQUIREMENTS PKGS-01 -- `packages/<purpose>.rb` present, no `packages/brew/` as layout claim, no 5-bundle fixed set: PASS.
2. REQUIREMENTS PKGS-04 -- `typed sub-table`, all three sub-array names, object shapes: PASS.
3. ROADMAP SC#3 -- core.rb, gui.rb, Brewfile- prohibition, typed sub-table: PASS.
4. PROJECT Packages -- flat path, no packages/brew/, extra_packages + typed buckets: PASS.
5. MANIFEST.md -- three typed-bucket rows, legacy flat-array row absent: PASS.
6. MANIFEST.md Fixture 06 -- typed-bucket merge semantics with `formulae`/`casks`/`mas`: PASS.
7. Markdown parse sanity -- line counts intact, files render: PASS.
8. No emojis introduced; no AI attribution introduced (pre-existing `Claude Code`, `claude-marketplace`, and `Co-Authored-By` references are unchanged and refer to the product / feature flag / project's own anti-attribution convention, not to this edit): PASS.
9. REQUIREMENTS.md Traceability table -- 5 PKGS rows, 4 VRFY rows: unchanged.

## Deviations from Plan

None. The plan prescribed five surgical replacements at five specific call sites; each was applied with the prescribed text and no other lines were touched.

### Auto-fixed Issues

None. No bugs found, no missing critical functionality, no blocking issues encountered.

## Authentication Gates

None.

## Known Stubs

None. All edits are concrete documentation changes that immediately take effect for any future doc reader.

## Threat Flags

None. No new security surface introduced -- this plan touches only canonical documentation.

## Requirements Addressed

- PKGS-01 (documentation-side completion -- code-side delivered by Plan 05-01)
- PKGS-04 (documentation-side completion -- code-side delivered by Plans 05-02 and 05-03)

Requirements remain in `[ ]` state in REQUIREMENTS.md because the v1 cutover gate (CUTV-04) checks each requirement on all four target machines; the doc-side edit does not flip the box. The orchestrator will mark them complete after the phase verifier confirms code + docs both ship.

## Self-Check: PASSED

- File: `.planning/REQUIREMENTS.md` -- FOUND (modified)
- File: `.planning/ROADMAP.md` -- FOUND (modified)
- File: `.planning/PROJECT.md` -- FOUND (modified)
- File: `docs/MANIFEST.md` -- FOUND (modified)
- File: `.planning/phases/05-packages-layer-brewfile-composition-verification/05-06-SUMMARY.md` -- FOUND (this file)
- Commit `8070b94` -- FOUND (Task 1)
- Commit `f42c5ad` -- FOUND (Task 2)
- Commit `0cad7af` -- FOUND (Task 3)
- Commit `f00aca0` -- FOUND (Task 4)
