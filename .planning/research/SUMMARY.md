# Project Research Summary

**Project:** Dotfiles v2 Refactor
**Domain:** Manifest-driven personal dotfiles (macOS-first laptops + first-class Linux servers)
**Researched:** 2026-05-13
**Confidence:** HIGH

## Executive Summary

The v2 rewrite is a well-scoped problem with high-confidence answers in every dimension. The domain (personal dotfiles with per-machine variance, zsh, go-task) is mature and the research confirms that the locked decisions are sound: TOML manifests + symlinks over chezmoi templates, explicit machine selection over hostname detection, antidote over the archived Antigen, and Starship over the life-support Powerlevel10k. The recommended architecture is a five-layer system (manifest resolution, task orchestration, helpers/messages, asset source-of-truth, deployed symlinks) where the manifest layer is compiled once to a JSON cache that every downstream task reads via go-task's native `fromJson`. The biggest structural bet — per-machine TOML manifests inheriting from `defaults.toml` with defined merge semantics — has clear prior art in chezmoi's data model and is well-understood.

The single most important cross-cutting decision still needing resolution before planning starts is the TOML parser choice. STACK.md recommends **yq** (already installed, full roundtrip since v4.52.1, single mental model with jq). ARCHITECTURE.md uses **dasel** in its implementation sketches (for TOML-to-JSON conversion in `resolver.zsh` and the manifest.yml pattern). These are not equally valid alternatives: yq wins on "already in repo, no new dep, same jq-flavored syntax used everywhere else." Dasel is the better choice only if INI file support is needed or if its selector syntax is preferred — neither applies here. **Resolution: use yq throughout.** Roadmapper should treat this as settled.

The dominant risks are not technical — they are process and hygiene risks that the current v1 repo already exhibits as live bugs: `status:` checks that use shell variables instead of task template variables, macOS-only aliases in `common/`, a bootstrap that pipes curl to sh, and 500ms shell startup from synchronous Antigen. Every one of these has a structural v2 prevention: lint enforces `status:` correctness, directory taxonomy encodes platform, bootstrap installs via Homebrew (single trusted event), and the plugin manager swap is a P1 for the shell phase. The pitfalls research makes clear that prevention must be structural (lints, CI checks, `status:` enforcement) — not textual (docs that drift from reality). Build the lint suite as part of the foundation, not as an afterthought.

## Key Findings

### Recommended Stack

The stack is almost entirely settled and aligned with what is already in the repo. Primary changes from v1: (1) replace Antigen with **antidote** — Antigen's last release was January 2018 and it is the dominant cause of the ~500ms cold start; (2) replace Powerlevel10k with **Starship** — p10k is on author-declared life support per 2025-2026 community sources; (3) use **yq v4.53+** as the sole TOML/JSON parser — already in the Brewfile, gained full TOML roundtrip in v4.52.1; (4) use a single cross-platform Brewfile with `if OS.mac?` / `if OS.linux?` guards rather than separate `Brewfile-<profile>.rb` files. All other stack components (go-task, zsh, Homebrew, Ghostty, 1Password CLI, eza/bat/ripgrep/fd/fzf/zoxide/delta/jq) are already in place and require no change.

**Core technologies:**
- **go-task v3.50+**: orchestrator — locked; `status:`, `preconditions:`, `fromJson`, parallel `deps:` cover all orchestration needs
- **yq v4.53+ (mikefarah)**: TOML/YAML/JSON parser — already in Brewfile; one mental model with jq; full roundtrip since v4.52.1; replaces dasel
- **antidote v2.1+**: zsh plugin manager — Antigen's explicit successor; static bundle file; fastest cold start in benchmarks; Antigen-compatible API
- **Starship**: prompt — cross-shell, cross-platform, single `starship.toml`, sub-millisecond render; replaces life-support p10k
- **Homebrew 5.1+**: cross-platform package manager — single `brew bundle` Brewfile with `if OS.mac?`/`if OS.linux?` guards
- **1Password CLI + SSH agent**: secrets and SSH; gated by `one-password-ssh` manifest feature flag; system ssh-agent on server machines

