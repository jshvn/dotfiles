# Phase 6: OS Defaults — macOS Configuration - Research

**Researched:** 2026-05-15
**Domain:** macOS `defaults` system, `go-task` template gating, `os/<concern>.zsh` script topology, idempotent install layer
**Confidence:** HIGH (verified on macOS 26.3.1 / arm64; go-task v3.37+; prior phase taskfiles)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: Flat keys, same flag for alias-gate + defaults-gate.** `defaults.toml [features]` gains `macos-dock = false`, `macos-input = false`, `macos-screenshots = false`, `macos-security = false`; `macos-finder = false` already present (P3 D-10). `macos-finder` consumed by both `shell/aliases/finder.zsh` (P3) AND `os/defaults/finder.zsh` (P6). All four `macos-*` keys are kebab-case → consumers MUST use `index .MANIFEST.features "macos-<concern>"`. ROADMAP success #1's `features.macos-defaults.dock` wording amends to `features.macos-dock` (flat).

- **D-02: Values hardcoded in `os/defaults/<concern>.zsh`; manifest gates are on/off only.** Each concern script declares an associative-array tuple list `(domain, key, expected_value, write_type)` at the top, exposes `apply_<concern>()` + `verify_<concern>()`, and shares the tuple list as the single source of truth for both write and verify. By analogy with P5 D-07, `verify_<concern>()` enumerates ALL keys (no fast-fail), prints check/cross per key, exits non-zero at end if any failed.

- **D-03: `os/shell-registration.zsh` runs unconditionally on every macOS machine. No feature flag.** Top-level under `os/` (NOT inside `os/defaults/`, per OSCF-01 wording). Status block uses `grep -qxF "{{.BREW_ZSH}}" /etc/shells` AND `[[ "$(dscl . -read /Users/$USER UserShell | awk '{print $2}')" = "{{.BREW_ZSH}}" ]]` — both with `{{.X}}` template vars only (LINT-02 compliance). **This is the structural fix for the v1 `macos:shell:145` `$BREW_ZSH`-in-status bug class.**

- **D-04: Server machines gain `macos-security = true`.** `manifests/machines/server-1.toml` and `server-2.toml` add `macos-security = true`. The other four `macos-*` keys stay absent → inherited `false`. Locks the server-behavior contract: `task install` on a server runs `macos:shell` + `macos:defaults:security` only.

### Claude's Discretion

- **apply/verify invocation pattern in the taskfile.** Recommend sourcing (`source os/defaults/dock.zsh && apply_dock`) over argv dispatch. If sourced, the script still carries `set -euo pipefail` per v2 convention.

