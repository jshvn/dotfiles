# Phase 1: Manifest Engine + Repository Skeleton — Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 11 pattern targets (fixture TOMLs + docs intentionally skipped per orchestrator brief)
**Analogs found:** 10 exact / role-match, 1 no-analog (repo-root CLAUDE.md — replace, see §No Analog Found)
**Constraint:** Parallel rewrite — v1 files are read-only references the planner ports patterns from. No v1 source is modified in Phase 1.

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `install/resolver.zsh` | service (zsh executable) | batch / transform (TOML → JSON) | `bootstrap.zsh` + `install/messages.zsh` (executable + library sourcing) + `zsh/.zprofile` (uname-m dispatch) | role-match (no v1 file does TOML→JSON; analog teaches the script skeleton, sourcing pattern, and arch detection) |
| `taskfiles/manifest.yml` | orchestration (go-task module) | request-response (CLI → task) | `taskfiles/common.yml` (vars + `_:` helpers + `status:`), `taskfiles/profile.yml` (CLI_ARGS + preconditions) | exact (two v1 files together cover every needed pattern) |
| `manifests/defaults.toml` | config (TOML schema) | static data | `zsh/configs/trippy.toml`, `zsh/configs/tlrc.toml` | role-match (TOML file-level conventions; no v1 file is a "manifest schema") |
| `manifests/machines/personal-laptop.toml` | config (per-machine TOML) | static data | `zsh/configs/trippy.toml`, `zsh/configs/tlrc.toml` | role-match (TOML conventions only — semantic shape from RESEARCH §3.2) |
| `manifests/machines/work-laptop.toml` | config | static data | same as above | role-match |
| `manifests/machines/server-1.toml` | config | static data | same as above | role-match |
| `manifests/machines/server-2.toml` | config | static data | same as above | role-match |
| `manifests/README.md` | docs (top-level dir README) | static data | RESEARCH.md §8.3 (already content-specified) | exact content provided |
| `manifests/machines/README.md` | docs (subdir README) | static data | RESEARCH.md §8.2 stub template | exact content pattern |
| `manifests/test/README.md` | docs (subdir README) | static data | RESEARCH.md §8.2 stub template | exact content pattern |
| `docs/README.md` | docs (one-liner) | static data | RESEARCH.md §8.3 (content specified) | exact content provided |
| `docs/MANIFEST.md` | docs (long-form) | static data | repo-root `CLAUDE.md`, `.claude/CLAUDE.md` (tone/structure) | role-match (no existing reference doc in v1; outline in RESEARCH §9 is authoritative) |
| `shell/README.md`, `identity/README.md`, `packages/README.md`, `configs/README.md`, `os/README.md` | docs (stub READMEs) | static data | RESEARCH.md §8.2 template | exact content provided |
| `CLAUDE.md` (repo root) | docs (project instructions) | static data | existing `/Users/josh/Git/personal/dotfiles/CLAUDE.md` (v1) | REPLACE — see §No Analog Found |

---

## Repo-Root `CLAUDE.md` — ADD vs REPLACE Determination

**Verified existence:** `ls -la` at `/Users/josh/Git/personal/dotfiles/CLAUDE.md` → exists, 19,577 bytes, last touched 2026-05-13.

**Action: REPLACE.** RESEARCH.md §10 explicitly states "v1 already has a `CLAUDE.md` at repo root with content that's a mix of v1 facts and v2 plans. P1 must **replace** this with v2-only conventions (the v1 facts are now historical and live in `.planning/codebase/`)."

The first 100 lines of the existing file (read this session) confirm it is auto-generated from `PROJECT.md` + `codebase/STACK.md` (note the `<!-- GSD:project-start -->` markers) and references v1 concepts (`$DOTFILES_PROFILE`, profile suffixing) that v2 removes. The planner should **wholesale rewrite** this file using the outline in RESEARCH.md §10. Do not preserve the GSD auto-generation markers — v2 CLAUDE.md is hand-authored project guidance, not a generated index.

---

## Pattern Assignments

### `install/resolver.zsh` (service, batch / transform)

**Analogs:** `/Users/josh/Git/personal/dotfiles/bootstrap.zsh` (executable skeleton), `/Users/josh/Git/personal/dotfiles/install/messages.zsh` (library guard pattern), `/Users/josh/Git/personal/dotfiles/zsh/.zprofile` (Homebrew prefix by `uname -m`).

#### Pattern 1 — Shebang + strict mode

**Source:** `/Users/josh/Git/personal/dotfiles/bootstrap.zsh:1-2`

```zsh
#!/bin/zsh
set -e
```

**Port for resolver:** Per CLAUDE.md and CONVENTIONS, upgrade to `set -euo pipefail` (CONTEXT.md "Established Patterns"). The bare `set -e` in v1 bootstrap is being hardened in Phase 2 — v2 net-new scripts use the strict form from day one. The shebang stays `#!/bin/zsh`.

```zsh
#!/bin/zsh
set -euo pipefail
```

