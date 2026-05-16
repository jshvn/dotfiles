---
status: human_needed
phase: 05-packages-layer-brewfile-composition-verification
verified: 2026-05-15T19:00:00Z
re_verified: 2026-05-16T02:30:00Z
goal: Per-purpose Brewfile bundles composed per-machine from the manifest, with idempotent install via `brew bundle check` AND post-install verification that declared binaries/casks are actually usable, plus a drift audit
requirements: [PKGS-01, PKGS-02, PKGS-03, PKGS-04, PKGS-05, VRFY-01, VRFY-02, VRFY-03, VRFY-04, DOCS-02]
must_haves_total: 10
must_haves_verified: 10
human_verification_items: 2
human_verification_passed: 1
gaps_open: 0
gaps_closed: 3
re_verification:
  previous_status: gaps_found
  previous_score: 7/9
  gaps_closed:
    - "Gap 2: 7 verify-comment correctness issues (pivot to brew-info two-layer model via plans 05-07 + 05-08)"
    - "Gap 3: packages:verify output invisible in non-TTY contexts (silent:false task-level override added)"
    - "Gap 1: 1password-cli misclassified as formula (moved to cask; originally closed in commit 896e09e)"
  gaps_remaining: []
  regressions: []
notes:
  - "Post-pivot semantics apply to VRFY-01 / VRFY-02: brew-info two-layer model replaces per-line # verify: comments (design pivot decided 2026-05-15; ratified in plans 05-07 + 05-08)."
  - "task packages:verify exits 0 with 'all declared packages verified (Layer 1 + Layer 2 + MAS)' on personal-laptop."
  - "Human Test 1 (PKGS-03 idempotency) passed 2026-05-15 (commit 896e09e fix)."
  - "Human Test 2 (VRFY-03 negative-path smoke) still requires user action but is structurally unblocked."
  - "Human Test 3 (task install end-to-end smoke) blocked by cutover-ack gate by design (D-09 / Phase 2 protection); not a gap."
  - "REQUIREMENTS.md PKGS-04 wording still says '{name, verify}' for cask objects; actual implementation uses name-only objects per Gap 2 pivot; behavioral contract met under post-pivot semantics."
  - "work-laptop.toml Things entry still says 'Things' (not 'Things3') -- the e1bd6f9 fix was only confirmed on personal-laptop; work-laptop has not been validated. Not a phase 5 gap (work-laptop validation deferred to cutover)."
human_verification:
  - test: "VRFY-03 negative-path smoke"
    expected: "mv /Applications/Slack.app /Applications/Slack.app.tmp; task packages:verify exits non-zero with a cross row identifying 'Slack.app NOT FOUND'; restore with mv back"
    why_human: "Requires destructive fs action on a real machine with Slack.app installed"
  - test: "End-to-end task install smoke (Test 3)"
    expected: "task install runs the full pipeline on personal-laptop and exits 0 with the success banner"
    why_human: "Blocked by cutover-ack gate (intentional Phase 2 protection D-09); user must ack the gate to allow full pipeline run"
---

# Phase 05 Verification Report -- Packages Layer (Re-verification after gap-closure waves 1 + 2)

**Phase Goal:** Per-purpose Brewfile bundles composed per-machine from the manifest, with idempotent install via `brew bundle check` AND post-install verification that declared binaries/casks are actually usable, plus a drift audit.
**Verified:** 2026-05-16 (re-verification after plans 05-07 + 05-08)
**Status:** human_needed
**Re-verification:** Yes -- after gap-closure waves 1 (plan 05-07: schema/docs cleanup) and 2 (plan 05-08: brew-info verify rewrite + silent:false fix).

## Design Pivot Notice

