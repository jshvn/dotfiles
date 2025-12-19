## Dotfiles AI Agent Guide

Purpose: Give an AI contributor the fastest path to making safe, effective changes in this dotfiles repo.

### 0. Quick Start
- Fresh install on macOS: `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./bootstrap.zsh`
- Re-run install: `task install`
- Update everything interactively: `update` (or `task update` from dotfiles dir)
- Show all tasks: `task --list`
- Set/change profile: `task profile:set -- personal` or `task profile:set -- work` or `task profile:set -- server`
- Validate install: `task validate`
- Clean caches: `task clean`
- Debug `DOTFILEDIR`: `echo $DOTFILEDIR` (in an active zsh session)
- Show current profile: `echo $DOTFILES_PROFILE` or `task profile:show`

### 1. Execution Flow (Install Pipeline)
Fresh macOS install runs `./bootstrap.zsh` which:
1. Resolves `DOTFILEDIR` and sources `install/messages.zsh` for colored output.
2. Installs go-task if not present (via official install script to `/usr/local/bin` or `~/.local/bin`).
3. Runs `task install` which:
   - Creates XDG directories (`common:xdg`)
   - Prompts for profile (personal/work/server) if not set (`profile:ensure`)
   - Configures ZDOTDIR in `/etc/zshenv` (`common:zdotdir`)
   - Creates all symlinks (`links:all`)
   - Installs Homebrew and packages (`brew:install`)
   - Applies macOS defaults (`macos:defaults`)
   - Sets Homebrew zsh as default shell (`macos:shell`)
   - Runs profile-specific installation (`profile:install`)

Profile is stored persistently at `${XDG_CONFIG_HOME}/dotfiles/profile`.

### 2. Core Layout & Key Files
- `bootstrap.zsh`: entrypoint; resolves DOTFILEDIR, sources messages.zsh, installs go-task, runs `task install`.
- `Taskfile.yml`: main task definitions with global variables (HOME, XDG paths, DOTFILEDIR, PROFILE, HOMEBREW_PREFIX).
- `taskfiles/*.yml`: modular taskfiles:
  - `helpers.yml`: reusable internal tasks (`safe-link`, `check-link`, `check-dir`, `check-file`, `check-command`). Included via `_:` namespace.
  - `common.yml`: XDG directory creation, ZDOTDIR configuration, Antigen updates, validation.
  - `profile.yml`: profile detection, prompting, persistence, and profile-specific installation dispatch.
  - `profile-tasks.yml`: unified parameterized tasks for all profiles (personal, work, server). Included with `internal: true` so tasks are hidden from `task --list` but callable via `task <profile>:install`.
  - `links.yml`: all symlink creation and removal tasks (`all`, `zsh`, `git`, `ssh`, `tools`, `unlink-*`).
  - `brew.yml`: Homebrew installation and bundle management.
  - `macos.yml`: macOS-specific defaults (dock, appearance, finder, security) and shell configuration.
- `install/messages.zsh`: messaging library with `info`, `success`, `warn`, `error`, `debug`, `header`, `step`, `check`, `cross` functions.
- `install/Brewfile.rb`: common Homebrew packages (all profiles).
- `install/Brewfile-personal.rb`: personal-only packages.
- `install/Brewfile-work.rb`: work-only packages.
- `install/Brewfile-server.rb`: server-only packages.
- `zsh/.zshenv`: sourced by every zsh invocation; sets XDG vars, ZDOTDIR, EDITOR, VEDITOR, VISUAL, BROWSER, LANG, LC_ALL, DOTFILES_PROFILE.
- `zsh/.zprofile`: login shell initialization; evaluates Homebrew shellenv based on architecture; sets SSH_AUTH_SOCK for 1Password.
- `zsh/.zshrc`: interactive startup; configures history, loads Antigen/oh-my-zsh, sources profile-aware aliases and functions, lazy-loads conda.
- `zsh/.zlogin`: login shell post-initialization; calls `motd()` if function exists.
- `zsh/.zlogout`: login shell logout hook; flushes history with `fc -W`.
- `zsh/theme.zsh`: custom theme configuration.
- `zsh/aliases/common/*.zsh`: aliases loaded for all profiles (general.zsh, hardware.zsh, networking.zsh).
- `zsh/aliases/personal/*.zsh`: personal-only aliases (jgrid.zsh).
- `zsh/aliases/work/*.zsh`: work-only aliases (directory created as needed).
- `zsh/functions/*.zsh`: common utility functions (24 files including update.zsh, motd.zsh, etc.).
- `zsh/functions/personal/*.zsh`: personal-only functions (directory created as needed).
- `zsh/functions/work/*.zsh`: work-only functions (directory created as needed).
- `zsh/styles/`: style configs (`eza_style.yaml`, `glow_style.json`).
- `zsh/configs/`: tool-specific configs (`condarc`, `ghostty`, `glow.yml`, `motd_sysinfo.jsonc`, `motd_tron.txt`, `tlrc.toml`, `trippy.toml`).
- `git/config`: main git config with `includeIf` directives for profile-specific configs.
- `git/ignore`: global gitignore.
- `git/config-personal`: personal git config (uses 1Password for signing).
- `git/config-work`: work git config.
- `git/config-server`: server git config (no GPG signing, uses deploy keys).
- `ssh/configs/config`: main SSH config with conditional profile-based includes.
- `ssh/configs/config-personal`: personal SSH config (uses 1Password IdentityAgent).
- `ssh/configs/config-work`: work SSH config (uses 1Password IdentityAgent).
- `ssh/configs/config-server`: server SSH config (uses system ssh-agent with deploy keys).
- `ssh/configs/agent.toml`: 1Password SSH agent config.
- `ssh/cloudflared.zsh`: Cloudflare tunnel helper script.
- `ssh/keys/id_ed25519_personal.pub`: personal public key.

