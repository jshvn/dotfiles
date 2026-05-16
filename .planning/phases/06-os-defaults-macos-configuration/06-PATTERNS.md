# Phase 6: OS Defaults -- macOS Configuration -- Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 15 (8 new, 7 modified)
**Analogs found:** 15 / 15
**Pattern extraction source:** read-only Grep + Read against P3/P4/P5 analogs + v1 `taskfiles/macos.yml` source content

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| **NEW** `os/defaults/dock.zsh` | sourced concern script (writer + verifier) | request-response (apply) + transform (verify) | `install/messages.zsh` (sourced library shape) + v1 `taskfiles/macos.yml:40-57` (content) | role-match (no existing tuple-array sourced concern script -- this is a new shape; pattern enumerated in RESEARCH Pattern 1) |
| **NEW** `os/defaults/finder.zsh` | sourced concern script | same as dock | same as dock + v1 `macos.yml:72-89` (content) | role-match |
| **NEW** `os/defaults/input.zsh` | sourced concern script (starter or stub) | same as dock | same as dock + v1 `macos.yml:59-70` (swipescrolldirection hoist) | role-match |
| **NEW** `os/defaults/screenshots.zsh` | sourced concern script (starter or stub) | same as dock | same as dock | role-match (new content; no v1 analog) |
| **NEW** `os/defaults/security.zsh` | sourced concern script + sudo guard | same as dock | same as dock + v1 `macos.yml:29-38, 91-109` (content) | role-match |
| **NEW** `os/shell-registration.zsh` | sourced library (apply + verify) | request-response | `install/messages.zsh` (sourced library shape) + v1 `macos.yml:111-146` (content -- THE bug-fix port) | role-match |
| **NEW** `taskfiles/macos.yml` | go-task module (replaces stub) | event-driven (task-graph) | `taskfiles/packages.yml` (apply/verify shape) + `taskfiles/identity.yml` (sourced helper + status template-vars) | exact |
| **NEW** `os/README.md` | sibling README | docs | `shell/README.md` + `packages/README.md` | exact |
| **NEW** `.planning/phases/06-.../06-HUMAN-UAT.md` | UAT script | docs | prior phase HUMAN-UAT files (P5 precedent) | exact (out of pattern-map scope; planner creates per VALIDATION callout) |
| **MOD** `Taskfile.yml` (root) | include declaration | config | existing `links:` / `packages:` include rows | exact (single-line flip; line 108) |
| **MOD** `manifests/defaults.toml` | TOML schema baseline | config | existing `[features]` block (lines 23-32) | exact |
| **MOD** `manifests/machines/server-1.toml` | TOML machine declaration | config | existing `[features]` block (lines 14-17) | exact |
| **MOD** `manifests/machines/server-2.toml` | TOML machine declaration | config | same as server-1 | exact |
| **MOD** `docs/MANIFEST.md` | schema reference table | docs | existing feature-flag table (lines 450-460; rows are already present from P1 stub, P6 adjusts the "Default in defaults.toml" column + adds dual-consumer note on macos-finder) | exact |
| **MOD** `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` | planning docs | docs | P5 D-02 textual-amend precedent (ROADMAP success-criterion wording soften) | role-match |

## Pattern Assignments

### NEW: sourced concern scripts (`os/defaults/<concern>.zsh`)

These five files share one shape. Pattern assignments are identical -- the only diffs are the `<CONCERN>_DEFAULTS` array contents and the `apply_<concern>` post-step (`killall Dock` vs `killall Finder` vs `killall SystemUIServer` vs none).

**Primary analog:** `install/messages.zsh` (the only existing sourced-only `.zsh` library in v2). RESEARCH Pattern 1 (06-RESEARCH.md lines 256-323) provides the complete tuple-array shape that is binding on every concern script.

**Header pattern** (sourced library; double-source guard optional but matches `messages.zsh`):

