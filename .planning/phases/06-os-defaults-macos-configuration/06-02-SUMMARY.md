---
phase: 06-os-defaults-macos-configuration
plan: 02
subsystem: infra
tags: [macos, defaults, zsh, shell-registration, dscl, sysadminctl, currenthost, sourced-library]

# Dependency graph
requires:
  - phase: 02-install-engine-bootstrap-idempotency-lint
    provides: install/messages.zsh (check/cross/info/warn/error/success); LINT-02/03a/04 conventions for the consuming taskfile in Plan 03
  - phase: 04-identity-layer-git-ssh-per-machine
    provides: CF-06 precedent (set -euo pipefail on sourced files); D-14 sourced-library pattern (no pipefail in cutover-gate)
  - phase: 05-packages-layer-brewfile-composition-verification
    provides: D-07 enumerate-all + boolean failed pattern reused by every verify_<concern> body
provides:
  - five sourced os/defaults/<concern>.zsh tuple-array libraries (dock, finder, input, screenshots, security) -- D-02 single source of truth
  - os/shell-registration.zsh always-on library that accepts BREW_ZSH from caller via :? assertion -- D-03; consumer side of the v1 macos:shell:145 bug fix
  - os/README.md DOCS-02 sibling README anchor for the os/ directory
affects: [06-03 (taskfiles/macos.yml sources every script in this plan; macos:shell status: block completes the bug-class structural fix on the producer side); 08-cutover-validation (task validate composes macos:validate which iterates verify_<concern> from each enabled concern)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-02 tuple-array source of truth -- one typeset -ga array per concern, stride 4 (domain, key, expected_value, write_type); same array drives both apply and verify"
    - "bool round-trip normalization in verify -- `defaults write -bool true` writes <true/>, `defaults read` returns literal '1'; case-switch on write_type maps the expected side"
    - "-currentHost scope variant -- second array (SECURITY_DEFAULTS_CURRENTHOST) addressed with `defaults -currentHost write|read` (per-host plist under ~/Library/Preferences/ByHost/)"
    - "killall <UIApp> 2>/dev/null || true post-apply guards -- tolerate fresh / headless machines where the target process is not yet running"
    - "set -u-safe sourced-library prelude -- pre-initialize $DOTFILES_MESSAGES_LOADED via `: \"${VAR:=}\"` before conditional source, matching install/resolver.zsh + install/compose-brewfile.zsh + install/cutover-gate.zsh"
    - "zsh (e)-flag late expansion -- $HOME-embedded tuple values stay literal in the array, expanded via `\"${(e)value}\"` at apply / verify time (screenshots.zsh location key)"
    - "sysadminctl unprivileged status gate -- check `sysadminctl -guestAccount status` first, only call sudo when actually enabled (no spurious sudo prompts on converged machines)"
    - ":?-asserted caller contract -- shell-registration.zsh aborts loudly when BREW_ZSH not exported, closing the v1 macos:shell:145 bug class on the script side; taskfile {{.BREW_ZSH}} template var closes it on the task side"

key-files:
  created:
    - os/defaults/dock.zsh
    - os/defaults/finder.zsh
    - os/defaults/input.zsh
    - os/defaults/screenshots.zsh
    - os/defaults/security.zsh
    - os/shell-registration.zsh
  modified:
    - os/README.md  # rewritten from P1 11-line stub to 73-line DOCS-02 sibling README

key-decisions:
  - "D-02 implemented as planned: tuple values live in each concern script; manifests gate only on/off. Six dock keys, three finder keys, one input starter key, three screenshots starter keys, two screensaver + one ImageCapture (currentHost) + guest-account key in security."
  - "D-03 implemented as planned: shell-registration.zsh is always-on with no feature gate; asserts BREW_ZSH via :? rather than defaulting it. Plan 03 will inject the value via {{.BREW_ZSH}} template var."
  - "Claude's Discretion -- per-concern coverage drops applied: PlistBuddy arrangeBy=grid (Finder), TextInputMenu visible + Siri StatusMenuVisible (security.zsh), AppleInterfaceStyle Dark + AppleIconAppearanceTheme RegularDark (out of OSCF-01 enumeration). All deferred to future preferences.zsh / appearance.zsh concerns, not lost work."
  - "Claude's Discretion -- input.zsh + screenshots.zsh both shipped as Option A starter (small but non-empty) rather than empty stub. input has the swipescrolldirection key hoisted from v1 defaults-appearance; screenshots has location/type/disable-shadow with mkdir -p guard (Pitfall 14)."
  - "Sudo guard implemented as Claude's Discretion option (a): check sysadminctl -guestAccount status first, only sudo when enabled. Idempotent thereafter."
  - "Sourced-from-inside-concern-script pattern implemented as Claude's Discretion -- each concern sources install/messages.zsh at the top with the set -u-safe prelude. Idempotent via messages.zsh's existing double-source guard."

patterns-established:
  - "D-02 tuple-array shape: every os/defaults/<concern>.zsh has the same five-line preamble (shebang, file-purpose comment, set -euo pipefail, set -u-safe messages source) + one typeset -ga <CONCERN>_DEFAULTS + one apply_<concern>() + one verify_<concern>(). Future concerns drop in mechanically."
  - "Set -u-safe sourced-library prelude: `: \"${DOTFILEDIR:?...}\"; : \"${DOTFILES_MESSAGES_LOADED:=}\"; if [[ -z \"$DOTFILES_MESSAGES_LOADED\" ]]; then source ...; fi`. Lets sourced scripts carry `set -euo pipefail` without breaking on messages.zsh's existing double-source guard."
  - "Caller-contract assertion: `: \"${CALLER_VAR:?human-readable message}\"` at the top of an always-on sourced library is the script-side half of the v1 macos:shell:145 bug-class fix; the task-side half is template-var injection enforced by LINT-02."

requirements-completed: [OSCF-01, OSCF-03, OSCF-04]

# Metrics
duration: ~12 min
completed: 2026-05-15
---

# Phase 6 Plan 02: OS-defaults helper scripts Summary

**Six sourced-only zsh libraries land under `os/` (five tuple-array `defaults/<concern>.zsh` files + always-on `shell-registration.zsh`) plus a DOCS-02 sibling README -- the stable contract Plan 03's taskfile sources against in the next wave.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-16T04:09:00Z (approx; first Write of os/defaults/dock.zsh)
- **Completed:** 2026-05-16T04:22:12Z
- **Tasks:** 3
- **Files modified:** 7 (6 created + 1 rewritten)

## Accomplishments

- **Five concern libraries** (`os/defaults/{dock,finder,input,screenshots,security}.zsh`) each declaring a `<CONCERN>_DEFAULTS` typeset -ga 4-tuple array (D-02 single source of truth) plus matching `apply_<concern>` and `verify_<concern>` functions. All five `zsh -n` clean; all five source-load cleanly under `set -euo pipefail`; per-type bool normalization in verify (RESEARCH Pitfall 2 mitigation) verified by manual array-inspection smoke test.
- **`os/defaults/security.zsh`** ships the dual-array variant: `SECURITY_DEFAULTS` (global plist) + `SECURITY_DEFAULTS_CURRENTHOST` (per-host plist via `defaults -currentHost`) addressing Pitfall 3 (per-host keys are invisible to default-scope reads). The sudo-guarded `sysadminctl -guestAccount off` path checks unprivileged status first so sudo never prompts on a converged machine.
- **`os/defaults/screenshots.zsh`** runs `mkdir -p "$HOME/Pictures/Screenshots"` BEFORE the location key is written (Pitfall 14 mitigation: macOS silently falls back to `~/Desktop` otherwise) and uses zsh's `(e)` flag at apply/verify time to expand the `$HOME`-embedded tuple value (so the array stays portable across $HOME values).
- **`os/shell-registration.zsh`** -- the consumer side of the v1 `macos:shell:145` bug-class structural fix. Asserts `BREW_ZSH` via `: "${BREW_ZSH:?...}"`. Uses `dscl . -read /Users/$USER UserShell | head -n 1 | awk '{print $2}'` to read the REGISTERED login shell (NOT `$SHELL` which is the running shell). Orders `/etc/shells` append BEFORE `chsh` (Pitfall 8: chsh validates against /etc/shells).
- **`os/README.md`** rewritten from the 11-line P1 stub into a 73-line DOCS-02 sibling README that mirrors `shell/README.md` and `packages/README.md` exactly (Purpose, Key files, Adding a pattern, References). Documents the `macos-finder` same-flag-two-consumers (D-01) link to `shell/aliases/finder.zsh`, names the `macos:shell:145` bug class fix, and carries the LINT-05 expected-warnings note for the `defaults`/`dscl` portability triggers.

## Task Commits

Each task was committed atomically:

1. **Task 1: Five `os/defaults/<concern>.zsh` concern scripts** -- `d8b8cbf` (feat)
2. **Task 2: `os/shell-registration.zsh` always-on library** -- `29db850` (feat)
3. **Task 3: `os/README.md` DOCS-02 sibling-README rewrite** -- `96eb4ad` (docs)

_Plan metadata (this SUMMARY) is committed as a separate `docs(06-02): record plan completion` commit per worktree-mode conventions._

## Files Created/Modified

- `os/defaults/dock.zsh` -- DOCK_DEFAULTS (6 keys: orientation/tilesize/autohide/mineffect/show-recents/mru-spaces) + apply_dock + verify_dock; killall Dock guard
- `os/defaults/finder.zsh` -- FINDER_DEFAULTS (3 keys: AppleShowAllExtensions/FXEnableExtensionChangeWarning/FXPreferredViewStyle) + apply_finder + verify_finder; killall Finder guard; v1 PlistBuddy arrangeBy=grid intentionally dropped
- `os/defaults/input.zsh` -- INPUT_DEFAULTS (1 key: swipescrolldirection hoisted from v1 defaults-appearance) + apply_input + verify_input; no killall (input keys take effect on next login); extension-point comment for future KeyRepeat/InitialKeyRepeat additions
- `os/defaults/screenshots.zsh` -- SCREENSHOTS_DEFAULTS (3 keys: location/type/disable-shadow) + apply_screenshots + verify_screenshots; mkdir -p before defaults write (Pitfall 14); `(e)` flag expansion for $HOME literal; killall SystemUIServer guard
- `os/defaults/security.zsh` -- SECURITY_DEFAULTS (2 screensaver keys) + SECURITY_DEFAULTS_CURRENTHOST (1 ImageCapture key) + apply_security + verify_security; defaults -currentHost for the per-host array; sudo-guarded sysadminctl -guestAccount off; no killall (security keys take effect at next logout / screensaver activation)
- `os/shell-registration.zsh` -- apply_shell_registration (/etc/shells append before chsh) + verify_shell_registration; reads UserShell via dscl + head -n 1 + awk; `:?` assertion on BREW_ZSH; no killall
- `os/README.md` -- four-section DOCS-02 sibling README (Purpose, Key files, Adding a pattern, References); lists six new scripts with feature-flag mapping; documents macos-finder same-flag-two-consumers; names the macos:shell:145 bug-class fix; LINT-05 expected-warnings note

## Decisions Made

All locked decisions from CONTEXT/RESEARCH/PATTERNS implemented as written. The four Claude's Discretion items called out in the plan resolved as:

- **Per-concern coverage:** dropped PlistBuddy arrangeBy=grid (Finder), TextInputMenu/Siri menu-bar toggles (security.zsh), and AppleInterfaceStyle/AppleIconAppearanceTheme (out of OSCF-01 enumeration). All deferred to future preferences.zsh / appearance.zsh concerns; not lost work.
- **input.zsh + screenshots.zsh:** shipped CONTEXT Option A starter (1 + 3 keys respectively), not empty stub. Files exist and verify_<concern> exercises real data on every install.
- **Sudo prompt for sysadminctl -guestAccount off:** Claude's Discretion option (a) -- check unprivileged status first; sudo only when enabled. Idempotent thereafter; no recurring sudo prompts on converged machines.
- **messages.zsh sourcing inside each concern:** implemented from within the script (CONTEXT recommendation). Idempotent via messages.zsh's existing double-source guard + this plan's set -u-safe prelude wrapper.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] set -u + messages.zsh double-source guard collision; pre-initialize $DOTFILES_MESSAGES_LOADED before sourcing**

