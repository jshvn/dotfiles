# Coding Conventions

**Analysis Date:** 2026-05-13

## Shell Scripting

**Shebang and Safety Header:**
All executable zsh scripts must start with:
```zsh
#!/bin/zsh
set -euo pipefail
```
Hook scripts under `claude/hooks/` all follow this pattern. Non-executable sourced files (like `install/messages.zsh`, `claude/hooks/lib.zsh`) omit the shebang but are still written with the same safety mindset.

**GNU grep via ggrep:**
Never use the system `grep` for regex pattern matching. Always use `ggrep` (GNU grep from Homebrew) resolved via `hook::require_ggrep` in `claude/hooks/lib.zsh`. This ensures PCRE support (`-P`) and consistent extended-regex (`-E`) behavior across macOS.

```zsh
# Correct: resolve ggrep before use
hook::require_ggrep block  # or warn for advisory hooks
"$GGREP" -qEi -- "$pattern" <<< "$text"

# Wrong: relying on system grep
grep -E "$pattern" <<< "$text"
```

## XDG Base Directories

All paths follow the XDG Base Directory Specification. Hardcoded `~/.config` or `~/.local` paths are never used.

| Variable | Default | Purpose |
|----------|---------|---------|
| `$XDG_CONFIG_HOME` | `~/.config` | App configuration |
| `$XDG_DATA_HOME` | `~/.local/share` | App data |
| `$XDG_STATE_HOME` | `~/.local/state` | App state |
| `$XDG_CACHE_HOME` | `~/.cache` | Caches |

Set in `zsh/.zshenv` with `${VAR:-default}` guard syntax:
```zsh
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
```

## Path Resolution — Never Hardcode

**In zsh scripts**, resolve the script's own location using symlink traversal:
```zsh
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"
```
See: `zsh/.zshrc` (lines 75–83).

**In hook scripts**, use `${0:A:h}` (zsh-specific absolute path of parent dir):
```zsh
source "${0:A:h}/lib.zsh"
```
See: `claude/hooks/secret-scan.zsh`, `claude/hooks/no-emojis.zsh`.

**In Taskfile**, DOTFILEDIR is resolved via:
```yaml
DOTFILEDIR:
  sh: cd "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")" 2>/dev/null && pwd || pwd
```
See: `Taskfile.yml` (line 18).

## Homebrew Prefix Detection

Never hardcode `/opt/homebrew` or `/usr/local`. Detect by architecture:
```zsh
if command -v brew &>/dev/null; then
    brew --prefix
elif [[ "$(uname)" == "Darwin" ]]; then
    [[ "$(uname -m)" == "arm64" ]] && echo "/opt/homebrew" || echo "/usr/local"
else
    echo "/home/linuxbrew/.linuxbrew"
fi
```
See: `Taskfile.yml` (lines 32–39). The resolved prefix is stored in `$HOMEBREW_PREFIX` and available to all taskfiles.

**In aliases**, use `$(command -v cmd)` to resolve Homebrew tool paths at source time:
```zsh
alias ls="$(command -v eza) --time-style long-iso"
alias traceroute="$(command -v trip) -u"
```
See: `zsh/aliases/common/general.zsh`, `zsh/aliases/common/networking.zsh`.

## Naming Conventions

**Files:**
- All filenames use `kebab-case` or `lowercase` — no spaces, no uppercase, no underscores in zsh files
- Zsh scripts: `.zsh` extension
- Taskfiles: `<topic>.yml` in `taskfiles/`
- Config files: match the tool's expected name (e.g., `trippy.toml`, `glow.yml`)
- Profile-specific variants: suffix with `-<profile>` (e.g., `config-personal`, `Brewfile-work.rb`)

**Functions:**
- One function per file; filename matches function name (e.g., `mkcd.zsh` defines `mkcd()`)
- Function names use `lowercase` with no separator (single word preferred) or camelCase for internal helpers
- Hook library uses `hook::` namespace prefix (e.g., `hook::read_stdin`, `hook::require_ggrep`)

**Variables in scripts:**
- Local variables: `local varname` with `lowercase_snake_case`
- Exported environment variables: `UPPER_SNAKE_CASE`
- Task-level vars in YAML: `UPPER_SNAKE_CASE`

**Taskfile tasks:**
- Task names use `kebab-case`
- Internal tasks are marked `internal: true` and typically prefixed with context (e.g., `ensure-homebrew`, `defaults-general`)
- Helper tasks use `_:` namespace (from `helpers.yml`)

## Zsh Functions

Rules:
1. One function per file
2. `.zsh` extension
3. No output on `source` — functions execute only when called
4. Idempotent where possible
5. File placed in `zsh/functions/<name>.zsh` (common) or `zsh/functions/<profile>/<name>.zsh` (profile-specific)
6. Include a comment with usage example on the same line as the function definition

