---
phase: 05-packages-layer-brewfile-composition-verification
plan: 01
subsystem: packages
tags: [packages, brewfile, bundles, dotfiles, verify-comments, homebrew]

requires:
  - phase: 03-shell-layer-flat-content-port
    provides: antidote-replaces-antigen (drives core.rb plugin-manager line)
  - phase: 04-identity-layer-git-ssh-per-machine
    provides: cloudflared-on-core dependency (personal SSH ProxyCommand)
provides:
  - "packages/core.rb (server-safe CLI baseline, 31 brew lines)"
  - "packages/gui.rb (laptop GUI baseline, 2 cask lines with mandatory verify)"
  - "packages/README.md (DOCS-02 anchor; minimal-bundles philosophy + verify rules + typed-bucket extras + composed-cache path)"
  - "Verify-comment convention shipped as authored content for Plan 04 parser to enforce"
affects:
  - 05-02-PLAN (manifest TOML migrations; reads bundle names + verify shape)
  - 05-03-PLAN (composer; concatenates packages/*.rb verbatim)
  - 05-04-PLAN (packages:verify; parses # verify: comments)
  - 05-05-PLAN (LINT-09; enforces mandatory cask verify)

tech-stack:
  added: []  # static-content authoring only; no new tools introduced
  patterns:
    - "Flat packages/<purpose>.rb layout (D-01)"
    - "Minimal bundles, heavy per-machine extras (D-02)"
    - "Mandatory cask # verify: <App> comment shape (D-04)"
    - "Formula # verify: <bin> override shape (D-05)"
    - "Uniform formula-line verify for CLI-only Homebrew casks (1password-cli)"

key-files:
  created:
    - "packages/core.rb (64 lines; 31 brew entries)"
    - "packages/gui.rb (30 lines; 2 cask entries with verify)"
  modified:
    - "packages/README.md (replaced 11-line Phase 1 stub with 103-line DOCS-02 anchor)"

key-decisions:
  - "1password-cli ships in core.rb as `brew '1password-cli' # verify: op` (formula-style) for uniform verify -- the Homebrew cask has no .app bundle (Claude's Discretion call from 05-CONTEXT.md)"
  - "Single-space `# verify: <token>` shape used uniformly (single space after `#`, single space after `:`) so the Plan 04 anchored-regex parser matches verbatim"
  - "core.rb header comment avoids the literal token `antigen` so the `! grep -q antigen` acceptance check passes; the file is authoritative content, not commentary"
  - "gui.rb header comment refers to the 1Password command-line tool descriptively rather than by package name so the `! grep -q 1password-cli` acceptance check passes"

patterns-established:
  - "Header comment block at the top of every packages/*.rb (CLAUDE.md file-header rule): purpose, side effects, verify rules legend, conventions, surgery vs v1"
  - "Single-quote string-literal form for brew/cask DSL lines (matches CONTEXT skeleton; consistent with the Plan 04 verify-parser regex)"
  - "Bundle file authorship style: bare formula lines for default-verify entries, suffixed `# verify: <bin>` for renamed-binary / multi-binary overrides"
  - "Cask line carries mandatory `# verify: <App>` -- no derivation, no defaults (D-04)"

requirements-completed: [PKGS-01, PKGS-05]

duration: ~30min
completed: 2026-05-15
---

# Phase 05 Plan 01: Bundle-File Authoring Summary

**Two minimal Brewfile bundles (core.rb server-safe CLI baseline + gui.rb laptop GUI baseline) at the flat `packages/` layout, plus a DOCS-02 README replacing the Phase 1 stub; ships the `# verify: <token>` comment convention as authored content for the downstream Plan 04 parser.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-05-15T17:53:00Z (approx; worktree spawn)
- **Completed:** 2026-05-15T18:22:13Z
- **Tasks:** 3 / 3 complete
- **Files created:** 2 (`packages/core.rb`, `packages/gui.rb`)
- **Files modified:** 1 (`packages/README.md` -- stub replaced)

## Accomplishments

- **packages/core.rb (31 brew lines, server-safe CLI baseline).** Ports v1 `install/Brewfile.rb` to the flat `packages/<purpose>.rb` layout per D-01. Drops the v1 zsh plugin manager (Phase 3 swapped to antidote); adds `brew 'antidote'`. Adds `brew '1password-cli' # verify: op` formula-style for uniform verify. Adds `# verify: <bin>` overrides on six non-conformer formulas (git-delta -> delta, grep -> ggrep, openssh -> ssh, trippy -> trip, bottom -> btm, coreutils -> gsha256sum) per D-05. Includes Phase 4's cloudflared dependency for personal SSH `ProxyCommand`.
- **packages/gui.rb (2 cask lines, laptop GUI baseline).** Minimum set: `cask '1password' # verify: 1Password` and `cask 'ghostty' # verify: Ghostty`. Both lines carry the MANDATORY `# verify: <App>` comment per D-04. No `cask_args` directive (composer concatenates verbatim; brew bundle's default appdir = `/Applications`). No `1password-cli` here -- it ships from core.rb formula-style per the Claude's Discretion call.
- **packages/README.md (103 lines, DOCS-02 anchor).** Replaces the 11-line Phase 1 stub. Mirrors `shell/README.md` shape: H1 + one-paragraph purpose summary + `## Key files` + `## Adding a pattern` (three bullets: bundle / per-machine extras / verify-comment override) + `## Verify rules` + `## Composed Brewfile cache` + `## References`. Documents D-02 minimal-bundles philosophy, D-03 typed-bucket schema, D-04/D-05 verify conventions, D-08 cache path, and links to `../docs/MANIFEST.md`, `../CLAUDE.md`, `../.planning/REQUIREMENTS.md`.

## Verify-Comment Mapping Shipped

**Formula `# verify: <bin>` overrides in core.rb (6 entries):**

| Formula      | Verify Bin       | Reason                                                  |
|--------------|------------------|---------------------------------------------------------|
| git-delta    | delta            | binary name differs from formula name                   |
| grep         | ggrep            | GNU grep installs under `g`-prefix (vs system grep)     |
| openssh      | ssh              | multi-binary formula; ssh is the representative bin     |
| trippy       | trip             | binary renamed from formula name                        |
| bottom       | btm              | binary renamed from formula name                        |
| coreutils    | gsha256sum       | multi-binary formula; gsha256sum is the representative  |

**Additional formula-style verify (Claude's Discretion call):**

| Formula        | Verify Bin | Reason                                                                              |
|----------------|------------|-------------------------------------------------------------------------------------|
| 1password-cli  | op         | Homebrew cask has no .app bundle; formula-style entry keeps verify rule uniform     |

**Cask `# verify: <App>` mandatory comments in gui.rb (2 entries):**

| Cask        | Verify App  | Notes                                                  |
|-------------|-------------|--------------------------------------------------------|
| 1password   | 1Password   | App name matches the canonical Mac App display name    |
| ghostty     | Ghostty     | App name matches the canonical Mac App display name    |

## Task Commits

Each task was committed atomically on the worktree branch `worktree-agent-a78da69204034f2ef`:

1. **Task 1: Author packages/core.rb** -- `927cd70` (feat)
2. **Task 2: Author packages/gui.rb** -- `344d61c` (feat)
3. **Task 3: Rewrite packages/README.md** -- `571fcec` (docs)

## Files Created/Modified

- `packages/core.rb` (created) -- server-safe CLI baseline; 31 brew lines; sourced verbatim into the composed Brewfile by Plan 03.
- `packages/gui.rb` (created) -- laptop GUI baseline; 2 cask lines with mandatory `# verify: <App>`; sourced verbatim when machine `bundles` includes `"gui"`.
- `packages/README.md` (modified) -- replaced 11-line Phase 1 stub with 103-line DOCS-02 anchor; mirrors `shell/README.md` shape per Plan 03's DOCS-02 precedent.

## Decisions Made

- **1password-cli placement: core.rb formula-style with `# verify: op`.** Recommended by 05-CONTEXT.md Claude's Discretion. The corresponding Homebrew cask installs the `op` binary on PATH but does not lay down a `.app` bundle, so the D-06 cask verify rule (`test -d /Applications/<App>.app`) cannot apply. Expressing it as a formula-style entry keeps the verify rule uniform and avoids a one-off special case in the Plan 04 parser.
- **Header-comment word choice avoids literal package-name tokens that downstream automated checks negate.** Specifically: core.rb's "surgery" comment refers to "the v1 zsh plugin manager" rather than naming `antigen` (the acceptance criterion `! grep -q antigen` is anchored on substring presence anywhere in the file, including comments); gui.rb's comment refers to "the 1Password command-line tool" rather than naming `1password-cli` (same reason, `! grep -q "1password-cli"`). The plan author flagged this risk implicitly through the acceptance criteria; the implementation honored it.
- **Uniform single-space `# verify: <token>` shape.** Plan 04's verify-comment parser is regex-anchored on `# verify: <token>` (single space after `#`, single space after `:`). gui.rb's ghostty line was initially aligned with multiple spaces (column-aligned with `1password`) which broke the literal-string `grep -q "cask 'ghostty' # verify: Ghostty"` automated verify check; corrected to single space to match the canonical shape uniformly across both bundles.

## Deviations from Plan

None - plan executed exactly as written.

The plan's `<read_first>` references, action steps, verify chains, and acceptance criteria all matched the implementation choices needed. The two minor implementation adjustments documented in `## Decisions Made` (avoiding literal `antigen` / `1password-cli` tokens in comments; single-space verify shape) are clarifications of how the acceptance criteria were honored, not deviations from the plan's instructions.

## Issues Encountered

- **Initial draft of core.rb included the literal token `antigen` in a surgery comment** ("Drops `brew \"antigen\"` (Phase 3 replaced antigen with antidote)"). This tripped the `! grep -q antigen packages/core.rb` acceptance check. Fixed by rewording the comment to "Drops the v1 zsh plugin manager (Phase 3 swapped it for antidote)."
- **Initial draft of gui.rb included the literal token `1password-cli` in a comment** explaining where the CLI lives. Tripped the `! grep -q "1password-cli" packages/gui.rb` acceptance check. Fixed by rewording to "The 1Password command-line tool is NOT here -- it lives in core.rb as a formula-style entry with `# verify: op`."
- **Initial draft of gui.rb column-aligned the ghostty verify comment with multiple spaces** (`cask 'ghostty'   # verify: Ghostty`). The plan's automated verify chain used a literal-string `grep -q "cask 'ghostty' # verify: Ghostty"` which expects a single space. Fixed to single space for both lines (also the canonical shape Plan 04's parser regex expects).

All three issues were caught by the plan's per-task verify chain on first run and corrected before the task commit.

## Threat Flags

None. The two new files (`packages/core.rb`, `packages/gui.rb`) carry only public Homebrew formula/cask identifiers -- no secrets, no credentials, no PII, no network access at source time, no eval. Plan-level `<threat_model>` register entries T-05-01 through T-05-04 all remain in their original disposition (accept for T-05-01/02/04; mitigate for T-05-03 happens in Plan 04). No new attack surface introduced; no new trust boundary opened.

## Next Phase Readiness

- **Plan 02 (manifest TOML migrations)** can proceed: the two bundle names (`core`, `gui`) referenced in the success criteria match what `packages/core.rb` and `packages/gui.rb` provide; the `# verify: <App>` cask comment shape and `# verify: <bin>` formula comment shape are stable for the typed-bucket extras the manifest TOMLs will declare.
- **Plan 03 (composer)** can proceed: bundle files are at the flat `packages/<bundle>.rb` paths the composer reads; concatenation order (each bundle in declared order, then typed-bucket extras) is unblocked.
- **Plan 04 (packages:verify + LINT-09)** can proceed: the `# verify: <token>` regex anchors specified in the plan's `<interfaces>` block match the authored content verbatim; the mandatory-cask-verify invariant is exercised by `packages/gui.rb` as the test fixture.

## Self-Check: PASSED

Files exist:
- `packages/core.rb` -- FOUND (committed `927cd70`)
- `packages/gui.rb` -- FOUND (committed `344d61c`)
- `packages/README.md` -- FOUND (committed `571fcec`)

Commits exist on `worktree-agent-a78da69204034f2ef`:
- `927cd70` -- FOUND (feat: core.rb)
- `344d61c` -- FOUND (feat: gui.rb)
- `571fcec` -- FOUND (docs: README.md rewrite)

Overall plan verification checks (re-run before SUMMARY write):
1. All three files exist at flat `packages/` paths: PASS
2. No `packages/brew/` subdirectory: PASS
3. core.rb brew line count = 31 (>= 29): PASS
4. gui.rb cask line count = 2: PASS
5. Every gui.rb cask carries `# verify:`: PASS (2 = 2)
6. `antigen` absent from core.rb: PASS
7. `antidote` present in core.rb: PASS
8. `1password-cli` formula-style with `# verify: op` in core.rb: PASS
9. No non-ASCII characters in any of the three files: PASS
10. No AI attribution in any of the three files: PASS

---
*Phase: 05-packages-layer-brewfile-composition-verification*
*Plan: 01*
*Completed: 2026-05-15*
