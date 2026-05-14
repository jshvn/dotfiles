---
phase: 03-shell-layer-flat-content-port
plan: 01
subsystem: infra
tags: [toml, manifest, antidote, zsh-plugins, feature-flags]

# Dependency graph
requires:
  - phase: 01-manifest-engine-repository-skeleton
    provides: "defaults.toml + machine TOML schema, install/resolver.zsh deep-merge, manifest:validate/manifest:test taskfile entries"
provides:
  - "macos-finder, ghostty, jgrid-net feature flags declared in defaults.toml (all false by default)"
  - "ghostty + jgrid-net enabled on personal-laptop; ghostty enabled on work-laptop; servers inherit defaults"
  - "configs/antidote/zsh_plugins.txt with the verbatim seven-plugin bundle list from D-01"
affects: [03-02-zsh-startup, 03-03-aliases, 03-04-functions-and-prompt, 03-05-symlinks]

# Tech tracking
tech-stack:
  added: [antidote-bundle-source-file]
  patterns: [manifest-driven-feature-flags, defaults-supply-shape, additive-feature-keys]

key-files:
  created:
    - configs/antidote/zsh_plugins.txt
  modified:
    - manifests/defaults.toml
    - manifests/machines/personal-laptop.toml
    - manifests/machines/work-laptop.toml

key-decisions:
  - "Feature keys are kebab-case and require yq/go-template index access (per CLAUDE.md)"
  - "work-laptop keeps jgrid-net at default false (D-13: identity-coupled file, network reachability uneven)"
  - "Servers untouched: all three new flags inherit defaults.toml false (correct for headless ops)"
  - "Antidote bundle order matches v1 antigen invocation order; syntax-highlighting precedes autosuggestions"

patterns-established:
  - "Pattern 19 (defaults supply shape): adding a feature flag is an additive edit to defaults.toml; machine TOMLs only override when they want non-default behavior"
  - "Pattern 18 (data-not-script configs): configs/<tool>/ holds plain-text declarative data with no shebang and no executable bit"

requirements-completed: [SHEL-04]

# Metrics
duration: 2min
completed: 2026-05-14
---

# Phase 3 Plan 1: Manifest Feature Flags + Antidote Bundle Source Summary

**Three new feature flags (macos-finder, ghostty, jgrid-net) wired into the manifest baseline plus verbatim seven-plugin antidote bundle file, all resolving correctly through install/resolver.zsh.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-14T22:28:00Z
- **Completed:** 2026-05-14T22:30:00Z
- **Tasks:** 3
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `manifests/defaults.toml` now declares all six feature keys with inline comments naming the gated alias file for each new flag (D-10, D-12)
- `personal-laptop.toml` enables `ghostty=true` and `jgrid-net=true`; `work-laptop.toml` enables `ghostty=true` only — per D-13 jgrid-only-identity-coupled-file rationale
- `configs/antidote/zsh_plugins.txt` created with the exact seven-plugin list from D-01 in dependency-correct order (syntax-highlighting before autosuggestions)
- All four machine TOMLs still parse as valid TOML; `task manifest:validate` and `task manifest:test` (8/8 fixtures) continue to pass
- `install/resolver.zsh` round-trip confirmed: personal-laptop gets `ghostty=true, jgrid-net=true`; work-laptop gets `ghostty=true, jgrid-net=false`; servers get all three new flags false

## Task Commits

Each task was committed atomically on branch `worktree-agent-aa5b399fcdcf473b3`:

1. **Task 1: Add three feature flags to defaults.toml** — `aa1dcdf` (feat)
2. **Task 2: Enable ghostty + jgrid-net on laptop manifests** — `307a1ed` (feat)
3. **Task 3: Create configs/antidote/zsh_plugins.txt** — `1c85bbb` (feat)

## Files Created/Modified

- `manifests/defaults.toml` — added `macos-finder`, `ghostty`, `jgrid-net` (all false) with inline comments naming the gated alias files
- `manifests/machines/personal-laptop.toml` — appended `ghostty = true` and `jgrid-net = true` to existing `[features]` block
- `manifests/machines/work-laptop.toml` — appended `ghostty = true` to existing `[features]` block (jgrid-net intentionally absent)
- `configs/antidote/zsh_plugins.txt` — new plain-text bundle source, 7 lines, non-executable, no shebang, matches v1 antigen list verbatim

## Decisions Made

- Followed plan as specified. The plan's `<action>` blocks left no ambiguity: kebab-case flags, default-false, inline comments naming the gated file. No discretion calls beyond what the plan already pre-resolved (D-13 work-laptop jgrid-net stays default-false).

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria for the three tasks passed on the first verification run; no auto-fix rules triggered.

## Issues Encountered

None. `task manifest:validate` and `task manifest:test` both pass cleanly with the new keys; the resolver flows them through to `resolved.json` for every machine without schema changes.

## User Setup Required

None — pure manifest + data-file changes with no runtime side effects.

## Next Phase Readiness

- Plans 03-02 (zsh startup), 03-03 (aliases), 03-04 (functions+prompt) can now read `index .MANIFEST.features "ghostty"` and friends from `resolved.json`.
- Plan 03-02's `.zshrc` antidote block can reference `configs/antidote/zsh_plugins.txt` as the bundle source — file exists and is in the canonical D-01 order.
- Plan 03-05's symlink wiring should add `_:safe-link` entries for `configs/antidote/zsh_plugins.txt` -> `$XDG_CONFIG_HOME/antidote/zsh_plugins.txt` (the antidote-expected location).
- No blockers; no deferred items added.

## Self-Check

Verified after writing this summary:

- `manifests/defaults.toml` — FOUND
- `manifests/machines/personal-laptop.toml` — FOUND
- `manifests/machines/work-laptop.toml` — FOUND
- `configs/antidote/zsh_plugins.txt` — FOUND
- Commit `aa1dcdf` (Task 1) — FOUND in git log
- Commit `307a1ed` (Task 2) — FOUND in git log
- Commit `1c85bbb` (Task 3) — FOUND in git log

## Self-Check: PASSED

---
*Phase: 03-shell-layer-flat-content-port*
*Completed: 2026-05-14*