The original VRFY-01/VRFY-02 specification referenced per-line `# verify:` comments and per-cask `verify` fields.
After UAT Gap 2 was surfaced (2026-05-15), a full design pivot was accepted: the brew-info two-layer model
(`brew bundle check` + bulk `brew info --installed --json=v2` artifact probe) replaces all per-line metadata.
Plans 05-07 and 05-08 implement this pivot. All VRFY-01/VRFY-02/VRFY-03/VRFY-04 truths below are evaluated
against the post-pivot semantics.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Per-purpose flat Brewfile bundles exist in `packages/` | VERIFIED | `packages/core.rb` (30 brew + 1 cask), `packages/gui.rb` (2 casks); flat dir, no `packages/brew/` subdir |
| 2 | Per-machine Brewfile composed from manifest into cache | VERIFIED | `install/compose-brewfile.zsh` (220 lines); produces `$XDG_CACHE_HOME/dotfiles/Brewfile`; 30 cask lines, 0 with `# verify:` suffix |
| 3 | Idempotent install via `brew bundle check` | VERIFIED | `packages:install` status block uses `brew bundle check --no-upgrade`; Human Test 1 passed 2026-05-15 |
| 4 | Typed-bucket `extra_packages.{formulae,casks,mas}` | VERIFIED | All 5 manifests use typed sub-table; personal-laptop: 27 casks (name-only), 2 MAS; work-laptop: 18 casks, 2 MAS; servers: empty |
| 5 | Mac server declines GUI bundles | VERIFIED | server-1/server-2 declare `bundles = ["core"]`; empty `casks = []`; resolved.json confirms cask-free |
| 6 | `task packages:verify` confirms formula install state | VERIFIED | Layer 2 probes `.linked_keg` (not `installed[0].linked_keg`); keg-only formulae handled; exits 0 on personal-laptop |
| 7 | `task packages:verify` confirms cask/MAS artifact presence | VERIFIED | Layer 2 walks `.artifacts[].app[0]` from `brew info --installed --json=v2`; binary casks use `.artifacts[].binary` path; MAS uses `mas list` + `/Applications/<name>.app` (D-06) |
| 8 | `packages:audit` reports drift | VERIFIED | `packages:audit` task present in `taskfiles/packages.yml` (385 lines); `--strict` flag exits non-zero |
| 9 | Verify failures exit non-zero with per-package report | VERIFIED (structural) | Hard-fail with enumerate-all per D-07/D-10; `silent: false` task-level override (Gap 3 closure) ensures output visible; negative-path smoke pending Human Test 2 |
| 10 | `task install` ends with `packages:verify` | VERIFIED | Root `Taskfile.yml install` cmds: chain ends `packages:verify -> success "install complete"`; VRFY-04 confirmed |

