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
- [x] **Phase 7: Claude + Tool Configs + Smoke Tests** - Claude integration with bug-fixed hooks, GSD sentinel, marketplace status check, tool config symlinks, hardened `_:check-link`, hook smoke tests, root `task test` (completed 2026-05-16)
- [x] **Phase 8: Validation + Cutover Readiness** - Composed `task validate`, two-mode links reconcile, install-time orphan warning, per-machine cutover register + fresh-machine procedure, top-level README, MIGRATION.md, MACHINES.md (completed 2026-05-16)

## v2.1 Milestone Phases

Milestone v2.1 (Cleanup) continues the phase sequence from v1.0. Phases are numbered 9 through 14 — there is no reset. v2.1 is a cleanup milestone: no net-new features, six phases ordered audit-first so the v1 leftover files (the source-of-truth for what was dropped) are read in full before any deletion happens. The driving live finding is the `/etc/zshenv` `ZDOTDIR` write — v1 `taskfiles/common.yml` `zdotdir:` task wrote `export ZDOTDIR="$HOME/.config/zsh"` to `/etc/zshenv` via sudo; v2 silently dropped this, producing a non-functional first shell on fresh machines. Phase 9 audits for siblings of this bug class; Phase 10 implements every keep; Phase 11 then removes the v1 files; Phases 12–14 polish the resulting surface.

- [x] **Phase 9: v1-Drop Audit** - Read-only enumeration of every v1 leftover taskfile, install asset, `zsh/` tree content, and doc; produces `AUDIT.md` keep/drop classification with v2 owner column (completed 2026-05-17)
- [x] **Phase 10: v1-Drop Remediation** - Implement every "keep" from `AUDIT.md`; `/etc/zshenv` `ZDOTDIR` write lands first; fresh-machine install produces a fully-functional first shell (completed 2026-05-18)
- [x] **Phase 11: v1 Removal** - Delete v1 leftover taskfiles, `zsh/` tree, `install/Brewfile*`, cutover infrastructure; simplify `Taskfile.yml`; purge v1 references from docs (completed 2026-05-18)
- [x] **Phase 12: Task Surface Redesign** - Audit every `task --list` entry; classify keep/rename/internal/remove; apply renames; mark internal tasks `internal: true` (completed 2026-05-18)
- [ ] **Phase 13: Code Review + Dead-Code Cleanup** - Language-aware repo-wide review (zsh shellcheck, taskfile lint, TOML schema); HIGH fixed; dead code removed; duplicated logic consolidated; `links:*` target-match bug fixed
- [ ] **Phase 14: Comment + Doc Trim** - Strip excess inline taskfile comments to WHY-only; slim per-file header banners; dedupe `README.md` / `CLAUDE.md` / `.claude/CLAUDE.md`; remove obsolete docs

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
  3. Bundles are named by purpose (`core.rb`, `gui.rb`, and any future purpose-named additions) -- no `Brewfile-<profile>.rb` files anywhere; per-machine variation lives in `extra_packages` typed sub-table (`formulae`/`casks`/`mas`), not in bundle files; a Mac server machine can decline GUI bundles via manifest and its composed Brewfile contains no casks.
  4. `task packages:verify` reads the active machine's bundles, parses `# verify: <name>` per-line comments (default: bin name = formula name; app name derived from cask name), and asserts `command -v <bin>` resolves for every formula and `/Applications/<App>.app` exists for every cask — exits non-zero with a per-package check/cross report on failure
  5. `task packages:audit` lists currently-installed brew formulae and casks that are NOT declared in any manifest bundle for the active machine — non-blocking by default; `--strict` exits non-zero. Surfaces the "I `brew install`'d something manually and forgot to declare it" drift class.
  6. `task install` runs `task packages:verify` in its final step so a successful install fails loudly when a declared package didn't actually land (silent install failures caught at the verification layer, not just at the bundle layer)