```zsh
# Source: install/messages.zsh lines 1-21
#!/bin/zsh
# Dotfiles messaging library
# Source this file to get consistent messaging functions
#
# Usage:
#   source "${DOTFILEDIR}/install/messages.zsh"
#   ...

# Prevent double-sourcing
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1
```

For Phase 6 concern scripts the header carries the file-purpose docstring + `set -euo pipefail` (project convention CF-06: v2 carries the flag even on sourced files for consistency).

**Tuple-array + apply + verify pattern** (the single source of truth per concern; D-02):

```zsh
# Source: .planning/phases/06-.../06-RESEARCH.md lines 269-313 (Pattern 1)
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

**Per-concern content sources** (v1 `taskfiles/macos.yml`, byte-stable on disk; this phase ports content into new shape):

| Concern | v1 source range | Surgery |
|---------|-----------------|---------|
| `dock.zsh` | `taskfiles/macos.yml:40-57` | Drop the `[[ "{{.PROFILE}}" == "server" ]] && echo false || echo true` branch on `autohide` (line 47); replace with literal `true`. Move all six keys into `DOCK_DEFAULTS`. |
| `finder.zsh` | `taskfiles/macos.yml:72-89` | Drop the three PlistBuddy `arrangeBy = grid` lines (80-82); keep `AppleShowAllExtensions`, `FXEnableExtensionChangeWarning`, `FXPreferredViewStyle` in `FINDER_DEFAULTS`. |
| `input.zsh` | `taskfiles/macos.yml:66` (swipescrolldirection) | New file. Hoist the single swipescrolldirection key from v1 `defaults-appearance`. Option B: empty stub if planner wants smaller P6 surface (CONTEXT D-discretion). |
| `screenshots.zsh` | NONE | New content: `com.apple.screencapture location` / `type` / `disable-shadow` + `killall SystemUIServer`. Option B available. |
| `security.zsh` | `taskfiles/macos.yml:29-38, 91-109` | Merge `defaults-general` (screensaver) + `defaults-misc` (ImageCapture `-currentHost` + guestAccount). Drop `TextInputMenu visible` and `Siri StatusMenuVisible` (Claude's Discretion: not security). |

**`-currentHost` scope variant** (security.zsh) -- second array + dedicated apply loop:

```zsh
# Source: 06-CONTEXT.md lines 293-332 (security.zsh skeleton)
typeset -ga SECURITY_DEFAULTS_CURRENTHOST=(
  "com.apple.ImageCapture"  "disableHotPlug"  "true"  "bool"
)
# Inside apply_security:
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
# Inside verify_security: defaults -currentHost read ...
```

**Sudo-guarded sysadminctl branch** (security.zsh) -- v1 pattern verbatim:

```zsh
# Source: v1 taskfiles/macos.yml lines 100-104
# Inside apply_security():
if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
  warn "Guest account is enabled. Disabling it now (sudo required)..."
  sudo sysadminctl -guestAccount off
fi
# Inside verify_security(): sysadminctl -guestAccount status 2>&1 | grep -q "disabled"
```

**Error handling pattern:**
- `set -euo pipefail` at top -- fail fast on unbound variables (the v2 convention; LINT-04 if the file gets the executable bit; project convention says carry the flag even on sourced files).
- `defaults read ... 2>/dev/null || echo "<unset>"` -- stderr suppressed, sentinel placed for the comparison (RESEARCH Pattern 1 explanation).
- `verify_<concern>()` returns the failure count (0 = clean). RESEARCH Pitfall 9 notes this is a count, not boolean; multi-key drift accumulates.
- `killall <App> 2>/dev/null || true` -- tolerate "no such process" on fresh machines (RESEARCH Pitfall 5).

---

### NEW: `os/shell-registration.zsh` (sourced library, the bug-fix file)

**Primary analog:** `install/messages.zsh` (sourced library shape) + v1 `taskfiles/macos.yml:111-146` (content, with the `$BREW_ZSH`-in-status fix).

**Apply pattern** (v1 content verbatim, ported to a function):

```zsh
# Source: v1 taskfiles/macos.yml lines 120-143 (content)
# Source: 06-CONTEXT.md lines 334-373 (skeleton shape)
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

