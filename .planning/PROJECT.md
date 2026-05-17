# Dotfiles (v2 Refactor)

## What This Is

Greenfield rewrite of the personal dotfiles repo at `/Users/josh/Git/personal/dotfiles`, built in parallel to the current implementation. Replaces the named-profile system (`personal` / `work` / `server` suffixed files) with explicit per-machine TOML manifests inheriting from a shared `defaults.toml`. Designed for macOS exclusively in v1 (laptops and Mac servers); Linux server support is deferred to a future milestone. Built on go-task orchestration, zsh as the primary shell, and symlink-based deployment. Optimized for AI-assisted maintenance: one concept per file, explicit manifests over implicit suffixing, predictable templates.

## Core Value

A single declarative manifest per machine makes the complete install state legible to both humans and AI agents — no inference from filename suffixes, no hidden profile branching, no hostname-based guessing.

## Current Milestone: v2.1 Cleanup

**Goal:** Make the v2 dotfiles repo lean, correct, and self-contained — port any silently-dropped v1 features, remove v1 entirely, redesign the public task surface, eliminate code/comment bloat and dead code, and ensure the test surface validates what each component actually delivers.

**Target features:**

- v1-drop audit — Read-only investigation across every v1 leftover file (`taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/brew.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/*-stub.yml`, `taskfiles/macos.v1.yml.bak`, `zsh/`, `install/Brewfile*`) producing a keep/drop classification of every v1 feature absent from v2.
- v1-drop remediation — Port the "keep" items from the audit into v2 (driver: `/etc/zshenv` writing currently breaks fresh-machine installs).
- v1 removal — Delete v1 leftover files, the `zsh/` directory, `install/Brewfile*`, and the cutover infrastructure (`install/cutover-gate.zsh`, `task cutover:ack`, `docs/CUTOVER.md`). Drop the per-machine 7-day-soak model.
- Task surface redesign — Audit every exposed go-task task; rename/remove/expose-or-internal-only based on actual use.
- Code review + dead-code cleanup — Repo-wide review for duplicated logic, dead code, unused helpers, simplification opportunities.
- Comment/doc trim — Strip excess inline commentary from taskfiles; simplify docs; prefer self-documenting code.

**Key context:** Live finding from fresh-machine install: `/etc/zshenv` writing was a v1 `common.yml` task that v2 silently dropped, breaking the shell layer on fresh machines. Phase 1 audit must find any siblings of this issue before phase 3 deletes the v1 files that contain the source-of-truth for what was dropped.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

**Bootstrap and install (Phase 1 + 2):**

- [x] One-shot fresh-install entry point — `bootstrap.zsh` installs Homebrew + go-task + yq with HTTPS-only AUDIT line + 3s abort window. No curl-to-shell into other targets. Validated in Phase 2. (BTSP-01/02/03)
- [x] Explicit machine selection at setup time — `task setup -- <machine-name>` writes `$XDG_STATE_HOME/dotfiles/machine`; no hostname guessing. Validated in Phase 1; re-confirmed in Phase 2. (BTSP-04)
- [x] Idempotent re-install — `lint:taskfile` enforces "cmds: requires status:" structurally (LINT-01 contract via LINT-03a). Every install task in `task install`'s call graph has a `status:` block. Validated in Phase 2. (LINT-01..LINT-07)
- [x] `task install` is the canonical entry — `task update` is dropped per D-10. Phase 3 ships shell alias `update='task install'` for muscle memory. Validated in Phase 2. (BTSP-06)
- [x] Cutover-ack gate — `install/cutover-gate.zsh` + Taskfile.yml preconditions + bootstrap.zsh defense-in-depth per D-07/D-09. Validated in Phase 2.
- [x] Bootstrap trust chain documented — `docs/SECURITY.md` (7 H2 sections covering trust anchors, threat model, audit commands). Validated in Phase 2. (BTSP-05/DOCS-07)

### Active

<!-- v1 feature-parity targets, organized by capability. All requirements are hypotheses until shipped. -->

**Bootstrap and install (remaining):**

- [ ] `task validate` reports per-component health using check/cross symbols (deferred to Phase 8 per CONTEXT)

**Manifest layer:**

- [ ] `defaults.toml` defines the shared baseline (packages, configs, features)
- [ ] `machines/<name>.toml` declares identity, features, package bundles, git/ssh identity, platform
- [ ] Machine manifest can override any `defaults.toml` key
- [ ] Manifest is parsed once at task evaluation and drives all subsequent install decisions
- [ ] Adding a new machine is a single new file in `machines/` plus `task setup`

**Shell (zsh):**

- [ ] `.zshenv` exports XDG vars and the selected machine identifier (replaces `DOTFILES_PROFILE`)
- [ ] `.zshrc` loads aliases and functions via glob (interactive only)
- [ ] `.zprofile` sets Homebrew shellenv and SSH agent socket — guarded so the file is safe on minimal Mac server installs
- [ ] One alias topic per file in flat `aliases/<topic>.zsh` (no platform subdirectories in v1; macOS is the only platform)
- [ ] One function per file in flat `functions/<name>.zsh`
- [ ] v1 prompt (`theme.zsh`, alanpeabody-based) ported as-is; no Starship swap in v1
- [ ] Antigen replaced by antidote (static bundle file) — the primary lever for the 200ms target
- [ ] Cold interactive shell startup target: under 200ms (current ~500ms with antigen)

