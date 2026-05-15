# Phase 4: Identity Layer - Git + SSH per Machine - Pattern Map

**Mapped:** 2026-05-14
**Files analyzed:** 26 (new + modified)
**Analogs found:** 24 / 26 (2 ship without a direct v2 analog; v1 source-of-truth content is the port reference)

Phase 4 is composition glue. No new tools, no novel data flows. Every new file maps directly onto a Phase 1-3 analog already in the repo, and the two "no v2 analog" rows (the static `identity/{git,ssh}/config` scaffold files) port from v1 content with documented divergences. The dominant patterns to copy are:

1. `taskfiles/links.yml` for the `taskfiles/identity.yml` shape (vars block, `_:safe-link` invocations, `status:` blocks with `{{.X}}` only, aggregator + sub-task topology).
2. `install/resolver.zsh` `validate_manifest()` for cross-field validation (extend in-place, do not invent a new helper).
3. `taskfiles/manifest.yml manifest:test` for adding negative fixtures (mirror the `_invalid-missing-desc` / `_invalid-bad-os` cp+resolver+grep+rm pattern).
4. v1 `git/` and `ssh/` source files for identity-content ports (path updates and the dropped `Match exec` block are the only deltas).

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `taskfiles/identity.yml` | taskfile / install | event-driven (manifest -> symlinks) | `taskfiles/links.yml` | exact (same shape, same vars, same helper) |
| `install/resolver.zsh` (edit `validate_manifest()`) | validator / shell function | transform (TOML in -> stderr errors out) | `install/resolver.zsh` `validate_manifest()` lines 92-215 (extend the same function) | self-analog (same file) |
| `identity/git/config` | config / static file | n/a (static gitconfig) | v1 `git/config` (drop server includeIf, add `[include] path = server-include.config`) | v1 port |
| `identity/git/identities/personal` | config / static file | n/a (gitconfig overlay) | v1 `git/config-personal` | v1 port (verbatim) |
| `identity/git/identities/work` | config / static file | n/a (gitconfig overlay) | v1 `git/config-work` | v1 port (email TBD; verbatim otherwise) |
| `identity/git/identities/server-1` | config / static file | n/a | v1 `git/config-server` | v1 port + rebrand (name/email per-server) |
| `identity/git/identities/server-2` | config / static file | n/a | v1 `git/config-server` | v1 port + rebrand |
| `identity/git/identities/none` | config / static file | n/a | none (new file; comment-only no-op per RESEARCH Pitfall 5) | no analog (greenfield) |
| `identity/git/ignore` | config / static file | n/a | v1 `git/ignore` | v1 port (verbatim) |
| `identity/ssh/config` | config / static file | n/a (static ssh_config) | v1 `ssh/configs/config` (drop the three `Match exec` blocks; replace with single `Include ~/.ssh/identities/active`) | v1 port + structural change |
| `identity/ssh/identities/personal` | config / static file | n/a | v1 `ssh/configs/config-personal` | v1 port + path updates |
| `identity/ssh/identities/work` | config / static file | n/a | v1 `ssh/configs/config-work` | v1 port (verbatim) |
| `identity/ssh/identities/server-1` | config / static file | n/a | v1 `ssh/configs/config-server` | v1 port + IdentityFile rename |
| `identity/ssh/identities/server-2` | config / static file | n/a | v1 `ssh/configs/config-server` | v1 port + IdentityFile rename |
| `identity/ssh/identities/none` | config / static file | n/a | none (new file; comment-only no-op per RESEARCH Pitfall 5) | no analog (greenfield) |
| `identity/ssh/cloudflared.zsh` | shell script | event-driven (ProxyCommand wrapper) | v1 `ssh/cloudflared.zsh` | v1 port (verbatim) |
| `identity/ssh/keys/personal.pub` | key file / static | n/a | v1 `ssh/keys/id_ed25519_personal.pub` | v1 port + rename |
| `identity/ssh/keys/server-1.pub` | key file / static | n/a | (none; ship placeholder content per D-09) | placeholder (new) |
| `identity/ssh/keys/server-2.pub` | key file / static | n/a | (none; ship placeholder content per D-09) | placeholder (new) |
| `identity/ssh/keys/.gitignore` | gitignore allowlist | n/a | (none; new file - belt-and-braces for IDNT-06) | no analog |
| `identity/README.md` | docs | n/a | `shell/README.md` + `taskfiles/README.md` | exact (one-page sectioned README, DOCS-02 shape) |
| `manifests/defaults.toml` (edit) | config / TOML | n/a | `manifests/defaults.toml` (existing) | self-analog |
| `manifests/machines/personal-laptop.toml` (edit) | config / TOML | n/a | existing TOML | self-analog |
| `manifests/machines/work-laptop.toml` (edit) | config / TOML | n/a | existing TOML | self-analog |
| `manifests/machines/server-1.toml` (edit) | config / TOML | n/a | existing TOML | self-analog |
| `manifests/machines/server-2.toml` (edit) | config / TOML | n/a | existing TOML | self-analog |
| `manifests/test/fixtures/_invalid-identity-without-opssh/machine.toml` | test fixture / TOML | n/a | `manifests/test/fixtures/_invalid-missing-desc/machine.toml` | exact (same negative-fixture shape) |
| `manifests/test/fixtures/_invalid-identity-without-opsign/machine.toml` | test fixture / TOML | n/a | `manifests/test/fixtures/_invalid-bad-os/machine.toml` | exact |
| `manifests/test/fixtures/_invalid-bad-identity/machine.toml` | test fixture / TOML | n/a | `manifests/test/fixtures/_invalid-bad-os/machine.toml` | exact |
| `taskfiles/manifest.yml` (edit `manifest:test`) | test runner | transform | existing `manifest:test` cp+resolver+grep+rm block | self-analog (extend the same task) |
| `docs/MANIFEST.md` (edit two rows) | docs / table | n/a | existing rows at lines 91-92 + 398 | self-analog |
| `taskfiles/links.yml` (edit `all:` aggregator) | taskfile | n/a | existing `all:` task (lines 75-80) | self-analog |
| `.planning/REQUIREMENTS.md` (edit IDNT-05) | requirements doc | n/a | existing IDNT-05 row | self-analog |

## Pattern Assignments

