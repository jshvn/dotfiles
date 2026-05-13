# Requirements: Dotfiles v2 Refactor

**Defined:** 2026-05-13
**Core Value:** A single declarative manifest per machine makes the complete install state legible to both humans and AI agents.

## v1 Requirements

Requirements for the v2.0 cutover gate. Each maps to a roadmap phase. All requirements are hypotheses until shipped and validated on every target machine.

### Manifest

Schema, parsing, merge semantics. Keystone layer — every other phase reads `resolved.json`.

- [ ] **MFST-01**: `manifests/defaults.toml` defines shared baseline (identity, platform-agnostic features, default package bundles)
- [ ] **MFST-02**: `manifests/machines/<name>.toml` declares per-machine identity, platform, features, package bundles, and any overrides
- [ ] **MFST-03**: Machine manifest can override any `defaults.toml` key with documented merge semantics (maps deep-merge, scalars/arrays replace, `extra_packages` concatenates)
- [ ] **MFST-04**: `install/resolver.zsh` compiles defaults + machine manifest into `$XDG_STATE_HOME/dotfiles/resolved.json` using yq for TOML-to-JSON and a correct deep-merge expression
- [ ] **MFST-05**: Test fixtures cover all merge cases (map-over-map, list-replace, scalar-override, nested table, missing key) and are run by `task manifest:test`
- [ ] **MFST-06**: `task manifest:resolve` produces `resolved.json`; downstream tasks consume it via go-task `fromJson` and never read TOML directly
- [ ] **MFST-07**: `task manifest:show` prints the post-merge structure for debugging
- [ ] **MFST-08**: `task manifest:validate` enforces required schema fields (description, identity, platform, features at minimum)
- [ ] **MFST-09**: Adding a new machine is a single new file in `manifests/machines/` plus `task setup -- <name>`

### Bootstrap

Fresh-install entry point with hardened supply chain.

- [ ] **BTSP-01**: `bootstrap.zsh` uses `set -euo pipefail` (not `set -e`); pipefail catches install-script failures
- [ ] **BTSP-02**: Bootstrap installs go-task via Homebrew on macOS (no curl-pipe-to-shell)
- [ ] **BTSP-03**: Bootstrap installs go-task on Linux via SHA256-verified binary download (checksum committed in repo)
- [ ] **BTSP-04**: Bootstrap installs yq before invoking the resolver (Linux pre-Homebrew sequencing handled explicitly)
- [ ] **BTSP-05**: Bootstrap is resumable — every step has a guard against re-running
- [ ] **BTSP-06**: `task setup -- <machine-name>` persists explicit machine selection to `$XDG_STATE_HOME/dotfiles/machine`; no hostname inference
- [ ] **BTSP-07**: `docs/SECURITY.md` documents the bootstrap trust chain (what is downloaded, from where, how verified)

### Install Engine

Idempotency, lint suite, validation foundation. Built before shell content is ported.

- [ ] **LINT-01**: Every install task has a `status:` block that makes re-runs a no-op (local-only conditions; no network dependencies)
- [ ] **LINT-02**: `task lint:taskfile` flags `$VAR` references inside `status:` blocks (fixes `macos:shell` class of bug)
- [ ] **LINT-03**: `task lint:taskfile` flags bare `ln -s` outside `helpers.yml` and flags tasks with `cmds:` but no `status:`
- [ ] **LINT-04**: `task lint:shell-headers` flags executable `.zsh` files missing `set -euo pipefail`
- [ ] **LINT-05**: `task lint:platform` flags known macOS-only commands (`pbcopy`, `osascript`, `defaults`, `mDNSResponder`, `system_profiler`, `diskutil`) in `common/` directories
- [ ] **LINT-06**: Root `task lint` aggregates all lint subtasks
- [ ] **LINT-07**: `zsh -n` runs over every `.zsh` file as Tier-0 syntax test (catches `local`-at-script-scope class of bug)
- [ ] **LINT-08**: `task install` re-run on a converged machine completes in under 5 seconds (idempotency timing test)

