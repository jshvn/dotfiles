# Phase 6: OS Defaults — macOS Configuration - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the OS-defaults layer: per-concern `os/defaults/<concern>.zsh` files (one per concern: `dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh`), each gated by a flat manifest feature flag (`macos-dock`, `macos-finder`, `macos-input`, `macos-screenshots`, `macos-security`), each idempotent via `defaults read <domain> <key>` status checks; plus `os/shell-registration.zsh` (sibling to `os/defaults/`, not inside it) that adds Homebrew zsh to `/etc/shells` and runs `chsh` with a correct `{{.BREW_ZSH}}` template-var status check (the structural fix for the v1 `macos:shell:145` `$BREW_ZSH`-in-status bug). Replaces v1 monolithic `taskfiles/macos.yml` and the current `taskfiles/macos-stub.yml`. Wires real bodies into the root `task install` call graph (the `macos:` include slot is already present in `Taskfile.yml:108`).

**Key architectural decision (sets the tone):** Flat feature flags + values-in-scripts + same flag for alias-gate + defaults-gate. The flat keys (`macos-dock`, `macos-finder`, ...) already declared on personal-laptop + work-laptop TOMLs (and the existing `macos-finder` in `defaults.toml` used by Phase 3 to gate `shell/aliases/finder.zsh`) become the manifest interface for OS defaults too — `macos-finder` means "this machine wants Finder customizations (aliases callable AND defaults applied)." ROADMAP success criterion #1's `features.macos-defaults.dock` wording amends to `features.macos-dock` (similar textual amend to Phase 5 D-02's ROADMAP success #3 amend). Concrete defaults values (`tilesize=45`, `mineffect=genie`, `FXPreferredViewStyle=clmv`, etc.) live inside the `os/defaults/<concern>.zsh` scripts as associative-array tuples; manifest gates only on/off. `task macos:validate` (OSCF-05) sources each enabled concern script and calls its `verify()` function — single source of truth per concern.

**In scope:**

- `os/defaults/dock.zsh` — port v1 `defaults-dock` keys: `orientation` ("bottom"), `tilesize` (45), `autohide` (true on laptops; v1 had `[[ "{{.PROFILE}}" == "server" ]] && echo false || echo true` — that branch disappears, because v2 servers won't have `macos-dock = true` in the first place; if a future server wants dock + autohide-off, that's a per-machine TOML choice for a later milestone). Drop the `mineffect = "genie"` if the planner prefers a single-value default; carry as-is otherwise. Keys: `show-recents` (planner verifies preference; v1 had `true`, project owners often flip to `false`), `mru-spaces` (false). Each script exports an associative array `DOCK_DEFAULTS=(domain key expected_value type ...)` (or equivalent structure), an `apply_dock()` function, and a `verify_dock()` function.

- `os/defaults/finder.zsh` — port v1 `defaults-finder` keys: `NSGlobalDomain AppleShowAllExtensions` (true), `com.apple.finder FXEnableExtensionChangeWarning` (false), `com.apple.finder FXPreferredViewStyle` ("clmv" — column view). PlistBuddy `arrangeBy = grid` for desktop icon view is more fragile and planner's call whether to port (v1 wraps it in `2>/dev/null || true`). Same shape as `dock.zsh` (array + apply + verify).

- `os/defaults/input.zsh` — v1 has nothing here. Phase 6 ships either:
  - **Option A (recommended):** minimum starter: `NSGlobalDomain com.apple.swipescrolldirection` (false — natural scroll off) hoisted out of v1's `defaults-appearance` task; `NSGlobalDomain KeyRepeat` and `InitialKeyRepeat` if josh has preferences (planner asks during execution if needed).
  - **Option B:** empty stub with a comment "populate as preferences emerge" — script exists, array is empty, `apply()` and `verify()` are no-ops. OSCF-01 satisfied (file exists); contents grow over time.
  Planner picks. Either way the file exists and is gated by `macos-input`.

- `os/defaults/screenshots.zsh` — v1 has nothing here. Phase 6 ships either:
  - **Option A (recommended):** minimum starter: `com.apple.screencapture location` (`$HOME/Pictures/Screenshots` — directory created if absent, like v1 `defaults-finder` PlistBuddy pattern), `com.apple.screencapture type` ("png"), `com.apple.screencapture disable-shadow` (true). Trigger `killall SystemUIServer` after `apply()` (matches macOS convention for screencapture changes to take effect).
  - **Option B:** empty stub. Planner picks.

- `os/defaults/security.zsh` — port v1 `defaults-general` (screensaver) + v1 `defaults-misc` (security-flavored subset): `com.apple.screensaver askForPassword` (1), `com.apple.screensaver askForPasswordDelay` (0), `com.apple.ImageCapture disableHotPlug` (true) — `currentHost` scoped per v1; `com.apple.TextInputMenu visible` (false) and `com.apple.Siri StatusMenuVisible` (false) are not strictly "security" — planner decides whether they land in `security.zsh` (catch-all for v1's misc) OR get dropped (they're personal-preference, not a security posture, and could be deferred to a future "preferences" concern). v1's `sysadminctl -guestAccount off` lands in `security.zsh` (it requires sudo; the apply() handles the prompt; verify() checks `sysadminctl -guestAccount status` for "disabled"). This is the concern servers run (per ROADMAP success #4) — keys must be server-safe (no GUI assumptions).

- `os/shell-registration.zsh` — top-level under `os/` (NOT inside `os/defaults/`, per OSCF-01 literal wording and the same "sibling-to-defaults" reading of the ROADMAP). Always-on for every macOS machine (no feature flag). Sourced by `taskfiles/macos.yml` task `macos:shell`. Two functions: `apply_shell_registration()` and `verify_shell_registration()`. Apply: (1) if `! grep -qxF "{{.BREW_ZSH}}" /etc/shells`, sudo-append Homebrew zsh; (2) if `dscl . -read /Users/$USER UserShell` doesn't match `{{.BREW_ZSH}}`, run `chsh -s "{{.BREW_ZSH}}"`. Verify: both conditions are true. Task `status:` block uses `{{.BREW_ZSH}}` template var, NOT `$BREW_ZSH` shell var — this is the structural fix for the v1 `macos:shell:145` bug class (LINT-02 compliance enforces it at lint time too).

