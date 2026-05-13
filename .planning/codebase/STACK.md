# Technology Stack

**Analysis Date:** 2026-05-13

## Languages

**Primary:**
- Zsh — all shell configuration, aliases, functions, hooks, and install scripts
- YAML — go-task orchestration (`Taskfile.yml`, `taskfiles/*.yml`)
- Ruby DSL — Homebrew bundle manifests (`install/Brewfile*.rb`)
- TOML — tool configuration files (`ssh/configs/agent.toml`, `zsh/configs/trippy.toml`, `zsh/configs/tlrc.toml`)

**Secondary:**
- JavaScript/Node.js — Claude Code hook scripts (`claude/hooks/*.js`)
- Bash — some Claude Code hook scripts (`claude/hooks/*.sh`)
- JSON — Claude Code settings (`claude/settings.json`)
- YAML/JSON — Claude Code agent definitions (`claude/agents/*.md` frontmatter)

## Runtime

**Environment:**
- macOS (primary target); Linux supported opportunistically
- Architecture-aware: arm64 (`/opt/homebrew`) vs. x86_64 (`/usr/local`)

**Shell:**
- Zsh (Homebrew-managed, not system zsh)
- `ZDOTDIR` set to `$XDG_CONFIG_HOME/zsh` via `/etc/zshenv`
- Startup order: `.zshenv` → `.zprofile` (login) → `.zshrc` (interactive) → `.zlogin` (login) → `.zlogout` (login exit)

**Node.js:**
- Required at `/opt/homebrew/bin/node` for Claude Code JS hooks
- Not managed by this repo directly — expected to be available via Homebrew

## Frameworks / Orchestration

**Task Runner:**
- go-task v3 (`Taskfile.yml` schema `version: '3'`)
- Installed via `https://taskfile.dev/install.sh` if missing (see `bootstrap.zsh`)
- Brewfile also installs it: `brew "go-task"` (`install/Brewfile.rb`)
- Modular: root `Taskfile.yml` includes `taskfiles/*.yml`
- Idempotent via `status:` checks on all tasks

**Plugin Manager (Zsh):**
- Antigen — installed via Homebrew (`brew "antigen"`)
- Config: `ADOTDIR=$XDG_CONFIG_HOME/antigen`
- Loaded in `.zshrc` from `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`
- oh-my-zsh used as Antigen bundle source

**Python Environment:**
- Miniconda (Cask) — installed in all profiles
- Lazy-loaded in `.zshrc` to avoid slow startup
- Config: `zsh/configs/condarc` → `$XDG_CONFIG_HOME/conda/condarc`
- Envs stored at `$XDG_DATA_HOME/conda/envs`, cache at `$XDG_CACHE_HOME/conda/pkgs`
- `uv` referenced in global `CLAUDE.md` as preferred Python package manager for projects

## Key Homebrew Packages

**Shell / Terminal:**
- `zsh` — Homebrew-managed shell
- `antigen` — Zsh plugin manager
- `eza` — `ls` replacement (aliased in `zsh/aliases/common/general.zsh`)
- `bat` — `cat` replacement
- `grc` — colorized output for common commands
- `highlight` — syntax highlighting for terminal output

**Development:**
- `git` — version-controlled, not relying on system git
- `git-delta` — pager for `git diff`/`git log` (configured in `git/config`)
- `grep` (GNU grep) — PCRE support, invoked as `ggrep` in hooks
- `fd` — `find` replacement
- `jq` — JSON processor (required by `taskfiles/claude.yml`)

**Networking / Ops:**
- `cloudflared` — Cloudflare Tunnel client, used as SSH `ProxyCommand`
- `openssh` — Homebrew SSH (not system)
- `doggo` — DNS lookup
- `trippy` — traceroute replacement (aliased in `zsh/aliases/common/networking.zsh`)
- `wget`

**Utilities:**
- `go-task` — task runner
- `tlrc` — tldr client
- `glow` — Markdown terminal renderer
- `htop`, `bottom`, `duf`, `ncdu` — system monitoring
- `fastfetch` — system info display
- `mas` — Mac App Store CLI
- `coreutils` — GNU utilities
- `hugo` — static site generation
- `onefetch` — git repo info display

## Claude Code Configuration Surface

**Config root:** `claude/` → symlinked to `$XDG_CONFIG_HOME/claude/`

**Components:**
- `claude/CLAUDE.md` — global instructions for all projects
- `claude/settings.json` — permissions allowlist/denylist, hooks, plugin registry
- `claude/hooks/` — 20 hook scripts (Zsh and Node.js)
- `claude/agents/` — 25 subagent definitions (Markdown with YAML frontmatter)
- `claude/commands/` — slash command definitions
- `claude/skills/` — 60+ GSD skill directories with `SKILL.md` index files

**GSD Framework:**
- Installed via `npx -y get-shit-done-cc@latest --claude --global` (see `taskfiles/claude.yml`)
- Plugin marketplace: `ecc` (everything-claude-code) from `https://github.com/affaan-m/everything-claude-code.git`
- Plugin installed: `ecc@ecc`

## Configuration System

**Environment:**
- XDG Base Directory Specification throughout:
  - `XDG_CONFIG_HOME=$HOME/.config`
  - `XDG_DATA_HOME=$HOME/.local/share`
  - `XDG_STATE_HOME=$HOME/.local/state`
  - `XDG_CACHE_HOME=$HOME/.cache`
- Profile stored at `$XDG_CONFIG_HOME/dotfiles/profile` (values: `personal`, `work`, `server`)
- Exported as `$DOTFILES_PROFILE` in `.zshenv`
- Claude config dir: `$XDG_CONFIG_HOME/claude` (via `CLAUDE_CONFIG_DIR` in `.zshenv`)

**Symlink Deployment:**
- All configs deployed via `ln -sfn` using `_:safe-link` helper in `taskfiles/helpers.yml`
- No config files are placed directly in home directory; all go through XDG paths
- Exception: `~/.ssh/config` (SSH spec requirement) and `~/.ssh/config-*` profile files

**Build/Installation:**
- `bootstrap.zsh` — fresh install entry point; installs go-task, then delegates to `task install`
- `task install` — full install sequence: XDG dirs → profile → zdotdir → symlinks → brew → claude → macOS defaults → shell → profile-specific install
- `task validate` — idempotent validation of all installed components
- `task update` — git pull + brew update + oh-my-zsh upgrade + antigen update + claude update

## Platform Requirements

**Development / macOS workstation:**
- macOS (tested on arm64; x86_64 supported)
- Homebrew (auto-installed by `bootstrap.zsh` and `taskfiles/brew.yml`)
- go-task (auto-installed by `bootstrap.zsh`)
- 1Password app + CLI (personal/work profiles)
- Node.js at `/opt/homebrew/bin/node` (for Claude hooks)

**Server profile:**
- Linux (Homebrew via Linuxbrew path `/home/linuxbrew/.linuxbrew`)
- System ssh-agent (no 1Password)
- Subset of casks installed (server Brewfile only has server-relevant apps)

---

*Stack analysis: 2026-05-13*