- **Per-concern coverage.** Recommended landing zones:
  - `dock.zsh`: v1 keys verbatim (orientation, tilesize, mineffect, show-recents, mru-spaces, autohide) MINUS the `[[ "{{.PROFILE}}" == "server" ]]` branch on `autohide`.
  - `finder.zsh`: v1 keys (AppleShowAllExtensions, FXEnableExtensionChangeWarning, FXPreferredViewStyle). DROP the three PlistBuddy `arrangeBy = grid` lines (brittle).
  - `input.zsh`: minimum starter — `NSGlobalDomain com.apple.swipescrolldirection` (false); optionally KeyRepeat (2) + InitialKeyRepeat (15).
  - `screenshots.zsh`: minimum starter — location ($HOME/Pictures/Screenshots), type (png), disable-shadow (true), `killall SystemUIServer` after apply.
  - `security.zsh`: v1 screensaver keys + ImageCapture disableHotPlug (with `-currentHost`) + sysadminctl -guestAccount off. DROP TextInputMenu visible and Siri StatusMenuVisible (personal preference, not security).
  - DROP NSGlobalDomain AppleInterfaceStyle = Dark and AppleIconAppearanceTheme = RegularDark (not in OSCF-01's five concerns).

- **security.zsh sudo prompt for sysadminctl -guestAccount off** — wrap in `if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then sudo sysadminctl -guestAccount off; fi`; verify path is unprivileged.

- **messages.zsh sourcing inside os/defaults/<concern>.zsh** — Cleaner to source from inside each concern script (idempotent — messages.zsh is double-source-guarded).

- **Validation enumeration order** — dock → finder → input → screenshots → security (matches OSCF-01 enumeration order).

- **Executable bit + shebang on os/defaults/<concern>.zsh** — Recommend sourced + shebang line for editor support, no executable bit (matches `install/messages.zsh` pattern).

- **One-screen lint hook (LINT-10 candidate)** — "any `defaults write` line in a cmds: block must have a matching `defaults read` in the same task's status:". Strongly recommended; planner picks ship-now or follow-up.

### Deferred Ideas (OUT OF SCOPE)

- Root `task validate` composition (P8 / CUTV-01).
- `task links:reconcile` orphan detection (P8 / CUTV-02).
- `docs/CUTOVER.md` per-machine procedure (P8 / DOCS-08).
- `docs/MIGRATION.md` v1→v2 mapping (P8 / DOCS-05).
- v1 `taskfiles/macos.yml` deletion (P8; parallel-rewrite invariant).
- LINT-10 (lint defaults-write-without-matching-defaults-read-in-status) — may ship in P6 or as follow-up against P2 lint suite.
- `appearance.zsh` concern (Dark mode etc.) — future hardening, not in OSCF-01 enumeration.
- `preferences.zsh` concern (TextInputMenu, Siri StatusMenuVisible) — defer or fold into security.zsh.
- PlistBuddy `arrangeBy = grid` desktop icon view — drop in v1 P6; future plan if needed.
- Per-machine override of defaults values — values live in scripts (D-02); if per-machine variation needed later, migrate to manifest values.
- `pmset` power management defaults.
- FileVault status / firewall toggle defaults.
- Spotlight indexing config (`mds` / `mdutil`).
- `defaults read/write` schema validation across macOS versions.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OSCF-01 | macOS defaults split into per-concern files (`os/defaults/dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh`) | Five concern files + `os/shell-registration.zsh` topology fully sketched in `<specifics>`; D-02 tuple-array shape verified. `os/` directory already exists (P1 created `os/README.md` stub). |
| OSCF-02 | Each defaults group is gated by a manifest feature flag — opt-in per machine | `index .MANIFEST.features "macos-<concern>"` pattern confirmed against `taskfiles/identity.yml` (`features.one-password-ssh` precedent); kebab-case requires `index` form per CLAUDE.md. **Critical finding (Pitfall #1 below):** the two-line status pattern in the CONTEXT skeleton is broken; needs a single-block template-prefixed status. |
| OSCF-03 | Every defaults task has a `status:` that reads `defaults read <domain> <key>` before writing | Verified on macOS 26.3.1: bool reads as `1`/`0` (not `true`/`false`); strings/ints read raw; missing keys exit 1 with stderr noise. `verify_<concern>()` must normalize per-type. |
| OSCF-04 | `os/shell-registration.zsh` adds Homebrew zsh to `/etc/shells` and runs `chsh` with correct `{{.BREW_ZSH}}` template-var `status:` check | The structural fix for the v1 `macos:shell:145` bug class (`taskfiles/macos.yml:145` uses `$BREW_ZSH` shell var; v2 uses `{{.BREW_ZSH}}` task template var). Verified dscl pattern + /etc/shells idempotency on real machine. |
| OSCF-05 | `task validate` reads current defaults values for declared keys and asserts them against in-script expected values | `task macos:validate` enumerates enabled concerns (deps: `manifest:resolve`), sources each `os/defaults/<concern>.zsh` whose feature gate is true, calls `verify_<concern>()`. Composed into root `task validate` in P8 (CUTV-01). |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These directives are binding on every plan; the planner MUST verify each new task body against this list before approving:

| Directive | Source | P6 Impact |
|-----------|--------|-----------|
| Flat directories in v1 (no `os/darwin/` nesting) | `CLAUDE.md` + `.claude/CLAUDE.md` | `os/defaults/<concern>.zsh` + `os/shell-registration.zsh` at flat depth; no platform sub-tree. |
| One concept per file | Global + project | One concern per `os/defaults/<concern>.zsh`. |
| `status:` blocks use `{{.X}}` template vars only — NEVER `$X` | LINT-02 + CONCERNS.md lines 15-19 | The v1 bug class P6 structurally fixes. `os/shell-registration.zsh` task uses `{{.BREW_ZSH}}` (template-resolved) where v1 used `$BREW_ZSH` (unset in status eval). |
| Kebab-case feature keys need `index` form | CLAUDE.md | All four new gates: `{{if index .MANIFEST.features "macos-dock"}}` (etc.). |
| `set -euo pipefail` on every executable `.zsh` | LINT-04 | `os/shell-registration.zsh` and `os/defaults/<concern>.zsh` carry it (even though sourced — v2 convention, P4 CF-06). |
| No hardcoded `/opt/homebrew` or `/usr/local` | CLAUDE.md | `os/shell-registration.zsh` uses `${HOMEBREW_PREFIX}/bin/zsh` (resolved at task-graph build time). |
| Symlinks via `_:safe-link` only | LINT-03b | P6 has no symlinks; not applicable. |
| No AI attribution; no emojis (markdown included) | Global + project, hook-enforced | Every file P6 ships. |
| `defaults read/write` and `dscl` trip LINT-05 (warn-only) | `taskfiles/lint.yml:247` | `os/defaults/*.zsh` and `os/shell-registration.zsh` WILL produce LINT-05 warnings. By design — LINT-05 is non-blocking (`exit 0`). |
| Every install task has a `status:` block | LINT-01 | All five `macos:defaults:<concern>` tasks + `macos:shell` carry status. Aggregator `macos:defaults` omits status with `# lint-allow: cmds-without-status` marker. |
| File-level comment block at top of every script | CLAUDE.md | Every `os/<...>.zsh` file. |

## Summary

Phase 6 ports v1's monolithic `taskfiles/macos.yml` (184 lines, 7 task entries, 4 known correctness defects) into a per-concern layout that closes three v1 bug classes simultaneously:

1. The **`$BREW_ZSH`-in-status bug** (CONCERNS.md lines 15-19; `taskfiles/macos.yml:145`) — fixed by using `{{.BREW_ZSH}}` template var that the task engine resolves at task-graph build time (verified pattern; identity.yml + packages.yml conform).
2. The **profile-branching bug class** (Out of Scope in REQUIREMENTS.md: "Inline profile branching in shared files — replaced by manifest feature gates") — fixed by deleting the v1 `[[ "{{.PROFILE}}" == "server" ]] && echo false || echo true` branch on `defaults-dock` autohide; servers won't have `macos-dock = true` in v2 so the branch is structurally dead.
3. The **single-monolith maintenance bug** — fixed by splitting into one-concern-per-file scripts where each `<CONCERN>_DEFAULTS` associative array is the single source of truth for both `apply_<concern>()` write and `verify_<concern>()` read.

The 5 concern scripts plus `os/shell-registration.zsh` are sourced (not executed) by `taskfiles/macos.yml` tasks; each task's `cmds:` invokes `apply_<concern>` and each task's `status:` invokes `verify_<concern>`. Feature gating happens via template-rendered `index .MANIFEST.features "macos-<concern>"`. `task macos:validate` (OSCF-05) sources every enabled concern script and calls each `verify_<concern>()` — composed into the root `task validate` by P8.

**Primary recommendation:** Use a **single-line shell-block `status:`** that begins with `{{if not (index .MANIFEST.features "macos-<concern>")}}exit 0{{end}}` and then continues with the `source` + `verify_<concern>` call. This is the only correct way to combine the feature-gate AND the verify check because go-task ANDs multi-line status entries (verified against taskfile.dev/usage) — a two-line status of `[feature-gate-renders-true-or-false, verify_dock]` would spuriously re-run the task on a converged machine with the feature OFF (verify_dock would fail because no defaults are written → AND fails → task runs). The CONTEXT.md skeleton's two-line shape is incorrect on this point and must be replaced before implementation.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Manifest feature gating (kebab-case `macos-*` keys) | Manifest layer (`resolved.json` via `ref: fromJson`) | Taskfile templates (`index .MANIFEST.features "macos-<concern>"`) | Single source of truth; same flag consumed by P3 alias scripts AND P6 defaults scripts. |
| Per-key write logic (`defaults write <domain> <key> -<type> <value>`) | `os/defaults/<concern>.zsh` `apply_<concern>()` | Taskfile `cmds:` (sources + invokes) | Script owns the tuple list; taskfile is a thin invocation. |
| Per-key read logic (`defaults read <domain> <key>` + normalization) | `os/defaults/<concern>.zsh` `verify_<concern>()` | Taskfile `status:` (single-block render of feature-gate + sourced verify) | Same script; same tuple list; idempotency contract OSCF-03. |
| Shell-registration (Homebrew zsh in `/etc/shells` + `chsh`) | `os/shell-registration.zsh` | Taskfile `macos:shell` task | Always-on (no gate); `${BREW_ZSH}` env var injected by taskfile from `{{.BREW_ZSH}}` template var (LINT-02 compliance). |
| Sudo elevation (`/etc/shells` append, `sysadminctl -guestAccount off`) | Script body (sudo guarded by an `if` check) | — | Verify path stays unprivileged; apply path prompts on first-install only. |
| Validation orchestration (`task macos:validate`) | Taskfile `macos:validate` | `os/defaults/<concern>.zsh` `verify_<concern>()` + `os/shell-registration.zsh` `verify_shell_registration()` | Always-rerun aggregator (status: [false] per P5 D-07 / LINT-03a pattern). |
| Killall side-effects (`killall Dock` / `killall Finder` / `killall SystemUIServer`) | `apply_<concern>()` body (suppressed with `|| true`) | — | Idempotency-safe: status gating means killall only fires when a write actually happened. |
| Manifest TOML schema (4 new `[features]` keys + 2 server enablements) | `manifests/defaults.toml` + `manifests/machines/server-{1,2}.toml` | `docs/MANIFEST.md` schema reference | P1 D-15 pattern; flat key namespace. |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `go-task` | 3.37+ | Taskfile engine with `ref: fromJson` for manifest reads and template `index`/`not` functions | Already in use; P1 D-14 + P2/P4/P5 confirmed; `ref:` is required for kebab-key `index` access (CF-02). |
| `defaults` (macOS built-in) | macOS 14+ (verified on 26.3.1 / arm64) | Reads/writes user defaults; supports `-bool`, `-int`, `-string`, `-float`, `-currentHost` scope | Apple's canonical tool; no alternative exists for system defaults. [VERIFIED: man defaults; tested on macOS 26.3.1] |
| `dscl` (macOS built-in) | macOS 14+ | Reliable read of login shell (`dscl . -read /Users/$USER UserShell`) — more reliable than `$SHELL` which reflects current process | Already used by v1 `taskfiles/macos.yml:130`. [VERIFIED: tested — returns `UserShell: /opt/homebrew/bin/zsh`, exit 0] |
| `sysadminctl` (macOS built-in) | macOS 14+ | Guest-account state and read (`sysadminctl -guestAccount status\|on\|off`) | Apple-canonical; required for guest-account toggle. [VERIFIED: tested — `sysadminctl -guestAccount status` exits 0 unprivileged, prints `Guest account disabled.` to stderr.] |
| `chsh` (macOS built-in) | macOS 14+ | Sets user login shell; requires target shell to be in `/etc/shells` | Apple-canonical for shell registration. [CITED: ss64.com/mac/chsh] |
| `messages.zsh` | repo-local | `info`/`success`/`warn`/`error`/`check`/`cross` UX helpers | P1 deliverable; reused by P2/P3/P4/P5; double-source-guarded. |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `jq` | 1.7+ | Already on PATH (P5 dep); not needed by P6 scripts directly | Only if planner adds a manifest re-read inside a script (the taskfile already does it via `MANIFEST` ref). |
| `awk` | macOS built-in | Extract `dscl` UserShell field | `awk '{print $2}'` on the `UserShell: <path>` line. |
| `grep` (GNU `ggrep`) | from Homebrew `core.rb` | Lint suite uses `ggrep -E` — not needed by P6 scripts; default `grep -qxF` for `/etc/shells` membership check is portable | `grep -qxF` is BSD-compatible. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `defaults read` for verify | `defaults read-type` | `read-type` returns `Type is boolean`/`Type is integer`/etc. — useful for type validation but doesn't expose the value; would still need a value read. **Recommend `defaults read` + per-type normalization.** [VERIFIED: tested both forms.] |
| PlistBuddy for `arrangeBy = grid` | (Drop) | v1 wraps in `2>/dev/null \|\| true` precisely because the keys may not exist until Finder has been launched once on a fresh machine. **Recommend drop** per Claude's Discretion in CONTEXT. |
| Sourced concern script | Argv-dispatch (`./dock.zsh apply`) | Sourcing avoids fork-per-invocation cost AND allows `typeset -ga` array sharing across apply/verify. **Recommend sourcing** per Claude's Discretion. |
| One-script-per-concern | Sub-key splitting (e.g., `os/defaults/dock-orientation.zsh` per key) | Granularity explosion; loses tuple-array single-source-of-truth shape. **Reject.** |
| `defaults write` literal `-bool true` | Branch on machine context | v1 had the dead `autohide` branch; v2 deletes it per D-01 (servers don't run `macos-dock`). |
| `$SHELL` for current shell read | `dscl . -read /Users/$USER UserShell` | `$SHELL` reflects the running shell process, NOT the registered login shell — wrong source of truth post-`chsh`. **Use dscl** (already in v1; CONTEXT confirms.) [CITED: ss64.com/mac/dscl] |

**Installation:** No new packages. P6 uses existing macOS built-ins + repo-local `messages.zsh` + go-task already on PATH.

**Version verification:**
```bash
# All tools verified present on the current Apple Silicon test machine:
$ sw_vers      # ProductVersion: 26.3.1
$ uname -m     # arm64
$ go-task --version  # (Phase 1 dep; assumed >= 3.37)
$ defaults read com.apple.dock autohide  # returns "1" — verified
$ dscl . -read /Users/$USER UserShell    # returns "UserShell: /opt/homebrew/bin/zsh" — verified
$ sysadminctl -guestAccount status       # returns "Guest account disabled." — verified
```

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                  manifests/defaults.toml + machines/<name>.toml      │
│                  (TOML; deep-merge → resolved.json by P1 resolver)   │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ `task setup -- <name>` → resolved.json
                                   ▼
                       ┌─────────────────────────────┐
                       │ $XDG_STATE_HOME/dotfiles/   │
                       │ resolved.json               │
                       │  .features.macos-dock       │
                       │  .features.macos-finder     │
                       │  .features.macos-input      │
                       │  .features.macos-screenshots│
                       │  .features.macos-security   │
                       └──────────────┬──────────────┘
                                      │ ref: fromJson .MANIFEST_JSON
                                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│ taskfiles/macos.yml          (root Taskfile.yml includes macos:)     │
│                                                                       │
│  macos:defaults  (aggregator; lint-allow: cmds-without-status)        │
│    ├─ task: defaults:dock          ──┐                                │
│    ├─ task: defaults:finder          │                                │
│    ├─ task: defaults:input           │ each gated on                  │
│    ├─ task: defaults:screenshots     │ index .MANIFEST.features       │
│    └─ task: defaults:security        │ "macos-<concern>"              │
│                                    ──┘                                │
│  macos:shell    (always-on; no gate; vars.BREW_ZSH from HOMEBREW_PREFIX)│
│  macos:validate (D-07 enumerate-all; composed into root validate / P8) │
└────────┬─────────────────────────┬──────────────────────────┬─────────┘
         │ cmds: source + apply_X  │ status: feature-gate-OR  │ deps:
         │                         │ short-circuit + verify_X │ manifest:resolve
         ▼                         ▼                          ▼
┌────────────────────────────────────────────────────────────────────────┐
│ os/                                                                     │
│  ├─ defaults/                                                           │
│  │   ├─ dock.zsh           [DOCK_DEFAULTS + apply_dock + verify_dock]   │
│  │   ├─ finder.zsh         [FINDER_DEFAULTS + apply_finder + verify_…]  │
│  │   ├─ input.zsh          [INPUT_DEFAULTS + apply_input + verify_…]    │
│  │   ├─ screenshots.zsh    [SHOTS_DEFAULTS + apply_shots + verify_…]    │
│  │   └─ security.zsh       [SECURITY_DEFAULTS + SECURITY_DEFAULTS_CURRENTHOST │
│  │                          + apply_security (incl. sysadminctl)         │
│  │                          + verify_security]                          │
│  ├─ shell-registration.zsh [apply_shell_registration + verify_…]        │
│  └─ README.md              [DOCS-02 anchor; mirrors shell/README.md]    │
└────────────────────────────────────────────────────────────────────────┘
         │
         │ each *.zsh sources install/messages.zsh
         ▼
┌────────────────────────────────────────────────────────────────────────┐
│ install/messages.zsh        check/cross/info/success/warn/error         │
│                             (double-source-guarded line 20-21)          │
└────────────────────────────────────────────────────────────────────────┘
```

**Data flow (per task):**

1. User runs `task install` → root Taskfile.yml call graph dispatches `task: macos:defaults` then `task: macos:shell` (already wired at Taskfile.yml:142-143; the include target flips from `macos-stub.yml` to `macos.yml`).
2. `macos:defaults` aggregator dispatches each `macos:defaults:<concern>` sub-task in declared order.
3. Each sub-task's `status:` (a single shell block) renders the feature gate at template time, exits 0 immediately if the feature is off, otherwise sources the concern script and calls `verify_<concern> >/dev/null 2>&1`.
4. On status failure (verify mismatch OR feature gate fails to short-circuit because it's enabled), the sub-task's `cmds:` block runs: source the concern script, call `apply_<concern>`.
5. `apply_<concern>` iterates the tuple array, issuing `defaults write <domain> <key> -<type> <value>` per row.
6. Side effects: `killall Dock` / `killall Finder` / `killall SystemUIServer` triggers in respective apply functions (suppressed with `|| true` so killing an unrunning UI process is a no-op).
7. `task macos:validate` (separate from install path; composed into root `task validate` by P8): always-rerun aggregator; for each concern with a `true` feature gate, sources the script and calls `verify_<concern>`; aggregates exit code.

### Recommended Project Structure

```
os/
├── README.md                  # DOCS-02 anchor (purpose / files / adding-a-pattern)
├── shell-registration.zsh     # /etc/shells + chsh; always-on; sourced by macos:shell task
└── defaults/
    ├── dock.zsh               # DOCK_DEFAULTS + apply_dock + verify_dock
    ├── finder.zsh             # FINDER_DEFAULTS + apply_finder + verify_finder
    ├── input.zsh              # INPUT_DEFAULTS + apply_input + verify_input
    ├── screenshots.zsh        # SHOTS_DEFAULTS + apply_screenshots + verify_screenshots
    └── security.zsh           # SECURITY_DEFAULTS [+ _CURRENTHOST] + apply_security + verify_security

taskfiles/
└── macos.yml                  # Replaces taskfiles/macos-stub.yml
                                # Tasks: defaults, defaults:dock..security, shell, validate
                                # File-header convention matches taskfiles/identity.yml line 1-44 verbatim

manifests/
├── defaults.toml              # [features] gains macos-dock/input/screenshots/security (= false)
└── machines/
    ├── server-1.toml          # [features] gains macos-security = true
    └── server-2.toml          # [features] gains macos-security = true
```

### Pattern 1: Source-only concern script (D-02 tuple-array shape)

**What:** Each `os/defaults/<concern>.zsh` is a sourced-only zsh file with three exports:
- A `typeset -ga <CONCERN>_DEFAULTS=(...)` flat array of 4-tuples `(domain, key, expected_value, write_type)`.
- An `apply_<concern>()` function that iterates the array and calls `defaults write` per row.
- A `verify_<concern>()` function that iterates the array, calls `defaults read`, normalizes per-type, prints check/cross per key, returns the failure count.

**When to use:** Every concern in `os/defaults/`. Single source of truth: the same tuple list drives write and verify, so adding a key requires editing exactly one line.

**Example (from CONTEXT specifics; verified against macOS 26.3.1 actual read output):**
```zsh
# Source: .planning/phases/06-os-defaults-macos-configuration/06-CONTEXT.md lines 234-291
# os/defaults/dock.zsh -- Dock defaults (gated on features.macos-dock).
set -euo pipefail
source "${DOTFILEDIR}/install/messages.zsh"

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
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
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

**Verified read normalization (from real macOS 26.3.1 reads):**
- `defaults read com.apple.dock autohide` → `1` (bool → `0`/`1`)
- `defaults read com.apple.dock tilesize` → `45` (int → raw)
- `defaults read com.apple.dock orientation` → `bottom` (string → raw, no quotes)
- `defaults read com.apple.dock mineffect` → `genie` (string → raw)
- `defaults read com.apple.dock <missing-key>` → exit 1 with stderr line `... does not exist`

The `2>/dev/null || echo "<unset>"` pattern in the sketch is correct: stderr suppressed, `<unset>` sentinel placed for the comparison so the cross-line prints `expected '1', got '<unset>'` instead of an empty value.

### Pattern 2: Single-shell-block status (closes the OSCF-02 + ANDed-status issue)

**What:** Status block is a single shell command that renders the feature gate at template build time and short-circuits with `exit 0` when the feature is off; only runs verify when the feature is on.

**When to use:** Every `macos:defaults:<concern>` task. Replaces the CONTEXT skeleton's two-line status (which is broken — see Pitfall #1).

**Example:**
```yaml
defaults:dock:
  desc: "Apply Dock defaults"
  internal: true
  platforms: [darwin]
  deps: [":manifest:resolve"]
  cmds:
    - |
      set -euo pipefail
      export DOTFILEDIR="{{.TASKFILE_DIR}}"
      {{if not (index .MANIFEST.features "macos-dock")}}exit 0{{end}}
      source "${DOTFILEDIR}/os/defaults/dock.zsh"
      apply_dock
  status:
    - |
      export DOTFILEDIR="{{.TASKFILE_DIR}}"
      {{if not (index .MANIFEST.features "macos-dock")}}exit 0{{end}}
      source "${DOTFILEDIR}/os/defaults/dock.zsh"
      verify_dock > /dev/null 2>&1
```

When `macos-dock = false`:
- Template renders `exit 0` at the second line of both status and cmds.
- `status:` script: `exit 0` → status passes → task skips. (cmds never runs.)
- Net: feature-off machines are a no-op at the task level (success criterion #4).

When `macos-dock = true`:
- Template renders empty at the second line.
- `status:` script: sources script, runs `verify_dock`, exits with its return code.
- If verify exits 0 (converged): task skips.
- If verify exits non-zero (drifted): cmds runs, `apply_dock` writes defaults, `killall Dock`.

**Note on `TASKFILE_DIR`:** go-task 3.37+ provides `{{.TASKFILE_DIR}}` as the directory of the invoked taskfile root. When `macos.yml` is included from the root `Taskfile.yml`, `{{.TASKFILE_DIR}}` resolves to the repo root — so `${DOTFILEDIR}` is correct. The root Taskfile.yml at line 44 sets `DOTFILEDIR: '{{.TASKFILE_DIR}}'`; identity.yml and packages.yml use the same `sh: dirname "{{.TASKFILE_DIR}}"` fallback for direct invocation.

### Pattern 3: Aggregator with no status

**What:** `macos:defaults` aggregator dispatches the per-concern tasks via `task:` delegations — no `cmds:` shell, no `status:`. The LINT-03a exemption is the "all-task-delegations" auto-rule in lint.yml line 188-195.

**When to use:** Whenever a task's body is purely orchestration of sub-tasks (no inline shell). Mirrors `identity.yml validate` and `packages.yml validate`.

**Example:**
```yaml
defaults:
  desc: "Apply macOS system defaults (per-concern, feature-gated)"
  platforms: [darwin]
  # lint-allow: cmds-without-status  (aggregator — LINT-01/03a exemption)
  deps: [":manifest:resolve"]
  cmds:
    - task: defaults:dock
    - task: defaults:finder
    - task: defaults:input
    - task: defaults:screenshots
    - task: defaults:security
```

### Pattern 4: Always-rerun aggregator (validate)

**What:** `macos:validate` is always-rerun (drift detection by design). Use `status: [false]` for the structural LINT-03a satisfier; carry the `# lint-allow: cmds-without-status` marker on the line above for documentation. Identical to P5 `packages:verify` and `packages:audit` (see `taskfiles/packages.yml:184-201`).

**When to use:** Any validate / drift-detect task that should always run.

**Example:**
```yaml
# lint-allow: cmds-without-status
validate:
  desc: "Validate macOS defaults match in-script expected values"
  platforms: [darwin]
  deps: [":manifest:resolve"]
  status: [false]
  cmds:
    - |
      set -euo pipefail
      {{.DOTFILES_MESSAGES}}
      export DOTFILEDIR="{{.TASKFILE_DIR}}"
      export BREW_ZSH="{{.HOMEBREW_PREFIX}}/bin/zsh"

      failed=0

      # Always-on: shell registration.
      source "${DOTFILEDIR}/os/shell-registration.zsh"
      verify_shell_registration || failed=1

      # Per-concern, feature-gated.
      {{if index .MANIFEST.features "macos-dock"}}
      source "${DOTFILEDIR}/os/defaults/dock.zsh"
      verify_dock || failed=1
      {{end}}
      {{if index .MANIFEST.features "macos-finder"}}
      source "${DOTFILEDIR}/os/defaults/finder.zsh"
      verify_finder || failed=1
      {{end}}
      {{if index .MANIFEST.features "macos-input"}}
      source "${DOTFILEDIR}/os/defaults/input.zsh"
      verify_input || failed=1
      {{end}}
      {{if index .MANIFEST.features "macos-screenshots"}}
      source "${DOTFILEDIR}/os/defaults/screenshots.zsh"
      verify_screenshots || failed=1
      {{end}}
      {{if index .MANIFEST.features "macos-security"}}
      source "${DOTFILEDIR}/os/defaults/security.zsh"
      verify_security || failed=1
      {{end}}

      exit "$failed"
```

### Pattern 5: `macos:shell` BREW_ZSH injection (structural LINT-02 fix)

**What:** The shell-registration task carries `vars: BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'` at task level. The `cmds:` exports `BREW_ZSH="{{.BREW_ZSH}}"` and sources the script. The `status:` ALSO uses `{{.BREW_ZSH}}` (template var — resolved at task-graph build time). The script uses `${BREW_ZSH}` shell var (legal inside script bodies; LINT-02 only flags `$VAR` in `status:`).

**When to use:** Any task that needs a value-from-Homebrew-prefix in both `cmds:` and `status:`.

**Example:**
```yaml
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
    # Both conditions ANDed; both use {{.X}} template vars (LINT-02).
    - grep -qxF "{{.BREW_ZSH}}" /etc/shells
    - '[[ "$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk "{print \$2}")" = "{{.BREW_ZSH}}" ]]'
```

**Comparison vs v1 bug (CONCERNS.md lines 15-19; `taskfiles/macos.yml:145`):**
```yaml
# v1 (BROKEN — $BREW_ZSH unset in status eval context, task re-runs every install):
status:
  - grep -qxF "$BREW_ZSH" /etc/shells

# v2 (FIXED — template var resolves at task-graph build time):
status:
  - grep -qxF "{{.BREW_ZSH}}" /etc/shells
```

### Anti-Patterns to Avoid

- **`$VAR` in `status:` blocks** — LINT-02 blocking. The v1 `macos:shell:145` bug class. Always use `{{.VAR}}` template vars in status.
- **Two-line status with template-rendered `true`/`false` + `verify_X`** — Breaks under ANDed multi-line status semantics. Use the single-block pattern (Pattern 2). See Pitfall #1 below.
- **Profile branching** (`[[ "{{.PROFILE}}" == "server" ]]`) — Forbidden by REQUIREMENTS Out of Scope ("Inline profile branching in shared files — replaced by manifest feature gates"). The v1 `defaults-dock` autohide branch dies in v2.
- **PlistBuddy without `2>/dev/null \|\| true`** — PlistBuddy fails when intermediate plist keys don't exist (e.g., desktop icon view settings before Finder has been launched). v2 drops the `arrangeBy = grid` keys entirely per Claude's Discretion; if a future need emerges, wrap consistently.
- **`hostname`-based detection anywhere** — Out of Scope (REQUIREMENTS line 211); the v1 `.zprofile:55` bug class.
- **`$SHELL` for current registered shell** — `$SHELL` reflects the currently-running process, NOT the registered login shell. Use `dscl . -read /Users/$USER UserShell`.
- **Sudo before checking state** — `sysadminctl -guestAccount off` requires sudo, but `sysadminctl -guestAccount status` does not. Always check status first.
- **Killing UI apps without `\|\| true` suffix** — On a server or fresh-install moment, the Dock/Finder/SystemUIServer process may not be running; `killall` exits 1 → script fails. Wrap with `\|\| true`.
- **Sourcing `messages.zsh` without `${DOTFILEDIR}` set** — `${DOTFILEDIR}` MUST be exported by the taskfile cmd block before sourcing the concern script. The current root Taskfile.yml resolves `DOTFILEDIR` at line 44 via `{{.TASKFILE_DIR}}`; the included `macos.yml` receives it on include but the cmds: heredoc still needs `export DOTFILEDIR="{{.TASKFILE_DIR}}"` explicit. (Identity.yml + packages.yml do the same.)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Read current `defaults` value with stable exit semantics | Custom plist parser, PlistBuddy walk, or `awk` over `defaults read <domain>` output | `defaults read <domain> <key>` directly | Direct read returns just the value; missing keys exit 1 (so verify can detect "unset"). [VERIFIED on macOS 26.3.1] |
| Determine bool round-trip | Re-derive bool truthiness | Hardcoded `case "$type" in bool) ...`, normalize `true`→`1`, `false`→`0` for comparison | `defaults write -bool true` writes `<true/>` in the plist; `defaults read` reads it back as `1` literal. Type-aware compare is the only correct path. [VERIFIED] |
| Resolve login shell from current process | Read `$SHELL` env var | `dscl . -read /Users/$USER UserShell \| awk '{print $2}'` | `$SHELL` reflects the running shell, not the registered login shell. Already in v1 macos.yml:130 and CONTEXT D-03. [CITED: ss64.com/mac/dscl] |
| Check `/etc/shells` membership | Read+grep with substring | `grep -qxF "<full-path>" /etc/shells` | `-x` matches whole-line; `-F` makes the pattern literal — avoids partial matches like `/usr/local/bin/zsh-5.9` matching `/usr/local/bin/zsh`. |
| Resolve Homebrew prefix | Hardcode `/opt/homebrew` or `/usr/local` | `{{.HOMEBREW_PREFIX}}` (task context) or `${HOMEBREW_PREFIX}` (shell context) | Root Taskfile.yml lines 47-52 resolves via `uname -m`. CLAUDE.md hard-codes this rule. |
| Set guest-account state | Custom `dscl` write | `sysadminctl -guestAccount off` (sudo) + `sysadminctl -guestAccount status` (unprivileged read) | Apple-canonical; idempotent (status check before write). [VERIFIED on macOS 26.3.1: `sysadminctl -guestAccount status` exits 0 unprivileged, prints `Guest account disabled.` to stderr.] |
| Append to `/etc/shells` | `echo "$path" >> /etc/shells` | `echo "$path" \| sudo tee -a /etc/shells > /dev/null` (and gate on `grep -qxF` first) | Avoids duplicates; safer permission model than direct write redirection. v1 pattern + CONTEXT skeleton verified. |
| Per-concern feature gating | Branch on `{{.PROFILE}}` | `{{if index .MANIFEST.features "macos-<concern>"}}` | Manifest-as-truth contract; v1 profile branching forbidden. |
| `messages.zsh` re-implementation | Inline echo with color codes | `source "${DOTFILEDIR}/install/messages.zsh"; check "..." / cross "..."` | Existing helper; double-source-guarded line 20-21. |

**Key insight:** Phase 6's surface area is small (5 concern scripts + 1 shell-registration script + 1 taskfile + 5 manifest deltas + 1 README) but every script touches macOS-canonical tooling. The hand-roll temptations are: (a) implementing a "smart" defaults-value normalizer that handles every type — instead, lean on `defaults read`'s exit-1 semantics + a per-type case; (b) writing custom UI-process restart logic — `killall` + `|| true` is the right primitive.

## Runtime State Inventory

> Phase 6 is a parallel rewrite + manifest schema migration. The runtime systems affected are macOS preferences (per-user plist files), system-level user-shell registration, and the live Dock/Finder/SystemUIServer UI processes. No rename of identifiers happens (the `macos-*` flag namespace is being EXTENDED, not renamed).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `~/Library/Preferences/com.apple.dock.plist`, `com.apple.finder.plist`, `com.apple.screensaver.plist`, `com.apple.screencapture.plist`, `~/Library/Preferences/ByHost/com.apple.ImageCapture.<HW-UUID>.plist`, `/Library/Preferences/com.apple.loginwindow.plist` (guest account). These are macOS-managed; `defaults read/write` IS the migration path. P6 is itself the install/migrate logic. | None separate — `apply_<concern>()` is the migration; `verify_<concern>()` is the post-state assertion. |
| Live service config | `cfprefsd` (Core Foundation preferences daemon) caches plist values in-process; `defaults write` followed by an immediate `defaults read` MAY see stale data if cfprefsd hasn't flushed. macOS handles this in practice but the verify-after-apply path SHOULD tolerate a brief eventual-consistency window. Current sketch wraps `defaults read` with `2>/dev/null \|\| echo "<unset>"` — no explicit `defaults -currentHost domains \| cfprefsd-flush` step. **Acceptable as-is** (apply triggers killall Dock/Finder/SystemUIServer which forces cfprefsd flush via SIGHUP). | None separate — UI killalls are the implicit flush. |
| OS-registered state | `/etc/shells` (system-wide registered login shells; appended via `sudo tee -a`); `chsh -s <path>` updates the user record in Directory Services (queryable via `dscl . -read /Users/$USER UserShell`). | `apply_shell_registration` handles both. Idempotency: `grep -qxF` against `/etc/shells` before `tee -a`; `dscl` read before `chsh`. |
| Secrets and env vars | None — P6 reads neither secrets nor passwords. The `sudo` prompt for `/etc/shells` append and `sysadminctl -guestAccount off` is interactive user authentication, not stored secrets. No SOPS keys; no `.env` files; no CI/CD env vars affected. | None. |
| Build artifacts / installed packages | Homebrew zsh binary lives at `${HOMEBREW_PREFIX}/bin/zsh` (`brew install zsh` from P5 `packages/core.rb`). Installation is owned by P5; P6 only references the path. | None separate — P6 requires Homebrew zsh installed as upstream dependency (`task install` runs `packages:install` before `macos:shell`, per Taskfile.yml:140-143). |

**Specifically NOT affected** (verified absent):
- ChromaDB / Mem0 / Datadog / Tailscale ACLs / Cloudflare Tunnels — none referenced by P6.
- n8n workflows, Windows Task Scheduler, pm2, launchd plists, systemd units — none referenced.
- SOPS, pip egg-info, npm globals, Docker registries — none referenced.

## Common Pitfalls

### Pitfall 1: Two-line status with ANDed semantics

**What goes wrong:** The CONTEXT.md `<specifics>` skeleton at lines 405-410 shows:
```yaml
status:
  - '{{if not (index .MANIFEST.features "macos-dock")}}true{{else}}false{{end}}'
  - |
    export DOTFILEDIR="{{.TASKFILE_DIR}}"
    source "${DOTFILEDIR}/os/defaults/dock.zsh"
    verify_dock > /dev/null 2>&1
```

Multi-line `status:` blocks in go-task are **ANDed** (all must exit 0 for the task to skip). On a machine with `macos-dock = false`:
- Line 1 renders to `true` → exits 0 (skip).
- Line 2 runs anyway: `verify_dock` returns 1 because no Dock defaults are set on a feature-off machine (the script's expected values are NOT applied) → exits 1.
- `AND(0, 1) = 1` → status fails → cmds runs → `apply_dock` writes defaults to a machine that DID NOT want Dock customization. **The feature gate is bypassed.**

**Why it happens:** Misreading `status:` as `OR` semantics (the natural "if any condition is true, skip" reading) instead of `AND` semantics (all must pass to skip).

**How to avoid:** Use the **single-shell-block status** in Pattern 2 above:
```yaml
status:
  - |
    export DOTFILEDIR="{{.TASKFILE_DIR}}"
    {{if not (index .MANIFEST.features "macos-dock")}}exit 0{{end}}
    source "${DOTFILEDIR}/os/defaults/dock.zsh"
    verify_dock > /dev/null 2>&1
```
One shell, one exit — feature-off means `exit 0` before verify runs.

**Warning signs:** Test by running `task macos:defaults:dock --dry` on a machine with `macos-dock = false`; if it would-have-run, the status pattern is broken. Easier signal: the apply runs spuriously on the converged feature-off machine.

**[VERIFIED: taskfile.dev/usage]** "Alternatively, you can inform a sequence of tests as `status`. If no error is returned (exit status 0), the task is considered up-to-date" — confirms AND semantics.

### Pitfall 2: Bool round-trip normalization

**What goes wrong:** Naively comparing `value="true"` to `defaults read com.apple.dock autohide` (which returns `1`) — the strings never match, so verify reports a false-positive failure on every converged run.

**Why it happens:** `defaults write` accepts `true`/`false`/`YES`/`NO`/`1`/`0` for `-bool` (Apple docs), but `defaults read` ALWAYS returns the numeric form (`1` or `0`).

**How to avoid:** Per-type normalization in `verify_<concern>()`:
```zsh
case "$type" in
  bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
  *)    expected_read="$value" ;;
esac
```
The CONTEXT skeleton has this correct — confirm planner replicates it in all 5 concern scripts.

**Warning signs:** verify reports `expected 'true', got '1'` — the cross message reveals the bug.

**[VERIFIED on macOS 26.3.1]** `defaults read com.apple.dock autohide` returns `1`.

### Pitfall 3: `-currentHost` scope confusion

**What goes wrong:** Writing with `-currentHost` (per-host) but reading without it (global) — read returns nothing because the value lives in the ByHost plist, not the global plist.

**Why it happens:** `-currentHost` flag is required on BOTH read and write to address the same value. `com.apple.ImageCapture disableHotPlug` is the canonical per-host key (CONTEXT references v1 line 96).

**How to avoid:** Split `security.zsh`'s tuple list into TWO arrays — `SECURITY_DEFAULTS` (no scope flag) and `SECURITY_DEFAULTS_CURRENTHOST` (currentHost scope). Iterate each with the correct flag. CONTEXT skeleton at lines 300-322 has this split.

**Warning signs:** Newly-converged machine reports `security.disableHotPlug: expected '1', got '<unset>'` on every run — the write went to ByHost, the read looks in the global domain.

**Are there other `-currentHost` keys in P6 scope?** Checked: `screensaver askForPassword`, `askForPasswordDelay`, `TextInputMenu visible`, `Siri StatusMenuVisible`, `ImageCapture disableHotPlug` are the only candidates. Only `disableHotPlug` requires `-currentHost`. Screensaver keys are global-domain in modern macOS. [CITED: macos-defaults.com; v1 macos.yml line 96 is the v2 source of truth for this scope flag.]

### Pitfall 4: `dscl` UserShell single-line discipline

**What goes wrong:** `awk '{print $2}'` over `dscl . -read /Users/$USER UserShell` works for `UserShell: /opt/homebrew/bin/zsh` (single line, two fields). If `dscl` emits a multi-line or differently-formatted response (e.g., post-OS-upgrade format change), `awk` emits multiple lines and the `[[ ... = "{{.BREW_ZSH}}" ]]` comparison silently fails because the LHS has embedded newlines.

**Why it happens:** `dscl` output format is stable but assuming it is risky.

**How to avoid:** Add `head -n 1` between dscl and awk, OR check `awk '/^UserShell:/ {print $2; exit}'`. CONTEXT D-03 + v1 macos.yml:130 use the bare `awk '{print $2}'` form; recommend stabilizing.

**Warning signs:** `verify_shell_registration` reports `shell.user-default: expected '/opt/homebrew/bin/zsh', got '/opt/homebrew/bin/zsh<newline>...'` — multi-line LHS.

**[VERIFIED on macOS 26.3.1]:** `dscl . -read /Users/$USER UserShell` returns exactly one line `UserShell: /opt/homebrew/bin/zsh` and exit 0. The single-line form holds for now; the `head -n 1` defense is cheap insurance against future variance.

### Pitfall 5: `killall` on a fresh / server machine

**What goes wrong:** `killall Dock` fails (exit 1) when the Dock isn't running — common on a server machine (no GUI) or during early install on a freshly-booted machine before the UI starts. Combined with `set -euo pipefail`, the script aborts.

**Why it happens:** `killall` returns non-zero when no matching process exists.

**How to avoid:** Suffix every UI-killall with `2>/dev/null || true`:
```zsh
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
```

**Warning signs:** Install aborts on the server with `killall: Dock: No matching process found` — script-level `set -e` propagates.

**Note:** Servers never have `macos-dock = true`, so `apply_dock` (and its `killall Dock`) won't run on them. But `security.zsh`'s killall (if any — recommend NONE) would. Safe-suffix is best practice regardless.

### Pitfall 6: Sourcing without DOTFILEDIR set

**What goes wrong:** `source "${DOTFILEDIR}/install/messages.zsh"` fails with unbound-variable error when DOTFILEDIR isn't set in the caller's environment.

**Why it happens:** Taskfile `cmds:` heredocs don't automatically inherit `DOTFILEDIR`. The root Taskfile.yml line 44 sets `DOTFILEDIR: '{{.TASKFILE_DIR}}'` but this is a task var, not a shell env var. The cmds heredoc must `export DOTFILEDIR="{{.TASKFILE_DIR}}"` explicitly. Identity.yml and packages.yml use exactly this pattern.

**How to avoid:** Every `cmds:` and `status:` shell block in `macos.yml` includes `export DOTFILEDIR="{{.TASKFILE_DIR}}"` BEFORE sourcing any concern script.

**Warning signs:** Task fails with `${DOTFILEDIR}: unbound variable` or with `source: no such file or directory`.

### Pitfall 7: sudo prompt blocking install pipeline

**What goes wrong:** `sudo sysadminctl -guestAccount off` and `sudo tee -a /etc/shells` both prompt for the user's password. On a fresh install, both fire in sequence — install pipeline stalls waiting for input. If the user has stepped away, the install hangs indefinitely.

**Why it happens:** sudo's default `-p` prompt waits for password input. macOS sudo doesn't have a 5-second timeout.

**How to avoid:** Print a clear `info "sudo required for ..."` line BEFORE the sudo call so the user knows what's happening. CONTEXT skeleton's `apply_shell_registration` does this; `apply_security` should too.

**Warning signs:** Install seems to "hang" on `macos:shell` or `macos:defaults:security` — actually waiting for password.

### Pitfall 8: `chsh` requires shell to be in `/etc/shells`

**What goes wrong:** Calling `chsh -s "${HOMEBREW_PREFIX}/bin/zsh"` BEFORE the path is in `/etc/shells` fails with "non-standard shell" error.

**Why it happens:** macOS chsh validates the target shell against `/etc/shells` for security.

**How to avoid:** `apply_shell_registration` orders the two steps correctly: (1) append to `/etc/shells` if not present; (2) then run chsh. CONTEXT skeleton has this order.

**Warning signs:** `chsh: <path>: non-standard shell` error.

**[CITED: ss64.com/mac/chsh; macnotes archive]**

### Pitfall 9: `verify_<concern>` exit code as count vs boolean

**What goes wrong:** `return $failed` where `$failed` may end up as `2` or higher (multiple keys failed). `task macos:validate` checks `|| failed=1` — fine. But a `set -e` caller checking the function call directly would see exit ≥ 2 as a "fatal" event vs `1` as "soft failure".

**Why it happens:** `failed` is incremented per-key in some implementations. CONTEXT's `verify_dock` uses `failed=1` (boolean), not `failed=$((failed+1))` (count) — this is correct for the boolean semantic.

**How to avoid:** Per CONTEXT D-02 enumerate-all + boolean failure flag pattern: set `failed=1` once on first mismatch, keep enumerating, return `$failed` at end. Matches P5 D-07.

**Warning signs:** If exit code is the count, then 5 missing keys returns exit 5 — shell `||` semantics still work (≥1 is failure) but error messages are noisy.

### Pitfall 10: LINT-05 portability warnings on every new file

**What goes wrong:** Adding the 5 concern scripts adds 5 files containing `defaults read`/`defaults write` and `dscl` — every line will trip the LINT-05 portability rule (`taskfiles/lint.yml:247`).

**Why it happens:** LINT-05 scans `shell/ os/` for macOS-only commands. The rule was calibrated PRECISELY because P6 was anticipated to add these files. LINT-05 is **warn-only** (`exit 0` per `taskfiles/lint.yml:259`).

**How to avoid:** Nothing to fix — this is expected behavior. The planner SHOULD document in `os/README.md` that these warnings are expected and will continue to fire until v2+ Linux support adds platform guards. Confirm `task lint` still exits 0 after P6 lands.

**Warning signs:** `task lint:portability` output is suddenly twice as long.

### Pitfall 11: `mineffect = genie` accessibility consideration

**What goes wrong:** `mineffect = genie` is the macOS default minimize animation. Some users with vestibular sensitivity or who enable "Reduce Motion" in Accessibility find genie disorienting; `scale` is calmer.

**Why it happens:** v1 hardcoded `genie` (it matches Apple's default). v2 inherits this.

**How to avoid:** Two options: (a) keep `genie` (matches default, minimal risk of "wait, why is my system different?"); (b) drop `mineffect` entirely (let user-level Accessibility settings win). Recommend (a) for minimal v1 surprise; document the trade in `os/README.md` so a future per-machine override is greppable.

**Warning signs:** None at install time; only emerges if user enables Reduce Motion in Accessibility and notices behavior conflict.

**[VERIFIED]** `mineffect` is a stable Dock key across macOS 14/15/26. Valid values: `genie`, `scale`, `suck` (hidden). [Source: macos-defaults.com/dock/mineffect; eclecticlight.co; intego.com Dock terminal tricks]

### Pitfall 12: cfprefsd cache lag (eventual-consistency window)

**What goes wrong:** Immediately after `defaults write`, a subsequent `defaults read` MAY return the old value because `cfprefsd` (Core Foundation Preferences daemon) caches plist values in-process.

**Why it happens:** cfprefsd is the broker — `defaults write` typically updates the on-disk plist AND notifies cfprefsd, but for some keys the cache flush is asynchronous.

**How to avoid:** In practice this rarely affects `defaults read` invoked from a separate `defaults` process. P6 doesn't write-then-read in the same script — apply and verify are separate task invocations with seconds-to-minutes between them. Recommend no special handling unless test runs surface the issue. Killing UI processes (`killall Dock` etc.) forces cfprefsd reload as a side effect.

**Warning signs:** First-install verify shows mismatch; second-run verify shows match. Sign that cfprefsd hadn't flushed.

### Pitfall 13: PlistBuddy fragility (CONTEXT recommends drop)

**What goes wrong:** PlistBuddy commands fail when intermediate keys don't exist. v1 wrapped them in `2>/dev/null || true`, which made the "key not set" case indistinguishable from "successfully set" — so the v1 status check also had `2>/dev/null` and the validation effectively no-oped.

**Why it happens:** PlistBuddy is a structural plist editor; `defaults write` is a key-value setter. They have different error models.

**How to avoid:** Drop the three v1 `arrangeBy = grid` PlistBuddy lines from `finder.zsh` per Claude's Discretion in CONTEXT. None of the other Phase 6 keys require PlistBuddy (every other key fits the simple `defaults write -<type> <value>` model).

**Warning signs:** If retained, verify reports flaky pass/fail depending on whether Finder has been launched.

### Pitfall 14: `screencapture location` directory must exist before write

**What goes wrong:** `defaults write com.apple.screencapture location "$HOME/Pictures/Screenshots"` succeeds (it's just a path string), but the next screenshot attempt silently saves to `$HOME/Desktop` because the target directory doesn't exist.

**Why it happens:** macOS doesn't auto-create the directory.

**How to avoid:** `apply_screenshots` runs `mkdir -p "$HOME/Pictures/Screenshots"` BEFORE writing the default. CONTEXT screenshots.zsh sketch mentions this.

**Warning signs:** User reports screenshots not landing in the expected location after install.

### Pitfall 15: `mineffect` / `tilesize` `defaults read` returns just the value, no quotes

**What goes wrong:** Comparing `expected_read="genie"` to `current="genie"` works; comparing `expected_read="\"genie\""` (with quotes) to `current="genie"` fails. The CONTEXT tuple list has values without quotes, which is correct.

**Why it happens:** `defaults read` outputs values as plain strings (no quotes around strings; integers as bare numbers). The tuple `(domain, key, "bottom", "string")` quotes are zsh literals; the array element value is `bottom` (no quotes).

**How to avoid:** Verify zsh array element extraction returns the raw value. CONTEXT's `value="${DOCK_DEFAULTS[$((i + 2))]}"` is correct.

**Warning signs:** verify reports `expected '"bottom"', got 'bottom'` — quotes leaked through.

## Code Examples

Verified patterns from official sources and the v1 codebase:

### Reading a defaults value with stable error handling

```zsh
# Source: verified on macOS 26.3.1; pattern adapted from v1 taskfiles/macos.yml:52-57
current=$(defaults read com.apple.dock autohide 2>/dev/null || echo "<unset>")
# current is "1" if set to true, "0" if set to false, "<unset>" if key missing
```

### currentHost-scoped read (security.zsh pattern)

```zsh
# Source: v1 taskfiles/macos.yml:106
current=$(defaults -currentHost read com.apple.ImageCapture disableHotPlug 2>/dev/null || echo "<unset>")
```

### `dscl` UserShell read (P6 shell-registration.zsh)

```zsh
# Source: v1 taskfiles/macos.yml:130 (preserved verbatim in CONTEXT D-03 sketch)
# Verified on macOS 26.3.1: returns "/opt/homebrew/bin/zsh", exit 0.
current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk '{print $2}')
```

### Etc/shells idempotent append

```zsh
# Source: CONTEXT D-03 sketch (lines 345-349)
if ! grep -qxF "${BREW_ZSH}" /etc/shells; then
  info "Adding Homebrew zsh to /etc/shells..."
  echo "${BREW_ZSH}" | sudo tee -a /etc/shells > /dev/null
fi
```

### `sysadminctl -guestAccount` idempotent disable

```zsh
# Source: v1 taskfiles/macos.yml:99-104
# Verified on macOS 26.3.1: status command exits 0 unprivileged.
if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
  warn "Guest account is enabled. Disabling it now (sudo required)..."
  sudo sysadminctl -guestAccount off
fi
```

### Manifest feature gate in template (kebab-case index form)

```yaml
# Source: taskfiles/identity.yml (one-password-ssh precedent); CLAUDE.md kebab-case rule
status:
  - |
    {{if not (index .MANIFEST.features "macos-dock")}}exit 0{{end}}
    export DOTFILEDIR="{{.TASKFILE_DIR}}"
    source "${DOTFILEDIR}/os/defaults/dock.zsh"
    verify_dock > /dev/null 2>&1
```

### Aggregator marker pattern (LINT-01/03a exempt)

```yaml
# Source: taskfiles/packages.yml:183-201 (verify task) + taskfiles/identity.yml validate task
# lint-allow: cmds-without-status
validate:
  desc: "Validate macOS defaults match in-script expected values"
  platforms: [darwin]
  deps: [":manifest:resolve"]
  status: [false]  # always-rerun aggregator
  cmds:
    - |
      # full validate body...
```

### v1 reference: shell-task status (CURRENTLY BROKEN — the bug P6 fixes)

```yaml
# Source: taskfiles/macos.yml:144-146 (v1; .planning/codebase/CONCERNS.md lines 15-19 documents the bug)
# DO NOT REPLICATE -- this is the LINT-02 violation P6 fixes structurally.
status:
  - grep -qxF "$BREW_ZSH" /etc/shells       # WRONG: $BREW_ZSH unset in status eval shell
  - '[[ "$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk "{print \$2}")" = "{{.BREW_ZSH}}" ]]'
```

### v2 corrected: shell-task status

```yaml
# P6 replacement — LINT-02 compliant. Both lines use {{.BREW_ZSH}} template var.
vars:
  BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'
status:
  - grep -qxF "{{.BREW_ZSH}}" /etc/shells
  - '[[ "$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk "{print \$2}")" = "{{.BREW_ZSH}}" ]]'
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| v1 monolithic `taskfiles/macos.yml` with 7 tasks (init / general / dock / appearance / finder / misc / shell) | Per-concern `os/defaults/<concern>.zsh` + `os/shell-registration.zsh` + thin `taskfiles/macos.yml` invocation layer | Phase 6 (this work) | Single-responsibility files; tuple-array shape allows new keys with one-line edits; bug-class-fix for `$VAR`-in-status |
| `[[ "{{.PROFILE}}" == "server" ]] && echo false || echo true` for autohide | Manifest feature gates (`macos-dock = true/false` per machine) | Phase 1 + Phase 6 | No profile branching anywhere; manifest is source of truth |
| Stub `taskfiles/macos-stub.yml` (P2 placeholder; satisfies `task install`'s call graph) | Real `taskfiles/macos.yml` | Phase 6 (this work) | `task install` body unchanged — only the include target flips |
| `$BREW_ZSH` shell var in status block | `{{.BREW_ZSH}}` template var with `vars: BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'` at task level | Phase 6 (this work) | Structural LINT-02 fix; the CONCERNS.md line-15 bug class closes |
| `NSGlobalDomain AppleInterfaceStyle = Dark` defaults written unconditionally | Drop in v1 P6 (not in OSCF-01 enumeration) | Phase 6 (this work) | If user wants Dark mode set programmatically, a future `appearance.zsh` concern owns it |
| PlistBuddy `arrangeBy = grid` for desktop icon view | Drop in v1 P6 (Claude's Discretion) | Phase 6 (this work) | Brittle dependency on Finder having launched once removed |

**Deprecated / outdated:**

- v1 `taskfiles/macos.yml` — STAYS on disk byte-stable until P8 (parallel-rewrite invariant). Active include target switches in P6.
- v1 `taskfiles/macos-stub.yml` — STAYS on disk byte-stable until P8 (same invariant). Include target switches in P6.
- v1 `defaults-init` task (`osascript -e 'tell application "System Preferences" to quit'`) — silently dropped; modern macOS uses "System Settings" and the quit pattern is fragile. If a user has it open during install, modern macOS handles concurrent reads/writes well enough.

## Assumptions Log

> Claims tagged `[ASSUMED]` in this research that the planner / user MAY want to confirm.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `defaults read` is sufficient for all P6 keys (no PlistBuddy needed except the dropped `arrangeBy = grid`) | Don't Hand-Roll; Code Examples | LOW — every CONTEXT-listed key is a top-level domain/key pair, which `defaults` handles natively. PlistBuddy is only needed for nested-dict paths. |
| A2 | `mineffect = genie` is acceptable for josh's machines (CONTEXT flags as "drop if planner prefers a single-value default"; Pitfall #11 raises accessibility) | Pitfall #11 | LOW — matches Apple default. User confirms during planning if accessibility is a concern. |
| A3 | `KeyRepeat = 2` and `InitialKeyRepeat = 15` are recommended `input.zsh` defaults | User Constraints (Claude's Discretion) | LOW — if user has different taste, planner asks at execution. Or ship Option B (empty stub). |
| A4 | `dscl` output format `UserShell: <path>` is stable across macOS 14/15/26 | Pitfall #4 | LOW — verified on macOS 26.3.1 (current). Apple has not changed this format in 15+ years per ss64.com docs. |
| A5 | `sysadminctl -guestAccount status` output `Guest account disabled.` / `Guest account enabled.` is stable | Standard Stack | LOW — verified on macOS 26.3.1 (output goes to stderr; the `2>&1 \| grep -q "enabled"` pattern is v1's, which has shipped for years). |
| A6 | LINT-10 candidate ("defaults write in cmds: must have matching defaults read in status:") is worth shipping in P6 vs deferring | Claude's Discretion | LOW — planner picks. Without it, the only enforcement is runtime `verify_<concern>()` (which catches misses but not "wrote a key, forgot to add to the tuple array"). |
| A7 | The `[ASSUMED]` `head -n 1` defense for dscl is not strictly required today | Pitfall #4 | LOW — verified single-line output on macOS 26.3.1; defense is cheap insurance, not a current bug. |

**If this table is empty:** N/A — 7 assumptions remain after verification. None are blockers; all are low-risk inheritances from prior phases or CONTEXT.md sketches.

## Open Questions

1. **Should LINT-10 ship in P6 or be deferred to a follow-up plan against P2's lint suite?**
   - What we know: P2 D-12 says all lint logic lives in `taskfiles/lint.yml`; P6 introduces the first set of `defaults write`-in-cmds + `defaults read`-in-status pairs that the rule would govern.
   - What's unclear: whether the planner wants to keep P6 surface minimal (defer LINT-10) or close the bug-class enforcement now.
   - Recommendation: Defer to a follow-up plan if P6 is already long; ship in P6 if the planner targets a "structural-bug-class-fix" theme. Either way, the runtime `verify_<concern>()` catches the same class of error (just at install time, not lint time).

2. **Should `input.zsh` ship Option A (3 keys: swipescrolldirection + KeyRepeat + InitialKeyRepeat) or Option B (empty stub)?**
   - What we know: v1 has nothing for input; OSCF-01 requires the file to exist; CONTEXT lists Option A as "recommended" but flags `KeyRepeat`/`InitialKeyRepeat` as "if josh has preferences."
   - What's unclear: josh's preference for keyboard repeat rate.
   - Recommendation: Option A with `swipescrolldirection = false` only (hoisted from v1 `defaults-appearance`); leave KeyRepeat/InitialKeyRepeat as a comment in the file ("add when preference confirmed"). Defers the keyboard decision without compromising OSCF-01.

3. **Should `screenshots.zsh` ship Option A (3 keys) or Option B (empty stub)?**
   - What we know: v1 has nothing here; OSCF-01 requires the file.
   - What's unclear: whether josh wants screenshots in `$HOME/Pictures/Screenshots` vs default `~/Desktop`.
   - Recommendation: Option A — most laptop users prefer non-Desktop screenshot location. Default is reasonable; per-machine override is trivial via future TOML-side migration.

4. **Should `security.zsh` include the `sysadminctl -guestAccount off` apply path or defer to `docs/CUTOVER.md`?**
   - What we know: v1 includes it (lines 99-104); CONTEXT recommends (a) — include with sudo prompt guarded by status check.
   - What's unclear: whether sudo prompt in `task install` is a UX concern.
   - Recommendation: Include per CONTEXT recommendation (a). The `info`/`warn` lines BEFORE the sudo call make the prompt explicable. First-install-only behavior.

5. **`appearance.zsh` Dark mode / theme keys — defer to v2+ or ship as a 6th concern in v1 P6?**
   - What we know: v1 had `AppleInterfaceStyle = Dark` and `AppleIconAppearanceTheme = RegularDark`; OSCF-01 enumerates exactly 5 concerns.
   - What's unclear: whether josh wants Dark mode programmatically managed.
   - Recommendation: Defer. OSCF-01 lists 5 concerns; growing to 6 amends the requirement. Deferred to a follow-up plan if needed; document in `os/README.md` Adding-a-Pattern section.

6. **Should `os/README.md` document the EXPECTED LINT-05 warnings as a "this is intentional" note?**
   - What we know: LINT-05 will fire on every `defaults read/write` and `dscl` line in `os/`.
   - What's unclear: whether the README is the right place for the disclaimer vs `docs/MIGRATION.md`.
   - Recommendation: `os/README.md` mentions briefly; `docs/MIGRATION.md` (DOCS-05, P8) carries the canonical "expected warnings" list.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `defaults` | All 5 concern scripts | ✓ | macOS-built-in (26.3.1 verified) | — (macOS-canonical; no fallback) |
| `dscl` | `os/shell-registration.zsh` | ✓ | macOS-built-in (26.3.1 verified) | — |
| `sysadminctl` | `os/defaults/security.zsh` | ✓ | macOS-built-in (26.3.1 verified) | — |
| `chsh` | `os/shell-registration.zsh` | ✓ | macOS-built-in | — |
| `killall` | `apply_<concern>()` UI restart side-effects | ✓ | macOS-built-in | — (with `\|\| true` suffix) |
| Homebrew zsh (`${HOMEBREW_PREFIX}/bin/zsh`) | `os/shell-registration.zsh` references the path | ✓ on personal-laptop test machine | 5.x (from Homebrew core) | If missing, `apply_shell_registration` fails on `chsh` step — fix is upstream (`task packages:install` runs FIRST per Taskfile.yml:140). |
| `go-task` | Engine for `taskfiles/macos.yml` | ✓ | 3.37+ (P2 dep) | — |
| `messages.zsh` | All concern scripts | ✓ | repo-local (`install/messages.zsh`) | — |
| `awk` | `dscl` UserShell extract | ✓ | macOS-built-in | — |
| `grep` (BSD or `ggrep`) | `/etc/shells` membership; `defaults` filter | ✓ | macOS-built-in (`grep -qxF` is portable) | — |
| `sudo` | `/etc/shells` append; `sysadminctl -guestAccount off` | ✓ | macOS-built-in | — (interactive password prompt) |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

**Install-time sequencing:** `task install` runs `task packages:install` BEFORE `task macos:defaults` and `task macos:shell` (Taskfile.yml:140-143). So by the time P6 scripts execute, Homebrew zsh, antidote, and the rest of `core.rb` are guaranteed to be on PATH. P6 has NO new external dependencies — every tool is either macOS-built-in or already installed by P5.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | go-task task-level invocations (no separate test framework) + `task lint` + manual verify via `task macos:validate` |
| Config file | `Taskfile.yml` (root) + `taskfiles/macos.yml` (P6 deliverable) + `taskfiles/lint.yml` (existing) |
| Quick run command | `task lint && task macos:validate` |
| Full suite command | `task lint && task install && task macos:validate && task validate` (where `task validate` is P8) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OSCF-01 | All 5 concern scripts exist under `os/defaults/`; `os/shell-registration.zsh` exists | smoke | `for f in os/defaults/{dock,finder,input,screenshots,security}.zsh os/shell-registration.zsh; do test -f "$f"; done` | ❌ Wave 0 — scripts created in P6 plans |
| OSCF-01 | Each concern script declares `<CONCERN>_DEFAULTS` array + `apply_<concern>` + `verify_<concern>` | smoke | `for c in dock finder input screenshots security; do grep -q "^typeset -ga ${c:u}_DEFAULTS=" "os/defaults/$c.zsh" && grep -q "^apply_$c()" "os/defaults/$c.zsh" && grep -q "^verify_$c()" "os/defaults/$c.zsh"; done` | ❌ Wave 0 |
| OSCF-02 | Each `macos:defaults:<concern>` task is gated on `index .MANIFEST.features "macos-<concern>"` | unit | `yq '.tasks."defaults:dock".status' taskfiles/macos.yml \| grep -q 'index .MANIFEST.features "macos-dock"'` (repeat for each concern) | ❌ Wave 0 |
| OSCF-02 | Manifest TOMLs declare the 4 new kebab-case feature keys | unit | `for k in macos-dock macos-input macos-screenshots macos-security; do grep -q "^$k = " manifests/defaults.toml; done` | ❌ Wave 0 |
| OSCF-02 | Server TOMLs have `macos-security = true` | unit | `grep -q '^macos-security = true' manifests/machines/server-1.toml && grep -q '^macos-security = true' manifests/machines/server-2.toml` | ❌ Wave 0 |
| OSCF-03 | Every `defaults write` line in `os/defaults/*.zsh` has a matching `defaults read` in the same script's `verify_<concern>` function | integration | `for f in os/defaults/*.zsh; do writes=$(grep -c "defaults.*write" "$f"); reads=$(grep -c "defaults.*read" "$f"); [[ "$writes" -le "$reads" ]]; done` | ❌ Wave 0 |
| OSCF-03 | Re-running `task macos:defaults` is a no-op (zero `defaults write` per `dtrace`/`strace`-equivalent) | manual / integration | Manual: run `task macos:defaults` twice; second invocation prints no "writing ..." info lines | ❌ Wave 0 (manual UAT) |
| OSCF-04 | `task macos:shell` status uses `{{.BREW_ZSH}}` template var only (no `$BREW_ZSH` shell var) | unit (LINT-02 regression) | `yq '.tasks.shell.status' taskfiles/macos.yml \| grep -qE '\$BREW_ZSH\b'` MUST exit non-zero (i.e., grep finds nothing) | ❌ Wave 0 |
| OSCF-04 | `os/shell-registration.zsh` exposes `apply_shell_registration` and `verify_shell_registration` | smoke | `grep -q '^apply_shell_registration()' os/shell-registration.zsh && grep -q '^verify_shell_registration()' os/shell-registration.zsh` | ❌ Wave 0 |
| OSCF-05 | `task macos:validate` sources every enabled concern script and calls each `verify_<concern>` | integration | Manual: run on personal-laptop (5 concerns enabled) → check/cross output for all 5 + shell-registration. Run on server-1 (only `macos-security` enabled) → check/cross output for security + shell-registration only. | ❌ Wave 0 (manual UAT) |
| OSCF-05 | `task macos:validate` exits non-zero on any key mismatch | unit | Deliberately bork a defaults value (`defaults write com.apple.dock orientation -string "left"`), run `task macos:validate`, assert exit ≠ 0, then restore | ❌ Wave 0 (manual UAT or Wave 0 fixture) |
| (regression) | `task lint` passes LINT-01..09 against the new `taskfiles/macos.yml` | static | `task lint` exits 0 (warnings from LINT-05 are expected and non-blocking) | ✅ existing |
| (regression) | `task install` on a converged machine is fast (no spurious re-runs) | smoke (LINT-08 deprecated per P2 D-11; manual timing) | Manual: time `task install`; second run should print no `[INFO] Adding/Writing/Changing` lines from `macos:*` | ✅ existing |
| (regression) | `grep '\$BREW_ZSH' taskfiles/macos.yml` returns nothing in `status:` lines (LINT-02 contract) | static | `task lint:taskfile` exits 0 | ✅ existing |

### Sampling Rate

- **Per task commit:** `task lint && zsh -n os/defaults/<edited-file>.zsh`
- **Per wave merge:** `task lint && task macos:validate` (on a converged test machine)
- **Phase gate:** `task lint && task install && task macos:validate` + manual UAT per `.planning/phases/06/06-HUMAN-UAT.md` (TBD; planner creates) before `/gsd-verify-work`

### Wave 0 Gaps

The phase has no pre-existing automated test infrastructure for OS defaults — every test is shell-level invocation of `task` commands.

- [ ] `taskfiles/macos.yml` — Wave 0 deliverable; the regression-test surface for OSCF-01..05.
- [ ] `os/defaults/{dock,finder,input,screenshots,security}.zsh` — five concern scripts.
- [ ] `os/shell-registration.zsh` — shell-registration script.
- [ ] `manifests/defaults.toml` four new `[features]` keys — Wave 0 deliverable (touches schema before any consumer reads).
- [ ] `manifests/machines/server-1.toml` + `server-2.toml` `macos-security = true` — Wave 0.
- [ ] `os/README.md` rewrite — Wave 0 (DOCS-02 anchor, mirrors `shell/README.md` + `packages/README.md`).
- [ ] Manual UAT plan recorded in `.planning/phases/06/06-HUMAN-UAT.md` (planner creates) covering:
  - Server-mode install (only macos-security + shell run; other 4 concerns skip)
  - Laptop-mode install (all 5 concerns + shell)
  - Re-run idempotency (zero writes on second run)
  - Bug-class regression (`grep '\$BREW_ZSH' taskfiles/macos.yml` in status: lines returns nothing)
  - Deliberate-mismatch + `task macos:validate` exits non-zero

*(All Wave 0 items are net-new deliverables for P6; no existing test infrastructure to amend.)*

## Security Domain

> Enabled (`security_enforcement` absent in config → treat as enabled).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (sudo for `/etc/shells` append and `sysadminctl -guestAccount off`) | Rely on macOS sudo / Touch ID; do NOT cache passwords; do NOT use `NOPASSWD` workarounds |
| V3 Session Management | no | n/a (no sessions in P6) |
| V4 Access Control | yes (write-access to `/etc/shells` requires sudo; `defaults write` is user-scoped) | Standard macOS user-vs-root model; `/etc/shells` write gated by sudo prompt |
| V5 Input Validation | yes (concern script tuple values are written via `defaults write -<type> <value>`) | Values are repo-static (no runtime user input); `-<type>` flag prevents type confusion. Tuple values are zsh-string-quoted (no shell metachar interpolation). |
| V6 Cryptography | no | n/a (no key material; the shell registration is config, not crypto) |

### Known Threat Patterns for macOS `defaults` + `chsh` + `sysadminctl`

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious value injection into `defaults write` | Tampering | Tuple values are repo-static (D-02; live in scripts, NOT runtime input). Code review at PR time. No dynamic interpolation from external sources. |
| Sudo prompt spoofing | Spoofing | macOS sudo prompts via Touch ID or terminal-native prompt; not subject to GUI-overlay attacks. Print `info "sudo required for ..."` BEFORE sudo so the user can correlate the prompt to a known action. |
| `/etc/shells` write race | Elevation of Privilege | `grep -qxF` + `sudo tee -a` is the canonical idempotent pattern. The `-x` flag prevents partial-match weirdness. macOS guarantees `/etc/shells` is root-owned 644. |
| `chsh` to non-`/etc/shells` shell | Tampering | macOS chsh enforces `/etc/shells` membership. Apply path runs `/etc/shells` append FIRST, then chsh — order is correct. |
| `sysadminctl -guestAccount off` failure leaves guest enabled | Tampering | Idempotent: status check before write; verify path asserts post-state via `sysadminctl -guestAccount status`. |
| Sourced concern script with `set -euo pipefail` exits the calling shell | DoS (developer) | Sourcing a script with `set -e` affects ONLY the function bodies (CONTEXT D-discretion notes this; tested pattern). The taskfile's `cmds:` heredoc carries its own `set -euo pipefail` per LINT-04, so script-level `set -e` is non-additive. |
| `defaults write` accidentally writes to wrong domain | Tampering | Domain values in tuple arrays are repo-static and code-reviewed. Per-key probe in `verify_<concern>()` would catch a mistyped domain (would always fail). |
| `killall <ProcessName>` killing the wrong process | Tampering / DoS | `killall` matches exact process name; macOS Dock/Finder/SystemUIServer are well-known stable names. `\|\| true` suffix handles "not running." |
| LINT-05 portability warnings ignored | Information Disclosure (about platform assumption) | LINT-05 is warn-only by design (P2 D-12 + LINT-05 spec). v2+ Linux work will promote it to blocking (LINUX-V2-06). |

## Sources

### Primary (HIGH confidence)

- **macOS `defaults` man page** — `man defaults` on macOS 26.3.1; verified type flags (`-bool`/`-int`/`-string`), `-currentHost` scope, exit semantics for missing keys.
- **Verified real-machine behavior** — Tested on macOS 26.3.1 / arm64 (current dev machine):
  - `defaults read com.apple.dock autohide` → `1`
  - `defaults read com.apple.dock tilesize` → `45`
  - `defaults read com.apple.dock orientation` → `bottom`
  - `defaults read com.apple.dock mineffect` → `genie`
  - `defaults read com.apple.dock <missing>` → exit 1, stderr noise
  - `defaults read NSGlobalDomain AppleShowAllExtensions` → `1`
  - `defaults read NSGlobalDomain com.apple.swipescrolldirection` → `0`
  - `defaults read com.apple.screensaver askForPassword` → `1`
  - `defaults read com.apple.screencapture location` / `type` → exit 1 (not yet set)
  - `dscl . -read /Users/$USER UserShell` → `UserShell: /opt/homebrew/bin/zsh`, exit 0
  - `sysadminctl -guestAccount status` → `Guest account disabled.` (stderr), exit 0
  - `grep -qxF "/opt/homebrew/bin/zsh" /etc/shells` → exit 0
- **`taskfile.dev/usage`** — Multi-line `status:` block semantics: "If no error is returned (exit status 0), the task is considered up-to-date" — confirms AND semantics.
- **Go text/template `pkg.go.dev/text/template`** — `index` and `not` function semantics confirmed.
- **Repo files (binding canonical references):**
  - `.planning/phases/06-os-defaults-macos-configuration/06-CONTEXT.md` (full user decisions; D-01..D-04, CF-01..CF-13)
  - `.planning/REQUIREMENTS.md` lines 110-118 (OSCF-01..05)
  - `.planning/ROADMAP.md` lines 125-135 (Phase 6 section + 5 success criteria)
  - `.planning/codebase/CONCERNS.md` lines 15-19 (the `$BREW_ZSH` bug class P6 fixes)
  - `taskfiles/macos.yml` (v1 source; the port input)
  - `taskfiles/macos-stub.yml` (current Phase 2 stub being replaced)
  - `taskfiles/identity.yml` (precedent: `MANIFEST_JSON`/`MANIFEST` vars, `index .MANIFEST.features "..."` pattern, validate task shape)
  - `taskfiles/packages.yml` (precedent: `status: [false]` aggregator pattern; `# lint-allow: cmds-without-status` marker; D-07 enumerate-all verify)
  - `taskfiles/lint.yml` lines 140-201 (LINT-02 + LINT-03a + LINT-03b enforcement; LINT-05 portability warn-list at line 247)
  - `taskfiles/helpers.yml` (`_:check-link`/`_:check-dir`/`_:check-file`/`_:check-command` — none ideally fit P6 defaults verification; verify body lives inline)
  - `Taskfile.yml` (root: `HOMEBREW_PREFIX` resolution at lines 47-52; macos: include slot at line 108; install pipeline at lines 122-152)
  - `install/messages.zsh` (UX primitives; double-source-guarded line 20-21)
  - `manifests/defaults.toml`, `manifests/machines/*.toml` (current feature flag namespace)
  - `shell/aliases/finder.zsh` (P3 D-07 same-flag-two-consumers precedent for `macos-finder`)

### Secondary (MEDIUM confidence)

- **`ss64.com/mac/chsh`** — `chsh` requires target shell in `/etc/shells`; macOS-wide invariant.
- **`ss64.com/mac/dscl`** — `dscl . -read /Users/$USER UserShell` is the canonical read for registered login shell.
- **`macos-defaults.com/dock/mineffect.html`** — `mineffect` values: genie (default), scale, suck (hidden); stable across macOS 14/15/26.
- **`eclecticlight.co/2026/04/27/the-minimise-easter-egg-lives-on/`** — Confirms `mineffect = suck` still works on current macOS (2026 timestamp); semantic stability of the key.
- **`intego.com/mac-security-blog`** — `killall Dock` is the canonical restart pattern after writing `com.apple.dock` keys.

### Tertiary (LOW confidence)

- **`developer.apple.com/forums/thread/767845`** — Reports of intermittent `dscl` failures on macOS 15.x Sequoia. Risk: low — no reports of `dscl . -read /Users/$USER UserShell` specifically failing. Defense in Pitfall #4 (`head -n 1`) is cheap insurance.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are macOS built-ins, repo-local, or already-in-use (go-task, jq). Versions verified on real machine.
- Architecture: HIGH — every pattern has a verbatim analog in `taskfiles/identity.yml` (P4) or `taskfiles/packages.yml` (P5). The only novel pattern is the single-shell-block status (Pattern 2), which is a refinement of the CONTEXT skeleton's broken two-line shape.
- Pitfalls: HIGH — pitfalls 1-9 verified against actual macOS 26.3.1 behavior or prior phase taskfiles; pitfalls 10-15 are conservative defenses against known-class-of-issue (cfprefsd cache, dscl stability) rather than reproduced bugs.
- Open questions: MEDIUM — 6 questions; most are scope/feature-set decisions for the planner, not technical unknowns.

**Research date:** 2026-05-15
**Valid until:** 2026-06-14 (30 days; stable domain — macOS defaults system semantics rarely change; go-task v3.37+ template stable since release).

---

*Phase: 06-os-defaults-macos-configuration*
*Research conducted: 2026-05-15*