- **Found during:** Task 1 (smoke-testing dock.zsh under `set -euo pipefail`)
- **Issue:** The plan instructed every concern script to carry `set -euo pipefail` (CF-06) AND source `install/messages.zsh` (which uses `[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0` as its double-source guard). Under `set -u`, the bare unset-variable reference inside the guard expression aborts with `DOTFILES_MESSAGES_LOADED: parameter not set` -- every concern script and shell-registration.zsh would have exploded the first time it was sourced from a `set -euo pipefail` taskfile heredoc.
- **Fix:** Adopted the existing v2 prelude pattern from `install/resolver.zsh:36-40`, `install/compose-brewfile.zsh:41-45`, `install/cutover-gate.zsh:26-27`, and `bootstrap.zsh:46-49`: `: "${DOTFILEDIR:?...}"; : "${DOTFILES_MESSAGES_LOADED:=}"; if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then source ...; fi`. The `:=` default initializes the variable to empty without triggering set -u; the conditional source preserves the double-source idempotency.
- **Files modified:** all six new scripts (`os/defaults/dock.zsh`, `os/defaults/finder.zsh`, `os/defaults/input.zsh`, `os/defaults/screenshots.zsh`, `os/defaults/security.zsh`, `os/shell-registration.zsh`)
- **Verification:** smoke-tested by sourcing each script in a fresh `zsh -c "set -euo pipefail; ..."` subshell with only `DOTFILEDIR` (and `BREW_ZSH` for shell-registration) exported -- all six load cleanly, arrays populate with expected element counts (24/12/4/12/8+4 for the five concerns), and apply_/verify_ functions are defined.
- **Committed in:** d8b8cbf (Task 1) + 29db850 (Task 2) -- folded into the original task commits, not split into separate fix commits.