- `taskfiles/macos.yml` — replaces `taskfiles/macos-stub.yml`. Tasks:
  - `macos:defaults` — aggregator. Calls each `macos:defaults:<concern>` task in declared order. No `status:` block; carries `# lint-allow: cmds-without-status` marker (LINT-01/03a aggregator exemption, P2 D-12).
  - `macos:defaults:dock` — gated on `index .MANIFEST.features "macos-dock"` (kebab-case index form, CLAUDE.md rule). `cmds:` sources `os/defaults/dock.zsh` and calls `apply_dock`. `status:` sources the same script and calls `verify_dock`. Both use `{{.X}}` template vars only (LINT-02).
  - `macos:defaults:finder`, `macos:defaults:input`, `macos:defaults:screenshots`, `macos:defaults:security` — same shape.
  - `macos:shell` — always-on (no feature gate). Sources `os/shell-registration.zsh`, calls `apply_shell_registration` in `cmds:`, `verify_shell_registration` in `status:`. Uses `{{.BREW_ZSH}}` (defined as a task-level `vars:` entry: `BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'`).
  - `macos:validate` — OSCF-05. Sources each `os/defaults/<concern>.zsh` script whose feature gate is true, calls each `verify_<concern>()`, prints check/cross per key via `messages.zsh`. Enumerates everything (no fast-fail — same pattern as P5 D-07). Exits non-zero if any key mismatches.

- **Root `Taskfile.yml` edits:**
  - `includes.macos` flips from `./taskfiles/macos-stub.yml` to `./taskfiles/macos.yml`. The include key stays `macos:` (no rename needed — the v1 namespace was already `macos:`).
  - Root `install` task's `cmds:` already wires `task: macos:defaults` then `task: macos:shell` (Taskfile.yml:142-143). No changes there.
  - Root `validate` task (P8 will assemble it) eventually calls `task: macos:validate`; P6 just ships `macos:validate` ready to compose.