**Critical surgery vs v1** -- the `$BREW_ZSH`-in-status bug class:
- v1 `taskfiles/macos.yml:145` reads `grep -qxF "$BREW_ZSH" /etc/shells` in the task `status:` block; `$BREW_ZSH` is unset in the status-eval shell so the check fails on every run and the task re-applies forever.
- v2 fix: the script is a function library; the `status:` block in `taskfiles/macos.yml` uses `{{.BREW_ZSH}}` (template var, resolved at task-graph build time -- always set). LINT-02 enforces this at lint time.

---

### NEW: `taskfiles/macos.yml` (the go-task module)

**Primary analog:** `taskfiles/packages.yml` (apply/verify shape, status: [false] always-rerun, status-template-var discipline, deps: [":manifest:resolve"], precondition pattern).
**Secondary analog:** `taskfiles/identity.yml` (sourced helper-script pattern, vars block, lint-allow marker for aggregator, validate as task: delegation).

**File header pattern** (mirrors packages.yml lines 1-35):

```yaml
# Source: taskfiles/packages.yml lines 1-35
version: '3'

# =============================================================================
# taskfiles/macos.yml -- Phase 6 macOS OS-defaults + shell-registration layer.
#
# Purpose:
#   Reads features.macos-{dock,finder,input,screenshots,security} from
#   resolved.json via `ref: fromJson` and applies per-concern defaults via
#   `os/defaults/<concern>.zsh` sourced helpers. Also runs
#   os/shell-registration.zsh (always-on) to add Homebrew zsh to /etc/shells
#   and chsh.
#
# Dependencies:
#   - :manifest:resolve (deps) -- ensures resolved.json is current before any
#     gate read.
#   - install/messages.zsh -- sourced via {{.DOTFILES_MESSAGES}} for check/cross.
#   - os/defaults/<concern>.zsh -- sourced by each macos:defaults:<concern>.
#   - os/shell-registration.zsh -- sourced by macos:shell.
#
# Status-block convention (LINT-02 enforcement):
#   Every install / verify task's `status:` uses `{{.X}}` template vars ONLY --
#   never `$X` shell vars (the v1 macos:shell:145 bug class). Aggregator-style
#   tasks (defaults, validate) intentionally omit `status:` and carry the
#   `# lint-allow: cmds-without-status` marker on the line immediately above
#   the task key (D-12 / LINT-01/03a exemption).
# =============================================================================
```

**Vars block pattern** (mirrors packages.yml lines 45-88 + identity.yml lines 54-95):

```yaml
# Source: taskfiles/packages.yml lines 45-85
vars:
  HOME: '{{.HOME}}'

  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"

  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"

  RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'

  MANIFEST_JSON:
    sh: |
      if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
        cat '{{.RESOLVED_JSON_PATH}}'
      else
        echo "warning: {{.RESOLVED_JSON_PATH}} missing or empty -- run 'task setup -- <machine>' first" >&2
        echo '{}'
      fi

  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'

  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'
```

**Aggregator pattern** (mirrors identity.yml lines 108-114 + RESEARCH Pattern 3):

```yaml
# Source: taskfiles/identity.yml lines 108-114
# lint-allow: cmds-without-status
install:
  desc: "Install identity layer (git + ssh)"
  deps: [":manifest:resolve"]
  cmds:
    - task: git
    - task: ssh
```

For P6 -- `macos:defaults` aggregator:

```yaml
# lint-allow: cmds-without-status
defaults:
  desc: "Apply macOS system defaults (per-concern, feature-gated)"
  platforms: [darwin]
  deps: [":manifest:resolve"]
  cmds:
    - task: defaults:dock
    - task: defaults:finder
    - task: defaults:input
    - task: defaults:screenshots
    - task: defaults:security
