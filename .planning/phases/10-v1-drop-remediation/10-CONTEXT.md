# Phase 10: v1-Drop Remediation - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement every "keep" item from Phase 9's `AUDIT.md` into the v2 codebase. The audit produced exactly three keep rows:

1. **PORT-01 (milestone driver):** Write `export ZDOTDIR="$HOME/.config/zsh"` to `/etc/zshenv` (via sudo, idempotent grep-and-append) so a fresh-machine first interactive shell loads `.zshenv` from `$XDG_CONFIG_HOME/zsh/`.
2. Add v2 validation that asserts the XDG base directories exist AND `/etc/zshenv` contains the ZDOTDIR export line.
3. Reconcile the v1-vs-v2 MAS app-name drift for `mas 904280696` (`Things` in v1 / `Things3` in v2). Functional install already works (mas resolves by id); the audit row is a naming/audit-trail concern, not an install concern.

After this phase: a fresh-machine `task install` produces a fully-functional first shell -- prompt, theme, aliases, functions, MOTD, and `_dotfiles_feature` available on first new terminal without manual remediation. Verified via a documented smoke procedure (not a real fresh-machine install in this phase).

Zero net-new features. No scope beyond the three keep rows. Phase 11 deletes the v1 files after Phase 10 confirms no live dependencies remain.

</domain>

<decisions>
## Implementation Decisions

### PORT-01 -- ZDOTDIR write to /etc/zshenv

- **D-01 (pipeline slot):** The ZDOTDIR write runs at the moment v2 links the zsh startup files into `$ZDOTDIR`. Operator-visible: the same `task install` step that places `.zshenv`/`.zprofile`/`.zshrc`/`.zlogin`/`.zlogout` symlinks ALSO ensures `/etc/zshenv` exports `ZDOTDIR`. Without that ordering, the symlinks land but the first new shell still has no `ZDOTDIR` so `.zshenv` never sources -- which is exactly the live finding that drove this milestone.
- **D-02 (code location):** The new logic lives as a step inside `taskfiles/links.yml`'s existing `zsh:` sub-task, right next to the five `_:safe-link` calls for the startup files. This deviates from AUDIT.md row #1's proposed v2 owner (`taskfiles/shell.yml`); the AUDIT row should be amended to point at `taskfiles/links.yml`. Rationale: D-01's "linked when we link the configs" intent is most natural as a sibling cmd inside `links:zsh`, not a separate file the operator must mentally bridge. Implementation flexibility (inline cmd block vs. a named `task: zdotdir` reference within links.yml) is Claude's discretion.
- **D-03 (sudo handling):** Direct v1 port -- `echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null` (and `sudo tee -a` for append). No upfront `sudo -v` priming, no skip-sudo-when-no-write-needed branching. The status block (idempotency check) MUST stay sudo-free because `/etc/zshenv` is world-readable by default on macOS -- so `grep -qF` in `status:` runs without sudo and steady-state re-runs never prompt. Sudo only fires on the very first install (or after `/etc/zshenv` is manually edited).
- **D-04 (status block):** Idempotency via `grep -qF` against `/etc/zshenv`. Status block uses `{{.ZDOTDIR}}` template var (root Taskfile.yml line 40), not `$ZDOTDIR` shell var -- LINT-02 rule, the v1 `macos:shell:145` bug class. Pattern matches v1 `common.yml:54-57` modulo the template-var hardening. Must handle the `[[ ! -f /etc/zshenv ]]` case in the cmd body the same way v1 did: create the file via `sudo tee` (no `-a`); subsequent runs append via `sudo tee -a` only when the export line is missing.

### Validation (PORT-02)