**Score:** 10/10 truths verified (2 require human confirmation for negative-path behavior)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `packages/core.rb` | Server-safe CLI baseline | VERIFIED | 30 brew formulas + `cask '1password-cli'`; 0 `# verify:` suffixes; `set -euo pipefail` N/A (Ruby file) |
| `packages/gui.rb` | Laptop GUI baseline | VERIFIED | `cask '1password'`, `cask 'ghostty'`; 0 `# verify:` suffixes |
| `packages/README.md` | Directory README (DOCS-02) | VERIFIED | 121 lines; covers purpose, key files, adding patterns, verify rules (brew-info model), composed Brewfile cache, references |
| `taskfiles/packages.yml` | Package management tasks | VERIFIED | 385 lines; 5 tasks: install, compose, verify, audit, validate; `silent: false` on verify |
| `install/compose-brewfile.zsh` | Brewfile composer | VERIFIED | 220 lines; `set -euo pipefail`; atomic write via mktemp+mv; cask emit is bare (no `# verify:` suffix) |
| `install/resolver.zsh` | Typed-bucket resolution | VERIFIED | Pass 2 handles `{formulae,casks,mas}` sub-arrays; cask dedupe keys on `.name` only; `.verify` optional per Gap 2 pivot |
| `docs/MANIFEST.md` | Schema reference + Verify model | VERIFIED | `## Verify model` section at line 349 (between Merge Semantics and Adding a New Machine); describes Layer 1 + Layer 2 + MAS path; fixture 06 updated to name-only cask objects; no "MANDATORY per cask" claim |
| `manifests/machines/personal-laptop.toml` | 27 casks, 2 MAS, name-only | VERIFIED | 27 cask objects, 0 with `verify` field; MAS: `Things3` (not `Things`); resolved.json confirms shape |
| `manifests/machines/work-laptop.toml` | 18 casks, 2 MAS, name-only | VERIFIED | 18 cask objects, 0 with `verify` field; MAS: `Magnet` + `Things` (not yet confirmed on work-laptop) |
| `manifests/machines/server-1.toml` | Cask-free | VERIFIED | `bundles = ["core"]`; `casks = []` |
| `manifests/machines/server-2.toml` | Cask-free | VERIFIED | `bundles = ["core"]`; `casks = []` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Manifest TOMLs `[packages.brew.extra_packages.casks]` | `install/resolver.zsh` Pass 2 | `yq -o=json` + `jq group_by(.name)` | VERIFIED | Cask dedupe keys on `.name` only; `.verify` optional and ignored |
| `install/resolver.zsh` `resolved.json` | `install/compose-brewfile.zsh` cask emit | `.packages.brew.extra_packages.casks[]` jq filter | VERIFIED | Line 148: `'.[] | "cask " + $q + .name + $q'` -- bare emit confirmed |
| `$XDG_CACHE_HOME/dotfiles/Brewfile` | `taskfiles/packages.yml :: packages:install` | `brew bundle install --file={{.COMPOSED_BREWFILE}}` | VERIFIED | Composed file present; `brew bundle check` clean on personal-laptop |
| `taskfiles/packages.yml :: verify` Layer 1 | `brew bundle check --no-upgrade` | shell-out in cmds block | VERIFIED | Reuses exact same flags as install status block (D-09 parity) |
| `taskfiles/packages.yml :: verify` Layer 2 | `brew info --installed --json=v2` | single bulk call + jq `.casks[].artifacts[]` walk | VERIFIED | 1 actual invocation; comment-only second reference; exits 0 on personal-laptop |
| `taskfiles/packages.yml :: verify` MAS layer | `mas list` + `/Applications/<name>.app` | shell-out + awk | VERIFIED | D-06 preserved; Things3 fix applied to personal-laptop |
| `task install` chain final step | `packages:verify` | `cmds: - task: packages:verify` in root `Taskfile.yml` | VERIFIED | VRFY-04 + D-10; final step before `success "install complete"` banner |
| `docs/MANIFEST.md ## Verify model` | `packages/README.md ## Verify rules` | shared two-layer narrative | VERIFIED | Both describe Layer 1 + Layer 2; README points at MANIFEST.md as canonical ref |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `taskfiles/packages.yml :: verify` | `brew_info_json` | `brew info --installed --json=v2` (local metadata, no network) | Yes | FLOWING |
| `taskfiles/packages.yml :: verify` | Cask artifact paths | `.casks[] | select(.token == $t) | .artifacts[]` from `brew_info_json` | Yes | FLOWING |
| `taskfiles/packages.yml :: verify` | Formula `linked_keg` | `.formulae[] | select(.name == $n) | .linked_keg` from `brew_info_json` | Yes | FLOWING |
| `taskfiles/packages.yml :: verify` | MAS installed ids | `mas list | awk '{print $1}'` | Yes | FLOWING |
| `install/compose-brewfile.zsh` | Cask list | `resolved.json .packages.brew.extra_packages.casks[]` | Yes | FLOWING |
| `install/compose-brewfile.zsh` | Bundle files | `packages/*.rb` read via `cat` concatenation | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `task manifest:test` 11/11 fixtures | `task manifest:test` | 11 total, 11 passed, 0 failed | PASS |
| `task packages:verify` exits 0 | `task packages:verify` | `all declared packages verified (Layer 1 + Layer 2 + MAS)` | PASS |
| Composed Brewfile has 0 `# verify:` cask suffixes | `ggrep -c "# verify:" packages/core.rb packages/gui.rb` | `packages/core.rb:0 packages/gui.rb:0` | PASS |
| Resolved.json cask objects have 0 `verify` fields | `jq '[.packages.brew.extra_packages.casks[] | select(has("verify"))] | length' resolved.json` | `0` (personal-laptop) | PASS |
| `silent: false` on verify task | `yq -r '.tasks.verify.silent' taskfiles/packages.yml` | `false` | PASS |
| 4 preconditions on verify task | `yq '.tasks.verify.preconditions \| length' taskfiles/packages.yml` | `4` | PASS |
| Single brew-info call (not per-package fan-out) | ggrep non-comment lines for `brew info --installed` | 1 code invocation | PASS |
| `linked_keg` field used (not `installed[0].linked_keg`) | `ggrep installed\[0\].linked_keg taskfiles/packages.yml` | Only in comment (explaining NOT to use it) | PASS |
| No cache file introduced | `! ggrep brew-artifacts.json taskfiles/packages.yml` | No cache file path | PASS |
| `task -t taskfiles/packages.yml --list` | List available tasks | 5 tasks: install, compose, verify, audit, validate | PASS |
| `task lint` -- no new failures from Phase 5 artifacts | `task lint 2>&1 \| ggrep "packages.yml"` | `yaml-parse: PASS`, `LINT-02: PASS`; 29 pre-existing v1-era failures unchanged | PASS |
| `packages:verify` is final step in `task install` | `ggrep -A30 "^  install:" Taskfile.yml` | `task: packages:verify` before `success "install complete"` | PASS |

### Requirements Coverage