```zsh
#!/bin/zsh
# Brief description of what this function does
function mkcd() {    # mkcd() will create a directory and cd into it. ex: $ mkcd new-project
    mkdir -p "$1" && cd "$1"
}
```

## Alias Conventions

- Placed in `zsh/aliases/common/<topic>.zsh` or `zsh/aliases/<profile>/<topic>.zsh`
- Use `$(command -v cmd)` to resolve Homebrew tool paths, not hardcoded paths
- Group by topic in separate files (e.g., `general.zsh`, `networking.zsh`, `hardware.zsh`)

## Messaging Library

All task output uses `install/messages.zsh`. Source it via the global `$DOTFILES_MESSAGES` variable at the top of any task block that needs colored output:

```yaml
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    info "Starting operation..."
    success "Done"
    warn "This might cause issues"
    error "Something went wrong"  # writes to stderr
    check "Item verified"         # ✓ prefix
    cross "Item missing"          # ✗ prefix
```

The library guards against double-sourcing via `$DOTFILES_MESSAGES_LOADED`. Do not use raw `echo` for user-facing task output.

## Taskfile Idempotency

Every installation task must have a `status:` block that makes re-runs a no-op:

```yaml
task-name:
  cmds:
    - ln -sfn "{{.SOURCE}}" "{{.TARGET}}"
  status:
    - test -L "{{.TARGET}}"
```

See: `taskfiles/links.yml` (every install task), `taskfiles/macos.yml` (every `defaults-*` task).

## Symlink Creation

Use the `_:safe-link` helper, never bare `ln` in top-level tasks:
```yaml
- task: _:safe-link
  vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zshrc", TARGET: "{{.ZDOTDIR}}/.zshrc" }
```

`_:safe-link` runs `mkdir -p` on the parent before calling `ln -sfn`. See `taskfiles/helpers.yml` (line 30–37).

## Profile-Conditional Logic

Profile-specific behavior is gated on `{{.PROFILE}}` (task context) or `$DOTFILES_PROFILE` (shell context):

```zsh
# In tasks
if [[ "{{.PROFILE}}" != "server" ]]; then
    # personal/work-only logic
fi

# In shell files
if [[ -d "$DOTFILEDIR/zsh/aliases/$DOTFILES_PROFILE" ]]; then
    for file in "$DOTFILEDIR/zsh/aliases/$DOTFILES_PROFILE/"*.zsh(.N); do
        source "$file"
    done
fi
```

Profile directories follow the pattern `<dir>/<profile>/` for profile-specific files and `<dir>/common/` for shared files.

## Hook Script Conventions

All Claude Code hooks in `claude/hooks/` follow this pattern:

1. `#!/bin/zsh` shebang
2. `set -euo pipefail`
3. `source "${0:A:h}/lib.zsh"` for shared helpers
4. `hook::require_ggrep block` (security hooks) or `hook::require_ggrep warn` (advisory hooks)
5. `hook::read_stdin` to capture Claude's JSON input
6. Extract fields with `hook::extract '<jq expression>'`
7. Use `hook::match_patterns` for pattern-based blocking/warning
8. Exit `0` for pass/warn, exit `2` to block the tool call

**Security hooks (blocking):** exit 2 on match. Example: `block-destructive.zsh`, `secret-scan.zsh`.
**Advisory hooks (non-blocking):** exit 0 always, print warning to stderr. Example: `no-emojis.zsh`, `no-ai-comments.zsh`.

## Error Handling

- `set -euo pipefail` on all executable scripts — fail fast on unset variables and pipeline errors
- Explicit guards before conditional operations: `command -v brew &>/dev/null` before using brew
- Errors written to stderr: `echo "..." >&2` or `error "..."` from messages library
- Task preconditions use `preconditions:` block for fail-fast input validation
- Optional operations use `|| true` to explicitly allow failure

## Comments

- File-level comment block at top of each script explaining purpose
- Single-line `#` comments for inline explanation of non-obvious logic
- Section separators in YAML files use `# ===` or `# ---` style banners
- No AI attribution comments (enforced by `no-ai-comments.zsh` hook)
- No emojis in non-markdown files (enforced by `no-emojis.zsh` hook)

## Git Conventions

- Commit format: `<type>(<scope>): <summary>` under 75 characters, imperative mood
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`
- Branch naming: `josh/<topic-slug>` or `josh/<TICKET-ID>/<topic-slug>`
- PRs: target `main`/`master`, squash merge
- Personal ignores: `.git/info/exclude` (not `.gitignore`)
- No `Co-Authored-By` trailers, no "generated by" comments anywhere

---

*Convention analysis: 2026-05-13*
