# Phase 3: Shell Layer — Flat Content Port - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 03-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 03-shell-layer-flat-content-port
**Areas discussed:** Antidote bundle + lazy-loading, Cross-machine alias gating, Personal jgrid metals + identity-coupled aliases

**Gray areas NOT selected by user (skipped in this session):** MOTD 24h cache architecture (deferred to planner)

---

## Antidote bundle + lazy-loading

### Question 1: How should v1's antigen plugin set port to antidote's `.zsh_plugins.txt`?

| Option | Description | Selected |
|--------|-------------|----------|
| Port verbatim | All seven plugins land 1:1 in `.zsh_plugins.txt` (ohmyzsh git/colorize/kubectl/extract + zsh-users syntax-highlighting/completions/autosuggestions). Antidote's static bundle gives the speed win on its own. | ✓ |
| Verbatim + drop unused omz noise | Same seven, but drop `ohmyzsh/ohmyzsh/lib/*` libraries that omz-git pulls transitively. | |
| Replace omz-git with native | Swap `ohmyzsh/ohmyzsh path:plugins/git` for `woefe/git-prompt.zsh` since theme only needs `git_prompt_info`/`git_prompt_status`. | |
| You decide | Pick the smallest port that hits 200ms. | |

**User's choice:** Port verbatim
**Notes:** Maximum muscle memory preservation. Antidote vs antigen is the speed lever.

### Question 2: Antidote `kind:defer` / `kind:zsh-defer` — apply to any plugins?

| Option | Description | Selected |
|--------|-------------|----------|
| Defer the three slowest | `kubectl`, `zsh-syntax-highlighting`, `zsh-autosuggestions` get `kind:defer`; rest load eagerly. | |
| Defer everything except git | Only `git` loads eagerly (theme depends on it); everything else defers. Aggressive. | |
| No defer | Static bundle alone is the lever. Ship simpler config; revisit defer only if `task perf:shell` regresses. | ✓ |
| You decide | Pick whatever combination hits 200ms with the simplest config. | |

**User's choice:** No defer
**Notes:** Trust the static bundle to do the work; layer defer in later if perf demands it.

### Question 3: Where does the antidote bundle file live, and where does the generated cache go?

| Option | Description | Selected |
|--------|-------------|----------|
| Bundle in repo, cache in XDG | Source at `shell/.zsh_plugins.txt` (in repo, symlinked to `$ZDOTDIR`). Cache at `$XDG_CACHE_HOME/antidote/zsh_plugins.zsh`. | |
| Bundle in configs/, cache in XDG | Source at `configs/antidote/zsh_plugins.txt` (matches configs/<tool>/ convention). Same XDG cache. | ✓ |
| You decide | Pick a placement consistent with conventions. | |

**User's choice:** Bundle in configs/, cache in XDG
**Notes:** Symmetric with other tool configs (ghostty, glow, trippy).

### Question 4: When does the generated static bundle get rebuilt?

| Option | Description | Selected |
|--------|-------------|----------|
| On `task install` | `task shell:plugins:bundle` runs as part of `task install`; `status:` mtime-gated. Shell startup just sources the cache. | |
| Lazy on shell startup | `.zshrc` mtime-checks the cache; rebuilds if stale. Self-healing on first shell after edit. | ✓ |
| Both: install builds, shell self-heals | Install builds for the converged case; shell self-heals for the edit-without-install case. | |
| You decide | Pick the model that survives the AI-edits-the-plugins-file workflow. | |

**User's choice:** Lazy on shell startup
**Notes:** Keeps install simple; shell owns its own cache.

---

## Cross-machine alias gating

### Question 1: How to handle macOS-GUI-only aliases on headless Mac servers?

| Option | Description | Selected |
|--------|-------------|----------|
| No gating — port verbatim | All machines are macOS; aliases like `finder` are harmless on servers (`open` exists). | |
| Split files by domain | Re-categorize during port: move Finder/macOS-GUI aliases into `shell/aliases/macos-gui.zsh`, gated via a new feature flag. | |
| Identity feature flag | Same split, but gate on existing `features.macos-finder`/`macos-dock` flags (already in machine TOMLs). Reuses signal. | ✓ |
| You decide | Pick the gating that's simplest without surprising on a fresh Mac server. | |

**User's choice:** Identity feature flag (reuse existing)

### Question 2: Where does the gating logic live?

| Option | Description | Selected |
|--------|-------------|----------|
| Filename-prefix + zshrc glob skip | Files prefixed `gui-` (e.g., `gui-finder.zsh`) skipped by zshrc's glob loop based on feature. | |
| Per-file early-return | File self-gates at source-time via `[[ ... ]] || return 0`. | |
| Single guard block in zshrc | `.zshrc` reads `resolved.json` once and conditionally sources files by name. | ✓ |
| You decide | Pick the model that lets an AI agent add a gated alias by following one pattern. | |

**User's choice:** Single guard block in zshrc
**Notes:** Reconciled in Question 4/5 below — actual implementation is wrapper-functions-with-lazy-helper, not zshrc reading manifest directly.

### Question 3: Which v1 aliases need extraction into gated files?

| Option | Description | Selected |
|--------|-------------|----------|
| Just Finder aliases | Extract `finder`, `findershow`, `finderhide` into `shell/aliases/finder.zsh` gated on `features.macos-finder`. | |
| Finder + Ghostty | Add `g='Ghostty.app'` extraction into `shell/aliases/ghostty.zsh` gated on new `features.ghostty`. | ✓ |
| All GUI-adjacent aliases | Conservative: every alias referencing `.app/`, `open -a`, or GUI `defaults write` gets gated. | |
| You decide | Pick the smallest gating set. | |

