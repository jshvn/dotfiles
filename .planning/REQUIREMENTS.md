# Requirements: Dotfiles v2 Refactor

**Defined:** 2026-05-13
**Last updated:** 2026-05-13 after testing/verification expansion
**Core Value:** A single declarative manifest per machine makes the complete install state legible to both humans and AI agents.

## v1 Requirements

Requirements for the v2.0 cutover gate. Each maps to a roadmap phase. All requirements are hypotheses until shipped and validated on every target machine.

**Scope note:** v1 is macOS-only across all four target machines (laptops + Mac servers). Linux support is deferred to v2+.

**Testing tiers (covered by these requirements):**

| Tier | Purpose | Where |
|---|---|---|
| 0. Static | Lint, syntax, shellcheck | LINT-01..08, CLDE-02 |
| 1. Validate | Installed state matches manifest | MFST-08, IDNT-07, OSCF-05, VRFY-01..02, CUTV-01 |
| 2. Reconcile | Detect/cleanup drift | VRFY-03, TOOL-04, CUTV-02, CUTV-07, CUTV-08 |
| 3. Smoke | Component functional tests | MFST-05, LINT-08, TEST-01, TEST-02 |
| 4. System | End-to-end on real machines | CUTV-04, CUTV-05, DOCS-08 |

### Manifest

Schema, parsing, merge semantics. Keystone layer — every other phase reads `resolved.json`.

- [ ] **MFST-01**: `manifests/defaults.toml` defines shared baseline (identity, features, default package bundles)
- [ ] **MFST-02**: `manifests/machines/<name>.toml` declares per-machine identity, features, package bundles, and any overrides
- [ ] **MFST-03**: Machine manifest can override any `defaults.toml` key with documented merge semantics (maps deep-merge, scalars/arrays replace, `extra_packages` concatenates)
- [ ] **MFST-04**: `install/resolver.zsh` compiles defaults + machine manifest into `$XDG_STATE_HOME/dotfiles/resolved.json` using yq for TOML-to-JSON and a correct deep-merge expression
- [ ] **MFST-05**: Test fixtures cover all merge cases (map-over-map, list-replace, scalar-override, nested table, missing key) and are run by `task manifest:test`
- [ ] **MFST-06**: `task manifest:resolve` produces `resolved.json`; downstream tasks consume it via go-task `fromJson` and never read TOML directly
- [ ] **MFST-07**: `task manifest:show` prints the post-merge structure for debugging
- [ ] **MFST-08**: `task manifest:validate` enforces required schema fields (description, identity, features at minimum)
- [ ] **MFST-09**: Adding a new machine is a single new file in `manifests/machines/` plus `task setup -- <name>`

### Bootstrap

Fresh-install entry point with hardened supply chain.

- [ ] **BTSP-01**: `bootstrap.zsh` uses `set -euo pipefail` (not `set -e`); pipefail catches install-script failures
- [ ] **BTSP-02**: Bootstrap installs go-task via Homebrew (no curl-pipe-to-shell)
- [ ] **BTSP-03**: Bootstrap is resumable — every step has a guard against re-running
- [ ] **BTSP-04**: `task setup -- <machine-name>` persists explicit machine selection to `$XDG_STATE_HOME/dotfiles/machine`; no hostname inference
- [ ] **BTSP-05**: `docs/SECURITY.md` documents the bootstrap trust chain (what is downloaded, from where, how verified)
- [ ] **BTSP-06**: `task install` is the canonical idempotent entry; `task update` is an alias for the same task (`task: install`) — there is no separate update pipeline that could diverge from install and produce the "added-to-update-forgot-install" drift class

### Install Engine

Idempotency, lint suite, validation foundation. Built before shell content is ported.

- [ ] **LINT-01**: Every install task has a `status:` block that makes re-runs a no-op (local-only conditions; no network dependencies)
- [ ] **LINT-02**: `task lint:taskfile` flags `$VAR` references inside `status:` blocks (fixes `macos:shell` class of bug)
- [ ] **LINT-03**: `task lint:taskfile` flags bare `ln -s` outside `helpers.yml` and flags tasks with `cmds:` but no `status:`
- [ ] **LINT-04**: `task lint:shell-headers` flags executable `.zsh` files missing `set -euo pipefail`
- [ ] **LINT-05**: `task lint:portability` warns (non-blocking) when likely portability-sensitive commands appear in flat directories (e.g. `pbcopy`, `osascript`, `defaults`) — surfaces what would need to be handled if Linux returns in v2; does not block v1 builds
- [ ] **LINT-06**: Root `task lint` aggregates all lint subtasks
- [ ] **LINT-07**: `zsh -n` runs over every `.zsh` file as Tier-0 syntax test (catches `local`-at-script-scope class of bug)
- [ ] **LINT-08**: `task install` re-run on a converged machine completes in under 5 seconds (idempotency timing test)