### 2.1. Profile System
The dotfiles support three profiles: `personal`, `work`, and `server`. Profile is stored at `${XDG_CONFIG_HOME}/dotfiles/profile`.

**Profile differences:**
- `personal` and `work`: Use 1Password SSH agent for key management, full desktop setup
- `server`: Uses system ssh-agent with deploy keys, minimal setup, no 1Password integration

At runtime:
- `.zshenv` reads the profile file and exports `DOTFILES_PROFILE`.
- `.zprofile` conditionally sets `SSH_AUTH_SOCK` to 1Password (skipped for server profile).
- `.zshrc` loads profile-aware aliases and functions:
  - Common aliases from `zsh/aliases/common/`
  - Profile-specific aliases from `zsh/aliases/$DOTFILES_PROFILE/`
  - Common functions from `zsh/functions/*.zsh` (excluding subdirectories)
  - Profile-specific functions from `zsh/functions/$DOTFILES_PROFILE/`

Profile tasks:
- `task profile:ensure` - prompts interactively if profile not set or invalid.
- `task profile:set -- <profile>` - set profile directly (e.g., `task profile:set -- server`).
- `task profile:show` - display current profile.
- `task profile:install` - run profile-specific installation (links + brew).

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
- Symlinks: use task-based approach with `_:safe-link` helper in taskfiles. Example:
  ```yaml
  - task: _:safe-link
    vars: { SOURCE: "{{.DOTFILEDIR}}/path", TARGET: "{{.XDG_CONFIG_HOME}}/target" }
  ```
  The helper creates parent directories automatically with `mkdir -p` before symlinking.
- Path resolution: reuse the existing `BASH_SOURCE` / `${(%):-%N}` symlink traversal approach; avoid hardcoding repo paths.
- Plugins: `zsh/.zshrc` uses Antigen at `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`; add bundles with `antigen bundle <repo>` lines near existing ones; run `antigen apply` after all bundles. Includes a guard for partial installs.
- Colorization: use `tput setaf <color>` for direct terminal output; always reset with `tput sgr0`. For install scripts, use `install/messages.zsh` functions.

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
  `task profile:set -- personal` or `task profile:set -- work` or `task profile:set -- server`
- Show current profile:
  `task profile:show`
- Validate installation:
  `task validate`
- Clean caches:
  `task clean`
- Debug DOTFILEDIR resolution:
  `echo $DOTFILEDIR` (in an active zsh session)
- Trace zsh startup:
  `zsh -x -i`
- Show all available tasks:
  `task --list`

### 5. macOS Specifics & Safety
- macOS defaults are split into subtasks in `macos.yml`: `defaults-general`, `defaults-dock`, `defaults-appearance`, `defaults-finder`, `defaults-misc`. Each includes status checks to avoid redundant writes.
- Preserve `set -e` in all orchestrated scripts—do not mask failing commands unless explicitly handled.
- Detect Homebrew prefix (`/opt/homebrew` ARM vs `/usr/local` Intel vs `/home/linuxbrew/.linuxbrew` Linux) exactly as in existing scripts; do not hardcode.
- Shell change logic: `macos:shell` task adds Homebrew zsh to `/etc/shells` and uses `chsh -s` to set default; uses Directory Services (`dscl`) to verify current shell.

