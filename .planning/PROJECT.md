# Dotfiles (v2 Refactor)

## What This Is

Greenfield rewrite of the personal dotfiles repo at `/Users/josh/Git/personal/dotfiles`, built in parallel to the current implementation. Replaces the named-profile system (`personal` / `work` / `server` suffixed files) with explicit per-machine TOML manifests inheriting from a shared `defaults.toml`. Designed for macOS-first laptops and first-class Linux servers, with go-task orchestration, zsh as the primary shell, and symlink-based deployment. Optimized for AI-assisted maintenance: one concept per file, explicit manifests over implicit suffixing, predictable templates.

## Core Value

A single declarative manifest per machine makes the complete install state legible to both humans and AI agents — no inference from filename suffixes, no hidden profile branching, no hostname-based guessing.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — parallel rewrite, nothing shipped against the new structure)

### Active

<!-- v1 feature-parity targets, organized by capability. All requirements are hypotheses until shipped. -->

**Bootstrap and install:**

- [ ] One-shot fresh-install entry point (no curl-to-shell; go-task installed via Homebrew or verified checksum)
- [ ] Explicit machine selection at setup time (`task setup -- <machine-name>`); no hostname guessing
- [ ] Idempotent re-install — every install task has a working `status:` check
- [ ] `task validate` reports per-component health using check/cross symbols
- [ ] `task update` refreshes Homebrew, plugins, and AI tooling without re-running unchanged steps

**Manifest layer:**

- [ ] `defaults.toml` defines the shared baseline (packages, configs, features)
- [ ] `machines/<name>.toml` declares identity, features, package bundles, git/ssh identity, platform
- [ ] Machine manifest can override any `defaults.toml` key
- [ ] Manifest is parsed once at task evaluation and drives all subsequent install decisions
- [ ] Adding a new machine is a single new file in `machines/` plus `task setup`

**Shell (zsh):**

- [ ] `.zshenv` exports XDG vars and the selected machine identifier (replaces `DOTFILES_PROFILE`)
- [ ] `.zshrc` loads aliases and functions via glob (interactive only)
- [ ] `.zprofile` sets Homebrew shellenv and SSH agent socket — guarded for Linux servers
- [ ] One alias topic per file in `aliases/{common,darwin,linux,machine-specific}/`
- [ ] One function per file in `functions/{common,darwin,linux,machine-specific}/`
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
- [ ] Linux package manifest (apt/dnf bundle) for servers — first-class, not stripped-down
- [ ] Per-machine package additions allowed without forking a bundle

**macOS defaults:**

- [ ] Configurable via manifest features (each defaults group is opt-in)
- [ ] Idempotent (no re-running on every install — current `macos:shell` bug fixed)
- [ ] No-op on Linux machines

**Claude Code integration:**

- [ ] Global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills installed via go-task
- [ ] Hooks ported: secret-scan, no-emojis, no-ai-comments, agent-transparency (with shellcheck-clean rewrite)
- [ ] Claude marketplace and plugin install with a working `status:` guard (current `gsd-install` re-runs every time)

**Documentation and discoverability:**

- [ ] Top-level `README.md` maps the repo and explains the manifest model
- [ ] Each top-level directory has a `README.md` explaining purpose and how to add to it
- [ ] `CLAUDE.md` captures conventions for AI-assisted maintenance
- [ ] `docs/MIGRATION.md` records the cutover plan and old-to-new mapping

**Cutover:**

- [ ] All four machine categories (`personal-laptop`, `work-laptop`, `server-1`, `server-2`) installable from the new repo
- [ ] Feature parity confirmed via `task validate` per machine
- [ ] Old repo archived (not deleted) after final cutover

### Out of Scope

<!-- Explicit boundaries with reasoning. -->

- **Nix / home-manager** — evaluated; conflicts with go-task lock-in, slows AI iteration loop, Homebrew still needed for macOS GUI apps via `nix-darwin.homebrew` escape hatch. Declarative-manifest goal achieved via TOML at lower cost.
- **chezmoi / stow / yadm** — adds a tool dependency that overlaps with go-task; doesn't solve the profile rethink.
- **Cross-platform beyond macOS and Linux** — no Windows, no WSL.
- **Migrating away from zsh** — fish / nu / bash are out.
- **Replacing go-task** — locked.
- **Hostname-based machine detection** — burned us before (`.zprofile:55-56` bug). Explicit selection only.
- **Inline profile branching in shared files** — replaced by platform-aware directory layout and manifest-driven feature gates.
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

- **Tech stack** — macOS-first laptops, first-class Linux servers; zsh as primary shell; go-task as orchestrator; Homebrew on macOS, apt/dnf on Linux
- **Platform support** — macOS (Apple Silicon and Intel) + Linux (Debian/Ubuntu, Fedora) for servers
- **Build approach** — parallel rewrite; new structure built from scratch, cut over only when feature parity achieved on all four machine categories
- **AI-collaboration fit** — structure must let an AI agent reach correctness by reading manifests and following templates, not by inferring intent from filename suffixes
- **Security** — bootstrap must verify install integrity; no curl-to-shell without checksum; no secrets in repo; public SSH keys only
- **Idempotency** — every install task has a working `status:` check; re-running `task install` is a fast no-op
- **Performance** — interactive shell cold start under 200ms; `task install` re-run under 5s on a converged machine
- **Conventions** — no AI attribution in commits or source (no `Co-Authored-By`, no "generated by" comments); no emojis in non-markdown files

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Symlinks + TOML manifests over Nix | Nix conflicts with go-task lock-in, slows AI iteration; manifest layer captures the declarative win without language overhead | — Pending |
| Per-machine manifest with shared `defaults.toml` | Picked clarity (per-machine) over DRY (tags); 4+ machines means defaults prevents pure duplication while machine files stay self-describing | — Pending |
| Explicit machine selection at setup | Hostname-based detection has bitten us; explicit selection beats clever auto-detect | — Pending |
| First-class Linux on servers | Server is a real platform now, not opportunistic; needs platform-aware directory structure and dedicated package manifest | — Pending |
| Parallel rewrite with feature-parity cutover | All four machine categories must be installable with v1 before flipping; preserves a working setup throughout | — Pending |
| Drop the `test` profile | Declared but never implemented; pure clutter | — Pending |
| Bootstrap without curl-to-shell | Removes supply-chain risk on every fresh install | — Pending |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself | — Pending |

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

*Last updated: 2026-05-13 after initialization*
