# External Integrations

**Analysis Date:** 2026-05-13

## SSH & Remote Access

**1Password SSH Agent:**
- Profiles: `personal`, `work` (not `server`)
- Socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- Set as `SSH_AUTH_SOCK` in `zsh/.zprofile`
- Agent config: `ssh/configs/agent.toml` → symlinked to `$XDG_CONFIG_HOME/1Password/ssh/agent.toml`
- Key managed: `id_ed25519_personal` from 1Password vault "Personal"
- Cask installed in all non-server profiles: `1password`, `1password-cli`
- Conditional: `zsh/.zprofile` checks `hostname -s != "server"` before setting socket

**Cloudflare Tunnel (cloudflared):**
- Purpose: SSH proxy for `*.jgrid.net` and `*.plex.me` hosts (personal profile)
- ProxyCommand wrapper: `ssh/cloudflared.zsh` → symlinked to `~/.ssh/cloudflared.zsh`
- Invoked via SSH config: `ProxyCommand ~/.ssh/cloudflared.zsh access ssh --hostname %h`
- Cask `cloudflare-warp` installed in personal and server profiles
- CLI `cloudflared` installed in common `Brewfile.rb`
- SSH aliases for jgrid.net hosts defined in `zsh/aliases/personal/jgrid.zsh`

**GitHub:**
- Server profile SSH config (`ssh/configs/config-server`) configures `Host github.com`
- Uses `id_ed25519_server` deploy key, `AddKeysToAgent yes`
- Public key stored at `ssh/keys/id_ed25519_personal.pub` (committed; private key not stored)

## Version Control

**Git (profile-conditional identity):**
- Common config: `git/config` → `$XDG_CONFIG_HOME/git/config`
- Profile-specific identities via `includeIf "gitdir/i:..."` in `git/config`:
  - `git/config-personal` → for repos under `~/git/personal/`
  - `git/config-work` → for repos under `~/git/work/`
  - `git/config-server` → for repos under `~/git/server/`
- Pager: `git-delta` (configured with side-by-side, Monokai Extended theme)
- Editor: `code` (VS Code)

## Claude Code Ecosystem

**Claude CLI:**
- Installed via Homebrew: `brew install claude` (referenced in `taskfiles/claude.yml`)
- Config dir: `$XDG_CONFIG_HOME/claude` (non-default; set via `CLAUDE_CONFIG_DIR` in `.zshenv`)

**GSD Framework (get-shit-done-cc):**
- Source: npm package `get-shit-done-cc`
- Install: `npx -y get-shit-done-cc@latest --claude --global` (run by `taskfiles/claude.yml`)
- Provides: GSD skill system (`claude/skills/gsd-*/`), commands, and agent definitions

**Plugin Marketplace — ecc (everything-claude-code):**
- Source: `https://github.com/affaan-m/everything-claude-code.git`
- Registered as marketplace name `ecc`
- Plugin installed: `ecc@ecc`
- Enabled in `claude/settings.json`: `"enabledPlugins": { "ecc@ecc": true }`

**MCP Servers (referenced in agent definitions):**
- `context7` (`mcp__context7__*`) — library documentation lookup; used by `gsd-domain-researcher` and `gsd-project-researcher` agents
- `firecrawl` (`mcp__firecrawl__*`) — web scraping and search; used by `gsd-project-researcher` and `gsd-ui-researcher` agents
- `exa` (`mcp__exa__*`) — semantic web search; used by `gsd-project-researcher` and `gsd-ui-researcher` agents
- Note: MCP servers are referenced in agent `tools:` frontmatter but not configured in this repo's `settings.json`. They are expected to be registered separately per-project.