```

**Per-concern feature-gated task pattern** (single-shell-block status; RESEARCH Pattern 2 lines 325-364 -- closes the ANDed-status-with-feature-gate issue):

```yaml
# Source: 06-RESEARCH.md lines 332-351 (Pattern 2)
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

**Why single-shell-block status (not two-line ANDed):** RESEARCH Pitfall 1 (lines 523-555) explains that two-line ANDed status with feature gates is fragile -- both conditions must pass for skip, but a feature-off machine wants skip with zero verify execution. The single-block form renders `exit 0` at template build time when the feature is off; when on, it runs verify and exits with its return code.

**Kebab-case index form** (CLAUDE.md rule + CF-02):

```yaml
# All five concern gates use index form (kebab-case keys require it):
{{if not (index .MANIFEST.features "macos-dock")}}exit 0{{end}}
{{if not (index .MANIFEST.features "macos-finder")}}exit 0{{end}}
{{if not (index .MANIFEST.features "macos-input")}}exit 0{{end}}
{{if not (index .MANIFEST.features "macos-screenshots")}}exit 0{{end}}
{{if not (index .MANIFEST.features "macos-security")}}exit 0{{end}}
```

**`macos:shell` task pattern** (RESEARCH Pattern 5 lines 439-474 -- the bug-fix shape; BREW_ZSH injection):

```yaml
# Source: 06-RESEARCH.md lines 446-463 (Pattern 5)
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

Note: `macos:shell` is unconditional (D-03, no feature gate) so the two-line ANDed status is correct here -- both conditions always evaluate; no feature short-circuit needed.

**`macos:validate` task pattern** (always-rerun + per-concern feature gate; RESEARCH Pattern 4 lines 387-437; mirrors packages.yml verify lines 184-201 status: [false]):

```yaml
# Source: 06-RESEARCH.md lines 394-437 (Pattern 4)
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
      # ... input, screenshots, security ...

      exit "$failed"
```

**Precondition pattern** (mirrors packages.yml lines 108-114 / identity.yml lines 127-138 -- hard-fail with actionable message when resolved.json missing):

```yaml
# Source: taskfiles/packages.yml lines 109-114
preconditions:
  - sh: test -s '{{.RESOLVED_JSON_PATH}}'
    msg: |
      resolved.json missing or empty; cannot resolve features.macos-*
        run: task setup -- <machine-name>
```

Apply to: `defaults` aggregator (and consider adding to each concern task; packages.yml only puts the precondition on `install`/`compose`/`verify`/`audit` at the top level).

---

### NEW: `os/README.md` (sibling README)

**Primary analog:** `shell/README.md` (52 lines) + `packages/README.md` (121 lines).

**Header pattern** (mirrors shell/README.md lines 1-6):

```markdown
# os

macOS configuration: per-concern `defaults` scripts and shell-registration.
Each concern is feature-gated; `task macos:defaults` orchestrates application;
`task macos:validate` asserts current state against in-script expected values.
macOS-only in v1; the flat layout (no platform subdirectories) collapses when
Linux is in scope -- see `../.planning/ROADMAP.md` for the deferred migration
cost.
```

**Key files section** (mirrors shell/README.md lines 8-23):

```markdown
## Key files

- `defaults/dock.zsh` -- Dock keys (gated on `macos-dock`)
- `defaults/finder.zsh` -- Finder keys (gated on `macos-finder`; shared
  with `shell/aliases/finder.zsh` -- D-01 same-flag-two-consumers)
- `defaults/input.zsh` -- Keyboard / trackpad keys (gated on `macos-input`)
- `defaults/screenshots.zsh` -- Screen capture keys (gated on `macos-screenshots`)
- `defaults/security.zsh` -- Security / privacy keys (gated on `macos-security`)
- `shell-registration.zsh` -- /etc/shells + chsh (always-on, no gate;
  structural fix for the v1 `macos:shell:145` `$BREW_ZSH`-in-status bug)
```

**Adding-a-pattern section** (mirrors shell/README.md lines 25-38 + packages/README.md lines 39-60):

```markdown
## Adding a pattern

