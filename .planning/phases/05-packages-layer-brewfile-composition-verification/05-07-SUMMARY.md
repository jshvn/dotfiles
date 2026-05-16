---
phase: 05-packages-layer-brewfile-composition-verification
plan: "07"
subsystem: packages
tags: [packages, schema, manifest, brewfile, docs, verify-pivot, gap-closure]
dependency_graph:
  requires: [05-06-SUMMARY.md]
  provides: [verify-stripped-bundles, verify-stripped-manifests, verify-model-docs]
  affects: [install/compose-brewfile.zsh, packages/core.rb, packages/gui.rb, manifests/machines, docs/MANIFEST.md, packages/README.md]
tech_stack:
  added: []
  patterns: [brew-info-driven-verify, name-only-cask-objects]
key_files:
  created: []
  modified:
    - packages/core.rb
    - packages/gui.rb
    - manifests/defaults.toml
    - manifests/machines/personal-laptop.toml
    - manifests/machines/work-laptop.toml
    - install/resolver.zsh
    - install/compose-brewfile.zsh
    - docs/MANIFEST.md
    - packages/README.md
decisions:
  - "Gap-2 pivot fully realized: per-line # verify: comments and per-cask verify= fields removed from all source artifacts"
  - "D-04 (cask verify MANDATORY) superseded by Gap-2 closure 2026-05-15; cask verify is now optional/ignored"
  - "D-05 (formula verify override via # verify: comment) partially preserved in composer dead-code path but no bundle lines carry verify annotations"
  - "D-06 (MAS name doubles as verify target) preserved; mas entries retain {id, name} shape unchanged"
metrics:
  duration: "~45 minutes"
  completed: "2026-05-16"
  tasks: 2
  files: 9
---

# Phase 5 Plan 7: Verify-pivot schema cleanup and docs Summary

Strip the per-line `# verify:` comment convention and the per-cask `{ name, verify }` schema
field from every source artifact, completing the brew-info-driven verify pivot decided during
Phase 5 UAT (Gap 2 closure, 2026-05-15).

## Tasks Completed

| Task | Commit | Files |
|------|--------|-------|
| 1: Strip verify comments/fields from bundles, manifests, resolver, composer | 6591dfe | packages/core.rb, packages/gui.rb, manifests/defaults.toml, manifests/machines/personal-laptop.toml, manifests/machines/work-laptop.toml, install/resolver.zsh, install/compose-brewfile.zsh |
| 2: Update docs/MANIFEST.md + packages/README.md for verify-model pivot | 3efc313 | docs/MANIFEST.md, packages/README.md |

## File Delta Summary

| File | Lines removed | Lines added | Nature of change |
|------|--------------|------------|-----------------|
| `packages/core.rb` | ~14 | ~11 | Stripped 6 formula verify comments + 1 cask verify comment; rewrote header |
| `packages/gui.rb` | ~10 | ~8 | Stripped 2 cask verify comments; rewrote header |
| `manifests/machines/personal-laptop.toml` | 27 | 27 | Stripped `verify = "..."` from all 27 cask entries |
| `manifests/machines/work-laptop.toml` | 18 | 18 | Stripped `verify = "..."` from all 18 cask entries |
| `manifests/defaults.toml` | 3 | 5 | Updated cask bucket doc comment (verify-optional wording) |
| `install/resolver.zsh` | 1 | 1 | Updated cask shape comment (verify optional post-Gap-2 pivot) |
| `install/compose-brewfile.zsh` | 3 | 4 | Updated header comment + stripped verify concatenation from cask emit |
| `docs/MANIFEST.md` | ~45 | ~90 | New ## Verify model section; updated optional-fields cask row; updated fixture 06 |
| `packages/README.md` | ~50 | ~70 | Rewrote ## Verify rules; collapsed verify-comment-override bullet |

Total: 9 files modified (2 bundles, 2 machine manifests, 1 defaults manifest, 2 install scripts, 2 docs).

## Verification Results

- `task manifest:test`: 11/11 fixtures pass (resolver runtime unchanged; fixture 06 tests
  the legacy flat-array path and was not affected by typed-bucket changes)
- `jq '[.packages.brew.extra_packages.casks[] | select(has("verify"))] | length' resolved.json`
  returns `0` for personal-laptop, work-laptop, and server machines
