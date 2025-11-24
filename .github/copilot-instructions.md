## Dotfiles AI Agent Guide

Purpose: Give an AI contributor the fastest path to making safe, effective changes in this dotfiles repo.

### 0. Quick Start
- Install on macOS: `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./install.zsh`
- Re-run links only: `zsh install/links.zsh`
- Re-run Homebrew bundle: `brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb`
- Update in an interactive Zsh: `update`
- Debug `DOTFILEDIR`: `echo $DOTFILEDIR` (in an active zsh session)

### 1. Execution Flow (Install Pipeline)
Fresh macOS install runs `./install.zsh` which:
1. Resolves and exports `DOTFILEDIR`.
2. Sources (in order): `install/xdg.zsh`, `install/links.zsh`, `install/brew.zsh`, `install/xcode.zsh`, `install/defaults.zsh`, `install/setshell.zsh`.
3. Prints completion message with color (`tput setaf`).
All steps abort on first error (`set -e`).

### 2. Core Layout & Key Files
- `install.zsh`: orchestrator (entrypoint); resolves `DOTFILEDIR` via `BASH_SOURCE` symlink traversal.
- `install/*.zsh`: segmented install phases (idempotent expectation).
- `install/xdg.zsh`: ensures XDG base directories exist early in the flow; sets up `ZDOTDIR` and manages `/etc/zshenv` for ZDOTDIR export.
- `install/Brewfile.rb`: declarative Homebrew bundle (CLI tools + apps).
- `install/links.zsh`: symlink creation script; uses `safe_link()` helper function to create parent directories and force-symlink files.
- `zsh/.zshenv`: sourced by every zsh invocation; sets XDG vars, EDITOR, VEDITOR, VISUAL, BROWSER, ZDOTDIR; minimal and non-interactive safe.
- `zsh/.zprofile`: login shell initialization; evaluates Homebrew shellenv based on architecture (ARM vs Intel); sets SSH agent.
- `zsh/.zshrc`: interactive startup; computes `DOTFILEDIR` via `${(%):-%N}` symlink resolution; loads Antigen plugins from oh-my-zsh; auto-sources `zsh/aliases/*` and `zsh/functions/*` via for-loops; includes lazy conda initialization.
- `zsh/.zlogin`: login shell post-initialization; calls `motd()` function to display Tron-themed message of the day on login.
- `zsh/.zlogout`: login shell logout hook with extensive documentation; provides cleanup framework but minimal actual cleanup code.
- `zsh/theme.zsh`: custom theme configuration sourced by `.zshrc`.
- `zsh/aliases/*.zsh`: utility aliases (loaded lexicographically). Keep side effects minimal. Many use `$(which cmd)` for Homebrew tool paths.
- `zsh/functions/*.zsh`: utility functions (loaded lexicographically). Keep side effects minimal. Includes `motd.zsh` for Tron-themed system info display.
- `zsh/styles/`: config files for tools (`eza_style.yaml`, `glow_style.json`).
- `zsh/configs/`: tool-specific configs (`trippy.toml`, `tlrc.toml`, `condarc`, `ghostty`, `motd_sysinfo.jsonc`, `motd_tron.txt`).
- `git/config`: main git config with `includeIf` directives for personal and work subdirectory configs; uses delta pager.
- `git/ignore`: global git ignore file (symlinked as excludesfile).
- `git/personal/config-personal`: personal git config (email, signing) included conditionally for `~/Git/personal/` repos.
- `git/work/config-work`: work git config included conditionally for `~/Git/work/` repos.
- `ssh/configs/config`: main SSH config file symlinked to `$HOME/.ssh/config`.
- `ssh/configs/personal/config_personal`: personal SSH config included from main config.
- `ssh/keys/id_ed25519_personal.pub`: public key symlinked to `$HOME/.ssh/`.
- `ssh/configs/agent.toml`: 1Password SSH agent filtering config symlinked to `$XDG_CONFIG_HOME/1Password/ssh/agent.toml`.
- `ssh/cloudflared.zsh`: proxy command script for cloudflared SSH tunnels.

### 2.1. Zsh Startup File Order & Purposes
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
- Aliases: group logically in separate files under `zsh/aliases/` (lexicographic load order). Use `$(which cmd)` for Homebrew-installed tools to ensure correct path resolution.
- Symlinks: follow `install/links.zsh` style using `safe_link()` function: `safe_link "${DOTFILEDIR}/path" "$HOME/target"`; creates parent directories with `mkdir -p` before symlinking; respect `XDG_CONFIG_HOME` when appropriate.
- Path resolution: reuse the existing `BASH_SOURCE` / `${(%):-%N}` symlink traversal approach; avoid hardcoding repo paths.
- Plugins: `zsh/.zshrc` uses Antigen at `$(brew --prefix)/share/antigen/antigen.zsh`; add bundles with `antigen bundle <repo>` lines near existing ones; run `antigen apply` after all bundles.
- Colorization: use `highlight --syntax=<type>` for piped output; use `tput setaf <color>` for direct terminal output; always reset with `tput sgr0`.

