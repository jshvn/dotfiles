## Dotfiles AI Agent Guide

Purpose: Give an AI contributor the fastest path to making safe, effective changes in this dotfiles repo.

### 0. Quick Start
- Fresh install on macOS: `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./bootstrap.zsh`
- Re-run install: `task install`
- Update everything interactively: `update` (or `task update` from dotfiles dir)
- Show all tasks: `task --list`
- Set/change profile: `task profile:set PROFILE=personal` or `task profile:set PROFILE=work`
- Validate install: `task validate`
- Debug `DOTFILEDIR`: `echo $DOTFILEDIR` (in an active zsh session)
- Show current profile: `echo $DOTFILES_PROFILE` or `task profile:show`

### 1. Execution Flow (Install Pipeline)
Fresh macOS install runs `./bootstrap.zsh` which:
1. Installs go-task if not present (via official install script, not Homebrew).
2. Runs `task install` which:
   - Creates XDG directories
   - Prompts for profile (personal/work) if not set
   - Configures ZDOTDIR in `/etc/zshenv`
   - Creates all symlinks
   - Installs Homebrew and packages (common + profile-specific)
   - Applies macOS defaults
   - Runs profile-specific installation

Profile is stored persistently at `${XDG_CONFIG_HOME}/dotfiles/profile`.

**Legacy**: `./install.zsh` still works but shows deprecation warning.

### 2. Core Layout & Key Files
- `bootstrap.zsh`: new entrypoint; installs go-task, runs `task install`.
- `Taskfile.yml`: main task definitions with global variables.
- `taskfiles/*.yml`: split taskfiles for modularity:
  - `common.yml`: XDG, ZDOTDIR, shared utilities
  - `profile.yml`: profile detection, prompting, persistence
  - `links.yml`: all symlink tasks with `safe-link` helper
  - `brew.yml`: Homebrew install and bundle
  - `macos.yml`: macOS-specific (defaults, xcode, shell)
  - `personal.yml`: personal profile tasks
  - `work.yml`: work profile tasks
- `install.zsh`: deprecated orchestrator (kept for reference).
- `install/*.zsh`: legacy segmented install phases.
- `install/Brewfile.rb`: common Homebrew packages (all profiles).
- `install/personal/Brewfile.rb`: personal-only packages.
- `install/work/Brewfile.rb`: work-only packages.
- `zsh/.zshenv`: sourced by every zsh invocation; sets XDG vars, EDITOR, VEDITOR, VISUAL, BROWSER, ZDOTDIR.
- `zsh/.zprofile`: login shell initialization; evaluates Homebrew shellenv based on architecture.
- `zsh/.zshrc`: interactive startup; loads profile-aware aliases and functions; includes Antigen guard.
- `zsh/.zlogin`: login shell post-initialization; calls `motd()` if function exists.
- `zsh/.zlogout`: login shell logout hook.
- `zsh/theme.zsh`: custom theme configuration.
- `zsh/aliases/common/*.zsh`: aliases loaded for all profiles.
- `zsh/aliases/personal/*.zsh`: personal-only aliases (e.g., jgrid.zsh).
- `zsh/aliases/work/*.zsh`: work-only aliases.
- `zsh/functions/*.zsh`: common utility functions.
- `zsh/functions/personal/*.zsh`: personal-only functions.
- `zsh/functions/work/*.zsh`: work-only functions.
- `zsh/styles/`: config files for tools (`eza_style.yaml`, `glow_style.json`).
- `zsh/configs/`: tool-specific configs.
- `git/config`: main git config with `includeIf` directives.
- `git/personal/config-personal`: personal git config.
- `git/work/config-work`: work git config.
- `ssh/configs/config`: main SSH config.
- `ssh/configs/personal/config_personal`: personal SSH config.
- `ssh/configs/agent.toml`: 1Password SSH agent config.

### 2.1. Profile System
The dotfiles support two profiles: `personal` and `work`. Profile is stored at `${XDG_CONFIG_HOME}/dotfiles/profile`.

At runtime, `.zshrc` reads the profile and loads:
- Common aliases from `zsh/aliases/common/`
- Profile-specific aliases from `zsh/aliases/$DOTFILES_PROFILE/`
- Common functions from `zsh/functions/*.zsh`
- Profile-specific functions from `zsh/functions/$DOTFILES_PROFILE/`

The `DOTFILES_PROFILE` environment variable is exported for use in scripts.

