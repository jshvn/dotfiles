# Linux Server Support — Design

Date: 2026-07-14
Status: Approved for planning

## Problem

The dotfiles repo is macOS-only by design (v1). The operator now runs long-lived
headless Ubuntu server VMs (x86_64, cloud/other hosts) and wants the same
manifest-driven install pipeline there: full zsh experience, MOTD, dev tool
configs, and declared CLI packages — without 1Password, whose credentials must
not live on remote disk.

## Decisions (settled during brainstorming)

| Decision | Choice |
|----------|--------|
| Linux target | Ubuntu only, headless servers, x86_64. No NixOS (no-Nix decision stands). No desktop Linux. |
| Package manager | Homebrew on Linux (linuxbrew, `/home/linuxbrew/.linuxbrew`). Reuses the existing bundle -> Brewfile -> `brew bundle` pipeline. No apt package layer beyond bootstrap prerequisites. |
| Server scope | Full zsh experience (antidote, theme, aliases, functions), MOTD, dev tool configs. No GUI configs. No Claude Code on servers. |
| Identity | Per-server local ed25519 keys. No 1Password. No commit signing on servers. |
| Bootstrap | Manual and interactive: SSH in, run bootstrap with consent gates. Repo is public; clone over HTTPS needs no credentials. |
| Linux OS layer | Hostname (`hostnamectl`) and default-shell registration (`chsh`) only. No systemd/timezone/unattended-upgrades management. |
| Ongoing testing | GitHub Actions CI on `ubuntu-latest` running the full pipeline. |

## Structural approach

Inline dispatch at existing seams — not a parallel Linux tree. The seams
already exist: `platform.os` is in the manifest schema (validation-locked to
darwin), `macos.yml`/`hostname.yml` carry `platforms: [darwin]`, macOS shell
surfaces are feature-gated via `_dotfiles_require_feature`, and
`shell/.zprofile` has a comment marking where the removed linuxbrew branch
goes back. Flat directory conventions are preserved.

## Design by component

### 1. Manifest and resolver (`install/resolver.zsh`, `manifests/`)

- Relax the `platform.os` validation enum from `{darwin}` to `{darwin, linux}`
  (resolver.zsh ~172-178).
- New cross-field rules: `features.one-password-ssh`,
  `features.one-password-signing`, and every `features.macos-*` flag require
  `platform.os = "darwin"`. Clear resolver error at `task setup` time otherwise.
- Existing rules unchanged: `identity.ssh in {personal, work}` still requires
  `one-password-ssh`, etc. The new `server` identity (below) escapes them the
  same way `atium`/`none` do.
- New machine manifest `manifests/machines/<server>.toml`:
  `platform.os = "linux"`, `platform.arch = "x86_64"`, CLI-only bundles
  (no `dotfiles-gui`/`apps`/`productivity`), `identity.git = identity.ssh =
  "server"`, `features.claude = false`, empty `[claude].addons`.
- `docs/MANIFEST.md` schema updated.

### 2. Identity without 1Password (`identity/`, `taskfiles/identity.yml`)

- New overlay `identity/git/identities/server`: user name/email,
  `commit.gpgsign = false`, no `gpg.ssh.program`.
- New overlay `identity/ssh/identities/server`: `IdentityFile
  ~/.ssh/id_ed25519`, no `IdentityAgent`, no 1Password socket.
- New task `identity:keygen` (Linux-relevant, platform-agnostic in
  implementation): generate `~/.ssh/id_ed25519` if missing (`status:` block
  checks existence), print the public key with instructions to add it to
  GitHub as an auth key. Private keys never enter the repo (existing rule).
- `identity:validate` ssh-add probe stays gated on `one-password-ssh`.

### 3. Homebrew prefix dispatch

- `Taskfile.yml` HOMEBREW_PREFIX resolution gains the Linux branch:
  `brew --prefix` if brew is on PATH; else Darwin/arm64 ->
  `/opt/homebrew`, Darwin/x86_64 -> `/usr/local`, Linux ->
  `/home/linuxbrew/.linuxbrew`.
- `shell/.zprofile`: restore the linuxbrew branch in the arch/OS dispatch.
- `shell/.zshrc` antidote path already flows through `$HOMEBREW_PREFIX` — no
  change.
- LINT-10 (hardcoded prefix) allowlist covers the new dispatch sites via the
  existing `# lint-allow: hardcoded-prefix` annotation.

### 4. Package pipeline (`install/compose-brewfile.zsh`, `taskfiles/packages.yml`)

- `compose-brewfile.zsh` filters by `platform.os` from resolved.json: on
  linux, drop `cask`, `mas`, and `vscode` DSL lines; keep `brew`, `cargo`,
  `uv`, `npm`.
- `packages:verify`: `/Applications/<App>.app` artifact probes and `mas`
  checks run only on darwin. Formula verification unchanged.
- `packages:audit`: cask/mas/vscode comparisons darwin-only.
- Bundle TOMLs unchanged — server manifests express platform differences by
  bundle selection, not per-entry annotations. The mandatory `dotfiles`
  bundle's formulae (coreutils, grep, openssh) install harmlessly on
  linuxbrew; its `mas` entries are dropped by the compose filter.