### Shell

zsh startup chain with flat content layout (macOS-only v1).

- [ ] **SHEL-01**: `shell/.zshenv` exports XDG vars and `$DOTFILES_MACHINE` (from state file); no `$DOTFILES_PROFILE`
- [ ] **SHEL-02**: `shell/.zprofile` sets Homebrew shellenv (guarded by `[[ -x "$BREW" ]]`) and SSH agent socket only when manifest declares the feature
- [ ] **SHEL-03**: `shell/.zshrc` glob-loads `shell/aliases/*.zsh` and `shell/functions/*.zsh` (interactive only; flat — no platform subdirectories in v1)
- [ ] **SHEL-04**: Antidote replaces Antigen as the plugin manager (static bundle file) — primary lever for the 200ms target
- [ ] **SHEL-05**: Port v1 `zsh/theme.zsh` (alanpeabody-based) to `shell/theme.zsh` as-is; Starship rejected in v1 (existing prompt is small, fast, and not on life support)
- [ ] **SHEL-06**: One alias topic per file in `shell/aliases/<topic>.zsh`
- [ ] **SHEL-07**: One function per file in `shell/functions/<name>.zsh`
- [ ] **SHEL-08**: All v1 aliases ported to flat `shell/aliases/`; broken `local`-at-script-scope and similar v1 quality issues fixed in transit
- [ ] **SHEL-09**: All v1 functions ported to flat `shell/functions/`; each file passes `zsh -n`
- [ ] **SHEL-10**: compinit uses a daily-rebuilt cache rather than running per shell startup
- [ ] **SHEL-11**: MOTD output is cached to disk with 24-hour TTL (async refresh)
- [ ] **SHEL-12**: Cold interactive shell startup under 200ms (measured by `task perf:shell`; fails CI if exceeded)

### Identity

git and SSH identity, manifest-driven.

- [ ] **IDNT-01**: `identity/git/config` uses `includeIf` for path-based identity selection
- [ ] **IDNT-02**: Per-identity git configs live under `identity/git/identities/<identity-name>` (no profile-suffix filenames)
- [ ] **IDNT-03**: `identity/ssh/config` uses `Include` directives for identity-based host configs
- [ ] **IDNT-04**: Per-identity SSH host configs live under `identity/ssh/identities/<identity-name>`
- [ ] **IDNT-05**: 1Password integration is split into two flags -- `features.one-password-ssh` gates the SSH agent socket + `IdentityAgent` directive, and `features.one-password-signing` gates git commit signing via the `op-ssh-sign` program. Cross-field validation rejects mismatched configurations. No hostname literals anywhere in the identity path.
- [ ] **IDNT-06**: Public SSH keys committed under `identity/ssh/keys/`; private keys never committed
- [ ] **IDNT-07**: `task validate` asserts `git config user.email` matches manifest identity and `ssh-add -L` lists the expected key
- [ ] **IDNT-08**: `taskfiles/identity.yml` reads identity from `resolved.json` and creates the appropriate symlinks via `_:safe-link`

### Packages

Homebrew package management driven by manifest bundles (macOS-only v1).

- [ ] **PKGS-01**: Per-purpose Brewfile bundles in `packages/<purpose>.rb` (flat -- not `packages/brew/`). v1 ships `core` and `gui`; bundles are an as-needed grouping, not a fixed set (per-machine extras carry the bulk).
- [ ] **PKGS-02**: `taskfiles/packages.yml` reads `packages.brew.bundles` from `resolved.json` and composes the per-machine Brewfile
- [ ] **PKGS-03**: `brew bundle` task uses a `status:` check based on `brew bundle check --file=<composed>` (replaces unconditional re-run)
- [ ] **PKGS-04**: Manifest can declare per-machine `extra_packages` as a typed sub-table (`formulae`, `casks`, `mas`); each sub-array concat+dedupes with defaults at resolve time. Cask and MAS entries are typed objects (`{name, verify}` for casks; `{id, name}` for MAS).
- [ ] **PKGS-05**: GUI bundles (casks) are isolated so server machines without GUI can omit them via manifest

### Package Verification

Post-install checks that declared packages are actually usable. Closes the "brew bundle applied but binary missing or app didn't land" gap.