- **Manifest TOML migrations (P6 deliverables):**
  - `manifests/defaults.toml` `[features]` section gains: `macos-dock = false`, `macos-input = false`, `macos-screenshots = false`, `macos-security = false`. (`macos-finder = false` is already present.) All five enumerate as the schema baseline.
  - `manifests/machines/server-1.toml` and `manifests/machines/server-2.toml` gain `macos-security = true` (per ROADMAP success #4: "only `shell-registration.zsh` and `security.zsh` run" on a Mac server that declines GUI defaults). The other four `macos-*` keys stay absent → inherited as `false`.
  - `manifests/machines/personal-laptop.toml` and `work-laptop.toml` already declare all five flags as `true` — no edit needed.

- **Required ROADMAP / REQUIREMENTS edits (planner action items):**
  - `ROADMAP.md` Phase 6 success criterion #1: text says `features.macos-defaults.dock = true` (nested). Amend to `features.macos-dock = true` (flat) — matches the manifest reality and the D-01 decision below.
  - `ROADMAP.md` Phase 6 success criterion #3: refers to `task macos:shell` using `{{.BREW_ZSH}}` template var — keep as-is; this is the bug class P6 fixes.
  - `ROADMAP.md` Phase 6 success criterion #5: refers to `task validate` reading current defaults and asserting against the manifest's "expected values for the active machine." Soften to: `task validate` reads current `defaults` values for declared keys and asserts them against the in-script expected values for each enabled concern. The "manifest's expected values" phrasing implies values live in the manifest; per D-02, values live in the scripts. Both readings satisfy OSCF-05's spirit ("validate asserts current defaults match expectations") — the wording amend is to keep the doc honest about where the source of truth lives.
  - `REQUIREMENTS.md` OSCF-02: text says "Each defaults group is gated by a manifest feature flag" — keep as-is (matches D-01).
  - `REQUIREMENTS.md` OSCF-05: text says "`task validate` asserts current defaults values match manifest expectations for the active machine" — same soften as ROADMAP #5 if the planner cares; otherwise leave (the requirement is satisfied either way).
  - `PROJECT.md` Active section: "macOS defaults — Configurable via manifest features (each defaults group is opt-in)" — no edit needed (matches D-01).
  - `docs/MANIFEST.md` schema reference: `[features]` table grows the four new entries (`macos-dock`, `macos-input`, `macos-screenshots`, `macos-security`). `macos-finder` already documented.

- **`os/README.md`** — new file. Purpose: explains the `os/defaults/<concern>.zsh` shape (associative-array tuples + apply + verify), the `os/shell-registration.zsh` sibling, the manifest feature gates, idempotency contract (`defaults read` in status; `{{.X}}` template vars only), and how to add a new defaults concern (one new file + one new feature flag + one new task entry).

- **Install-pipeline participation** — `task macos:defaults` and `task macos:shell` already invoked by root `task install` (Taskfile.yml:142-143 against the stub). P6 swaps the include target; pipeline unchanged.

**Out of scope (deferred to later phases or future versions):**

- `task validate` root composition — P8 (CUTV-01). P6 ships `task macos:validate` ready to compose.
- v1 `taskfiles/macos.yml` deletion — P8. v1 file stays byte-stable until cutover completes (parallel-rewrite invariant).
- Linux equivalent (`os/<linux-concern>.zsh`, e.g., gnome-defaults, sysctl) — v2+ milestone. v1 is macOS-only.
- A `preferences.zsh` concern (TextInputMenu, Siri StatusMenuVisible, etc. that aren't strictly security) — defer unless josh wants the split now; otherwise those keys land in `security.zsh` as v1's `defaults-misc` catch-all (planner's call).
- Per-machine override of defaults values (e.g., a different dock tilesize on work-laptop) — D-02 keeps values in scripts; if josh ever needs per-machine value variation, it migrates to manifest-declared values then. v1 ships single-value-per-key.
- `mds` (Spotlight indexing) toggles, `pmset` power-management defaults, FileVault status checks — out of v1 scope unless josh names a specific need.
- macOS-defaults change-watcher / restore-on-drift — not v1.
- Window-manager defaults (Yabai, Magnet config, etc.) — Magnet is a MAS app declared in P5 extras; its config is GUI-only, not a `defaults write` target. Out of P6 scope.

**Requirements addressed:** OSCF-01, OSCF-02, OSCF-03, OSCF-04, OSCF-05

</domain>

<decisions>
## Implementation Decisions

### Feature-Flag Schema

- **D-01: Flat keys, same flag for alias-gate + defaults-gate.** `defaults.toml [features]` gains `macos-dock = false`, `macos-input = false`, `macos-screenshots = false`, `macos-security = false`; `macos-finder = false` is already present (P3 D-10). `macos-finder` means "this machine wants Finder customizations" — both the `shell/aliases/finder.zsh` wrapper functions (already wired by Phase 3 D-07) and `os/defaults/finder.zsh` consult the same flag. Same-flag-two-consumers pattern: anyone who wants the Finder alias also wants the Finder defaults applied (and vice versa, on every v1 machine that has `macos-finder = true`: personal-laptop and work-laptop). No machine in v1 has a use case for "alias yes, defaults no" (or vice versa), so the dual-consumer mapping is correct by construction. Index form in tasks: `{{if index .MANIFEST.features "macos-finder"}}` (kebab-case requires `index`, CLAUDE.md rule). **Rationale (user-led):** "Flat, reuse same flag for alias + defaults (Recommended)." ROADMAP success #1's `features.macos-defaults.dock` wording amends to `features.macos-dock` (textual amend pattern matching P5 D-02).

- **D-04: Server machines gain `macos-security = true`.** Per ROADMAP Phase 6 success criterion #4 ("only `shell-registration.zsh` and `security.zsh` run" on a Mac server that declines GUI defaults), `manifests/machines/server-1.toml` and `server-2.toml` add `macos-security = true`. The other four `macos-*` keys stay absent → inherited `false`. Locks the server-behavior contract: `task install` on a server runs `macos:shell` (always-on, D-03) and `macos:defaults:security` only; `macos:defaults:dock`/`:finder`/`:input`/`:screenshots` are all no-ops at the feature-gate level.

### Defaults Values Placement

- **D-02: Values hardcoded in `os/defaults/<concern>.zsh`; manifest gates are on/off only.** Each concern script declares an associative-array tuple list at the top of the file: `(domain, key, expected_value, write_type)` rows. The script exposes `apply_<concern>()` (iterates the tuples, runs `defaults write <domain> <key> -<type> <value>` for each) and `verify_<concern>()` (iterates the same tuples, runs `defaults read <domain> <key>` and compares — exits non-zero if any mismatch; prints check/cross via `messages.zsh` for OSCF-05). Single source of truth per concern: the tuples are the contract for both write and verify. Taskfile `cmds:` sources the script and calls `apply_<concern>`; `status:` sources the script and calls `verify_<concern>`. Both invocations use `{{.X}}` template vars only (LINT-02). **Verify enumeration pattern:** by analogy with P5 D-07, `verify_<concern>()` enumerates every key (no fast-fail on first mismatch), prints the full check/cross table, exits non-zero if any key failed. **Rationale (user-led):** "Hardcoded in os/defaults/<concern>.zsh + sibling validate (Recommended)." Manifest TOML schema surface stays minimal (just the five gate flags + `macos-finder` already in place); per-machine value overrides are deferred until a real need emerges.

### shell-registration Scope

- **D-03: `os/shell-registration.zsh` runs unconditionally on every macOS machine. No feature flag.** Top-level under `os/` (NOT inside `os/defaults/`, per OSCF-01 wording). Every machine (laptops + servers) gets Homebrew zsh as login shell — consistent zsh feature set across the fleet, no `.zshrc` divergence between system-zsh and Homebrew-zsh edge cases. Idempotent: status block uses `grep -qxF "{{.BREW_ZSH}}" /etc/shells` AND `[[ "$(dscl . -read /Users/$USER UserShell | awk '{print $2}')" = "{{.BREW_ZSH}}" ]]` — both with `{{.X}}` template vars only (LINT-02 compliance). **This is the structural fix for the v1 `macos:shell:145` `$BREW_ZSH`-in-status bug class** referenced in `.planning/codebase/CONCERNS.md` lines 15-19: the v1 task evaluated `status:` in a fresh shell where `$BREW_ZSH` was unset, causing the task to re-run on every install; the v2 task uses the task-template variable, which is resolved at task-graph build time and is always set. **Rationale (user-led):** "Always-on for every macOS machine, no feature flag (Recommended)." Servers explicitly want Homebrew zsh too — the dotfiles `.zshrc` assumes Homebrew zsh feature parity (history options, completion behavior); a server on system zsh would subtly break those assumptions.

### Claude's Discretion (planner concerns)

- **`apply`/`verify` invocation pattern in the taskfile** — the natural shape is taskfile `cmds:` does `source os/defaults/dock.zsh && apply_dock`, and `status:` does `source os/defaults/dock.zsh && verify_dock`. The alternative (executable script with argv dispatch: `./os/defaults/dock.zsh apply` vs `./os/defaults/dock.zsh verify`) is slightly more self-contained but pays a fork-per-invocation cost. Recommend sourcing; planner picks. If sourced, the script header still carries `set -euo pipefail` (LINT-04 applies even to sourced files in this repo's convention — confirm against the executable bit; sourced-only files exempt per P4 CF-06 wording but the convention is consistent in v2 to set the flag).

- **Per-concern coverage (what keys land in dock/finder/input/screenshots/security)** — selected as "user discretion → Claude's discretion" during area-selection (user picked 3 of 4 areas; this was the 4th). Recommended landing zones:
  - `dock.zsh`: v1 `defaults-dock` keys verbatim (`orientation`, `tilesize`, `mineffect`, `show-recents`, `mru-spaces`, `autohide`) MINUS the v1 `[[ "{{.PROFILE}}" == "server" ]]` branch on `autohide` (which v2 servers don't run anyway, so the branch is dead). `autohide` becomes a simple `true`.
  - `finder.zsh`: v1 `defaults-finder` keys (`AppleShowAllExtensions`, `FXEnableExtensionChangeWarning`, `FXPreferredViewStyle`). v1's PlistBuddy `arrangeBy = grid` calls are brittle (depend on Finder having been launched once and the keys existing) — recommend DROPPING from v1 P6 ship; if josh misses the icon-grid behavior, it gets a P6+1 follow-up plan.
  - `input.zsh`: minimum starter — `NSGlobalDomain com.apple.swipescrolldirection` (false, hoisted from v1 `defaults-appearance`); optionally `NSGlobalDomain KeyRepeat` (2) + `InitialKeyRepeat` (15) if josh confirms taste during execution.
  - `screenshots.zsh`: minimum starter — `com.apple.screencapture location` (`$HOME/Pictures/Screenshots`, mkdir if absent), `type` (`png`), `disable-shadow` (true). Final `killall SystemUIServer` after `apply()` so the change takes effect without logout. Empty-stub option is on the table if the planner wants smaller P6 surface.
  - `security.zsh`: v1 `defaults-general` keys (`com.apple.screensaver askForPassword`/`askForPasswordDelay`) + v1 `defaults-misc` keys (`com.apple.ImageCapture disableHotPlug` with `-currentHost` scope; `sysadminctl -guestAccount off` with sudo prompt). v1's `TextInputMenu visible` and `Siri StatusMenuVisible` are personal-preference, not security — recommend either dropping (planner's call) or landing in a future `preferences.zsh` concern; out of P6 if dropped.
  - **NSGlobalDomain `AppleInterfaceStyle = Dark` and `AppleIconAppearanceTheme = RegularDark`** (v1 `defaults-appearance`) don't fit any of OSCF-01's five concerns. Recommend dropping in v1 P6 — they're personal-preference, not in the OSCF-01 enumeration. If josh wants them back, they get a future `appearance.zsh` concern with `features.macos-appearance`. Out of P6.

- **`security.zsh` sudo prompt for `sysadminctl -guestAccount off`** — the apply path needs sudo. Two options: (a) wrap in `if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then sudo sysadminctl -guestAccount off; fi` (same pattern as v1 line 100-104); the verify path is unprivileged. (b) skip the guest-account toggle entirely and document it as a manual step in `docs/CUTOVER.md` (P8). Recommend (a) — sudo prompt fires only on first install on a fresh machine (idempotent thereafter; verify exits 0). Planner picks.

- **`messages.zsh` sourcing inside `os/defaults/<concern>.zsh` for verify output** — `verify_<concern>()` calls `check`/`cross` from `messages.zsh`. The script needs `source "${DOTFILEDIR}/install/messages.zsh"` at the top, or the taskfile sources `messages.zsh` first and then sources the concern script. Cleaner: source `messages.zsh` from inside each concern script (idempotent — `messages.zsh` is double-source-guarded per its line 21-22).

- **Validation enumeration order (which concern reports first)** — `task macos:validate` iterates enabled concerns in a deterministic order: dock, finder, input, screenshots, security (alphabetical-ish, matches OSCF-01 enumeration order). Servers see only security (their one enabled concern); laptops see all five.

- **Should `os/defaults/<concern>.zsh` carry executable bit + shebang?** The CLAUDE.md rule is `set -euo pipefail on every executable .zsh`. If sourced (D-discretion above), the file is sourced-only — executable bit optional; shebang line still recommended for editor language detection. If invoked via argv dispatch, executable bit + `#!/bin/zsh` mandatory. Recommend sourced + shebang line for editor support, no executable bit (matches the `install/messages.zsh` pattern which is sourced-only).

- **One-screen lint hook for the `defaults read <domain> <key>` idempotency contract** — OSCF-03 says every defaults task has a status that reads `defaults read <domain> <key>` before writing. The LINT-02 rule already catches the `$VAR` regression class. A potential LINT-10 (similar to the proposed-in-P5 LINT-09 for cask verify-comment): "any `defaults write` line in a cmds: block must have a matching `defaults read` in the same task's status:". Strongly recommended addition to `taskfiles/lint.yml`; planner picks whether P6 ships it or files a follow-up plan against P2's lint suite. Without this, the only enforcement is the verify() function's runtime check — which catches misses but not "wrote a key, forgot to add it to the expected-tuples array."

### Carried Forward (not re-decided in this discussion)

- **CF-01:** Manifest is the source of truth — `taskfiles/macos.yml` reads `resolved.json` via `ref: fromJson` (P1 D-15, P2/P4/P5 confirmed pattern). No hostname inference, no `[[ "{{.PROFILE}}" == "server" ]]` branches; the v1 `defaults-dock` and `validate` profile branches disappear.
- **CF-02:** Kebab-case feature keys use `index` form in go-template; snake_case keys use dot access (CLAUDE.md, repeated in every prior CONTEXT). `macos-*` keys are kebab — every gate is `{{if index .MANIFEST.features "macos-<concern>"}}`.
- **CF-03:** `status:` blocks use `{{.X}}` template vars ONLY — never `$X` shell vars (LINT-02; the v1 `macos:shell:145` bug class). Phase 6 is the structural fix for this bug; the `os/shell-registration.zsh` status block uses `{{.BREW_ZSH}}` (defined as a `vars:` entry on the task, set to `{{.HOMEBREW_PREFIX}}/bin/zsh`).
- **CF-04:** Every install task has a `status:` block; aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker (LINT-01/03a). `macos:defaults` is an aggregator — gets the marker.
- **CF-05:** No bare `ln -s` outside `taskfiles/helpers.yml` (LINT-03b). P6 has no symlinks (no `os/` symlinks declared in `taskfiles/links.yml`); `_:safe-link` not used here.
- **CF-06:** `set -euo pipefail` on every executable `.zsh` (LINT-04). Sourced-only `.zsh` files exempt per P4 CF-06 wording, but the convention is consistent in v2 to set the flag anyway — `os/defaults/<concern>.zsh` and `os/shell-registration.zsh` headers carry it.
- **CF-07:** XDG everywhere — no XDG paths needed in P6 (`defaults read/write` writes to `~/Library/Preferences/`, owned by macOS). `screencapture location` defaults to `$HOME/Pictures/Screenshots` (not XDG; matches macOS convention; XDG is for dotfiles repo's own state/config/cache, not user-facing media).
- **CF-08:** `deps: [manifest:resolve]` on every `macos:*` task that reads `resolved.json` (P1 D-14 pattern, reused by P4 `identity.yml`, P5 `packages.yml`).
- **CF-09:** `install/messages.zsh` sourced via `{{.DOTFILES_MESSAGES}}` for check/cross output (P1 deliverable; used by P2/P3/P4/P5).
- **CF-10:** Detect Homebrew prefix via `uname -m`; use `$HOMEBREW_PREFIX` (shell) / `{{.HOMEBREW_PREFIX}}` (task) — never hardcode `/opt/homebrew`. `os/shell-registration.zsh` uses `${HOMEBREW_PREFIX}/bin/zsh`.
- **CF-11:** Parallel rewrite — v1 `taskfiles/macos.yml` stays byte-stable on disk; P8 owns its deletion (CONTEXT precedent from P1–P5).
- **CF-12:** No AI attribution in commits or source; no emojis (project convention, hook-enforced).
- **CF-13:** Sibling-README pattern (P3 SC#6 origin) — `os/README.md` mirrors `shell/README.md` and `packages/README.md` shape: purpose, key files, how-to-add-pattern.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints, Out of Scope ("Hostname-based machine detection — burned us before"; "Inline profile branching in shared files — replaced by manifest-driven feature gates"). Active section: "macOS defaults — Configurable via manifest features (each defaults group is opt-in)" already matches D-01.
- `.planning/REQUIREMENTS.md` OSCF-01..05 — Full requirements; OSCF-02 wording matches D-01; OSCF-05 wording may soften per D-02 (planner's call).
- `.planning/ROADMAP.md` Phase 6 section — Goal, five success criteria, requirement mapping; success criterion #1 needs amend per D-01 (nested `features.macos-defaults.dock` → flat `features.macos-dock`); success criterion #5 may soften per D-02.
- `.planning/STATE.md` — Pre-Phase-6 state (Phases 1–5 complete; manifest + install + shell + identity + packages layers shipped).

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md` — Phase 1 decisions binding on P6:
  - **D-14:** Auto-rebuild via task precondition — `macos.yml` declares `deps: [manifest:resolve]`.
  - **D-15:** `resolved.json` at `$XDG_STATE_HOME/dotfiles/resolved.json` — machine-local; one-active-machine-at-a-time invariant.
  - **D-16:** Missing-state hard-fail pattern — `macos:defaults` and `macos:shell` abort cleanly when state file or resolved.json is absent (the install path already enforces this upstream of macos:* via `manifest:resolve` deps).
- `.planning/phases/02-install-engine-bootstrap-idempotency-lint/02-CONTEXT.md` — Phase 2 decisions binding on P6:
  - **D-12:** All lint logic inlined in `taskfiles/lint.yml`; `taskfiles/macos.yml` must pass LINT-01..04 + LINT-07. P6 proposes a candidate LINT-10 ("defaults write in cmds: must have matching defaults read in status:" — see Claude's Discretion).
  - **D-13:** Lint severity model — LINT-02 (`$VAR` in `status:`) and LINT-03a (`cmds:` without `status:`) are blocking; `macos.yml` conforms (this phase is the structural fix for the LINT-02 bug class).
- `.planning/phases/03-shell-layer-flat-content-port/03-CONTEXT.md` — Phase 3 decisions binding on P6:
  - **D-07:** `shell/aliases/finder.zsh` wraps `finder`/`findershow`/`finderhide` as functions gated on `_dotfiles_feature macos-finder`. P6 reuses the same `macos-finder` flag for `os/defaults/finder.zsh` (D-01 same-flag-two-consumers).
  - **D-10:** Gated alias scope — only `finder.zsh` (`macos-finder`) and `ghostty.zsh` (`ghostty`) extracted from common in P3; P6's defaults gates are independent of the shell alias gates EXCEPT that `macos-finder` is shared.
- `.planning/phases/04-identity-layer-git-ssh-per-machine/04-CONTEXT.md` — Phase 4 decisions binding on P6:
  - **CF-06:** `set -euo pipefail` on every executable `.zsh`; sourced-only files exempt — `os/defaults/<concern>.zsh` files are sourced-only (per Claude's Discretion above) but still carry the flag for consistency.
- `.planning/phases/05-packages-layer-brewfile-composition-verification/05-CONTEXT.md` — Phase 5 decisions binding on P6:
  - **D-07:** `packages:verify` enumerates every package (no fast-fail). P6's `verify_<concern>()` and `task macos:validate` mirror this pattern — enumerate every key, print full check/cross table, exit non-zero at end if any failed.
  - **D-10:** Hard-fail verify at the install gate. v2 `task install`'s call graph: `links:all → packages:install → claude:install → macos:defaults → macos:shell → packages:verify`. `macos:validate` is composed into root `task validate` in P8 (CUTV-01), not into `task install` — runtime install asserts via the individual `status:` blocks (OSCF-03 idempotency contract); the top-level `validate` is the periodic / on-demand integrity check.

### Existing v1 Codebase (sources for the port)
- `taskfiles/macos.yml` — v1 monolith; sourced for `os/defaults/<concern>.zsh` content (the `defaults write` lines + the expected-value tuples for `verify`):
  - `defaults-dock` (lines 40-57) → `os/defaults/dock.zsh` (minus the `[[ "{{.PROFILE}}" == "server" ]]` branch on `autohide`).
  - `defaults-finder` (lines 72-89) → `os/defaults/finder.zsh` (PlistBuddy `arrangeBy = grid` lines flagged for drop per Claude's Discretion).
  - `defaults-general` (lines 29-38) → `os/defaults/security.zsh` (screensaver `askForPassword` + `askForPasswordDelay`).
  - `defaults-misc` (lines 91-109) → `os/defaults/security.zsh` (ImageCapture, guestAccount) + DROP candidates (TextInputMenu, Siri).
  - `defaults-appearance` (lines 59-70) → mostly DROPS; only `swipescrolldirection` migrates to `os/defaults/input.zsh`. `AppleInterfaceStyle Dark` + `AppleIconAppearanceTheme RegularDark` recommended drops in v1 P6 (out of OSCF-01 enumeration).
  - `shell` (lines 111-146) → `os/shell-registration.zsh` (with the `$BREW_ZSH`-in-status bug structurally fixed via D-03 `{{.BREW_ZSH}}` template var).
  - `validate` (lines 152-184) — v1 validate logic for macOS components; portions migrate to `os/defaults/<concern>.zsh` `verify_<concern>()` (the shell-in-/etc/shells check stays on `os/shell-registration.zsh` `verify_shell_registration()`).
- `taskfiles/macos-stub.yml` — Phase 2 stub for the `macos:` include slot in root `Taskfile.yml`. P6 replaces it with the real `taskfiles/macos.yml`.
- `install/messages.zsh` — reused by `taskfiles/macos.yml` and by `os/defaults/<concern>.zsh` for `check`/`cross` validation output.
- `taskfiles/helpers.yml` — `_:check-command` and `_:check-file` are NOT a natural fit for defaults checks (those check binaries on PATH and file existence; defaults check `defaults read <domain> <key>` output). The defaults checks live inline in each concern's `verify_<concern>()` function.
- `.planning/codebase/CONCERNS.md` — Tech debt P6 must NOT reintroduce and tech debt P6 fixes:
  - **Fixes (lines 15-19):** `macos:shell` status check uses `$BREW_ZSH` shell var instead of `{{.BREW_ZSH}}` template var — re-runs on every install. D-03's status block uses the template var (LINT-02 enforces).
  - **Must not reintroduce:** Profile-based branching (`[[ "$PROFILE" == "server" ]]`) — gone via D-01 manifest feature flags.

### Manifest Layer (P6 reads + writes)
- `manifests/defaults.toml` — P6 adds to `[features]`: `macos-dock = false`, `macos-input = false`, `macos-screenshots = false`, `macos-security = false`. (`macos-finder = false` already present, P3 D-10.) Documents `macos-finder` shared dual-consumer semantics inline.
- `manifests/machines/personal-laptop.toml` — Already declares all five `macos-*` flags as `true`. No edit needed.
- `manifests/machines/work-laptop.toml` — Already declares all five `macos-*` flags as `true`. No edit needed.
- `manifests/machines/server-1.toml` — P6 adds `macos-security = true` (D-04). Other four `macos-*` keys stay absent → inherited `false`.
- `manifests/machines/server-2.toml` — Same as server-1.
- `docs/MANIFEST.md` — P6 updates schema reference: `[features]` table grows four new rows (`macos-dock`, `macos-input`, `macos-screenshots`, `macos-security`); `macos-finder` row gains a note about dual-consumer semantics (alias + defaults).

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — v2 conventions: flat directories in v1 ("No `os/darwin/` nesting"), one concept per file (one concern per `os/defaults/<concern>.zsh`), `status:` blocks use template vars only (the v1 `macos:shell:145` bug class — fixed structurally by P6), no hardcoded `/opt/homebrew`, kebab-case feature keys need `index` access (`{{if index .MANIFEST.features "macos-finder"}}`).
- `.claude/CLAUDE.md` — Project-level Claude instructions; reaffirms flat layout + manifest-as-truth + LINT contract.
- `~/.config/claude/CLAUDE.md` — Global conventions (no AI attribution; no curl-to-sh; etc.).

### External Reference
- Apple `defaults` man page — `defaults read/write/delete`, `-currentHost` scope, type flags (`-bool`, `-int`, `-string`, `-float`, `-array`, `-dict`). `verify_<concern>()` must match the write type's read output exactly (e.g., `-bool true` reads as `"1"`; the verify comparison handles this).
- `dscl` man page — `dscl . -read /Users/$USER UserShell` is the reliable way to read the login shell (more reliable than `$SHELL`, which reflects the currently-running shell rather than the registered login shell). Used by D-03's status check.
- `sysadminctl` man page — `-guestAccount status|on|off`. Requires sudo for state changes. Used by the proposed `security.zsh` guestAccount handling (Claude's Discretion).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (port from v1; minor surgery in transit)
- **`taskfiles/macos.yml`** — the v1 monolith provides nearly verbatim source content for all five concern scripts plus `shell-registration.zsh`. Surgery (per concern):
  - **dock:** drop the `[[ "{{.PROFILE}}" == "server" ]] && echo false || echo true` branch on `autohide` (line 47); replace with literal `true`. Move all six keys into `DOCK_DEFAULTS` array in `os/defaults/dock.zsh`.
  - **finder:** drop the three PlistBuddy `arrangeBy = grid` calls (lines 80-82); keep `AppleShowAllExtensions`, `FXEnableExtensionChangeWarning`, `FXPreferredViewStyle` in `FINDER_DEFAULTS` array.
  - **security:** merge v1 `defaults-general` (screensaver) + selected `defaults-misc` keys (`ImageCapture disableHotPlug` with `-currentHost`; `sysadminctl -guestAccount off`) into `SECURITY_DEFAULTS` array. Drop `TextInputMenu visible` and `Siri StatusMenuVisible` (Claude's Discretion: not security; either dropped in v1 P6 or deferred to a future `preferences.zsh`).
  - **input:** new content. Minimum starter: `NSGlobalDomain com.apple.swipescrolldirection` (false, hoisted from v1 `defaults-appearance`).
  - **screenshots:** new content. Minimum starter: `com.apple.screencapture location`, `type`, `disable-shadow`. `killall SystemUIServer` after apply.
  - **shell-registration:** the `/etc/shells` + `chsh` logic from v1 `shell` task (lines 111-146) ports nearly verbatim; the FIX is in the status block (lines 144-146): v2 uses `{{.BREW_ZSH}}` (template var) where v1 used `$BREW_ZSH` (shell var, unset in fresh status-eval shell).
- **`install/messages.zsh`** — reused by `taskfiles/macos.yml` for `info`/`success`/`warn`/`error` (during apply) and by `os/defaults/<concern>.zsh` for `check`/`cross` (during verify and `task macos:validate`).
- **`taskfiles/helpers.yml`** — `_:safe-link` not used (P6 has no symlinks). `_:check-link` not used.

### Established Patterns (binding on P6)
- **`status:` blocks use `{{.X}}` template vars only** — LINT-02. P6 IS the structural fix for the v1 violation; every `macos:*` task status conforms.
- **Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker** — `macos:defaults` aggregates each `macos:defaults:<concern>` sub-task and carries the marker (LINT-01/03a).
- **`set -euo pipefail` on every executable `.zsh`** — applies to `os/shell-registration.zsh`. Sourced `os/defaults/<concern>.zsh` files inherit by convention (P4 CF-06; v2 convention to set anyway).
- **Manifest as runtime source of truth** — `macos.yml` reads `resolved.json` via go-task `fromJson`. Feature gates use `index .MANIFEST.features "<key>"` (all `macos-*` are kebab-case).
- **`deps: [manifest:resolve]`** — every `macos:*` task that reads `resolved.json` declares this.
- **Idempotency contract** — every install task has a working `status:` block (LINT-01/03a). For P6's `defaults`-writing tasks, status reads `defaults read <domain> <key>` and asserts the expected value (OSCF-03).
- **Per-concern script as both writer and verifier** — `apply_<concern>()` + `verify_<concern>()` share the same expected-tuples array. Single source of truth per script (D-02).

### Integration Points
- **`os/` → `manifests/`** — `taskfiles/macos.yml` reads `features.macos-{dock,finder,input,screenshots,security}` from `resolved.json`. Each `macos:defaults:<concern>` task is gated on the corresponding feature flag via `index .MANIFEST.features "macos-<concern>"` (kebab-case index form).
- **`os/` → root `Taskfile.yml`** — `includes.macos:` flips from `./taskfiles/macos-stub.yml` to `./taskfiles/macos.yml`. Root `install` task's `cmds:` already wires `task: macos:defaults` then `task: macos:shell` (Taskfile.yml:142-143). No `cmds:` edits needed; only the include target.
- **`os/` → P3 shell layer** — `shell/aliases/finder.zsh` already consults `_dotfiles_feature macos-finder`. P6's `os/defaults/finder.zsh` is gated on the same `macos-finder` flag (D-01 same-flag-two-consumers). The shell helper reads `resolved.json` at runtime; the task reads it at task-graph build time — both see the same source of truth.
- **`os/` → P8 `task validate`** — P6 ships `task macos:validate`; P8 composes the root `task validate` (CUTV-01) which calls `task: macos:validate` among other component validators.
- **`os/` → `install/messages.zsh`** — every concern's `verify_<concern>()` and the `apply_<concern>()` paths source `messages.zsh` for consistent output.
- **`os/shell-registration.zsh` → `$HOMEBREW_PREFIX`** — the task defines `BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'` as a vars entry; the script and the status block both reference `{{.BREW_ZSH}}`. Architecture-aware via `HOMEBREW_PREFIX` (set by root Taskfile.yml; arm64 → `/opt/homebrew`; x86_64 → `/usr/local`).

</code_context>

<specifics>
## Specific Ideas

- **`os/defaults/dock.zsh` skeleton (illustrative; planner finalizes the exact data shape):**
  ```zsh
  # os/defaults/dock.zsh -- Dock defaults (gated on features.macos-dock).
  #
  # Source-only file: sourced by taskfiles/macos.yml's macos:defaults:dock task
  # for both cmds (apply_dock) and status (verify_dock). Carries set -euo pipefail
  # by v2 convention even though sourced.

  set -euo pipefail

  source "${DOTFILEDIR}/install/messages.zsh"

  # Tuples: (domain, key, expected_value, write_type).
  # write_type is one of: bool int string float.
  typeset -ga DOCK_DEFAULTS=(
    "com.apple.dock"  "orientation"   "bottom"  "string"
    "com.apple.dock"  "tilesize"      "45"      "int"
    "com.apple.dock"  "autohide"      "true"    "bool"
    "com.apple.dock"  "mineffect"     "genie"   "string"
    "com.apple.dock"  "show-recents"  "false"   "bool"
    "com.apple.dock"  "mru-spaces"    "false"   "bool"
  )

  apply_dock() {
    local i domain key value type
    for ((i = 1; i <= ${#DOCK_DEFAULTS[@]}; i += 4)); do
      domain="${DOCK_DEFAULTS[$i]}"
      key="${DOCK_DEFAULTS[$((i + 1))]}"
      value="${DOCK_DEFAULTS[$((i + 2))]}"
      type="${DOCK_DEFAULTS[$((i + 3))]}"
      defaults write "$domain" "$key" "-${type}" "$value"
    done
    killall Dock 2>/dev/null || true
  }

  verify_dock() {
    local i domain key value type current expected_read failed=0
    for ((i = 1; i <= ${#DOCK_DEFAULTS[@]}; i += 4)); do
      domain="${DOCK_DEFAULTS[$i]}"
      key="${DOCK_DEFAULTS[$((i + 1))]}"
      value="${DOCK_DEFAULTS[$((i + 2))]}"
      type="${DOCK_DEFAULTS[$((i + 3))]}"
      current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
      # bool reads as 0/1; normalize for comparison
      case "$type" in
        bool) [[ "$value" == "true"  ]] && expected_read="1" || expected_read="0" ;;
        *)    expected_read="$value" ;;
      esac
      if [[ "$current" == "$expected_read" ]]; then
        check "dock.$key = $value"
      else
        cross "dock.$key: expected '$expected_read', got '$current'"
        failed=1
      fi
    done
    return $failed
  }
  ```

- **`os/defaults/security.zsh` skeleton (sudo-handling):**
  ```zsh
  # os/defaults/security.zsh -- Security defaults (gated on features.macos-security).

  set -euo pipefail
  source "${DOTFILEDIR}/install/messages.zsh"

  typeset -ga SECURITY_DEFAULTS=(
    "com.apple.screensaver"  "askForPassword"      "1"  "int"
    "com.apple.screensaver"  "askForPasswordDelay" "0"  "int"
  )

  # currentHost-scoped tuples (require -currentHost flag for both read and write).
  typeset -ga SECURITY_DEFAULTS_CURRENTHOST=(
    "com.apple.ImageCapture"  "disableHotPlug"  "true"  "bool"
  )

  apply_security() {
    # ... standard tuples loop (as in dock.zsh) ...
    # currentHost tuples:
    defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
    # Guest account:
    if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
      warn "Guest account is enabled. Disabling it now (sudo required)..."
      sudo sysadminctl -guestAccount off
    fi
  }

  verify_security() {
    # ... iterate SECURITY_DEFAULTS + SECURITY_DEFAULTS_CURRENTHOST ...
    # Plus an additional check for sysadminctl -guestAccount status == "disabled".
    if sysadminctl -guestAccount status 2>&1 | grep -q "disabled"; then
      check "security.guest-account = disabled"
    else
      cross "security.guest-account: expected 'disabled', got 'enabled'"
      failed=1
    fi
    return $failed
  }
  ```

- **`os/shell-registration.zsh` skeleton (the bug-fix file):**
  ```zsh
  # os/shell-registration.zsh -- Register Homebrew zsh + chsh.
  # Always-on (no feature gate). Sourced by taskfiles/macos.yml's macos:shell task.

  set -euo pipefail
  source "${DOTFILEDIR}/install/messages.zsh"

  # BREW_ZSH passed in by the task as an env var (set from {{.BREW_ZSH}}).
  : "${BREW_ZSH:?BREW_ZSH must be set by the caller}"

  apply_shell_registration() {
    if ! grep -qxF "$BREW_ZSH" /etc/shells; then
      info "Adding Homebrew zsh to /etc/shells..."
      echo "$BREW_ZSH" | sudo tee -a /etc/shells > /dev/null
      success "Homebrew zsh added to /etc/shells"
    fi
    local current_shell
    current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk '{print $2}')
    if [[ "$current_shell" != "$BREW_ZSH" ]]; then
      info "Changing default shell from $current_shell to $BREW_ZSH..."
      chsh -s "$BREW_ZSH" || { error "chsh failed; run manually: chsh -s $BREW_ZSH"; exit 1; }
    fi
  }

  verify_shell_registration() {
    local failed=0 current_shell
    if grep -qxF "$BREW_ZSH" /etc/shells; then
      check "shell.brew-zsh-in-etc-shells"
    else
      cross "shell.brew-zsh-not-in-etc-shells (expected: $BREW_ZSH)"; failed=1
    fi
    current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk '{print $2}')
    if [[ "$current_shell" == "$BREW_ZSH" ]]; then
      check "shell.user-default = $BREW_ZSH"
    else
      cross "shell.user-default: expected '$BREW_ZSH', got '$current_shell'"; failed=1
    fi
    return $failed
  }
  ```

- **`taskfiles/macos.yml` skeleton (the key task shapes):**
  ```yaml
  version: '3'

  tasks:
    defaults:
      desc: "Apply macOS system defaults (per-concern, feature-gated)"
      platforms: [darwin]
      # lint-allow: cmds-without-status   (aggregator -- LINT-01/03a exemption)
      deps: [manifest:resolve]
      cmds:
        - task: defaults:dock
        - task: defaults:finder
        - task: defaults:input
        - task: defaults:screenshots
        - task: defaults:security

    defaults:dock:
      desc: "Apply Dock defaults"
      internal: true
      platforms: [darwin]
      deps: [manifest:resolve]
      cmds:
        - |
          set -euo pipefail
          export DOTFILEDIR="{{.TASKFILE_DIR}}"
          source "${DOTFILEDIR}/os/defaults/dock.zsh"
          apply_dock
      status:
        # Feature-gate: if macos-dock is off, status returns 0 (skip).
        - '{{if not (index .MANIFEST.features "macos-dock")}}true{{else}}false{{end}}'
        - |
          export DOTFILEDIR="{{.TASKFILE_DIR}}"
          source "${DOTFILEDIR}/os/defaults/dock.zsh"
          verify_dock > /dev/null 2>&1

    # ... defaults:finder, defaults:input, defaults:screenshots, defaults:security identical shape ...

    shell:
      desc: "Register Homebrew zsh as login shell (/etc/shells + chsh)"
      platforms: [darwin]
      vars:
        BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'
      cmds:
        - |
          set -euo pipefail
          export DOTFILEDIR="{{.TASKFILE_DIR}}"
          export BREW_ZSH="{{.BREW_ZSH}}"
          source "${DOTFILEDIR}/os/shell-registration.zsh"
          apply_shell_registration
      status:
        # Both conditions must hold: file marker AND user-default shell.
        - grep -qxF "{{.BREW_ZSH}}" /etc/shells
        - '[[ "$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk "{print \$2}")" = "{{.BREW_ZSH}}" ]]'

    validate:
      desc: "Validate macOS defaults match manifest expectations"
      platforms: [darwin]
      deps: [manifest:resolve]
      cmds:
        - |
          set -euo pipefail
          export DOTFILEDIR="{{.TASKFILE_DIR}}"
          source "${DOTFILEDIR}/install/messages.zsh"

          failed=0

          # Shell registration (always-on, always-validated).
          export BREW_ZSH="{{.HOMEBREW_PREFIX}}/bin/zsh"
          source "${DOTFILEDIR}/os/shell-registration.zsh"
          verify_shell_registration || failed=1

          # Per-concern validation, feature-gated.
          {{if index .MANIFEST.features "macos-dock"}}
          source "${DOTFILEDIR}/os/defaults/dock.zsh"   && (verify_dock   || failed=1)
          {{end}}
          {{if index .MANIFEST.features "macos-finder"}}
          source "${DOTFILEDIR}/os/defaults/finder.zsh" && (verify_finder || failed=1)
          {{end}}
          # ... input, screenshots, security ...

          exit $failed
  ```

- **`manifests/defaults.toml` `[features]` block after P6 migration:**
  ```toml
  [features]
  one-password-ssh = false
  one-password-signing = false
  motd = true
  claude-marketplace = true
  macos-dock = false            # NEW (P6)
  macos-finder = false          # existing (P3)
  macos-input = false           # NEW (P6)
  macos-screenshots = false     # NEW (P6)
  macos-security = false        # NEW (P6)
  ghostty = false
  jgrid-net = false
  ```

- **`manifests/machines/server-1.toml` `[features]` block after P6 migration:**
  ```toml
  [features]
  one-password-ssh = false
  motd = true
  claude-marketplace = false
  macos-security = true   # NEW (P6 D-04 -- per ROADMAP success #4)
  # macos-dock, macos-finder, macos-input, macos-screenshots stay absent
  # (inherited as false from defaults.toml).
  ```
  (Same edit on `server-2.toml`.)

- **`os/README.md` outline (planner finalizes):**
  ```
  # os/ -- macOS configuration

  ## Purpose
  Per-concern macOS defaults scripts + shell registration. Each concern is
  feature-gated; `task macos:defaults` orchestrates application; `task
  macos:validate` asserts current state against expected values.

  ## Files
  - `defaults/dock.zsh`         -- Dock keys (gated on `macos-dock`)
  - `defaults/finder.zsh`       -- Finder keys (gated on `macos-finder`)
  - `defaults/input.zsh`        -- Keyboard/trackpad keys (gated on `macos-input`)
  - `defaults/screenshots.zsh`  -- Screen capture keys (gated on `macos-screenshots`)
  - `defaults/security.zsh`     -- Security/privacy keys (gated on `macos-security`)
  - `shell-registration.zsh`    -- /etc/shells + chsh (always-on, no gate)

  ## Adding a new concern
  1. New file `os/defaults/<concern>.zsh` with `<CONCERN>_DEFAULTS` array + `apply_<concern>` + `verify_<concern>`.
  2. Add `features.macos-<concern>` to `manifests/defaults.toml` (default `false`).
  3. Add `macos:defaults:<concern>` task to `taskfiles/macos.yml` (sources the script, gates on the feature flag).
  4. Wire the task into the `macos:defaults` aggregator's `cmds:` list.
  5. Enable on machines that want it via their `manifests/machines/<name>.toml`.
  ```

</specifics>

<deferred>
## Deferred Ideas

### Owned by later phases (do not pull into P6 scope)
- **Root `task validate` composition** — Phase 8 (CUTV-01). P6 ships `task macos:validate` ready to compose.
- **`task links:reconcile` orphan detection** — Phase 8 (CUTV-02). No `os/` interaction.
- **`docs/CUTOVER.md` per-machine procedure** — Phase 8 (DOCS-08). The "what to do when guestAccount-off sudo prompt fires on a fresh server" notes live there.
- **`docs/MIGRATION.md` v1→v2 mapping** — Phase 8 (DOCS-05). The "v1 `taskfiles/macos.yml` defaults-{dock,finder,general,misc,appearance} ⇒ v2 `os/defaults/<concern>.zsh`" mapping table lives there.
- **v1 `taskfiles/macos.yml` deletion** — Phase 8. v1 file stays byte-stable until cutover completes.
- **Proposed LINT-10 (lint defaults-write-without-matching-defaults-read-in-status)** — Strongly recommended addition to `taskfiles/lint.yml`. Planner picks whether P6 ships it or it gets a follow-up plan against P2's lint suite.

### Future hardening (out of v1 scope)
- **`appearance.zsh` concern** — `NSGlobalDomain AppleInterfaceStyle = Dark`, `AppleIconAppearanceTheme = RegularDark` (v1 `defaults-appearance` carryover). Out of OSCF-01's five-concern enumeration; defer until josh names a need. If added: `features.macos-appearance` flag + `os/defaults/appearance.zsh`.
- **`preferences.zsh` concern** — `TextInputMenu visible`, `Siri StatusMenuVisible`, similar personal-preference toggles. Defer or fold into `security.zsh` as v1's misc catch-all (planner picks).
- **PlistBuddy `arrangeBy = grid` for desktop icon view** — v1 had it (fragile); P6 recommended drop. If josh misses the behavior, it becomes a P6+1 follow-up plan (or an addition to `os/defaults/finder.zsh`).
- **Per-machine override of defaults values** — D-02 keeps values in scripts. If josh ever wants per-machine value variation (e.g., bigger dock tilesize on work-laptop), it migrates to manifest-declared values then. v1 ships single-value-per-key.
- **`pmset` power management defaults** — `pmset -a sleep 30`, hibernate modes, etc. Out of v1; would land as `os/defaults/power.zsh` if added.
- **FileVault status / firewall toggle defaults** — `fdesetup` and `socketfilterfw` are more invasive than `defaults`; recommend a separate `os/admin/<concern>.zsh` namespace if added (and a separate feature flag scope). Out of v1.
- **Spotlight indexing config (`mds`/`mdutil`)** — out of v1.
- **`defaults read/write` schema validation across macOS versions** — Apple sometimes renames keys (`com.apple.dock orientation` is stable; some Finder keys have shifted across macOS releases). Recommend a one-line `sw_vers` log in `task macos:validate` output so a future drift across OS upgrades is greppable from CI logs. Out of v1; falls under P8 verification UX.

### Open questions for later (not blocking P6)
- **Should `verify_<concern>()` distinguish "key unset" from "key set to wrong value"?** Current sketch reports `expected 'X', got '<unset>'`. Acceptable; planner refines messaging if needed.
- **Does `chsh` need a `--shell` arg flag check?** macOS 14+ may have changed `chsh` semantics; sanity-check during execution. Falls under `os/shell-registration.zsh` apply path; non-blocking.
- **Should `killall Dock` (and `killall Finder`, `killall SystemUIServer`) be conditional?** Current sketch fires unconditionally on apply, suppressed with `|| true`. Idempotent (a no-op on a converged machine because the verify-gated status block keeps the task from running). Planner refines if cosmetic flicker becomes a UX issue.

</deferred>

---

*Phase: 06-os-defaults-macos-configuration*
*Context gathered: 2026-05-15*