### 5. Bootstrap (`bootstrap.zsh`)

- `uname -s` dispatch at the top. Darwin path unchanged.
- Linux path, same interactive AUDIT/consent gate pattern:
  1. `sudo apt-get install -y build-essential procps curl file git zsh`
  2. Homebrew install script (same consent gate as macOS path)
  3. `brew install go-task yq`
  4. List machine manifests and point at `task setup -- <machine>`.
- Ubuntu-only guard: warn (not fail) if `/etc/os-release` is not Ubuntu.

### 6. Linux OS layer (`os/`, `taskfiles/hostname.yml`, `taskfiles/macos.yml`)

- `os/hostname.zsh`: internal dispatch — `scutil` on Darwin,
  `sudo hostnamectl set-hostname` on Linux. `taskfiles/hostname.yml` tasks
  drop `platforms: [darwin]` (script handles both).
- `os/shell-registration.zsh`: read the registered shell via `dscl` on
  Darwin, `getent passwd $USER` on Linux; `chsh -s` and `/etc/shells` append
  work on both. The registration task moves out from behind
  `platforms: [darwin]` (currently in macos.yml) so Linux machines get zsh
  as login shell; `os/defaults/` and the rest of `macos.yml` stay
  darwin-only.
- No other OS state managed on Linux.

### 7. Shell experience (`shell/`, `configs/motd/`)

- `.zshenv`, theme, history, completions: already portable (BSD/GNU `stat`
  fallback exists; `BROWSER` is existence-guarded).
- macOS-only aliases/functions (the LINT-05 inventory: `pbcopy`,
  `system_profiler`/`sysctl`/`diskutil` hardware aliases, `open`-based
  functions, `pmset`, `/var/db/.AppleSetupDone`): add `uname`/command
  presence guards or `_dotfiles_require_feature` gates so they are absent,
  not broken, on Linux. `pubkey.zsh` falls back to printing the key when
  `pbcopy` is missing.
- MOTD: `motd.zsh` is portable; add a sibling Linux fastfetch config
  (`configs/motd/motd_sysinfo.linux.jsonc`, macOS-only modules dropped) and
  have `motd.zsh` select the config by `uname` (fastfetch JSONC has no
  conditional syntax).
- `links.yml`: GUI-app config links (VSCode, iTerm, Ghostty, Library/
  Application Support targets) gated darwin; XDG-target links unchanged.

### 8. Claude gating

- New `features.claude = true` in `manifests/defaults.toml`; servers set
  `false`. Root install pipeline gates `claude:install` and
  `claude-addons:install` on it (kebab-case not needed — `claude` is a safe
  key for dot-access, but follow the `index` rule if the final name is
  kebab-case).

### 9. Tooling portability

- Taskfiles' hardcoded `ggrep` calls become a root-level `GREP` template var
  (`ggrep` if present, else `grep`) — the resolver already implements this
  fallback internally; taskfiles adopt the same.
- Lint fixtures updated where rules change (LINT-10 prefix list).

### 10. CI (`.github/workflows/`)

- New workflow on `ubuntu-latest` (native x86_64): run the Linux bootstrap
  steps (non-interactive equivalents for CI), `task setup -- <ci-machine>`
  (a minimal Linux machine manifest checked in for CI), `task install`,
  `task validate`, `task test`, `task lint`, then a second `task install`
  asserting fast no-op (idempotency/status-block check).
- CI needs a consent-gate bypass for automation (env var such as
  `DOTFILES_BOOTSTRAP_ASSUME_YES=1`) — CI-only; interactive remains the
  documented path for real servers.

### 11. Documentation

- `CLAUDE.md`: revise the "Out of Scope — Linux" entry to the new boundary
  (Ubuntu x86_64 headless servers in scope; desktop Linux, apt package
  layer, NixOS, other distros remain out). Update Key Decisions and the
  "Where to Add Things" table (new machine on Linux).
- `docs/MACHINES.md`: server machine runbook (bootstrap, keygen, GitHub key
  registration).

## Error handling

- Resolver cross-field rules fail `task setup` with clear stderr messages
  when a Linux manifest enables darwin-only features (consistent with
  existing rule errors).
- Bootstrap Linux path fails fast (`set -euo pipefail` per repo rule) with
  actionable messages; warns on non-Ubuntu.
- `identity:keygen` never overwrites an existing key.

## Testing

- CI workflow above is the primary regression net.
- Local verification during development: x86_64 Ubuntu container running the
  same sequence.
- Existing tiers extend naturally: resolver fixture tests gain
  linux-manifest fixtures (os enum, new cross-field rules, server identity
  escape); lint fixtures updated.

## Out of scope

- NixOS, non-Ubuntu distros, desktop Linux environments.
- apt as a package manifest layer (apt is bootstrap-prerequisite only).
- 1Password on Linux in any form (including op CLI).
- Claude Code on servers.
- systemd unit/timer/timezone management.
- arm64 Linux (revisit if a real arm64 VM enters scope; linuxbrew arm64 is
  beta-tier).