### `taskfiles/identity.yml` (NEW; controller / event-driven)

**Analog:** `/Users/josh/Git/personal/dotfiles/taskfiles/links.yml`

**Read first:**
- `taskfiles/links.yml` (137 lines - read in full)
- `taskfiles/helpers.yml` (89 lines - read in full; defines `_:safe-link` and `_:check-link`)
- `taskfiles/manifest.yml` lines 35-97 (vars block with `MANIFEST_JSON` sh: + `MANIFEST` ref: 'fromJson .MANIFEST_JSON' - this is the exact pattern to copy for manifest consumption)

**File-header banner pattern** (`taskfiles/links.yml` lines 1-38):
```yaml
version: '3'

# =============================================================================
# taskfiles/links.yml -- Phase 3 link orchestration (real implementation)
#
# Purpose:
#   ...
# Dependencies:
#   - taskfiles/helpers.yml provides `_:safe-link` (mkdir -p + ln -sfn) and
#     `_:check-link` (verifies -L and -e on the target symlink).
#
# Status-block convention (LINT-02 enforcement):
#   Every install-style task has a `status:` block. Status blocks use
#   `{{.X}}` template vars ONLY -- never `$X` shell vars. ...
#   Aggregator tasks (e.g., the `all:` aggregator below) intentionally
#   omit the `status:` block and use the `# lint-allow: cmds-without-status`
#   marker; ...
#
# Symlink-creation convention (LINT-03b enforcement):
#   No bare `ln -s` lives here -- every symlink goes through `_:safe-link`
#   in taskfiles/helpers.yml. ...
# =============================================================================
```
Phase 4: write the equivalent banner naming purpose (manifest-driven identity), dependencies (`manifest:resolve`, `_:safe-link`, `_:check-link`, `install/messages.zsh`), and the same status-block + symlink-creation conventions.

**Includes + vars block pattern** (`taskfiles/links.yml` lines 40-63 + `taskfiles/manifest.yml` lines 35-97):

`links.yml` vars block (Phase 4 must extend this shape with manifest consumption from `manifest.yml`):
```yaml
includes:
  _: ./helpers.yml

vars:
  HOME: '{{.HOME}}'

  XDG_CONFIG_HOME:
    sh: echo "${XDG_CONFIG_HOME:-$HOME/.config}"

  ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'

  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"

  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'
```

`manifest.yml` lines 38-93 (MANIFEST consumption - copy this verbatim into `identity.yml`):
```yaml
  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"

  STATE_DIR: '{{.XDG_STATE_HOME}}/dotfiles'
  RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'

  MANIFEST_JSON:
    sh: |
      if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
        cat '{{.RESOLVED_JSON_PATH}}'
      else
        echo "warning: {{.RESOLVED_JSON_PATH}} missing or empty -- run 'task setup -- <machine>' first" >&2
        echo '{}'
      fi

  # fromJson ref: verified syntax (RESEARCH section 6.1, PATTERNS Pattern 2).
  # Downstream: {{.MANIFEST.identity.git}}
  # Kebab keys: {{index .MANIFEST.features "one-password-ssh"}}
  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'
```

**Aggregator pattern** (`taskfiles/links.yml` lines 75-80):
```yaml
  # lint-allow: cmds-without-status
  all:
    desc: "Create all symlinks (P3: shell only; later phases extend)"
    cmds:
      - task: zsh
      - task: antidote
```
The `# lint-allow: cmds-without-status` marker MUST sit immediately above the task key; LINT-03a self-exempts on this exact comment. `identity:install` is the Phase 4 aggregator with the same shape (cmds-only, no status).

**Install sub-task pattern with `_:safe-link` calls + `status:` block** (`taskfiles/links.yml` lines 86-104):
```yaml
  zsh:
    desc: "Link zsh configuration files"
    cmds:
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zprofile", TARGET: "{{.ZDOTDIR}}/.zprofile" }
      # ... three more _:safe-link calls ...
    status:
      - test -L "{{.ZDOTDIR}}/.zshenv"
      - test -L "{{.ZDOTDIR}}/.zprofile"
      # ... one test -L per symlink ...
```
Phase 4 `identity:git` and `identity:ssh` copy this exact shape: list every `_:safe-link` invocation in `cmds:`, list one matching `test -L "{{.X}}"` line per link in `status:`. Status entries use `{{.X}}` template vars only (LINT-02).

**Validate sub-task pattern** (`taskfiles/links.yml` lines 122-137):
```yaml
  # lint-allow: cmds-without-status
  validate:
    desc: "Validate all P3 symlinks"
    cmds:
      - task: _:check-link
        vars: { TARGET: "{{.ZDOTDIR}}/.zshenv", NAME: "zshenv" }
      # ... one _:check-link per symlink ...
```
Phase 4 `identity:validate` ports this shape for (a) the symlink-presence assertions. The other three assertions (git config user.email, ssh-add -L, keys-dir contents) need inline `cmds:` blocks that source `{{.DOTFILES_MESSAGES}}` and call `check`/`cross`/`info`/`warn` - see RESEARCH lines 1043-1128 for the full assertion sketch.

**Manifest read pattern** (kebab-case keys vs snake_case keys):

From `taskfiles/manifest.yml` line 90-93 (the `MANIFEST` ref + comment block):
```yaml
  # Downstream: {{.MANIFEST.identity.git}}        <- snake_case dot-access
  # Kebab keys: {{index .MANIFEST.features "one-password-ssh"}}
  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'
```
Phase 4 uses:
- `{{.MANIFEST.identity.git}}` and `{{.MANIFEST.identity.ssh}}` for identity values (snake_case keys; dot-access works).
- `{{index .MANIFEST.features "one-password-ssh"}}` and `{{index .MANIFEST.features "one-password-signing"}}` for feature flags (kebab-case keys; index form required - dot-access fails go-template parsing).

**`_:safe-link` helper** (`taskfiles/helpers.yml` lines 30-37 - reference only, do not duplicate):
```yaml
  safe-link:
    desc: "Create a symlink with automatic parent directory creation"
    internal: true
    requires:
      vars: [SOURCE, TARGET]
    cmds:
      - mkdir -p "$(dirname "{{.TARGET}}")"
      - ln -sfn "{{.SOURCE}}" "{{.TARGET}}"
```
Idempotent (`ln -sfn`), auto-creates parent dir. Phase 4 calls it via `- task: _:safe-link` with `SOURCE` / `TARGET` vars - never invokes `ln` or `mkdir` directly.