### 2.2. Zsh Startup File Order & Purposes
Zsh sources files in this order for login interactive shells:
1. `/etc/zshenv` — System-wide environment (exports ZDOTDIR in this setup).
2. `$ZDOTDIR/.zshenv` (or `~/.zshenv`) — Always sourced (login, non-login, interactive, non-interactive). Sets XDG vars, ZDOTDIR, EDITOR, VEDITOR, VISUAL, BROWSER. Must be minimal and safe for scripts.
3. `$ZDOTDIR/.zprofile` (or `~/.zprofile`) — Login shells only. Evaluates `brew shellenv` with architecture detection, sets session-specific vars like SSH_AUTH_SOCK.
4. `$ZDOTDIR/.zshrc` (or `~/.zshrc`) — Interactive shells. Loads plugins (Antigen/oh-my-zsh), sources aliases/functions, sets prompts and history, lazy-loads conda.
5. `$ZDOTDIR/.zlogin` (or `~/.zlogin`) — Login shells after .zshrc. Calls `motd()` to display Tron-themed message of the day.
6. `$ZDOTDIR/.zlogout` (or `~/.zlogout`) — Login shell exit. Cleanup and finalization framework (currently minimal actual cleanup).

Key principles:
- `.zshenv`: environment only, no interactive features, no plugin managers. Sets ZDOTDIR and XDG paths.
- `.zprofile`: login-specific setup, Homebrew initialization with ARM/Intel detection.
- `.zshrc`: interactive features only (plugins, aliases, functions, prompts, history). Computes DOTFILEDIR dynamically.
- `.zlogin`: post-interactive login setup. Displays MOTD.
- `.zlogout`: cleanup on logout (history flush, temp file removal, credential locking). Extensively documented but minimal implementation.

### 3. Required Patterns & Conventions
- Functions: filename ends in `.zsh`, no output unless invoked, safe if sourced multiple times. Define function with `function name() { }` syntax.
- Aliases: group logically in separate files under `zsh/aliases/` (lexicographic load order). Use `$(command -v cmd)` for Homebrew-installed tools to ensure correct path resolution.
- Symlinks: follow `install/links.zsh` style using `safe_link()` function: `safe_link "${DOTFILEDIR}/path" "$HOME/target"`; creates parent directories with `mkdir -p` before symlinking; respect `XDG_CONFIG_HOME` when appropriate.
- Path resolution: reuse the existing `BASH_SOURCE` / `${(%):-%N}` symlink traversal approach; avoid hardcoding repo paths.
- Plugins: `zsh/.zshrc` uses Antigen at `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`; add bundles with `antigen bundle <repo>` lines near existing ones; run `antigen apply` after all bundles.
- Colorization: use `highlight --syntax=<type>` for piped output; use `tput setaf <color>` for direct terminal output; always reset with `tput sgr0`.

### 4. Common Tasks (Copy/Paste)
- Fresh install:
  `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./bootstrap.zsh`
- Re-run full install:
  `task install`
- Re-run only symlinks:
  `task links:all`
- Re-run Homebrew bundle:
  `task brew:bundle`
- Update everything interactively (inside a zsh session):
  `update`
- Set profile:
  `task profile:set PROFILE=personal` or `task profile:set PROFILE=work`
- Show current profile:
  `task profile:show`
- Validate installation:
  `task validate`
- Debug DOTFILEDIR resolution:
  `echo $DOTFILEDIR` (in an active zsh session)
- Trace zsh startup:
  `zsh -x -i`
- Show all available tasks:
  `task --list`

### 5. macOS Specifics & Safety
- Many defaults in `install/defaults.zsh` require `sudo` and affect system behavior (login, UI tweaks). Announce any modifications with rationale before changing.
- Preserve `set -e` in all orchestrated scripts—do not mask failing commands unless explicitly handled.
- Detect Homebrew prefix (`/opt/homebrew` ARM vs `/usr/local` Intel) exactly as in existing scripts; do not hardcode.
- Shell change logic: only modify `install/setshell.zsh` if adjusting how Zsh is registered; follow existing flow (`/etc/shells`, `chsh -s`).

### 6. Adding New Capabilities
- New function: create `zsh/functions/<name>.zsh` for common, or `zsh/functions/<profile>/<name>.zsh` for profile-specific; ensure idempotent; no immediate execution beyond declarations; avoid global variable leakage.
- New alias sets: add to `zsh/aliases/common/<topic>.zsh` for all profiles, or `zsh/aliases/<profile>/<topic>.zsh` for profile-specific; keep each line simple; avoid redefining existing aliases silently.
- New brew packages: append to `install/Brewfile.rb` for common packages, or `install/<profile>/Brewfile.rb` for profile-specific; run `task brew:bundle` to verify.
- New symlinks: add to `taskfiles/links.yml` using `safe-link` helper task, or to profile-specific taskfiles; test with `task links:all`.
- New configs: add to `zsh/configs/` and create corresponding symlink entry in `taskfiles/links.yml` targeting appropriate XDG location.