### 6. Adding New Capabilities
- New function: create `zsh/functions/<name>.zsh` for common, or `zsh/functions/<profile>/<name>.zsh` for profile-specific; ensure idempotent; no immediate execution beyond declarations; avoid global variable leakage.
- New alias sets: add to `zsh/aliases/common/<topic>.zsh` for all profiles, or `zsh/aliases/<profile>/<topic>.zsh` for profile-specific; keep each line simple; avoid redefining existing aliases silently.
- New brew packages: append to `install/Brewfile.rb` for common packages, or `install/Brewfile-<profile>.rb` for profile-specific; run `task brew:bundle` to verify.
- New symlinks: add to `taskfiles/links.yml` using `safe-link` helper task; profile-specific links are handled automatically by `profile-tasks.yml`; test with `task links:all`.
- New configs: add to `zsh/configs/` and create corresponding symlink entry in `taskfiles/links.yml` targeting appropriate XDG location.

### 7. Troubleshooting & Diagnostics
- Check which shell: `echo $SHELL` or `ps -p $$ -o comm=`.
- Verify color support: `tput setaf 2 | cat -v` (should output non-printing escape sequences) and a green test echo.
- Confirm installed formula: `brew list | grep <name>`.
- Confirm a function loaded: `type <functionName>`.
- SSH link correctness: `ls -l ~/.ssh` (verify symlinks point to dotfiles repo).

### 8. Sourcing vs Executing (Important)
- Task-based approach: tasks run as separate shell invocations. Environment changes in one command don't persist to the next unless chained with `&&` or heredocs.
- Tasks source `install/messages.zsh` at the start of commands that need messaging functions.
- Do not rely on being executed as standalone processes; avoid `exit` in sourced scripts unless you intend to abort the whole install.
- Maintain idempotency: allow re-runs without breaking links or duplicating config. Tasks use `status:` checks to skip already-completed work.

### 9. Do / Do Not
DO:
- Keep changes atomic and scoped.
- Maintain portability (avoid hardcoding absolute user paths).
- Document any system-level change in commit message / PR description.
DO NOT:
- Rewrite macOS defaults in `macos.yml` wholesale without understanding each setting.
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
- `bootstrap.zsh` resolves `DOTFILEDIR` using symlink traversal before sourcing any other files.
- `.zshrc` also computes `DOTFILEDIR` dynamically using symlink resolution from `${(%):-%N}` to support interactive sessions.
- `.zshenv` reads the profile file and exports `DOTFILES_PROFILE` for use throughout the shell session.
- macOS is the primary target. Linux support is opportunistic; do not assume parity without checks.
- The `update()` function in `zsh/functions/update.zsh` calls `task update` which handles oh-my-zsh, tldr, and antigen updates.
- Many aliases use `$(command -v <command>)` expansion for portability (e.g., `alias ls="$(command -v eza)"`). This resolves at shell initialization to Homebrew-installed tools.
- The `_:safe-link` helper in `taskfiles/helpers.yml` creates parent directories automatically before creating symlinks.
- ZDOTDIR is managed via `/etc/zshenv` (configured by `common:zdotdir` task) to ensure it's set system-wide before any user zsh files are sourced.
- The MOTD system uses config files in `zsh/configs/` (`motd_sysinfo.jsonc`, `motd_tron.txt`) and is displayed via `.zlogin` calling `motd()` if the function exists.
- SSH agent is conditionally set in `.zprofile`: 1Password for workstations (hostname != "server"), system ssh-agent for servers.
- Antigen has a guard in `.zshrc` that shows a warning if not installed, allowing partial installs to proceed.
- 1Password agent.toml symlink is only created for non-server profiles.

### 14. Security & Secrets
- Never commit private keys. Files under `ssh/keys/` are public keys or placeholders only.
- Avoid echoing sensitive material to terminal logs in scripts.
- Prefer least-privilege: only use `sudo` for commands that require it; document why.

### 15. How Agents Use This File
- Agents (including Copilot Chat) prioritize `.github/` guidance documents. Referencing this file in discussions or PR templates increases visibility.
- This guide sets project conventions and guardrails; it is advisory but treated as authoritative for agent behavior in this repo.

If any section becomes stale (e.g., new install phase added), update both the Execution Flow and Checklist sections together.
