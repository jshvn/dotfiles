# Phase 5: Packages Layer - Brewfile Composition + Verification - Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 14 (5 new, 9 modified)
**Analogs found:** 12 / 14 (2 files have no direct analog; precedent files identified)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `packages/core.rb` (new) | bundle/config | static-content | `install/Brewfile.rb` | exact (v1 verbatim port) |
| `packages/gui.rb` (new) | bundle/config | static-content | `install/Brewfile-personal.rb` (cask-args + cask lines), `install/Brewfile.rb` (file shape) | partial -- new convention (mandatory `# verify:`) |
| `packages/README.md` (rewrite) | docs | static-content | `shell/README.md` | role-match |
| `taskfiles/packages.yml` (new) | taskfile | event-driven + request-response | `taskfiles/identity.yml` | exact (deps + fromJson + status block topology) |
| `install/compose-brewfile.zsh` (new, optional) | script/utility | file-I/O (transform) | `install/resolver.zsh` | exact (jq read of resolved.json + mktemp+mv) |
| `manifests/defaults.toml` (edit) | config/schema | static-content | own current `[packages.brew]` block (lines 34-39) | self-replacement |
| `manifests/machines/personal-laptop.toml` (edit) | config/schema | static-content | own current file (lines 28-30) | self-replacement |
| `manifests/machines/work-laptop.toml` (edit) | config/schema | static-content | own current file (lines 26-27) | self-replacement |
| `manifests/machines/server-1.toml` (edit) | config/schema | static-content | own current file (lines 19-20) | self-replacement |
| `manifests/machines/server-2.toml` (edit) | config/schema | static-content | own current file (lines 19-20) | self-replacement |
| `Taskfile.yml` (edit) | taskfile/root | request-response | own current includes block (lines 74-97) + install task (lines 111-135) | self-replacement |
| `docs/MANIFEST.md` (edit) | docs/schema | static-content | own current schema tables (lines 90, 100) | self-replacement |
| `.planning/REQUIREMENTS.md` (edit, PKGS-01 + PKGS-04 text) | docs | static-content | own current PKGS-01/04 lines | self-replacement |
| `.planning/ROADMAP.md` (edit, Phase 5 success #3) | docs | static-content | own current Phase 5 section | self-replacement |
| `.planning/PROJECT.md` (edit, Validated/Active lines) | docs | static-content | own current PROJECT.md package lines | self-replacement |

---

## Pattern Assignments

### `packages/core.rb` (bundle, static-content) -- new

**Analog:** `install/Brewfile.rb` (v1 source; ports nearly verbatim per CONTEXT D-domain).

**File-header pattern** (Brewfile.rb has no top-of-file comment block; v2 introduces one).
The CONTEXT block (`<specifics>` section, lines 264-302) already prescribes the new header:

```ruby
# packages/core.rb -- server-safe CLI baseline. Every machine includes this.
#
# Verify rules:
#   brew '<name>'                  -> command -v <name>     (default)
#   brew '<name>' # verify: <bin>  -> command -v <bin>      (override)
```

This matches the file-level comment block convention from `CLAUDE.md` ("File-level
comment block at the top of every script explaining its purpose, callers, and
side effects").

**Body pattern -- bare `brew` lines + inline verify-comment overrides** (v1 source, `install/Brewfile.rb` lines 1-96):

```ruby
brew "zsh"
brew "go-task"
# ...
brew "git-delta"
brew "coreutils"
brew "mas"
```

**Surgery:** drop `brew "antigen"` (Brewfile.rb:71 -- P3 replaced antigen with
antidote); add `brew "antidote"` if not already there. Add `# verify: <bin>`
suffix to non-conformers per D-05:

- `brew 'git-delta'   # verify: delta`
- `brew 'grep'        # verify: ggrep`
- `brew 'openssh'     # verify: ssh`
- `brew 'trippy'      # verify: trip`
- `brew 'bottom'      # verify: btm`
- `brew 'coreutils'   # verify: gsha256sum`

Per CONTEXT Claude's-Discretion footnote, `1password-cli` lands here as
`brew '1password-cli' # verify: op` (uniform formula-line verify; cask
would have no `.app`).

**No precedent / new pattern flagged:**
- The inline `# verify: <bin>` comment shape is new in v2. v1 Brewfiles
  have no comment-borne semantics.

---

### `packages/gui.rb` (bundle, static-content) -- new

**Analog:** partial -- `install/Brewfile-personal.rb` for `cask_args appdir:` +
`cask "<name>"` shape (lines 11-46); `install/Brewfile.rb` for top-comment shape.

**File-header pattern** (new -- CONTEXT prescribes):

```ruby
# packages/gui.rb -- laptop GUI baseline. Any machine with a display.
#
# Verify rules:
#   cask '<name>' # verify: <App Name>  -> /Applications/<App Name>.app  (MANDATORY)
```

**Body pattern -- cask lines + MANDATORY inline `# verify:` comment** (new; v1
analog had unannotated casks):

```ruby
cask '1password'   # verify: 1Password
cask 'ghostty'     # verify: Ghostty
```

**Reference cask line from v1 for shape only** (`install/Brewfile-personal.rb:11`):

```ruby
cask_args appdir: "/Applications"
cask "discord"
cask "1password"
```

v2's `gui.rb` drops the `cask_args appdir:` directive (the composed Brewfile
inherits `brew bundle`'s default `/Applications`) and adopts the mandatory
verify-comment per D-04. The composer will not derive verify names; every
cask line is required to carry `# verify: <App>` -- LINT-09 (proposed in
CONTEXT Claude's Discretion) enforces this.

**No precedent / new pattern flagged:**
- A cask-only bundle file with mandatory `# verify:` on every line. v1
  Brewfile-*.rb mixes casks and `mas` and uses unannotated `cask "..."`.
- The minimum-set policy (1Password + Ghostty) -- v1 GUI inventories were
  per-machine, not per-bundle.

---

### `packages/README.md` (docs, static-content) -- rewrite

**Analog:** `shell/README.md` (the README-per-directory pattern set by Phase 3 +
referenced by DOCS-02; same project precedent for "real README replacing Phase 1
stub").

**Frontmatter pattern** (shell/README.md lines 1-7):

```markdown
# shell

Zsh startup files, theme, aliases, and functions. Sourced by every login or
interactive shell on a converged v2 machine. macOS-only in v1; the flat
layout (no platform subdirectories) collapses when Linux is in scope --
see `../.planning/ROADMAP.md` for the deferred migration cost.
```

**Adopt this shape for `packages/README.md`:** one-paragraph purpose summary,
then a "Key files" section enumerating the bundle files, then an "Adding a
pattern" section covering "add a bundle file" vs "add to a machine manifest"
vs "add a per-line `# verify:` override."

**"Adding a pattern" pattern** (shell/README.md lines 25-38):

```markdown
## Adding a pattern

- **An alias.** Create `aliases/<topic>.zsh`. If the alias is GUI-coupled
  or identity-coupled, gate inside the file: wrapper-function gate for
  1-3 aliases (D-07) [...]
- **A function.** Create `functions/<name>.zsh`; the filename equals the
  function name. [...]
- **A feature flag.** Add the kebab-case key to `../manifests/defaults.toml`
```

Packages README mirrors with: add a bundle file, add a machine extras entry,
add a verify-comment override. Cask `# verify:` is MANDATORY -- call this out
explicitly.

---

### `taskfiles/packages.yml` (taskfile, event-driven + request-response) -- new

**Analog (primary):** `taskfiles/identity.yml` -- exact match for
`deps: [manifest:resolve]` + `fromJson` MANIFEST loading + `_:check-link`/
`_:check-file` validation patterns + `# lint-allow: cmds-without-status`
aggregator marker.

**Analog (secondary):** `taskfiles/shell.yml` -- compact single-purpose taskfile
with self-contained vars block, used as a model for `packages:verify` /
`packages:audit` measurement-style tasks.

**File-header pattern** (identity.yml lines 1-44, including conventions block):

```yaml
version: '3'

# =============================================================================
# taskfiles/packages.yml -- Phase 5 manifest-driven package layer.
#
# Purpose:
#   Reads packages.brew.bundles, packages.brew.extra_packages.{formulae,casks,mas}
#   from resolved.json via `ref: fromJson` and composes the per-machine Brewfile
#   to $XDG_CACHE_HOME/dotfiles/Brewfile, then runs `brew bundle install` and
#   verifies post-install state (every formula bin on PATH; every cask .app in
#   /Applications).
#
# Dependencies:
#   - manifest:resolve (deps) -- ensures resolved.json is current.
#   - taskfiles/helpers.yml -- _:check-command, _:check-file for verify
#     building blocks.
#   - install/messages.zsh sourced via {{.DOTFILES_MESSAGES}} for check/cross.
#
# Status-block convention (LINT-02 enforcement):
#   Every install sub-task uses a `status:` block. Status blocks use `{{.X}}`
#   template vars ONLY -- never `$X` shell vars. Aggregator tasks
#   (install, verify, audit) intentionally omit `status:` and carry the
#   `# lint-allow: cmds-without-status` marker.
# =============================================================================
```

Copy this convention block verbatim with packages-specific edits.

**Includes pattern** (identity.yml lines 46-47, shell.yml lines 30-31):

```yaml
includes:
  _: ./helpers.yml
```

**Vars-block pattern** (identity.yml lines 54-95, the self-contained vars block):

```yaml
vars:
  HOME: '{{.HOME}}'

  XDG_CONFIG_HOME:
    sh: echo "${XDG_CONFIG_HOME:-$HOME/.config}"
  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"
  XDG_CACHE_HOME:
    sh: echo "${XDG_CACHE_HOME:-$HOME/.cache}"

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

  # Derived path vars
  COMPOSED_BREWFILE: '{{.XDG_CACHE_HOME}}/dotfiles/Brewfile'
```

Adopt verbatim. `COMPOSED_BREWFILE` is the new derived path for the composed
Brewfile cache (D-08; CF-07).

**Aggregator pattern (no status block)** (identity.yml lines 107-114):

```yaml
# lint-allow: cmds-without-status
install:
  desc: "Install identity layer (git + ssh)"
  deps: [":manifest:resolve"]
  cmds:
    - task: git
    - task: ssh
```

For `packages:install`, decision per CONTEXT Claude's Discretion: either a
single task with the two-condition status block (D-09) OR split into
`compose` + `brew-install` + `verify` sub-tasks (then `install` is an
aggregator). Both shapes have precedent in identity.yml.

**`deps: [":manifest:resolve"]`** -- note the leading colon. This is the
correct cross-include task reference when the root Taskfile.yml maps
`manifest:` to `./taskfiles/manifest.yml`. (CF-08; identity.yml:111)

**Status-block pattern with manifest values** (identity.yml lines 155-162):

```yaml
status:
  - test -L "{{.GIT_CONFIG_DIR}}/config"
  - test -L "{{.GIT_CONFIG_DIR}}/identities/personal"
```

For `packages:install` (D-09, two-condition status):

```yaml
status:
  - test -f "{{.COMPOSED_BREWFILE}}"
  - brew bundle check --file="{{.COMPOSED_BREWFILE}}" --no-upgrade
```

LINT-02 contract: `{{.COMPOSED_BREWFILE}}` is a template var; `$COMPOSED_BREWFILE`
would be a LINT-02 violation.

**Preconditions pattern (resolved.json absence guard)** (identity.yml lines
127-138):

```yaml
preconditions:
  - sh: test -s '{{.RESOLVED_JSON_PATH}}'
    msg: |
      resolved.json missing or empty; cannot resolve packages.brew.bundles
        run: task setup -- <machine-name>
```

Adopt verbatim for `packages:install` and `packages:compose` (any task that
reads `{{.MANIFEST.packages.brew.*}}`).

**jq read of resolved.json (when fromJson dot-access is awkward)** (identity.yml
lines 380-385):

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  opssh=$(jq -r '.features."one-password-ssh" // false' "{{.RESOLVED_JSON_PATH}}" 2>/dev/null || echo false)
```

For packages, the snake-case dot path `.packages.brew.bundles` etc. is safe
for fromJson dot-access; jq is needed only for kebab-case feature keys or for
typed-bucket array enumeration (jq `.[] | "\(.name) \(.verify)"` style).

**Validation-task pattern (check/cross output via messages.zsh)** (identity.yml
lines 380-418):

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  # ... compute expected vs actual
  if [[ "$actual" = "$expected" ]]; then
    check "package <name> verified"
  else
    cross "package <name> failed: ..."
    exit 1
  fi
```

Adopt verbatim for `packages:verify` per-package output. D-07 contract: ALL
packages enumerated (no first-failure exit); track failure count, exit with
non-zero count at the end.

**_:check-command / _:check-file invocation pattern** (helpers.yml lines 81-89):

```yaml
- task: _:check-command
  vars: { CMD: "brew", NAME: "Homebrew" }
```

For `packages:verify`, `_:check-command` handles each formula's verify-bin
check; `_:check-file` (helpers.yml:71-79; test -f) needs a `/Applications/<App>.app`
adaptation (test -d for `.app` bundles) -- planner may use inline `test -d`
plus messages.zsh `check`/`cross` rather than the helper.

---

### `install/compose-brewfile.zsh` (script/utility, file-I/O transform) -- new, optional

**Analog:** `install/resolver.zsh` -- exact pattern for "a `.zsh` script in
`install/` that reads `resolved.json` via jq and emits an artifact via
mktemp+mv atomic write."

**File-header pattern** (resolver.zsh lines 1-28):

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/compose-brewfile.zsh -- compose per-machine Brewfile from manifest
#
# Sourced from: taskfiles/packages.yml (packages:compose, packages:install
#               tasks). Also runnable directly via `zsh install/compose-brewfile.zsh`.
#
# Reads:        $XDG_STATE_HOME/dotfiles/resolved.json
#               $DOTFILEDIR/packages/<bundle>.rb (for each bundle in
#                                                  packages.brew.bundles)
# Writes:       $XDG_CACHE_HOME/dotfiles/Brewfile (atomic via mktemp+mv)
# Depends on:   jq (>= 1.7), zsh (>= 5)
#
# Hard-fails (exit 1) if $XDG_STATE_HOME/dotfiles/resolved.json is missing or
# empty -- caller must run `task setup -- <machine-name>` + `task manifest:resolve`.
# -----------------------------------------------------------------------------
```

**`set -euo pipefail` + DOTFILEDIR guard + messages source** (resolver.zsh lines
30-40; CF-06 + LINT-04):

```zsh
set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task packages:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi
```

**Path-vars pattern** (resolver.zsh lines 43-49, typeset -r):

```zsh
typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r RESOLVED_JSON="${STATE_DIR}/resolved.json"
typeset -r CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
typeset -r COMPOSED_OUT="${CACHE_DIR}/Brewfile"
typeset -r BUNDLES_DIR="${DOTFILEDIR}/packages"
```

**Atomic mktemp+mv write with SIGINT/TERM trap** (resolver.zsh lines 341-368):

```zsh
resolve_manifest() {
  local out_path="$3"
  local out_dir tmp
  out_dir="${out_path:h}"
  mkdir -p "$out_dir"

  tmp=$(mktemp "${out_path}.XXXXXX")
  trap 'rm -f "$tmp"' EXIT INT TERM
  {
    resolve_pipeline ... > "$tmp"
    mv "$tmp" "$out_path"
  } || {
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 1
  }
  trap - EXIT INT TERM
}
```

Adopt this signal-safe atomic-write pattern verbatim for the composed Brewfile
write -- D-08 requires atomic `mktemp+mv` to avoid readers seeing partial files.

**jq read of resolved.json pattern** (resolver.zsh lines 313, 320 + identity.yml:381):

```zsh
# Iterate bundles in declared order
local -a bundles
bundles=( $(jq -r '.packages.brew.bundles[]' "$RESOLVED_JSON") )

# Read typed-bucket extras as JSON streams
formulae_json=$(jq -c '.packages.brew.extra_packages.formulae // []' "$RESOLVED_JSON")
casks_json=$(jq -c '.packages.brew.extra_packages.casks // []' "$RESOLVED_JSON")
mas_json=$(jq -c '.packages.brew.extra_packages.mas // []' "$RESOLVED_JSON")
```

**Missing-state hard-fail pattern** (resolver.zsh lines 474-481; CF/D-16):

```zsh
if [[ ! -f "$STATE_FILE" ]]; then
  error "no machine selected"
  error "  run: task setup -- <machine-name>"
  return 1
fi
```

Adopt verbatim: if `resolved.json` missing/empty, hard-fail with actionable
message naming `task setup -- <machine>`. Do not silently emit an empty Brewfile.

**No precedent / new pattern flagged:**
- Composing Ruby DSL lines (`brew '...'`, `cask '...' # verify: ...`,
  `mas '<name>', id: <id>`) from typed-bucket JSON. resolver.zsh emits JSON
  output; the composer emits Ruby DSL output. The general jq-read-and-emit
  shape transfers; the line-format strings are new.
- Header-banner emission at the top of the composed Brewfile (CONTEXT
  Claude's Discretion). No v1 file has this; planner defines the exact
  format (date stamp + machine + bundles + extras counts).

---

### `manifests/defaults.toml` (config/schema, static-content) -- edit

**Analog:** own current `[packages.brew]` block (lines 34-39) -- self-replacement.

**Current block** (defaults.toml lines 34-40):

```toml
[packages.brew]
# Bundle names map to packages/<name>.rb in Phase 5.
bundles = ["core"]
# Additive escape hatch -- resolver computes the dedupe union of defaults
# plus the active machine's extras at resolve time.
extra_packages = []
```

**New shape per D-03** (typed-bucket sub-table):

```toml
[packages.brew]
bundles = ["core"]

[packages.brew.extra_packages]
formulae = []
casks    = []
mas      = []
```

Comment lines updated accordingly. Resolver's `extra_packages` concatenation
logic (resolver.zsh:316-320) needs an update: instead of a single
`add | unique` over a flat array, each sub-array (formulae, casks, mas)
gets its own concat+dedupe. This is a P5 change to resolver.zsh as well --
flagged in the planner's plan list.

---

### `manifests/machines/personal-laptop.toml` (config/schema, static-content) -- edit

**Analog:** own current file -- self-replacement.

**Current block** (personal-laptop.toml lines 28-30):

```toml
[packages.brew]
bundles = ["core", "gui", "dev", "personal"]
extra_packages = ["docker-desktop"]
```

**New shape** (CONTEXT `<specifics>` lines 317-359):

```toml
[packages.brew]
bundles = ["core", "gui"]

[packages.brew.extra_packages]
formulae = []  # all CLI lives in core.rb

casks = [
  { name = "discord",            verify = "Discord" },
  { name = "slack",              verify = "Slack" },
  # ... full personal cask inventory ...
  { name = "docker-desktop",     verify = "Docker" },
]

mas = [
  { id = 441258766, name = "Magnet" },
  { id = 904280696, name = "Things" },
]
```

Per D-02, bundles trim to `["core", "gui"]`; per D-04, every cask carries a
`verify` field. v1 inventory drawn from `install/Brewfile-personal.rb` (the
full set ports into `casks = [...]`).

---

### `manifests/machines/work-laptop.toml` (config/schema, static-content) -- edit

**Analog:** own current file (lines 26-27); v1 inventory from
`install/Brewfile-work.rb`.

Same shape change as personal-laptop.toml. v1 inventory in
`install/Brewfile-work.rb:14-50` maps to `casks = [...]` with explicit
verify fields; `mas` block carries Magnet + Things.

---

### `manifests/machines/server-1.toml` and `server-2.toml` (config/schema) -- edit

**Analog:** own current files (lines 19-20); shape stays minimal.

**Current block** (server-1.toml lines 19-20):

```toml
[packages.brew]
bundles = ["core"]
```

**New shape** (CONTEXT `<specifics>` lines 395-404 -- typed-empty buckets):

```toml
[packages.brew]
bundles = ["core"]

[packages.brew.extra_packages]
formulae = []
casks = []
mas = []
```

Bundles stay `["core"]` (no `gui` on servers); extras are explicit empty
buckets so the resolver's dot-access into `.packages.brew.extra_packages.casks`
returns `[]` cleanly rather than `null`.

---

### `Taskfile.yml` (root) (taskfile/root, request-response) -- edit

**Analog:** own current includes block + install task -- self-replacement
with three discrete edits.

**Current includes block** (Taskfile.yml lines 74-97):

```yaml
includes:
  manifest:
    taskfile: ./taskfiles/manifest.yml
    vars: { DOTFILEDIR: '{{.DOTFILEDIR}}', XDG_STATE_HOME: '{{.XDG_STATE_HOME}}', DOTFILES_MESSAGES: '{{.DOTFILES_MESSAGES}}' }
  # ...
  brew:     ./taskfiles/brew-stub.yml       # P5 wires real bodies
  claude:   ./taskfiles/claude-stub.yml     # P7 wires real bodies
  macos:    ./taskfiles/macos-stub.yml      # P6 wires real bodies
```

**Required edits (CONTEXT Claude's Discretion bullet on aggregator placement):**

1. Rename the `brew:` include key to `packages:` AND swap the file from
   `./taskfiles/brew-stub.yml` to `./taskfiles/packages.yml`. Since
   `packages.yml` also reads `resolved.json` via `fromJson`, mirror the
   `manifest:` / `identity:` shape and explicitly forward
   `DOTFILEDIR`/`XDG_STATE_HOME`/`DOTFILES_MESSAGES` vars:

   ```yaml
   packages:
     taskfile: ./taskfiles/packages.yml
     vars:
       DOTFILEDIR: '{{.DOTFILEDIR}}'
       XDG_STATE_HOME: '{{.XDG_STATE_HOME}}'
       XDG_CACHE_HOME: '{{.XDG_CACHE_HOME}}'
       DOTFILES_MESSAGES: '{{.DOTFILES_MESSAGES}}'
   ```

   Pattern source: identity.yml include block at lines 87-94. The
   `XDG_CACHE_HOME` forward is the new addition (D-08 cache path).

**Current install task** (Taskfile.yml lines 111-135):

```yaml
install:
  desc: "Install dotfiles for active machine (canonical entry)"
  status: [false]
  preconditions:
    - sh: ...
  deps: [manifest:resolve]
  cmds:
    - task: links:all
    - task: brew:install
    - task: claude:install
    - task: macos:defaults
    - task: macos:shell
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"
```

**Required edits:**

2. Replace `task: brew:install` with `task: packages:install`.
3. Add `task: packages:verify` AFTER `task: macos:shell` and BEFORE the
   `success "install complete"` line. Per D-10 (hard-fail at install gate)
   and ROADMAP Phase 5 success criterion #6 ("`task packages:verify` in
   its final step").

Final cmds order:

```yaml
cmds:
  - task: links:all
  - task: packages:install
  - task: claude:install
  - task: macos:defaults
  - task: macos:shell
  - task: packages:verify
  - |
    {{.DOTFILES_MESSAGES}}
    success "install complete"
```

---

### `docs/MANIFEST.md` (docs/schema, static-content) -- edit

**Analog:** own current schema tables and worked-example snippets --
self-replacement at three specific call sites.

**Edit 1: required-fields row** (MANIFEST.md:90):

Current:
```markdown
| `packages.brew.bundles` | array of strings | non-empty; must include `"core"` | Maps to `packages/<name>.rb` files (Phase 5) |
```

After P5: bundles row unchanged; add a new row OR update the optional-fields
row for the typed sub-table.

**Edit 2: optional-fields row** (MANIFEST.md:100):

Current:
```markdown
| `packages.brew.extra_packages` | array of strings | Additive escape hatch; deduplicated union with defaults value |
```

Replace with a sub-table block. Suggested shape:

```markdown
| `packages.brew.extra_packages.formulae` | array of strings or `{name, verify}` objects | Per-machine formula extras; concat+dedupe across defaults+machine |
| `packages.brew.extra_packages.casks` | array of `{name, verify}` objects | Per-machine cask extras; verify field MANDATORY per cask (D-04) |
| `packages.brew.extra_packages.mas` | array of `{id, name}` objects | Per-machine MAS app extras; `name` is also the `.app` verify name (D-06) |
```

**Edit 3: worked example block** (MANIFEST.md:70-72, 294-301):

Current `extra_packages = ["docker-desktop"]` flat-array example needs
replacing with the typed-bucket shape. The Merge Semantics section's
worked example for `extra_packages` (around line 309) needs updating to
show per-bucket concat+dedupe, not flat-array union.

---

### `.planning/REQUIREMENTS.md` (docs, edit) -- PKGS-01 and PKGS-04 text

**Analog:** own current PKGS-01 + PKGS-04 lines.

**Current PKGS-01** (REQUIREMENTS.md:95):
```markdown
- [ ] **PKGS-01**: Per-purpose Brewfile bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`) -- named by role, not by profile
```

**New PKGS-01** (per D-01 + D-02):
```markdown
- [ ] **PKGS-01**: Per-purpose Brewfile bundles in `packages/<purpose>.rb` (flat -- not `packages/brew/`). v1 ships `core` and `gui`; bundles are an as-needed grouping, not a fixed set (per-machine extras carry the bulk).
```

**Current PKGS-04** (REQUIREMENTS.md:98):
```markdown
- [ ] **PKGS-04**: Manifest can declare per-machine `extra_packages` (additive, concatenates with bundle contents)
```

**New PKGS-04** (per D-03):
```markdown
- [ ] **PKGS-04**: Manifest can declare per-machine `extra_packages` as a typed sub-table (`formulae`, `casks`, `mas`); each sub-array concat+dedupes with defaults at resolve time. Cask and MAS entries are typed objects (`{name, verify}` for casks; `{id, name}` for MAS).
```

---

### `.planning/ROADMAP.md` (docs, edit) -- Phase 5 success criterion #3

**Analog:** own current Phase 5 success criterion text (ROADMAP.md:111).

**Current text:**
```markdown
3. Bundles are named by purpose (`core.rb`, `gui.rb`, `dev.rb`, `ops.rb`, `personal.rb`) -- no `Brewfile-<profile>.rb` files anywhere; ...
```

**New text** (per D-02):
```markdown
3. Bundles are named by purpose (`core.rb`, `gui.rb`, and any future purpose-named additions) -- no `Brewfile-<profile>.rb` files anywhere; per-machine variation lives in `extra_packages` typed sub-table (formulae/casks/mas), not in bundle files; a Mac server machine can decline GUI bundles via manifest and its composed Brewfile contains no casks.
```

The "no `Brewfile-<profile>.rb`" prohibition is preserved (D-02 narrative).

---

### `.planning/PROJECT.md` (docs, edit) -- Validated/Active package lines

**Analog:** own current PROJECT.md Validated/Active sections.

PROJECT.md currently references `packages/brew/<purpose>.rb` and the 5-bundle
enumeration. Update to `packages/<purpose>.rb` (flat) and the 2-bundle
minimum (`core`, `gui`) plus the typed-bucket extras model. Exact line
locations: planner sees PROJECT.md and applies the same edit pattern as
REQUIREMENTS.md PKGS-01.

---

## Shared Patterns

### Manifest read at task-graph build time
**Source:** `taskfiles/identity.yml:67-85` + `Taskfile.yml:59-72`
**Apply to:** `taskfiles/packages.yml` (every task that reads
`{{.MANIFEST.packages.brew.*}}`)

```yaml
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
```

Plus `deps: [":manifest:resolve"]` on every `packages:*` task that consumes
`{{.MANIFEST}}` (CF-08). Cross-include task ref uses the leading colon form
(identity.yml:111).

### Status block uses `{{.X}}` template vars only (LINT-02)
**Source:** `taskfiles/identity.yml:155-162`, `Taskfile.yml:122` (preconditions
shell-var usage is OK), CLAUDE.md (LINT-02 contract)
**Apply to:** every `packages:*` task with a `status:` block.

```yaml
status:
  - test -f "{{.COMPOSED_BREWFILE}}"
  - brew bundle check --file="{{.COMPOSED_BREWFILE}}" --no-upgrade
```

`$COMPOSED_BREWFILE` (shell var) inside `status:` is the LINT-02 violation;
the v1 `macos:shell:145` bug class. Inline shell blocks under `cmds:` may
read template vars into shell vars freely (e.g.,
`identity="{{.MANIFEST.identity.git}}"` -- identity.yml:177).

### Aggregator omits `status:` with `# lint-allow: cmds-without-status` marker
**Source:** `taskfiles/identity.yml:108-114`, `taskfiles/links.yml:76-82`
**Apply to:** `packages:install` (if split into compose+install+verify),
`packages:verify`, `packages:audit`, `packages:validate`.

```yaml
# lint-allow: cmds-without-status
install:
  desc: "Install identity layer (git + ssh)"
  deps: [":manifest:resolve"]
  cmds:
    - task: git
    - task: ssh
```

LINT-03a exempts internal tasks AND tasks whose cmds are all `task:`
delegations AND tasks carrying the marker (lint.yml:175-198).

### messages.zsh sourced via `{{.DOTFILES_MESSAGES}}` for check/cross output
**Source:** `install/messages.zsh:64-70` (provides `check`/`cross`/`info`/`warn`/`error`)
+ `taskfiles/identity.yml:307-310`, `Taskfile.yml:55-56`
**Apply to:** every cmds block in `packages:verify`, `packages:audit`, and
the success/failure summary in `packages:install`.

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  if [[ "$actual" = "$expected" ]]; then
    check "package $name verified"
  else
    cross "package $name failed: $reason"
    exit 1
  fi
```

`messages.zsh` `check` emits ✓; `cross` emits ✗. Both via stderr-safe
ANSI escapes (messages.zsh:64-70). NOTE: the `check`/`cross` functions in
messages.zsh do use the ✓/✗ characters; this is a v1 carryover. The
no-emoji project rule (CLAUDE.md "No emojis in any file -- including
markdown") does not extend to these check-marks (they predate the rule and
are functional UX markers, not decorative emoji).

### Helper tasks for command/file presence
**Source:** `taskfiles/helpers.yml:81-89` (`_:check-command`), lines 71-79
(`_:check-file`)
**Apply to:** `packages:verify` formula checks (`_:check-command` per formula)
and cask checks (custom `test -d /Applications/<App>.app` inline; the
existing `_:check-file` is `test -f`, not `test -d`).

```yaml
- task: _:check-command
  vars: { CMD: "delta", NAME: "git-delta" }
```

Planner may use `_:check-command` per-formula in a generated `cmds:` list or
inline the `command -v` checks with shell loops over the bundle's parsed
`brew '...'` lines. The latter is more compact for ~30+ packages.

### `set -euo pipefail` on every executable `.zsh` (LINT-04)
**Source:** CLAUDE.md, `install/resolver.zsh:30`
**Apply to:** `install/compose-brewfile.zsh` (if planner chooses the
external-script approach over inline cmds).

```zsh
#!/bin/zsh
# ... file header ...
set -euo pipefail
```

### No bare `ln -s` outside `helpers.yml` (LINT-03b)
**Source:** CLAUDE.md, `taskfiles/helpers.yml:30-37`, lint.yml:160-169
**Apply to:** `taskfiles/packages.yml` -- N/A in practice (CF-05 confirms no
symlinks in P5). The composed Brewfile is a FILE written to cache, not a
symlink.

### kebab-case feature keys use `index`; snake_case use dot access
**Source:** CLAUDE.md, `taskfiles/identity.yml:381` (jq-side kebab read)
**Apply to:** `packages.yml`. `.packages.brew.bundles`,
`.packages.brew.extra_packages.formulae|casks|mas` are all snake/dot-safe.
No kebab-case keys consumed by packages.yml in v1.

### File-level comment block at the top of every script
**Source:** CLAUDE.md ("File-level comment block at the top of every script
explaining its purpose, callers, and side effects"), `install/resolver.zsh:1-28`,
`taskfiles/identity.yml:3-44`, `taskfiles/shell.yml:3-28`
**Apply to:** `packages/core.rb`, `packages/gui.rb`,
`taskfiles/packages.yml`, `install/compose-brewfile.zsh`.

### XDG paths via template vars (CF-07)
**Source:** `Taskfile.yml:33-38`, `taskfiles/identity.yml:91-95`
**Apply to:** `packages.yml` `COMPOSED_BREWFILE` derivation:

```yaml
COMPOSED_BREWFILE: '{{.XDG_CACHE_HOME}}/dotfiles/Brewfile'
```

XDG_CACHE_HOME is the new XDG dimension P5 introduces (P1-P4 used STATE +
CONFIG only). Root Taskfile.yml line 38 already declares it; packages.yml
must explicitly forward it via the include block (above).

---

## No Analog Found

Files / patterns with no close codebase analog (planner relies on CONTEXT
prescription directly):

| Pattern | Where | Reason |
|---------|-------|--------|
| Cask-only bundle file with mandatory `# verify:` on every line | `packages/gui.rb` | v1 Brewfile-personal.rb has cask lines but no verify-comment convention; the convention is new (D-04). |
| Composed-Brewfile header banner | `install/compose-brewfile.zsh` output | No v1 file emits a "this file is auto-generated" header. Planner defines exact format per CONTEXT specifics. |
| Typed-bucket `extra_packages` schema (`{name, verify}`, `{id, name}` objects in TOML arrays) | `manifests/*.toml` | v1 had only flat `extra_packages = ["..."]`. The typed-object-in-TOML-array shape is supported by yq (verified Phase 1) but is new in v2. |
| `brew bundle check --no-upgrade` as a status-block command | `taskfiles/packages.yml` `packages:install` status | No v1 task uses `brew bundle check` as a status guard (v1 `brew:bundle` lacks a status block entirely -- CONCERNS.md tech-debt). The pattern is invented in P5. |
| Per-package check/cross table output (enumerate all, exit non-zero at end) | `taskfiles/packages.yml` `packages:verify` | identity.yml's validate tasks emit per-check `check`/`cross` but exit on first failure; D-07 contract for verify is enumerate-all + count-failures. Build on identity.yml's per-task output style; add a failure-counter loop. |

---

## Conventions Binding on Every Phase-5 Deliverable

All P5 files must satisfy:

| Convention | Enforced By |
|-----------|-------------|
| Flat directory: `packages/<purpose>.rb` (no `packages/brew/` subdir) | CLAUDE.md "no `packages/brew/` subdirectory"; D-01 |
| No hardcoded `/opt/homebrew` -- use `{{.HOMEBREW_PREFIX}}` (task) or `$HOMEBREW_PREFIX` (shell) | CLAUDE.md; CF-10. `Taskfile.yml:47-52` resolves it. |
| `_:safe-link` only for symlinks; no bare `ln -s` outside helpers.yml | CLAUDE.md, LINT-03b. CF-05 confirms no symlinks in P5. |
| `index` form for kebab-case keys in go-template; dot for snake | CLAUDE.md, identity.yml. CF-02. No kebab keys consumed in P5. |
| `{{.X}}` template vars in `status:` blocks ONLY; never `$X` | LINT-02. CF-03. D-09's status block conforms. |
| `set -euo pipefail` on every executable `.zsh` | LINT-04. CF-06. install/compose-brewfile.zsh (if used) conforms. |
| `deps: [":manifest:resolve"]` on every task that reads `resolved.json` | CF-08. identity.yml:111 pattern. |
| File-level comment block at top of every script (purpose, callers, side effects) | CLAUDE.md. resolver.zsh:1-28 + identity.yml:3-44 patterns. |
| No AI attribution in commits or source | CLAUDE.md, ~/.config/claude/CLAUDE.md. CF-12. Hook-enforced. |
| No emojis in any file (including markdown) | CLAUDE.md ("project convention is stricter"). messages.zsh's ✓/✗ check-marks are pre-existing functional UX and out of scope for P5 churn. |
| XDG everywhere: composed Brewfile at `{{.XDG_CACHE_HOME}}/dotfiles/Brewfile` | CLAUDE.md, CF-07, D-08. |
| Errors to stderr via `error "..."` from `install/messages.zsh` | CLAUDE.md ("Errors go to stderr"). messages.zsh:46-48. |

---

## Metadata

**Analog search scope:** `/Users/josh/Git/personal/dotfiles/` --
`taskfiles/` (identity.yml, shell.yml, links.yml, helpers.yml, lint.yml,
brew.yml, brew-stub.yml, manifest.yml), `install/` (resolver.zsh,
messages.zsh, Brewfile.rb, Brewfile-personal.rb, Brewfile-work.rb,
Brewfile-server.rb), `manifests/` (defaults.toml + four machine TOMLs),
`Taskfile.yml`, `docs/MANIFEST.md`, `shell/README.md`, `packages/README.md`.

**Files scanned:** 25
**Pattern extraction date:** 2026-05-15
**Phase artifact:** `.planning/phases/05-packages-layer-brewfile-composition-verification/05-PATTERNS.md`