**Plans**: 8 plans (6 original + 2 gap-closure from 05-UAT.md Gaps 2 + 3)
  - [x] 05-01-PLAN.md — packages/core.rb + packages/gui.rb + packages/README.md (PKGS-01, PKGS-05)
  - [x] 05-02-PLAN.md — Manifest TOML migration: defaults + 4 machines to typed-bucket extras (PKGS-04, PKGS-05)
  - [x] 05-03-PLAN.md — install/compose-brewfile.zsh + resolver Pass 2 update (PKGS-02, PKGS-03, PKGS-04)
  - [x] 05-04-PLAN.md — taskfiles/packages.yml (install/compose/verify/audit/validate) (PKGS-02, PKGS-03, PKGS-05, VRFY-01, VRFY-02, VRFY-03)
  - [x] 05-05-PLAN.md — Root Taskfile.yml integration: rename brew include to packages; add packages:verify final step (VRFY-04)
  - [x] 05-06-PLAN.md — Canonical docs corrections: REQUIREMENTS PKGS-01/04, ROADMAP SC#3, PROJECT, docs/MANIFEST.md (PKGS-01, PKGS-04)
  - [x] 05-07-PLAN.md — Strip per-line `# verify:` comments + per-cask `verify` field from bundles, manifests, resolver/composer comments, docs (Gap 2 schema/code/docs; VRFY-01, VRFY-02, PKGS-04, DOCS-02)
  - [x] 05-08-PLAN.md — Rewrite `verify` task body to brew-info-driven two-layer model + `silent: false` task-level override (Gaps 2 + 3; VRFY-01, VRFY-02, VRFY-03, VRFY-04)

### Phase 6: OS Defaults — macOS Configuration
**Goal**: macOS defaults split into per-concern files, opt-in via manifest features, idempotent on every run
**Depends on**: Phase 5
**Requirements**: OSCF-01, OSCF-02, OSCF-03, OSCF-04, OSCF-05
**Success Criteria** (what must be TRUE):
  1. On a machine with `features.macos-dock = true`, `task macos:defaults:dock` writes the configured dock keys; on a machine without the feature, the task is a no-op (skipped at the feature-gate level)
  2. Re-running `task macos:defaults` on a converged machine performs zero `defaults write` operations because each task's `status:` reads `defaults read <domain> <key>` first and matches the manifest value
  3. `task macos:shell` uses `{{.BREW_ZSH}}` (template var) in its `status:` check — not `$BREW_ZSH` (shell var) — and re-running on a converged machine is a no-op (live v1 bug fixed structurally)
  4. A Mac server machine that declines GUI defaults (dock, finder, screenshots) installs cleanly with those tasks gated off; only `shell-registration.zsh` and `security.zsh` run
  5. `task validate` reads current `defaults` values for declared keys and asserts them against the in-script expected values for each enabled concern
**Plans**: 4 plans
  - [x] 06-01-PLAN.md — Manifest schema: defaults.toml +4 macos-* keys + server-{1,2}.toml macos-security = true (OSCF-02)
  - [x] 06-02-PLAN.md — Five os/defaults/<concern>.zsh sourced scripts + os/shell-registration.zsh + os/README.md DOCS-02 (OSCF-01, OSCF-03, OSCF-04)
  - [x] 06-03-PLAN.md — taskfiles/macos.yml real bodies + Taskfile.yml include flip + ROADMAP/REQUIREMENTS/docs/MANIFEST.md amends (OSCF-01..05; structural fix for v1 macos:shell:145 bug class)
  - [x] 06-04-PLAN.md — 06-HUMAN-UAT.md manual UAT plan: 5 tests (LINT-02 static, server-mode install, laptop-mode round-trip, deliberate-drift validate, lint regression) (OSCF-03/04/05)

