# Codebase Structure

**Analysis Date:** 2026-05-13

## Directory Layout

```
dotfiles/
├── bootstrap.zsh              # Fresh-install entry point (installs go-task, delegates to task install)
├── Taskfile.yml               # Root orchestrator: global vars, taskfile includes, top-level tasks
├── taskfiles/                 # Modular go-task taskfiles
│   ├── helpers.yml            # Internal reusable tasks (_:safe-link, _:check-*)
│   ├── common.yml             # XDG dirs, ZDOTDIR /etc/zshenv, antigen update
│   ├── profile.yml            # Profile selection, ensure, set, validate
│   ├── profile-tasks.yml      # Parameterized per-profile install/links/brew/validate
│   ├── links.yml              # All symlink creation and removal
│   ├── brew.yml               # Homebrew install, update, bundle
│   ├── macos.yml              # macOS system defaults and shell registration
│   └── claude.yml             # Claude Code CLI, marketplace, plugin management
├── install/
│   ├── messages.zsh           # Colored output library (info/success/warn/error/check/cross)
│   ├── Brewfile.rb            # Common Homebrew packages (all profiles)
│   ├── Brewfile-personal.rb   # Personal-profile Homebrew packages
│   ├── Brewfile-work.rb       # Work-profile Homebrew packages
│   └── Brewfile-server.rb     # Server-profile Homebrew packages
├── zsh/
│   ├── .zshenv                # XDG vars, ZDOTDIR, DOTFILES_PROFILE (all shells)
│   ├── .zprofile              # Homebrew shellenv, SSH_AUTH_SOCK (login shells)
│   ├── .zshrc                 # Antigen plugins, aliases, functions, theme (interactive)
│   ├── .zlogin                # MOTD display (login shells, after .zshrc)
│   ├── .zlogout               # History flush (login-shell exit)
│   ├── theme.zsh              # Zsh prompt customization (alanpeabody-based)
│   ├── aliases/
│   │   ├── common/            # Aliases loaded for all profiles
│   │   │   ├── general.zsh
│   │   │   ├── hardware.zsh
│   │   │   └── networking.zsh
│   │   └── personal/          # Aliases loaded only for personal profile
│   │       └── jgrid.zsh
│   ├── functions/             # One function per file, loaded for all profiles
│   │   ├── afk.zsh
│   │   ├── aliaslist.zsh
│   │   ├── cheat.zsh
│   │   ├── docker.zsh
│   │   ├── fs.zsh
│   │   ├── functionlist.zsh
│   │   ├── geoip.zsh
│   │   ├── getcertnames.zsh
│   │   ├── ghpubkey.zsh
│   │   ├── host.zsh
│   │   ├── info.zsh
│   │   ├── ipv4lookup.zsh
│   │   ├── ipv6lookup.zsh
│   │   ├── mkcd.zsh
│   │   ├── motd.zsh
│   │   ├── permissions.zsh
│   │   ├── prettyjson.zsh
│   │   ├── pubkey.zsh
│   │   ├── sethostname.zsh
│   │   ├── sshlist.zsh
│   │   ├── timezsh.zsh
│   │   ├── update.zsh
│   │   ├── vnc.zsh
│   │   └── whois.zsh
│   ├── configs/               # Tool config files (symlinked to XDG locations)
│   │   ├── ghostty            # Ghostty terminal config
│   │   ├── glow.yml           # Glow markdown viewer config
│   │   ├── tlrc.toml          # tldr client config
│   │   ├── trippy.toml        # Trippy network tool config
│   │   ├── condarc            # Conda config
│   │   └── motd_*.{jsonc,txt} # MOTD data files
│   └── styles/                # Visual style configs (symlinked to XDG locations)
│       ├── eza_style.yaml     # eza ls-replacement theme
│       └── glow_style.json    # Glow markdown style
├── git/
│   ├── config                 # Global git config with includeIf profile routing
│   ├── config-personal        # Personal-profile git overrides (email, signing)
│   ├── config-work            # Work-profile git overrides
│   ├── config-server          # Server-profile git overrides
│   └── ignore                 # Global gitignore
├── ssh/
│   ├── cloudflared.zsh        # Cloudflare tunnel helper (symlinked to ~/.ssh/)
│   ├── configs/
│   │   ├── config             # Main SSH config with Match exec profile routing
│   │   ├── config-personal    # Personal SSH host entries
│   │   ├── config-work        # Work SSH host entries
│   │   ├── config-server      # Server SSH host entries
│   │   └── agent.toml         # 1Password SSH agent config (personal/work only)
│   └── keys/
│       └── id_ed25519_personal.pub  # Public SSH keys only (no private keys)
├── claude/
│   ├── CLAUDE.md              # Global Claude Code instructions
│   ├── settings.json          # Claude Code settings
│   ├── hooks/                 # Claude Code lifecycle hooks (.zsh and .js)
│   ├── agents/                # Claude sub-agent definitions (.md)
│   ├── commands/              # Claude slash-command definitions
│   └── skills/                # GSD skill definitions (one subdir per skill)
├── .claude/
│   └── CLAUDE.md              # Project-level Claude instructions (this repo)
├── .planning/
│   └── codebase/              # GSD codebase map documents
├── .gitignore
├── LICENSE.md
└── README.md
```