### Shell

zsh startup chain with platform-aware directory layout and content port.

- [ ] **SHEL-01**: `shell/.zshenv` exports XDG vars, `$DOTFILES_MACHINE` (from state file), and `$PLATFORM` (from `uname`); no `$DOTFILES_PROFILE`
- [ ] **SHEL-02**: `shell/.zprofile` sets Homebrew shellenv (guarded by `[[ -x "$BREW" ]]`) and SSH agent socket only when manifest declares the feature
- [ ] **SHEL-03**: `shell/.zshrc` glob-loads `aliases/common/`, `aliases/$PLATFORM/`, `functions/common/`, `functions/$PLATFORM/` (interactive only)
- [ ] **SHEL-04**: Antidote replaces Antigen as the plugin manager (static bundle file)
- [ ] **SHEL-05**: Starship replaces Powerlevel10k (`configs/starship/starship.toml`)
- [ ] **SHEL-06**: One alias topic per file in `aliases/{common,darwin,linux}/<topic>.zsh`
- [ ] **SHEL-07**: One function per file in `functions/{common,darwin,linux}/<name>.zsh`
- [ ] **SHEL-08**: All v1 aliases ported to correct platform bucket; `task lint:platform` passes on every file
- [ ] **SHEL-09**: All v1 functions ported; each file passes `zsh -n`
- [ ] **SHEL-10**: compinit uses a daily-rebuilt cache rather than running per shell startup
- [ ] **SHEL-11**: MOTD output is cached to disk with 24-hour TTL (async refresh)
- [ ] **SHEL-12**: Cold interactive shell startup under 200ms (measured by `task perf:shell`; fails CI if exceeded)

### Identity

git and SSH identity, manifest-driven.

- [ ] **IDNT-01**: `identity/git/config` uses `includeIf` for path-based identity selection
- [ ] **IDNT-02**: Per-identity git configs live under `identity/git/identities/<identity-name>` (no profile-suffix filenames)
- [ ] **IDNT-03**: `identity/ssh/config` uses `Include` directives for identity-based host configs
- [ ] **IDNT-04**: Per-identity SSH host configs live under `identity/ssh/identities/<identity-name>`
- [ ] **IDNT-05**: 1Password SSH agent integration enabled only when manifest declares `one-password-ssh = true`; no hostname literals anywhere in the identity path
- [ ] **IDNT-06**: Public SSH keys committed under `identity/ssh/keys/`; private keys never committed
- [ ] **IDNT-07**: `task validate` asserts `git config user.email` matches manifest identity and `ssh-add -L` lists the expected key
- [ ] **IDNT-08**: `taskfiles/identity.yml` reads identity from `resolved.json` and creates the appropriate symlinks via `_:safe-link`

### Packages

Cross-platform package management driven by manifest bundles.

- [ ] **PKGS-01**: Per-purpose Brewfile bundles in `packages/brew/<purpose>.rb` (core, gui, dev, ops, personal) — named by role, not by profile
- [ ] **PKGS-02**: Brewfile bundles use `if OS.mac?` / `if OS.linux?` guards (Homebrew 5.1+ cross-platform)
- [ ] **PKGS-03**: Linux package manifests in `packages/apt/<bundle>.list` and `packages/dnf/<bundle>.list` are first-class (not stripped subsets of macOS)
- [ ] **PKGS-04**: `taskfiles/packages.yml` reads `packages.brew.bundles` and `packages.<pm>.bundles` from `resolved.json` and composes the per-machine package set
- [ ] **PKGS-05**: `brew bundle` task uses a `status:` check based on `brew bundle check --file=<composed>` (replaces unconditional re-run)
- [ ] **PKGS-06**: Linux package install has an idempotency check (per-package `dpkg -s` or `rpm -q`, or a sentinel file written after successful bundle install)
- [ ] **PKGS-07**: Manifest can declare per-machine `extra_packages` (additive, concatenates with bundle contents)

