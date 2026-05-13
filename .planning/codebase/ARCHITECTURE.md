<!-- refreshed: 2026-05-13 -->
# Architecture

**Analysis Date:** 2026-05-13

## System Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                        Entry Points                              │
│   `bootstrap.zsh`           `Taskfile.yml`       `/etc/zshenv`  │
│   (fresh install)          (re-install/update)   (sets ZDOTDIR) │
└────────┬───────────────────────────┬────────────────────────────┘
         │                           │
         ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Task Orchestration Layer                      │
│              `taskfiles/` (modular taskfiles)                    │
│  common.yml  profile.yml  links.yml  brew.yml  macos.yml         │
│  claude.yml  profile-tasks.yml                                   │
└────────┬───────────────────────────────────────────────────────┘
         │  delegates to
         ▼
┌────────────────────┬────────────────────┬────────────────────────┐
│  Helpers Layer     │  Messages Layer     │  Profile Layer         │
│ `taskfiles/        │ `install/           │ `${XDG_CONFIG_HOME}/  │
│  helpers.yml`      │  messages.zsh`      │  dotfiles/profile`    │
│ _:safe-link        │ info/success/warn/  │ personal|work|server  │
│ _:check-*          │ error/check/cross   │                        │
└────────────────────┴────────────────────┴────────────────────────┘
         │  deploys
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Asset Layer (Source of Truth)               │
│  zsh/   git/   ssh/   install/   claude/                        │
│  (config files, aliases, functions, Brewfiles)                   │
└────────────────────────────────────────────────────────────────┘
         │  symlinks → ~/.config/... , ~/.ssh/... , etc.
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Deployed Symlink Targets                    │
│  $ZDOTDIR  $XDG_CONFIG_HOME  $HOME/.ssh  $HOME/.config/claude   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| bootstrap.zsh | One-shot entry point; installs go-task then delegates | `bootstrap.zsh` |
| Taskfile.yml | Root orchestrator; defines global vars, includes taskfiles | `Taskfile.yml` |
| common.yml | XDG dir creation, ZDOTDIR config in /etc/zshenv, antigen update | `taskfiles/common.yml` |
| profile.yml | Profile detection, validation, and selection prompt | `taskfiles/profile.yml` |
| profile-tasks.yml | Parameterized per-profile install/links/brew/validate | `taskfiles/profile-tasks.yml` |
| links.yml | All symlink creation and removal (zsh, git, ssh, tools, claude) | `taskfiles/links.yml` |
| brew.yml | Homebrew install, update, and common Brewfile bundle | `taskfiles/brew.yml` |
| macos.yml | macOS system defaults and shell registration | `taskfiles/macos.yml` |
| claude.yml | Claude Code CLI, marketplace, and plugin management | `taskfiles/claude.yml` |
| helpers.yml | Reusable `_:safe-link` and `_:check-*` internal tasks | `taskfiles/helpers.yml` |
| messages.zsh | Shared colored output library (info/success/warn/error/check/cross) | `install/messages.zsh` |
| .zshenv | XDG vars, ZDOTDIR, DOTFILES_PROFILE export; sourced by all shells | `zsh/.zshenv` |
| .zprofile | Homebrew shellenv, SSH_AUTH_SOCK (login shells only) | `zsh/.zprofile` |
| .zshrc | Plugin manager (antigen/oh-my-zsh), aliases, functions, theme (interactive only) | `zsh/.zshrc` |
| .zlogin | MOTD display on login | `zsh/.zlogin` |
| .zlogout | History flush on login-shell exit | `zsh/.zlogout` |
| git/config | Global git config with `includeIf` for profile-specific configs | `git/config` |
| ssh/configs/config | SSH config with `Match exec` for profile-conditional includes | `ssh/configs/config` |

## Pattern Overview

**Overall:** Profile-aware, symlink-based dotfiles with modular task orchestration

**Key Characteristics:**
- All config files live in the repo (source of truth); installed locations are symlinks
- Profile (`personal`/`work`/`server`) stored as a single file at `${XDG_CONFIG_HOME}/dotfiles/profile`, read at install time (tasks) and shell startup (`.zshenv`)
- Task orchestration via go-task with a root `Taskfile.yml` and modular `taskfiles/*.yml` includes
- Helpers are internal tasks in `taskfiles/helpers.yml` consumed by other taskfiles via `_` namespace
- Messages library (`install/messages.zsh`) sourced inline inside task `cmds:` blocks using the `DOTFILES_MESSAGES` global var
- All tasks have `status:` checks for idempotency — re-running install is safe

## Layers

**Entry Layer:**
- Purpose: Human-facing entry points for initial install and routine operations
- Location: `bootstrap.zsh`, `Taskfile.yml` (root tasks: `install`, `update`, `validate`, `clean`)
- Depends on: Task orchestration layer

