## Dotfiles AI Agent Guide

Purpose: Give an AI contributor the fastest path to making safe, effective changes in this dotfiles repo.

### 0. Quick Start
- Install on macOS: `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./install.zsh`
- Re-run links only: `bash install/links.zsh`
- Re-run Homebrew bundle: `brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb`
- Update in an interactive Zsh: `update`
- Debug `DOTFILEDIR`: `ZDOTDIR=$PWD/zsh zsh -i -c 'echo $DOTFILEDIR'`

### 1. Execution Flow (Install Pipeline)
Fresh macOS install runs `./install.zsh` which:
1. Resolves and exports `DOTFILEDIR`.
2. Sources (in order): `install/links.zsh`, `install/brew.zsh`, `install/xcode.zsh`, `install/defaults.zsh`, `install/setshell.zsh`.
3. Prints completion message with color (`tput setaf`).
All steps assume Bash (`#!/usr/bin/env bash`) and abort on first error (`set -e`).

### 2. Core Layout & Key Files
- `install.zsh`: orchestrator (entrypoint).
- `install/*.zsh`: segmented install phases (idempotent expectation).
- `install/Brewfile.rb`: declarative Homebrew bundle (CLI tools + apps).
- `zsh/.zshrc`: interactive startup; computes `DOTFILEDIR`; auto-sources `zsh/aliases/*` and `zsh/functions/*`.
- `zsh/aliases/*.zsh`: utility aliases (loaded unconditionally). Keep side effects minimal.
- `zsh/functions/*.zsh`: utility functions (loaded unconditionally). Keep side effects minimal.
- `ssh/configs/`, `ssh/keys/`: symlinked into `$HOME/.ssh/` by `install/links.zsh`.

### 3. Required Patterns & Conventions
- Functions: filename ends in `.zsh`, no output unless invoked, safe if sourced multiple times.
- Aliases: group logically in separate files under `zsh/aliases/` (lexicographic load order).
- Symlinks: follow `install/links.zsh` style: `ln -sf "${DOTFILEDIR}/path" "$HOME/target"`; respect `XDG_CONFIG_HOME` when appropriate.
- Path resolution: reuse the existing `BASH_SOURCE` / script-location approach; avoid hardcoding repo paths.
- Plugins: `zsh/.zshrc` uses Antigen at `$(brew --prefix)/share/antigen/antigen.zsh`; add bundles with `antigen bundle <repo>` lines near existing ones.

### 4. Common Tasks (Copy/Paste)
- Fresh install:
  `git clone https://github.com/jshvn/dotfiles.git && cd dotfiles && ./install.zsh`
- Re-run only symlinks (after moving repo):
  `bash install/links.zsh`
- Re-run Homebrew bundle:
  `brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb`
- Update everything interactively (inside a zsh session):
  `update`
- Debug DOTFILEDIR resolution:
  `echo $DOTFILEDIR`
  `ZDOTDIR=$PWD/zsh zsh -i -c 'echo $DOTFILEDIR'`
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
- New symlinks: modify `install/links.zsh` following existing pattern; test by re-running links script.

### 7. Troubleshooting & Diagnostics
- Check which shell: `echo $SHELL` or `ps -p $$ -o comm=`.
- Verify color support: `tput setaf 2 | cat -v` (should output non-printing escape sequences) and a green test echo.
- Confirm installed formula: `brew list | grep <name>`.
- Confirm a function loaded: `type <functionName>`.
- SSH link correctness: `ls -l ~/.ssh | grep DOTFILEDIR`.

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
- `install.zsh` computes `INSTALLFILEDIR` and exports `DOTFILEDIR`, but ensure `DOTFILEDIR` is actually assigned to the repo root (e.g., `DOTFILEDIR="$INSTALLFILEDIR"; export DOTFILEDIR`). If not, subordinate `source "$DOTFILEDIR"/...` calls will fail. Ask to patch if this diverges.
- macOS is the primary target. Linux support is opportunistic; do not assume parity without checks.

### 14. Security & Secrets
- Never commit private keys. Files under `ssh/keys/` are public keys or placeholders only.
- Avoid echoing sensitive material to terminal logs in scripts.
- Prefer least-privilege: only use `sudo` for commands that require it; document why.

### 15. How Agents Use This File
- Agents (including Copilot Chat) prioritize `.github/` guidance documents. Referencing this file in discussions or PR templates increases visibility.
- This guide sets project conventions and guardrails; it is advisory but treated as authoritative for agent behavior in this repo.

If any section becomes stale (e.g., new install phase added), update both the Execution Flow and Checklist sections together.