## Directory Purposes

**`taskfiles/`:**
- Purpose: Modular go-task task definitions, included by the root `Taskfile.yml`
- Contains: One `.yml` per concern (links, brew, macos, profile, claude, common, helpers)
- Key files: `helpers.yml` (shared internal helpers), `profile-tasks.yml` (parameterized per-profile)
- Naming: kebab-case filenames matching their concern

**`install/`:**
- Purpose: Install-time assets — messaging library and Homebrew manifests
- Contains: `messages.zsh` (color output), `Brewfile.rb` (common packages), `Brewfile-<profile>.rb` (per-profile)
- Key files: `messages.zsh` must be sourced before any colored output in tasks

**`zsh/`:**
- Purpose: All zsh configuration — startup chain, aliases, functions, tool configs, styles
- Key files: `.zshenv` (always-sourced env vars), `.zshrc` (interactive setup)
- Profile-aware: `aliases/<profile>/` and `functions/<profile>/` loaded conditionally by `.zshrc`

**`git/`:**
- Purpose: Git configuration with profile routing via `includeIf gitdir`
- Key files: `config` (base config with includes), `config-<profile>` (profile overrides)

**`ssh/`:**
- Purpose: SSH configuration with runtime profile routing via `Match exec`
- Key files: `configs/config` (main config reading profile file), `configs/config-<profile>` (host entries)
- Note: `keys/` contains public keys only; private keys are never committed

**`claude/`:**
- Purpose: Claude Code configuration — global instructions, hooks, agents, commands, skills
- Key files: `CLAUDE.md` (global instructions), `hooks/*.zsh` (lifecycle enforcement), `skills/` (GSD skill library)
- Deployed: All subdirs and files symlinked from `~/.config/claude/` via `taskfiles/links.yml`

## Key File Locations

**Entry Points:**
- `bootstrap.zsh`: One-shot fresh-install script; resolves DOTFILEDIR, installs go-task, runs `task install`
- `Taskfile.yml`: All routine operations — `task install`, `task update`, `task validate`, `task clean`

**Configuration:**
- `Taskfile.yml`: Global vars (XDG paths, DOTFILEDIR, PROFILE, HOMEBREW_PREFIX, DOTFILES_MESSAGES, BREW_SHELLENV)
- `zsh/.zshenv`: Runtime XDG env vars and DOTFILES_PROFILE export
- `zsh/.zshrc`: Interactive shell setup — antigen plugins, alias/function glob-loading

**Messaging:**
- `install/messages.zsh`: Colored output library, sourced inline via `{{.DOTFILES_MESSAGES}}` in all task cmds

**Profile Runtime:**
- `${XDG_CONFIG_HOME}/dotfiles/profile`: Machine-local profile name (not in repo); read by tasks, .zshenv, SSH, git

**Symlink Definitions:**
- `taskfiles/links.yml`: Canonical map of every `SOURCE → TARGET` symlink for common assets
- `taskfiles/profile-tasks.yml`: Profile-specific symlinks (`git/config-<profile>`, `ssh/configs/config-<profile>`)

