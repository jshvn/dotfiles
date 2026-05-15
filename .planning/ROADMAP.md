# Roadmap: Dotfiles v2 Refactor

## Overview

Greenfield rewrite that replaces the named-profile filename suffixing with explicit per-machine TOML manifests inheriting from a shared `defaults.toml`. The journey starts by building the manifest engine and repository skeleton (the keystone every other phase reads from), then a hardened bootstrap and lint suite (so content is validated as it lands), then ports content layer-by-layer (shell, identity, packages with verification, OS defaults, Claude with hook smoke tests and tool configs with hardened helpers), and finishes by composing per-component validate tasks plus links reconciliation into a cutover gate that takes each machine from v1 to v2 individually. v1 stays fully working throughout; cutover is per-machine, not big-bang.

**Scope (v1):** macOS only. All four target machines (laptops + Mac servers) run macOS. Linux support is deferred to v2+ — flat `shell/aliases/` and `shell/functions/` for now, with platform-aware split reintroduced when a Linux machine enters scope.

**Testing tiers:** 0. Static (lint/syntax/shellcheck — Phase 2), 1. Validate (installed-state-matches-manifest — Phases 4, 5, 6, 8), 2. Reconcile (drift detect/cleanup — Phases 5, 7, 8), 3. Smoke (component functional tests — Phases 1, 7), 4. System (end-to-end on real machines — Phase 8).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Manifest Engine + Repository Skeleton** - TOML schema, deep-merge resolver, `resolved.json` cache, directory skeleton, AI-conventions doc
- [ ] **Phase 2: Install Engine — Bootstrap, Idempotency, Lint** - Hardened bootstrap, install=update unification, lint suite, twice-run timing gate, security trust-chain doc
- [ ] **Phase 3: Shell Layer — Flat Content Port** - `shell/` tree (flat aliases/functions), antidote swap, v1 theme ported as-is, all v1 aliases/functions ported, 200ms cold start
- [ ] **Phase 4: Identity Layer — Git + SSH per Machine** - Manifest-driven `includeIf` git config, `Include`-based SSH config, 1Password feature flag, identity validation
- [ ] **Phase 5: Packages Layer — Brewfile Composition + Verification** - Purpose-named bundles, manifest-driven composition, `brew bundle check` idempotency, post-install binary/cask verification, install-vs-declared drift audit
- [ ] **Phase 6: OS Defaults — macOS Configuration** - Per-concern defaults files, feature-flag gating, `defaults read` idempotency, `chsh` bug fix
- [ ] **Phase 7: Claude + Tool Configs + Smoke Tests** - Claude integration with bug-fixed hooks, GSD sentinel, marketplace status check, tool config symlinks, hardened `_:check-link`, hook smoke tests, root `task test`
- [ ] **Phase 8: Validation + Cutover Readiness** - Composed `task validate`, two-mode links reconcile, install-time orphan warning, per-machine cutover register + fresh-machine procedure, top-level README, MIGRATION.md, MACHINES.md

## Phase Details

### Phase 1: Manifest Engine + Repository Skeleton
**Goal**: A correct, tested manifest layer compiled once to `resolved.json` plus a documented repository skeleton — every downstream phase reads its inputs from this layer
**Depends on**: Nothing (first phase)
**Requirements**: MFST-01, MFST-02, MFST-03, MFST-04, MFST-05, MFST-06, MFST-07, MFST-08, MFST-09, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. `task setup -- personal-laptop` writes `$XDG_STATE_HOME/dotfiles/machine` and `task manifest:resolve` produces a `resolved.json` file at `$XDG_STATE_HOME/dotfiles/resolved.json`
  2. `task manifest:show` prints the post-merge structure (defaults + machine), and `task manifest:validate` exits non-zero when a required schema field (description, identity, features) is missing
  3. `task manifest:test` runs deep-merge fixtures covering map-over-map, list-replace, scalar-override, nested table, missing-key, and `extra_packages` concatenation cases — all pass
  4. Adding a fifth machine is exactly one new file under `manifests/machines/` plus `task setup -- <name>` (verified with a throwaway fixture machine)
  5. `docs/MANIFEST.md` and project-level `CLAUDE.md` (v2 conventions) are on disk; every top-level directory exists with a placeholder README
