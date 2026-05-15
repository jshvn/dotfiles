---
status: human_needed
phase: 05-packages-layer-brewfile-composition-verification
verified: 2026-05-15
goal: Per-purpose Brewfile bundles composed per-machine from the manifest, with idempotent install via `brew bundle check` AND post-install verification that declared binaries/casks are actually usable, plus a drift audit
requirements: [PKGS-01, PKGS-02, PKGS-03, PKGS-04, PKGS-05, VRFY-01, VRFY-02, VRFY-03, VRFY-04]
must_haves_total: 9
must_haves_verified: 6
human_verification_items: 3
notes:
  - Verifier agent stalled on the SSE stream at the VERIFICATION.md write step; its findings were complete and transcribed here verbatim.
  - Spot-checked all key filesystem and task-listing claims before persisting this report.
---

# Phase 05 Verification Report -- Packages Layer

## Verdict

**status: human_needed** -- automated checks all pass; three behavioral smoke tests need execution on a converged macOS machine before this phase can be marked `passed`.

## Requirement Coverage

| ID | Requirement | Plan Owners | Verified |
|----|-------------|-------------|----------|
| PKGS-01 | Purpose-named flat Brewfile bundles (no `packages/brew/`, no `Brewfile-<profile>.rb`) | 05-01, 05-06 | yes |
| PKGS-02 | Per-machine Brewfile composed from manifest into known cache path | 05-03, 05-04 | yes |
| PKGS-03 | Idempotency: `brew bundle check --file=<composed>` clean -> no-op | 05-03, 05-04 | yes (status block present); human smoke pending |
| PKGS-04 | Typed-bucket `extra_packages.{formulae,casks,mas}` sub-table | 05-02, 05-03, 05-06 | yes |
| PKGS-05 | Mac server declines GUI bundles; composed Brewfile has no casks | 05-01, 05-02, 05-03 | yes (server-1/server-2 bundles=["core"], composed Brewfile cask-free) |
| VRFY-01 | `packages:verify` parses `# verify:` per-line for formulas and casks | 05-04 | yes |
| VRFY-02 | `packages:audit` reports installed-but-undeclared drift (`--strict` non-zero) | 05-04 | yes |
| VRFY-03 | Verify failures exit non-zero with per-package report | 05-04 | yes (taskfile structure); human smoke pending |
| VRFY-04 | `task install` runs `packages:verify` as its final step | 05-05 | yes |

## Must-Haves vs Codebase

### Verified automatically (6 / 9)

1. **PKGS-01 (Bundle Files):** `packages/core.rb` (64 lines, 31 brew entries, all six required verify overrides present + `1password-cli # verify: op`, `antidote` present, `antigen` absent). `packages/gui.rb` (exactly 2 cask entries, each with `# verify: <App>`). `packages/README.md` rewritten from Phase 1 stub.
2. **PKGS-04 (Typed Buckets):** All 5 TOMLs migrated to `[packages.brew.extra_packages]` typed sub-table. `personal-laptop` has 27 casks + 2 MAS apps; `work-laptop` has 18 casks + 2 MAS apps. All cask entries declare `{name, verify}`, all MAS entries declare `{id, name}`. No legacy flat `extra_packages = [...]` form remains.
3. **PKGS-05 (Server Cask-Free):** `server-1.toml` and `server-2.toml` declare `bundles = ["core"]` with empty typed buckets. Composed Brewfile for `server-1` is 76 lines with zero cask/mas/formulae extras.
4. **PKGS-02 (Composition):** `install/compose-brewfile.zsh` (217 lines, executable, `set -euo pipefail` on line 22; LINT-04 compliant). Reads `resolved.json`, concatenates bundles in `packages.brew.bundles[]` order, appends typed extras, atomic `mktemp` + `mv` to `$XDG_CACHE_HOME/dotfiles/Brewfile`. `install/resolver.zsh` Pass 2 extended to dual-shape concat+dedupe across `{formulae, casks, mas}`. Composed Brewfile for `personal-laptop` is 137 lines with header banner (ISO-8601 UTC + Machine + Bundles + Extras counts).
5. **VRFY-01 / VRFY-02 (Verify + Audit Tasks):** `taskfiles/packages.yml` (385 lines) ships `install`, `compose`, `verify`, `audit`, `validate`. `verify` enumerates formula bins (`command -v`), cask `.app` bundles (`/Applications/<App>.app`), and MAS apps. `audit` reads `brew leaves` / `brew list --cask` / `mas list` and reports drift; `--strict` flag triggers non-zero exit.
6. **VRFY-04 (Install Chain):** Root `Taskfile.yml` `install` task chain ends `links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify -> success`. `packages:verify` is the final task-call before the success message.

