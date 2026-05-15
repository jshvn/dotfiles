---
phase: 05-packages-layer-brewfile-composition-verification
plan: 02
subsystem: packages
tags: [manifest, schema, toml, packages, extras, brewfile]

# Dependency graph
requires:
  - phase: 01-manifest-engine-repository-skeleton
    provides: "Five manifest TOMLs (defaults + four machines) with the legacy flat `extra_packages = []` shape and the resolver pipeline that reads them."
provides:
  - "Typed-bucket `[packages.brew.extra_packages]` sub-table shape (formulae, casks, mas) across defaults.toml + all four machine manifests"
  - "27 personal-laptop casks + 2 MAS apps, 18 work-laptop casks + 2 MAS apps, explicit empty buckets on both servers"
  - "Bundle trim: personal-laptop and work-laptop drop down to [\"core\", \"gui\"]; servers stay at [\"core\"] (PKGS-05 invariant preserved)"
  - "Every cask entry declares explicit { name, verify } per D-04 (verify mandatory; no derivation)"
  - "Every MAS entry declares { id, name } per D-06 (name doubles as the verify target)"
affects: [05-03, 05-04, 05-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-03 typed-bucket extras schema (one TOML sub-table, three independent sub-arrays)"
    - "D-04 mandatory `verify` on every cask (drift guard at TOML edit time, not at install-time)"
    - "D-05 hybrid pattern: defaults supply shape, every machine TOML re-declares every required field explicitly"
    - "D-06 MAS entry shape `{ id, name }` where `name` is also the verify target"

key-files:
  created: []
  modified:
    - "manifests/defaults.toml"
    - "manifests/machines/personal-laptop.toml"
    - "manifests/machines/work-laptop.toml"
    - "manifests/machines/server-1.toml"
    - "manifests/machines/server-2.toml"

key-decisions:
  - "Migration is a self-replacement of `[packages.brew]` only; [meta], [platform], [features], [identity], and `schema_version` unchanged in every file (drift surface kept minimal)."
  - "Explicit empty `[packages.brew.extra_packages]` declared on servers (rather than relying on defaults inheritance) so the resolver/composer never reads `null` and never needs a `// []` guard at downstream sites."
  - "1password, ghostty, and 1password-cli stay out of every machine's extras list (they live in gui.rb / core.rb per Plan 01); the verify-field divergence (e.g., zoom -> zoom.us; docker-desktop -> Docker) is exactly the D-04 rationale and is now encoded in the manifests."

patterns-established:
  - "Pattern (this plan): TOML extras sub-table with three named sub-arrays; resolver Pass 2 must concat+dedupe per sub-array (Plan 03 work, NOT this plan)."
  - "Pattern (this plan): Every cask + MAS entry declares both human-readable verify text and bare cask/id at TOML edit time -- review-gate threat (T-05-07) accepted because divergence is now visually obvious in PR diffs."

requirements-completed: [PKGS-04, PKGS-05]

# Metrics
duration: ~12min
completed: 2026-05-15
---

# Phase 05 Plan 02: Manifest Extras Typed-Bucket Migration Summary

**Migrated five manifest TOMLs from flat `extra_packages = [...]` to `[packages.brew.extra_packages]` sub-table (formulae/casks/mas) with 27 personal + 18 work casks carrying mandatory verify fields plus 2 MAS apps each.**

## Performance

- **Duration:** ~12 minutes
- **Started:** 2026-05-15T (plan execution)
- **Completed:** 2026-05-15
- **Tasks:** 4 (all `type="auto"`, no checkpoints)
- **Files modified:** 5

## Accomplishments

- `manifests/defaults.toml` baseline schema migrated to typed-bucket extras (empty formulae/casks/mas sub-arrays); legacy `extra_packages = []` removed.
- `manifests/machines/personal-laptop.toml` bundles trimmed from `["core", "gui", "dev", "personal"]` to `["core", "gui"]` (D-02); 27 casks + 2 MAS apps from v1 Brewfile-personal.rb migrated into typed extras with verify text on every entry (D-04).
- `manifests/machines/work-laptop.toml` bundles trimmed from `["core", "gui", "dev"]` to `["core", "gui"]`; 18 casks + 2 MAS apps from v1 Brewfile-work.rb migrated.
- `manifests/machines/server-1.toml` and `server-2.toml` receive explicit empty typed buckets; bundles remain at `["core"]` (PKGS-05: servers decline gui).
- Resolver `--validate-only` accepts all four machine manifests; pre-plan lint exit code (201, from unrelated taskfile failures) preserved -- no new lint regressions introduced.

## Task Commits

Each task was committed atomically on `worktree-agent-ae6f4f2981a120aed`:

1. **Task 1: Migrate manifests/defaults.toml to typed-bucket extras schema** — `5bd3a97` (refactor)
2. **Task 2: Migrate manifests/machines/personal-laptop.toml** — `b5ca424` (refactor)
3. **Task 3: Migrate manifests/machines/work-laptop.toml** — `10ff11a` (refactor)
4. **Task 4: Migrate manifests/machines/server-1.toml + server-2.toml** — `daa137b` (refactor)

## Files Created/Modified

- `manifests/defaults.toml` — Legacy `extra_packages = []` replaced with `[packages.brew.extra_packages]` sub-table; three empty typed sub-arrays (formulae, casks, mas) seeded by the defaults layer.
- `manifests/machines/personal-laptop.toml` — Bundles trimmed to `["core", "gui"]`; 27 casks + 2 MAS apps populated with explicit `{ name, verify }` (D-04) and `{ id, name }` (D-06) entries.
- `manifests/machines/work-laptop.toml` — Bundles trimmed to `["core", "gui"]`; 18 casks + 2 MAS apps populated. No prior `extra_packages` line on this file pre-plan.
- `manifests/machines/server-1.toml` — Bundles unchanged at `["core"]`; explicit empty typed buckets added for downstream dot-access correctness.
- `manifests/machines/server-2.toml` — Same change as server-1.

## Final Inventory Counts

| Machine          | Bundles         | Casks | MAS Apps | Formulae |
|------------------|-----------------|-------|----------|----------|
| personal-laptop  | core, gui       | 27    | 2        | 0        |
| work-laptop      | core, gui       | 18    | 2        | 0        |
| server-1         | core            | 0     | 0        | 0        |
| server-2         | core            | 0     | 0        | 0        |
| defaults         | core (baseline) | 0     | 0        | 0        |

## Bundle Trim Deltas

| Machine          | Pre-plan bundles                   | Post-plan bundles | Dropped     |
|------------------|------------------------------------|-------------------|-------------|
| personal-laptop  | core, gui, dev, personal           | core, gui         | dev, personal |
| work-laptop      | core, gui, dev                     | core, gui         | dev         |
| server-1         | core                               | core              | (none)      |
| server-2         | core                               | core              | (none)      |

D-02 minimal-bundles invariant: laptops carry `gui`; servers do not (PKGS-05).

## Decisions Made

- **Implementation choice:** Self-replacement editing (single `Edit` per file replacing the `[packages.brew]` stanza) rather than `yq -i`-based transformation. Justification: yq write-back through `.toml` is roundtrip-safe but reorders keys and strips comments; manual self-replacement preserves the file-header comment block + sibling-stanza ordering.
- **Verify text source:** Used CONTEXT specifics block (lines 317-393) verbatim as the authoritative inventory. Did not re-derive verify names from `mdfind` because verification against live `/Applications/` is the planner-discretion footnote called out in the plan's Output section -- left as a sanity-check note below rather than executed in-plan.

## Deviations from Plan

None — plan executed exactly as written.

All four tasks completed in order, every acceptance criterion satisfied, no auto-fixes or Rule 1/2/3 deviations triggered. No checkpoints in this plan.

---

**Total deviations:** 0
**Impact on plan:** Zero scope creep; zero unplanned files touched.

## Issues Encountered

- One verification command in plan acceptance criteria used a `bash`-style quoting form (`yq '... contains(["gui"]) ...'`) that produced a yq lexer error inside a heredoc-free shell wrapper. Worked around it locally by re-expressing the same invariant via `yq '.packages.brew.bundles[] | select(. == "gui")'` and asserting the result is empty. The TOML output is correct; this was a verification-script quoting quirk, not a TOML defect.
- Resolver `Pass 2` (`install/resolver.zsh:315-320`) still treats `extra_packages` as a flat array (`jq -s 'add | unique'`) and will NOT correctly union the new typed-bucket shape. This is **out of scope for this plan**: Plan 03 owns the resolver merge-pipeline extension. Until Plan 03 ships, `task manifest:resolve` will produce malformed `.packages.brew.extra_packages` in `resolved.json`. The plan's verification section step 5 explicitly anticipates and documents this exact failure mode; the `--validate-only` path (used by `task manifest:validate`) does NOT exercise Pass 2 and passes cleanly for all four machines.

## Sanity-Check Note for Future Live Verification

Per the Output section "Claude's Discretion footnote": the cask `verify` strings encode the `/Applications/<Verify>.app` directory name Apple/the vendor ships with each app. They were taken verbatim from CONTEXT specifics rather than checked against `mdfind -name '<App>.app' -onlyin /Applications` on the live `personal-laptop`. Suggested follow-up (Plan 04 or a Phase 5 verification milestone): run

```zsh
yq -o=json '.packages.brew.extra_packages.casks[] | .verify' manifests/machines/personal-laptop.toml \
  | tr -d '"' \
  | while IFS= read -r app; do
      [ -d "/Applications/${app}.app" ] && echo "OK ${app}" || echo "MISS ${app}"
    done
```

on a freshly-installed machine. Notable verify entries to double-check (their cask names diverge from their `.app` directory names — exactly the case D-04 was designed for):

| Cask                  | Verify (.app dir)        |
|-----------------------|--------------------------|
| zoom                  | zoom.us                  |
| docker-desktop        | Docker                   |
| nvidia-geforce-now    | NVIDIA GeForce NOW       |
| cloudflare-warp       | Cloudflare WARP          |
| protonvpn             | Proton VPN               |

Any false-positive `MISS` indicates a verify-text correction is needed.

## Downstream Notes

- **Plan 03 (composer + resolver pipeline extension):** MUST extend `install/resolver.zsh` Pass 2 from a single `jq -s 'add | unique'` over a flat array to three independent concat+dedupe operations across `formulae`, `casks`, and `mas`. Until this lands, `resolved.json` will not faithfully reflect the new typed-bucket schema.
- **Plan 04 (taskfiles/packages.yml + compose-brewfile.zsh):** Reads `.packages.brew.extra_packages.{formulae,casks,mas}` from `resolved.json` via dot-access. T-05-05 mitigation (verify-field shell quoting) lives in Plan 04, not here -- the threat surface is now present in the TOMLs but no taskfile currently consumes it.
- **Plan 06 (docs/MANIFEST.md update):** Schema documentation needs to be re-synced to the typed-bucket shape; this plan only writes valid TOML against the new shape, not the schema reference doc.

## Requirements Completed

- **PKGS-04** -- Manifest typed-bucket extras schema (`[packages.brew.extra_packages]` with `formulae`/`casks`/`mas` sub-arrays). Realized across all five manifests.
- **PKGS-05** -- Server machines decline GUI by keeping `bundles = ["core"]`. Both server-1 and server-2 retain `["core"]` post-migration; `gui` is not a member of either bundles list.

## Cross-References

- D-02 (minimal bundles + heavy extras) -- bundle trim decisions for laptops
- D-03 (typed-bucket schema) -- the canonical shape this plan ships
- D-04 (cask verify mandatory) -- every cask entry in every machine carries verify
- D-05 (hybrid declaration -- defaults shape + per-machine explicit) -- why servers re-declare empty typed buckets
- D-06 (MAS entry `{ id, name }`) -- both laptops carry Magnet (441258766) and Things (904280696)

## Self-Check: PASSED

Verified all artifacts exist and all four commits are reachable from HEAD on `worktree-agent-ae6f4f2981a120aed`:

- `manifests/defaults.toml` — present, `.packages.brew.extra_packages | tag` = `!!map`
- `manifests/machines/personal-laptop.toml` — present, 27 casks + 2 mas
- `manifests/machines/work-laptop.toml` — present, 18 casks + 2 mas
- `manifests/machines/server-1.toml` — present, empty typed buckets, bundles `["core"]`
- `manifests/machines/server-2.toml` — present, empty typed buckets, bundles `["core"]`
- Commits `5bd3a97`, `b5ca424`, `10ff11a`, `daa137b` all present in `git log`.
- Resolver `--validate-only` exits 0 for all four machines.
- Lint exit code unchanged from pre-plan baseline (201, unrelated taskfile failures).

---
*Phase: 05-packages-layer-brewfile-composition-verification*
*Plan: 02*
*Completed: 2026-05-15*