- [ ] **VRFY-01**: `task packages:verify` confirms `command -v <bin>` resolves for every formula declared in the active manifest's bundles. Binary names declared as per-line comments in bundle files: `brew 'ripgrep' # verify: rg`. Default convention: if no comment, assume bin name == formula name.
- [ ] **VRFY-02**: `task packages:verify` confirms `/Applications/<App>.app` exists for every cask declared in the active manifest's bundles. App names declared as per-line comments: `cask '1password' # verify: 1Password`. Default convention: if no comment, derive from cask name.
- [ ] **VRFY-03**: `task packages:audit` lists currently-installed brew formulae/casks that are NOT declared in any manifest bundle for the active machine — surfaces "installed manually, forgot to declare" drift. Non-blocking by default; exits non-zero with `--strict`.
- [ ] **VRFY-04**: `task install` includes `task packages:verify` in its final step so a successful install fails loudly when a declared package didn't actually land (silent install failures caught at the bundle layer)

### OS Defaults

macOS defaults feature-flag-gated.

- [ ] **OSCF-01**: macOS defaults split into per-concern files (`os/defaults/dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh`)
- [ ] **OSCF-02**: Each defaults group is gated by a manifest feature flag — opt-in per machine (servers can decline all GUI-related defaults)
- [ ] **OSCF-03**: Every defaults task has a `status:` that reads `defaults read <domain> <key>` before writing (replaces re-running on every install)
- [ ] **OSCF-04**: `os/shell-registration.zsh` adds Homebrew zsh to `/etc/shells` and runs `chsh` with a correct `{{.BREW_ZSH}}` template-var `status:` check (fixes the live v1 bug)
- [ ] **OSCF-05**: `task validate` asserts current defaults values match in-script expectations for each enabled concern

### Claude

Claude Code integration with bug fixes for known v1 issues.

- [ ] **CLDE-01**: Global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills installed via `taskfiles/claude.yml`
- [ ] **CLDE-02**: All hooks ported and shellcheck-clean: `secret-scan.zsh`, `no-emojis.zsh`, `no-ai-comments.zsh`, `agent-transparency.zsh` (last one rewritten to remove `local` at script scope)
- [ ] **CLDE-03**: GSD install task uses a presence sentinel file as its `status:` check — `npx` runs only when the sentinel is absent. An explicit `task claude:update` deletes the sentinel and re-runs `npx`.
- [ ] **CLDE-04**: Marketplace install uses `claude plugin list` as its `status:` check

### Tool Configs

Per-tool configuration deployment via symlinks.

- [ ] **TOOL-01**: Tool configs deployed via `taskfiles/links.yml` using the `_:safe-link` helper (no bare `ln`)
- [ ] **TOOL-02**: Ghostty, glow, trippy, tlrc, conda, eza, motd configs ported to `configs/<tool>/`
- [ ] **TOOL-03**: `_:safe-link` hardened to verify target type (catches broken symlinks pointing to wrong target type)
- [ ] **TOOL-04**: `_:check-link` verifies the symlink (a) exists, (b) target is not broken, and (c) `readlink -f` equals the manifest-expected source path; mismatch is a failure not a warning (catches "symlink exists but points to stale path after refactor" class of bug)

### Smoke Tests

Component-level functional tests aggregated under `task test`.

- [ ] **TEST-01**: `task test:hooks` pipes synthetic JSON input through each Claude hook (`secret-scan`, `no-emojis`, `no-ai-comments`, `agent-transparency`) and asserts expected exit code (0 for pass/warn, 2 for block) and stderr pattern. Catches runtime regressions that lint misses.
- [ ] **TEST-02**: Root `task test` aggregates `task manifest:test` (existing MFST-05 fixtures) and `task test:hooks` so a single command runs all smoke tests; CI wires this in alongside `task lint`

### Documentation

README-per-directory + project-level docs for AI-collaboration fit.

- [ ] **DOCS-01**: Top-level `README.md` explains the manifest model, machine setup flow, and where to add things
- [ ] **DOCS-02**: Each top-level directory has a `README.md` covering purpose, key files, and how-to-add patterns
- [ ] **DOCS-03**: `CLAUDE.md` (project-level) captures v2 conventions for AI maintenance
- [ ] **DOCS-04**: `docs/MANIFEST.md` documents schema, inheritance rules, and worked examples
- [ ] **DOCS-05**: `docs/MIGRATION.md` records v1-to-v2 mapping and cutover plan
- [ ] **DOCS-06**: `docs/MACHINES.md` documents each machine's purpose, identity, and special config
- [ ] **DOCS-07**: `docs/SECURITY.md` documents bootstrap trust chain and SSH key handling
- [ ] **DOCS-08**: `docs/CUTOVER.md` includes a per-machine fresh-install verification procedure (manual steps to verify on a clean Mac before declaring cutover complete)