#### Pattern 2 — Source the messages library with double-source guard

**Source:** `/Users/josh/Git/personal/dotfiles/install/messages.zsh:19-21`

```zsh
# Prevent double-sourcing
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1
```

**Consumer side — port for resolver:** `bootstrap.zsh:15` sources unconditionally. Because resolver may be called from a taskfile that has already sourced messages (taskfiles inline-source via `{{.DOTFILES_MESSAGES}}`), the resolver should guard:

```zsh
[[ -n "${DOTFILES_MESSAGES_LOADED:-}" ]] || source "${DOTFILEDIR}/install/messages.zsh"
```

`${...:-}` form is required under `set -u` (the bare `$DOTFILES_MESSAGES_LOADED` in v1 messages.zsh:20 works only because the library is sourced before `set -u` would matter; the resolver runs `set -u` first, then sources).

#### Pattern 3 — DOTFILEDIR resolution (symlink-traversal)

**Source:** `/Users/josh/Git/personal/dotfiles/bootstrap.zsh:5-12`

```zsh
# Resolve DOTFILEDIR first (needed for sourcing messages)
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR
```

**Port for resolver:** When invoked by `task` (the canonical path), `DOTFILEDIR` is already exported by the root `Taskfile.yml` vars block (see Taskfile.yml:17-18). The resolver should NOT re-resolve DOTFILEDIR — it should expect the caller to pass it OR use the env value with a fallback. Concrete pattern:

```zsh
: "${DOTFILEDIR:?DOTFILEDIR not set — run via 'task manifest:*'}"
```

This matches RESEARCH §4.2 line `readonly DEFAULTS="${DOTFILEDIR}/manifests/defaults.toml"` — relies on caller-set DOTFILEDIR. If a standalone CLI mode is desired later, port the symlink-traversal block verbatim.

#### Pattern 4 — Architecture-aware Homebrew dispatch (for tool detection, NOT path hardcoding)

**Source:** `/Users/josh/Git/personal/dotfiles/zsh/.zprofile:33-43`

```zsh
# MacOS
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        DIRECTORY="/opt/homebrew/bin/brew"
    else
        DIRECTORY="/usr/local/bin/brew"
    fi
else
# Linux
    DIRECTORY="/home/linuxbrew/.linuxbrew/bin/brew"
fi
```

**Port for resolver:** The resolver only needs `arch` detection per D-02 (resolver writes `arch` into `resolved.json`). One line suffices — `uname -m` returns `arm64` / `x86_64` directly (verified RESEARCH §2). The v1 .zprofile pattern is the conceptual analog for "branch on architecture without hardcoding paths" — the resolver does not hardcode brew prefix; that's `Taskfile.yml`'s job (see HOMEBREW_PREFIX vars at lines 30-39). Concrete resolver fragment:

```zsh
local arch
arch=$(yq -r '.platform.arch // ""' "$machine_file")
[[ -z "$arch" ]] && arch=$(uname -m)
```

#### Pattern 5 — Hard-fail with actionable error using `error()` library function

**Source:** `/Users/josh/Git/personal/dotfiles/install/messages.zsh:46-48`

```zsh
function error() {
    echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2
}
```

**Port for resolver:** Use `error` (writes to stderr per CONVENTIONS) for the D-16 missing-state failure. Pattern verified in RESEARCH §4.2 — resolver lists available machines and calls `error` three times before `exit 1`. Concrete:

```zsh
error "no machine selected"
error "  run: task setup -- <machine-name>"
error "  available: ${available:-(none — populate manifests/machines/)}"
exit 1
```

#### Pattern 6 — Atomic write via mktemp + mv

**No direct v1 analog.** v1 task files use `tee` (`taskfiles/common.yml:45,49`) which is not atomic for non-trivial writes. The resolver writes a multi-pass JSON pipeline (RESEARCH §4.2 lines 382-387) and per RESEARCH §13 Q5 should write atomically to avoid partial-write windows breaking the downstream `fromJson`. Recommended planner addition (no v1 source to copy from — implement fresh):

```zsh
local tmp
tmp=$(mktemp "${OUT}.XXXXXX")
echo "$merged" \
  | jq --argjson extras "$union_extras" --arg arch "$arch" \
      '.packages.brew.extra_packages = $extras
       | .platform.arch = $arch' \
  > "$tmp"
mv "$tmp" "$OUT"
```

#### Pattern 7 — File-level comment header

**Source:** `/Users/josh/Git/personal/dotfiles/install/messages.zsh:1-18` and `/Users/josh/Git/personal/dotfiles/zsh/.zshenv:1-27`