### OS Defaults

macOS defaults feature-flag-gated; no-op on Linux.

- [ ] **OSCF-01**: macOS defaults split into per-concern files (`os/darwin/defaults/dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh`)
- [ ] **OSCF-02**: Each defaults group is gated by a manifest feature flag — opt-in per machine
- [ ] **OSCF-03**: Every defaults task has a `status:` that reads `defaults read <domain> <key>` before writing (replaces re-running on every install)
- [ ] **OSCF-04**: `os/darwin/shell-registration.zsh` adds Homebrew zsh to `/etc/shells` and runs `chsh` with a correct `{{.BREW_ZSH}}` template-var `status:` check (fixes the live v1 bug)
- [ ] **OSCF-05**: All macOS defaults tasks are no-ops on Linux (platform check at task level)
- [ ] **OSCF-06**: `task validate` asserts current defaults values match manifest expectations for the active machine

### Claude

Claude Code integration with bug fixes for known v1 issues.

- [ ] **CLDE-01**: Global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills installed via `taskfiles/claude.yml`
- [ ] **CLDE-02**: All hooks ported and shellcheck-clean: `secret-scan.zsh`, `no-emojis.zsh`, `no-ai-comments.zsh`, `agent-transparency.zsh` (last one rewritten to remove `local` at script scope)
- [ ] **CLDE-03**: GSD install task uses a version-pinned sentinel file as its `status:` check (no `npx` on every `task install`)
- [ ] **CLDE-04**: Marketplace install uses `claude plugin list` as its `status:` check

### Tool Configs

Per-tool configuration deployment via symlinks.

- [ ] **TOOL-01**: Tool configs deployed via `taskfiles/links.yml` using the `_:safe-link` helper (no bare `ln`)
- [ ] **TOOL-02**: Ghostty, glow, trippy, tlrc, conda, eza, motd configs ported to `configs/<tool>/`
- [ ] **TOOL-03**: `_:safe-link` hardened to verify target type (catches broken symlinks pointing to wrong target type)

### Documentation

README-per-directory + project-level docs for AI-collaboration fit.

- [ ] **DOCS-01**: Top-level `README.md` explains the manifest model, machine setup flow, and where to add things
- [ ] **DOCS-02**: Each top-level directory has a `README.md` covering purpose, key files, and how-to-add patterns
- [ ] **DOCS-03**: `CLAUDE.md` (project-level) captures v2 conventions for AI maintenance
- [ ] **DOCS-04**: `docs/MANIFEST.md` documents schema, inheritance rules, and worked examples
- [ ] **DOCS-05**: `docs/MIGRATION.md` records v1-to-v2 mapping and cutover plan
- [ ] **DOCS-06**: `docs/MACHINES.md` documents each machine's purpose, identity, and special config
- [ ] **DOCS-07**: `docs/SECURITY.md` documents bootstrap trust chain and SSH key handling

### Cutover

Per-machine cutover gates; v1 stays fully working throughout.

- [ ] **CUTV-01**: `task validate` composes all per-component validate tasks with check/cross output
- [ ] **CUTV-02**: `task links:reconcile` flags symlinks pointing into `$DOTFILEDIR` that are not in the manifest
- [ ] **CUTV-03**: `docs/CUTOVER.md` tracks per-machine cutover state with verification steps
- [ ] **CUTV-04**: All four machine categories (personal-laptop, work-laptop, server-1, server-2) installable from v2 with 100% `task validate` pass
- [ ] **CUTV-05**: Each machine runs v2 for at least 7 days without falling back to v1 before being declared cut over
- [ ] **CUTV-06**: Old repo archived (not deleted) after final per-machine cutover

## v2 Requirements

Deferred to a follow-up milestone after the v1 cutover is stable.

### Performance and UX

- **PERF-01**: Drift detection in `task validate` (manifest-declared vs deployed state diff)
- **PERF-02**: `DRY_RUN=1 task install` shows planned actions without executing
- **PERF-03**: Per-directory predictable templates (one example file per directory illustrating the pattern)
- **PERF-04**: Brew bundle pre-install snapshot for rollback safety