- `task packages:compose` produces `$XDG_CACHE_HOME/dotfiles/Brewfile` where every
  `^cask '` line carries NO `# verify:` suffix (verified via ggrep count = 0)
- `task packages:install` remains idempotent (status block passes `brew bundle check --no-upgrade`
  on re-run; cask name values are identical, only per-line metadata changed)

## Cask Line Counts (Composed Brewfile, personal-laptop)

| Source | Cask count | Before | After |
|--------|-----------|--------|-------|
| core.rb | 1 | `cask '1password-cli'       # verify: bin:op` | `cask '1password-cli'` |
| gui.rb | 2 | had `# verify: 1Password`, `# verify: Ghostty` | bare lines |
| personal-laptop extras | 27 | had `# verify: ...` suffix | bare lines |
| **Total** | **30** | 30 cask lines with verify suffix | 30 cask lines, 0 with suffix |

## Decision References

- **D-04 (cask verify MANDATORY) -- SUPERSEDED** by Gap-2 closure 2026-05-15. The cask
  `verify` field is now optional and ignored by both the resolver dedupe and the composer.
  The MANDATORY claim in defaults.toml comments and resolver.zsh function header has been
  removed.

- **D-05 (formula verify via # verify: comment) -- PARTIALLY PRESERVED** as dead-code-but-
  schema in the composer's formula emit branch (object form: `"brew " + $q + .name + $q + " # verify: " + .verify`).
  No machine TOMLs currently carry object-form formulae (`formulae = []` everywhere), so this
  branch is unreachable in practice. The bundle files (core.rb) no longer carry `# verify:`
  comments per the Gap-2 pivot; the compiler dead-code path is preserved for schema defense-
  in-depth if a future formula extras object is added.

- **D-06 (MAS name doubles as verify target) -- PRESERVED** unchanged. The `{ id, name }`
  shape in `extra_packages.mas` retains its `name` field which doubles as the
  `/Applications/<name>.app` verify target. Apple App Store has no `brew info` equivalent,
  so per-entry verify metadata is still authored here.

- **gap-1 commit 896e09e** (1password-cli as cask, `bin:op` verify prefix) -- the cask
  classification (1password-cli as cask, not formula) is preserved. The `bin:op` verify
  annotation introduced in that commit is retired by this plan: the `# verify: bin:op` suffix
  is stripped from core.rb; the `bin:` convention paragraph is removed from packages/README.md.

## Plan 05-08 Readiness

This plan produces the inputs Plan 05-08 (Wave 2) needs:
- `$XDG_CACHE_HOME/dotfiles/Brewfile` with bare cask lines (no `# verify:` suffix) -- the
  verify task body can consume these lines without needing to strip annotations first
- `$XDG_STATE_HOME/dotfiles/resolved.json` with `{ "name": "<cask>" }` cask objects (no
  `verify` field) -- the verify task can iterate `.packages.brew.extra_packages.casks[]`
  and pass each `.name` to `brew info` without needing to handle a mixed schema

## Deviations from Plan

None. Plan executed exactly as written. The two files expected to be unchanged (server-1.toml
and server-2.toml) were confirmed byte-identical (no verify references existed in either).
The fixture 06 machine.toml and expected.json were NOT modified (as specified -- fixture 06
tests the legacy flat-array path which is unaffected by typed-bucket shape changes).

## Known Stubs

None. This plan makes no behavior change -- it strips stale metadata from data files and
updates docs. The verify logic itself (Plan 05-08) is the consumer of these changes.

## Self-Check: PASSED

Files verified present:
- packages/core.rb: FOUND
- packages/gui.rb: FOUND
- manifests/machines/personal-laptop.toml: FOUND (27 cask entries, no verify field)
- manifests/machines/work-laptop.toml: FOUND (18 cask entries, no verify field)
- install/compose-brewfile.zsh: FOUND (cask emit: no # verify: suffix)
- docs/MANIFEST.md: FOUND (## Verify model section at line 349)
- packages/README.md: FOUND (## Verify rules section rewritten)

Commits verified present:
- 6591dfe: FOUND (feat(05-07): strip per-line verify comments and per-cask verify fields)
- 3efc313: FOUND (docs(05-07): add Verify model section; rewrite verify rules for brew-info pivot)