**`_:check-link` helper** (`taskfiles/helpers.yml` lines 43-59):
```yaml
  check-link:
    desc: "Validate a symlink exists and points to a valid target"
    internal: true
    requires:
      vars: [TARGET, NAME]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        if [[ -L "{{.TARGET}}" ]]; then
          if [[ -e "{{.TARGET}}" ]]; then
            check "{{.NAME}} linked"
          else
            cross "{{.NAME}} broken (target missing)"
          fi
        else
          cross "{{.NAME}} missing"
        fi
```
Phase 4 `identity:validate` calls this for every Phase 4 symlink. `{{.DOTFILES_MESSAGES}}` sourcing happens automatically inside the helper.

**`deps: [manifest:resolve]` precondition** (RESEARCH lines 884-886; CF-10 in CONTEXT.md):
```yaml
  install:
    desc: "Install identity layer (git + ssh)"
    deps: [manifest:manifest:resolve]   # ensures resolved.json is fresh
    cmds:
      - task: git
      - task: ssh
```
Note: when `taskfiles/identity.yml` is included from the root `Taskfile.yml` under alias `identity`, and `taskfiles/manifest.yml` under alias `manifest`, the cross-include reference is `manifest:manifest:resolve` (alias:taskname). Planner verifies the alias against the root Taskfile.yml includes block when wiring.

**Server-include materialization sketch** (RESEARCH lines 934-970 - generate-at-install with status-block content check):
```yaml
  server-include:
    desc: "Materialize ~/.config/git/server-include.config when identity is a server"
    internal: true
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        identity="{{.MANIFEST.identity.git}}"
        case "$identity" in
          server-1|server-2)
            mkdir -p "{{.GIT_CONFIG_DIR}}"
            printf '[includeIf "gitdir:~/"]\n    path = identities/%s\n' "$identity" \
              > "{{.SERVER_INCLUDE_CONFIG}}"
            check "server-include.config materialized for $identity"
            ;;
          *)
            if [[ -f "{{.SERVER_INCLUDE_CONFIG}}" ]]; then
              rm -f "{{.SERVER_INCLUDE_CONFIG}}"
              info "removed stale server-include.config (identity is $identity)"
            fi
            ;;
        esac
    status:
      - |
        identity="{{.MANIFEST.identity.git}}"
        case "$identity" in
          server-1|server-2)
            test -f "{{.SERVER_INCLUDE_CONFIG}}" && \
              grep -q "identities/${identity}" "{{.SERVER_INCLUDE_CONFIG}}"
            ;;
          *)
            test ! -f "{{.SERVER_INCLUDE_CONFIG}}"
            ;;
        esac
```
Both blocks reference `{{.MANIFEST.identity.git}}` (template var, resolved at task-graph build time); the shell-var `$identity` is set inside the rendered shell script. The status block uses `{{.SERVER_INCLUDE_CONFIG}}` template var, never `$SERVER_INCLUDE_CONFIG` shell var (LINT-02).

---

### `install/resolver.zsh` (EDIT `validate_manifest()`; validator / transform)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/install/resolver.zsh` lines 92-215 (the existing `validate_manifest()` function)

**Read first:** the entire `validate_manifest()` function (resolver.zsh:92-215) to understand the existing pattern: `errors` local counter, `yq` reads with `// ""` fallbacks, `error "..."` calls (sourced from `messages.zsh`), and `VALIDATE_ERRORS=$errors` final assignment plus `return 1` on errors > 0.

**Existing identity enum case-statement** (resolver.zsh lines 197-208 - this is the exact block to expand):
```zsh
  # identity.git / identity.ssh enum: personal|work|none.
  local ident_key ident_val
  for ident_key in git ssh; do
    ident_val=$(yq -r ".identity.${ident_key} // \"\"" "$machine_file" 2>/dev/null || echo "")
    if [[ -z "$ident_val" ]]; then
      continue  # already counted above as missing/empty
    fi
    case "$ident_val" in
      personal|work|none) ;;
      *) error "identity.${ident_key} must be one of personal|work|none; got: ${ident_val}"
         errors=$(( errors + 1 )) ;;
    esac
  done
```

**Phase 4 change** - expand the case branch and the error message to the five-value enum (D-05):
```zsh
    case "$ident_val" in
      personal|work|server-1|server-2|none) ;;
      *) error "identity.${ident_key} must be one of personal|work|server-1|server-2|none; got: ${ident_val}"
         errors=$(( errors + 1 )) ;;
    esac
```

**Cross-field validation pattern to add** (RESEARCH lines 1135-1163; D-16) - place AFTER the expanded enum case-statement, BEFORE the `VALIDATE_ERRORS=$errors` line at resolver.zsh:210. Use the same `yq -r "<path> // \"<fallback>\"" "$machine_file" 2>/dev/null || echo "<fallback>"` pattern as every other read in the function:
```zsh
  # D-16: cross-field rules.
  #   identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true
  #   identity.git ∈ {personal, work} ⇒ features.one-password-signing = true
  local identity_ssh identity_git opssh opsign
  identity_ssh=$(yq -r '.identity.ssh // ""' "$machine_file" 2>/dev/null || echo "")
  identity_git=$(yq -r '.identity.git // ""' "$machine_file" 2>/dev/null || echo "")
  opssh=$(yq -r '.features."one-password-ssh" // false' "$machine_file" 2>/dev/null || echo "false")
  opsign=$(yq -r '.features."one-password-signing" // false' "$machine_file" 2>/dev/null || echo "false")

  case "$identity_ssh" in
    personal|work)
      if [[ "$opssh" != "true" ]]; then
        error "identity.ssh = \"${identity_ssh}\" requires features.one-password-ssh = true"
        errors=$(( errors + 1 ))
      fi
      ;;
  esac

  case "$identity_git" in
    personal|work)
      if [[ "$opsign" != "true" ]]; then
        error "identity.git = \"${identity_git}\" requires features.one-password-signing = true"
        errors=$(( errors + 1 ))
      fi
      ;;
  esac
```