Both files open with a block comment describing purpose, sourcing context, and usage. CONVENTIONS section "Comments" mandates this for every script. The resolver opens with a header in the same style:

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/resolver.zsh — compile defaults + machine manifest into resolved.json
#
# Sourced from: taskfiles/manifest.yml (manifest:resolve task)
# Reads:        $DOTFILEDIR/manifests/defaults.toml
#               $DOTFILEDIR/manifests/machines/<machine>.toml
# Writes:       $XDG_STATE_HOME/dotfiles/resolved.json
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh
#
# Hard-fails (exit 1) if $XDG_STATE_HOME/dotfiles/machine is missing — caller
# must run `task setup -- <machine-name>` first.
# -----------------------------------------------------------------------------
```

---

### `taskfiles/manifest.yml` (orchestration, request-response)

**Analogs:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml` (vars + `_:` helpers + `status:` blocks), `/Users/josh/Git/personal/dotfiles/taskfiles/profile.yml` (CLI_ARGS handling + `preconditions:` block + `_:check-*` validation pattern).

#### Pattern 1 — Schema version + helpers include header

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml:1-11`

```yaml
version: '3'

# =============================================================================
# Include shared helper tasks
# =============================================================================
# The underscore (_) namespace provides access to reusable helper tasks defined
# in helpers.yml. This avoids duplicating validation logic across taskfiles.
# See helpers.yml for available tasks.
# =============================================================================
includes:
  _: ./helpers.yml
```

**Port for manifest.yml:** Identical opening block — `version: '3'`, the `# === Section Banner ===` style (CONVENTIONS), and `includes: { _: ./helpers.yml }` so `manifest:validate` can call `_:check-file` against `$RESOLVED_JSON_PATH`. The `# ===` separator is the canonical YAML banner style per CONVENTIONS.

#### Pattern 2 — Task-local vars with `sh:` resolvers

**Source:** `/Users/josh/Git/personal/dotfiles/Taskfile.yml:7-52` (root) — pattern of var blocks that combine literal paths and `sh:` invocations:

```yaml
vars:
  XDG_CONFIG_HOME: '{{.HOME}}/.config'
  XDG_STATE_HOME: '{{.HOME}}/.local/state'
  PROFILE_FILE: '{{.XDG_CONFIG_HOME}}/dotfiles/profile'
  PROFILE:
    sh: |
      if [[ -f "{{.PROFILE_FILE}}" ]]; then
        cat "{{.PROFILE_FILE}}" 2>/dev/null | tr -d '[:space:]'
      fi
```

**Port for manifest.yml:** Same pattern, swapping `PROFILE` → `MACHINE` and pointing to STATE_HOME (D-15). Concrete (RESEARCH §6.1 confirms `fromJson` works):

```yaml
vars:
  STATE_DIR: '{{.XDG_STATE_HOME}}/dotfiles'
  STATE_FILE: '{{.STATE_DIR}}/machine'
  RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'
  DEFAULTS_TOML: '{{.DOTFILEDIR}}/manifests/defaults.toml'
  MACHINE:
    sh: |
      if [[ -f "{{.STATE_FILE}}" ]]; then
        cat "{{.STATE_FILE}}" 2>/dev/null | tr -d '[:space:]'
      fi
  MACHINE_TOML: '{{.DOTFILEDIR}}/manifests/machines/{{.MACHINE}}.toml'
  MANIFEST_JSON:
    sh: cat {{.RESOLVED_JSON_PATH}} 2>/dev/null || echo '{}'
  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'
  AVAILABLE_MACHINES:
    sh: |
      ls "{{.DOTFILEDIR}}/manifests/machines/"*.toml 2>/dev/null \
        | xargs -n1 basename \
        | sed 's/\.toml$//' \
        | tr '\n' ' '
```

The `MANIFEST` ref-fromJson line is net-new (no v1 analog — v1 has no JSON-loaded manifest), but RESEARCH §6.1 verifies the syntax against go-task v3.50.

#### Pattern 3 — Inline-source the messages library in every cmd block

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml:22-29`

```yaml
  xdg:
    desc: "Create XDG base directories"
    run: once
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        info "Ensuring XDG Base Directories exist..."
        mkdir -p "{{.XDG_CONFIG_HOME}}"
        ...
        success "XDG Base Directories created"
```

**Port for manifest.yml:** Every cmd block that prints anything starts with `{{.DOTFILES_MESSAGES}}` so `info`, `success`, `warn`, `error`, `check`, `cross` are in scope. `DOTFILES_MESSAGES` is defined in `Taskfile.yml:47-49` as an inline `source` statement — already global to all included taskfiles.

#### Pattern 4 — Idempotent `status:` block

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml:30-34` (XDG dirs) and `taskfiles/common.yml:54-57` (zdotdir)

```yaml
    status:
      - test -d "{{.XDG_CONFIG_HOME}}"
      - test -d "{{.XDG_DATA_HOME}}"
      - test -d "{{.XDG_STATE_HOME}}"
      - test -d "{{.XDG_CACHE_HOME}}"
```

```yaml
    status:
      - |
        ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
        grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv
```

**Port for manifest.yml `manifest:resolve` — fuse with RESEARCH §7 BSD-find pattern:**