- **A new defaults concern.** Create `defaults/<concern>.zsh` with the
  `<CONCERN>_DEFAULTS` tuple array + `apply_<concern>` + `verify_<concern>`
  (one source of truth per concern -- D-02). Add `features.macos-<concern>`
  to `../manifests/defaults.toml` `[features]` with `false`. Add a
  `macos:defaults:<concern>` task to `../taskfiles/macos.yml` (sources the
  script, gates on the feature flag). Wire the task into the
  `macos:defaults` aggregator's `cmds:` list. Enable on machines that want
  it via `../manifests/machines/<name>.toml`.
- **A new key inside an existing concern.** Append one 4-tuple
  `(domain, key, expected_value, write_type)` to the existing
  `<CONCERN>_DEFAULTS` array. Both apply and verify pick it up
  automatically -- the array is the contract.
```

**References section** (mirrors shell/README.md lines 47-52 + packages/README.md lines 114-121):

```markdown
## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics; feature-flag
  reference table
- `../CLAUDE.md` -- v2 conventions (flat directories, one concept per file,
  status-block templating rules, the `macos:shell:145` bug class fix)
- `../.planning/REQUIREMENTS.md` -- OSCF-01..05 traceability
```

---

### MODIFIED: `Taskfile.yml` (root)

**Analog:** existing `links:`, `claude:` include rows (lines 107-108).

**Current state** (line 108):

```yaml
# Source: Taskfile.yml line 108
  claude:   ./taskfiles/claude-stub.yml     # P7 wires real bodies
  macos:    ./taskfiles/macos-stub.yml      # P6 wires real bodies
```

**P6 edit** (single-line flip; matches the P5 pattern where `packages:` was promoted from a stub to a full include with vars-forwarding; here the macos: layer does not need extra vars forwarding -- the local sh: DOTFILEDIR fallback handles it):

```yaml
  claude:   ./taskfiles/claude-stub.yml     # P7 wires real bodies
  macos:    ./taskfiles/macos.yml           # P6 ships real bodies (replaces macos-stub.yml)