### Tooling Hardening

- **TOOL-V2-01**: Manifest JSON Schema for editor validation (taplo lint in CI)
- **TOOL-V2-02**: Audit-and-trim pass over ported v1 functions and aliases (kept verbatim in v1 for feature parity)
- **TOOL-V2-03**: `bats` or `zunit` unit tests for shell functions (Tier 2 — only if regression frequency justifies)
- **TOOL-V2-04**: macOS CI runner for end-to-end validation of the install pipeline

## Out of Scope

Explicit exclusions documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Nix / home-manager | Conflicts with go-task lock-in; slows AI iteration loop; Homebrew still needed for macOS GUI apps; declarative-manifest goal achieved at lower cost with TOML |
| chezmoi / stow / yadm | Adds a tool that overlaps with go-task; doesn't address the profile rethink that motivates this work |
| Windows or WSL support | Out of platform scope — macOS + Linux only |
| Migrating away from zsh | fish/nu/bash explicitly out |
| Replacing go-task | Locked decision |
| Hostname-based machine detection | Burned us before (`.zprofile:55-56` bug); explicit selection only |
| Inline profile branching in shared files | Replaced by platform-aware directory layout + manifest feature gates |
| Auditing every v1 alias/function for keep-or-cut | Feature parity in v1; trim pass deferred to v2 |
| `test` profile | Currently declared but never implemented; drop entirely |
| Auto-detection of identity or capabilities at runtime | Manifest is the source of truth; no clever inference |
| Tag-based manifest composition (`tags/dev.toml`, etc.) | User chose clarity (per-machine) over DRY (tags) |
| dasel as a parser | Resolved during research — yq throughout; one query syntax |
| Antigen, Powerlevel10k | Antigen archived since Jan 2018; p10k on author-declared life support; replaced by antidote + Starship |
| Encrypted secrets in repo | 1Password is the answer; no `git-crypt` / `transcrypt` / `sops` for secrets |

## Traceability

