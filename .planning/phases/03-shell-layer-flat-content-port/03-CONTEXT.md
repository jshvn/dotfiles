# Phase 3: Shell Layer — Flat Content Port - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the v1 `zsh/` tree to a flat `shell/` layout under a 200ms cold-start budget. Swap antigen → antidote (the primary lever). Replace `DOTFILES_PROFILE` with `DOTFILES_MACHINE` sourced from `$XDG_STATE_HOME/dotfiles/machine`. Ship the v1 alanpeabody-based prompt verbatim. Achieve v1 feature parity for every alias and function — auditing for keep-or-cut is OOS per PROJECT.md.

**In scope:**
- `shell/.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout` — five startup files, each ported from v1 `zsh/*.zsh*` with v1 conventions preserved
- `shell/theme.zsh` — port v1 `zsh/theme.zsh` (alanpeabody-based) as-is
- `shell/aliases/<topic>.zsh` — flat layout (no `common/`, `personal/`, `darwin/` subdirs); every v1 alias ported
- `shell/functions/<name>.zsh` — flat layout; every v1 function ported
- `configs/antidote/zsh_plugins.txt` — antidote source bundle list (seven plugins from v1's antigen)
- `_dotfiles_feature <name>` lazy helper — used to gate `finder.zsh`, `ghostty.zsh`, `jgrid.zsh` against manifest features
- `defaults.toml` additions: `features.ghostty`, `features.jgrid-net` (and confirm `features.macos-finder`)
- `task perf:shell` — measures cold interactive shell start; fails non-zero above 200ms
- MOTD caching with 24h TTL (SHEL-11) + compinit daily cache (SHEL-10) — mechanics deferred to planner
- `shell/README.md` — purpose, key files, how-to-add-pattern (anchor for the sibling-README pattern referenced by SC#6)

**Out of scope (deferred to later phases):**
- Identity-layer logic (Phase 4) — `.zprofile`'s 1Password SSH agent block still uses a manifest-feature check (`one-password-ssh`) in P3, but the SSH config wiring is P4
- Brewfile composition (Phase 5)
- macOS defaults (Phase 6) — `defaults write` on Finder/dock lives there, not here
- Claude install + tool config symlinks (Phase 7) — Ghostty/glow/trippy/tlrc/conda config dirs are P7
- v1 modifications on master — v1 stays byte-stable

**Required ROADMAP / REQUIREMENTS edits (planner action items):**
- None blocking; current ROADMAP Phase 3 success criteria match the locked decisions.

**Requirements addressed:** SHEL-01, SHEL-02, SHEL-03, SHEL-04, SHEL-05, SHEL-06, SHEL-07, SHEL-08, SHEL-09, SHEL-10, SHEL-11, SHEL-12, DOCS-02

</domain>

<decisions>
## Implementation Decisions

### Antidote Plugin Manager

- **D-01: Port v1's antigen plugin set verbatim into `configs/antidote/zsh_plugins.txt`.** The seven plugins land 1:1:
  ```
  ohmyzsh/ohmyzsh path:plugins/git
  ohmyzsh/ohmyzsh path:plugins/colorize
  ohmyzsh/ohmyzsh path:plugins/kubectl
  ohmyzsh/ohmyzsh path:plugins/extract
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-completions
  zsh-users/zsh-autosuggestions
  ```
  Maximum muscle memory preservation. The static-bundle-file mechanic (antidote vs antigen) is the speed win on its own — no plugin substitution needed.
- **D-02: No `kind:defer` / `kind:zsh-defer`.** Antidote's static bundle alone is the 200ms lever. Defer adds complexity (`zsh-syntax-highlighting` ordering quirks) for marginal gain. Revisit only if `task perf:shell` flags regression on a converged machine.
- **D-03: Bundle source location — `configs/antidote/zsh_plugins.txt`.** Lives alongside other tool configs (ghostty, glow, trippy) under `configs/<tool>/`, symlinked through `_:safe-link` into `$ZDOTDIR/.zsh_plugins.txt` if needed. Consistent with the configs/<tool>/ convention.
- **D-04: Static bundle cache — `$XDG_CACHE_HOME/antidote/zsh_plugins.zsh`.** Machine-local, never committed.
- **D-05: Bundle regeneration is lazy on shell startup.** `.zshrc` does an mtime check: if the cache file is missing or older than `configs/antidote/zsh_plugins.txt`, it runs `antidote bundle < configs/antidote/zsh_plugins.txt > $XDG_CACHE_HOME/antidote/zsh_plugins.zsh`. Then sources the cache. `task install` does NOT pre-build — keeps install simple, shell owns its own cache. Cost: one `stat` per shell startup (~1ms) plus a rare `antidote bundle` after edits.

### Cross-Machine Alias Gating (flat-dir contract)

- **D-06: `_dotfiles_feature <name>` lazy helper.** Defined in `shell/functions/_dotfiles_feature.zsh` (or equivalent). On first call, reads the active machine's `resolved.json` once via `jq` and caches results in a shell associative-array global (e.g., `_DOTFILES_FEATURES`). Subsequent calls are O(1) lookups. Helper returns `"true"` / `"false"` on stdout; callers test with `[[ "$(_dotfiles_feature foo)" == "true" ]]`.
- **D-07: Gated alias files are defined as wrapper functions, not bare aliases.** `shell/aliases/finder.zsh` and `shell/aliases/ghostty.zsh` define `finder()`, `findershow()`, `finderhide()`, `g()` as zsh functions. First line of each function calls `_dotfiles_feature` and either runs the body or prints a `feature 'macos-finder' is disabled on this machine` message to stderr and returns 1.
- **D-08: Source-time gate is the documented exception for bulk-alias-loop files.** `shell/aliases/jgrid.zsh` opens with `[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0` then runs the 22-element metal loop. Pays a one-time jq cost (~10ms) only when the feature is enabled (i.e., only on personal-laptop). Pattern: source-time gate for bulk-alias-loop files; wrapper-function gate for 1-3 alias files.
- **D-09: `.zshrc` sources every `shell/aliases/*.zsh` and `shell/functions/*.zsh` unconditionally** via glob (`(.N)` nullglob qualifier). No conditional file lists in `.zshrc`. Gating lives in the file itself (wrapper function or source-time gate). `.zshrc` stays clean and AI-agent-readable: add a new alias file → it loads on every machine that wants it (or self-gates if it shouldn't).
- **D-10: Gated alias scope (v1 inventory walk).** Only two GUI-coupled files extracted:
  - `shell/aliases/finder.zsh` — `finder`, `findershow`, `finderhide` (3 aliases → 3 wrapper functions) gated on `features.macos-finder` (already in `defaults.toml`/personal-laptop.toml).
  - `shell/aliases/ghostty.zsh` — `g` (1 alias → 1 wrapper function) gated on new `features.ghostty` (add to `defaults.toml`; true on personal-laptop and work-laptop; false on servers).
  - Everything else (`hardware.zsh` system_profiler, `lastinstalled`, `networking.zsh`, `history`, `dotfile`/`dotfiles`, `t`, `ls`/`ll`, `path`, `reload`, etc.) ports verbatim into `shell/aliases/general.zsh` (or topical splits like `dotfiles.zsh`, `task.zsh`) and sources unconditionally — harmless on every macOS machine.

### Identity-Coupled Aliases (jgrid metals)

- **D-11: jgrid metals stay in `shell/`, gated by manifest feature.** `shell/aliases/jgrid.zsh` ports v1's `aliases/personal/jgrid.zsh` verbatim — the 22-element `METALS=(...)` array and the `for i in $METALS; do alias $i="ssh josh@$i-ssh.jgrid.net"; done` loop. Gating via source-time check on `features.jgrid-net` (D-08 pattern).
- **D-12: New feature flag `features.jgrid-net` added to `defaults.toml`.** Default `false`. Set to `true` only on `manifests/machines/personal-laptop.toml`. Planner adds the manifest edits as part of P3.
- **D-13: jgrid is the only identity-coupled file in v1.** No `aliases/work/*.zsh` exists. No `functions/personal/` or `functions/work/` exists. The flat-layout + feature-flag pattern handles v1's full identity-coupled surface. If a `work-net` analogue appears later, it follows the same pattern (new feature flag, new gated file).

### Carried Forward (not re-decided in this discussion)

- **CF-01:** Flat directory layout — `shell/aliases/<topic>.zsh`, `shell/functions/<name>.zsh`, no subdirectories. (Phase 1 D-10.) Linux reshape cost accepted.
- **CF-02:** v1 `zsh/theme.zsh` (alanpeabody-based) ported as-is to `shell/theme.zsh`; Starship rejected. (PROJECT.md OOS, SHEL-05.)
- **CF-03:** Antidote replaces Antigen. (SHEL-04.)
- **CF-04:** `DOTFILES_MACHINE` exported from `$XDG_STATE_HOME/dotfiles/machine`; no `DOTFILES_PROFILE` anywhere. (SHEL-01.)
- **CF-05:** Missing-state hard-fail with actionable error (Phase 1 D-16 pattern) reused when `$XDG_STATE_HOME/dotfiles/machine` is absent — `.zshenv` must degrade gracefully (zsh sourced by cron/scp without state shouldn't crash); `.zshrc` (interactive) may emit a warning pointing to `task setup -- <machine-name>`.
- **CF-06:** `update='task install'` alias ships in P3, replaces v1's `zsh/functions/update.zsh`. (Phase 2 D-10.) Lands in `shell/aliases/dotfiles.zsh` or similar topic file at planner's discretion.
- **CF-07:** `set -euo pipefail` on every executable `.zsh`; lint suite from Phase 2 enforces. Sourced-only files (`aliases/*.zsh`, `functions/*.zsh`) are exempt — they're not executable.
- **CF-08:** No hardcoded `/opt/homebrew` or `/usr/local`; `.zprofile` must detect via `uname -m` or read `$HOMEBREW_PREFIX`. (Global convention; v1 already does this.)
- **CF-09:** XDG base directory spec — `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` exported in `.zshenv` with `:-$HOME/.x` fallbacks.

### Claude's Discretion (planner concerns)

- **MOTD cache architecture (SHEL-11)** — 24h TTL, async refresh, cache file location, what triggers initial populate. Planner picks; options include: `motd:refresh` task with cron-style mtime gate; display-stale-then-async-refresh on shell start; `&` background refresh after display. Cache file convention: `$XDG_CACHE_HOME/dotfiles/motd.cache` (machine-local).
- **compinit daily-rebuild cache (SHEL-10)** — Typical pattern: check `zcompdump` age via `mtime`, only run `compinit -d $ZSH_COMPDUMP` if older than 24h; else `compinit -C $ZSH_COMPDUMP` (fast path, no security check). Planner picks exact implementation.
- **Topic split inside `shell/aliases/`** — How to break v1's `general.zsh` / `hardware.zsh` / `networking.zsh` into v2 topic files. One-concept-per-file is binding; suggested splits: `dotfiles.zsh` (dotfile/dotfiles/reload + update), `task.zsh` (`t`), `eza.zsh` (ls/ll), `path.zsh`, `history.zsh`, `hardware.zsh`, `networking.zsh`. Planner finalizes.
- **`.zshrc` startup-cost order** — Plugin bundle load → theme load → aliases glob → functions glob → `_dotfiles_feature` priming (or lazy). Some orderings trade ms; planner profiles.
- **`task perf:shell` measurement tool** — `hyperfine` (already in research stack) is the obvious choice; `zprof` for one-off profiling. Planner picks.
- **`.zprofile` 1Password block** — v1 uses literal `hostname -s != "server"` check (PROJECT.md known issue). v2 must use a manifest feature check (`features.one-password-ssh`). Planner decides whether `.zprofile` calls `_dotfiles_feature` (which costs jq at login-shell start) or reads a precomputed env var written by `task setup`. Phase 4 owns the SSH config wiring; Phase 3 only sets `SSH_AUTH_SOCK` based on the feature.
- **Theme-port "as-is" bug-fix policy** — Strict literal port unless a bug breaks startup. Phase 2's lint catches the obvious classes (`set -e` alone, etc.); theme.zsh is sourced (not executable) so most lint rules don't apply. Planner uses judgement on edge cases.
- **Sibling-README pattern propagation (SC#6, DOCS-02)** — P3 writes `shell/README.md` as the anchor. Whether P3 also writes `identity/README.md`, `packages/README.md`, `configs/README.md`, `os/README.md`, `claude/README.md` (replacing Phase 1 stubs) or whether each owning phase writes its own is a planner call. Recommendation: P3 establishes the template via `shell/README.md` and DOCS-02 captures the *contract* — subsequent phases replace stubs with content during their phase work. Phase 8 verifies all top-level READMEs exist.
- **Feature flag naming** — `features.ghostty` and `features.jgrid-net` are working names. Planner may rename for consistency (e.g., `features.ghostty-launcher` vs `features.ghostty`; `features.jgrid` vs `features.jgrid-net`). Kebab-case rule binding.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints (parallel rewrite, no hostname inference, no AI attribution, no emojis), v1 feature parity contract, known v1 issues to fix structurally
- `.planning/REQUIREMENTS.md` — Full requirements list (SHEL-01..12 + DOCS-02 in scope for P3)
- `.planning/ROADMAP.md` Phase 3 section — Goal, success criteria, requirement mapping
- `.planning/STATE.md` — Pre-Phase-3 state (Phase 2 complete; antidote pre-decision from research)

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md` — Phase 1 decisions binding on P3:
  - **D-10:** Flat directory layout for v1; Linux reshape cost accepted
  - **D-14:** Auto-rebuild via task precondition — `manifest:resolve` ensures `resolved.json` is fresh before any task that reads it; `_dotfiles_feature` can rely on the file being fresh after `task install`
  - **D-15:** `resolved.json` at `$XDG_STATE_HOME/dotfiles/resolved.json` — machine-local, not in repo
  - **D-16:** Missing-state hard-fail pattern — `.zshenv` / `.zshrc` reuse this approach when `$XDG_STATE_HOME/dotfiles/machine` is missing
- `.planning/phases/02-install-engine-bootstrap-idempotency-lint/02-CONTEXT.md` — Phase 2 decisions binding on P3:
  - **D-10:** `task install` is canonical; `update='task install'` alias ships in P3
  - **D-13:** Lint severity model — `shell/.zshenv` etc. must pass LINT-04 (executable `.zsh` with `set -euo pipefail`); sourced alias/function files exempt
  - **D-14:** Lint scope covers every `.zsh` under repo — P3's `shell/` tree comes under lint coverage as content lands

### Domain Research (already on disk)
- `.planning/research/STACK.md` — Antidote v2.1+ rationale, eza/bat/ripgrep/fd/fzf/zoxide table-stakes, `zsh -n` (not shellcheck) for zsh files. Note: STACK.md recommends Starship; PROJECT.md / SHEL-05 explicitly override to keep v1's alanpeabody theme — research is informational, not binding here.
- `.planning/research/SUMMARY.md` — Synthesized research findings
- `.planning/research/PITFALLS.md` — Drift class (manifest vs runtime); applies to `_dotfiles_feature` cache freshness

### Existing Codebase (v1 patterns — port what works, fix the known bugs in transit)
- `.planning/codebase/CONCERNS.md` — Live v1 bugs P3 must NOT reintroduce:
  - `.zprofile:55-56` (literal `"server"` hostname check for 1Password) → must use `features.one-password-ssh` instead
  - `aliases/common/hardware.zsh` references macOS-only `system_profiler` — fine on macOS-only v1
  - `aliases/common/general.zsh:27-31` Finder aliases — extracted to gated `shell/aliases/finder.zsh` per D-10
  - `aliases/common/networking.zsh:4` `traceroute` aliased to `trip` (trippy) — fine to port verbatim if `trippy` is in the core Brewfile (Phase 5)
  - `antigen apply` and synchronous MOTD push interactive shell to ~500ms — D-01..D-05 (antidote) and the MOTD cache (planner) address this
  - `agent-transparency.zsh` uses `local` at script scope (Phase 7's hook fix, not P3)
- `.planning/codebase/CONVENTIONS.md` — v1 naming/scripting conventions; `set -euo pipefail`, kebab-case files, no AI attribution, file-level comment block at top of every script
- `.planning/codebase/STRUCTURE.md` — v1 `zsh/` tree (what we're porting from):
  - `zsh/.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout` — five startup files
  - `zsh/theme.zsh` — alanpeabody-based prompt (port verbatim)
  - `zsh/aliases/common/` (3 files: general.zsh, hardware.zsh, networking.zsh)
  - `zsh/aliases/personal/` (1 file: jgrid.zsh)
  - `zsh/functions/` (22 files at root: afk, aliaslist, cheat, docker, fs, functionlist, geoip, getcertnames, ghpubkey, host, info, ipv4lookup, ipv6lookup, mkcd, motd, permissions, prettyjson, pubkey, sethostname, sshlist, timezsh, update, vnc, whois)
  - `zsh/configs/` (ghostty, glow.yml, motd_sysinfo.jsonc, motd_tron.txt, tlrc.toml, trippy.toml, condarc) — Phase 7 owns the move to `configs/<tool>/`; P3 only references the MOTD-related ones via the cached MOTD function
  - `zsh/styles/` (eza, glow) — Phase 7 owns the move

### Manifest Layer (P3 reads, doesn't write, except for new feature flags)
- `manifests/defaults.toml` — current `[features]`: `one-password-ssh`, `motd`, `claude-marketplace`. P3 adds: `ghostty`, `jgrid-net`. (`macos-finder` already exists in machine TOMLs as a feature key.)
- `manifests/machines/*.toml` — P3 edits: enable `features.ghostty` on personal-laptop + work-laptop; enable `features.jgrid-net` on personal-laptop only.
- `docs/MANIFEST.md` — schema reference. P3 documents the new feature keys.

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — v2 conventions: kebab-case feature names need `index` access in templates; manifests are source of truth (no hostname inference); flat `shell/aliases/` in v1
- `.claude/CLAUDE.md` — Project-level Claude instructions (v1 references but conventions transfer)
- `~/.config/claude/CLAUDE.md` — Global conventions (Code section, Language Tooling: shellcheck conventions, XDG base directories)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (port from v1; fix known bugs in transit)
- **`install/messages.zsh`** — colored output library (info/success/warn/error/check/cross + `DOTFILES_MESSAGES_LOADED` guard). Reused by `task perf:shell` for output. Already on disk; Phase 1 preserved.
- **v1 `zsh/theme.zsh`** — port verbatim to `shell/theme.zsh`. Uses `git_prompt_info` / `git_prompt_status` from omz-git plugin — that's why D-01 ports omz-git rather than swapping to a leaner git-prompt.
- **v1 `zsh/.zshenv` XDG block** — first 30 lines port verbatim (XDG vars, ZDOTDIR, HISTFILE, EDITOR, LANG/LC_ALL). The `DOTFILES_PROFILE=$(cat $XDG_CONFIG_HOME/dotfiles/profile ...)` block is replaced with `DOTFILES_MACHINE=$(cat $XDG_STATE_HOME/dotfiles/machine ...)`.
- **v1 `zsh/.zprofile`** — Homebrew shellenv detection via `uname -m` ports as-is; the 1Password `SSH_AUTH_SOCK` block must replace literal `hostname -s != "server"` with `features.one-password-ssh` check.
- **v1 `zsh/.zshrc`** — overall shape ports (compinit + ZSH_COMPDUMP, conda lazy init, VSCode shell integration, alias glob loop, theme source, function glob loop). The antigen block at top is replaced by antidote source + bundle file logic. Profile-specific subdirectory loops collapse into flat globs.
- **v1 `zsh/.zlogin`** — `if (( $+functions[motd] )); then motd; fi` ports verbatim; the `motd` function itself must be cache-backed (SHEL-11).
- **v1 functions** — 22 files port verbatim into `shell/functions/<name>.zsh` (one per file, name matches function). `motd.zsh` is rewritten to honor the 24h TTL cache.

### Established Patterns (binding on P3)
- **`set -euo pipefail` on every executable `.zsh`** — `shell/.zshenv`/`.zprofile`/`.zshrc`/`.zlogin`/`.zlogout` are sourced (not executable) → exempt from LINT-04. But internal helper scripts under `shell/lib/` (if any) follow the rule.
- **One concept per file** — alias topic / function name / startup-file role. Bundle file lives at `configs/antidote/zsh_plugins.txt`, not inline in `.zshrc`.
- **`$XDG_STATE_HOME/dotfiles/` as machine-local state surface** — `machine`, `resolved.json`, `cutover-ack` (Phase 2). P3 reads from this dir; no new file types added.
- **Manifest as runtime source of truth** — `_dotfiles_feature` reads `resolved.json` (regenerated by `manifest:resolve` whenever a TOML changes); no hostname inference, no env-var sniffing.
- **`zsh -n` as syntax check** — Phase 2 LINT-07 already covers `.zsh` files; P3's new content comes under coverage automatically.

### Integration Points
- **`shell/` → `manifests/`** — `_dotfiles_feature` reads `$XDG_STATE_HOME/dotfiles/resolved.json`. If the file is missing (fresh machine, before `task setup`), helper returns `"false"` for every feature (degrade gracefully; loud-fail only inside `.zshrc` interactive path).
- **`shell/` → `taskfiles/`** — Phase 3 adds `taskfiles/shell.yml` (or similar) for `task shell:install` (symlink `shell/.zshenv` → `$ZDOTDIR/.zshenv`, etc.) and `task perf:shell`. The install task uses `_:safe-link` (no bare `ln`).
- **`shell/` → `configs/`** — `configs/antidote/zsh_plugins.txt` is the only configs/ entry P3 creates. Other tool configs (ghostty, glow, trippy, tlrc, conda, eza, motd) move from v1 `zsh/configs/` to v2 `configs/<tool>/` in Phase 7.
- **`.zlogin` → `motd` function** — P3 keeps the v1 pattern (`(( $+functions[motd] )) && motd`); the function itself is cache-backed.

</code_context>

<specifics>
## Specific Ideas

- **`_dotfiles_feature` helper sketch:**
  ```zsh
  # shell/functions/_dotfiles_feature.zsh
  typeset -gA _DOTFILES_FEATURES
  _dotfiles_features_loaded=0

  function _dotfiles_feature() {
      local name="$1"
      if (( ! _dotfiles_features_loaded )); then
          local resolved="$XDG_STATE_HOME/dotfiles/resolved.json"
          if [[ -r "$resolved" ]]; then
              while IFS='=' read -r k v; do
                  _DOTFILES_FEATURES[$k]="$v"
              done < <(jq -r '.features | to_entries[] | "\(.key)=\(.value)"' "$resolved" 2>/dev/null)
          fi
          _dotfiles_features_loaded=1
      fi
      echo "${_DOTFILES_FEATURES[$name]:-false}"
  }
  ```
  Planner refines: handle missing-file path, exit code conventions, integration with `set -u`.

- **`shell/aliases/finder.zsh` sketch (wrapper-function pattern):**
  ```zsh
  # shell/aliases/finder.zsh -- Finder GUI aliases (gated on features.macos-finder)
  function finder() {
      [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
          || { echo "finder: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
      open -a Finder ./
  }
  function findershow() { ... }
  function finderhide() { ... }
  ```

- **`shell/aliases/jgrid.zsh` sketch (source-time gate, bulk-loop exception):**
  ```zsh
  # shell/aliases/jgrid.zsh -- jgrid.net allomantic-metals ssh-jump aliases (gated on features.jgrid-net)
  [[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0

  local METALS=(steel iron zinc brass pewter tin copper bronze \
                duralumin aluminum gold electrum nicrosil chromium \
                cadmium bendalloy atium malatium lerasium harmonium \
                trellium raysium)
  for i in $METALS; do
      alias $i="ssh josh@$i-ssh.jgrid.net"
  done
  unset METALS
  ```

- **`.zshrc` antidote block sketch:**
  ```zsh
  # antidote: static bundle, lazy-rebuilt
  local _antidote_src="$DOTFILEDIR/configs/antidote/zsh_plugins.txt"
  local _antidote_cache="$XDG_CACHE_HOME/antidote/zsh_plugins.zsh"
  if [[ ! -f "$_antidote_cache" || "$_antidote_src" -nt "$_antidote_cache" ]]; then
      mkdir -p "${_antidote_cache:h}"
      antidote bundle < "$_antidote_src" > "$_antidote_cache"
  fi
  source "$_antidote_cache"
  ```

- **`.zshenv` machine-id block sketch:**
  ```zsh
  # Read active machine from state surface (written by `task setup -- <name>`)
  if [[ -r "$XDG_STATE_HOME/dotfiles/machine" ]]; then
      DOTFILES_MACHINE="$(<$XDG_STATE_HOME/dotfiles/machine)"
      export DOTFILES_MACHINE
  fi
  # NOTE: .zshenv is sourced by non-interactive contexts (cron, scp); do NOT loud-fail here.
  # .zshrc handles the missing-machine case for interactive shells.
  ```

- **New manifest feature flags (P3 adds to `defaults.toml`):**
  ```toml
  [features]
  one-password-ssh = false
  motd = true
  claude-marketplace = true
  macos-finder = false      # gates shell/aliases/finder.zsh
  ghostty = false           # gates shell/aliases/ghostty.zsh
  jgrid-net = false         # gates shell/aliases/jgrid.zsh
  ```
  Then in `manifests/machines/personal-laptop.toml`: `macos-finder = true`, `ghostty = true`, `jgrid-net = true`. In `work-laptop.toml`: `macos-finder = true`, `ghostty = true`, `jgrid-net = false`. Servers: all three false (default).

</specifics>

<deferred>
## Deferred Ideas

### Owned by later phases (do not pull into P3 scope)
- **MOTD cache architecture details** — SHEL-11 says "MOTD output is cached to disk with 24-hour TTL (async refresh)." Mechanics (cache file, async-refresh trigger, what happens on first login) are planner-level decisions inside P3, but if the design grows complex, the *task* `task motd:refresh` is a P3 deliverable while the cache *file format* is implementation. No external owner.
- **compinit daily cache (SHEL-10)** — same story; planner concern inside P3.
- **Sibling-README writes for non-shell top-level dirs** — DOCS-02 says every top-level dir has a README. P3 writes `shell/README.md` as the anchor; Phase 4-7 each replace their stub READMEs when content lands; Phase 8 verifies. P3 does NOT write all sibling READMEs upfront.
- **Move v1 `zsh/configs/` to v2 `configs/<tool>/`** — Phase 7 (TOOL-01..04). P3 keeps the v1 paths working until P7 cuts over.
- **Move v1 `zsh/styles/` to v2 `configs/<tool>/styles`** — Phase 7.
- **Tool config symlinks (Ghostty, glow, trippy, tlrc, conda, eza, motd)** — Phase 7 (TOOL-01..04).
- **SSH config wiring beyond `SSH_AUTH_SOCK`** — Phase 4 (IDNT-03).
- **`task validate` composition with shell-layer health checks** — Phase 8 (CUTV-01).

### Future hardening (out of v1 scope)
- **Aggressive `kind:defer` / `kind:zsh-defer`** — revisit only if `task perf:shell` flags regression on a converged machine.
- **Move from antidote to zinit** — if 200ms target slips badly. Antidote's static bundle is the current pick.
- **Audit-and-trim of v1 aliases/functions** — explicitly OOS per PROJECT.md. v1 feature parity is the contract for v2.
- **Source-time `jq` cost in `.zshrc`** — `_dotfiles_feature` lazy + per-shell caching is the v1 answer. A precomputed `features.zsh` exports file (written by `task install`) is a future micro-optimization if perf demands it.
- **Linux platform-aware split for `shell/aliases/`** — v2 Linux roadmap (out of v1 scope per Phase 1 D-10).
- **Replacing alanpeabody theme with Starship** — explicitly OOS per PROJECT.md / SHEL-05. Defer indefinitely.

### Open questions for later (not blocking P3)
- **`features.ghostty` vs `features.ghostty-launcher`** — the `g` alias is a launcher, but the broader Ghostty config (theme, font, keybindings) lives in `configs/ghostty/` (Phase 7). One flag for "this machine has Ghostty.app installed" is fine for both. Final name decided by planner.
- **`features.jgrid-net` semantics** — true means "this machine has the jgrid network accessible / wants the metal-ssh shortcuts." On work-laptop the network may be partially reachable (some metals are not on jgrid). Default false on work-laptop is the safer call; can flip later.

</deferred>

---

*Phase: 03-shell-layer-flat-content-port*
*Context gathered: 2026-05-14*