**Plans**: 4 plans
  - [x] 01-01-PLAN.md — Author six positive + two negative deep-merge test fixtures (the spec for Plan 02 resolver)
  - [x] 01-02-PLAN.md — Implement install/resolver.zsh + author defaults.toml + four machine manifests
  - [x] 01-03-PLAN.md — Build taskfiles/manifest.yml (setup, manifest:resolve, manifest:show, manifest:validate, manifest:test, manifest:test:add-machine)
  - [x] 01-04-PLAN.md — Replace repo-root CLAUDE.md (v2 conventions) + author docs/MANIFEST.md + five stub READMEs (shell/, identity/, packages/, configs/, os/)

### Phase 2: Install Engine — Bootstrap, Idempotency, Lint
**Goal**: A hardened bootstrap and an enforced idempotency contract so every install task is a fast no-op on re-run, every shell file is linted before content lands, and `task install` is the single canonical entry point (no separate update pipeline that can drift)
**Depends on**: Phase 1
**Requirements**: BTSP-01, BTSP-02, BTSP-03, BTSP-04, BTSP-05, BTSP-06, LINT-01, LINT-02, LINT-03, LINT-04, LINT-05, LINT-06, LINT-07, LINT-08, DOCS-07
**Success Criteria** (what must be TRUE):
  1. `./bootstrap.zsh` on a fresh macOS machine installs go-task via Homebrew (no `curl | sh`); re-running is a no-op at every step
  2. `task install` and `task update` resolve to the same idempotent task — verified by `task --list` and by running both commands in sequence with byte-identical output
  3. `task lint` exits non-zero when any taskfile uses `$VAR` inside a `status:` block, has `cmds:` without `status:`, or uses bare `ln -s` outside `helpers.yml`
  4. `task lint` exits non-zero when any executable `.zsh` file is missing `set -euo pipefail`; `task lint:portability` warns (non-blocking) when known portability-sensitive commands appear in flat shell directories (future-Linux hint)
  5. `zsh -n` runs as Tier-0 syntax test over every `.zsh` file in CI and exits non-zero on any parse error
  6. `task install` on a converged machine completes in under 5 seconds, measured by a CI timing test
  7. `docs/SECURITY.md` documents the bootstrap trust chain (what is downloaded, from where, how verified, and who is trusted)
**Plans**: 6 plans
  - [x] 02-01-PLAN.md — Lint suite (taskfiles/lint.yml: syntax, taskfile, shell-headers, portability — LINT-01..07)
  - [x] 02-02-PLAN.md — Stub taskfiles (links/brew/claude/macos) for Phase 3/5/6/7 placeholders
  - [x] 02-03-PLAN.md — Bootstrap rewrite (set -euo pipefail, brew/go-task/yq trust anchors with audit + 3s window — BTSP-01..03)
  - [x] 02-04-PLAN.md — Cutover-gate helper + Taskfile.yml rewrite (drop update:, add cutover-gate preconditions — BTSP-04, BTSP-06, LINT-08[deprecated per D-11])
  - [x] 02-05-PLAN.md — Lint fixtures (11 positive+negative cases) + lint:test-fixtures self-test runner
  - [x] 02-06-PLAN.md — docs/SECURITY.md bootstrap trust chain documentation (BTSP-05, DOCS-07)

### Phase 3: Shell Layer — Flat Content Port
**Goal**: A `shell/` tree with flat alias/function layout (macOS-only v1), v1 prompt ported as-is, antidote replacing antigen, and v1 shell content fully ported under a 200ms cold-start budget
**Depends on**: Phase 2
**Requirements**: SHEL-01, SHEL-02, SHEL-03, SHEL-04, SHEL-05, SHEL-06, SHEL-07, SHEL-08, SHEL-09, SHEL-10, SHEL-11, SHEL-12, DOCS-02
**Success Criteria** (what must be TRUE):
  1. A fresh interactive zsh shell on a target machine exports `$DOTFILES_MACHINE` from the state file, with no `$DOTFILES_PROFILE` anywhere in the environment
  2. `task perf:shell` measures cold interactive shell start under 200ms; CI fails if exceeded (down from the v1 ~500ms baseline) — primary lever is the antigen → antidote swap
  3. Every v1 alias is ported to flat `shell/aliases/<topic>.zsh`; every v1 function is ported to flat `shell/functions/<name>.zsh`; `zsh -n` passes on every function file
  4. v1 `zsh/theme.zsh` (alanpeabody-based) is ported as-is to `shell/theme.zsh`; antidote loads the static bundle file with no Antigen references anywhere in the repo
  5. MOTD output is cached to disk with a 24h TTL (no synchronous fastfetch on shell startup) and compinit uses a daily-rebuilt cache
  6. Every top-level directory has a `README.md` (purpose, key files, how-to-add-pattern) — pattern established by the `shell/` README and replicated across all sibling directories