Mapping from requirement to roadmap phase. Confirmed by roadmapper 2026-05-13.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MFST-01 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-02 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-03 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-04 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-05 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-06 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-07 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-08 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| MFST-09 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| BTSP-01 | Phase 2 (Install Engine) | Pending |
| BTSP-02 | Phase 2 (Install Engine) | Pending |
| BTSP-03 | Phase 2 (Install Engine) | Pending |
| BTSP-04 | Phase 2 (Install Engine) | Pending |
| BTSP-05 | Phase 2 (Install Engine) | Pending |
| BTSP-06 | Phase 2 (Install Engine) | Pending |
| BTSP-07 | Phase 2 (Install Engine) | Pending |
| LINT-01 | Phase 2 (Install Engine) | Pending |
| LINT-02 | Phase 2 (Install Engine) | Pending |
| LINT-03 | Phase 2 (Install Engine) | Pending |
| LINT-04 | Phase 2 (Install Engine) | Pending |
| LINT-05 | Phase 2 (Install Engine) | Pending |
| LINT-06 | Phase 2 (Install Engine) | Pending |
| LINT-07 | Phase 2 (Install Engine) | Pending |
| LINT-08 | Phase 2 (Install Engine) | Pending |
| SHEL-01 | Phase 3 (Shell Layer) | Pending |
| SHEL-02 | Phase 3 (Shell Layer) | Pending |
| SHEL-03 | Phase 3 (Shell Layer) | Pending |
| SHEL-04 | Phase 3 (Shell Layer) | Pending |
| SHEL-05 | Phase 3 (Shell Layer) | Pending |
| SHEL-06 | Phase 3 (Shell Layer) | Pending |
| SHEL-07 | Phase 3 (Shell Layer) | Pending |
| SHEL-08 | Phase 3 (Shell Layer) | Pending |
| SHEL-09 | Phase 3 (Shell Layer) | Pending |
| SHEL-10 | Phase 3 (Shell Layer) | Pending |
| SHEL-11 | Phase 3 (Shell Layer) | Pending |
| SHEL-12 | Phase 3 (Shell Layer) | Pending |
| IDNT-01 | Phase 4 (Identity Layer) | Pending |
| IDNT-02 | Phase 4 (Identity Layer) | Pending |
| IDNT-03 | Phase 4 (Identity Layer) | Pending |
| IDNT-04 | Phase 4 (Identity Layer) | Pending |
| IDNT-05 | Phase 4 (Identity Layer) | Pending |
| IDNT-06 | Phase 4 (Identity Layer) | Pending |
| IDNT-07 | Phase 4 (Identity Layer) | Pending |
| IDNT-08 | Phase 4 (Identity Layer) | Pending |
| PKGS-01 | Phase 5 (Packages Layer) | Pending |
| PKGS-02 | Phase 5 (Packages Layer) | Pending |
| PKGS-03 | Phase 5 (Packages Layer) | Pending |
| PKGS-04 | Phase 5 (Packages Layer) | Pending |
| PKGS-05 | Phase 5 (Packages Layer) | Pending |
| PKGS-06 | Phase 5 (Packages Layer) | Pending |
| PKGS-07 | Phase 5 (Packages Layer) | Pending |
| OSCF-01 | Phase 6 (OS Defaults) | Pending |
| OSCF-02 | Phase 6 (OS Defaults) | Pending |
| OSCF-03 | Phase 6 (OS Defaults) | Pending |
| OSCF-04 | Phase 6 (OS Defaults) | Pending |
| OSCF-05 | Phase 6 (OS Defaults) | Pending |
| OSCF-06 | Phase 6 (OS Defaults) | Pending |
| CLDE-01 | Phase 7 (Claude + Configs) | Pending |
| CLDE-02 | Phase 7 (Claude + Configs) | Pending |
| CLDE-03 | Phase 7 (Claude + Configs) | Pending |
| CLDE-04 | Phase 7 (Claude + Configs) | Pending |
| TOOL-01 | Phase 7 (Claude + Configs) | Pending |
| TOOL-02 | Phase 7 (Claude + Configs) | Pending |
| TOOL-03 | Phase 7 (Claude + Configs) | Pending |
| DOCS-01 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-02 | Phase 3 (Shell Layer) | Pending |
| DOCS-03 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| DOCS-04 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| DOCS-05 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-06 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-07 | Phase 2 (Install Engine) | Pending |
| CUTV-01 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-02 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-03 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-04 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-05 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-06 | Phase 8 (Validation + Cutover) | Pending |

**Coverage:**

- v1 requirements: 77 total (MFST: 9, BTSP: 7, LINT: 8, SHEL: 12, IDNT: 8, PKGS: 7, OSCF: 6, CLDE: 4, TOOL: 3, DOCS: 7, CUTV: 6)
- Mapped to phases: 77
- Unmapped: 0

**Per-phase requirement counts:**

| Phase | Count | Categories |
|-------|-------|------------|
| 1 — Manifest Engine + Skeleton | 11 | MFST-01..09, DOCS-03, DOCS-04 |
| 2 — Install Engine | 16 | BTSP-01..07, LINT-01..08, DOCS-07 |
| 3 — Shell Layer | 13 | SHEL-01..12, DOCS-02 |
| 4 — Identity Layer | 8 | IDNT-01..08 |
| 5 — Packages Layer | 7 | PKGS-01..07 |
| 6 — OS Defaults | 6 | OSCF-01..06 |
| 7 — Claude + Configs | 7 | CLDE-01..04, TOOL-01..03 |
| 8 — Validation + Cutover | 9 | CUTV-01..06, DOCS-01, DOCS-05, DOCS-06 |

---

*Requirements defined: 2026-05-13*
*Last updated: 2026-05-13 after roadmap traceability confirmation*