### Phase 7: Claude + Tool Configs + Smoke Tests
**Goal**: Claude Code integration with shellcheck-clean hooks AND runtime hook smoke tests, idempotent GSD/marketplace install, tool config symlinks via hardened `_:safe-link` and `_:check-link` (target-match enforced), and a root `task test` aggregator
**Depends on**: Phase 6
**Requirements**: CLDE-01, CLDE-02, CLDE-03, CLDE-04, TOOL-01, TOOL-02, TOOL-03, TOOL-04, TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. `task claude:install` installs the global `CLAUDE.md`, `settings.json`, hooks, agents, commands, and skills via `taskfiles/claude.yml`; re-running is a no-op
  2. `task claude:gsd` uses a presence sentinel file as its `status:` check — `npx` is invoked only when the sentinel is absent, not on every `task install`. An explicit `task claude:update` deletes the sentinel and re-runs `npx`. `task claude:marketplace` uses `claude plugin list` parsing as its `status:` check and is a no-op when expected plugins are already installed.
  3. All four hooks (`secret-scan.zsh`, `no-emojis.zsh`, `no-ai-comments.zsh`, `agent-transparency.zsh`) pass `shellcheck` with zero errors — `agent-transparency.zsh` no longer uses `local` at script scope
  4. `task test:hooks` pipes synthetic JSON input through every Claude hook and asserts expected exit code (0 for pass/warn, 2 for block) plus expected stderr pattern; failures surface the regression class that `shellcheck` cannot catch (logic bugs, regex changes, missing `set -euo pipefail` side effects)
  5. Root `task test` aggregates `task manifest:test` (deep-merge fixtures from Phase 1) and `task test:hooks` so a single command runs all smoke tests; CI wires this in alongside `task lint`
  6. Every tool config (Ghostty, glow, trippy, tlrc, conda, eza, motd) is symlinked through `_:safe-link` from `configs/<tool>/` to its destination; `_:safe-link` verifies target type and refuses to clobber an incompatible target
  7. `_:check-link` enforces all three conditions: symlink exists, target resolves (non-broken), AND `readlink -f` equals the manifest-expected source path — mismatch fails the check (catches "symlink exists but points to stale path after refactor")
**Plans**: 6 plans
  - [x] 07-01-PLAN.md — Pre-Phase-7 cleanup: drop GSD-managed artifacts + .gitignore + REQUIREMENTS/ROADMAP wording amend (D-02, D-09)
  - [x] 07-02-PLAN.md — Harden _:safe-link (TOOL-03) + _:check-link strict mode (TOOL-04) + rewrite agent-transparency.zsh (CLDE-02)
  - [x] 07-03-PLAN.md — Real taskfiles/claude.yml (install/marketplace/gsd/update/status/validate/ensure-cli) + root include flip + claude/README.md (CLDE-01/03/04)
  - [x] 07-04-PLAN.md — install/test-hooks.zsh runner + taskfiles/test.yml + root `task test` aggregator (TEST-01, TEST-02)
  - [x] 07-05-PLAN.md — Port seven tool configs to configs/<tool>/ with per-tool READMEs + aggregate configs/README.md (TOOL-02)
  - [x] 07-06-PLAN.md — Extend taskfiles/links.yml with claude: + configs: sub-tasks; retrofit validate with SOURCE strict mode (CLDE-01, TOOL-01, TOOL-02, TOOL-04)

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
**Plans**: 6 plans
  - [x] 08-01-PLAN.md — taskfiles/links.yml EXPECTED_TARGETS refactor + links:validate exit-code fix (CUTV-02 foundation)
  - [x] 08-02-PLAN.md — Root `task validate` aggregator in Taskfile.yml + D-06 feature-off sentinel (CUTV-01)
  - [x] 08-03-PLAN.md — links:reconcile two-mode task + install-time orphan warn + cutover:ack writer (CUTV-02, CUTV-07, CUTV-08)
  - [x] 08-04-PLAN.md — docs/CUTOVER.md (procedure + state table) + docs/MACHINES.md (CUTV-03, DOCS-06, DOCS-08)
  - [x] 08-05-PLAN.md — docs/MIGRATION.md (per-concept + rollback + archive) + root README.md replacement (DOCS-01, DOCS-05)
  - [x] 08-06-PLAN.md — Per-machine cutover execution + 7-day soak per machine + v1 archive (CUTV-04, CUTV-05, CUTV-06) — autonomous: false