**Plans**: 5 plans
  - [x] 03-01-PLAN.md — Manifest feature flags (ghostty/jgrid-net/macos-finder) + configs/antidote/zsh_plugins.txt
  - [x] 03-02-PLAN.md — Port 5 startup files (.zshenv/.zprofile/.zshrc/.zlogin/.zlogout) + shell/theme.zsh (antidote swap, compinit cache, hostname-bug fix)
  - [x] 03-03-PLAN.md — Port 23 function files (_dotfiles_feature helper + 22 v1 ports incl. cached motd for SHEL-11)
  - [x] 03-04-PLAN.md — Port 7 alias files (general/hardware/networking/dotfiles + gated finder/ghostty/jgrid)
  - [x] 03-05-PLAN.md — Wire taskfiles/links.yml + taskfiles/shell.yml (task perf:shell SHEL-12) + Taskfile.yml update + shell/README.md DOCS-02 anchor
**UI hint**: yes

### Phase 4: Identity Layer — Git + SSH per Machine
**Goal**: Manifest-driven git and SSH identity selection with no hostname literals or filename suffixes anywhere in the identity path
**Depends on**: Phase 3
**Requirements**: IDNT-01, IDNT-02, IDNT-03, IDNT-04, IDNT-05, IDNT-06, IDNT-07, IDNT-08
**Success Criteria** (what must be TRUE):
  1. Running `git config user.email` inside a path covered by `identity/git/identities/personal` returns the personal email; inside a work-identity path it returns the work email — selection driven by `includeIf gitdir:`, not by filename suffix
  2. `ssh -G <host>` resolves identity-specific options (User, IdentityFile, IdentityAgent) through `Include identity/ssh/identities/<active>` — selection driven by manifest, not by `Match exec`
  3. On a machine with `one-password-ssh = true` in its manifest, `echo $SSH_AUTH_SOCK` resolves to the 1Password agent socket; on a machine without the feature, it resolves to the system agent — with zero `hostname` references in any identity-determining code path
  4. `task validate` asserts `git config user.email` matches the manifest identity, that `ssh-add -L` lists the expected public key, and that `identity/ssh/keys/` contains only `.pub` files (no private keys committed)
  5. `taskfiles/identity.yml` reads the active identity from `resolved.json` and creates all identity symlinks through `_:safe-link` (no bare `ln`); re-running is a no-op
**Plans**: 7 plans (4 original + 3 gap-closure from 04-UAT.md)
  - [x] 04-01-PLAN.md — Schema layer: resolver enum + cross-field rules; defaults.toml + four machine TOMLs + docs/MANIFEST.md (D-05/D-07/D-15/D-16)
  - [x] 04-02-PLAN.md — Identity content: identity/git/ + identity/ssh/ trees (v1 port + documented deltas; IDNT-01/02/03/04/06)
  - [x] 04-03-PLAN.md — Negative fixtures + manifest:test extension (three new fixtures; negative_count=5)
  - [x] 04-04-PLAN.md — taskfiles/identity.yml + Taskfile.yml/links.yml wiring + identity/README.md (IDNT-07/08, DOCS-02)
  - [x] 04-05-PLAN.md — Drop redundant manifest: prefix and absolute-form identity dep (UAT gaps 1+3; IDNT-07/08)
  - [x] 04-06-PLAN.md — One-hop RESOLVED_JSON_PATH avoids include-vars eval gap (UAT gap 2; IDNT-08)
  - [x] 04-07-PLAN.md — Probe validate:git from real subrepo via find + rev-parse (UAT gap 4; IDNT-07)

