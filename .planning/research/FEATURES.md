# Feature Research

**Domain:** Manifest-driven personal dotfiles repo (macOS-first laptops + first-class Linux servers, zsh + go-task + symlinks, AI-collaboration optimized)
**Researched:** 2026-05-13
**Confidence:** HIGH (mature ecosystem; the dominant patterns are well-documented across chezmoi, yadm, home-manager, dotbot, mise, and 100+ public dotfiles repos surveyed via dotfiles.github.io)

---

## Feature Landscape

### Table Stakes (Users Expect These)

A mature dotfiles repo that lacks any of these will feel broken either at fresh-install time, during normal use, or when onboarding a new machine. Missing these is a regression vs. the current v1 repo.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One-shot fresh-install entry point | Users expect `./bootstrap.zsh` or equivalent to take a clean machine to "working dev env" with zero further input | MEDIUM | Current `bootstrap.zsh` works but pipes `curl` to `sh` for go-task install — must be replaced with a checksum-verified Homebrew install or a pinned binary download with SHA-256 verification |
| Idempotent re-install | Every install task has a working `status:` check; re-running is fast (~seconds) and safe | MEDIUM | go-task's `status:` and `preconditions:` blocks. Current `gsd-install` and `macos:shell` violations to fix |
| Symlink-based config deployment | Source of truth in repo, symlinks into `$XDG_CONFIG_HOME` / `$HOME` / `$HOME/.ssh` | LOW | Current `_:safe-link` helper is correct shape; port unchanged |
| Per-machine identity selection (git, ssh) | Different email/signing key per machine; SSH host configs vary; this is the headline pain `v1` solves with profiles and `v2` solves with manifests | MEDIUM | TOML manifest declares identity refs; `git/identities/<name>` and `ssh/identities/<name>` files mapped per machine |
| Homebrew package management (macOS) | Industry standard; `brew bundle` from a `Brewfile` is the default for any macOS dev setup | LOW | Existing pattern works; just resolve which bundles a machine picks up from its manifest |
| Linux package management (apt/dnf) for servers | First-class servers require native package install — Homebrew on Linux is too slow on resource-constrained boxes | MEDIUM | Parallel `apt.list` and `dnf.list` per bundle; manifest selects which |
| Zsh startup chain (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`) | Industry standard zsh layout; deviating breaks user expectations | LOW | Port as-is; remove DOTFILES_PROFILE and hostname checks |
| One-alias-topic-per-file, one-function-per-file | Users want grep-able, additive shell config — not 800-line monoliths | LOW | Already done; just enforce in templates |
| Global `gitignore` | Universal expectation; covers `.DS_Store`, editor swap files, OS detritus | LOW | Port |
| Public SSH keys committed, private keys never | Security baseline; users assume the repo is safe to publish | LOW | Keep `ssh/keys/<machine>.pub` pattern |
| Per-component validation (`task validate`) | Users need to know *what* failed when something breaks; per-component health beats one giant pass/fail | MEDIUM | Current `_:check-*` helpers + per-taskfile `validate` already does this — port and extend |
| README at top level explaining the model | New users (and AI agents) need a roadmap in 60 seconds | LOW | Required for AI-collaboration goal; v1 README is light here |
| Routine update flow (`task update`) | Refresh brew, plugins, AI tooling without re-running unchanged steps | LOW | Current pattern works; just gate `gsd-install` and similar with `status:` |
| macOS system defaults application | Setting up dock, Finder, key-repeat etc. is what people switch dotfiles repos *for* | MEDIUM | Idempotent `defaults write` calls gated by status check on a marker file; manifest opts in per group |
| Cross-machine portability via git clone + bootstrap | Single git URL → full env on a new machine; the entire genre's value prop | LOW | Already works; preserve |
| Hooks integration for Claude Code | If repo manages Claude config (yours does), users expect hooks to install with everything else | LOW | Port existing hook installer; ensure executable bit preserved |
| Plain-text storage of public-facing config | Users read their dotfiles repo; binary blobs and opaque encodings are friction | LOW | Already a property; preserve. TOML is the right manifest format (chezmoi uses it, mise uses it, ecosystem norm) |

### Differentiators (Competitive Advantage)

These are where this repo competes — not because every dotfiles repo has them, but because each one materially improves the experience for josh + AI agents specifically.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Explicit per-machine TOML manifests (no profile suffixes, no hostname guessing) | Single declarative source of truth per machine; the install state is *legible* to humans and AI without inference | HIGH | Core architectural bet of v2. Chezmoi templates are the closest comparable but mix data and presentation; pure-data manifests + symlink deployment is the winning combo. **Depends on**: TOML parser available at task-eval time (go-task supports this via shell out to `tq` / `dasel` / `taplo` or a custom helper) |
| `defaults.toml` inheritance with per-machine override | Captures the "DRY across 4+ machines" win without the readability cost of tag-based composition | MEDIUM | Single level of inheritance only — no tag inheritance trees. Manifest reads as `defaults.toml + machines/<name>.toml`, machine wins on conflict |
| Adding a machine = one new file + one command | New laptop or server onboards in `vim machines/<name>.toml && task setup -- <name> && ./bootstrap.zsh` | MEDIUM | Reduces the v1 "8-step new-profile checklist" (STRUCTURE.md: "New profile" section) to one file edit |
| README-per-top-level-directory | Every directory teaches itself: purpose, how to add to it, conventions, examples | LOW | High AI-collaboration value: agents can answer "where does X go?" from a local README rather than inferring from siblings |
| One-concept-per-file across the repo | Aliases, functions, hooks, configs, taskfiles all follow the same rule; predictable for AI to extend | LOW | Already mostly there; codify in `.claude/CLAUDE.md` and per-directory READMEs |
| Predictable templates for new additions | "Adding a function looks like this; adding an alias looks like this; adding a hook looks like this" — written down with a real example file as the template | LOW | Pair each top-level directory's README with a template/example file. AI agents bias toward copying nearby examples; give them good ones |
| First-class Linux on servers (not "Linux works if you're lucky") | Server machines get their own package list, platform-aware shell config, no `macos:` task accidentally running | MEDIUM | Platform-aware directory layout (`aliases/{common,darwin,linux}/`) + manifest declares `platform = "linux"` + tasks guard on platform |
| Cold interactive shell startup under 200ms | Sub-second shell startup is felt every login; current ~500ms with antigen is laggy on slow servers | MEDIUM | Switch from antigen to antidote or zinit-turbo; cache compinit (rebuild once daily); defer non-critical loads. **Depends on**: plugin-manager swap |
| Drift detection in `task validate` | Reports symlinks that point to wrong source, missing targets, hooks that lost `+x`, brew packages installed outside the manifest | MEDIUM | Already 60% there with `_:check-*`; extend to compare manifest-declared state vs deployed state |
| Dry-run mode for `task install` and `task update` | "Show me what would change before I let it run" — table stakes in IaC (terraform plan, ansible --check) but rare in dotfiles | MEDIUM | go-task does not have a built-in `--dry-run`; implement by passing `DRY_RUN=1` env and having each task echo what it would do when set |
| Bootstrap with checksum-verified go-task install | Removes supply-chain risk on every fresh install; differentiator vs the common `curl \| sh` shame | MEDIUM | Preferred: `brew install go-task/tap/go-task` on macOS, distro package or pinned-tarball + SHA256 on Linux. Either way: no piping curl to sh |
| Migration documentation (v1 → v2 mapping) | Old-to-new file map preserved as `docs/MIGRATION.md`; archived old repo stays referenceable | LOW | Standard practice for parallel rewrites; cheap to do, painful to skip later |
| `CLAUDE.md` capturing conventions for AI maintenance | AI agent reads it on every session, follows the patterns, doesn't invent new ones | LOW | Already exists in v1; expand to cover manifest model, platform layout, "where to add X" — and link to per-directory READMEs |
| 1Password SSH agent gated by manifest feature flag (`one-password-ssh`) | Server machines skip 1Password (op CLI not installed); laptops get it; no hostname-string-matching bug | LOW | Manifest declares `features = ["one-password-ssh", ...]`; `.zprofile` checks an env var set by the install instead of literal `"$(hostname)" = "server"` |
| Per-identity git/ssh config files (decoupled from machine) | Same machine could host work + personal git repos via `includeIf gitdir/i:...`; the identity lives separately from the machine | MEDIUM | `git/identities/personal`, `git/identities/work`; manifest lists which identities to include |
| Performance budget enforced in CI/validate | `task validate` measures shell startup time and fails if over budget (200ms cold) | MEDIUM | `timezsh` function already exists; lift it into `zsh:validate` as a hard check |
| Documented anti-patterns in `.claude/CLAUDE.md` + ARCHITECTURE | Names the traps (hostname checks, profile branching in shared files, hardcoded Homebrew prefix) so neither human nor AI re-introduces them | LOW | v1 already has 3 anti-patterns documented; preserve and extend with manifest-era ones |

### Anti-Features (Commonly Requested, Often Problematic)

These are features that mature dotfiles repos sometimes ship, are tempting on the surface, but create more pain than they solve given the constraints of this project. Each anti-feature names its surface appeal and the better alternative.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Hostname-based auto-detection of machine identity** | "Just figure out which machine I'm on so I don't have to pick" | Bites you when hostnames overlap (`server`, `server-1`, `Joshs-MacBook-Pro.local`), when corporate IT renames machines, when a backup is restored on a different host. v1 has the literal hostname-match bug in `.zprofile:55-56` | Explicit machine selection at setup: `task setup -- <machine-name>`. State persisted to `${XDG_CONFIG_HOME}/dotfiles/machine` |
| **Curl-pipe-to-shell bootstrap** (`curl ... \| sh`) | "One-liner install command for new machines" | Supply-chain risk on every install, no checksum verification, no offline-replayable artifact. Per lobste.rs and HN consensus: anti-pattern | `git clone` first, then run `./bootstrap.zsh` from disk. Bootstrap installs go-task via Homebrew (with brew already a pinned dep) or downloads a checksum-verified binary |
| **Encrypted secrets in the dotfiles repo** (sops/age/git-crypt) | "Single repo holds everything including secrets — restore on any machine" | Adds a heavy dependency (sops + age + key management), needs key recovery story for "I lost my YubiKey." 1Password agent + reference-only resolution is simpler for personal use | 1Password SSH agent for SSH keys; 1Password CLI (`op read`) for any other secret retrieval. No secret material ever in the repo |
| **chezmoi-style file-as-template** | "Single source file generates per-machine variants via Go templates" | Mixes data (machine differences) with presentation (config content); makes diffs noisy; AI agents struggle with templated files because the rendered output is invisible | Pure-data TOML manifests + plain-text config files. Variation expressed via "which file gets symlinked" not "which template renders" |
| **Nix / home-manager** | "Fully declarative, reproducible, atomic rollback" | Conflicts with go-task lock-in; slow AI iteration loop (Nix is not idiomatic for one-off file edits); macOS GUI apps still need Homebrew via the `nix-darwin.homebrew` escape hatch; large learning surface area for one user. Per PROJECT.md: explicitly out of scope | TOML manifests + go-task + symlinks. The declarative win at a fraction of the cost |
| **Auto-update on shell startup or login** | "Always run the latest version of my dotfiles" | Network calls in interactive shell startup violate the 200ms budget; silent updates surprise you when something breaks at the worst time | Explicit `task update`. Optional: MOTD shows "X days since last update" as a soft nudge |
| **A `test` profile / machine** | "Place to try things before applying to real machines" | v1 declared but never implemented; pure clutter (`CONCERNS.md` flags this as a runtime crash) | Test on the real machine in a branch; archived old repo serves as the rollback target |
| **Hostname-pattern matching in shared files** (e.g., `if [[ $HOST == work-* ]]`) | "Auto-detect what kind of machine I'm on" | Identical failure mode to hostname-based identity; couples shared files to environment ambiguity | Manifest-declared feature flags exported as env vars at shell startup; shared files branch on env, not hostname |
| **Inline `if [[ $PROFILE == ... ]]` branching in shared config files** | "Keep all the logic in one place" | Spreads profile knowledge across the repo; impossible to grep "what does personal profile do?"; current v1 anti-pattern listed in ARCHITECTURE.md | Platform-aware directory structure (`aliases/{common,darwin,linux}/`) + manifest feature gates. Branching is in *which files load*, not inside files |
| **Bundled rollback / snapshot of pre-install state** | "Restore my old config if the new install breaks something" | Adds a backup directory that grows unbounded, false sense of safety (won't capture brew global state, macOS defaults, system-wide changes), users rarely actually use it | Git history (the dotfiles repo) + 1Password (secrets) is the rollback story. For brew: `brew bundle dump` before installs as a manual safety net if desired |
| **Audit-and-trim of every v1 function/alias during the rewrite** | "Rewrite is a good time to clean up cruft" | Triples the scope of the rewrite; mixes refactoring with archaeology; risks dropping functions someone (you, future you) actually uses. Per PROJECT.md: feature parity first | Port everything in v2; spawn a separate later milestone to audit and trim once cutover is verified working |
| **Cross-shell support (bash + fish + zsh)** | "Use bash on minimal servers where zsh isn't available" | Triples maintenance per feature; you only use zsh; per PROJECT.md: out of scope | Install zsh on every server as part of bootstrap; if a machine truly can't run zsh, it's out of scope for this dotfiles repo |
| **Windows / WSL support** | "Cross-platform completeness" | Adds substantial complexity (different path semantics, no symlink permissions by default, different package managers); you have no Windows machines per PROJECT.md | Explicitly out of scope. Document in README |
| **Auto-detection of installed identity ("smart" git config)** | "Figure out which email to use based on directory or remote URL" | Eventually misfires; sets wrong email on a commit that's then signed and published. v1 already uses `includeIf gitdir/i:...` which is the right amount of automation | `includeIf gitdir/i:...` for path-based; manifest declares the identity list; no extra "smart" detection |
| **Tag-based / inheritance-tree manifest composition** (chezmoi-style, ansible-style) | "Maximum DRY: define `is_laptop`, `has_gui`, `has_corp_vpn` and compose machines from tags" | High readability cost: reading a machine's manifest no longer tells you what it does — you have to mentally compose multiple tag files. Per PROJECT.md decision: clarity (per-machine) over DRY (tags) | One level of inheritance only: `defaults.toml` + `machines/<name>.toml`. Machine file is self-describing |
| **Plugin auto-update on every shell start** (antigen-style) | "Always have latest plugins" | Adds network call + filesystem scan to interactive startup; violates 200ms budget | Plugins updated via `task update`; locked between updates |
| **Inferring machine platform from `uname` at task-evaluation time** | "Why have the manifest say `platform = linux` if I can detect it?" | Conflates two different questions: "what OS am I running on" (detect from uname) and "what kind of machine is this for the purposes of which packages and configs to install" (declare in manifest). The latter is a *decision*, not a detection | Manifest declares `platform`. Tasks verify `uname` matches the manifest's `platform` and abort with a clear error if they don't (catches "you ran this on the wrong machine") |

---

## Feature Dependencies

```
Manifest Schema (defaults.toml + machines/*.toml)
    ├──required-by──> Per-machine identity selection (git, ssh)
    ├──required-by──> Brewfile composition via manifest bundles
    ├──required-by──> Linux package manifest (apt/dnf bundle)
    ├──required-by──> macOS defaults opt-in via manifest features
    ├──required-by──> 1Password SSH agent feature flag
    └──required-by──> Adding a machine = one new file

Explicit Machine Selection (task setup -- <name>)
    ├──required-by──> Manifest read at task eval
    ├──required-by──> Drift detection (compares manifest vs deployed)
    └──required-by──> All platform-conditional tasks

Bootstrap (checksum-verified)
    └──required-by──> Idempotent re-install
        └──required-by──> Routine update flow (task update)

Platform-aware directory layout (aliases/{common,darwin,linux}/)
    ├──required-by──> First-class Linux on servers
    └──required-by──> Cross-platform divergence handling

Zsh plugin manager swap (antigen → antidote or zinit-turbo)
    ├──required-by──> Cold shell startup under 200ms
    └──enhanced-by──> compinit cache strategy (rebuild daily)

Performance budget in task validate
    └──requires──> Plugin manager swap (otherwise budget unattainable)

README-per-directory
    ├──enhances──> AI-collaboration fit
    ├──enhances──> Predictable templates for new additions
    └──enhances──> CLAUDE.md conventions document

Dry-run mode (DRY_RUN=1)
    └──enhances──> Idempotent re-install (safer to verify before applying)

Drift detection
    ├──requires──> Manifest schema (knows what *should* exist)
    └──requires──> Per-component validation (knows how to check)

Hooks integration (Claude Code)
    └──depends-on──> Symlink-based config deployment
                  └──depends-on──> _:safe-link helper

Manifest-driven feature flags exported as env vars
    ├──replaces──> Hostname-based detection (anti-feature)
    └──required-by──> 1Password SSH agent gating
                   └──required-by──> Cross-platform .zprofile correctness
```

### Dependency Notes

- **Manifest schema is the keystone.** Almost every differentiator depends on it. It must be implemented and stable before any feature that reads from it (identity, packages, defaults, features). Suggests Phase 1: manifest schema + parser + validator.
- **Plugin manager swap unlocks the perf budget.** You cannot enforce a 200ms startup budget while still on antigen. Either commit to both (swap + budget enforcement) or neither.
- **Drift detection requires both manifest *and* per-component validation.** Cheaper to do as one feature (extend existing `_:check-*` helpers to read manifest expectations) than two.
- **README-per-directory and predictable templates are mutually reinforcing.** Each README points to its template; each template's existence is documented in its README. Ship them together per directory.
- **Bootstrap checksum verification depends on choosing the install method.** `brew install go-task/tap/go-task` is cheapest (relies on Homebrew's existing signing) but requires Homebrew first; for Linux servers you may want a pinned binary download with SHA-256. Decide before implementing.
- **Manifest-driven env vars replace every hostname check.** Once `DOTFILES_MACHINE` and feature-flag env vars are exported by `.zshenv` (read from manifest), all the legacy hostname-string-matching bugs (`.zprofile:55-56`, `pubkey.zsh` docstring drift, profile-conditional branches) get fixed *as a class*, not one-by-one.

---

## MVP Definition

### Launch With (v2.0 — feature parity cutover)

The minimum to declare cutover from v1. All four machine categories (`personal-laptop`, `work-laptop`, `server-1`, `server-2`) must install cleanly and `task validate` must pass on each.

- [ ] **Manifest schema** (`defaults.toml` + `machines/<name>.toml`) — keystone for everything else
- [ ] **Explicit machine selection** (`task setup -- <name>`; persisted machine identifier) — replaces profile
- [ ] **Bootstrap with checksum-verified go-task install** — removes the curl-pipe-to-sh footgun
- [ ] **Idempotent install with `status:` on every task** — fixes `gsd-install`, `macos:shell` from v1
- [ ] **Symlink deployment via `_:safe-link`** — port from v1 unchanged
- [ ] **Platform-aware directory layout** (`aliases/{common,darwin,linux}/`, same for `functions/`) — fixes the macOS-aliases-in-common bug
- [ ] **Per-identity git config** (`git/identities/<name>` with `includeIf`) — replaces `git/config-<profile>`
- [ ] **Per-identity ssh config** (`ssh/identities/<name>` referenced by manifest) — replaces `Match exec` profile read
- [ ] **Brewfile composition via manifest bundles** — replaces `Brewfile-<profile>.rb`
- [ ] **Linux package manifest** (apt + dnf lists) for servers — first-class
- [ ] **macOS defaults opt-in via manifest features** — idempotent (fixes v1 re-run bug), no-op on Linux
- [ ] **1Password SSH agent gated by `one-password-ssh` feature flag** — fixes hostname-match bug
- [ ] **Per-component `task validate`** — port + extend
- [ ] **Hooks integration for Claude Code** — port from v1, fix shellcheck issues
- [ ] **README at top-level explaining the manifest model** — onboarding requirement
- [ ] **README per top-level directory** — AI-collaboration goal; also human-onboarding
- [ ] **CLAUDE.md updated for v2 conventions** — captures manifest model, platform layout
- [ ] **docs/MIGRATION.md** — old-to-new mapping; cutover plan
- [ ] **All v1 functions/aliases ported** — feature parity per PROJECT.md (no audit-and-trim)

### Add After Validation (v2.1 — first iteration after cutover)

Add once v2.0 is shipped and proven on all four machines. These compound the value of the manifest layer.

- [ ] **Cold shell startup under 200ms** — plugin manager swap (antigen → antidote or zinit-turbo); compinit caching. Trigger: cutover complete, v1 archived
- [ ] **Performance budget enforced by `task validate`** — `timezsh` integrated as a hard check. Trigger: 200ms achieved
- [ ] **Dry-run mode** (`DRY_RUN=1 task install`) — every task echoes what it would do. Trigger: first time you want to test a manifest change before applying
- [ ] **Drift detection in `task validate`** — compare manifest-declared state vs deployed state. Trigger: first surprise of "wait, why is this brew package installed?"
- [ ] **Predictable per-directory templates** (one example file per directory paired with its README) — Trigger: first time AI agent gets the pattern wrong adding a new function/alias

### Future Consideration (v2.2+)

Deferred until v2 ships and proves the manifest model. Each requires a clearer trigger event.

- [ ] **Audit-and-trim pass** over ported v1 functions/aliases — separate milestone; trigger: v2 is stable and you find yourself avoiding certain shell functions
- [ ] **Update freshness MOTD nudge** ("X days since last task update") — only if forgetting to update becomes a real problem
- [ ] **Manifest-schema JSON Schema for editor validation** — only if you find yourself making manifest typos that bootstrap doesn't catch
- [ ] **Backup of pre-install brew state** (`brew bundle dump` to a dated file before `task install` modifies anything) — only if you actually have a rollback need
- [ ] **Multi-identity manifest composition** (machine declares multiple identities, not just one) — only if a single machine genuinely needs both work + personal at the same time, more than `includeIf` solves
- [ ] **Bootstrap from a Linux server with no Homebrew at all** (pure apt/dnf path) — currently bootstrap assumes brew on macOS and at least curl + tar on Linux; harden if servers get more restrictive

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Manifest schema (TOML, defaults + per-machine) | HIGH | MEDIUM | P1 |
| Explicit machine selection | HIGH | LOW | P1 |
| Checksum-verified bootstrap | HIGH | MEDIUM | P1 |
| Idempotent install (status: on every task) | HIGH | LOW | P1 |
| Symlink deployment (port from v1) | HIGH | LOW | P1 |
| Platform-aware directory layout | HIGH | LOW | P1 |
| Per-identity git config | HIGH | LOW | P1 |
| Per-identity ssh config | HIGH | LOW | P1 |
| Brewfile composition via manifest | HIGH | MEDIUM | P1 |
| Linux package manifest (apt/dnf) | HIGH | MEDIUM | P1 |
| macOS defaults opt-in via manifest features | MEDIUM | MEDIUM | P1 |
| 1Password SSH agent feature-flag gating | HIGH | LOW | P1 |
| Per-component validation | HIGH | LOW | P1 |
| Hooks integration for Claude Code | HIGH | LOW | P1 |
| Top-level README | HIGH | LOW | P1 |
| README per top-level directory | HIGH | LOW | P1 |
| CLAUDE.md for v2 conventions | HIGH | LOW | P1 |
| docs/MIGRATION.md | MEDIUM | LOW | P1 |
| Port all v1 functions/aliases | HIGH | LOW | P1 |
| Cold shell startup under 200ms | HIGH | MEDIUM | P2 |
| Performance budget in validate | MEDIUM | LOW | P2 |
| Dry-run mode | MEDIUM | MEDIUM | P2 |
| Drift detection | MEDIUM | MEDIUM | P2 |
| Predictable templates per directory | HIGH | LOW | P2 |
| Audit/trim v1 cruft | LOW | MEDIUM | P3 |
| Manifest JSON Schema | LOW | LOW | P3 |
| Brew bundle pre-install snapshot | LOW | LOW | P3 |
| Multi-identity composition | LOW | MEDIUM | P3 |

**Priority key:**
- **P1:** Must have for v2.0 cutover (feature parity + safety)
- **P2:** Should have, add in v2.1 once cutover is stable
- **P3:** Defer until a real trigger appears

---

## Competitor Feature Analysis

The competitive set is "what comparable dotfiles solutions do," chosen to anchor the design space.

| Feature | chezmoi | yadm | home-manager (Nix) | dotbot | v1 (current dotfiles) | v2 Approach |
|---------|---------|------|---------------------|--------|----------------------|-------------|
| Per-machine variation | Templates on rendered files | OS-suffix files (##os.Darwin) | Per-host Nix expressions | `if` keys in install.conf | Profile suffix on filenames | Per-machine TOML manifest (data, not templates) |
| Identity selection | Machine config TOML | Bare git + per-machine branches | Per-host module imports | None native | Profile file at `${XDG}/dotfiles/profile` | Manifest `identity =` field; `includeIf` for git, identity-file include for ssh |
| Fresh-install command | `chezmoi init --apply <url>` | `yadm clone <url>` | Nix install + flake apply | `git clone && ./install` | `git clone && ./bootstrap.zsh` (curl-pipe-to-sh inside) | `git clone && ./bootstrap.zsh` (no curl-pipe; brew or pinned binary install of go-task) |
| Cross-platform | YES (templates + chezmoi.os) | YES (##os. suffix) | YES (Linux/macOS via nix-darwin) | YES (`if` shell-out) | Partial (macOS-aliases leak into common) | Platform-aware directory layout (common/darwin/linux) |
| Secret management | YES (age, gpg, password mgrs) | YES (gpg/transcrypt) | YES (sops-nix, agenix) | NO (out of scope) | 1Password SSH agent | 1Password SSH agent (gated by manifest feature flag); no in-repo secrets |
| Idempotent re-install | YES | Partial | YES (atomic) | YES (`if-already-linked`) | YES (status:) — except `gsd-install`, `macos:shell` | YES (status: on every task, enforced) |
| Validation / dry-run | `chezmoi diff`, `chezmoi verify` | `yadm status` | `nix build` (no-op shows diff) | `--very-verbose` | `task validate` per component | `task validate` + drift detection (v2.1) + `DRY_RUN=1` (v2.1) |
| AI-collaboration affordances | Limited (template syntax obscures intent for agents) | None explicit | None explicit | None explicit | CLAUDE.md + per-file conventions | First-class: manifest is pure data; README-per-dir; templates; CLAUDE.md captures all conventions |
| Rollback story | Git revert + chezmoi re-apply | Git revert + yadm checkout | Nix generations (atomic rollback) | Manual unlink + git revert | Git revert + task install | Git revert + task install (no separate backup system) |
| Linux servers first-class | Cross-platform, no opinion | Cross-platform, no opinion | NixOS native, very strong | Cross-platform via `if` | Server profile exists; some macOS aliases leak | Yes — dedicated Linux package manifest, platform-aware dirs |
| Performance focus | Not a goal | Not a goal | Build-time not runtime | Not a goal | ~500ms shell startup (antigen) | <200ms shell startup target (antidote or zinit-turbo) |
| Documentation density per dotfiles directory | None expected | None expected | Nix module docs sometimes | Sparse READMEs typical | One top-level README | README per top-level directory + CLAUDE.md (AI-collab differentiator) |

**Net positioning:** v2 mostly competes with chezmoi (the closest comparable for a personal multi-machine dotfiles setup). v2 trades off chezmoi's template power for legibility — manifests are pure data, files are plain config, variation lives in *which files load*. The bet is that for a 4-machine personal repo maintained jointly with AI agents, pure-data manifests + per-directory READMEs + predictable templates are a better fit than chezmoi's template DSL.

---

## Sources

### Authoritative documentation (HIGH confidence)
- [chezmoi: Manage machine-to-machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/) — confirms templates + machine config TOML as the standard cross-machine pattern
- [chezmoi: Templating](https://www.chezmoi.io/user-guide/templating/) — variables like chezmoi.hostname, chezmoi.os, chezmoi.arch
- [chezmoi: Comparison table](https://www.chezmoi.io/comparison-table/) — direct features matrix vs yadm, dotbot, home-manager
- [Task (go-task) usage docs](https://taskfile.dev/usage/) — confirms `Taskfile_{{GOOS}}.yml` platform-specific files, dotenv override precedence
- [Task: Schema reference](https://taskfile.dev/docs/reference/schema) — `status:`, `preconditions:`, dotenv, includes
- [zinit GitHub](https://github.com/zdharma-continuum/zinit) — Turbo mode for 50-80% faster startup
- [antidote.sh](https://antidote.sh/) — concurrent loading, static plugin file
- [SOPS GitHub](https://github.com/getsops/sops) — secret encryption tool reference (anti-feature)
- [getsops.io](https://getsops.io/) — official SOPS site

### Strong secondary sources (MEDIUM-HIGH confidence)
- [dotfiles.github.io: Bootstrap repositories](https://dotfiles.github.io/bootstrap/) — community wiki of patterns
- [dotfiles.github.io: General-purpose utilities](https://dotfiles.github.io/utilities/) — tool landscape including Homemaker (TOML manifests)
- [dotfiles.github.io: Inspiration](https://dotfiles.github.io/inspiration/) — patterns surveyed across many public repos
- [DeployHQ: Chezmoi Guide](https://www.deployhq.com/guides/chezmoi) — comprehensive walkthrough of templates, encryption
- [BigGo News: Dotfile Management Tools Battle (YADM vs Chezmoi vs Nix)](https://biggo.com/news/202412191324_dotfile-management-tools-comparison) — community comparison
- [Cross-Platform Dotfiles — Calvin Bui](https://calvin.me/cross-platform-dotfiles/) — uname-based detection, includeIf for git
- [Building a Unified, Cross-Platform Dotfiles Architecture — Joseph Hall](https://josephhall.org/blog/building-a-unified-cross-platform-dotfiles-architecture/) — directory layout patterns
- [Speed up zsh compinit by only checking cache once a day (gist)](https://gist.github.com/ctechols/ca1035271ad134841284) — daily-cache compinit pattern
- [zsh plugin manager benchmark](https://github.com/rossmacarthur/zsh-plugin-manager-benchmark) — empirical startup-time comparison

### Anti-pattern / cautionary sources (MEDIUM confidence)
- [What's the problem with pipe-curl-into-sh? (lobste.rs)](https://lobste.rs/s/ymcbwl/what_s_problem_with_pipe_curl_into_sh) — community consensus on curl-pipe-to-shell risks
- [Is curl|bash insecure? (HN)](https://news.ycombinator.com/item?id=10277470) — HN thread
- [holman/dotfiles issue #158: Host-specific dotfiles](https://github.com/holman/dotfiles/issues/158) — confirms hostname-detection pitfalls in practice
- [dotdrop usage docs](https://dotdrop.readthedocs.io/en/latest/usage/) — `--profile` switch and `DOTDROP_PROFILE` env var as explicit override
- [Are Your Public Dotfiles Revealing Too Much?](https://thoughts.theden.sh/posts/pub-dotfiles-opsec/) — opsec considerations

### AI-collaboration angle (MEDIUM confidence — newer territory)
- [A Practical Guide to AI Dotfiles](https://engineersmeetai.substack.com/p/a-practical-guide-to-ai-dotfiles) — predates v2 design; one of the few specifically on AI-coding-agent-friendly dotfiles
- [Dotfiles: Taming Your Dev Environment and Your AI Coding Agents](https://drmowinckels.io/blog/2026/dotfiles-coding-agents/) — recent post on the same theme
- [Anthropic: Using CLAUDE.md files](https://claude.com/blog/using-claude-md-files) — official guidance on CLAUDE.md as project context
- [.agents Guidelines (dotStandards)](https://dotstandards.info/guidelines/agents/) — emerging conventions for `~/.agents/`

### Tooling references (HIGH confidence)
- [mise: Lockfiles and Reproducibility (DeepWiki)](https://deepwiki.com/jdx/mise/6.7-lockfiles-and-reproducibility) — `mise.lock` for tool-version pinning
- [mise vs asdf comparison](https://mise.jdx.dev/dev-tools/comparison-to-asdf.html)

### Local context (HIGH confidence — primary sources for this repo)
- `/Users/josh/Git/personal/dotfiles/.planning/PROJECT.md` — v2 requirements, constraints, key decisions
- `/Users/josh/Git/personal/dotfiles/.planning/codebase/STRUCTURE.md` — v1 layout the rewrite must preserve features from
- `/Users/josh/Git/personal/dotfiles/.planning/codebase/ARCHITECTURE.md` — v1 patterns and documented anti-patterns

---
*Feature research for: manifest-driven personal dotfiles (macOS + Linux, AI-collaboration optimized)*
*Researched: 2026-05-13*