### 7. Troubleshooting & Diagnostics
- Check which shell: `echo $SHELL` or `ps -p $$ -o comm=`.
- Verify color support: `tput setaf 2 | cat -v` (should output non-printing escape sequences) and a green test echo.
- Confirm installed formula: `brew list | grep <name>`.
- Confirm a function loaded: `type <functionName>`.
- SSH link correctness: `ls -l ~/.ssh` (verify symlinks point to dotfiles repo).

### 8. Sourcing vs Executing (Important)
- Task-based approach: tasks run as separate shell invocations. Environment changes in one command don't persist to the next unless chained.
- Sub-steps in legacy `install.zsh` are sourced (e.g., `source "$DOTFILEDIR"/install/brew.zsh`). Keep sub-scripts safe to source: avoid `set -o nounset` pitfalls, prefer returning control to caller.
- Do not rely on being executed as standalone processes; avoid `exit` in sourced scripts unless you intend to abort the whole install.
- Maintain idempotency: allow re-runs without breaking links or duplicating config.

### 9. Do / Do Not
DO:
- Keep changes atomic and scoped.
- Maintain portability (avoid hardcoding absolute user paths).
- Document any system-level change in commit message / PR description.
DO NOT:
- Rewrite `install/defaults.zsh` wholesale.
- Introduce interactive prompts in non-interactive scripts.
- Assume Linux parity for macOS-specific defaults.
- Hardcode Homebrew prefix or shell paths.

### 10. Quick Reference Checklist (Before Merging)
1. Script passes `shellcheck` (where reasonable) or manual review for obvious issues.
2. No unintended side effects on load (functions/aliases just define, not execute logic).
3. Symlink changes tested by running `task links:all`.
4. Brew additions run cleanly: `task brew:bundle`.
5. Zsh plugin additions don't break startup (`zsh -x -i` shows successful antigen load).

### 11. Requesting More Detail
Ask for expansion explicitly: e.g. “Expand on symlink rules” or “Show pattern for adding a new update sub-step.” This file will be extended—avoid guessing.

### 12. Minimal Escape Sequences (Colors)
Use `tput` for portability; reset with `tput sgr0`.
Example: `echo "$(tput setaf 2)Success$(tput sgr0)"`

### 13. Known Quirks & Accuracy Notes
- `install.zsh` correctly computes `INSTALLFILEDIR` and exports `DOTFILEDIR="$INSTALLFILEDIR"` which points to the repo root. All subordinate scripts rely on this.
- `.zshrc` also computes `DOTFILEDIR` dynamically using symlink resolution from `${(%):-%N}` to support interactive sessions.
- macOS is the primary target. Linux support is opportunistic; do not assume parity without checks.
- The `update()` function in `zsh/functions/update.zsh` references `tldr --update`; the installed package `tlrc` provides a `tldr` binary for compatibility.
- Many aliases use `$(command -v <command>)` expansion for portability (e.g., `alias ls="$(command -v eza)"`). This resolves at shell initialization to Homebrew-installed tools.
- Syntax highlighting is ubiquitous: `highlight` command is piped throughout aliases for colorized output (history, path, hardware info).
- The `safe_link()` function in `install/links.zsh` creates parent directories automatically before creating symlinks, avoiding common path errors.
- ZDOTDIR is managed via `/etc/zshenv` (configured by `install/zdotdir.zsh`) to ensure it's set system-wide before any user zsh files are sourced.
- The MOTD system uses config files in `zsh/configs/` (`motd_sysinfo.jsonc`, `motd_tron.txt`) and can be triggered by uncommenting the `motd()` call in `.zlogin`.

### 14. Security & Secrets
- Never commit private keys. Files under `ssh/keys/` are public keys or placeholders only.
- Avoid echoing sensitive material to terminal logs in scripts.
- Prefer least-privilege: only use `sudo` for commands that require it; document why.

### 15. How Agents Use This File
- Agents (including Copilot Chat) prioritize `.github/` guidance documents. Referencing this file in discussions or PR templates increases visibility.
- This guide sets project conventions and guardrails; it is advisory but treated as authoritative for agent behavior in this repo.

If any section becomes stale (e.g., new install phase added), update both the Execution Flow and Checklist sections together.