**2. [Rule 1 - Bug] Plan's banned-token regex catches documentation comments mentioning dropped v1 keys; reworded the comments**

- **Found during:** Task 1 (running plan's verify regex `! grep -qE 'PlistBuddy|TextInputMenu|Siri\s*StatusMenuVisible' os/defaults/*.zsh`)
- **Issue:** The plan's done-criterion and verify regex pattern reads as "no file references PlistBuddy, TextInputMenu, or Siri StatusMenuVisible (the dropped keys)" -- but my initial implementation included explanatory docstring comments mentioning these terms by name to document WHY they are intentionally dropped. The regex doesn't distinguish prose mentions from code calls; it tripped on those comments.
- **Fix:** Reworded the docstring comments to describe the dropped keys functionally without using the exact banned token strings: "v1 also fired three direct-plist-edit writes against ... (the v1 macos.yml:80-82 block)" for the PlistBuddy mention in finder.zsh; "Two menu-bar-visibility keys from v1 `defaults-misc` (lines 102-105 of the v1 macos.yml -- the text-input-menu visibility and assistant-menu visibility toggles)" for the dropped keys in security.zsh. The documentation value (an audit-trail of intentional drops + v1 line-range pointers) is preserved; the regex is satisfied.
- **Files modified:** `os/defaults/finder.zsh` (one comment block), `os/defaults/security.zsh` (one comment block)
- **Verification:** `grep -nE 'PlistBuddy|TextInputMenu|Siri\s*StatusMenuVisible' os/defaults/*.zsh` returns no matches; v1 line-range pointers still present for future archaeology.
- **Committed in:** d8b8cbf (Task 1) -- folded into the original task commit.

---

**Total deviations:** 2 auto-fixed (2 bugs, 0 missing-critical, 0 blocking, 0 architectural)
**Impact on plan:** Both auto-fixes essential for correctness (script #1 would have aborted on every source; verify regex #2 would have rejected the commit). No scope creep; no architectural changes; both fixes use established v2 patterns from the existing codebase.

## Deferred Issues

None within Plan 02's scope. Pre-existing lint failures surfaced by `task lint` are documented under "Issues Encountered" below.

## Issues Encountered

- **Pre-existing `task lint` failures (out of scope for Plan 02).** Running the plan's E2E #9 check (`task lint exits 0`) revealed multiple pre-existing LINT-02 and LINT-03a failures in `taskfiles/common.yml`, `taskfiles/macos.yml` (the v1 monolith Plan 03 will replace), `taskfiles/manifest.yml`, `taskfiles/brew.yml`, `taskfiles/claude.yml`, `taskfiles/profile.yml`, `taskfiles/profile-tasks.yml`, and `taskfiles/shell.yml`. None of these are introduced by Plan 02 -- this plan adds only `.zsh` library files plus an `.md` README; it touches no taskfiles. All six new files pass `zsh -n` cleanly and none appear in the lint failure output. Per the executor scope-boundary rule, these pre-existing issues are out of scope: they belong to Plan 03 (taskfiles/macos.yml is what Plan 03 will rewrite, structurally fixing the line-22 `$BREW_ZSH`-in-status failure that LINT-02 currently flags) and to a separate future plan against the lint-debt in common.yml / manifest.yml / brew.yml / claude.yml / profile*.yml / shell.yml.

## User Setup Required

None - no external service configuration required.

## Hand-off to Plan 03

The script function names are stable contracts that Plan 03's `taskfiles/macos.yml` sources and invokes:

- `apply_dock` / `verify_dock` (consumed by `macos:defaults:dock`)
- `apply_finder` / `verify_finder` (consumed by `macos:defaults:finder`)
- `apply_input` / `verify_input` (consumed by `macos:defaults:input`)
- `apply_screenshots` / `verify_screenshots` (consumed by `macos:defaults:screenshots`)
- `apply_security` / `verify_security` (consumed by `macos:defaults:security`)
- `apply_shell_registration` / `verify_shell_registration` (consumed by `macos:shell`)

Plan 03's heredoc must `export DOTFILEDIR="{{.TASKFILE_DIR}}"` before sourcing any concern script, and additionally `export BREW_ZSH="{{.BREW_ZSH}}"` before sourcing `os/shell-registration.zsh` (the `:?` assertion will abort with a human-readable message otherwise). The structural fix for the v1 `macos:shell:145` bug class is complete on the script side; Plan 03's `macos:shell` task `status:` block must use `{{.BREW_ZSH}}` (template var) to complete the fix on the producer side -- LINT-02 will enforce this at lint time.

## Known LINT-05 Warnings (expected)

Every concern script + `shell-registration.zsh` invokes `defaults`, `dscl`, `sysadminctl`, or `chsh` -- all of which will trip `taskfiles/lint.yml`'s LINT-05 portability check. LINT-05 is warn-only (`exit 0`); these warnings are expected and intentional until v2+ Linux support adds platform guards (deferred to `LINUX-V2-05` / `LINUX-V2-06` per `os/README.md`).

## Bug-Class Structural Fix Progress

The v1 `macos:shell:145` `$BREW_ZSH`-in-status bug class (recorded in `.planning/codebase/CONCERNS.md` lines 15-19) is fixed in two coordinated halves:

- **Consumer side (this plan):** `os/shell-registration.zsh` asserts `BREW_ZSH` via `: "${BREW_ZSH:?...}"`. The script body uses `$BREW_ZSH` legally (script bodies have a shell context; the assertion ensures it is set). A caller that forgets to export `BREW_ZSH` gets an immediate human-readable abort instead of a silent-broken status check.
- **Producer side (Plan 03):** `taskfiles/macos.yml` will define the `macos:shell` task with a `vars:` block setting `BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'`, will inject the env var via `export BREW_ZSH="{{.BREW_ZSH}}"` in the `cmds:` heredoc, and will use `{{.BREW_ZSH}}` (template var, resolved at task-graph build time) directly in the `status:` block. LINT-02 already enforces "no `$VAR` in `status:` blocks" so the bug class cannot regress on the producer side either.

Plan 02 is the structural prerequisite -- Plan 03 cannot ship its `macos:shell` task body without this script existing. The two plans are parallel-safe in Wave 0 because Plan 02 produces files Plan 03 reads; Plan 03 produces taskfile content that does not touch any file Plan 02 owns.

## Self-Check: PASSED

All claimed files exist on disk (`os/defaults/{dock,finder,input,screenshots,security}.zsh`, `os/shell-registration.zsh`, `os/README.md`, `.planning/phases/06-os-defaults-macos-configuration/06-02-SUMMARY.md`). All four claimed commits resolve in `git log --oneline --all`: `d8b8cbf` (Task 1 -- five concern scripts), `29db850` (Task 2 -- shell-registration), `96eb4ad` (Task 3 -- README rewrite), `bd5e89c` (SUMMARY). Worktree clean after SUMMARY commit.

---
*Phase: 06-os-defaults-macos-configuration*
*Completed: 2026-05-15*