```

No edits to `cmds:` -- the root install task at lines 142-143 already calls `task: macos:defaults` then `task: macos:shell` against the stub. The pipeline is unchanged; only the include target flips.

---

### MODIFIED: `manifests/defaults.toml`

**Analog:** existing `[features]` block (lines 23-32).

**Current state** (lines 23-32):

```toml
# Source: manifests/defaults.toml lines 23-32
[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in
# a later phase. Defaults are conservative (mostly off).
one-password-ssh = false
one-password-signing = false   # gates git commit signing via 1Password op-ssh-sign
motd = true
claude-marketplace = true
macos-finder = false  # gates shell/aliases/finder.zsh
ghostty = false       # gates shell/aliases/ghostty.zsh
jgrid-net = false     # gates shell/aliases/jgrid.zsh
```

**P6 edit** (add four kebab-case keys + update the `macos-finder` comment to flag the dual-consumer semantics):

```toml
[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in
# a later phase. Defaults are conservative (mostly off).
one-password-ssh = false
one-password-signing = false   # gates git commit signing via 1Password op-ssh-sign
motd = true
claude-marketplace = true
macos-dock = false        # gates os/defaults/dock.zsh + macos:defaults:dock (P6)
macos-finder = false      # gates shell/aliases/finder.zsh (P3) + os/defaults/finder.zsh (P6) -- D-01 same-flag-two-consumers
macos-input = false       # gates os/defaults/input.zsh + macos:defaults:input (P6)
macos-screenshots = false # gates os/defaults/screenshots.zsh + macos:defaults:screenshots (P6)
macos-security = false    # gates os/defaults/security.zsh + macos:defaults:security (P6)
ghostty = false           # gates shell/aliases/ghostty.zsh
jgrid-net = false         # gates shell/aliases/jgrid.zsh
```

---

### MODIFIED: `manifests/machines/server-1.toml` + `manifests/machines/server-2.toml`

**Analog:** existing `[features]` block on each (server-1 lines 14-17; server-2 lines 14-17 -- identical shape).

**Current state** (server-1 lines 14-17; server-2 identical):

```toml
# Source: manifests/machines/server-1.toml lines 14-17
[features]
one-password-ssh = false
motd = true
claude-marketplace = false
```

**P6 edit** (D-04: servers gain `macos-security = true`; other four macos-* keys stay absent and inherit `false`):

```toml
[features]
one-password-ssh = false
motd = true
claude-marketplace = false
macos-security = true  # P6 D-04: server runs security defaults + shell-registration only
# macos-dock, macos-finder, macos-input, macos-screenshots absent -> inherited false
```

Identical edit on `server-2.toml`. Reference machine for the laptops is `personal-laptop.toml` (lines 15-26) which already declares all five `macos-*` keys as `true` (no edit needed; declared during P5).

---

### MODIFIED: `docs/MANIFEST.md`

**Analog:** existing feature-flag table (lines 450-460 -- rows are already present; the "Default in `defaults.toml`" column says "machine-set (not in defaults.toml)" for all five macos-* rows, which is incorrect post-P6 because P6 explicitly adds the defaults).

**Current state** (lines 450-460):

```markdown
# Source: docs/MANIFEST.md lines 450-460
| Feature | Owner phase | What it does | Default in `defaults.toml` |
|---------|-------------|--------------|---------------------------|
| `one-password-ssh` | Phase 4 | Enables 1Password SSH agent integration | `false` |
| `one-password-signing` | Phase 4 | Enables git commit signing via 1Password op-ssh-sign | `false` |
| `motd` | Phase 3 | Enables MOTD display on `.zlogin` | `true` |
| `claude-marketplace` | Phase 7 | Installs Claude marketplace plugins | `true` |
| `macos-dock` | Phase 6 | Runs `os/defaults/dock.zsh` | machine-set (not in defaults.toml) |
| `macos-finder` | Phase 6 | Runs `os/defaults/finder.zsh` | machine-set (not in defaults.toml) |
| `macos-input` | Phase 6 | Runs `os/defaults/input.zsh` | machine-set (not in defaults.toml) |
| `macos-screenshots` | Phase 6 | Runs `os/defaults/screenshots.zsh` | machine-set (not in defaults.toml) |
| `macos-security` | Phase 6 | Runs `os/defaults/security.zsh` | machine-set (not in defaults.toml) |
```

**P6 edit** (flip the five default cells to `false`; expand `macos-finder` row to note dual-consumer semantics):

```markdown
| `macos-dock` | Phase 6 | Runs `os/defaults/dock.zsh` | `false` |
| `macos-finder` | Phase 3 + Phase 6 | Gates `shell/aliases/finder.zsh` (P3 D-07) + runs `os/defaults/finder.zsh` (P6 D-01 same-flag-two-consumers) | `false` |
| `macos-input` | Phase 6 | Runs `os/defaults/input.zsh` | `false` |
| `macos-screenshots` | Phase 6 | Runs `os/defaults/screenshots.zsh` | `false` |
| `macos-security` | Phase 6 | Runs `os/defaults/security.zsh` | `false` |
```

---

### MODIFIED: `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md`

**Analog:** P5 D-02 textual-amend precedent (ROADMAP success-criterion wording soften when implementation reality diverges from initial wording).

**ROADMAP.md Phase 6 success criterion #1** (current text at line 130):

```markdown
# Source: .planning/ROADMAP.md line 130
  1. On a machine with `features.macos-defaults.dock = true`, `task macos:defaults:dock` writes the configured dock keys; on a machine without the feature, the task is a no-op (skipped at the feature-gate level)
```

**P6 edit** (flat schema -- D-01):

```markdown
  1. On a machine with `features.macos-dock = true`, `task macos:defaults:dock` writes the configured dock keys; on a machine without the feature, the task is a no-op (skipped at the feature-gate level)
```

**ROADMAP.md Phase 6 success criterion #5** (optional soften per D-02 -- current at line 134):

```markdown
  5. `task validate` reads current `defaults` values for declared keys and asserts them against the manifest's expected values for the active machine
```

**Optional P6 edit** (soften "manifest's expected values" -> "in-script expected values" -- values live in the concern scripts per D-02; manifest gates only on/off):

```markdown
  5. `task validate` reads current `defaults` values for declared keys and asserts them against the in-script expected values for each enabled concern
```

**REQUIREMENTS.md OSCF-05** (mirror amend optional; current at line 118 -- requirement is satisfied either way; planner picks).

---

## Shared Patterns

### LINT-02 status template-var discipline

**Source:** `taskfiles/lint.yml:140-155` (LINT-02 implementation) + RESEARCH Pattern 5
**Apply to:** EVERY status: block in `taskfiles/macos.yml`

```yaml
# Source: taskfiles/lint.yml lines 140-150
# --- LINT-02: $VAR-style shell variables inside status: blocks ---
# The macos:shell:145 bug class: $BREW_ZSH is unset in status eval context
# so the check always fails and the task always re-runs.
while IFS= read -r f; do
  out=$(yq '.tasks[] | select(.status) | .status' "$f" 2>/dev/null \
        | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
        | ggrep -vE '\$\(' \
        | ggrep -vE '\{\{' || true)
```

**Concrete rules binding on P6:**
- `status:` blocks reference vars ONLY as `{{.X}}` (template var, resolved at task-graph build time).
- Shell vars inside `cmds:` blocks are fine (LINT-02 only scans `.tasks[] | .status`).
- The `os/shell-registration.zsh` apply path uses `${BREW_ZSH}` (legal -- inside the script body, not the task status); the task `status:` uses `{{.BREW_ZSH}}` (template var).

### LINT-03a aggregator exemption

**Source:** `taskfiles/lint.yml:175-199` (LINT-03a implementation) + RESEARCH Pattern 3
**Apply to:** `macos:defaults` aggregator (cmds: are all `task:` delegations -- auto-exempt) + `macos:validate` (`status: [false]` always-rerun + carry the marker for documentation).

The lint rule auto-exempts tasks whose `cmds:` are all `task:` delegations (line 194-195 in lint.yml). The `# lint-allow: cmds-without-status` marker is documentation -- redundant for the auto-exempt case, but matches packages.yml + identity.yml convention so the planner carries it.

### CF-06 set -euo pipefail discipline

**Source:** `taskfiles/lint.yml:208-228` (LINT-04 implementation)
**Apply to:** All five `os/defaults/<concern>.zsh` files + `os/shell-registration.zsh`

LINT-04 scans for the `set -euo pipefail` line in the first 30 lines of every `-perm +111` (executable bit set) `.zsh` file. Sourced-only files are technically exempt (no executable bit), but the v2 convention is to carry the flag for consistency (CF-06; P4 precedent). Setting the flag does not affect sourced behavior in a parent shell that already has its own pipefail settings; it's defensive.

### Source-messages-from-script pattern

**Source:** `install/messages.zsh:20-21` (double-source guard)
**Apply to:** All five `os/defaults/<concern>.zsh` files + `os/shell-registration.zsh`

```zsh
# Source: install/messages.zsh lines 20-21
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1
```

Idempotent re-sourcing -- safe to call `source "${DOTFILEDIR}/install/messages.zsh"` from each concern script even if the taskfile already sourced it. Pattern: each concern script sources messages.zsh at its top (Claude's Discretion in CONTEXT lines 108-109: "Cleaner: source `messages.zsh` from inside each concern script (idempotent)").

### Manifest read pattern (ref: fromJson)

**Source:** `taskfiles/packages.yml:78-81` + `taskfiles/identity.yml:81-85`
**Apply to:** `taskfiles/macos.yml` vars block

```yaml
# Source: taskfiles/packages.yml lines 77-81
# fromJson ref pattern (matches taskfiles/manifest.yml +
# taskfiles/identity.yml). Downstream consumers use
# {{.MANIFEST.packages.brew.bundles}} via dot-access (snake_case-safe).
MANIFEST:
  ref: 'fromJson .MANIFEST_JSON'
```

P6 access: `{{index .MANIFEST.features "macos-dock"}}` (kebab-case requires `index`). Dot access only valid for snake_case keys (`{{.MANIFEST.identity.git}}`).

### WR-03 manifest-missing fallback

**Source:** `taskfiles/packages.yml:67-75` + `taskfiles/identity.yml:71-79`
**Apply to:** `taskfiles/macos.yml` MANIFEST_JSON var

```yaml
# Source: taskfiles/packages.yml lines 67-75
MANIFEST_JSON:
  sh: |
    if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
      cat '{{.RESOLVED_JSON_PATH}}'
    else
      echo "warning: {{.RESOLVED_JSON_PATH}} missing or empty -- run 'task setup -- <machine>' first" >&2
      echo '{}'
    fi
```

Combined with the `preconditions:` block (`test -s '{{.RESOLVED_JSON_PATH}}'`), this gives loud-fail + actionable-message + safe-fallback when the active machine is not set.

### Deps on :manifest:resolve

**Source:** CF-08 (P1 D-14) + `taskfiles/packages.yml:108` + `taskfiles/identity.yml:111`
**Apply to:** Every `macos:*` task that reads `resolved.json`

```yaml
# Source: taskfiles/identity.yml line 111
deps: [":manifest:resolve"]
```

Critical -- the `:` prefix invokes the root-namespace task (manifest:resolve is included at the root via `manifest:    ./taskfiles/manifest.yml`). Without the leading `:`, go-task looks for a local `manifest:resolve` task inside macos.yml.

---

## No Analog Found

None. Every file in P6's scope has a clear analog in the v2 codebase:

| File | Analog |
|------|--------|
| `os/defaults/<concern>.zsh` (5 files) | `install/messages.zsh` (sourced library shape) + v1 `taskfiles/macos.yml` line ranges (content) -- the tuple-array + apply + verify shape is new but fully specified in RESEARCH Pattern 1 |
| `os/shell-registration.zsh` | same -- sourced library shape from `install/messages.zsh`; content from v1 `taskfiles/macos.yml:111-146` with the `$BREW_ZSH`-in-status fix |
| `taskfiles/macos.yml` | `taskfiles/packages.yml` (primary -- apply/verify shape, status discipline) + `taskfiles/identity.yml` (secondary -- sourced helper + aggregator) |
| `os/README.md` | `shell/README.md` + `packages/README.md` |
| `Taskfile.yml` (root) edit | line 108 single-line flip; matches the P5 packages stub-to-real transition |
| `manifests/defaults.toml` edit | existing `[features]` block, four-row append + one-row comment expand |
| `manifests/machines/server-{1,2}.toml` edit | existing `[features]` block, one-row append |
| `docs/MANIFEST.md` edit | existing feature-flag table, five-row cell update |
| `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` edit | P5 D-02 textual-amend precedent |

The HUMAN-UAT.md file is planner-output (per CONTEXT VALIDATION callout) and not subject to pattern mapping at this stage.

---

## Metadata

**Analog search scope:**
- `taskfiles/*.yml` (10 files; primary analog packages.yml + identity.yml)
- `install/messages.zsh` (sourced library shape)
- `shell/aliases/finder.zsh` (dual-consumer reference)
- `shell/README.md` + `packages/README.md` (sibling README shape)
- `manifests/defaults.toml` + `manifests/machines/*.toml` (TOML config edits)
- `docs/MANIFEST.md` (schema reference table)
- `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` (success-criterion + requirement amends)
- v1 `taskfiles/macos.yml` (sourced for content port; lines 29-184)

**Files scanned:** ~25 Read calls + Grep filters; no re-reads.

**Pattern extraction date:** 2026-05-15.