### Phase 9: v1-Drop Audit
**Goal**: Every v1 leftover file (taskfile, install asset, `zsh/` tree content, doc) is read in full and every dropped feature is classified keep/drop/already-ported in a single `AUDIT.md` report with v2 owner column — read-only investigation; zero code changes in this phase
**Depends on**: Phase 8
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04, AUDIT-05
**Success Criteria** (what must be TRUE):
  1. `.planning/phases/09-v1-drop-audit/AUDIT.md` exists and enumerates every task defined in every v1 leftover taskfile (`taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/brew.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/claude-stub.yml`, `taskfiles/brew-stub.yml`, `taskfiles/links-stub.yml`, `taskfiles/macos.v1.yml.bak`) with: source file:line range, task purpose (one sentence), v2 status (ported / partially-ported / dropped), keep/drop classification, rationale, and v2 owner file
  2. Every v1 install asset (`install/Brewfile*`, plus any `install/*.zsh` not part of the v2 set) is enumerated in `AUDIT.md` with the same six-column shape; the live `/etc/zshenv` `ZDOTDIR` finding from `taskfiles/common.yml:36-57` is captured as a "keep" item with `taskfiles/shell.yml` (or equivalent) as the proposed v2 owner
  3. The v1 `zsh/` tree is compared file-by-file against v2 `shell/`; any alias file, function file, theme line, or `.zshrc` block present in v1 and absent from v2 is captured as a row in `AUDIT.md` — comparison is verified by `diff -rq zsh/ shell/` (interpreted, not raw) and a manual `zsh/aliases/` walkthrough cross-referenced against `shell/aliases/`
  4. Every v1-only doc fragment (notes in v1 READMEs, `install/README.md`, `docs/` content not present in v2 `docs/`) is reviewed; substantive content the v2 docs do not carry is logged in `AUDIT.md` for Phase 10 / Phase 14 disposition
  5. Cross-reference grep proves no v1 feature is missed: `grep -rh '^[[:space:]]*[a-z][a-z0-9:-]*:' taskfiles/common.yml taskfiles/profile.yml taskfiles/brew.yml taskfiles/profile-tasks.yml taskfiles/*-stub.yml taskfiles/macos.v1.yml.bak` produces a task-name list, and every name in that list appears in `AUDIT.md` (the audit is a superset of the grep output)
**Plans**: TBD

### Phase 10: v1-Drop Remediation
**Goal**: Every "keep" item from Phase 9's `AUDIT.md` is implemented in v2 in the file the audit named as the v2 owner; fresh-machine install produces a fully-functional first shell (prompt, theme, aliases, functions, MOTD, `_dotfiles_feature`) without manual remediation
**Depends on**: Phase 9
**Requirements**: PORT-01, PORT-02, PORT-03
**Success Criteria** (what must be TRUE):
  1. A v2 task writes `/etc/zshenv` with `export ZDOTDIR="$HOME/.config/zsh"` during `task install`; the task has a working `status:` block that exits zero when the line is already present (no re-running on every invocation); a fresh `task install` on a machine without `/etc/zshenv` writes the file via `sudo` and re-running is a no-op
  2. Every "keep" row in `AUDIT.md` has a corresponding committed change in the v2 owner file; the `AUDIT.md` row is annotated with the commit SHA (or PLAN reference) that implemented it; zero "keep" rows remain unimplemented when Phase 10 closes
  3. A fresh-machine smoke procedure (run on a clean macOS machine OR a documented synthetic equivalent) confirms: a brand-new terminal opens, `$ZDOTDIR` is exported, the antidote prompt renders, `alias` lists the ported aliases, `which _dotfiles_feature` resolves, `motd` prints, and no v1 fallback is needed at any step — procedure and pass result recorded in `.planning/phases/10-v1-drop-remediation/10-SMOKE.md`
  4. No PORT item is outstanding when Phase 10 closes: `AUDIT.md`'s keep-list and the implemented-set match exactly; this is the gate before Phase 11 deletes the v1 source-of-truth files
**Plans**: 1 plan
  - [x] 10-01-PLAN.md — Phase 10 single-plan implementation: PORT-01 (links.yml zdotdir task + outer status extension), PORT-02 (shell.yml validate task + Taskfile.yml dual-alias include + aggregator wiring), AUDIT.md row 3 amend (D-07), 10-SMOKE.md (PORT-03)

