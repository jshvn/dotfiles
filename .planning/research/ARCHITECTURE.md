# Architecture Research

**Domain:** Manifest-driven dotfiles (macOS + Linux, go-task + zsh + symlinks)
**Researched:** 2026-05-13
**Confidence:** HIGH for shape and pipeline; MEDIUM for exact TOML schema field names (these are recommended, not industry-standard)

## Standard Architecture

### System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│                          Entry Points                                 │
│   bootstrap.zsh          Taskfile.yml          /etc/zshenv            │
│   (fresh install)        (re-install/update)   (sets ZDOTDIR)         │
└─────────┬─────────────────────────┬──────────────────────────────────┘
          │                         │
          ▼                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Manifest Resolution Layer                         │
│                                                                       │
│  manifests/defaults.toml ──┐                                          │
│                            ├──► resolver.zsh ──► .resolved.json      │
│  manifests/machines/        │   (deep merge,    (machine-local cache)│
│   <name>.toml ─────────────┘    arrays replaced,  read by all tasks  │
│                                 maps merged)      via fromJson)       │
│                                                                       │
│  Identity at setup:                                                   │
│    ${XDG_STATE_HOME}/dotfiles/machine ── single line: "personal-laptop"│
└─────────┬────────────────────────────────────────────────────────────┘
          │  drives
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Task Orchestration Layer                          │
│              taskfiles/ (one yml per concern)                         │
│  manifest.yml  links.yml  packages.yml  identity.yml                 │
│  shell.yml     macos.yml  claude.yml    validate.yml                 │
│                                                                       │
│  Each task: status: check ── reads .resolved.json ── delegates       │
└─────────┬────────────────────────────────────────────────────────────┘
          │  delegates to
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│   Helpers Layer       │   Messages Layer    │  Platform Detection    │
│   taskfiles/          │   install/          │  install/              │
│    helpers.yml        │    messages.zsh     │   platform.zsh         │
│   _:safe-link         │   info/success/warn/│   detects darwin|linux │
│   _:check-*           │   error/check/cross │   sets $PLATFORM       │
└──────────────────────────────────────────────────────────────────────┘
          │  deploys
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                  Asset Layer (Source of Truth)                        │
│                                                                       │
│  shell/  identity/  packages/  configs/  os/  claude/                │
│   (config files, aliases, functions, package bundles)                 │
└─────────┬────────────────────────────────────────────────────────────┘
          │  symlinks → ~/.config/... , ~/.ssh/... , etc.
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      Deployed Symlink Targets                         │
│  $ZDOTDIR  $XDG_CONFIG_HOME  $HOME/.ssh  $HOME/.config/claude        │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Entry layer | One-shot bootstrap; routine `install`/`update`/`validate` | `bootstrap.zsh` + root `Taskfile.yml` |
| Manifest resolver | Read `defaults.toml` + `machines/<name>.toml`, deep-merge, emit canonical JSON cache | A small zsh script using `dasel` or `tomlq` (TOML→JSON), then `jq` for merge |
| Identity binding | Resolve which identity (personal/work/none) the machine uses, expose to git/ssh/zsh | Manifest field → identity file symlinks |
| Task orchestration | Drive install steps in dependency order; each step idempotent | go-task taskfiles, one yml per concern |
| Helpers | Reusable symlink + validation primitives | `taskfiles/helpers.yml` |
| Messages | Consistent colored output across all task contexts | `install/messages.zsh` |
| Platform detection | macOS vs Linux branching | `install/platform.zsh` sets `$PLATFORM` from `uname` |
| Asset layer | Source-of-truth config files, scripts, bundles | `shell/`, `identity/`, `packages/`, `configs/`, `os/`, `claude/` |
| Resolved cache | Machine-local materialized manifest, read by tasks | `${XDG_STATE_HOME}/dotfiles/resolved.json` |

## Recommended Project Structure