### Phase 5: Packages Layer — Brewfile Composition + Verification
**Goal**: Per-purpose Brewfile bundles composed per-machine from the manifest, with idempotent install via `brew bundle check` AND post-install verification that declared binaries/casks are actually usable, plus a drift audit
**Depends on**: Phase 4
**Requirements**: PKGS-01, PKGS-02, PKGS-03, PKGS-04, PKGS-05, VRFY-01, VRFY-02, VRFY-03, VRFY-04
**Success Criteria** (what must be TRUE):
  1. `task packages:install` composes the per-machine Brewfile from the bundles listed in `resolved.json` (`packages.brew.bundles` plus per-machine `extra_packages`) and writes it to a known cache path
  2. `task packages:install` on a converged machine is a no-op because `brew bundle check --file=<composed>` returns clean (sub-second `status:` check, no full `brew bundle` run)
  3. Bundles are named by purpose (`core.rb`, `gui.rb`, `dev.rb`, `ops.rb`, `personal.rb`) — no `Brewfile-<profile>.rb` files anywhere; a Mac server machine can decline GUI bundles via manifest and its composed Brewfile contains no casks; per-machine `extra_packages` adds a one-off tool without forking a bundle
  4. `task packages:verify` reads the active machine's bundles, parses `# verify: <name>` per-line comments (default: bin name = formula name; app name derived from cask name), and asserts `command -v <bin>` resolves for every formula and `/Applications/<App>.app` exists for every cask — exits non-zero with a per-package check/cross report on failure
  5. `task packages:audit` lists currently-installed brew formulae and casks that are NOT declared in any manifest bundle for the active machine — non-blocking by default; `--strict` exits non-zero. Surfaces the "I `brew install`'d something manually and forgot to declare it" drift class.
  6. `task install` runs `task packages:verify` in its final step so a successful install fails loudly when a declared package didn't actually land (silent install failures caught at the verification layer, not just at the bundle layer)
**Plans**: 6 plans
  - [ ] 05-01-PLAN.md — packages/core.rb + packages/gui.rb + packages/README.md (PKGS-01, PKGS-05)
  - [ ] 05-02-PLAN.md — Manifest TOML migration: defaults + 4 machines to typed-bucket extras (PKGS-04, PKGS-05)
  - [ ] 05-03-PLAN.md — install/compose-brewfile.zsh + resolver Pass 2 update (PKGS-02, PKGS-03, PKGS-04)
  - [ ] 05-04-PLAN.md — taskfiles/packages.yml (install/compose/verify/audit/validate) (PKGS-02, PKGS-03, PKGS-05, VRFY-01, VRFY-02, VRFY-03)
  - [ ] 05-05-PLAN.md — Root Taskfile.yml integration: rename brew include to packages; add packages:verify final step (VRFY-04)
  - [ ] 05-06-PLAN.md — Canonical docs corrections: REQUIREMENTS PKGS-01/04, ROADMAP SC#3, PROJECT, docs/MANIFEST.md (PKGS-01, PKGS-04)

### Phase 6: OS Defaults — macOS Configuration
**Goal**: macOS defaults split into per-concern files, opt-in via manifest features, idempotent on every run
**Depends on**: Phase 5
**Requirements**: OSCF-01, OSCF-02, OSCF-03, OSCF-04, OSCF-05
**Success Criteria** (what must be TRUE):
  1. On a machine with `features.macos-defaults.dock = true`, `task macos:defaults:dock` writes the configured dock keys; on a machine without the feature, the task is a no-op (skipped at the feature-gate level)
  2. Re-running `task macos:defaults` on a converged machine performs zero `defaults write` operations because each task's `status:` reads `defaults read <domain> <key>` first and matches the manifest value
  3. `task macos:shell` uses `{{.BREW_ZSH}}` (template var) in its `status:` check — not `$BREW_ZSH` (shell var) — and re-running on a converged machine is a no-op (live v1 bug fixed structurally)
  4. A Mac server machine that declines GUI defaults (dock, finder, screenshots) installs cleanly with those tasks gated off; only `shell-registration.zsh` and `security.zsh` run
  5. `task validate` reads current `defaults` values for declared keys and asserts them against the manifest's expected values for the active machine
**Plans**: TBD