- **D-05 (new validate component):** A new `shell:validate` task joins the root `task validate` aggregator. Aggregator loop in `Taskfile.yml:215+222` becomes `manifest identity links macos packages claude shell` (or alphabetized `claude identity links macos packages shell` after the manifest keystone). `shell:validate` asserts:
  - Each XDG base directory exists (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`)
  - `$ZDOTDIR` directory exists
  - `/etc/zshenv` exists AND contains the `export ZDOTDIR=` line
- **D-06 (validate location):** `shell:validate` lives in `taskfiles/shell.yml`. That file is currently included by root Taskfile.yml as `perf: ./taskfiles/shell.yml` -- so its lone existing task `shell` surfaces as `perf:shell`. Adding the new validate task there means either:
  - (a) Renaming the include from `perf:` to `shell:` (then `perf:shell` → `shell:shell` for the cold-start gate, awkward), OR
  - (b) Aliasing the include twice (`perf:` AND `shell:` both pointing at the same file), OR
  - (c) Splitting `shell.yml` into `perf.yml` (keeps `perf:shell`) and `shell.yml` (hosts `shell:validate`).
  
  Picking among (a)/(b)/(c) is Claude's discretion -- planner picks based on least churn for the rest of the install graph. The audit-locked v2 owner is "shell-layer concerns live in `taskfiles/shell.yml`," not a particular include alias.

### MAS app-name drift (audit-row #3)

- **D-07 (Things vs Things3):** Leave `Things3` in `manifests/machines/personal-laptop.toml:67` -- it is the actual App Store name returned by `mas list` for id 904280696. Functional install is correct on both v1 and v2 (mas resolves by id). Amend `AUDIT.md` row `install/Brewfile-personal.rb:72` from `keep` to `drop` with rationale "ported under canonical App Store name (v1 used short name 'Things', v2 uses canonical 'Things3'); id 904280696 is the install primitive; mas-list-name drift is a display-string concern, not an install concern." Counts table at AUDIT.md top updates: Keep `3 → 2`, Drop `99 → 100`.

### PORT-03 verification

- **D-08 (smoke procedure, not real fresh install):** PORT-03 ("fresh-machine install produces a fully-functional first shell") is satisfied in this phase by a documented smoke procedure -- not by a real fresh-machine install. ROADMAP P10 SC#1 allows this explicitly ("Verified via real fresh-machine install OR a documented smoke procedure that exercises the startup chain"). The smoke section walks: bootstrap -> setup -> install -> launch new terminal -> assert prompt, theme, aliases, MOTD, and `_dotfiles_feature` all work without manual remediation. Where the smoke procedure lives (new doc, section in `docs/MIGRATION.md`, or `shell/README.md`) is Claude's discretion.

### Claude's Discretion

- Plan breakdown: PORT-01 (links.yml change), PORT-02 (shell:validate + aggregator wiring), AUDIT.md row #3 amend, and PORT-03 smoke doc could be one plan (small phase) or split per concern. Planner picks. Recommendation: one plan -- the entire phase is ~30-50 lines of YAML + one TOML row unchanged + a short doc section.
- Within D-02, the exact shape of the new step inside `links:zsh` (inline `cmd:` heredoc vs a separate `zdotdir:` task in links.yml referenced via `task: zdotdir`) is planner choice.
- D-06: shell.yml include strategy (rename / dual-alias / split).
- Where the PORT-03 smoke procedure section lives (D-08).
- Whether `shell:validate` should also include a presence check for `$DOTFILES_MACHINE` being exported (catches the `task setup` precondition from first-shell perspective) -- not explicitly in audit-row #2 but a logical fresh-install smoke check.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 9 deliverable (the input to this phase)
- `.planning/phases/09-v1-drop-audit/AUDIT.md` -- the keep/drop classification. Phase 10 implements the three keep rows in the Summary section and amends row `install/Brewfile-personal.rb:72` per D-07.
- `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` -- audit-shape decisions; D-09 "behavior-equivalent on same machine" threshold is the bar PORT-02/PORT-03 verify against.

### Project specs
- `.planning/ROADMAP.md` §"Phase 10: v1-Drop Remediation" -- goal, depends-on Phase 9, requirements PORT-01/02/03, SC#1 (smoke-procedure-OR-real-fresh-install). The `lands first` phrasing is captured by D-01/D-02 (ZDOTDIR write happens when zsh symlinks land, before any startup-file behavior matters).
- `.planning/REQUIREMENTS.md` §"Port (v1-drop remediation)" -- PORT-01, PORT-02, PORT-03 exact text.
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" -- milestone driver (the live `/etc/zshenv` ZDOTDIR finding); audit-first ordering rationale.

### v1 source (the port primary source)
- `taskfiles/common.yml:36-57` -- v1 `zdotdir:` task. PORT-01's source-of-truth shape: `ZDOTDIR_EXPORT='export ZDOTDIR="..."'`, three branches (file absent, line absent, line present), `sudo tee` for write, `grep -qF` for status check.
- `taskfiles/common.yml:63-88` -- v1 `validate:` task. PORT-02's shape: XDG base-dir presence + ZDOTDIR dir presence + `/etc/zshenv` contains the ZDOTDIR export line.
- `install/Brewfile-personal.rb:72` -- v1 `mas 'Things', id: 904280696`. The audit-row amend target.

### v2 target surfaces
- `taskfiles/links.yml:139-151` -- the `zsh:` sub-task that links the five startup files. PORT-01's physical home (D-02).
- `taskfiles/shell.yml` -- current home of `perf:shell` (SHEL-12 cold-start gate). PORT-02's `shell:validate` lands here (D-06).
- `Taskfile.yml:160-233` -- root `validate:` aggregator. The aggregator loop at lines 215 and 222 takes the new `shell` component.
- `Taskfile.yml:80-122` -- includes block; the `perf: ./taskfiles/shell.yml` line is the include-alias decision point for D-06.
- `manifests/machines/personal-laptop.toml:65-68` -- the MAS array containing the Things3 entry (D-07: leave unchanged).

### Convention docs (rules every implementation must follow)
- `CLAUDE.md` (project root) §"Rules" -- LINT-02 (template vars `{{.X}}` in status blocks, never shell vars `$X`); LINT-04 (`set -euo pipefail` on every executable .zsh); LINT-03b (symlinks via `_:safe-link` only, no bare `ln -s` outside helpers.yml); kebab-case feature `index` rule; `$HOMEBREW_PREFIX` / `{{.HOMEBREW_PREFIX}}` instead of hardcoded paths.
- `.claude/CLAUDE.md` §"Conventions" -- no AI attribution; no emojis in any file; file-level comment block at top of every script; errors to stderr.
- `docs/MANIFEST.md` -- schema reference; the Things3 row sits in `[packages.brew.mas]` typed sub-table.

### Codebase maps (for context)
- `.planning/codebase/ARCHITECTURE.md` -- five-layer model; PORT-01 sits at the shell-layer/install-engine boundary.
- `.planning/codebase/CONCERNS.md` -- known v1 bugs cluster; the v2 `macos:shell:145` fix (CONCERNS.md #2) is the template-var pattern D-04 follows.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `taskfiles/links.yml` `zsh:` sub-task (lines 139-151) -- existing home for the five `_:safe-link` calls; PORT-01's new step lands inside it (D-02). Already correctly inherits root vars (`DOTFILEDIR`, `ZDOTDIR`, `DOTFILES_MESSAGES`).
- `install/messages.zsh` (sourced via `{{.DOTFILES_MESSAGES}}`) -- `info`, `success`, `check`, `cross`, `error` helpers. Both PORT-01 (status messaging) and PORT-02 (validate render) consume these for consistent operator output.
- `Taskfile.yml:40` -- `ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'` is already defined at root; the PORT-01 status block can reference `{{.ZDOTDIR}}` directly.
- Root `task validate` aggregator (Taskfile.yml:160-233) -- already implements the single-pass design with per-component teeing and exit-code capture. Adding `shell` to the two for-loops at lines 215 and 222 is the entire wiring change for PORT-02.

### Established Patterns
- Status-block template-var rule (LINT-02; CONCERNS.md `macos:shell:145` bug class). D-04 follows this verbatim -- `{{.ZDOTDIR}}` in the status block, never `$ZDOTDIR`.
- Feature-flagged sub-tasks (e.g., `taskfiles/macos.yml`'s `macos-dock` gate): no feature flag applies to PORT-01/02 -- /etc/zshenv ZDOTDIR is unconditional on every machine (laptop AND server) because it is a precondition for ANY zsh-based first shell.
- The validate aggregator's "feature disabled -- skipped" sentinel pattern: not applicable for `shell:validate` because every machine needs this validation.
- `_:check-dir` helper in `taskfiles/helpers.yml` -- PORT-02 can use it for the four XDG dirs + ZDOTDIR dir (mirrors v1 `common.yml:67-78`).

### Integration Points
- `taskfiles/links.yml` `zsh:` sub-task -- the inserted ZDOTDIR-write step joins the five existing symlink calls. Status block of `zsh:` may need extending if the aggregate idempotency claim depends on /etc/zshenv state (or the new step can carry its own status). Planner picks.
- Root `validate:` aggregator -- two for-loops at Taskfile.yml:215 and :222 take the new `shell` token. Optional: include `shell` alphabetically OR keep manifest-first then alphabetical (current pattern is `manifest identity links macos packages claude` -- `claude` is out of alphabetical order, so the existing scheme is "manifest, then phase-order"; planner picks placement).
- `taskfiles/shell.yml` include strategy (D-06). Whatever the planner picks must not break the existing `task perf:shell` invocation referenced in CI (SHEL-12 gate runs as `perf:shell`).
- AUDIT.md amend (D-07): the Summary counts table and the Install Assets row both need updating; the keep-list bullet for `install/Brewfile-personal.rb:72` must be removed.

</code_context>

<specifics>
## Specific Ideas

- The `/etc/zshenv` write block in `taskfiles/common.yml:42-53` is the literal template for PORT-01. Three branches: file absent (create with `sudo tee`), line absent (append with `sudo tee -a`), line present (info + no-op). The cmd body of the new step should mirror these three branches with v2-style template-var idempotency in the status block.
- The PORT-02 ZDOTDIR check at `taskfiles/common.yml:81-88` (the `[[ -f /etc/zshenv ]] && grep -qF ...` cmd) is the literal template for the validation row; render via `check`/`cross` helpers from `install/messages.zsh`.
- For the smoke procedure (D-08), the assertions a new terminal must pass include: `echo $ZDOTDIR` resolves to `$XDG_CONFIG_HOME/zsh`; `type _dotfiles_feature` shows a function; the alanpeabody prompt renders; `alias` lists the expected ported aliases; the MOTD output appears (or its cache file exists).

</specifics>

<deferred>
## Deferred Ideas

- Sudo-cred priming via upfront `sudo -v`: rejected for this phase (D-03). If operator UX feedback says the mid-install sudo prompt is jarring, revisit in a later milestone -- not a v2.1 concern.
- VM-based fresh install for PORT-03: rejected for this phase (D-08). If a real Mac rebuild surfaces a regression the smoke procedure missed, that becomes the trigger to add VM-based pre-merge verification in a later milestone (likely v2.2).
- `shell:validate` extension to check `$DOTFILES_MACHINE` export from first-shell perspective: noted in D-decisions Claude's Discretion. If planner adds it, document as a discretionary extension; if not, log for a later v2.x phase.
- Verbose `task install` UX upgrade so the operator knows ahead of time that sudo will be prompted: out of scope for v2.1 cleanup; revisit alongside any broader task-surface UX work post-SURF (Phase 12).
- AUDIT.md update mechanism: this phase amends `.planning/phases/09-v1-drop-audit/AUDIT.md` in-place rather than producing a "AUDIT-V2.md" or change-log. The amend is a single row reclassification + counts-table adjustment; preserves AUDIT.md as the single source of truth for Phase 11.

</deferred>

---

*Phase: 10-v1-drop-remediation*
*Context gathered: 2026-05-17*