```yaml
  manifest:resolve:
    desc: "Compile defaults + active machine TOML to resolved.json (idempotent)"
    deps: [_:require-state]   # see Pattern 6
    cmds:
      - mkdir -p "{{.STATE_DIR}}"
      - zsh "{{.DOTFILEDIR}}/install/resolver.zsh"
    status:
      - test -f "{{.RESOLVED_JSON_PATH}}"
      - |
        ! find "{{.DOTFILEDIR}}/manifests" \
            \( -name 'defaults.toml' -o -path '*/machines/*.toml' \) \
            -newer "{{.RESOLVED_JSON_PATH}}" \
            -print -quit \
          | grep -q .
```

CONVENTIONS rule: status blocks use `{{.X}}` template vars, never `$X` shell vars (the v1 `macos:shell:145` bug class per the v2 CLAUDE.md outline). The find-with-`-newer` syntax is verified BSD-portable in RESEARCH §7.

#### Pattern 5 — `preconditions:` with `msg:` for hard-fail UX

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/profile.yml:40-44`

```yaml
  require:
    desc: "Require profile to be set (fail if not)"
    preconditions:
      - sh: test -f "{{.PROFILE_FILE}}" && test -n "{{.PROFILE}}"
        msg: "Profile not set. Run 'task install' or 'task profile:set PROFILE=personal'"
```

**Port for manifest.yml — D-16 missing-state actionable error (RESEARCH §6.4 verifies `{{.X}}` interpolation inside `msg:`):**

```yaml
  manifest:resolve:
    preconditions:
      - sh: test -f "{{.STATE_FILE}}"
        msg: |
          error: no machine selected
            run: task setup -- <machine-name>
            available: {{.AVAILABLE_MACHINES}}
```

#### Pattern 6 — CLI_ARGS handling for `task setup -- <name>`

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/profile.yml:46-62`

```yaml
  set:
    desc: "Set profile: $ task profile:set -- personal"
    cmds:
      - mkdir -p "$(dirname "{{.PROFILE_FILE}}")"
      - |
        {{.DOTFILES_MESSAGES}}
        INPUT_PROFILE="{{.CLI_ARGS}}"
        if [[ -z "$INPUT_PROFILE" ]]; then
          error "Profile required. Use: task profile:set -- personal"
          exit 1
        fi
        if [[ ! " {{.VALID_PROFILES}} " =~ " $INPUT_PROFILE " ]]; then
          error "Invalid profile '$INPUT_PROFILE'. Must be one of: {{.VALID_PROFILES}}"
          exit 1
        fi
        echo "$INPUT_PROFILE" > "{{.PROFILE_FILE}}"
        success "Profile set to: $INPUT_PROFILE"
```

**Port for `task setup -- <name>` — fuse with RESEARCH §12 security hardening (regex + manifest-file existence check BEFORE state-file write):**

```yaml
  setup:
    desc: "Persist active machine selection: task setup -- <machine-name>"
    requires:
      vars: [CLI_ARGS]
    preconditions:
      - sh: |
          name="{{.CLI_ARGS}}"
          # Reject anything that isn't a kebab-case identifier (path-traversal guard)
          [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 1
          # Reject if the manifest file doesn't exist
          test -f "{{.DOTFILEDIR}}/manifests/machines/${name}.toml"
        msg: |
          error: invalid or unknown machine: "{{.CLI_ARGS}}"
            available: {{.AVAILABLE_MACHINES}}
    cmds:
      - mkdir -p "{{.STATE_DIR}}"
      - echo "{{.CLI_ARGS}}" > "{{.STATE_FILE}}"
      - |
        {{.DOTFILES_MESSAGES}}
        success "Machine set to: {{.CLI_ARGS}}"
      - task: manifest:validate
      - task: manifest:resolve
```

The v1 pattern checks against an inline-string whitelist; v2 swaps that for the file-existence check (`test -f manifests/machines/<name>.toml`) so adding a machine is a single TOML file. The kebab-case regex is the security guard per RESEARCH §12.

#### Pattern 7 — Validation task using `_:check-*` helpers

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml:76-105` (whole `validate` task)

```yaml
  validate:
    desc: "Validate common components (XDG, ZDOTDIR, Antigen)"
    cmds:
      - task: _:check-dir
        vars: { TARGET: "{{.XDG_CONFIG_HOME}}", NAME: "XDG config home" }
      - task: _:check-dir
        vars: { TARGET: "{{.XDG_STATE_HOME}}", NAME: "XDG state home" }
      - task: _:check-file
        vars: { TARGET: "{{.HOMEBREW_PREFIX}}/share/antigen/antigen.zsh", NAME: "Antigen" }
```

**Port for `manifest:validate`:** mix `_:check-file` for file presence with inline yq schema checks for D-03 required-field set. The hand-rolled validation logic lives in `install/resolver.zsh` (RESEARCH §3.3 — sharing the script avoids duplicating validation between resolve and validate). The task wires it:

```yaml
  manifest:validate:
    desc: "Validate active (or --machine NAME) manifest schema"
    cmds:
      - task: _:check-file
        vars: { TARGET: "{{.DEFAULTS_TOML}}", NAME: "manifests/defaults.toml" }
      - task: _:check-file
        vars: { TARGET: "{{.MACHINE_TOML}}", NAME: "manifests/machines/{{.MACHINE}}.toml" }
      - |
        {{.DOTFILES_MESSAGES}}
        zsh "{{.DOTFILEDIR}}/install/resolver.zsh" --validate-only --machine "{{.MACHINE}}"