| Requirement | Plan Owners | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| PKGS-01 | 05-01, 05-06 | Flat per-purpose bundles in `packages/<purpose>.rb` | SATISFIED | `packages/core.rb` + `packages/gui.rb` in flat dir; no `packages/brew/` subdir |
| PKGS-02 | 05-03, 05-04 | Manifest-driven Brewfile composition | SATISFIED | `install/compose-brewfile.zsh` reads `resolved.json`; outputs to `$XDG_CACHE_HOME/dotfiles/Brewfile` |
| PKGS-03 | 05-03, 05-04 | `status:` block with `brew bundle check` | SATISFIED | `packages:install` status block confirmed; Human Test 1 passed 2026-05-15 |
| PKGS-04 | 05-02, 05-03, 05-06 | Typed sub-table `extra_packages.{formulae,casks,mas}` | SATISFIED (post-pivot) | All 5 manifests migrated; cask objects now `{name}` only per Gap 2 pivot (verify field optional/ignored) |
| PKGS-05 | 05-01, 05-02, 05-03 | Server machines decline GUI bundles | SATISFIED | server-1/server-2 `bundles = ["core"]`; empty `casks = []` in resolved.json |
| VRFY-01 | 05-04, 05-08 | `packages:verify` confirms formula install state | SATISFIED (post-pivot) | Layer 2: `.linked_keg` probe via `brew info --installed --json=v2`; replaces `command -v <bin>` per-line model |
| VRFY-02 | 05-04, 05-08 | `packages:verify` confirms cask/MAS artifact presence | SATISFIED (post-pivot) | Layer 2: `.artifacts[].app[0]` for app-bundle casks; `.artifacts[].binary` for binary-only casks; `/Applications/<name>.app` for MAS (D-06) |
| VRFY-03 | 05-04, 05-08 | Negative-path failures exit non-zero with per-package report | SATISFIED (structural) | Hard-fail (D-10); enumerate-all (D-07); `silent: false` (Gap 3 closure); negative-path smoke pending Human Test 2 |
| VRFY-04 | 05-05 | `task install` ends with `packages:verify` | SATISFIED | Root `Taskfile.yml install` cmds chain: `packages:verify -> success banner` |
| DOCS-02 | 05-01, 05-07 | `packages/README.md` directory README | SATISFIED | 121 lines; covers purpose, key files, adding patterns, verify rules (brew-info model), references |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | All modified files pass no-emoji, no-AI-attribution, no-TBD/FIXME/XXX checks |

### Human Verification Required

#### 1. VRFY-03 negative-path smoke (Test 2)

**Test:** On `personal-laptop` with `Slack.app` installed:
1. `mv /Applications/Slack.app /Applications/Slack.app.tmp`
2. `task packages:verify`
3. Expect: non-zero exit with a cross row identifying `Slack.app NOT FOUND`
4. `mv /Applications/Slack.app.tmp /Applications/Slack.app` to restore

**Expected:** The brew-info Layer 2 path returns `Slack.app` as the actual artifact target via `.artifacts[].app[0]`; `test -d /Applications/Slack.app` fails; cross row printed; verify exits non-zero.

**Why human:** Requires a destructive filesystem action on a real machine with the app installed. Cannot be exercised in a static verification pass.

#### 2. End-to-end `task install` smoke (Test 3)

**Test:** On `personal-laptop` with the current `josh/dotfiles-v2-refactor` branch, run `task install`.

**Expected:** Full pipeline `links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify -> success "install complete"` completes with exit 0.

**Why human:** Blocked by the cutover-ack gate (Phase 2 protection D-09 / `install/cutover-gate.zsh`). This is intentional design -- `task install` requires the user to explicitly acknowledge the cutover gate on this machine before allowing the full pipeline to run. Not a Phase 5 gap.

### Gaps Summary

No gaps remain. All 3 original gaps (Gap 1: 1password-cli misclassification, Gap 2: 7 verify-comment correctness issues, Gap 3: packages:verify output invisible) are closed by commits 896e09e, 6591dfe + 3efc313, and e46b053 + e1bd6f9 respectively.

The `task packages:verify` probe runs clean on personal-laptop (`all declared packages verified (Layer 1 + Layer 2 + MAS)`; exit 0). The two remaining human verification items are behavioral confirmation of failure modes (Test 2) and a full-pipeline smoke (Test 3) that requires user interaction with the cutover gate.

---

_Verified: 2026-05-15_
_Re-verified: 2026-05-16_
_Verifier: Claude (gsd-verifier)_