**Claude Code Hooks:**
- `claude/hooks/hooks.json` — hook definitions loaded by Claude Code
- `claude/settings.json` — additional hooks embedded (SessionStart, PreToolUse, PostToolUse)
- Hook scripts:
  - `secret-scan.zsh` — blocks writes containing API keys, tokens, private keys (PreToolUse)
  - `block-destructive.zsh` — blocks force push, `rm -rf`, `DROP TABLE`, `--no-verify` (PreToolUse)
  - `no-ai-comments.zsh` — warns on AI attribution in code/commits (PostToolUse)
  - `no-emojis.zsh` — warns on emoji in code files (PostToolUse)
  - `agent-transparency.zsh` — logs subagent delegation details (PreToolUse)
  - `notify.zsh` — macOS desktop notification when Claude needs attention (Notification)
  - `post-compact.zsh` — re-injects git context after compaction (SessionStart)
  - `gsd-check-update.js` / `gsd-check-update-worker.js` — checks for GSD updates (SessionStart)
  - `gsd-context-monitor.js` — monitors context usage (PostToolUse)
  - `gsd-phase-boundary.sh` — detects phase boundary changes (PostToolUse)
  - `gsd-prompt-guard.js`, `gsd-read-guard.js`, `gsd-workflow-guard.js` — GSD workflow enforcement (PreToolUse)
  - `gsd-read-injection-scanner.js` — scans reads for prompt injection (PostToolUse)
  - `gsd-validate-commit.sh` — validates commit format (PreToolUse on Bash)
  - `gsd-session-state.sh` — manages session state (SessionStart)
  - `gsd-statusline.js` — status line display
  - `gsd-update-banner.js` — displays update notifications

## Python Environment

**Miniconda:**
- Cask installed in all three profiles (`Brewfile-personal.rb`, `Brewfile-work.rb`, `Brewfile-server.rb`)
- Lazy-initialized in `.zshrc` to avoid startup latency
- Config symlinked: `zsh/configs/condarc` → `$XDG_CONFIG_HOME/conda/condarc`
- Environments: `$XDG_DATA_HOME/conda/envs`
- Package cache: `$XDG_CACHE_HOME/conda/pkgs`
- Telemetry disabled: `anaconda_anon_usage: false`

## Containerization

**Docker Desktop:**
- Cask installed in all three profiles
- Zsh function wrapper: `zsh/functions/docker.zsh` adds `docker ps` and `docker bash` subcommands

## Developer Tooling

**VS Code:**
- Shell integration loaded in `.zshrc` when `TERM_PROGRAM == "vscode"`
- Cask installed in personal and work profiles: `visual-studio-code`
- Set as `VEDITOR` and `VISUAL` env vars in `.zshenv`

**Ghostty Terminal:**
- Cask installed in all profiles
- Config symlinked: `zsh/configs/ghostty` → `$XDG_CONFIG_HOME/ghostty/config`
- `TERM` override in SSH config to `xterm-256color` (Ghostty's `xterm-ghostty` not widely supported)
- Shell alias: `g` → `/Applications/Ghostty.app/Contents/MacOS/ghostty`

## Personal Productivity Apps (macOS Casks)

**Personal profile:**
- Proton Mail, Proton Drive, ProtonVPN — encrypted communications
- Dropbox — file sync
- Cryptomator — encrypted vault for cloud storage
- 1Password — password/secrets manager
- Raycast — launcher
- Standard Notes — encrypted notes
- Fantastical, Cardhop — calendar and contacts
- Discord, Slack, WhatsApp — messaging
- Spotify — music
- Firefox — browser

**Work profile (subset):**
- 1Password, Raycast, Slack, Standard Notes, Fantastical, Cardhop, Firefox, Spotify, VS Code, Ghostty, Sourcetree, Sublime Text, Docker Desktop, Miniconda

**Server profile (minimal):**
- 1Password, Docker Desktop, Dropbox, Cryptomator, Ghostty, Miniconda, Cloudflare WARP

**App Store (personal + work):**
- Magnet (`id: 441258766`) — window manager
- Things (`id: 904280696`) — task manager

## Secrets Management

**Location:** 1Password (personal/work profiles)
- SSH private keys stored in 1Password, accessed via SSH agent socket
- No private keys committed to this repo (`ssh/keys/` contains only `.pub` files)
- Claude hooks block: API keys, tokens, private keys, `.env` contents from being written to files

**Environment variables:**
- No `.env` files in this repo
- Profile file: `$XDG_CONFIG_HOME/dotfiles/profile` (plaintext, value: profile name only)
- `settings.json` denylist blocks Claude from reading `.env`, `*.pem`, `*.key`, `**/secrets/*`, `**/*credential*`

---

*Integration audit: 2026-05-13*
