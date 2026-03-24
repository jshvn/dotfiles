# Dotfiles Project

## Overview

macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.
Supports three profiles: `personal`, `work`, `server`. Profile stored at
`${XDG_CONFIG_HOME}/dotfiles/profile` and exported as `$DOTFILES_PROFILE`.

## Quick Reference

- Fresh install: `./bootstrap.zsh`
- Re-install: `task install`
- Update: `task update` (or `update` in zsh)
- Validate: `task validate`
- Show tasks: `task --list`
- Set profile: `task profile:set -- personal`

## Structure

- `Taskfile.yml` -- main orchestration with global vars (XDG paths, DOTFILEDIR, PROFILE, HOMEBREW_PREFIX)
- `taskfiles/*.yml` -- modular taskfiles (helpers, common, profile, links, brew, macos, profile-tasks)
- `taskfiles/helpers.yml` -- reusable `_:safe-link`, `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`
- `install/messages.zsh` -- messaging functions (info, success, warn, error, check, cross)
- `install/Brewfile*.rb` -- common + profile-specific Homebrew packages
- `zsh/` -- shell config (.zshenv, .zprofile, .zshrc, .zlogin, .zlogout)
- `zsh/aliases/{common,personal,work}/*.zsh` -- profile-aware aliases
- `zsh/functions/*.zsh` -- common functions; `zsh/functions/{personal,work}/*.zsh` for profile-specific
- `zsh/configs/` -- tool configs (ghostty, trippy, tlrc, glow, conda, motd)
- `zsh/styles/` -- style configs (eza, glow)
- `git/` -- git config with `includeIf` for profile-specific settings
- `ssh/` -- SSH config with conditional profile includes, 1Password agent for non-server
- `claude/` -- Claude Code config (CLAUDE.md, settings, hooks, agents, commands, skills)

## Conventions

- All hooks are zsh scripts with `set -euo pipefail`. They use GNU grep (`ggrep`) from Homebrew.
- Symlinks use `_:safe-link` helper which creates parent dirs automatically.
- Aliases use `$(command -v cmd)` for Homebrew tool resolution.
- Functions: one per file, `.zsh` extension, no output on source, idempotent.
- Path resolution: use `BASH_SOURCE` / `${(%):-%N}` symlink traversal. Never hardcode repo paths.
- Detect Homebrew prefix by architecture, never hardcode.
- Tasks use `status:` checks for idempotency.
- `install/messages.zsh` must be sourced in task commands that need colored output.

## Adding Things

- **Function:** `zsh/functions/<name>.zsh` (common) or `zsh/functions/<profile>/<name>.zsh`
- **Alias:** `zsh/aliases/common/<topic>.zsh` or `zsh/aliases/<profile>/<topic>.zsh`
- **Brew package:** `install/Brewfile.rb` (common) or `install/Brewfile-<profile>.rb`
- **Symlink:** add `_:safe-link` entry in `taskfiles/links.yml` + matching validation
- **Tool config:** add to `zsh/configs/`, create symlink in `taskfiles/links.yml`

## Zsh Startup Order

1. `/etc/zshenv` -- sets ZDOTDIR
2. `.zshenv` -- XDG vars, EDITOR, DOTFILES_PROFILE (always sourced, must be minimal)
3. `.zprofile` -- brew shellenv, SSH_AUTH_SOCK (login only)
4. `.zshrc` -- plugins (Antigen/oh-my-zsh), aliases, functions, history (interactive only)
5. `.zlogin` -- MOTD display (login only)
6. `.zlogout` -- history flush (login exit)

## Safety

- macOS is the primary target. Linux support is opportunistic.
- Only use `sudo` when required; document why.
- Never commit private keys. `ssh/keys/` contains public keys only.
- Profile-conditional logic: 1Password for personal/work, system ssh-agent for server.