**Git:**

- [ ] Global git config with `includeIf` for identity selection (driven by manifest, not profile name)
- [ ] Per-identity config files (e.g. `git/identities/personal`, `git/identities/work`)
- [ ] Global `gitignore`

**SSH:**

- [ ] Main SSH config with conditional includes (driven by manifest, not `Match exec` on a profile file)
- [ ] Per-identity host configs (e.g. `ssh/identities/personal`, `ssh/identities/work`)
- [ ] 1Password SSH agent integration enabled only when manifest declares the `one-password-ssh` feature
- [ ] Public SSH keys committed; private keys never

**Packages:**

- [ ] Brewfile composition via manifest bundles (replaces `Brewfile-<profile>.rb` suffixing)
- [ ] Per-purpose bundles in flat `packages/<purpose>.rb` (`core`, `gui`; +any future purpose-named additions). Per-machine variation lives in manifest `extra_packages` typed sub-table (`formulae`/`casks`/`mas`).
- [ ] Per-machine package additions allowed via manifest `extra_packages` without forking a bundle

**macOS defaults:**

- [ ] Configurable via manifest features (each defaults group is opt-in)
- [ ] Idempotent (no re-running on every install — current `macos:shell` bug fixed)

**Claude Code integration:**

- [ ] Global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills installed via go-task
- [ ] Hooks ported: secret-scan, no-emojis, no-ai-comments, agent-transparency (with shellcheck-clean rewrite)
- [ ] Claude marketplace and plugin install with a working `status:` guard (current `gsd-install` re-runs every time)

**Documentation and discoverability:**

- [ ] Top-level `README.md` maps the repo and explains the manifest model
- [ ] Each top-level directory has a `README.md` explaining purpose and how to add to it
- [ ] `CLAUDE.md` captures conventions for AI-assisted maintenance
- [ ] `docs/MIGRATION.md` records the cutover plan and old-to-new mapping

**Verification and testing:**

- [ ] `task packages:verify` confirms each declared formula's binary resolves on PATH and each declared cask's `/Applications/<App>.app` exists (binary/app names declared as per-line comments in `packages/brew/*.rb`)
- [ ] `task packages:audit` lists currently-installed brew formulae/casks NOT declared in the active manifest — surfaces "installed manually, forgot to declare" drift
- [ ] `task links:reconcile` detects orphan symlinks (default; CI-safe) and supports `--remove` for cleanup with interactive confirmation
- [ ] `_:check-link` verifies the symlink exists AND its `readlink -f` matches the manifest-expected source — target mismatch is a failure
- [ ] `task test` aggregates manifest deep-merge fixtures + Claude hook smoke tests (synthetic JSON input through every hook)
- [ ] `docs/CUTOVER.md` documents a fresh-machine verification procedure per machine

**Cutover:**

- [ ] All four machines (`personal-laptop`, `work-laptop`, `server-1`, `server-2` — all running macOS, mixed roles) installable from the new repo
- [ ] Feature parity confirmed via `task validate` per machine
- [ ] Old repo archived (not deleted) after final cutover

### Out of Scope

<!-- Explicit boundaries with reasoning. -->

- **Linux support in v1** — simplification; all four target machines are macOS (laptops + Mac servers). Linux returns as a real target only when a real Linux machine enters scope. Platform-aware directory split, apt/dnf manifests, and Linux bootstrap branch all deferred.
- **Nix / home-manager** — evaluated; conflicts with go-task lock-in, slows AI iteration loop, Homebrew still needed for macOS GUI apps via `nix-darwin.homebrew` escape hatch. Declarative-manifest goal achieved via TOML at lower cost.
- **chezmoi / stow / yadm** — adds a tool dependency that overlaps with go-task; doesn't solve the profile rethink.
- **Windows / WSL** — out of platform scope.
- **Starship prompt** — v1 keeps the existing alanpeabody-based `theme.zsh`. Starship would be a behavior change with no problem to solve (the current prompt is small, fast, and not on life support).
- **Migrating away from zsh** — fish / nu / bash are out.
- **Replacing go-task** — locked.
- **Hostname-based machine detection** — burned us before (`.zprofile:55-56` bug). Explicit selection only.
- **Inline profile branching in shared files** — replaced by manifest-driven feature gates.
- **Auditing every existing zsh function/alias for keep-or-cut** — feature parity means port them all; audit-and-trim is a separate later milestone.
- **A `test` profile** — currently declared but never implemented; drop entirely.
- **Auto-detection of identity / capabilities** — manifest is the source of truth; no clever inference at runtime.

## Context

