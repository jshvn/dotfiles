---
phase: 260519-pkg-consolidate-packages-into-shared-toml
plan: "01"
subsystem: manifests
tags: [packages, manifests, resolver, composer, refactor]
---

# Quick Task: Consolidate packages/*.rb into manifests/shared/*.toml

## Why

The pre-refactor model split brew package declarations across two locations:

- `packages/core.rb` and `packages/gui.rb` -- shared baselines (Ruby DSL,
  concatenated verbatim by the composer)
- `manifests/machines/<name>.toml [packages.brew.extra_packages]` --
  per-machine extras (typed-bucket TOML, merged by the resolver)

Operators had to remember which location a new package belonged in. The
heuristic ("needed on >=2 machines with zero variation -> bundle; otherwise
-> machine extras") was correct but not obvious from the codebase.

## What

Replace the `packages/*.rb` Ruby DSL bundles with `manifests/shared/*.toml`
typed-bucket TOML files. Single schema for all brew declarations
(shared or per-machine). The resolver merges shared-bundle buckets into
`resolved.json packages.brew.extra_packages` so the composer only ever
reads typed extras -- no `.rb` concatenation path remains.

Bundles are still selected per-machine via `packages.brew.bundles = [...]`
(unchanged). The string in that array now resolves to
`manifests/shared/<name>.toml` instead of `packages/<name>.rb`.

## Steps (one commit each)

1. Add `manifests/shared/{core,gui}.toml` + `README.md`.
2. Extend `install/resolver.zsh` with a bundle-merge pass; validate each
   bundle name maps to an existing shared TOML.
3. Simplify `install/compose-brewfile.zsh` to emit only typed buckets.
4. Update freshness checks in `taskfiles/{manifest,packages}.yml`.
5. Delete `packages/`.
6. Update docs (`CLAUDE.md`, `docs/MANIFEST.md`, `install/README.md`,
   `configs/{tlrc,trippy,eza,glow,conda}/README.md`).
7. Verify via `task validate && task test && task lint` + Brewfile parity.

## Acceptance

- `task validate` succeeds; `task test` 11/11 fixtures pass; `task lint`
  clean (LINT-04/07/08; pre-existing LINT-05 portability warnings only).
- Composed Brewfile entry counts on `personal-laptop` match pre-refactor:
  31 formulae + 31 casks + 2 mas.
- `atium` (core-only) shows no GUI bleed-in.
- A bundle name without a shared TOML hard-fails validation with an
  available-list hint.

## Non-goals

- Eliminating the `bundles = [...]` array (kept; lets `atium` skip `gui`).
- Replacing bundle selection with feature flags (deferred; bigger schema
  change).
- Updating `.planning/PROJECT.md` and `.planning/research/ARCHITECTURE.md`
  (historical planning records; left as-is).
