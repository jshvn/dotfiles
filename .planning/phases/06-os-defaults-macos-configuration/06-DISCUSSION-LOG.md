# Phase 6: OS Defaults — macOS Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 06-os-defaults-macos-configuration
**Areas discussed:** Feature-flag schema, Defaults values placement, shell-registration scope

---

## Gray Areas Presented (user-selection turn)

| Area | Description | Selected |
|------|-------------|----------|
| Feature-flag schema | Flat (`macos-dock`) vs nested (`macos-defaults.dock`) vs split alias-gate / defaults-gate flags | yes |
| Defaults values placement | Hardcoded in scripts vs declared in manifest vs hybrid | yes |
| Per-concern coverage | What keys land in dock/finder/input/screenshots/security? | deferred (Claude's Discretion) |
| shell-registration scope | Top-level vs nested, always-on vs gated, server inclusion | yes |

User selected three of four areas; per-concern coverage was deferred to Claude's Discretion (defaults recommended in CONTEXT.md, planner refines).

---

## Feature-Flag Schema

| Option | Description | Selected |
|--------|-------------|----------|
| Flat, reuse same flag for alias + defaults | Keep flat keys `macos-dock` / `macos-finder` / ...; `macos-finder` gates BOTH `shell/aliases/finder.zsh` (P3-wired) AND `os/defaults/finder.zsh`. Add the four missing keys to `defaults.toml`. Amend ROADMAP success #1 wording (`features.macos-defaults.dock` -> `features.macos-dock`). Zero machine-TOML migration cost. | yes |
| Nested namespace `macos-defaults.{concern}` | Match ROADMAP wording verbatim: `features.macos-defaults.dock`, `.finder`, etc. Shell-alias gate `macos-finder` stays untouched as a separate key. Cost: 4 machine TOMLs migrate; downstream code uses chained `index` calls. Cleanest semantic separation. | |
| Two flat keys per concern (alias + defaults) | `macos-finder` gates shell aliases; add `macos-defaults-finder` gating OS defaults. Most explicit -- could want alias without defaults or vice versa. Cost: doubles flag surface. | |

**User's choice:** Flat, reuse same flag for alias + defaults (Recommended)
**Notes:** Captured as **D-01** in CONTEXT.md. Locks the same-flag-two-consumers pattern: `macos-finder` means "this machine wants Finder customizations (aliases callable AND defaults applied)." ROADMAP success #1 wording gets a textual amend (same pattern as P5 D-02's success-#3 amend). All five flags (`macos-dock`, `macos-finder`, `macos-input`, `macos-screenshots`, `macos-security`) enumerate as `false` in `defaults.toml`.

Locked-by-ROADMAP-authority follow-on: **D-04** -- `server-1.toml` + `server-2.toml` gain `macos-security = true` per ROADMAP success criterion #4 ("only `shell-registration.zsh` and `security.zsh` run" on Mac servers that decline GUI defaults). Did not consume a question slot since the roadmap is explicit.

---

## Defaults Values Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded in `os/defaults/<concern>.zsh` + sibling validate | Each script declares an associative-array of `(domain, key, expected_value, write_type)` tuples; exposes `apply_<concern>()` and `verify_<concern>()` sourcing the same array. Taskfile cmds source and call `apply_<concern>`; status sources and calls `verify_<concern>`. Single source of truth per concern. OSCF-05 reads expected values from the scripts (not the manifest); manifest controls only on/off. | yes |
| Manifest declares per-concern value tables | `[macos-defaults.dock] tilesize = 45, mineffect = "genie"` in TOMLs. Scripts read `resolved.json` and apply. Most flexible (per-machine value overrides), most TOML schema surface, requires schema docs in `docs/MANIFEST.md`. | |
| Hybrid: scripts own values; manifest only gates | Same write path as Recommended, but `task validate` uses a separate `os/defaults/expected.zsh`. Two files per concern -- doubles author burden, splits source of truth. | |

**User's choice:** Hardcoded in `os/defaults/<concern>.zsh` + sibling validate (Recommended)
**Notes:** Captured as **D-02** in CONTEXT.md. The associative-array tuple shape (`domain key expected_value type`) is illustrated by the `os/defaults/dock.zsh` skeleton in the `<specifics>` section. `verify_<concern>()` enumerates every key (no fast-fail), by analogy with P5 D-07 (`packages:verify`). Planner's call whether scripts are sourced inline (`source ... && apply_dock`) or invoked with argv dispatch (`./os/defaults/dock.zsh apply|verify`) -- Claude's Discretion bullet in CONTEXT.md recommends sourcing.

---

## shell-registration Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Always-on for every macOS machine, no feature flag | `os/shell-registration.zsh` runs on every machine (laptops + servers). Idempotent: status checks `/etc/shells` AND `dscl UserShell`. Matches v1 behavior (v1 had no shell flag). Simplest. | yes |
| Gated on a new `features.homebrew-zsh` flag (default true) | Future-proof but no current need. Cost: one more manifest flag + extra index lookup in the task gate. | |
| Always-on for laptops; gated off for servers | Servers stay on system `/bin/zsh` -- faster, no `chsh` prompt; but their `.zshrc` (which assumes Homebrew zsh feature parity) would subtly break. | |

**User's choice:** Always-on for every macOS machine, no feature flag (Recommended)
**Notes:** Captured as **D-03** in CONTEXT.md. `os/shell-registration.zsh` is sibling to `os/defaults/`, not nested inside (per OSCF-01 wording). The `status:` block uses `{{.BREW_ZSH}}` template var, NOT `$BREW_ZSH` shell var -- this IS the structural fix for the v1 `macos:shell:145` bug (CONCERNS.md lines 15-19). LINT-02 enforces the template-var rule.

---

## Claude's Discretion

- **Per-concern coverage** -- user deferred area #4 to Claude. Recommended landing zones written into CONTEXT.md `<decisions>` Claude's Discretion section:
  - `dock.zsh`: v1 `defaults-dock` keys verbatim minus the `[[ "{{.PROFILE}}" == "server" ]]` `autohide` branch.
  - `finder.zsh`: v1 `defaults-finder` keys minus the fragile PlistBuddy `arrangeBy = grid` lines.
  - `input.zsh`: minimum starter (`swipescrolldirection = false`, hoisted from v1 `defaults-appearance`).
  - `screenshots.zsh`: minimum starter (`location`, `type`, `disable-shadow` + `killall SystemUIServer`).
  - `security.zsh`: v1 `defaults-general` + selected `defaults-misc` keys + `sysadminctl -guestAccount off` (sudo-gated). Drop `TextInputMenu`/`Siri` -- not security; out of P6 or future `preferences.zsh`.
- **`apply`/`verify` invocation pattern** -- recommend sourcing the script from the taskfile (no argv-dispatch indirection); planner picks.
- **`security.zsh` sudo handling for `sysadminctl -guestAccount off`** -- recommend inline sudo path (same as v1 lines 100-104); planner picks vs deferring to docs/CUTOVER.md.
- **`messages.zsh` sourcing inside each concern script** -- recommend inline (idempotent via double-source guard); planner picks.
- **Executable bit + shebang on `os/defaults/<concern>.zsh`** -- recommend sourced + shebang for editor support, no executable bit (matches `install/messages.zsh` pattern).
- **Validation enumeration order** -- alphabetical: dock, finder, input, screenshots, security.
- **Proposed LINT-10** (`defaults write` in cmds: must have matching `defaults read` in status:) -- strongly recommended addition to `taskfiles/lint.yml`; planner picks whether P6 ships it or files a P2 follow-up.

## Deferred Ideas

Captured in CONTEXT.md `<deferred>` section:

### Owned by later phases
- Root `task validate` composition -> Phase 8 (CUTV-01)
- `task links:reconcile` orphan detection -> Phase 8 (CUTV-02)
- `docs/CUTOVER.md` per-machine procedure -> Phase 8 (DOCS-08)
- `docs/MIGRATION.md` v1->v2 mapping -> Phase 8 (DOCS-05)
- v1 `taskfiles/macos.yml` deletion -> Phase 8 (parallel-rewrite invariant)
- Proposed LINT-10 -> P6 or P2 follow-up (planner picks)

### Future hardening (out of v1 scope)
- `appearance.zsh` concern (Dark mode keys from v1 `defaults-appearance`)
- `preferences.zsh` concern (TextInputMenu, Siri toggles)
- PlistBuddy `arrangeBy = grid` for desktop icon view
- Per-machine override of defaults values
- `pmset` power management defaults
- FileVault / firewall toggles
- Spotlight indexing config
- `sw_vers` log in `task macos:validate` output for OS-upgrade drift detection

### Open questions for later (not blocking P6)
- Should `verify_<concern>()` distinguish "key unset" vs "wrong value"?
- Does `chsh` need a `--shell` arg flag check on macOS 14+?
- Should `killall Dock` / `killall Finder` / `killall SystemUIServer` be conditional?