**Conventions binding on this edit (from resolver.zsh):**
- `set -euo pipefail` at top of file (line 30) - unchanged.
- All errors emit via `error "..."` (sourced from `messages.zsh`, goes to stderr).
- All `yq` reads have `2>/dev/null || echo "<fallback>"` to keep `set -u` and the `set -e` happy on missing keys.
- The function returns 0 on success, 1 on errors > 0 (caller reads `VALIDATE_ERRORS` global - WR-07 fix at resolver.zsh:91 documents this).
- `local` declarations must NOT use `local path` - zsh ties `path` to `$PATH` (see comment at resolver.zsh:108-110).

**Also expand `emit_unknown_key_warnings()` whitelist** if Phase 4 adds new schema-recognized keys. The whitelist at resolver.zsh:226-237 currently lists `features`, `identity.git`, `identity.ssh`, etc. The new `features.one-password-signing` key falls under `features` (prefix match at line 249), so no whitelist edit needed. Verify no other Phase 4 keys land outside this prefix tree.

---

### `identity/git/config` (NEW; static gitconfig - port of v1)

**Analog:** `/Users/josh/Git/personal/dotfiles/git/config` (v1 source - 56 lines)

**Read first:** the entire v1 `git/config` to extract content. Phase 4 changes are localized:

**v1 `git/config` lines 1-12 (the `[includeIf]` blocks that change):**
```ini
[user]
    name = Josh Vaughen
[includeIf "gitdir/i:~/git/personal/"]
    path = config-personal
[includeIf "gitdir/i:~/git/server/"]    ; <-- drop this block (D-08: server is per-machine via wildcard)
    path = config-server
[includeIf "gitdir/i:~/git/work/"]
    path = config-work
```

**Phase 4 replacement (RESEARCH lines 614-696):**
```ini
[user]
    name = Josh Vaughen

[includeIf "gitdir/i:~/git/personal/"]
    path = identities/personal           ; <-- v2: identities/ subdirectory + flat name

[includeIf "gitdir/i:~/git/work/"]
    path = identities/work

[include]
    path = server-include.config         ; <-- NEW: D-08 unconditional include; absent on workstations = silent no-op
```

**v1 `git/config` lines 9-57** (the `[core]`, `[init]`, `[fetch]`, `[interactive]`, `[delta]`, `[status]`, `[alias]` blocks) - port verbatim. Note tabs-vs-spaces inconsistency in v1; v2 should normalize to 4-space indentation (RESEARCH line 642+ shows the normalized output).

**File-level comment block at top** (project convention - CLAUDE.md "File-level comment block at top of every script"):
```ini
# identity/git/config -- main git config; symlinked to ~/.config/git/config.
#
# Identity selection model:
#   ...
# Schema reference: docs/MANIFEST.md identity.git enum.
```
Full sketch in RESEARCH lines 615-628.

---

### `identity/git/identities/personal` (NEW; gitconfig overlay - verbatim port)

**Analog:** `/Users/josh/Git/personal/dotfiles/git/config-personal` (11 lines - port verbatim)

**Read first:** the entire v1 `git/config-personal`:
```ini
[user]
	name = Josh Vaughen
    email = josh@vaughen.net
    signingkey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMsU4L+sNRYKBy7p294G4YVbsjT4O4ewT9OTnKbfnfdT
[github]
    user = jshvn
[gpg]
    format = ssh
[gpg "ssh"]
    program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
[commit]
    gpgsign = true
```

Port verbatim into `identity/git/identities/personal`. Add file-level header comment per project convention (RESEARCH lines 701-705 shows the v2 header).

---

### `identity/git/identities/work` (NEW; verbatim port - email TBD)

**Analog:** `/Users/josh/Git/personal/dotfiles/git/config-work` (7 lines)

v1 lacks `email`. Phase 4 ships the file with either (a) the actual work email if user provides before merge, or (b) a `# TODO: set work email` marker per CONTEXT.md Deferred-Open-Questions. The cross-field validator (D-16) will hard-fail if `identity.git = "work"` and `features.one-password-signing = true` but the file has no email - planner decides whether to soft-warn here or hard-fail.

---

### `identity/git/identities/server-1` / `server-2` (NEW; v1 port + rebrand)

**Analog:** `/Users/josh/Git/personal/dotfiles/git/config-server` (7 lines):
```ini
[user]
    name = Server
    email = server@jgrid.net
[github]
    user = jshvn
[commit]
    gpgsign = false
```

**Phase 4 changes** - `name` and `email` become per-server:
- `server-1`: `name = Server-1`, `email = server-1@jgrid.net`
- `server-2`: `name = Server-2`, `email = server-2@jgrid.net`

`[github] user = jshvn` and `[commit] gpgsign = false` port verbatim. Full sketch in RESEARCH lines 726-741.

---

### `identity/ssh/config` (NEW; structural change from v1)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/configs/config` (20 lines - 13 lines are removed)

**Read first:** the v1 file in full. Lines 11-20 (the three `Match exec "cat .../profile = 'X'"` blocks) ARE the v1 bug class being structurally closed in Phase 4 (CONCERNS.md `ssh/configs/config:13-20`).

**Phase 4 replacement** - drop everything below line 7, add a single Include:
```
# identity/ssh/config -- main SSH config; symlinked to ~/.ssh/config.
#
# Identity selection model:
#   The Include line below points at ~/.ssh/identities/active, which is a
#   symlink to one of identities/{personal,work,server-1,server-2}. ...

Host *
    SetEnv TERM=xterm-256color

Include ~/.ssh/identities/active
```
Full sketch in RESEARCH lines 745-759.

---

### `identity/ssh/identities/personal` (NEW; v1 port + path updates)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/configs/config-personal` (20 lines)

**Read first:** the full v1 `config-personal`. Two path updates required:
- `IdentityFile ~/.ssh/id_ed25519_personal.pub` -> `IdentityFile ~/.ssh/identities/keys/personal.pub` (D-13)
- `ProxyCommand ~/.ssh/cloudflared.zsh access ssh --hostname %h` -> `ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h` (D-14)