### Cutover

Per-machine cutover gates; v1 stays fully working throughout.

- [ ] **CUTV-01**: `task validate` composes all per-component validate tasks with check/cross output
- [ ] **CUTV-02**: `task links:reconcile` (default mode) detects orphan symlinks — symlinks pointing into `$DOTFILEDIR` not declared in the manifest. Prints them and exits non-zero. CI-safe; no destructive action.
- [ ] **CUTV-03**: `docs/CUTOVER.md` tracks per-machine cutover state with verification steps
- [ ] **CUTV-04**: All four target machines (personal-laptop, work-laptop, server-1, server-2 — all macOS, mixed roles) installable from v2 with 100% `task validate` pass
- [ ] **CUTV-05**: Each machine runs v2 for at least 7 days without falling back to v1 before being declared cut over
- [ ] **CUTV-06**: Old repo archived (not deleted) after final per-machine cutover
- [ ] **CUTV-07**: `task links:reconcile -- --remove` enters interactive cleanup mode: for each orphan, prompts y/N before deleting. Destructive operations are never silent.
- [ ] **CUTV-08**: `task install` runs `task links:reconcile` in detect-only mode at the end and warns (non-fatal) if orphans exist — surfaces "you moved a link in the manifest, the old one is dangling" feedback at install time

## v2 Requirements

Deferred to a follow-up milestone after the v1 cutover is stable.

### Linux Support

- **LINUX-V2-01**: Reintroduce platform-aware directory split (`aliases/{common,darwin,linux}/`) when first Linux machine enters scope
- **LINUX-V2-02**: First-class Linux package manifests (`packages/apt/*.list`, `packages/dnf/*.list`)
- **LINUX-V2-03**: Linux bootstrap branch (SHA256-verified go-task binary; yq pre-Homebrew sequencing)
- **LINUX-V2-04**: Linux idempotency check for apt/dnf package installs (`dpkg -s` or `rpm -q`, or sentinel file)
- **LINUX-V2-05**: macOS-defaults tasks no-op on Linux (platform check at task level)
- **LINUX-V2-06**: Promote LINT-05 from warning to blocker once cross-platform support is live

### Performance & UX

- **PERF-01**: Drift detection in `task validate` (manifest-declared vs deployed state diff — broader than VRFY-03 audit)
- **PERF-02**: `DRY_RUN=1 task install` shows planned actions without executing
- **PERF-03**: Per-directory predictable templates (one example file per directory illustrating the pattern)
- **PERF-04**: Brew bundle pre-install snapshot for rollback safety

### Tooling Hardening

- **TOOL-V2-01**: Manifest JSON Schema for editor validation (taplo lint in CI)
- **TOOL-V2-02**: Audit-and-trim pass over ported v1 functions and aliases (kept verbatim in v1 for feature parity)
- **TOOL-V2-03**: `bats` or `zunit` unit tests for shell functions (Tier-2 expansion — only if regression frequency justifies)
- **TOOL-V2-04**: macOS CI runner for end-to-end validation of the install pipeline (full fresh-install simulation)

## Out of Scope

Explicit exclusions documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Linux support in v1 | All four target machines are macOS (laptops + Mac servers); avoids cross-platform complexity until a real Linux machine enters scope. Returns as v2 work item set. |
| Starship prompt | v1 keeps the existing alanpeabody-based `theme.zsh`. Starship recommendation was based on a misread of the v1 prompt as Powerlevel10k. Existing prompt is small, fast, and not on life support. |
| Separate `task update` pipeline | `task install` IS `task update` — single idempotent entry point. Prevents drift class where adding a package to update path silently misses the install path. |
| Nix / home-manager | Conflicts with go-task lock-in; slows AI iteration loop; Homebrew still needed for macOS GUI apps; declarative-manifest goal achieved at lower cost with TOML |
| chezmoi / stow / yadm | Adds a tool that overlaps with go-task; doesn't address the profile rethink that motivates this work |
| Windows or WSL support | Out of platform scope |
| Migrating away from zsh | fish/nu/bash explicitly out |
| Replacing go-task | Locked decision |
| Hostname-based machine detection | Burned us before (`.zprofile:55-56` bug); explicit selection only |
| Platform-aware directory split (v1) | Deferred to v2 with Linux support — flat `shell/aliases/` and `shell/functions/` for v1 |
| Inline profile branching in shared files | Replaced by manifest feature gates |
| Auditing every v1 alias/function for keep-or-cut | Feature parity in v1; trim pass deferred to v2 |
| `test` profile | Currently declared but never implemented; drop entirely |
| Auto-detection of identity or capabilities at runtime | Manifest is the source of truth; no clever inference |
| Tag-based manifest composition (`tags/dev.toml`, etc.) | User chose clarity (per-machine) over DRY (tags) |
| dasel as a parser | Resolved during research — yq throughout; one query syntax |
| Antigen, Powerlevel10k | Antigen archived since Jan 2018; replaced by antidote. p10k not in use; keep v1 alanpeabody-based theme. |
| Encrypted secrets in repo | 1Password is the answer; no `git-crypt` / `transcrypt` / `sops` for secrets |
| Automated fresh-install CI | Documented manual procedure in `docs/CUTOVER.md` (DOCS-08); full macOS CI runner is v2 (TOOL-V2-04) |