### Phase 11: v1 Removal
**Goal**: Every v1 leftover is removed from the repo after Phase 10 proves no live dependency remains; `Taskfile.yml` is simplified; cutover infrastructure (gate, ack task, docs) is retired; `task install` on a clean machine succeeds without any cutover-ack step
**Depends on**: Phase 10
**Requirements**: RMV-01, RMV-02, RMV-03, RMV-04, RMV-05, RMV-06, RMV-07
**Success Criteria** (what must be TRUE):
  1. The eight v1 leftover taskfiles are deleted from the repo: `taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/brew.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/claude-stub.yml`, `taskfiles/brew-stub.yml`, `taskfiles/links-stub.yml`, `taskfiles/macos.v1.yml.bak` — verified by `ls taskfiles/` showing only v2 files
  2. The v1 `zsh/` directory is deleted (`shell/` is the only shell-content tree); `install/Brewfile*` files are deleted (`packages/<purpose>.rb` is the only Brewfile source); verified by `test ! -d zsh/` and `find install -name 'Brewfile*' -print` returning empty
  3. Cutover infrastructure is fully removed: `install/cutover-gate.zsh` is deleted, the `cutover:ack` task is removed from `Taskfile.yml`, the `cutover_gate_check` precondition is removed from the `install` task, `docs/CUTOVER.md` is deleted, and `docs/MIGRATION.md` either deletes its cutover-specific sections or is itself removed (final form decided per AUDIT-05 in Phase 9); the per-machine 7-day-soak model is retired entirely
  4. `Taskfile.yml` is simplified: the "v1 leftover taskfiles" comment block (`Taskfile.yml:22-26` at v2.1 start) is removed; the include list contains only real v2 taskfiles; no v1 file path appears anywhere in the file
  5. `git grep -E '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover'` returns only references the operator has deliberately kept (e.g., a single "what changed from v1" doc line, if any); the project-level `CLAUDE.md`, `.claude/CLAUDE.md`, top-level `README.md`, and `docs/` tree carry no operational v1 references
  6. `task install` on a clean machine (or a documented synthetic equivalent) succeeds end-to-end with no `cutover:ack` step, no manual gate, no v1 path reference, and no missing-file error from a deleted v1 leftover