**Settled TOML parser conflict — yq over dasel:** STACK.md recommends yq; ARCHITECTURE.md sketches use dasel. Use yq. It is already installed (no new dependency), the jq-compatible syntax matches existing taskfile patterns, and adding dasel introduces a fourth query syntax (jq/yq/bash/dasel) for no offsetting benefit. ARCHITECTURE.md implementation sketches that reference `dasel -f ... -r toml -w json` should be translated to `yq -o=json '.' <file.toml>` in the actual implementation.

### Expected Features

The FEATURES.md v2.0 MVP list maps cleanly to the PROJECT.md active requirements with no conflicts. Research adds priority ordering and dependency structure.

**Must have (table stakes — v2.0 cutover gate):**
- Manifest schema (`defaults.toml` + `machines/<name>.toml`) — keystone; nothing else builds without it
- Explicit machine selection (`task setup -- <name>`; state persisted to `$XDG_STATE_HOME/dotfiles/machine`)
- Bootstrap without curl-to-shell (Homebrew installs go-task on macOS; SHA256-verified binary on Linux)
- Idempotent install with `status:` on every task — fixes `gsd-install` and `macos:shell` from v1
- Platform-aware directory layout (`aliases/{common,darwin,linux}/`; same for functions) — eliminates four live v1 violations
- Per-identity git and SSH config (manifest-driven; `includeIf` for git; `Include` for SSH)
- Brewfile composition via manifest bundles; Linux apt/dnf package manifests first-class
- macOS defaults opt-in via manifest features; idempotent; no-op on Linux
- 1Password SSH agent gated by manifest feature flag — fixes `.zprofile:55` hostname bug structurally
- Per-component `task validate` with check/cross output
- README per top-level directory; CLAUDE.md for v2 conventions; `docs/MIGRATION.md`
- All v1 aliases and functions ported (feature parity — no audit-and-trim in this rewrite)

**Should have (v2.1, after cutover is stable):**
- Cold shell startup under 200ms (plugin manager swap + compinit caching); perf budget enforced in CI
- Dry-run mode (`DRY_RUN=1 task install`)
- Drift detection in `task validate` (manifest-declared vs deployed state diff)
- Predictable per-directory templates (one example file per directory)

**Defer (v2.2+, needs real trigger):**
- Audit-and-trim pass over ported v1 functions/aliases
- Manifest JSON Schema for editor validation (taplo lint in CI)
- Brew bundle pre-install snapshot

**Key anti-features — do not build:** hostname-based auto-detection, curl-pipe-to-shell in bootstrap, chezmoi-style templated file rewriting, tag-based manifest composition, auto-update on shell startup, `test` profile (drop entirely per PROJECT.md).

### Architecture Approach

Five layers with clean boundaries: (1) entry points (bootstrap.zsh, Taskfile.yml, /etc/zshenv), (2) manifest resolution layer (TOML source → `install/resolver.zsh` → `$XDG_STATE_HOME/dotfiles/resolved.json` JSON cache), (3) task orchestration (one taskfile per concern: manifest, shell, links, packages, identity, macos, claude, validate), (4) helpers/messages layer (stable from v1), (5) asset source-of-truth (shell/, identity/, packages/, configs/, os/, claude/) deployed as symlinks. The key architectural bet is that manifests are authored in TOML and consumed as JSON — resolved once at `task manifest:resolve`, never re-parsed per task.

**Major components:**
1. **`manifests/` + `install/resolver.zsh`**: TOML source-of-truth + compile step; produces `resolved.json`; every task depends on this; resolver uses yq for TOML-to-JSON, jq for deep-merge
2. **`taskfiles/` (one yml per concern)**: manifest.yml, shell.yml, links.yml, packages.yml, identity.yml, macos.yml, claude.yml, validate.yml
3. **`shell/`** (renamed from `zsh/`): platform-aware alias/function glob-loading; `.zshenv` exports `$DOTFILES_MACHINE` and `$PLATFORM`; no profile branching inside files
4. **`identity/`**: git and SSH identity files decoupled from machines; manifest selects which identity each machine activates
5. **`packages/brew/<bundle>.rb` + `packages/apt/<bundle>.list`**: bundles named by purpose (core, gui, dev, ops, personal), composed by manifest
6. **`os/darwin/defaults/`**: one file per defaults group, each gated by a manifest feature flag