## Traceability

Per-REQ-ID mapping to roadmap phase.

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
| VRFY-01 | Phase 5 (Packages Layer) | Pending |
| VRFY-02 | Phase 5 (Packages Layer) | Pending |
| VRFY-03 | Phase 5 (Packages Layer) | Pending |
| VRFY-04 | Phase 5 (Packages Layer) | Pending |
| OSCF-01 | Phase 6 (OS Defaults) | Pending |
| OSCF-02 | Phase 6 (OS Defaults) | Pending |
| OSCF-03 | Phase 6 (OS Defaults) | Pending |
| OSCF-04 | Phase 6 (OS Defaults) | Pending |
| OSCF-05 | Phase 6 (OS Defaults) | Pending |
| CLDE-01 | Phase 7 (Claude + Configs) | Pending |
| CLDE-02 | Phase 7 (Claude + Configs) | Pending |
| CLDE-03 | Phase 7 (Claude + Configs) | Pending |
| CLDE-04 | Phase 7 (Claude + Configs) | Pending |
| TOOL-01 | Phase 7 (Claude + Configs) | Pending |
| TOOL-02 | Phase 7 (Claude + Configs) | Pending |
| TOOL-03 | Phase 7 (Claude + Configs) | Pending |
| TOOL-04 | Phase 7 (Claude + Configs) | Pending |
| TEST-01 | Phase 7 (Claude + Configs) | Pending |
| TEST-02 | Phase 7 (Claude + Configs) | Pending |
| DOCS-01 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-02 | Phase 3 (Shell Layer) | Pending |
| DOCS-03 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| DOCS-04 | Phase 1 (Manifest Engine + Skeleton) | Pending |
| DOCS-05 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-06 | Phase 8 (Validation + Cutover) | Pending |
| DOCS-07 | Phase 2 (Install Engine) | Pending |
| DOCS-08 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-01 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-02 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-03 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-04 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-05 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-06 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-07 | Phase 8 (Validation + Cutover) | Pending |
| CUTV-08 | Phase 8 (Validation + Cutover) | Pending |

**Coverage:**

- v1 requirements: 83 total (MFST: 9, BTSP: 6, LINT: 8, SHEL: 12, IDNT: 8, PKGS: 5, VRFY: 4, OSCF: 5, CLDE: 4, TOOL: 4, TEST: 2, DOCS: 8, CUTV: 8)
- Mapped to phases: 83
- Unmapped: 0

**Per-phase requirement counts:**

| Phase | Count | Categories |
|-------|-------|------------|
| 1 — Manifest Engine + Skeleton | 11 | MFST-01..09, DOCS-03, DOCS-04 |
| 2 — Install Engine | 15 | BTSP-01..06, LINT-01..08, DOCS-07 |
| 3 — Shell Layer | 13 | SHEL-01..12, DOCS-02 |
| 4 — Identity Layer | 8 | IDNT-01..08 |
| 5 — Packages Layer | 9 | PKGS-01..05, VRFY-01..04 |
| 6 — OS Defaults | 5 | OSCF-01..05 |
| 7 — Claude + Configs | 10 | CLDE-01..04, TOOL-01..04, TEST-01..02 |
| 8 — Validation + Cutover | 12 | CUTV-01..08, DOCS-01, DOCS-05, DOCS-06, DOCS-08 |

---

*Requirements defined: 2026-05-13*
*Last updated: 2026-05-13 after testing/verification expansion (VRFY, TOOL-04, BTSP-06, CUTV-07/08, TEST, DOCS-08)*