```

#### Pattern 8 — Section-banner comments

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/common.yml:14-16, 72-74`

```yaml
  # ============================================================================
  # XDG Base Directories
  # ============================================================================
```

**Port:** Use `# ====` banners around each section (Vars, Tasks: Setup, Tasks: Resolve, Tasks: Show, Tasks: Validate, Tasks: Test, Tasks: Validation Helpers). CONVENTIONS canonicalizes `# ===` and `# ---` banners.

#### Pattern 9 — Wiring into root `Taskfile.yml` includes

**Source:** `/Users/josh/Git/personal/dotfiles/Taskfile.yml:54-72`

```yaml
includes:
  common: ./taskfiles/common.yml
  profile: ./taskfiles/profile.yml
  links: ./taskfiles/links.yml
  brew: ./taskfiles/brew.yml
  macos: ./taskfiles/macos.yml
  claude: ./taskfiles/claude.yml
```

**Port:** Per RESEARCH §8.1 "**`taskfiles/manifest.yml` is wired into the root `Taskfile.yml`** by adding `manifest: ./taskfiles/manifest.yml` under `includes:`. This is a low-risk one-line edit to Taskfile.yml."

**HOWEVER** — orchestrator brief explicitly says "DOES NOT modify root `Taskfile.yml`" for Phase 1. Two reconciliation options for the planner:

1. **Honor the orchestrator brief literally** — leave Taskfile.yml alone in P1; expose manifest tasks via direct `task -t taskfiles/manifest.yml <subtask>` invocation; defer the one-line include to Phase 2 when bootstrap is rewritten. This keeps the parallel-rewrite invariant pure.
2. **Append-only edit** — adding one line under existing `includes:` is technically a modification but is non-destructive. RESEARCH considers it low-risk.

**Recommendation for the planner:** Option 1 — the brief is explicit. Document the future one-line addition in `docs/MANIFEST.md` "CLI Reference" as a Phase 2 follow-up. Phase 1 users invoke tasks via `task -t taskfiles/manifest.yml manifest:resolve` or via a tiny `task manifest` shim if needed. Note this as a known UX wart that Phase 2 closes.

---

### `manifests/defaults.toml` (config, static data)

**Analogs:** `/Users/josh/Git/personal/dotfiles/zsh/configs/trippy.toml`, `/Users/josh/Git/personal/dotfiles/zsh/configs/tlrc.toml`.

**Note:** No v1 file has the manifest's *semantic* shape; the analogs teach *TOML file-level conventions only*. The schema shape is locked in RESEARCH §3.1 and CONTEXT.md decisions D-01..D-06.

#### Pattern 1 — File header as a block comment

**Source:** `/Users/josh/Git/personal/dotfiles/zsh/configs/trippy.toml:1-15`

```toml
# Sample config file for Trippy.
#
# Copy this template config file to your platform specific config dir.
#
# Trippy will attempt to locate a `trippy.toml` or `.trippy.toml` config file
# in one of the following locations:
#   the current directory
#   ...
# All sections and all items within each section are non-mandatory.
```

**Port for `defaults.toml`:** Open with a `#` block describing role (shared baseline, every machine inherits), reference to the schema doc (`docs/MANIFEST.md`), and merge-rule reminder.

```toml
# manifests/defaults.toml — shared baseline inherited by every machine manifest.
#
# Schema reference: docs/MANIFEST.md
# Merge semantics:  deep-merge maps, replace scalars/arrays, concat extra_packages.
# Required fields:  must still be declared explicitly in each manifests/machines/<name>.toml
#                   (defaults supply shape; machine declarations are the validation surface).
```

#### Pattern 2 — Inline section comments

**Source:** `/Users/josh/Git/personal/dotfiles/zsh/configs/trippy.toml:21-35`

```toml
[trippy]

# The Trippy mode.
#
# Allowed values are:
#   tui         - Display interactive Tui [default]
#   stream      - Display a continuous stream of tracing data
mode = "tui"
```

**Port:** Each table block in `defaults.toml` is preceded by a `#` comment describing the section's role. Inline `# ...` comments on individual keys document allowed values, especially for the enum-shaped strings (`identity.git = "personal" | "work" | "none"`). The schema shape from RESEARCH §3.1:

```toml
schema_version = 1

[meta]
description = "default — machine must override"

[platform]
# Required field — every machine must explicitly set this (validator enforces).
# v1: must equal "darwin"; v2 will accept "linux" as well.
os = "darwin"

[features]
# Opt-in flags consumed by downstream tasks. Each is owned by exactly one phase.
# kebab-case keys MUST be accessed via {{index .MANIFEST.features "name"}} in taskfiles.
one-password-ssh = false
motd = true
claude-marketplace = true

[packages.brew]
# Bundle names map to packages/<name>.rb (Phase 5).
bundles = ["core"]
# Additive escape hatch — concat+dedupe with machine's extras at resolve time.
extra_packages = []

[identity]
# Allowed: "personal" | "work" | "none". Drives Phase 4 git+SSH config selection.
git = "none"
ssh = "none"
```

#### Pattern 3 — TOML naming and formatting (no spaces in keys, kebab-case)

**Source:** `/Users/josh/Git/personal/dotfiles/zsh/configs/trippy.toml:91-92` (`target-port`, `max-samples`), `tlrc.toml:1-7` (`auto_update`, `defer_auto_update`, etc.)

Observation: existing v1 TOML files use a mix of `kebab-case` (trippy.toml) and `snake_case` (tlrc.toml). For manifests, **kebab-case is mandated** by CONVENTIONS and project CLAUDE.md (features and machine names). Match trippy.toml's style for feature flags. `schema_version` is `snake_case` because go-template dot-access works with `_` but not `-` (RESEARCH §6.2 — the kebab/index trap applies to anything under `[features]`).

---

### `manifests/machines/personal-laptop.toml` (config, static data)

Same analogs and patterns as `defaults.toml`. Concrete shape from RESEARCH §3.2:

```toml
# manifests/machines/personal-laptop.toml — Josh's personal MacBook Pro.
#
# This machine is the daily driver: full GUI + dev + personal feature set.
# See docs/MANIFEST.md for the schema reference and field semantics.

schema_version = 1

[meta]
description = "Josh's personal MacBook — Apple Silicon, primary dev machine"

[platform]
os = "darwin"
arch = "arm64"            # optional; resolver fills via uname -m if absent

[features]
one-password-ssh = true
macos-dock = true
macos-finder = true
macos-input = true
macos-screenshots = true
macos-security = true
motd = true
claude-marketplace = true

[packages.brew]
bundles = ["core", "gui", "dev", "personal"]
extra_packages = ["docker-desktop"]

[identity]
git = "personal"
ssh = "personal"
```

**For `work-laptop.toml`, `server-1.toml`, `server-2.toml`:** identical schema, different values. Servers omit GUI feature flags, use `bundles = ["core"]` (or `["core", "server"]` if a server bundle is added in Phase 5 — defer), set `identity.git = "none"`, `identity.ssh = "none"` (or `"personal"` for personal servers). Per CONTEXT.md "Reference machine list."

---

### Stub READMEs (`shell/`, `identity/`, `packages/`, `configs/`, `os/`)

**Analog:** RESEARCH.md §8.2 template (content fully specified).

**Pattern (verbatim from RESEARCH §8.2):**

```markdown
# <directory-name>

<one-line purpose>

**Populated by Phase <N> — see `.planning/ROADMAP.md`.**

**Requirements landing here:** <REQ-IDs>

Until then this directory is intentionally empty. The manifest layer
(`manifests/`) drives what eventually lands here at install time.
```

**Per-directory binding (from RESEARCH §8.2 mapping table):**

| File | Purpose line | Phase | Requirements |
|------|--------------|-------|--------------|
| `shell/README.md` | zsh startup chain, aliases, functions, and theme. | 3 | SHEL-01..SHEL-12, DOCS-02 |
| `identity/README.md` | Git and SSH identity configs (personal, work, none). | 4 | IDNT-01..08 |
| `packages/README.md` | Homebrew bundles by purpose (core, gui, dev, personal, ...). | 5 | PKGS-01..05, VRFY-01..04 |
| `configs/README.md` | Tool configs (ghostty, glow, trippy, tlrc, conda, ...). | 7 | TOOL-01..04 |
| `os/README.md` | macOS `defaults write` scripts plus shell registration. | 6 | OSCF-01..05 |

Per D-11: each stub stays under ~10 lines. Phase that populates the dir replaces the stub with the real README.

---

### `manifests/README.md`, `manifests/machines/README.md`, `manifests/test/README.md`, `docs/README.md`

**Analog:** RESEARCH §8.3 (content provided).

Use the prose blocks from RESEARCH §8.3 verbatim. `manifests/machines/README.md` and `manifests/test/README.md` are not specified verbatim — port the same stub template (purpose line, see-also link, no implementation details):

```markdown
# manifests/machines

One TOML manifest per machine. Each machine inherits from `../defaults.toml`.

See `../../docs/MANIFEST.md` for schema and worked examples.
Add a machine: create `<name>.toml` here, then `task setup -- <name>`.
```

```markdown
# manifests/test

Golden-output test fixtures for the deep-merge resolver.

Each fixture under `fixtures/<NN>-<name>/` has:
- `defaults.toml` — fixture-scoped defaults
- `machine.toml`  — fixture-scoped machine override
- `expected.json` — hand-computed expected resolver output

Run: `task manifest:test` (in Phase 1, via `task -t taskfiles/manifest.yml manifest:test`).
```