**Testing/Validation:**
- Every taskfile exposes a `validate` task; root `task validate` chains them all

## Naming Conventions

**Files:**
- Zsh scripts: `.zsh` extension, kebab-case (e.g., `secret-scan.zsh`, `no-emojis.zsh`)
- Taskfiles: kebab-case `.yml` (e.g., `profile-tasks.yml`)
- Brewfiles: `Brewfile.rb` (common), `Brewfile-<profile>.rb` (profile-specific)
- Git/SSH configs: `config-<profile>` suffix (no extension)
- Functions: one per file, filename matches function name (e.g., `mkcd.zsh` defines `mkcd`)

**Directories:**
- Profile-conditional directories: `<profile>` name as subdirectory (e.g., `aliases/personal/`, `aliases/work/`)
- All lowercase, no spaces, kebab-case for multi-word names

**Tasks:**
- Public tasks: descriptive verbs (`install`, `validate`, `update`, `clean`)
- Internal helpers: `_:` namespace (`_:safe-link`, `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`)
- Profile-namespaced: `<profile>:<task>` (e.g., `personal:install`, `work:validate`)

## Where to Add New Code

**New zsh function (available to all profiles):**
- Implementation: `zsh/functions/<function-name>.zsh`
- Automatically sourced by `.zshrc` glob `zsh/functions/*.zsh`
- No registration required

**New zsh function (profile-specific):**
- Implementation: `zsh/functions/<profile>/<function-name>.zsh`
- Automatically sourced by `.zshrc` when `$DOTFILES_PROFILE` matches

**New alias (all profiles):**
- Add to existing file: `zsh/aliases/common/<topic>.zsh`
- Or create a new topic file: `zsh/aliases/common/<topic>.zsh`
- Automatically sourced by `.zshrc` glob

**New alias (profile-specific):**
- Add to or create: `zsh/aliases/<profile>/<topic>.zsh`
- Automatically sourced when profile matches

**New tool config file:**
1. Add config file to: `zsh/configs/<toolname>` or `zsh/styles/<toolname>`
2. Add `_:safe-link` entry to `taskfiles/links.yml` (tools task) pointing `SOURCE` → `TARGET` in XDG path
3. Add matching `status:` test-L check in the same task
4. Add `_:check-link` entry to `links:validate` task

**New common Homebrew package:**
- Add to `install/Brewfile.rb`

**New profile-specific Homebrew package:**
- Add to `install/Brewfile-<profile>.rb`

**New profile:**
1. Add profile name to `VALID_PROFILES` in `Taskfile.yml`
2. Create `install/Brewfile-<profile>.rb`
3. Create `git/config-<profile>`
4. Create `ssh/configs/config-<profile>`
5. Add `Match exec` block to `ssh/configs/config`
6. Add `includeIf` block to `git/config`
7. Add profile include in `Taskfile.yml` under `includes:`
8. Create `zsh/aliases/<profile>/` and `zsh/functions/<profile>/` as needed

**New Claude hook:**
- Add script to `claude/hooks/` with `.zsh` extension, make it executable (`chmod +x`)
- Register the hook event in `claude/hooks/hooks.json`
- Hook scripts are validated for executability by `task validate` via `links:validate`

**New git config entry (all profiles):**
- Edit `git/config`

**New git config entry (profile-specific):**
- Edit `git/config-<profile>`

## Special Directories

**`.planning/`:**
- Purpose: GSD project planning documents and codebase maps
- Contains: `codebase/` (ARCHITECTURE.md, STRUCTURE.md, etc.)
- Generated: No (written by GSD codebase mapper)
- Committed: Yes

**`claude/skills/`:**
- Purpose: GSD skill definitions — one subdirectory per skill, each with `SKILL.md` and `rules/*.md`
- Generated: Updated by `task claude:update` (fetches from get-shit-done-cc)
- Committed: Yes (pinned versions)

**`ssh/keys/`:**
- Purpose: Public SSH keys only; never contains private keys
- Contains: `id_ed25519_<profile>.pub` files
- Committed: Yes (public keys are safe to commit)

---

*Structure analysis: 2026-05-13*