### Pending human verification (3)

These behaviors require execution on a converged macOS machine and cannot be exercised in this static verification pass.

1. **PKGS-03 idempotency smoke** -- Run `task packages:install` twice on a converged machine. The second invocation must be a sub-second no-op driven by the `brew bundle check --file=<composed>` status block.
2. **VRFY-03 negative-path smoke** -- On a machine with declared casks installed, temporarily rename one application bundle (e.g. `/Applications/Slack.app` -> `/Applications/Slack.app.tmp`). Then run `task install`. Expected: the full `task install` pipeline hard-fails at `packages:verify` with a per-package cross report; rename back to restore.
3. **End-to-end `task install` smoke** -- From a clean working tree on `personal-laptop`, run `task install`. Expected: full pipeline executes through `packages:install` (composing the Brewfile, then `brew bundle install`) and `packages:verify` (every formula + cask + mas reports check) with exit 0.

## Cross-Plan Wiring

| Wiring | Source | Sink | Verified |
|--------|--------|------|----------|
| Resolved manifest -> composer | `$XDG_STATE_HOME/dotfiles/resolved.json` | `install/compose-brewfile.zsh` jq reads | yes |
| Bundle files -> composer | `packages/<name>.rb` | composer `cat` concatenation in `bundles[]` order | yes |
| Composed Brewfile -> installer | `$XDG_CACHE_HOME/dotfiles/Brewfile` | `taskfiles/packages.yml :: packages:install` | yes |
| Typed extras -> resolver | `[packages.brew.extra_packages]` in machine TOML | `install/resolver.zsh` Pass 2 per-subarray dedupe | yes |
| Packages namespace -> root | `taskfiles/packages.yml` | `Taskfile.yml` `includes.packages` (replaced legacy `brew:` include) | yes |
| Final-step verification | `task: packages:verify` | `Taskfile.yml :: install` cmds chain final entry | yes |

## Deviations Recorded by Subagents

1. **Plan 05-03 (Rule 1 auto-fix):** `jq` has no `\x27` escape. The plan's three canonical jq emit forms and the source-grep canary acceptance criteria expecting literal `\x27` substrings were unsatisfiable. Replaced with `--arg q "$SQ"` parameter injection where `SQ=$'\x27'` is zsh ANSI-C quoting. Underlying contract preserved: literal single-quote delimiters around every emit-line name; no `'\''` shell-escape nested form anywhere.
2. **Plan 05-04 (Rule 1 auto-fix):** `verify` + `audit` aggregator tasks needed structural `status: [false]` (in addition to the documentation marker `# lint-allow: cmds-without-status`) because `taskfiles/lint.yml`'s LINT-03a check exempts tasks by mechanical rules (`internal: true`, all-task-cmds, or hardcoded `lint.yml` self-exemption). Without the fix, two new LINT-03a failures would have been introduced. Pattern matches the root `Taskfile.yml` `install` task.

Both deviations are documented in their respective SUMMARY.md files and preserve the plans' behavioral contracts.

## Test Suite Results

- `task manifest:test` -- 11/11 fixtures pass, including the legacy flat-array fixture 06 (resolver dual-shape path holds).
- `task -t taskfiles/packages.yml --list` -- all 5 tasks reachable (`install`, `compose`, `verify`, `audit`, `validate`).
- `task --list` (root) -- `packages:*` namespace exposed; legacy `brew:*` namespace removed; exit 0.
- `task lint` -- 29 pre-existing LINT-03a failures in v1-era taskfiles (`profile.yml`, `profile-tasks.yml`, `common.yml`, `macos.yml`, `manifest.yml`, `brew.yml`, `claude.yml`, `shell.yml`). Zero new failures from Phase 5 artifacts. Identical baseline to Phase 4 close.

## Out-of-Scope Observations

- `install/Brewfile-personal.rb`, `install/Brewfile-work.rb`, `install/Brewfile-server.rb` remain as v1 leftover sources. CF-11 (Phase 8 cleanup) schedules their removal once Phase 5 is verified end-to-end on every machine.

## Human Verification Items (mirrored to 05-HUMAN-UAT.md)

The three behavioral smoke tests above persist as a HUMAN-UAT artifact and will surface in `/gsd-progress` and `/gsd-audit-uat` until the user marks them passed.