**Plans**: 1 plan
  - [x] 11-01-PLAN.md — Single-plan v1 removal: simplify Taskfile.yml + bootstrap.zsh (RMV-04/05), delete install/cutover-gate.zsh + 8 v1 taskfiles + zsh/ tree + 4 v1 Brewfiles + docs/CUTOVER.md + docs/MIGRATION.md (RMV-01..04), rewrite README.md fresh-install (RMV-06/D-09), scrub doc drift in docs/SECURITY.md + taskfiles/lint.yml + taskfiles/README.md (D-08), rewrite LINT-05 citations in 6 os/*.zsh files (D-06), write 11-VERIFICATION.md with steady-state install capture + SC#5 grep gate report (RMV-07/D-05)

### Phase 12: Task Surface Redesign
**Goal**: Every task listed by `task --list` is reviewed and curated; renames are applied across all included taskfiles and docs; internal-only tasks are hidden via `internal: true`; the bare `task` invocation prints the final curated surface
**Depends on**: Phase 11
**Requirements**: SURF-01, SURF-02, SURF-03, SURF-04
**Success Criteria** (what must be TRUE):
  1. A written classification table (committed under `.planning/phases/12-task-surface-redesign/`) records every task currently listed by `task --list` with a verdict — keep-as-is / rename-to-X / mark-internal / remove — and a one-line rationale per row; no task is left unclassified
  2. Every "rename" verdict is applied: the task name is changed in its source taskfile, every call site in `Taskfile.yml` / included taskfiles / shell aliases is updated to the new name, every doc reference (README, CLAUDE.md, docs/*) is updated, and `task --list` after the change reflects the new name
  3. Every "mark-internal" verdict applies `internal: true` to the task; running `task --list` does not show those tasks; running them directly (`task <internal-name>`) is documented in the source taskfile as "internal — invoked by <caller>" but is not surfaced to the operator
  4. The bare `task` invocation prints the final curated list with operator-friendly descriptions (no leaked internals, no v1 names); the top-level `README.md` and project `CLAUDE.md` reference the canonical surface as the single source-of-truth for "what can I run"
**Plans**: 8 plans
  - [x] 12-01-PLAN.md — Author SURFACE.md classification table (SURF-01 deliverable; six-column shape; pre-populated callsites)
  - [x] 12-02-PLAN.md — Drop perf: include alias + rename shell:shell -> shell:startup-time + mark shell:validate internal (D-05/06/07)
  - [x] 12-03-PLAN.md — Rename links:all -> links:install + sub-targets to install-<target> + audit:links delegate via new taskfiles/audit.yml (D-09/10/02)
  - [x] 12-04-PLAN.md — Rename identity sub-targets to install-<target> + mark all internal (D-01/10/11)
  - [x] 12-05-PLAN.md — Add macos:install aggregator + rename macos:defaults -> apply-defaults + macos:shell -> install-shell + collapse install body (D-09/10)
  - [x] 12-06-PLAN.md — Mark packages + claude tasks internal + add audit:packages / show:claude / refresh:claude delegates (D-01/02/03)
  - [x] 12-07-PLAN.md — Mark manifest tasks internal + move manifest:test* -> taskfiles/test.yml as test:manifest + test:add-machine + mark test/lint sub-checks internal + doc updates (D-01/02/03/04)
  - [x] 12-08-PLAN.md — Rewrite default: banner to two-tier curated surface + add lint:banner-parity check + paired fixtures (D-12/13)

### Phase 13: Code Review + Dead-Code Cleanup
**Goal**: A repo-wide code review run by language-aware reviewers produces a HIGH/MEDIUM/LOW finding list; HIGH is fixed in this phase, dead code is removed, duplicated logic is consolidated, and the `links:*` target-match status-block bug is fixed before Phase 14 touches `links.yml`
**Depends on**: Phase 12
**Requirements**: REVW-01, REVW-02, REVW-03, REVW-04, REVW-05, REVW-06
**Success Criteria** (what must be TRUE):
  1. A review report (committed at `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md`) enumerates every finding with file:line, severity (HIGH/MEDIUM/LOW), category (correctness / portability / security / clarity / dead-code / duplication), and a one-line remediation; review uses language-aware reviewers (zsh / shellcheck, taskfile lint, TOML schema) per global instruction "Always use the language-specific reviewer agent if exists"
  2. Every HIGH-severity finding in `REVIEW.md` is fixed in this phase; the finding row is annotated with the commit SHA or PLAN reference that closed it; MEDIUM and LOW findings each carry a verdict — "fix now" / "defer with rationale" — with explicit rationale for each defer
  3. Dead code is removed: unused functions, dead branches, unreachable code, helpers with zero call sites — verified by `grep -r '<symbol>' --include='*.zsh' --include='*.yml'` returning zero hits for every removed symbol; the removal commit lists each symbol it dropped
  4. The `links:*` status blocks verify each symlink's target (`readlink -f` equals the manifest-expected source path), not just its existence; after the fix, a deliberately corrupted symlink (pointing to a wrong source) forces a re-link on next `task install` — verified via a manual test recorded in `.planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md`
  5. `task lint`, `task lint:taskfile`, every `shellcheck` invocation, and `task test` (manifest fixtures + hook fixtures) all pass green after every fix lands; any test fixture exercising removed v1 code is updated or removed (no orphan fixtures left behind)
**Plans**: 6 plans
  - [x] 13-01-PLAN.md — Review pass: four parallel ecc:code-reviewer spawns (zsh/YAML/TOML/aux); merge into 13-REVIEW.md; amend ROADMAP SC#1/SC#4 path (REVW-01)
  - [ ] 13-02-PLAN.md — HIGH-severity fixes: apply remediations per REVIEW.md HIGH rows; annotate with closing short-SHAs (REVW-02, REVW-06)
  - [ ] 13-03-PLAN.md — Dead-code removal: Class A preserved, Class B strict per D-08; orphan fixtures per D-10; grep-verified zero hits (REVW-03, REVW-06)
  - [ ] 13-04-PLAN.md — Duplication consolidation: rule-of-three per D-09; new helpers in taskfiles/helpers.yml or install/messages.zsh (REVW-04, REVW-06)
  - [ ] 13-05-PLAN.md — links:* readlink -f target-match fix (helper path preferred via pre-flight); 13-SMOKE.md manual procedure per D-07 (REVW-05, REVW-06)
  - [ ] 13-06-PLAN.md — MEDIUM/LOW triage: fix-now annotated with SHA; defer per D-11(a) Phase 14 TRIM-NN or D-11(b) needs-new-infra + ROADMAP backlog (REVW-02, REVW-06)

### Phase 14: Comment + Doc Trim
**Goal**: Inline taskfile comments are reduced to WHY-only; per-file header banners are slimmed to purpose + dependencies + side effects; READMEs (`README.md`, `CLAUDE.md`, `.claude/CLAUDE.md`) are deduped so each piece of info has a single canonical home; obsolete docs are removed; the codebase reads cleanly for a new contributor with zero v2-history context
**Depends on**: Phase 13
**Requirements**: TRIM-01, TRIM-02, TRIM-03, TRIM-04, TRIM-05
**Success Criteria** (what must be TRUE):
  1. Inline taskfile comments are reduced to essential WHY only: the comment-to-code ratio across `Taskfile.yml` and `taskfiles/*.yml` falls measurably (recorded pre/post by `wc -l` on commented vs code lines per file in `.planning/phases/14-comment-doc-trim/14-METRICS.md`); redundant restatements of what the code does are gone
  2. Per-file header banners across taskfiles and `.zsh` scripts are slimmed to three elements — purpose (one or two lines), key dependencies, side effects — with verbose change-history annotations moved to git history; banner shape is consistent across files
  3. The `docs/` directory is reviewed; obsolete docs are removed (e.g., `CUTOVER.md` is gone per Phase 11 RMV-04 and stays gone; `MIGRATION.md` is either removed or rewritten as a single-page "what changed from v1" summary per Phase 9's AUDIT-05 decision); every doc remaining in `docs/` has a clear, current purpose
  4. Top-level `README.md`, project `CLAUDE.md`, and `.claude/CLAUDE.md` are deduped: each piece of info (manifest model, task surface, conventions, where to add things) lives in exactly one canonical home; cross-references replace duplication; running `diff <(grep '^##' README.md) <(grep '^##' CLAUDE.md)` shows minimal overlap
  5. After trim, the codebase reads cleanly for a new contributor with zero v2-history context: no "v1 macos:shell:145 bug class" references, no "Gap 2 brew-info pivot" references, no historical commit-hash references in code comments; `git grep -E 'v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap'` returns zero matches in code (only `.planning/` history retains those references, which is correct)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Manifest Engine + Repository Skeleton | 0/4 | Planned | - |
| 2. Install Engine — Bootstrap, Idempotency, Lint | 0/TBD | Not started | - |
| 3. Shell Layer — Flat Content Port | 0/TBD | Not started | - |
| 4. Identity Layer — Git + SSH per Machine | 4/7 | Gap closure planned | - |
| 5. Packages Layer — Brewfile Composition + Verification | 0/6 | Planned | - |
| 6. OS Defaults — macOS Configuration | 0/4 | Planned | - |
| 7. Claude + Tool Configs + Smoke Tests | 6/6 | Complete   | 2026-05-16 |
| 8. Validation + Cutover Readiness | 6/6 | Complete   | 2026-05-16 |
| 9. v1-Drop Audit | 5/5 | Complete   | 2026-05-17 |
| 10. v1-Drop Remediation | 1/1 | Complete    | 2026-05-18 |
| 11. v1 Removal | 1/1 | Complete   | 2026-05-18 |
| 12. Task Surface Redesign | 8/8 | Complete    | 2026-05-18 |
| 13. Code Review + Dead-Code Cleanup | 1/6 | In Progress|  |
| 14. Comment + Doc Trim | 0/TBD | Not started (v2.1) | - |