**Critical naming decision — lock before content is added:** rename `zsh/` to `shell/`; rename `aliases/{personal,work,server}/` to `aliases/{common,darwin,linux}/`. This is the structural change that eliminates the profile concept at the filesystem level.

**Merge semantics to lock in Phase 1:** maps deep-merge, scalars replace, arrays replace (machine's list wins), `extra_packages` concatenates (explicit additive escape). Source: chezmoi data model. Write test fixtures before writing any code that depends on it. The `jq -s '.[0] * .[1]'` expression in ARCHITECTURE.md is a shallow merge — it will drop nested table keys. Use `yq eval-all '. as $i ireduce ({}; . * $i)' defaults.toml machine.toml | yq -o=json` or a recursive jq function.

### Critical Pitfalls

All seven pitfalls below have live instances in the current v1 repo (from CONCERNS.md) — they are not speculative.

1. **`status:` uses `$VAR` instead of `{{.VAR}}`** (live: `macos:shell:145`) — `task lint:taskfile` greps for `$[A-Z_]+` in `status:` lines; CI fails the PR. Every install task must have a local-condition `status:` block; network-dependent checks defeat idempotency.

2. **Manifest-vs-installed drift** — forward-only install logic leaves orphaned symlinks and feature side effects. Prevention: pair every feature-install with a feature-remove; `task links:reconcile` scans managed dirs for symlinks pointing into `$DOTFILEDIR` not in manifest; `task validate` flags both directions (missing-declared and present-undeclared).

3. **Bootstrap supply-chain** (live: `bootstrap.zsh:33` pipes curl to sh) — accept Homebrew's install script once (documented), then `brew install go-task`. On Linux: download go-task binary, verify SHA256 committed in repo. `set -euo pipefail` mandatory in bootstrap (currently only `set -e`).

4. **Cross-platform leakage** (live: 4 instances — `hardware.zsh`, `general.zsh:27-31`, `networking.zsh:4`, `pubkey.zsh:11`) — `task lint:platform` greps `common/` for known macOS-only commands (`pbcopy`, `defaults`, `osascript`, etc.); CI fails on violation. Directory taxonomy is the structural fix; lint is the enforcement.

5. **Identity bleed** (live: `.zprofile:55` hostname check for 1Password) — `[identity]` is a required top-level schema field; validation fails if missing; `task validate` reads actual `git config user.email` and asserts against manifest; no `hostname` reference in any identity-determining code path.

6. **Premature cutover** — "feature parity" asserted not measured. Prevention: `docs/CUTOVER.md` with per-machine status; cutover is individual not big-bang; gate requires 100% `task validate` pass + 7-day run on v2 with no v1 fallback; v1 stays fully working throughout.

7. **Shell startup regression** (live: antigen apply + synchronous MOTD = ~500ms) — plugin manager swap (antidote) is a P1 for the shell phase; `task perf:shell` measures against 200ms budget in CI; MOTD must be async with 24h TTL cache; heavy completions (kubectl, gcloud) lazy-loaded.

## Implications for Roadmap

The dependency graph from FEATURES.md and the build order from ARCHITECTURE.md are well-aligned and both converge on the same phase structure. The manifest layer is the keystone — nothing downstream can be built without it. Shell platform layout must be locked before any shell content is ported. Lints must be established before content is added.

### Phase 1: Foundation — Manifest Engine + Repository Skeleton

**Rationale:** The manifest layer is a hard dependency for every subsequent phase. Schema and merge semantics must be locked with test fixtures before any downstream task reads the manifest. The repository skeleton (directory layout, naming conventions, README per directory, CLAUDE.md) must be established before content is added to prevent costly renames.

**Delivers:**
- `manifests/defaults.toml` + `manifests/machines/*.toml` (all four machines with required `description` fields)
- `install/resolver.zsh` using yq for TOML-to-JSON and correct deep-merge semantics; produces `$XDG_STATE_HOME/dotfiles/resolved.json`
- `taskfiles/manifest.yml` with `resolve`, `show`, `validate` tasks; `show` prints post-merge TOML for debugging
- Merge semantics documented and test-fixture-verified (map-over-map, list-replace, scalar-override, nested tables, missing keys)
- `docs/MANIFEST.md` with schema spec, inheritance rules, and worked examples
- Repository skeleton: all top-level directories, README per directory, CLAUDE.md updated for v2 conventions
- `install/messages.zsh` and `install/platform.zsh` ported from v1
- `taskfiles/helpers.yml` ported with `_:safe-link` hardened to `ln -sfn` + target-type check

**Avoids:** Pitfall 2 (schema sprawl), Pitfall 3 (merge ambiguity), Pitfall 8 (symlink hygiene)

**Research flags:** The `jq -s '.[0] * .[1]'` shallow merge in ARCHITECTURE.md is incorrect for the "maps deep-merge, arrays replace" semantics. Write the resolver with test fixtures first and verify all merge cases before shipping Phase 1. No additional external research needed.

---

### Phase 2: Install Engine — Bootstrap, Idempotency, Lint Foundation

**Rationale:** Bootstrap must be fixed before any machine is onboarded to v2 (live supply-chain risk). The lint suite must exist before shell content is ported — retroactive linting of 50+ alias files is painful. The twice-run timing test (`task install` under 5s on second run) must be enforced before task count grows.

**Delivers:**
- `bootstrap.zsh` rewritten with `set -euo pipefail`; Homebrew → `brew install go-task` on macOS; checksum-verified binary on Linux; fully resumable (every step has a guard)
- `task lint:taskfile` — flags `$VAR` in `status:` lines; flags bare `ln -s` outside helpers.yml; flags tasks with `cmds:` but no `status:`
- `task lint:shell-headers` — flags missing `set -euo pipefail` in executable `.zsh` files
- `task lint:platform` — flags macOS-only / Linux-only commands in `common/` directories
- Root `task lint` aggregates all lint tasks
- CI: `task lint` + `zsh -n` on every `.zsh` file (Tier 0) + `task install` twice-run timing test
- `docs/SECURITY.md` — bootstrap trust chain; what is downloaded, from where, how verified, who is trusted

**Avoids:** Pitfall 9 (status: idempotency bugs), Pitfall 10 (bootstrap supply-chain), Pitfall 11 (doc drift), Pitfall 12 (testing floor)

**Research flags:** None — standard patterns throughout.

---

### Phase 3: Shell Layer — Platform Layout + Content Port

**Rationale:** Platform directory taxonomy (`common/`, `darwin/`, `linux/`) is a prerequisite to porting any alias or function correctly. The plugin manager swap and Starship prompt belong here because they directly govern the 200ms cold-start requirement — deferring them means shipping v2 with the known 500ms regression.

**Delivers:**
- `shell/` directory with `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`
- `.zshenv` exports `$DOTFILES_MACHINE` (from state file) and `$PLATFORM` (from uname); removes `$DOTFILES_PROFILE`
- `.zprofile` — SSH agent export gated on manifest feature flag; brew shellenv wrapped in existence check
- `.zshrc` — glob-loads `aliases/{common,darwin,linux}/` and `functions/{common,darwin,linux}/` by `$PLATFORM`; Antigen replaced by antidote with static bundle file
- All v1 aliases sorted into `common/`, `darwin/`, `linux/` buckets; `task lint:platform` passes on every file
- All v1 functions ported; each file passes `zsh -n`
- Starship replaces Powerlevel10k; `configs/starship/starship.toml` configured
- compinit cache (daily rebuild, not per shell start)
- `task perf:shell` — measures shell cold start against 200ms budget; fails CI if exceeded
- MOTD async: fastfetch output cached to file with 24h TTL

**Avoids:** Pitfall 6 (startup regression), Pitfall 7 (cross-platform leakage)

**Research flags:** antidote `kind:defer` configuration for specific plugins — no external research needed, but requires a measurement loop: add antidote, measure startup, identify which plugins to defer, measure again. The 200ms budget gate provides the feedback signal.

---

### Phase 4: Identity Layer — Git + SSH per Machine

**Rationale:** Identity mistakes (wrong git email on a commit, wrong SSH key to a server) are high-stakes and hard to reverse. Building identity in its own phase lets the manifest-driven selection be validated in isolation before packages and OS defaults are layered on.

**Delivers:**
- `identity/git/config` with `includeIf` for path-based identity selection; `identity/git/identities/personal` and `identity/git/identities/work`
- `identity/ssh/config` with `Include` for identity-based host configs; `identity/ssh/identities/personal` and `identity/ssh/identities/work`
- `identity/ssh/agent/1password.toml` included only when `one-password-ssh` feature is active
- `identity/ssh/keys/` — public keys committed; private keys gitignored
- `taskfiles/identity.yml` — manifest-driven identity symlink selection; `status:` on each task
- `task validate` assertions: `git config user.email` matches manifest; `ssh-add -L` shows expected key; zero `hostname` references in any identity-determining code path
- Pre-commit hook: configured email matches allowed set for current repo remote origin

**Avoids:** Pitfall 5 (identity bleed; `.zprofile:55` bug class eliminated structurally)

**Research flags:** None — `includeIf gitdir:` and SSH `Include` are stable, well-documented. The active-identity-symlink vs `includeIf gitdir:` strategy is a per-machine choice, not a research question.

---

### Phase 5: Packages Layer — Brewfile Composition + Linux Packages

**Rationale:** Package installation is the longest-running step. Having the manifest engine and lint foundation in place before this phase means bundle composition logic can be built correctly and tested for idempotency from the start (`brew bundle check` sentinel pattern).

**Delivers:**
- `packages/brew/core.rb`, `gui.rb`, `dev.rb`, `ops.rb`, `personal.rb` — bundles named by purpose, not by profile
- `packages/apt/core.list`, `dev.list`, `ops.list` — first-class Linux package manifests (not stripped-down macOS)
- `packages/dnf/core.list`, `ops.list` — Fedora server support
- `taskfiles/packages.yml` — reads `packages.brew.bundles` and `packages.apt.bundles` from resolved manifest; composes Brewfile per machine; `status:` using `brew bundle check --file=<bundle>` sentinel
- Cross-platform single assembled Brewfile with `if OS.mac?` / `if OS.linux?` guards

**Avoids:** Pitfall 9 (`brew bundle` re-run is the most expensive task; `status:` is critical here)

**Research flags:** apt/dnf idempotency pattern — `dpkg -s` per-package check vs a sentinel file written after successful bundle install. Decide before writing `taskfiles/packages.yml`. Not a research phase; a one-time implementation decision.

---

### Phase 6: OS Defaults + macOS Configuration

**Rationale:** macOS defaults tasks are the most machine-specific and the most user-visible. They must be gated by feature flags from Day 1 to avoid accidentally running on Linux. Building after manifest and identity layers ensures feature flags are already wired.

**Delivers:**
- `os/darwin/defaults/dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh` — one file per group
- `os/darwin/shell-registration.zsh` — adds brew zsh to `/etc/shells`, runs `chsh`; fixes `$BREW_ZSH` vs `{{.BREW_ZSH}}` live bug
- `taskfiles/macos.yml` — each defaults group gated by manifest feature; `status:` checks `defaults read <domain> <key>` before writing; no-op on Linux via platform check
- `task validate` extended: macOS defaults key values asserted against manifest expectations

**Avoids:** Pitfall 9 (the `$BREW_ZSH` bug is the canonical `status:` error; fix it here structurally)

**Research flags:** None — macOS `defaults` API and idempotent `status:` pattern are standard.

---

### Phase 7: Claude + Tool Configs

**Rationale:** Claude Code integration has the most conditional logic (feature flag gating, marketplace versioning, hooks) and the most known bugs from v1 (`gsd-install`, `agent-transparency.zsh`). Tool config symlinks are straightforward. Both belong in the same phase as the last functional component before validation.

**Delivers:**
- `claude/` ported from v1; `agent-transparency.zsh` rewritten (remove `local` at script scope; shellcheck-clean)
- `taskfiles/claude.yml` — GSD install with version-pinned sentinel file; marketplace install with `claude plugin list` status check; no `npx` on every install
- All hooks: `secret-scan.zsh`, `no-emojis.zsh`, `no-ai-comments.zsh`, `agent-transparency.zsh` — shellcheck-clean rewrites
- `configs/` symlinks for all tool configs (Ghostty, glow, trippy, tlrc, conda, eza, motd) via `taskfiles/links.yml`

**Avoids:** Pitfall 9 (gsd-install is the other live `status:` bug; fix structurally)

**Research flags:** GSD version sentinel — verify how `npx -y get-shit-done-cc@latest` surfaces its installed version before writing the `status:` check. One lookup, not a research phase.

---

### Phase 8: Validation + Cutover Readiness

**Rationale:** Per-component validate tasks accumulate throughout Phases 1-7. This phase composes them, fills cross-component gaps, and produces the artifacts that gate per-machine cutover. Cutover itself is not a scheduled event — it happens when each machine passes all gates.

**Delivers:**
- Root `task validate` chains all per-component validate tasks
- Validate extended: symlink readlink-target check (not just existence); git email assertion; startup budget check
- `task links:reconcile` — orphaned symlink removal (symlinks into `$DOTFILEDIR` not in manifest); runs as part of `task install`
- `docs/CUTOVER.md` — per-machine register with verification steps (100% validate, smoke test checklist, 7-day run requirement)
- Feature-parity diff checklist: every alias, function, hook, brew package, macOS default, symlink in v1 accounted for in v2
- `docs/MACHINES.md` — one section per machine with description, special config, rationale

**Avoids:** Pitfall 1 (manifest drift), Pitfall 4 (premature cutover), Pitfall 13 (bus-factor)

**Research flags:** None — structural composition; no new patterns.

---

### Phase Ordering Rationale

Two hard dependency chains drive the order:

**Chain 1 — Manifest is the keystone:** Phases 3-8 all read from `resolved.json`. Phase 1 (manifest engine) must be complete with tested merge semantics before any downstream task is written. The resolver is the single most important deliverable in the project.

**Chain 2 — Lint before content:** Phase 2 (lints, bootstrap) must exist before Phase 3 (shell content port) so that every alias added is immediately validated by `task lint:platform`. Retroactive linting of 50+ files is a known pain point in parallel rewrites.

**Other ordering rationale:**
- Platform taxonomy before content port: the `common/`/`darwin/`/`linux/` structure must be documented and the lint active before any v1 alias is ported
- Identity (Phase 4) before packages (Phase 5): identity mistakes are high-stakes; fix them in a focused phase before the longer-running package phase adds noise
- Validation (Phase 8) as composition: per-component validate tasks accumulate across all phases; the final phase composes and extends them, not writes them from scratch

### Research Flags

**Needs additional resolution before/during Phase 1:**
- **Deep-merge jq implementation**: The `jq -s '.[0] * .[1]'` in ARCHITECTURE.md is a shallow merge. Write test fixtures first, then choose between a recursive jq function or `yq eval-all '. as $i ireduce ({}; . * $i)'`. Verify all cases: map-over-map, list-replace, scalar-override, deeply nested table, missing-in-defaults, missing-in-machine.
- **go-task `ref:` syntax**: ARCHITECTURE.md uses `ref: 'fromJson .MANIFEST'` — verify this is valid syntax in go-task v3.50 before using Pattern B manifest loading.

**Needs a one-time check during Phase 7:**
- GSD marketplace version sentinel pattern — not a research phase, a 5-minute lookup.

**Standard patterns (skip research):**
- Phases 2, 4, 5, 6, 8 — bootstrap, git/ssh identity, packages, macOS defaults, validation — all well-documented with established patterns.
- antidote configuration (Phase 3) — docs are clear; configuration is empirical (measure, adjust).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every recommendation is either already in the repo or confirmed against 2026 official release notes. yq vs dasel conflict is resolved; yq wins. |
| Features | HIGH | Grounded in live codebase audit plus chezmoi/dotbot/home-manager comparison. MVP list maps 1:1 to PROJECT.md active requirements. |
| Architecture | HIGH for shape; MEDIUM for implementation details | Five-layer architecture is well-motivated with clear prior art. Two implementation details need correction: dasel → yq in sketches; shallow-merge jq expression → correct deep-merge. |
| Pitfalls | HIGH | All 13 pitfalls in PITFALLS.md have concrete live instances in CONCERNS.md. They are not speculative. |

**Overall confidence:** HIGH

### Gaps to Address

- **TOML deep-merge implementation**: The resolver implementation needs a correct recursive deep-merge, not `jq -s '.[0] * .[1]'`. Write and test this in Phase 1 before anything else reads `resolved.json`. Suggested approach: `yq eval-all '. as $i ireduce ({}; . * $i)' defaults.toml machine.toml -o=json > resolved.json` — verify against hand-computed expected output for one machine with non-trivial overrides.

- **apt/dnf idempotency**: ARCHITECTURE.md shows `apt install $(cat bundle.list)` but does not specify the `status:` check. Options: `dpkg -s <package>` per-package (verbose but correct) or a sentinel file written after successful bundle install (simpler but misses mid-install failures). Decide in Phase 5 planning.

- **antidote lazy-loading specifics**: Which plugins get `kind:defer` vs synchronous load is a performance-empirical question, not resolvable without measuring. The Phase 3 work is: install antidote with all plugins synchronous, measure startup, identify the slowest plugins via `zprof`, add `kind:defer` selectively, measure again. The 200ms CI gate provides the feedback loop.

- **Linux server bootstrap sequencing**: The resolver depends on yq being installed, but on a fresh Linux server, yq may not be present before `brew install` runs. The bootstrap sequence needs an explicit "install yq from apt/dnf/binary if Homebrew is not yet available" step. This is an ordering problem in Phase 2 that the research does not fully resolve.

## Sources

### Primary (HIGH confidence)
- `/Users/josh/Git/personal/dotfiles/.planning/codebase/CONCERNS.md` — live bug inventory; primary source for pitfall instances
- [taskfile.dev](https://taskfile.dev) — `status:`, `preconditions:`, `fromJson`, vars.sh; confirmed v3.50.0 (Apr 2026)
- [mikefarah/yq](https://github.com/mikefarah/yq) + [yq TOML docs](https://mikefarah.gitbook.io/yq/usage/toml) — TOML roundtrip since v4.52.1; v4.53.2 (Apr 2026)
- [mattmc3/antidote](https://github.com/mattmc3/antidote) — antigen successor; v2.1.0 (Apr 2026); static bundle; `kind:defer`
- [brew.sh Homebrew 5.1.0](https://brew.sh/2026/03/10/homebrew-5.1.0/) + [docs.brew.sh Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile) — `if OS.mac?`/`if OS.linux?` confirmed
- [chezmoi data model](https://www.chezmoi.io/reference/special-directories/chezmoidata/) — "maps merge, lists replace" semantics
- [developer.1password.com/docs/ssh/agent](https://developer.1password.com/docs/ssh/agent/) — socket paths; XDG support

### Secondary (MEDIUM confidence)
- [rossmacarthur/zsh-plugin-manager-benchmark](https://github.com/rossmacarthur/zsh-plugin-manager-benchmark) — antidote vs zinit benchmark data
- [starship.rs](https://starship.rs/) + community sources on p10k status — Starship recommendation
- [ghostty.org release notes 1.3.x](https://ghostty.org/docs/install/release-notes/) — GTK4/Linux stable
- [Speeding up Zsh by 81%](https://wicksipedia.com/blog/speeding-up-zsh-startup/) — antigen-to-zinit migration concrete data
- [romkatv/zsh-bench](https://github.com/romkatv/zsh-bench) — shell startup benchmark methodology
- [dotfiles.github.io](https://dotfiles.github.io/) — community pattern survey

### Tertiary (LOW confidence — verify during implementation)
- ARCHITECTURE.md implementation sketches using dasel — translate to yq before use
- ARCHITECTURE.md `manifest.yml` using `ref:` go-task syntax — verify in v3.50 before adopting Pattern B manifest loading
- ARCHITECTURE.md shallow-merge jq expression — replace with correct deep-merge before shipping

---
*Research completed: 2026-05-13*
*Ready for roadmap: yes*