**Task Orchestration Layer:**
- Purpose: Drives installation, linking, validation in a defined sequence
- Location: `taskfiles/`
- Contains: `common.yml`, `profile.yml`, `profile-tasks.yml`, `links.yml`, `brew.yml`, `macos.yml`, `claude.yml`
- Depends on: Helpers layer, Messages layer, Profile layer, Asset layer
- Used by: Entry layer

**Helpers Layer:**
- Purpose: Reusable internal tasks avoiding duplication across taskfiles
- Location: `taskfiles/helpers.yml`
- Contains: `_:safe-link` (symlink with mkdir -p), `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`
- Depends on: Messages layer (via `DOTFILES_MESSAGES` var)
- Used by: `links.yml`, `common.yml`, `brew.yml`, `profile-tasks.yml`, `claude.yml`

**Messages Layer:**
- Purpose: Consistent colored terminal output for all shell contexts
- Location: `install/messages.zsh`
- Contains: `info`, `success`, `warn`, `error`, `debug`, `header`, `step`, `check`, `cross`
- Depended on by: All taskfiles (via inline `source '${DOTFILEDIR}/install/messages.zsh'`)
- Guard: `$DOTFILES_MESSAGES_LOADED` prevents double-sourcing

**Profile Layer:**
- Purpose: Runtime profile selection controlling which profile-specific assets are loaded
- Location: `${XDG_CONFIG_HOME}/dotfiles/profile` (deployed machine, not repo)
- Read by: `Taskfile.yml` vars block (task execution), `zsh/.zshenv` (shell startup), `ssh/configs/config` (SSH `Match exec`), `git/config` (`includeIf gitdir`)

**Asset Layer:**
- Purpose: Source-controlled config files, scripts, and manifests
- Location: `zsh/`, `git/`, `ssh/`, `install/`, `claude/`
- Contains: Zsh startup chain, aliases, functions, theme, git configs, SSH configs, Brewfiles, Claude Code config
- Deployed by: `taskfiles/links.yml` and `taskfiles/profile-tasks.yml`

## Data Flow

### Fresh Install

1. User runs `./bootstrap.zsh` — resolves `DOTFILEDIR` via symlink traversal (`bootstrap.zsh:5-11`)
2. Sources `install/messages.zsh` for output functions (`bootstrap.zsh:15`)
3. Installs go-task if missing (`bootstrap.zsh:20-38`)
4. Delegates to `task install` (`bootstrap.zsh:42`)
5. `install` task in `Taskfile.yml`: creates XDG dirs → ensures profile → configures ZDOTDIR → creates symlinks → installs Homebrew packages → installs Claude plugins → applies macOS defaults → runs profile-specific install

### Profile-Conditional Zsh Loading

1. `/etc/zshenv` sets `ZDOTDIR=$HOME/.config/zsh` (configured by `common:zdotdir`)
2. `zsh/.zshenv` runs, exports `DOTFILES_PROFILE` from `${XDG_CONFIG_HOME}/dotfiles/profile`
3. `zsh/.zshrc` globs `zsh/aliases/common/*.zsh` and `zsh/aliases/$DOTFILES_PROFILE/*.zsh`
4. `zsh/.zshrc` globs `zsh/functions/*.zsh` and `zsh/functions/$DOTFILES_PROFILE/*.zsh`

### SSH Profile Routing

1. `~/.ssh/config` → symlink → `ssh/configs/config`
2. SSH evaluates `Match exec` lines, reading profile file at connect time
3. Matching profile's `Include ~/.ssh/config-<profile>` is activated
4. Profile config files: `ssh/configs/config-personal`, `config-work`, `config-server`

### Git Profile Routing

1. `~/.config/git/config` → symlink → `git/config`
2. `includeIf "gitdir/i:~/git/personal/"` selects `config-personal` for repos under that path
3. Profile-specific configs (`git/config-personal`, `git/config-work`, `git/config-server`) set email/signing

**State Management:**
- Profile state: single file `${XDG_CONFIG_HOME}/dotfiles/profile`
- Task idempotency: `status:` blocks on every install task (skip if already done)
- Shell state: all exports live in `zsh/.zshenv`; interactive state in `zsh/.zshrc`

## Key Abstractions

**`_:safe-link` helper:**
- Purpose: Create a symlink and ensure parent directory exists
- Examples: Used in `links.yml` for every symlink target, `profile-tasks.yml` for per-profile links
- Pattern: `task: _:safe-link` with `vars: { SOURCE: "...", TARGET: "..." }`

**`_:check-*` helpers:**
- Purpose: Validation reporting — each prints a green check or red cross
- Examples: `links:validate`, `common:validate`, `profile-tasks:validate`
- Pattern: `task: _:check-link` with `vars: { TARGET: "...", NAME: "label" }`

**`DOTFILES_MESSAGES` var:**
- Purpose: Inline sourcing of `install/messages.zsh` without requiring it be pre-sourced
- Pattern: Every task `cmd:` block that needs colored output starts with `{{.DOTFILES_MESSAGES}}`
- Location: Defined in `Taskfile.yml:48-49`