### Phase 7: Claude + Tool Configs + Smoke Tests
**Goal**: Claude Code integration with shellcheck-clean hooks AND runtime hook smoke tests, idempotent GSD/marketplace install, tool config symlinks via hardened `_:safe-link` and `_:check-link` (target-match enforced), and a root `task test` aggregator
**Depends on**: Phase 6
**Requirements**: CLDE-01, CLDE-02, CLDE-03, CLDE-04, TOOL-01, TOOL-02, TOOL-03, TOOL-04, TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. `task claude:install` installs the global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills via `taskfiles/claude.yml`; re-running is a no-op
  2. `task claude:gsd` uses a version-pinned sentinel file as its `status:` check — `npx` is invoked only when the pinned version is missing, not on every `task install`. `task claude:marketplace` uses `claude plugin list` parsing as its `status:` check and is a no-op when expected plugins are already installed.
  3. All four hooks (`secret-scan.zsh`, `no-emojis.zsh`, `no-ai-comments.zsh`, `agent-transparency.zsh`) pass `shellcheck` with zero errors — `agent-transparency.zsh` no longer uses `local` at script scope
  4. `task test:hooks` pipes synthetic JSON input through every Claude hook and asserts expected exit code (0 for pass/warn, 2 for block) plus expected stderr pattern; failures surface the regression class that `shellcheck` cannot catch (logic bugs, regex changes, missing `set -euo pipefail` side effects)
  5. Root `task test` aggregates `task manifest:test` (deep-merge fixtures from Phase 1) and `task test:hooks` so a single command runs all smoke tests; CI wires this in alongside `task lint`
  6. Every tool config (Ghostty, glow, trippy, tlrc, conda, eza, motd) is symlinked through `_:safe-link` from `configs/<tool>/` to its destination; `_:safe-link` verifies target type and refuses to clobber an incompatible target
  7. `_:check-link` enforces all three conditions: symlink exists, target resolves (non-broken), AND `readlink -f` equals the manifest-expected source path — mismatch fails the check (catches "symlink exists but points to stale path after refactor")
**Plans**: TBD

### Phase 8: Validation + Cutover Readiness
**Goal**: A composed `task validate`, two-mode `task links:reconcile` (detect + cleanup), install-time orphan warning, and per-machine cutover gate with a documented fresh-machine verification procedure
**Depends on**: Phase 7
**Requirements**: CUTV-01, CUTV-02, CUTV-03, CUTV-04, CUTV-05, CUTV-06, CUTV-07, CUTV-08, DOCS-01, DOCS-05, DOCS-06, DOCS-08
**Success Criteria** (what must be TRUE):
  1. Root `task validate` composes every per-component validate task (manifest, identity, packages, packages:verify, macos, claude, tool configs) and prints check/cross output per component on every machine
  2. `task links:reconcile` (default mode) lists every symlink pointing into `$DOTFILEDIR` that is not declared in the manifest (orphan detection) and exits non-zero in CI — no destructive action; safe to run unattended
  3. `task links:reconcile -- --remove` enters interactive cleanup: for each orphan, prompts y/N before deleting; never deletes silently. `task install` also runs `task links:reconcile` in detect-only mode at the end and prints a warning (non-fatal) when orphans exist — surfaces "you moved a link, the old one is dangling" feedback at install time.
  4. All four target macOS machines (`personal-laptop`, `work-laptop`, `server-1`, `server-2` — all macOS, mixed roles) install end-to-end from v2 with a 100% `task validate` pass — recorded in `docs/CUTOVER.md`; per-machine fresh-install verification procedure (manual steps for a clean Mac) documented in the same file (DOCS-08)
  5. Each machine runs v2 for at least 7 days without falling back to v1 before being declared cut over; `docs/CUTOVER.md` tracks per-machine state
  6. After the last machine cuts over, the v1 repo is archived (renamed, not deleted) and `docs/MIGRATION.md`, `docs/MACHINES.md`, and the top-level `README.md` are finalized with the v1-to-v2 mapping, per-machine purpose/identity, and the manifest-model explanation
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Manifest Engine + Repository Skeleton | 0/4 | Planned | - |
| 2. Install Engine — Bootstrap, Idempotency, Lint | 0/TBD | Not started | - |
| 3. Shell Layer — Flat Content Port | 0/TBD | Not started | - |
| 4. Identity Layer — Git + SSH per Machine | 4/7 | Gap closure planned | - |
| 5. Packages Layer — Brewfile Composition + Verification | 0/6 | Planned | - |
| 6. OS Defaults — macOS Configuration | 0/TBD | Not started | - |
| 7. Claude + Tool Configs + Smoke Tests | 0/TBD | Not started | - |
| 8. Validation + Cutover Readiness | 0/TBD | Not started | - |