Both `Host *.jgrid.net` and `Host *.plex.me` blocks need the same edits. `Host * IdentityAgent ...1password...agent.sock` ports verbatim (the agent socket path is stable per RESEARCH Pattern 4 + Assumptions Log A1). `User josh`, `RemoteCommand`, `RequestTTY yes` port verbatim. Full sketch in RESEARCH lines 763-787.

---

### `identity/ssh/identities/work` (NEW; verbatim port)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/configs/config-work` (9 lines - port verbatim):
```
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Add work-specific host configurations below
```
Add file-level header per project convention.

---

### `identity/ssh/identities/server-1` / `server-2` (NEW; v1 port + IdentityFile rename)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/configs/config-server` (11 lines):
```
Host github.com
    IdentityFile ~/.ssh/id_ed25519_server
    IdentitiesOnly yes
    AddKeysToAgent yes
```

**Phase 4 changes** - `IdentityFile` path becomes per-server:
- `server-1`: `IdentityFile ~/.ssh/id_ed25519_server-1`
- `server-2`: `IdentityFile ~/.ssh/id_ed25519_server-2`

Note: the IdentityFile points to the PRIVATE key path on the server (`~/.ssh/id_ed25519_server-N`, no `.pub`), which is generated locally on each server at cutover time - not committed. The PUBLIC key (`identity/ssh/keys/server-N.pub`) is the file the operator pastes back into the repo after first cutover (D-09). Full sketch in RESEARCH lines 792-803.

---

### `identity/ssh/identities/none` and `identity/git/identities/none` (NEW; greenfield - no analog)

Comment-only no-op files (RESEARCH Pitfall 5 + Open Question 2). Recommended content for the SSH variant (RESEARCH lines 805-813):
```
# identity/ssh/identities/none -- no-op identity.
#
# Linked as ~/.ssh/identities/active when identity.ssh = "none".
# Ensures the Include in main config resolves to a real file (avoids any
# "Include of missing file" ambiguity across ssh versions).
```
Git variant similar. Both files contain only a header comment block; both deploy on every machine.

---

### `identity/ssh/cloudflared.zsh` (NEW; v1 verbatim port)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/cloudflared.zsh` (4 lines):
```zsh
#!/bin/zsh

# This simple script allows me to directly use cloudflared tunnels via ProxyCommand in SSH configs

exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"
```

**Phase 4 port** - extend the header to project convention (file-level comment block naming purpose / callers / side effects), add `set -euo pipefail` (LINT-04 - executable `.zsh` must have it; CONTEXT.md CF-06 confirms). Body unchanged. The `exec "$HOMEBREW_PREFIX/bin/cloudflared"` line correctly uses `$HOMEBREW_PREFIX` (no hardcoded `/opt/homebrew` per CLAUDE.md rules).

---

### `identity/ssh/keys/personal.pub` (NEW; rename of v1 key)

**Analog:** `/Users/josh/Git/personal/dotfiles/ssh/keys/id_ed25519_personal.pub` (1 line):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMsU4L+sNRYKBy7p294G4YVbsjT4O4ewT9OTnKbfnfdT josh@vaughen.net
```
Copy verbatim to `identity/ssh/keys/personal.pub`.

---

### `identity/ssh/keys/server-1.pub` / `server-2.pub` (NEW; placeholder)

No v1 analog. Placeholder content per RESEARCH Open Question 5:
```
# Replace this file with the contents of id_ed25519_server-1.pub generated at cutover.
# See docs/CUTOVER.md (Phase 8, DOCS-08).
```
`task identity:validate`'s `ssh-add -L` assertion is gated on `features.one-password-ssh = true` (which is false on servers), so the placeholder does not cause validation failure on servers.

---

### `identity/ssh/keys/.gitignore` (NEW; allowlist)

No v1 analog. RESEARCH Pitfall 10 + lines 1178-1184:
```
# identity/ssh/keys/.gitignore
# Allowlist: only .pub files (and this .gitignore) may live here.
# IDNT-06: private keys NEVER enter the repo.
*
!*.pub
!.gitignore
```

---

### `identity/README.md` (REPLACE Phase 1 stub; docs)

**Analog:** `/Users/josh/Git/personal/dotfiles/shell/README.md` (52 lines) AND `/Users/josh/Git/personal/dotfiles/taskfiles/README.md` (75 lines)

**Read first:** both files. Shape pattern:
1. One-paragraph intro (purpose + scope).
2. `## Key files` section (bulleted list of files + responsibilities).
3. `## Adding a pattern` section (how to add an alias / identity / machine).
4. `## References` section (back-links to CLAUDE.md, REQUIREMENTS.md, docs/MANIFEST.md).
5. Trailer line: `Satisfies DOCS-02 for <dir>/.` (only `taskfiles/README.md` carries this; verify whether DOCS-02 also covers identity/).

**`shell/README.md` lines 1-7** (intro pattern - mirror this):
```markdown
# shell

Zsh startup files, theme, aliases, and functions. Sourced by every login or
interactive shell on a converged v2 machine. macOS-only in v1; the flat
layout (no platform subdirectories) collapses when Linux is in scope --
see `../.planning/ROADMAP.md` for the deferred migration cost.
```

**`shell/README.md` lines 9-23** (Key files section - mirror the bullet structure for `identity/`):
```markdown
## Key files

- `.zshenv` / `.zprofile` / `.zshrc` / `.zlogin` / `.zlogout` -- startup
  files in zsh's documented order; one role per file. ...
- `theme.zsh` -- ...
- `aliases/<topic>.zsh` -- flat layout, one topic per file. ...
- `functions/<name>.zsh` -- flat layout, one function per file; ...
```

**`shell/README.md` lines 25-38** (Adding a pattern section):
```markdown
## Adding a pattern

- **An alias.** Create `aliases/<topic>.zsh`. If the alias is GUI-coupled
  or identity-coupled, gate inside the file: ...
- **A function.** Create `functions/<name>.zsh`; ...
- **A feature flag.** ...
```

**Phase 4 identity README content (per CONTEXT.md domain section):**
- Purpose: manifest-driven git + SSH identity per machine.
- Key files: `git/config`, `git/identities/<name>`, `ssh/config`, `ssh/identities/<name>`, `ssh/keys/<name>.pub`, `ssh/cloudflared.zsh`.
- Adding an identity: add new file under `identity/{git,ssh}/identities/`, expand the resolver enum + cross-field rules, add new machine TOML if needed.
- Adding a machine: `manifests/machines/<name>.toml` + `task setup -- <name>`.
- References: `../docs/MANIFEST.md`, `../CLAUDE.md`, `../.planning/REQUIREMENTS.md` (IDNT-01..08).