**`profile-tasks.yml` parameterization:**
- Purpose: Single taskfile that serves all three profiles via `TARGET_PROFILE` variable
- Pattern: Included three times in `Taskfile.yml` under `personal:`, `work:`, `server:` namespaces with different `TARGET_PROFILE` values

## Entry Points

**`bootstrap.zsh`:**
- Location: `bootstrap.zsh`
- Triggers: Manual execution on a new machine (`./bootstrap.zsh`)
- Responsibilities: DOTFILEDIR resolution, go-task bootstrap, delegates to `task install`

**`Taskfile.yml` (install task):**
- Location: `Taskfile.yml:92-116`
- Triggers: `task install` or after `./bootstrap.zsh`
- Responsibilities: Full installation sequence across all components in dependency order

**`zsh/.zshenv`:**
- Location: `zsh/.zshenv` (deployed to `$ZDOTDIR/.zshenv`)
- Triggers: Every zsh invocation (interactive, non-interactive, scripts, login)
- Responsibilities: XDG vars, ZDOTDIR, CLAUDE_CONFIG_DIR, DOTFILES_PROFILE export

## Architectural Constraints

- **Shell compatibility:** All hooks and task shell scripts use `zsh` (`set -euo pipefail` or `set -e`). GNU grep (`ggrep`) required by hooks — assumes Homebrew on macOS.
- **Global state:** `DOTFILES_MESSAGES_LOADED` in `install/messages.zsh` guards double-sourcing. `DOTFILEDIR` and `DOTFILES_PROFILE` exported at shell startup via `.zshenv`.
- **Homebrew dependency:** Task commands that need Homebrew prepend `{{.BREW_SHELLENV}}` to ensure brew is on PATH in each shell context (go-task spawns fresh subshells).
- **Idempotency contract:** Every install task has a `status:` block. Running `task install` twice is safe and fast (no-ops on already-done steps).
- **No hardcoded paths:** Homebrew prefix detected by architecture. DOTFILEDIR resolved via symlink traversal in both `bootstrap.zsh` and `zsh/.zshrc`.
- **Profile file not in repo:** `${XDG_CONFIG_HOME}/dotfiles/profile` is a machine-local file, not committed.

## Anti-Patterns

### Sourcing messages.zsh outside task cmds

**What happens:** Some developers might try to `source install/messages.zsh` at the top of a taskfile rather than using the `{{.DOTFILES_MESSAGES}}` inline pattern.
**Why it's wrong:** go-task spawns a fresh subshell for each `cmd:` entry; state from a prior cmd is lost. The inline sourcing pattern ensures messages are available in every cmd block.
**Do this instead:** Start each cmd block that needs output with `{{.DOTFILES_MESSAGES}}` — see `taskfiles/helpers.yml` and `taskfiles/links.yml` for examples.

### Hardcoding /opt/homebrew or /usr/local

**What happens:** Writing a hardcoded Homebrew prefix instead of using `{{.HOMEBREW_PREFIX}}` or `{{.BREW_SHELLENV}}`.
**Why it's wrong:** x86 Macs use `/usr/local`; Apple Silicon uses `/opt/homebrew`; Linux uses `/home/linuxbrew/.linuxbrew`. Hardcoding breaks on other architectures.
**Do this instead:** Use `{{.HOMEBREW_PREFIX}}` for path construction and `{{.BREW_SHELLENV}}` before any `brew` commands — both defined in `Taskfile.yml:29-45`.

### Profile-specific logic in common files

**What happens:** Adding `if [[ $DOTFILES_PROFILE == personal ]]` branches inside `zsh/.zshrc` or `git/config`.
**Why it's wrong:** Profile-conditional logic is expressed via directory conventions (`zsh/aliases/<profile>/`) and file naming (`git/config-<profile>`, `ssh/configs/config-<profile>`), not inline branching.
**Do this instead:** Add profile aliases to `zsh/aliases/<profile>/`, profile functions to `zsh/functions/<profile>/`, and profile git/ssh config to their respective `*-<profile>` files.

## Error Handling

**Strategy:** Fail-fast with explicit messaging.

**Patterns:**
- `set -euo pipefail` in `bootstrap.zsh`; `set: [errexit, pipefail]` in `Taskfile.yml`
- Validation tasks (`task validate`) report pass/fail per item using `check`/`cross` symbols rather than aborting — allows partial installs to be diagnosed
- `install/messages.zsh::error()` writes to stderr; normal output to stdout

## Cross-Cutting Concerns

**Logging:** `install/messages.zsh` functions used across all task cmds. `DOTFILES_DEBUG=true` enables `debug()` output.
**Validation:** Each taskfile owns its own `validate` task; root `task validate` chains them all. Status checks via `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`.
**Profile detection:** Read from filesystem at task eval time (Taskfile.yml vars block `sh:` subshell) and at zsh startup (`.zshenv` cat). SSH and git use their own runtime mechanisms (Match exec / includeIf).

---

*Architecture analysis: 2026-05-13*