---

### `docs/MANIFEST.md` (docs, static long-form)

**Analog (tone/structure only):** repo-root `CLAUDE.md` v1 and `.claude/CLAUDE.md` v1.

**Authoritative outline:** RESEARCH §9. The planner ports the §9 outline verbatim — every section heading, every table column, every worked example. Tone matches existing CLAUDE.md files: declarative, table-heavy, code-block-heavy, second-person ("Add a machine: ..."), no emojis.

Style points to preserve from the v1 analogs:
- `##` for top-level sections, `###` for subsections.
- Tables for enumerable schemas (required fields, feature flags).
- Inline code (`backticks`) for filenames, command names, manifest keys.
- Triple-backtick fenced blocks with explicit language hint (` ```toml `, ` ```yaml `, ` ```zsh `).
- "Why" sections (rationale paragraphs) follow each rule — see existing CLAUDE.md §"Architecture → Anti-Patterns" for the style.
- No AI attribution; no emojis in markdown either (project convention is stricter than the global "no emojis in non-markdown" rule per the hook description in v1 CLAUDE.md).

---

### `CLAUDE.md` (repo root — REPLACE)

**Authoritative outline:** RESEARCH §10. Wholesale rewrite.

Key v1 → v2 deltas the planner enforces:
- Remove `$DOTFILES_PROFILE` / profile-suffix references — v2 has machines, not profiles.
- Remove platform-subdir patterns (`aliases/{common,personal,work}/`) — v2 is flat.
- ADD: "kebab-case keys in `[features]` MUST be accessed via `{{index .MANIFEST.features "name"}}` in taskfiles" (RESEARCH §6.2 verified gotcha).
- ADD: "manifests are the source of truth" — never read TOML in a taskfile, never grep hostname, always read `resolved.json` via `fromJson`.
- ADD: "status blocks use `{{.X}}` template vars, never `$X` shell vars" (the `macos:shell:145` bug class).

Drop the GSD auto-generation markers (`<!-- GSD:project-start -->` etc.) — v2 CLAUDE.md is hand-authored, not generated.

---

## Shared Patterns (cross-cutting)

### S1 — Strict mode on every executable .zsh

**Source:** rule in `CONVENTIONS.md` and project `CLAUDE.md`; v1 partial implementation in `bootstrap.zsh:2` (`set -e` only — being hardened in P2).
**Apply to:** `install/resolver.zsh` (the only new executable zsh in P1).
**Pattern:**
```zsh
#!/bin/zsh
set -euo pipefail
```

### S2 — Inline-source DOTFILES_MESSAGES in every cmd block that prints

**Source:** every existing v1 taskfile (e.g., `taskfiles/common.yml:23, 41, 64`); definition at `Taskfile.yml:47-49`.
**Apply to:** every `cmd:` in `taskfiles/manifest.yml` that calls `info`, `success`, `warn`, `error`, `check`, `cross`.
**Pattern:**
```yaml
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    info "..."
    ...
    success "..."
```

### S3 — Errors to stderr via `error()`, exit non-zero immediately

**Source:** `install/messages.zsh:46-48` (writes `>&2`), `taskfiles/profile.yml:54-56` (exit 1 after error).
**Apply to:** `install/resolver.zsh` D-16 missing-state branch, `manifest:validate` schema failures, `setup` invalid-machine-name branch.
**Pattern:**
```zsh
error "machine manifest not found: ${machine_file}"
exit 1
```

### S4 — Idempotency via `status:` block on every task that performs work

**Source:** `taskfiles/common.yml:30-34` (XDG dirs), `taskfiles/common.yml:54-57` (zdotdir), CONVENTIONS rule.
**Apply to:** `manifest:resolve` (mtime check via BSD find — RESEARCH §7), implicit on read-only tasks (`manifest:show`, `manifest:validate`, `manifest:test`).
**Critical rule (from v2 CLAUDE.md outline):** Status blocks MUST use `{{.X}}` template vars, not `$X` shell vars. v1's `macos:shell:145` bug is exactly this class — don't reintroduce.

### S5 — XDG base directory exclusivity

**Source:** `zsh/.zshenv:31-34`, root `Taskfile.yml:9-13`.
**Apply to:** every new file. State files under `$XDG_STATE_HOME/dotfiles/`; configs (none in P1) would go under `$XDG_CONFIG_HOME`; nothing in `$HOME` directly.
**Pattern:** Defaults follow the `${VAR:-default}` form (zshenv style) for shell scripts; taskfile vars use `{{.XDG_STATE_HOME}}` (already exported by root Taskfile.yml).

### S6 — Architecture detection via `uname -m`, never hardcode brew prefix

**Source:** `zsh/.zprofile:33-43`, root `Taskfile.yml:30-39` HOMEBREW_PREFIX vars block.
**Apply to:** `install/resolver.zsh` `arch` detection (D-02 fallback when machine TOML omits `platform.arch`).
**Pattern:** `arch=$(uname -m)` — returns `arm64` or `x86_64` directly (verified RESEARCH §2). The resolver does not need brew prefix detection itself — taskfile vars supply `{{.HOMEBREW_PREFIX}}` for any future need.

### S7 — File-level comment header on every script

**Source:** `install/messages.zsh:1-18`, `zsh/.zshenv:1-27`, `zsh/.zprofile:1-31`, every `taskfiles/*.yml`.
**Apply to:** `install/resolver.zsh`, `taskfiles/manifest.yml`, every TOML manifest, every README.
**Pattern:** Open with a comment block describing purpose, sourced-by/called-by context, dependencies, and side effects. YAML files use `# === Banner ===` separators between sections; TOML and zsh use `# ----- Section -----` or aligned `#` blocks.

### S8 — No AI attribution, no emojis in non-markdown

**Source:** rule in global `CLAUDE.md` ("No AI attribution anywhere — no Co-Authored-By trailers, no 'generated by' comments, not in source code or commit messages") and project conventions (hooks `no-emojis.zsh`, `no-ai-comments.zsh`).
**Apply to:** every new file (resolver, taskfile, TOMLs, READMEs, docs/MANIFEST.md, repo-root CLAUDE.md). Markdown files also avoid emojis per project preference (CLAUDE.md v1 has none).

### S9 — `_:` namespace for internal/helper tasks

**Source:** `taskfiles/helpers.yml:14-23` (header doc), every `_:check-*` and `_:safe-link` definition.
**Apply to:** any helper task introduced in `taskfiles/manifest.yml`. If `manifest:validate` or `manifest:test` needs a parameterized helper (e.g., "diff one fixture"), put it under a `_:` prefix and mark `internal: true`.
**Pattern:**
```yaml
  _:diff-fixture:
    internal: true
    requires:
      vars: [FIXTURE_DIR]
    cmds:
      - diff <(jq -S . "{{.FIXTURE_DIR}}/expected.json") <(jq -S . "{{.FIXTURE_DIR}}/actual.json")
```

### S10 — kebab-case filenames, no spaces, no underscores in zsh files

**Source:** CONVENTIONS section "Naming Conventions"; v1 examples: `messages.zsh`, `safe-link` (task name with hyphen).
**Apply to:** machine manifest names (`personal-laptop.toml`, `work-laptop.toml`, `server-1.toml`, `server-2.toml`), task names (`manifest:resolve`, `manifest:show`, `manifest:validate`, `manifest:test`), fixture directory names (`01-map-over-map`, `06-extra-packages-concat`).

---

## No Analog Found

| File | Reason | Planner Reference |
|------|--------|-------------------|
| `manifests/test/fixtures/*/expected.json` | Pure golden-output data — no analog needed. Hand-compute per merge rules in RESEARCH §4.1 + §5. | RESEARCH §4.1 table (six fixture cases verified end-to-end this session) |
| `manifests/test/fixtures/_invalid-*/machine.toml` | Negative-test fixtures (intentionally malformed). No analog in v1; semantics specified by D-03 + D-01 (RESEARCH §11.4). | RESEARCH §3.3 (required-field set) |
| `CLAUDE.md` (repo root) | v1 file exists but is auto-generated from PROJECT.md / codebase index files. v2 is hand-authored and conceptually different (manifest-driven, not profile-driven). Treat as REPLACE, not modify. | RESEARCH §10 (full outline) |
| The two-pass `extra_packages` merge logic in resolver | No v1 file does anything like this. Pure implementation against RESEARCH §5. | RESEARCH §5 (concrete fragment) |

---

## Metadata

**Analog search scope:** `bootstrap.zsh`, `install/messages.zsh`, `Taskfile.yml`, `taskfiles/common.yml`, `taskfiles/helpers.yml`, `taskfiles/profile.yml`, `zsh/.zshenv`, `zsh/.zprofile`, `zsh/configs/trippy.toml`, `zsh/configs/tlrc.toml`, repo-root `CLAUDE.md` (first 100 lines).
**Files scanned (existence check only):** 11 in `taskfiles/`, 6 TOMLs in `zsh/configs/`, 4 zsh startup files, plus directory listings for `/install/`, `/zsh/`, root.
**Files NOT scanned (out of P1 scope per orchestrator brief):** `taskfiles/links.yml`, `taskfiles/brew.yml`, `taskfiles/claude.yml`, `taskfiles/macos.yml`, `taskfiles/profile-tasks.yml`, all of `git/`, `ssh/`, `claude/`, `zsh/aliases/`, `zsh/functions/`.
**Pattern extraction date:** 2026-05-13

**Cross-cutting reminder for the planner:** the parallel-rewrite invariant means every analog cited above is a *read-only reference*. Phase 1 must not edit `bootstrap.zsh`, `install/messages.zsh`, `Taskfile.yml`, or any existing `taskfiles/*.yml`. Phase 1's only writes are NEW files plus a REPLACE of the auto-generated repo-root `CLAUDE.md` (see §No Analog Found).