**Origin.** Current dotfiles repo at `/Users/josh/Git/personal/dotfiles` evolved over years — from manual setup, to manual zsh-script orchestration, to the current go-task + symlink + profile-suffix model, to AI-assisted refactors layered on top. Architecture is genuinely solid (five clean layers documented in `.planning/codebase/ARCHITECTURE.md`) but accumulated cruft and structural smells make extension friction-heavy and obscure intent for both humans and AI agents.

**Known issues in the current repo** (from `.planning/codebase/CONCERNS.md`, 2026-05-13 audit):

- `test` profile declared in `VALID_PROFILES` but has no install artifacts — runtime crash if selected
- `macos:shell` status check uses `$BREW_ZSH` (shell var) instead of `{{.BREW_ZSH}}` (task var) — re-runs on every install
- `.zprofile` uses literal hostname `"server"` check for 1Password — silently breaks on hostnames containing "server" or on server machines without that hostname
- `gsd-install` task runs `npx` on every `task install` with no `status:` guard
- `bootstrap.zsh` uses `set -e` rather than `set -euo pipefail`, pipes `curl` to `sh` with no integrity check
- `antigen apply` and synchronous MOTD push interactive shell startup to ~500ms cold
- macOS-only aliases (`hardware.zsh`, `general.zsh:27-31`, `networking.zsh:4`) live in `common/` and break on server profile
- `agent-transparency.zsh` uses `local` at script scope (shellcheck error)
- `pubkey.zsh` docstring references a stale key name from a prior employer

**AI workflow context.** This repo is maintained jointly by josh and AI agents (Claude Code, GSD skills). Structure should make the agent's job easier: explicit manifests beat implicit suffixing, one-concept-per-file beats grab-bag scripts, predictable templates beat one-off patterns. The agent should be able to add a new alias, function, hook, tool config, or machine by reading a single template and following it.

**Codebase map.** `.planning/codebase/` contains a fresh audit (ARCHITECTURE / CONCERNS / STRUCTURE / CONVENTIONS / STACK / INTEGRATIONS / TESTING) from 2026-05-13. Reference throughout the rewrite to preserve institutional knowledge embedded in current patterns.

## Constraints

- **Tech stack** — macOS exclusively in v1 (all machines including servers); zsh as primary shell; go-task as orchestrator; Homebrew for packages
- **Platform support** — macOS (Apple Silicon and Intel); Linux deferred to v2+
- **Build approach** — parallel rewrite; new structure built from scratch, cut over only when feature parity achieved on all four target machines
- **AI-collaboration fit** — structure must let an AI agent reach correctness by reading manifests and following templates, not by inferring intent from filename suffixes
- **Security** — bootstrap must verify install integrity; no curl-to-shell without checksum; no secrets in repo; public SSH keys only
- **Idempotency** — every install task has a working `status:` check; re-running `task install` is a fast no-op
- **Performance** — interactive shell cold start under 200ms; `task install` re-run under 5s on a converged machine
- **Conventions** — no AI attribution in commits or source (no `Co-Authored-By`, no "generated by" comments); no emojis in non-markdown files

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Symlinks + TOML manifests over Nix | Nix conflicts with go-task lock-in, slows AI iteration; manifest layer captures the declarative win without language overhead | — Pending |
| Per-machine manifest with shared `defaults.toml` | Picked clarity (per-machine) over DRY (tags); 4 machines means defaults prevents pure duplication while machine files stay self-describing | — Pending |
| Explicit machine selection at setup | Hostname-based detection has bitten us; explicit selection beats clever auto-detect | — Pending |
| macOS-only in v1 (Linux deferred) | All four target machines are macOS (laptops + Mac servers); avoids cross-platform complexity until a real Linux machine enters scope; platform-aware directory split, apt/dnf manifests, and Linux bootstrap are deferred to v2 | — Pending |
| Keep v1 prompt; reject Starship | Existing alanpeabody-based `theme.zsh` is small, fast, and not on life support; Starship recommendation was based on a misread of the v1 prompt as Powerlevel10k | — Pending |
| Parallel rewrite with feature-parity cutover | All four target machines must be installable with v1 before flipping; preserves a working setup throughout | — Pending |
| Drop the `test` profile | Declared but never implemented; pure clutter | — Pending |
| Bootstrap without curl-to-shell | Removes supply-chain risk on every fresh install | — Pending |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself | — Pending |
| `task install` is the canonical entry; `task update` is an alias for the same task | Prevents the "add a package to update path, forget install, fresh machine breaks" drift class — single source of truth, single pipeline | — Pending |
| Five-tier testing: static lint, validate, reconcile, smoke, system | Each tier catches different drift; without verify+reconcile we'd ship "looks installed but isn't" or "symlink-soup-after-refactor" | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):

1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):

1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

*Last updated: 2026-05-17 -- Milestone v2.1 (Cleanup) started after v1.0 shipped (8 phases: manifest engine, install engine, shell layer, identity, packages, OS defaults, claude/tool-configs, validation+cutover). v2.1 prioritizes v1-drop audit before v1 removal after fresh-machine install surfaced silently-dropped /etc/zshenv writing.*