### 4. Common Tasks (Copy/Paste)
- Fresh install:
  `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./install.zsh`
- Re-run only symlinks (after moving repo):
  `zsh install/links.zsh`
- Re-run Homebrew bundle:
  `brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb`
- Update everything interactively (inside a zsh session):
  `update`
- Debug DOTFILEDIR resolution:
  `echo $DOTFILEDIR` (in an active zsh session)
- Trace zsh startup:
  `zsh -x -i`
- Homebrew only (manual):
  `brew update && brew bundle --file "$PWD/install/Brewfile.rb"`

### 5. macOS Specifics & Safety
- Many defaults in `install/defaults.zsh` require `sudo` and affect system behavior (login, UI tweaks). Announce any modifications with rationale before changing.
- Preserve `set -e` in all orchestrated scripts—do not mask failing commands unless explicitly handled.
- Detect Homebrew prefix (`/opt/homebrew` ARM vs `/usr/local` Intel) exactly as in existing scripts; do not hardcode.
- Shell change logic: only modify `install/setshell.zsh` if adjusting how Zsh is registered; follow existing flow (`/etc/shells`, `chsh -s`).

### 6. Adding New Capabilities
- New function: create `zsh/functions/<name>.zsh`; ensure idempotent; no immediate execution beyond declarations; avoid global variable leakage.
- New alias sets: add `zsh/aliases/<topic>.zsh`; keep each line simple; avoid redefining existing aliases silently.
- New brew packages: append to `install/Brewfile.rb` in appropriate section (formula vs cask); run bundle to verify.
- New symlinks: modify `install/links.zsh` following existing pattern using `safe_link()` function; test by re-running links script.
- New configs: add to `zsh/configs/` and create corresponding symlink in `install/links.zsh` using `safe_link()` to target appropriate XDG location.

### 7. Troubleshooting & Diagnostics
- Check which shell: `echo $SHELL` or `ps -p $$ -o comm=`.
- Verify color support: `tput setaf 2 | cat -v` (should output non-printing escape sequences) and a green test echo.
- Confirm installed formula: `brew list | grep <name>`.
- Confirm a function loaded: `type <functionName>`.
- SSH link correctness: `ls -l ~/.ssh` (verify symlinks point to dotfiles repo).

### 8. Sourcing vs Executing (Important)
- Sub-steps are sourced by `install.zsh` (e.g., `source "$DOTFILEDIR"/install/brew.zsh`). Keep sub-scripts safe to source: avoid `set -o nounset` pitfalls, prefer returning control to caller.
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
3. Symlink changes tested by running `zsh install/links.zsh`.
4. Brew additions run cleanly: `brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb`.
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
- The `update()` function in `zsh/functions/update.zsh` references `tldr --update`, but the installed package is `tlrc`. The command is likely an alias or binary provided by tlrc package.
- Many aliases use `$(which <command>)` expansion for portability (e.g., `alias ls="$(which eza)"`). This resolves at shell initialization to Homebrew-installed tools.
- Syntax highlighting is ubiquitous: `highlight` command is piped throughout aliases for colorized output (history, path, hardware info).
- The `safe_link()` function in `install/links.zsh` creates parent directories automatically before creating symlinks, avoiding common path errors.
- ZDOTDIR is managed via `/etc/zshenv` to ensure it's set system-wide before any user zsh files are sourced.
- The MOTD system uses config files in `zsh/configs/` (`motd_sysinfo.jsonc`, `motd_tron.txt`) and is triggered by `.zlogin` calling the `motd()` function.

### 14. Security & Secrets
- Never commit private keys. Files under `ssh/keys/` are public keys or placeholders only.
- Avoid echoing sensitive material to terminal logs in scripts.
- Prefer least-privilege: only use `sudo` for commands that require it; document why.

### 15. How Agents Use This File
- Agents (including Copilot Chat) prioritize `.github/` guidance documents. Referencing this file in discussions or PR templates increases visibility.
- This guide sets project conventions and guardrails; it is advisory but treated as authoritative for agent behavior in this repo.

If any section becomes stale (e.g., new install phase added), update both the Execution Flow and Checklist sections together.
