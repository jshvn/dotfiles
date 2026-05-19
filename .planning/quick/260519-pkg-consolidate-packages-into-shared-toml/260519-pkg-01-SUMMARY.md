---
phase: 260519-pkg-consolidate-packages-into-shared-toml
plan: "01"
status: complete
subsystem: manifests
tags: [packages, manifests, resolver, composer, refactor]
dependency_graph:
  requires: []
  provides:
    - Single-location declaration model for all brew packages
    - manifests/shared/<bundle>.toml schema identical to per-machine extras
    - Resolver fold-in pass for shared bundles
  affects:
    - install/resolver.zsh
    - install/compose-brewfile.zsh
    - taskfiles/manifest.yml
    - taskfiles/packages.yml
tech_stack:
  added: []
  removed: ["packages/*.rb (Ruby DSL bundle layer)"]
  patterns:
    - "Typed-bucket TOML for both shared baselines and per-machine extras"
    - "Resolver merge order: defaults -> shared[bundles[]] -> machine; last-write-wins"
key_files:
  created:
    - manifests/shared/core.toml
    - manifests/shared/gui.toml
    - manifests/shared/README.md
  modified:
    - install/resolver.zsh
    - install/compose-brewfile.zsh
    - taskfiles/manifest.yml
    - taskfiles/packages.yml
    - CLAUDE.md
    - docs/MANIFEST.md
    - install/README.md
    - configs/tlrc/README.md
    - configs/trippy/README.md
    - configs/eza/README.md
    - configs/glow/README.md
    - configs/conda/README.md
  removed:
    - packages/core.rb
    - packages/gui.rb
    - packages/README.md
decisions:
  - "Kept the `bundles = [...]` array. Letting `atium` (headless) opt out of `gui` via this list is the simplest selection mechanism; replacing it with feature flags is a bigger schema change for no functional gain."
  - "Shared TOMLs use `[packages.brew] {formulae,casks,mas}` (no `extra_packages` wrapper) since they ARE the baseline, not extras."
  - "Merge order: defaults -> shared (in `bundles[]` order) -> machine. Machine wins on collision. Preserves existing `extra_packages` dedupe semantics."
  - "Validator hard-fails on unknown bundle names with an available-list hint. Catches typos at `task setup`/validate time rather than silently dropping every package in a typoed bundle at resolve time."
  - "Legacy flat-array extras path (fixture 06) left untouched. No machine in the repo uses it; shared-bundle merging only happens in the typed-bucket path."
metrics:
  duration: "~25 minutes"
  completed: "2026-05-19"
  commits: 6
  files_created: 4
  files_modified: 12
  files_removed: 3
---

# Quick Task 260519-pkg: Consolidate packages/*.rb into manifests/shared/*.toml

## Outcome

Brew package declarations now live in exactly one of two places: a shared
baseline at `manifests/shared/<name>.toml`, or a per-machine override at
`manifests/machines/<name>.toml [packages.brew.extra_packages]`. Both use
the same typed-bucket TOML schema. The `packages/` Ruby DSL layer is gone.

## What shipped

| Commit | Scope |
|--------|-------|
| `7befe5c` | feat(manifests): add `manifests/shared/` TOML bundle baseline |
| `1f0ccf8` | feat(resolver): merge `manifests/shared/<bundle>.toml` into typed extras |
| `c6e2d92` | refactor(composer): drop `.rb` concatenation; emit only typed buckets |
| `06601f5` | fix(tasks): track `shared/*.toml` in freshness checks |
| `e799a49` | refactor: remove `packages/` directory |
| `74ad424` | docs: retarget `packages/` references to `manifests/shared/` |

## Verification

- `task validate` -- success; all 31 formulae + 31 casks + 2 mas verified
  on `personal-laptop` via two-layer (`brew bundle check` + `brew info`
  artifact probe) path.
- `task test` -- 11/11 fixtures pass (positive + negative). Hook smoke
  tests pass.
- `task lint` -- LINT-04, LINT-07, LINT-08 clean. Pre-existing LINT-05
  portability warnings unchanged (4, all macOS-specific calls).
- Composed Brewfile entry counts unchanged vs. pre-refactor:
  31 formulae + 31 casks + 2 mas on `personal-laptop`. `atium` correctly
  excludes GUI casks.
- Negative case: a machine TOML with `bundles = ["core", "nonexistent"]`
  is rejected by `--validate-only` with the message:
  `packages.brew.bundles entry 'nonexistent' has no shared file at <path> (available: core|gui)`.

## Future work (not in scope)

- Consider replacing `bundles = [...]` with feature flags
  (`features.shared-gui = true`) for uniformity with the existing
  feature-flag model. Deferred -- bigger schema change for no functional
  gain right now.
- Update `.planning/PROJECT.md` and `.planning/research/ARCHITECTURE.md`
  to reflect the post-refactor layout when the next milestone opens
  (left as historical record for now).