```
dotfiles/
├── bootstrap.zsh                 # Fresh-install entry: install go-task, run task setup
├── Taskfile.yml                  # Root: vars, includes, top-level install/update/validate/clean
├── README.md                     # Top-level map + manifest model explanation
│
├── manifests/                    # SOURCE OF TRUTH for what gets installed where
│   ├── README.md                 # Manifest schema + how to add a machine
│   ├── defaults.toml             # Shared baseline; every machine inherits this
│   ├── schema.json               # JSON Schema for manifest validation
│   └── machines/
│       ├── personal-laptop.toml  # One file per machine; explicitly named, no hostname guess
│       ├── work-laptop.toml
│       ├── server-1.toml
│       └── server-2.toml
│
├── taskfiles/                    # go-task orchestration, one yml per concern
│   ├── README.md
│   ├── helpers.yml               # _:safe-link, _:check-link, _:check-dir, _:check-file
│   ├── manifest.yml              # resolve, show, validate-schema
│   ├── shell.yml                 # zsh deploy, glob-load wiring
│   ├── links.yml                 # symlink creation for everything not shell-specific
│   ├── packages.yml              # brew + apt + dnf, driven by manifest.packages.*
│   ├── identity.yml              # git/ssh identity binding from manifest.identity.*
│   ├── macos.yml                 # macOS defaults, gated by manifest.features
│   ├── claude.yml                # Claude install + plugin marketplace
│   └── validate.yml              # Per-component validate; root chains them
│
├── install/                      # Install-time scripts (not deployed)
│   ├── README.md
│   ├── messages.zsh              # info/success/warn/error/check/cross
│   ├── platform.zsh              # uname → $PLATFORM (darwin|linux), $ARCH
│   └── resolver.zsh              # TOML → JSON → deep-merge → write .resolved.json
│
├── shell/                        # All shell config (renamed from zsh/)
│   ├── README.md
│   ├── .zshenv                   # XDG vars, $DOTFILES_MACHINE, $PLATFORM
│   ├── .zprofile                 # brew shellenv, SSH agent (platform-gated)
│   ├── .zshrc                    # plugin manager, glob-load aliases + functions
│   ├── .zlogin                   # MOTD
│   ├── .zlogout                  # history flush
│   ├── theme.zsh
│   ├── aliases/                  # Loaded by .zshrc glob
│   │   ├── common/               # Always loaded
│   │   │   ├── README.md
│   │   │   ├── git.zsh           # One topic per file
│   │   │   └── files.zsh
│   │   ├── darwin/               # Loaded only when $PLATFORM == darwin
│   │   │   ├── README.md
│   │   │   ├── hardware.zsh      # macOS-only hardware aliases
│   │   │   └── networking.zsh    # macOS-only networking aliases
│   │   └── linux/                # Loaded only when $PLATFORM == linux
│   │       ├── README.md
│   │       └── systemd.zsh
│   └── functions/                # One function per file
│       ├── common/
│       │   ├── README.md
│       │   ├── mkcd.zsh
│       │   └── prettyjson.zsh
│       ├── darwin/
│       └── linux/
│
├── identity/                     # Identity binding (replaces git/config-<profile> suffixing)
│   ├── README.md
│   ├── git/
│   │   ├── config                # Base config with includeIf hooks
│   │   ├── ignore                # Global gitignore
│   │   └── identities/
│   │       ├── personal          # email, signingkey, etc — per identity, not per machine
│   │       └── work
│   ├── ssh/
│   │   ├── config                # Base config with conditional Includes
│   │   ├── identities/
│   │   │   ├── personal          # Host entries, control sockets
│   │   │   └── work
│   │   ├── agent/
│   │   │   └── 1password.toml    # Only included when manifest.features.one-password-ssh
│   │   └── keys/                 # Public keys only (id_ed25519_personal.pub, etc.)
│   └── README.md
│
├── packages/                     # Package bundles (replaces install/Brewfile-*.rb)
│   ├── README.md
│   ├── brew/
│   │   ├── core.rb               # Always installed on macOS
│   │   ├── gui.rb                # casks for laptops with GUI
│   │   ├── dev.rb                # developer tooling bundle
│   │   ├── ops.rb                # ops/server tools
│   │   └── personal.rb           # personal-machine apps (1Password, etc.)
│   ├── apt/                      # Debian/Ubuntu
│   │   ├── core.list             # Always installed on Linux servers
│   │   ├── dev.list
│   │   └── ops.list
│   └── dnf/                      # Fedora
│       ├── core.list
│       └── ops.list
│
├── configs/                      # Tool configs (renamed from zsh/configs + zsh/styles)
│   ├── README.md
│   ├── ghostty/
│   ├── glow/
│   ├── trippy/
│   ├── tlrc/
│   ├── conda/
│   ├── eza/                      # Was zsh/styles/eza_style.yaml
│   └── motd/
│
├── os/                           # OS-level system configuration (replaces macos.yml inline)
│   ├── README.md
│   ├── darwin/
│   │   ├── defaults/             # One file per defaults group; manifest features gate them
│   │   │   ├── README.md
│   │   │   ├── dock.zsh
│   │   │   ├── finder.zsh
│   │   │   ├── input.zsh         # Trackpad, keyboard
│   │   │   ├── screenshots.zsh
│   │   │   └── security.zsh
│   │   └── shell-registration.zsh # Add zsh to /etc/shells, chsh
│   └── linux/
│       ├── sysctl/               # Future: server sysctl tunables
│       └── systemd/              # Future: user systemd units
│
├── claude/                       # Claude Code config
│   ├── README.md
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── hooks/
│   │   ├── README.md
│   │   ├── hooks.json
│   │   ├── secret-scan.zsh
│   │   ├── no-emojis.zsh
│   │   ├── no-ai-comments.zsh
│   │   └── agent-transparency.zsh
│   ├── agents/
│   ├── commands/
│   └── skills/
│
├── docs/
│   ├── MIGRATION.md              # v1 → v2 cutover plan and mapping
│   └── MANIFEST.md               # Deep dive on schema + inheritance rules
│
├── .claude/                      # Project-level Claude config (this repo)
│   └── CLAUDE.md
│
├── .planning/                    # GSD planning (already exists)
└── .gitignore
```