**User's choice:** Finder + Ghostty
**Notes:** Two gated files, two feature flags. Everything else (system_profiler, etc.) ports verbatim into general flat files.

### Question 4: How does `.zshrc` learn feature values cheaply (200ms budget)?

| Option | Description | Selected |
|--------|-------------|----------|
| Generated features.zsh sourced from zshrc | `task install` writes a flat exports file; zshrc sources it (~1ms). | |
| jq once at zshrc start | Single jq eval'd into exports at zshrc top (~10ms). Manifest is single source of truth at runtime. | |
| Lazy on first use | `_dotfiles_feature` shell function does jq lookup only when called; gated aliases wrap and check on first invocation. | ✓ |
| You decide | Pick what keeps the 200ms target safe. | |

**User's choice:** Lazy on first use
**Notes:** Reconciled (Q5) to wrapper-function model — gated alias FILES define zsh functions that call `_dotfiles_feature` on first invocation, not at source-time.

### Question 5 (reconcile): Confirm — gated files use wrapper functions (lazy at call-time), zshrc never blocks on jq?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — wrapper functions | Gated files define zsh functions; first line calls `_dotfiles_feature`; returns early if false. zshrc unconditional. | ✓ |
| Source-time check instead | Files self-gate at source time. First call triggers jq read once at zshrc time. Aliases don't exist on non-matching machines. | |
| You decide — planner reconciles | Lock spirit; let planner pick. | |

**User's choice:** Yes — wrapper functions

---

## Personal jgrid metals + identity-coupled aliases

### Question 1: Where does identity-keyed alias content land in the flat layout?

| Option | Description | Selected |
|--------|-------------|----------|
| Gate via feature flag, same as macOS-GUI | `shell/aliases/jgrid.zsh` defined as wrapper functions; new `features.jgrid-net` flag. Consistent with the gating model just locked. | ✓ |
| Gate on identity.git == "personal" | Same wrapper model but check identity rather than a feature flag. | |
| Relocate to Phase 4 (identity layer) | jgrid is identity-network coupling; move to `identity/network/<name>/aliases.zsh`. | |
| Land verbatim, no gating | Source unconditionally; broken hosts harmless. | |

**User's choice:** Gate via feature flag, same as macOS-GUI

### Question 2: 22-metal bulk-alias loop — wrapper-function-per-alias is awkward. Resolve.

| Option | Description | Selected |
|--------|-------------|----------|
| Source-time gate (exception for bulk loops) | File opens with `[[ ... ]] || return 0` then runs the metal loop. Pays one-time jq cost only on personal-laptop. Establishes documented pattern: source-time for bulk-alias-loops; wrapper-function for 1-3 alias files. | ✓ |
| Install-time generation | `task shell:install` generates `$XDG_STATE_HOME/dotfiles/shell-cache/jgrid-aliases.zsh` only if feature is true. zshrc sources the cache dir. | |
| Single dispatcher function | `jgrid <metal>` instead of 22 standalone aliases. Breaks v1 muscle memory. | |
| You decide | Pick what's consistent with the wrapper-function gating already locked. | |

**User's choice:** Source-time gate (exception for bulk loops)

### Question 3: Other identity-coupled aliases in v1 needing similar handling?

| Option | Description | Selected |
|--------|-------------|----------|
| jgrid is the only one | v1 has only `aliases/personal/jgrid.zsh`; no `aliases/work/*` and no `functions/{personal,work}/`. Pattern handles full v1 surface. | ✓ |
| Audit functions/ subdir too | Confirm no `functions/{personal,work}/` exist. | |
| You decide | Pick the safer audit. | |

**User's choice:** jgrid is the only one

---

## Claude's Discretion

User explicitly deferred to planner / Claude:

- **MOTD cache architecture (SHEL-11)** — not selected as a discussion area; planner picks 24h TTL mechanics, cache file location, async-refresh trigger.
- **compinit daily-rebuild cache (SHEL-10)** — planner concern inside P3.
- **Topic split inside `shell/aliases/`** — how v1's `general.zsh`/`hardware.zsh`/`networking.zsh` break into v2 topic files (one-concept-per-file binding).
- **`.zshrc` startup-cost order** — plugin load → theme → aliases → functions → feature priming.
- **`task perf:shell` measurement tool** — hyperfine vs zprof.
- **`.zprofile` 1Password feature check mechanism** — jq via `_dotfiles_feature` at login-shell start vs precomputed env var written by `task setup`.
- **Theme-port "as-is" bug-fix policy** — strict literal unless startup breaks.
- **Sibling-README pattern propagation** — P3 writes `shell/README.md` as anchor; subsequent phases replace their stubs; Phase 8 verifies coverage.
- **Feature flag final names** — `features.ghostty` vs `features.ghostty-launcher`; `features.jgrid-net` vs `features.jgrid`.

---

## Deferred Ideas

- **Aggressive `kind:defer` / `kind:zsh-defer`** — revisit only if `task perf:shell` flags regression.
- **Move from antidote to zinit** — if 200ms slips badly.
- **Audit-and-trim of v1 aliases/functions** — OOS per PROJECT.md.
- **Precomputed `features.zsh` exports** — future micro-optimization if perf demands.
- **Linux platform-aware split for `shell/`** — v2 Linux roadmap.
- **Starship swap** — OOS per PROJECT.md / SHEL-05.
- **MOTD cache details, compinit cache mechanics** — planner concern inside P3 (not separate phase deferral, just not pre-decided here).
- **Tool config moves (configs/ghostty, configs/glow, configs/trippy, etc.)** — Phase 7.
- **SSH config wiring** — Phase 4.
- **`task validate` shell-layer health checks** — Phase 8.