---

### `manifests/defaults.toml` (EDIT; add `one-password-signing = false`)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/manifests/defaults.toml` (44 lines)

**Existing `[features]` block** (lines 23-31):
```toml
[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in
# a later phase. Defaults are conservative (mostly off).
one-password-ssh = false
motd = true
claude-marketplace = true
macos-finder = false  # gates shell/aliases/finder.zsh
ghostty = false       # gates shell/aliases/ghostty.zsh
jgrid-net = false     # gates shell/aliases/jgrid.zsh
```

**Phase 4 edit** - add one line under `one-password-ssh = false` (D-15):
```toml
one-password-ssh = false
one-password-signing = false   # gates git commit signing via 1Password op-ssh-sign
```

**Existing `[identity]` block** (lines 40-44):
```toml
[identity]
# Allowed values: "personal" | "work" | "none". Drives Phase 4 git+SSH
# identity selection.
git = "none"
ssh = "none"
```

**Phase 4 edit** - update the comment to reflect the five-value enum (D-05):
```toml
# Allowed values: "personal" | "work" | "server-1" | "server-2" | "none".
```

---

### `manifests/machines/server-1.toml` (EDIT; identity values)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/manifests/machines/server-1.toml` (25 lines)

**Phase 4 edit** - update `[identity]` block (D-07):
```toml
[identity]
git = "server-1"     # was "none"
ssh = "server-1"     # was "none"
```
`features.one-password-ssh` and `features.one-password-signing` stay `false` on servers (per CONTEXT.md decisions + cross-field rule's "no implication for server identities").

---

### `manifests/machines/server-2.toml` (EDIT; identity values)

**Analog (self):** same as server-1.toml.

**Phase 4 edit** - update `[identity]` block:
```toml
[identity]
git = "server-2"     # was "none"
ssh = "server-2"     # was "none"
```

---

### `manifests/machines/personal-laptop.toml` / `work-laptop.toml` (EDIT; add `one-password-signing`)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/manifests/machines/personal-laptop.toml` lines 15-25 (existing `[features]` block):
```toml
[features]
one-password-ssh = true
macos-dock = true
# ...
```

**Phase 4 edit** - add one line in the `[features]` block of each laptop TOML (D-16 cross-field validator hard-fails without this):
```toml
one-password-ssh = true
one-password-signing = true
```

---

### `manifests/test/fixtures/_invalid-identity-without-opssh/machine.toml` (NEW; negative fixture)

**Analog:** `/Users/josh/Git/personal/dotfiles/manifests/test/fixtures/_invalid-missing-desc/machine.toml` (16 lines)

**Read first:** the analog fixture verbatim:
```toml
# negative fixture -- meta.description omitted; validator must reject

schema_version = 1

[platform]
os = "darwin"

[features]

[packages.brew]
bundles = ["core"]

[identity]
git = "none"
ssh = "none"
```

**Phase 4 new fixture** - mirror the shape; trigger the new cross-field rule:
```toml
# negative fixture -- identity.ssh = "personal" but features.one-password-ssh = false
# validator must reject with cross-field error

schema_version = 1

[meta]
description = "negative fixture: identity-ssh-without-opssh"

[platform]
os = "darwin"

[features]
one-password-ssh = false
one-password-signing = true

[packages.brew]
bundles = ["core"]

[identity]
git = "none"
ssh = "personal"
```

---

### `manifests/test/fixtures/_invalid-identity-without-opsign/machine.toml` (NEW; negative fixture)

Same shape as above but trips the `identity.git ∈ {personal, work} ⇒ one-password-signing = true` rule:
```toml
# negative fixture -- identity.git = "personal" but features.one-password-signing = false

schema_version = 1

[meta]
description = "negative fixture: identity-git-without-opsign"

[platform]
os = "darwin"

[features]
one-password-ssh = true
one-password-signing = false

[packages.brew]
bundles = ["core"]

[identity]
git = "personal"
ssh = "none"
```

---

### `manifests/test/fixtures/_invalid-bad-identity/machine.toml` (NEW; negative fixture)

**Analog:** `manifests/test/fixtures/_invalid-bad-os/machine.toml` (19 lines):
```toml
# negative fixture -- platform.os = "linux"; validator must reject in v1

schema_version = 1

[meta]
description = "bad-os negative fixture"

[platform]
os = "linux"

[features]

[packages.brew]
bundles = ["core"]

[identity]
git = "none"
ssh = "none"
```

**Phase 4 new fixture** - identity.ssh = "alice" (unknown enum value):
```toml
# negative fixture -- identity.ssh = "alice"; validator must reject (enum check)

schema_version = 1

[meta]
description = "negative fixture: bad-identity-ssh enum value"

[platform]
os = "darwin"

[features]

[packages.brew]
bundles = ["core"]

[identity]
git = "none"
ssh = "alice"
```

---

### `taskfiles/manifest.yml` (EDIT `manifest:test`; add three negative-fixture runs)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/taskfiles/manifest.yml` lines 354-393 (the `_invalid-missing-desc` and `_invalid-bad-os` blocks inside `manifest:test`)

**Read first:** the full `manifest:test` task (lines 277-412). Pay special attention to:
- The `neg_copies=()` array + `cleanup_neg()` EXIT trap pattern (lines 287-301) - CR-01 fix guarantees fixture cleanup even on yq crash or Ctrl-C.
- The order: register copy in `neg_copies` BEFORE `cp`, then run resolver `--validate-only`, then `grep` stderr for the expected fragment.
- The `negative_count=2` constant at line 404 - bumped to 5 in Phase 4 (existing 2 + new 3).

**Exact analog block to copy** (manifest.yml lines 361-375 - `_invalid-missing-desc` pattern):
```yaml
        neg_dir="${fix_dir}/_invalid-missing-desc"
        tmp_neg="{{.MACHINES_DIR}}/_invalid-missing-desc.toml"
        neg_copies+=("$tmp_neg")
        cp "$neg_dir/machine.toml" "$tmp_neg"
        neg_stderr=$(DOTFILEDIR="{{.DOTFILEDIR}}" XDG_STATE_HOME="{{.XDG_STATE_HOME}}" \
          zsh "{{.DOTFILEDIR}}/install/resolver.zsh" \
          --validate-only --machine _invalid-missing-desc 2>&1 >/dev/null || true)
        rm -f "$tmp_neg"
        if echo "$neg_stderr" | grep -q 'meta.description'; then
          check "fixture: _invalid-missing-desc -- correctly rejected (meta.description in stderr)"
        else
          cross "fixture: _invalid-missing-desc -- expected rejection with 'meta.description' in stderr"
          echo "stderr was: $neg_stderr" >&2
          failures=$(( failures + 1 ))
        fi
```

**Phase 4 new blocks (three new fixtures)** - copy the above shape verbatim, changing only:
- `neg_dir` -> `${fix_dir}/_invalid-identity-without-opssh` (and the other two)
- `tmp_neg` -> `{{.MACHINES_DIR}}/_invalid-identity-without-opssh.toml`
- `--machine _invalid-identity-without-opssh`
- `grep -q '<fragment>'` - the stderr fragment to assert. For the three new fixtures:
  - `_invalid-identity-without-opssh`: `grep -q 'one-password-ssh'` (validator error message: `identity.ssh = "personal" requires features.one-password-ssh = true`)
  - `_invalid-identity-without-opsign`: `grep -q 'one-password-signing'`
  - `_invalid-bad-identity`: `grep -q 'server-1|server-2|none'` (validator error message: `identity.ssh must be one of personal|work|server-1|server-2|none; got: alice`)

**Update the summary counter** (manifest.yml line 404):
```yaml
        negative_count=2    # <-- bump to 5
```

---

### `docs/MANIFEST.md` (EDIT; two table rows)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/docs/MANIFEST.md`

**Existing required-fields table rows** (lines 91-92):
```markdown
| `identity.git` | string | `"personal"` \| `"work"` \| `"none"` | Drives Phase 4 git config selection |
| `identity.ssh` | string | `"personal"` \| `"work"` \| `"none"` | Drives Phase 4 SSH config selection |
```

**Phase 4 edit** - expand the Allowed-values column to include the two server values (D-05):
```markdown
| `identity.git` | string | `"personal"` \| `"work"` \| `"server-1"` \| `"server-2"` \| `"none"` | Drives Phase 4 git config selection |
| `identity.ssh` | string | `"personal"` \| `"work"` \| `"server-1"` \| `"server-2"` \| `"none"` | Drives Phase 4 SSH config selection |
```

**Existing Feature-Flag Reference table** (lines 396-405) - add one new row:
```markdown
| `one-password-ssh` | Phase 4 | Enables 1Password SSH agent integration | `false` |
| `one-password-signing` | Phase 4 | Enables git commit signing via 1Password op-ssh-sign | `false` |    <-- NEW
| `motd` | Phase 3 | Enables MOTD display on `.zlogin` | `true` |
...
```

---

### `taskfiles/links.yml` (EDIT `all:` aggregator; one new task entry)

**Analog (self):** `/Users/josh/Git/personal/dotfiles/taskfiles/links.yml` lines 75-80:
```yaml
  # lint-allow: cmds-without-status
  all:
    desc: "Create all symlinks (P3: shell only; later phases extend)"
    cmds:
      - task: zsh
      - task: antidote
```

**Phase 4 edit** - add `identity:install` task (or per CONTEXT.md Claude's Discretion, the planner may instead wire to root `Taskfile.yml`):
```yaml
  # lint-allow: cmds-without-status
  all:
    desc: "Create all symlinks (P3+P4: shell + identity)"
    cmds:
      - task: zsh
      - task: antidote
      - task: identity:install         # <-- NEW (alias depends on root Taskfile.yml include name)
```
The exact `identity:install` alias depends on how `taskfiles/identity.yml` is included from the root - planner verifies. The comment at links.yml lines 7-13 ("P4 adds git/ssh/identity") already names this extension point.

---

## Shared Patterns

These patterns apply across multiple Phase 4 files and originate from CLAUDE.md, Phase 2 lint rules, and Phase 1-3 conventions.

### Pattern S1: `_:safe-link` is the only symlink mechanism

**Source:** `/Users/josh/Git/personal/dotfiles/taskfiles/helpers.yml` lines 30-37
**Apply to:** every symlink in `taskfiles/identity.yml`
**Rule (LINT-03b):** No bare `ln -s` anywhere outside `taskfiles/helpers.yml`. Bypass = lint failure.

```yaml
  safe-link:
    desc: "Create a symlink with automatic parent directory creation"
    internal: true
    requires:
      vars: [SOURCE, TARGET]
    cmds:
      - mkdir -p "$(dirname "{{.TARGET}}")"
      - ln -sfn "{{.SOURCE}}" "{{.TARGET}}"
```

Caller pattern:
```yaml
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/identity/git/config", TARGET: "{{.GIT_CONFIG_DIR}}/config" }
```

### Pattern S2: `status:` blocks use `{{.X}}` template vars only - never `$X`

**Source:** `taskfiles/links.yml` lines 99-104, `taskfiles/manifest.yml` lines 164-168 (the resolve task's status block); CLAUDE.md "Rules" section; LINT-02
**Apply to:** every `status:` block in `taskfiles/identity.yml`
**Rule:** Shell vars are not in scope during status-block evaluation; `$X` in status: causes the task to re-run on every invocation (the v1 macos:shell:145 bug class).

Wrong (causes re-run every time):
```yaml
status:
  - test -f "$RESOLVED_JSON_PATH"
```
Correct (template var resolved at task-graph build time):
```yaml
status:
  - test -f "{{.RESOLVED_JSON_PATH}}"
```

Inside a status: block, `$(...)` command substitution IS allowed (it runs in the rendered shell after go-template substitution completes). The forbidden pattern is specifically `$VAR` where `VAR` is meant to be a go-task template variable.

### Pattern S3: Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker

**Source:** `taskfiles/links.yml` line 75 (the `all:` aggregator), CLAUDE.md "Conventions", LINT-03a
**Apply to:** `identity:install` (aggregator), `identity:validate` (diagnostic; always-re-run by design)
**Rule:** The comment marker MUST sit IMMEDIATELY ABOVE the task key. LINT-03a parses it via line lookup; mis-positioning fails the lint.

```yaml
  # lint-allow: cmds-without-status
  install:
    desc: "Install identity layer (git + ssh)"
    deps: [manifest:manifest:resolve]
    cmds:
      - task: git
      - task: ssh
```

Putting a `status:` on an aggregator that only checks a subset of sub-task symlinks short-circuits on partial state - the exact regression class CR-02 closes (links.yml banner lines 24-29 documents this).

### Pattern S4: Kebab-case feature keys use `index`; snake_case uses dot-access

**Source:** `taskfiles/manifest.yml` lines 90-93 (vars block comment); CLAUDE.md "Rules"
**Apply to:** every read of `features.*` and `identity.*` inside `taskfiles/identity.yml`
**Rule:** Go-template dot-access fails parse on `-`; the `index` form is mandatory for kebab-case.

```yaml
# Snake_case: dot-access works
{{.MANIFEST.identity.git}}
{{.MANIFEST.identity.ssh}}

# Kebab-case: index form required
{{index .MANIFEST.features "one-password-ssh"}}
{{index .MANIFEST.features "one-password-signing"}}
```

### Pattern S5: `set -euo pipefail` on every executable `.zsh`

**Source:** `install/resolver.zsh` line 30; CLAUDE.md "Rules"; LINT-04
**Apply to:** `identity/ssh/cloudflared.zsh` (the only Phase 4 executable .zsh)
**Rule:** No `set -e` alone. `-u` catches unbound-variable bugs; `-o pipefail` catches pipeline-middle failures.

v1 `ssh/cloudflared.zsh` is 4 lines and currently lacks `set -euo pipefail`. Phase 4 port adds it:
```zsh
#!/bin/zsh
# identity/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels.
# ...
set -euo pipefail

exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"
```

### Pattern S6: File-level comment block at the top of every script

**Source:** CLAUDE.md "Conventions"; every existing `.zsh`, `.yml`, `.md` in the repo follows this
**Apply to:** `taskfiles/identity.yml`, `identity/ssh/cloudflared.zsh`, `identity/git/config`, `identity/ssh/config`, every identity-overlay file
**Rule:** Header comment block names purpose, callers, and side effects. The first line is `# <path> -- <one-line summary>.`. See `taskfiles/links.yml` lines 1-38 for the most thorough example.

### Pattern S7: Error output goes to stderr via `error` (sourced from messages.zsh)

**Source:** `install/messages.zsh` (Phase 1); `install/resolver.zsh` uses `error`/`warn` throughout
**Apply to:** every cmds: block in `taskfiles/identity.yml` and the new validation in `resolver.zsh`
**Rule:** Use `check`/`cross`/`error`/`warn`/`info`/`success` from `messages.zsh`, sourced via `{{.DOTFILES_MESSAGES}}` in taskfiles or directly in shell scripts.

Caller pattern (from `taskfiles/manifest.yml` line 230):
```yaml
      - |
        {{.DOTFILES_MESSAGES}}
        if [[ ! -f "{{.DEFAULTS_TOML}}" ]]; then
          cross "manifests/defaults.toml not found"
          exit 1
        fi
        check "manifests/defaults.toml exists"
```

### Pattern S8: `deps: [manifest:manifest:resolve]` for tasks that consume resolved.json

**Source:** CF-10 in CONTEXT.md (Phase 1 D-14); the convention is named but no existing taskfile yet uses it (Phase 3 `links.yml` doesn't read resolved.json directly)
**Apply to:** `identity:install` (and any other identity sub-task that reads `{{.MANIFEST.X}}`)
**Rule:** Declaring `deps: [manifest:manifest:resolve]` ensures `resolved.json` is rebuilt before the consumer task runs. Without it, edits to TOMLs followed by `task identity:install` would read stale JSON.

The double-prefix `manifest:manifest:resolve` reflects the root Taskfile.yml include alias `manifest:` plus the task name `manifest:resolve`. Planner verifies the alias against the root Taskfile.yml includes block (taskfiles/README.md lines 49-54 describes the convention).

## No Analog Found

Files with no close match in the codebase. Planner uses RESEARCH.md patterns instead.

| File | Role | Reason |
|------|------|--------|
| `identity/git/identities/none` | gitconfig overlay | New no-op file class introduced in Phase 4 (RESEARCH Pitfall 5 / Open Question 2). Comment-only content. |
| `identity/ssh/identities/none` | ssh_config overlay | Same as above; symmetric no-op. |
| `identity/ssh/keys/server-1.pub` / `server-2.pub` | placeholder pub-key | No analog; ship with header-comment placeholder per RESEARCH Open Question 5. User fills at first server cutover per DOCS-08 (Phase 8). |
| `identity/ssh/keys/.gitignore` | gitignore allowlist | Belt-and-braces for IDNT-06 (RESEARCH Pitfall 10). No existing `.gitignore` file in the repo uses the allowlist pattern. |

## Metadata

**Analog search scope:**
- `/Users/josh/Git/personal/dotfiles/taskfiles/` (links.yml, helpers.yml, manifest.yml, shell.yml, README.md)
- `/Users/josh/Git/personal/dotfiles/install/` (resolver.zsh)
- `/Users/josh/Git/personal/dotfiles/manifests/` (defaults.toml, machines/*.toml, test/fixtures/_invalid-*)
- `/Users/josh/Git/personal/dotfiles/git/` (v1 source: config, config-personal, config-work, config-server)
- `/Users/josh/Git/personal/dotfiles/ssh/` (v1 source: configs/config, configs/config-personal, configs/config-work, configs/config-server, cloudflared.zsh, keys/id_ed25519_personal.pub)
- `/Users/josh/Git/personal/dotfiles/identity/README.md` (Phase 1 stub - replaced)
- `/Users/josh/Git/personal/dotfiles/shell/README.md` (DOCS-02 reference shape)
- `/Users/josh/Git/personal/dotfiles/docs/MANIFEST.md` (schema reference)

**Files scanned:** 24 unique files plus 7 test-fixture directories.

**Pattern extraction date:** 2026-05-14