### Structure Rationale

- **`manifests/` at top level:** Manifests are *the* source of truth for install state. They deserve their own directory at the same level as `shell/` and `packages/`, not buried under `install/` or `taskfiles/`. The directory makes the new mental model obvious: "look here to see what each machine is."

- **`shell/` over `zsh/`:** Renaming signals that the directory holds shell config in general, not just zsh's. If a future profile ever needs bash compatibility for a CI runner, it lives here. Avoids the "zsh-only" connotation that confused readers of the v1 repo.

- **Platform subdirectories (`common/`, `darwin/`, `linux/`) replace profile subdirectories:** This is the biggest structural shift. Profile (`personal/work/server`) was conflating two orthogonal dimensions — *who the human is* (identity) and *what the machine is* (platform). Splitting them means:
  - Aliases that depend on `pbcopy` or `sw_vers` go in `darwin/` (was wrongly in `common/`)
  - Aliases that depend on `systemctl` go in `linux/`
  - Identity-specific aliases (a `jgrid.zsh` for the user's personal email scripts) go in a machine-local file referenced by the manifest, not in `aliases/personal/`

- **`identity/` separates from `shell/`:** Git and SSH identity are about *who*, not *what shell*. Grouping them sidesteps the v1 confusion where `git/config-server` was really "config for the machine that has no personal identity," not a real third identity.

- **`packages/brew/<bundle>.rb`:** Bundles are named by *purpose* (`core`, `gui`, `dev`, `ops`, `personal`), not by machine. The manifest decides which bundles to compose. Adding a new machine never requires a new bundle file — it's a list of bundle names in TOML.

- **`packages/apt/` and `packages/dnf/`:** First-class Linux support means real package manifests for both major server distros, not afterthoughts. Format is a simple newline-delimited list (`.list`); `apt install $(cat core.list dev.list)` is the install command, simpler than Brewfile DSL.

- **`os/darwin/defaults/` one file per group:** Replaces the v1 `taskfiles/macos.yml` monolithic defaults block. Each file is opt-in via a manifest feature flag. Adding a new defaults group is a new file plus a feature key in `defaults.toml`.

- **`configs/<tool>/`:** Each tool gets a directory, not a loose file. Even if the tool has only one config, the directory holds room for a README. Mirrors the "every directory teaches itself" principle.

- **README per top-level directory:** Each README covers (1) purpose, (2) one-line "how it integrates with the manifest," (3) "how to add a new X" recipe. Keeps add-a-thing decisions reachable without grepping the whole repo.

- **`install/` reduced to install-time scripts:** No longer holds Brewfiles (those moved to `packages/`). Just `messages.zsh`, `platform.zsh`, and `resolver.zsh`. Smaller, single-concern.

## Manifest Schema

### `manifests/defaults.toml` (sketch)

```toml
# Inherited by every machine. Machine manifests override any key.
schema_version = 1

[platform]
# Acceptable: "darwin" | "linux". A machine MUST set this; defaults provides no fallback.
# Listing here documents the field for the schema validator only.

[features]
# Opt-in feature flags. Each is consumed by exactly one task/asset:
#   one-password-ssh   → ssh/agent/1password.toml is included
#   macos-dock         → os/darwin/defaults/dock.zsh runs
#   macos-finder       → os/darwin/defaults/finder.zsh runs
#   macos-input        → os/darwin/defaults/input.zsh runs
#   macos-screenshots  → os/darwin/defaults/screenshots.zsh runs
#   macos-security     → os/darwin/defaults/security.zsh runs
#   claude-marketplace → claude.yml installs marketplace plugins
#   motd               → .zlogin sources motd
one-password-ssh = false
motd = true
claude-marketplace = true

[shell]
# Plugin manager choice (antigen is heavy; we may switch).
plugin_manager = "antigen"
theme = "alanpeabody"

[packages.brew]
# Default Brewfile bundles applied on darwin. Machine manifest may extend or override.
bundles = ["core"]
extra_packages = []   # ad-hoc additions without forking a bundle

[packages.apt]
bundles = ["core"]
extra_packages = []

[packages.dnf]
bundles = ["core"]
extra_packages = []

[identity]
# Each machine MUST set git identity; defaults provides shape only.
git = "none"   # one of: "personal" | "work" | "none"
ssh = "none"   # one of: "personal" | "work" | "none"
```

### `manifests/machines/personal-laptop.toml` (sketch)

```toml
schema_version = 1

[meta]
# Free-text; surfaces in `task manifest:show` and validate output.
description = "Josh's personal MacBook"
notes = "Apple Silicon. Primary dev machine."

[platform]
os = "darwin"
arch = "arm64"

[features]
# Overrides defaults; deep-merged (per-key replace).
one-password-ssh = true
macos-dock = true
macos-finder = true
macos-input = true
macos-screenshots = true
macos-security = true
motd = true
claude-marketplace = true

[packages.brew]
# Arrays REPLACE rather than merge (per chezmoi's data model — predictable).
bundles = ["core", "gui", "dev", "personal"]
extra_packages = ["docker-desktop"]

[identity]
git = "personal"
ssh = "personal"

[git]
# Resolved into the personal identity file via the resolver.
email = "josh@personal.example"
signingkey = "ABCDEF1234567890"

# No [packages.apt] block — N/A on darwin. Resolver ignores irrelevant blocks.
```

### `manifests/machines/server-1.toml` (sketch)

```toml
schema_version = 1

[meta]
description = "Home homelab Debian 12 server"

[platform]
os = "linux"
arch = "amd64"
distro = "debian"   # informs which package manager to drive

[features]
one-password-ssh = false   # servers use system ssh-agent
motd = true
claude-marketplace = false # servers don't run Claude Code

[packages.apt]
bundles = ["core", "ops"]
extra_packages = ["tailscale"]

[identity]
git = "none"
ssh = "none"
```

### Inheritance and Override Semantics

Inheritance follows chezmoi's well-tested model:

1. **Maps (tables) are deep-merged** key-by-key.
2. **Scalars (strings, numbers, bools) are replaced** by the machine value.
3. **Arrays are REPLACED, not concatenated.** This is critical: a machine that wants `core` only must not be silently extended by defaults' `["core", "dev"]`. To extend, use `extra_packages` (additive) versus `bundles` (replacing).
4. **`extra_packages` is concatenated** (defaults + machine, deduplicated) so users have an explicit additive escape hatch without losing the array-replace clarity for bundles.

Source: [chezmoi data model](https://www.chezmoi.io/reference/special-directories/chezmoidata/) — "Values in `.chezmoidata` files are merged based on lexical file sorting, and only dictionaries are merged; all other values (particularly lists) are replaced."

## Architectural Patterns

### Pattern 1: Manifest as Compile-Time Input, Resolved JSON as Runtime Input

**What:** TOML manifests are *authored* in TOML for human ergonomics. They are *consumed* as JSON by tasks because go-task templating speaks JSON natively (via `fromJson`) and not TOML.

**When to use:** Any orchestration tool that supports JSON better than TOML. Translating once at task-init time avoids re-parsing TOML in every task.

**Trade-offs:** Adds a "resolved cache" file that must be regenerated when manifests change. Mitigated by making `task manifest:resolve` cheap (~50ms) and a dependency of every other task.

**Implementation sketch:**
```zsh
# install/resolver.zsh
DEFAULTS=$(dasel -f manifests/defaults.toml -r toml -w json)
MACHINE=$(dasel -f "manifests/machines/${1}.toml" -r toml -w json)
echo "$DEFAULTS" "$MACHINE" \
  | jq -s '.[0] * .[1]' \
  > "${XDG_STATE_HOME}/dotfiles/resolved.json"
```
```yaml
# taskfiles/manifest.yml
vars:
  MANIFEST:
    sh: cat ${XDG_STATE_HOME}/dotfiles/resolved.json
  M:
    ref: 'fromJson .MANIFEST'

tasks:
  show:
    cmds:
      - jq . ${XDG_STATE_HOME}/dotfiles/resolved.json
```

Sources: [go-task fromJson templating](https://taskfile.dev/docs/guide), [dasel TOML→JSON](https://github.com/tomwright/dasel).

### Pattern 2: Feature Flag → File-Existence Routing

**What:** Each feature flag in the manifest controls *exactly one* asset file or task. The task checks the flag and decides whether to include/run.

**When to use:** When opt-in behavior matters (e.g., 1Password SSH agent, individual macOS defaults groups).

**Trade-offs:** Adds boilerplate (a feature flag per opt-in concern). Avoids inline `if`s scattered across configs and tasks.

**Example:**
```yaml
# taskfiles/macos.yml
defaults-dock:
  status:
    - test "{{.M.features.macos-dock}}" = "true" && exit 1 || exit 0
  cmds:
    - "{{.DOTFILES_MESSAGES}}; zsh os/darwin/defaults/dock.zsh"
```

This collapses three previous concerns: the v1 `taskfiles/macos.yml` monolith, the inline `$DOTFILES_PROFILE == server` shell branches, and the implicit "skip on linux" via task availability.

### Pattern 3: Identity Indirection via Symlink

**What:** `~/.config/git/identity` is a symlink chosen at install time pointing to `identity/git/identities/<chosen>`. The base `git/config` does `includeIf gitdir → ~/.config/git/identity-personal` etc., but the *identity selection* is made by the manifest, not by directory paths.

**When to use:** When identity is owned by the machine, not the working directory.

**Trade-offs:** Slightly more files than inlining email in the manifest. Bigger win: identities are first-class, reusable across machines (server-1 and server-2 can share `identity/git/identities/personal` without duplicating).

**Implementation:**
```yaml
# taskfiles/identity.yml
git-identity:
  status:
    - test -L ${HOME}/.config/git/active-identity
  cmds:
    - "{{.DOTFILES_MESSAGES}}"
    - |
      IDENTITY="{{.M.identity.git}}"
      if [[ $IDENTITY != "none" ]]; then
        task _:safe-link SOURCE="${DOTFILEDIR}/identity/git/identities/${IDENTITY}" \
                         TARGET="${HOME}/.config/git/active-identity"
      fi
```

### Pattern 4: Per-Component Validate That Composes

**What:** Every taskfile owns a `validate` task that prints per-item check/cross. Root `task validate` simply chains them.

**When to use:** Always. This is what makes "feature parity" objectively assessable.

**Example output:**
```
=== Manifest ===
  ✓ manifests/defaults.toml exists
  ✓ manifests/machines/personal-laptop.toml exists
  ✓ resolver: produced resolved.json
  ✓ schema: defaults.toml validates
  ✓ schema: personal-laptop.toml validates

=== Shell ===
  ✓ /etc/zshenv configures ZDOTDIR
  ✓ $ZDOTDIR/.zshenv linked
  ✓ aliases/common/ globs (3 files)
  ✓ aliases/darwin/ globs (2 files)

=== Packages ===
  ✓ brew installed
  ✓ Brewfile bundle: core (42 packages)
  ✓ Brewfile bundle: gui (18 casks)
  ✗ Brewfile bundle: dev (missing: gh, jq)
```

The shape (one validate per concern, root chains them) is already in v1 — port verbatim.

## Data Flow

### Setup Flow (fresh install)

```
User: ./bootstrap.zsh
  ↓
bootstrap.zsh: resolve DOTFILEDIR, install go-task
  ↓
Run: task setup -- <machine-name>
  ↓
1. validate machine file exists at manifests/machines/<name>.toml
2. write ${XDG_STATE_HOME}/dotfiles/machine = <name>
3. resolver.zsh: defaults.toml + machines/<name>.toml → resolved.json
4. task manifest:validate (schema check)
5. task install (full install using resolved.json)
```

### Install Flow

```
task install
  ↓
manifest:ensure → reads ${XDG_STATE_HOME}/dotfiles/machine, regenerates resolved.json if stale
  ↓
For each component (in dependency order):
   common: → XDG dirs, /etc/zshenv ZDOTDIR
   shell:  → symlink shell/ assets, glob-load wiring
   identity: → symlink identity/git, identity/ssh, set active-identity
   packages: → invoke brew/apt/dnf with bundles from manifest.packages.<pm>.bundles
   os:     → run os/<platform>/defaults/<group>.zsh for each enabled feature
   claude: → install Claude Code, marketplace plugins (if features.claude-marketplace)
   links:  → all other tool config symlinks (configs/*)
   ↓
task validate  (final per-component health check)
```

### Shell Startup Flow

```
/etc/zshenv → sets ZDOTDIR
  ↓
$ZDOTDIR/.zshenv → XDG vars, $DOTFILES_MACHINE (from state file),
                   $PLATFORM (uname)
  ↓ (login shells only)
$ZDOTDIR/.zprofile → brew shellenv, SSH_AUTH_SOCK (only if features.one-password-ssh)
  ↓ (interactive shells only)
$ZDOTDIR/.zshrc:
  1. plugin manager
  2. glob shell/aliases/common/*.zsh
  3. glob shell/aliases/${PLATFORM}/*.zsh        ← was aliases/${DOTFILES_PROFILE}/
  4. glob shell/functions/common/*.zsh
  5. glob shell/functions/${PLATFORM}/*.zsh
  6. source theme.zsh
  ↓ (login shells only)
.zlogin → motd (if features.motd)
```

### Identity Resolution at Runtime

```
git command in any repo
  ↓
~/.config/git/config (symlink to identity/git/config)
  ↓
includeIf "gitdir:~/Git/personal/" → personal identity file
includeIf "gitdir:~/Git/work/"     → work identity file
  ↓ (or, simpler:)
unconditional include ~/.config/git/active-identity
  (which the install symlinks to the manifest-selected identity)
```

The choice between `includeIf gitdir:` and `active-identity` symlink is per-machine: laptops use `gitdir:` to switch by project location, servers use `active-identity` for the single identity.

## Build Order

What unblocks what:

1. **Manifest layer first.** `manifests/defaults.toml`, `manifests/machines/*.toml`, `install/resolver.zsh`, schema, `task manifest:resolve` / `validate` / `show`. **Nothing else can be built without the resolved JSON to consume.**

2. **Platform detection.** `install/platform.zsh`, `$PLATFORM` in `.zshenv`. Required by every subsequent component that branches OS.

3. **Helpers + Messages port.** `taskfiles/helpers.yml`, `install/messages.zsh`. Stable from v1; port mostly verbatim.

4. **Shell skeleton.** `.zshenv`, `.zprofile`, `.zshrc` glob loading from `shell/aliases/{common,darwin,linux}` and `shell/functions/{common,darwin,linux}`. Port aliases and functions from v1 with `common` → split into `common` + `darwin`-correct buckets.

5. **Identity layer.** `identity/git/`, `identity/ssh/`, `taskfiles/identity.yml`. Manifest field drives selection.

6. **Packages layer.** `packages/brew/`, `packages/apt/`, `packages/dnf/`, `taskfiles/packages.yml`. Read bundle names from manifest, compose.

7. **OS layer.** `os/darwin/defaults/*`, `taskfiles/macos.yml`. Each defaults group gated by a feature flag. (Fix the `$BREW_ZSH` vs `{{.BREW_ZSH}}` v1 bug here.)

8. **Configs layer.** `configs/<tool>/` symlinks via `taskfiles/links.yml`.

9. **Claude layer.** `claude/`, `taskfiles/claude.yml`. Fix the `gsd-install` re-run bug from v1 with a real `status:` check.

10. **Validate composition.** Per-component validate already accumulating in each yml; root `task validate` chains.

11. **Bootstrap.** `bootstrap.zsh` with `set -euo pipefail` and go-task verified by checksum.

12. **Migration docs.** `docs/MIGRATION.md` — v1→v2 mapping, cutover sequence.

13. **Per-machine cutover.** One machine at a time. Validate parity, archive v1 only after all four pass.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-5 machines | Current proposal is fine. Manifest-per-machine is sustainable. |
| 5-15 machines | Consider introducing a `manifests/profiles/` layer between defaults and machines (e.g., `profiles/laptop.toml`, `profiles/server.toml`) that machines reference. Resolver merges in three stages. |
| 15+ machines | Reach for chezmoi or Ansible. At this scale, hand-rolled is no longer winning. |

### Scaling Priorities

1. **First bottleneck: duplication across machines.** When two machines share 80% of their manifest, copy-paste is irritating. Mitigation is the `profiles/` intermediate layer — *not* the v1 tag/composition pattern we explicitly rejected, just one more inheritance step.

2. **Second bottleneck: shell startup time.** Antigen + synchronous MOTD push v1 cold start to ~500ms. Mitigation: replace antigen with a leaner manager (zinit, znap, or pure zsh autoload), defer MOTD to a background process, lazy-load functions. Target <200ms cold.

3. **Third bottleneck: package list drift.** When Brewfile bundles get long, surveying "what's installed and why" gets hard. Mitigation: a `task packages:audit` that diffs `brew list` vs the union of active bundles.

## Anti-Patterns

### Anti-Pattern 1: Hostname Detection Anywhere

**What people do:** Read `$(hostname)` or `$(uname -n)` and branch on the result.

**Why it's wrong:** Hostnames change. The v1 repo has a documented bug where `.zprofile` checks `if hostname == "server"`, which silently breaks on any machine whose hostname contains "server" or any server with a different hostname.

**Do this instead:** Always read from the manifest. `$DOTFILES_MACHINE` is set explicitly at setup time and exported by `.zshenv`. Identity, features, and platform all come from the manifest, never from inference.

### Anti-Pattern 2: Inline Profile/Platform Branching in Shared Files

**What people do:** Add `if [[ $PLATFORM == darwin ]]` inside `shell/.zshrc` or `identity/git/config`.

**Why it's wrong:** It hides what runs where. An AI agent reading `.zshrc` can't tell which lines fire on a server without tracing the conditional.

**Do this instead:** Use the directory taxonomy. macOS-only aliases go to `shell/aliases/darwin/`. macOS-only features go in `os/darwin/`. The directory name *is* the conditional.

### Anti-Pattern 3: Re-Parsing TOML in Every Task

**What people do:** Call `dasel` (or `tomlq`) inside every task's `cmds:` block to read the manifest.

**Why it's wrong:** Slow (dasel adds ~30ms per invocation; multiplied across 30+ tasks adds up). Also brittle — `dasel` becomes a hard bootstrap dependency before `task install` can even run.

**Do this instead:** Resolve once at `manifest:resolve`, write `resolved.json`, and load it via go-task's native `fromJson` template function. The cache file is regenerated when manifests change (mtime check).

### Anti-Pattern 4: Encoding Identity in File Suffixes

**What people do:** `Brewfile-personal.rb`, `git/config-personal`, `ssh/config-personal`, `aliases/personal/`. The v1 repo's structural mistake.

**Why it's wrong:** Three different concerns get fused (who you are, what platform, what tools). When a server needs no identity but does need a tool that the personal Brewfile had, the only escape is duplication.

**Do this instead:** Identity → `identity/<tool>/identities/<name>` referenced by manifest. Platform → directory. Tool bundles → named by purpose (`core`, `gui`, `dev`, `ops`), composed by manifest.

### Anti-Pattern 5: Tasks Without `status:` Checks

**What people do:** Tasks always run, even when nothing has changed.

**Why it's wrong:** v1 has two known offenders (`gsd-install` and `macos:shell`). They make `task install` slow and non-idempotent.

**Do this instead:** Every install task has a `status:` block. The block returns non-zero (task runs) or zero (task skipped). For "is this symlink present?" use `test -L`. For "is this brew bundle satisfied?" use `brew bundle check --file=<bundle>`.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Homebrew (macOS, Linux) | Brewfile per bundle; `brew bundle --file=<bundle>` composed by manifest | Detect prefix by architecture; never hardcode |
| apt (Debian/Ubuntu) | `apt install $(cat packages/apt/<bundle>.list)` | Idempotent; `dpkg -s` checks for status |
| dnf (Fedora) | `dnf install $(cat packages/dnf/<bundle>.list)` | Same pattern as apt |
| Claude Code | `claude marketplace add` + `claude plugin install` per skill | `status:` must check `claude plugin list` output, not just installation marker |
| 1Password CLI | SSH agent socket via `op` env vars | Gated by `features.one-password-ssh` |
| go-task | YAML taskfiles; `fromJson` for manifest data | Install via Homebrew or checksum-verified binary |
| dasel | TOML→JSON conversion at resolve time | One-time at `manifest:resolve`, not per-task |
| jq | Deep merge of defaults + machine; query in shell | Already a v1 dependency |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Manifests ↔ Tasks | Via `resolved.json` cache | Tasks never read TOML directly; resolver is the only TOML reader |
| Tasks ↔ Assets | Symlinks created by `taskfiles/links.yml` and `taskfiles/identity.yml` | Asset files have no knowledge of the manifest |
| Shell ↔ Manifest | Via `$DOTFILES_MACHINE` + `$PLATFORM` env vars from `.zshenv` | Shell doesn't parse JSON at startup; just consumes pre-set env vars |
| Identity ↔ Git/SSH | Via active-identity symlink or `includeIf gitdir` | Two equally valid strategies; choose per machine |
| Hooks ↔ Settings | `claude/hooks/hooks.json` registers; `settings.json` references | Hooks should `set -euo pipefail`, not just `set -e` |
| Validate ↔ Components | Each component owns its `validate`; root chains | No central validate registry; discoverable by directory |

## Comparison to Known Mature Repos

| Repo / Tool | Pattern | Our Lift | Our Reject |
|-------------|---------|----------|------------|
| chezmoi | Per-machine `~/.config/chezmoi/chezmoi.toml` + `.chezmoidata` + templates | Per-machine TOML; deep-merge semantics (maps merge, lists replace) | Template-based file rewriting (we use symlinks for legibility) |
| Homemaker | Single TOML with `[tasks]`, `[macros]`, variant decorators | TOML-driven action list; macro-like reuse | Variant-decorated keys (`task__ubuntu`) — too implicit |
| holman/dotfiles | Topic-centric (`git/`, `ruby/`, etc.) with `.zsh` and `.symlink` extensions | Topic directories (`identity/git/`, `shell/`, `configs/<tool>/`) | Convention-based filename extensions (less explicit than manifests) |
| Mathias Bynens | Single sourced `~/.macos` defaults script | Per-feature defaults file (`os/darwin/defaults/dock.zsh`) | Monolithic defaults script (v1's macos.yml pain) |
| drduh/macOS | Documented hardening guide, opinionated defaults | Opt-in feature flags for each defaults group | Manual install steps (we want everything `task install`-able) |
| rcm | Tags as directories prefixed `tag-`; multiple DOTFILES_DIRS | Tag-like composition for bundles | Hooks via filename prefix (we use task `status:` blocks) |
| GNU Stow | Directory structure mirrors home directory; symlinks by package | Symlink-based deploy | Mirror-home tree (forces a specific layout that doesn't fit XDG well) |

Sources: [chezmoi data model](https://www.chezmoi.io/reference/special-directories/chezmoidata/), [Homemaker manifest examples](https://github.com/FooSoft/homemaker), [Holman's topical organization](https://github.com/holman/dotfiles), [rcm tag pattern](https://thoughtbot.github.io/rcm/rcm.7.html).

## Sources

- [chezmoi: Manage machine-to-machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/) — HIGH confidence; canonical source for manifest inheritance semantics
- [chezmoi: .chezmoidata reference](https://www.chezmoi.io/reference/special-directories/chezmoidata/) — HIGH confidence; "maps merge, lists replace" rule
- [chezmoi: Configuration file](https://www.chezmoi.io/reference/configuration-file/) — HIGH confidence; per-machine config-file pattern
- [Homemaker (FooSoft)](https://github.com/FooSoft/homemaker) — HIGH confidence; TOML-driven task/macro/dep model
- [Holman dotfiles](https://github.com/holman/dotfiles) — MEDIUM confidence; well-known topic-centric layout
- [Homebrew Bundle documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) — HIGH confidence; multi-Brewfile patterns and HOMEBREW_BUNDLE_FILE
- [Homebrew Bundle issue #158: directory of Brewfiles](https://github.com/Homebrew/homebrew-bundle/issues/158) — MEDIUM confidence; confirms native include is not supported, workarounds documented
- [go-task guide](https://taskfile.dev/docs/guide) — HIGH confidence; templating with `fromJson` (note: no native TOML support)
- [go-task issue #978: platform/arch keys](https://github.com/go-task/task/issues/978) — MEDIUM confidence; native platform branching in tasks
- [dasel: query/transform JSON/YAML/TOML](https://github.com/tomwright/dasel) — HIGH confidence; TOML→JSON conversion path
- [yq / tomlq](https://kislyuk.github.io/yq/) — HIGH confidence; alternate TOML parser
- [rcm man page](https://thoughtbot.github.io/rcm/rcm.7.html) — MEDIUM confidence; tag-based composition pattern
- [Mathias Bynens .macos](https://github.com/mathiasbynens/dotfiles) — HIGH confidence; canonical macOS defaults script (we reject the monolith pattern)
- [JSON Schema validation for TOML](https://github.com/toml-lang/toml/discussions/1038) — MEDIUM confidence; validation path for `manifests/schema.json`
- v1 codebase audit at `.planning/codebase/` — HIGH confidence; current-state architecture and known bugs

---
*Architecture research for: manifest-driven dotfiles*
*Researched: 2026-05-13*
