# Phase 10: v1-Drop Remediation - Research

**Researched:** 2026-05-17
**Domain:** go-task taskfile authoring, idempotent shell install, manifest-driven validation
**Confidence:** HIGH

## Summary

This is an implementation-detail research pass for a phase whose architecture is already pinned by CONTEXT.md (D-01 through D-08). The phase has three keep items from AUDIT.md:

1. PORT-01 -- write `export ZDOTDIR="$HOME/.config/zsh"` to `/etc/zshenv` (sudo, idempotent grep-and-append) -- physically lands inside `taskfiles/links.yml`'s `zsh:` sub-task per D-02.
2. PORT-02 -- add `shell:validate` to the root `task validate` aggregator -- physically lands in `taskfiles/shell.yml` per D-06.
3. AUDIT row #3 amend -- reclassify the Things/Things3 MAS row from `keep` to `drop` per D-07; no code change to `manifests/machines/personal-laptop.toml`.

Plus PORT-03 -- a documented smoke procedure (not a real fresh-machine install) per D-08.

The entire phase is ~30-50 lines of YAML, one AUDIT.md row reclassification + counts-table edit, and a short doc section. All implementation decisions reduce to mechanical choices:
- Inline `cmd:` vs separate `task: zdotdir` reference inside `links.yml` (D-02 sub-question).
- shell.yml include-alias strategy: rename / dual-alias / split (D-06).
- PORT-03 smoke procedure home: new doc / `docs/MIGRATION.md` section / `shell/README.md`.

**Primary recommendation:** Inline the ZDOTDIR write as a new `cmd:` block inside the existing `links:zsh` task body (D-02 inline option). Dual-alias the `taskfiles/shell.yml` include in root `Taskfile.yml` so both `perf:shell` (existing CI gate) and `shell:validate` (new) work without touching any external reference. Host the PORT-03 smoke procedure in a new `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` (ROADMAP P10 SC#3 explicitly names this path).

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 (pipeline slot):** The ZDOTDIR write runs at the same operator-visible moment as the five `_:safe-link` calls for the zsh startup files (inside `links:zsh`).

**D-02 (code location):** The new logic lives as a step inside `taskfiles/links.yml`'s existing `zsh:` sub-task, right next to the five `_:safe-link` calls. AUDIT.md row #1's proposed v2 owner (`taskfiles/shell.yml`) is amended to point at `taskfiles/links.yml`. Inline `cmd:` vs separate `task: zdotdir` reference is Claude's discretion.

**D-03 (sudo handling):** Direct v1 port -- `echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null` (and `sudo tee -a` for append). No upfront `sudo -v` priming. Status block stays sudo-free (`/etc/zshenv` is world-readable on macOS so `grep -qF` runs without sudo).

**D-04 (status block):** Idempotency via `grep -qF` against `/etc/zshenv`. Status block uses `{{.ZDOTDIR}}` template var (LINT-02 rule, the v1 `macos:shell:145` bug class), not `$ZDOTDIR` shell var. Cmd body handles three branches: file absent (`sudo tee`), line absent (`sudo tee -a`), line present (info no-op) -- mirrors v1 `common.yml:42-53`.

**D-05 (new validate component):** A new `shell:validate` task joins the root `task validate` aggregator. Aggregator loops at `Taskfile.yml:215` and `:222` take the new `shell` token. `shell:validate` asserts:
- Each XDG base directory exists (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`)
- `$ZDOTDIR` directory exists
- `/etc/zshenv` exists AND contains the `export ZDOTDIR=` line

**D-06 (validate location):** `shell:validate` lives in `taskfiles/shell.yml`. The current `perf: ./taskfiles/shell.yml` include alias must keep `perf:shell` working (CI gate). Three options: (a) rename `perf:` -> `shell:` (breaks `perf:shell`), (b) dual-alias `perf:` AND `shell:` to the same file, (c) split into `perf.yml` (keeps `perf:shell`) + `shell.yml` (hosts `shell:validate`). Planner picks lowest churn.

**D-07 (Things vs Things3):** Leave `Things3` in `manifests/machines/personal-laptop.toml:67` -- it is the actual App Store name returned by `mas list` for id 904280696. Amend `AUDIT.md` row `install/Brewfile-personal.rb:72` from `keep` to `drop`. Counts table updates: Keep `3 -> 2`, Drop `99 -> 100`.

**D-08 (smoke procedure, not real fresh install):** PORT-03 satisfied by a documented smoke procedure. Smoke section walks: bootstrap -> setup -> install -> launch new terminal -> assert prompt, theme, aliases, MOTD, and `_dotfiles_feature` all work. Location is Claude's discretion (new doc / `docs/MIGRATION.md` section / `shell/README.md`).

### Claude's Discretion

- Plan breakdown: PORT-01 + PORT-02 + AUDIT amend + PORT-03 smoke could be one plan or split per concern. Recommendation in CONTEXT.md: **one plan** (~30-50 lines YAML + one TOML row unchanged + short doc section).
- Inline `cmd:` heredoc vs separate `zdotdir:` task within `links.yml` referenced via `task: zdotdir` (D-02 sub-question).
- D-06 shell.yml include strategy (rename / dual-alias / split).
- Where the PORT-03 smoke procedure section lives (D-08).
- Whether `shell:validate` should also check `$DOTFILES_MACHINE` is exported from a first-shell perspective.

### Deferred Ideas (OUT OF SCOPE)

- Sudo-cred priming via upfront `sudo -v`.
- VM-based fresh install for PORT-03.
- Verbose `task install` UX upgrade to warn the operator about sudo.
- Producing a "AUDIT-V2.md" or change-log instead of an in-place AUDIT.md amend.
- `shell:validate` extension to check `$DOTFILES_MACHINE` is exported (noted in D-discretion -- planner can include or defer to a later v2.x phase).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PORT-01 | A v2 task writes `/etc/zshenv` with `export ZDOTDIR="$HOME/.config/zsh"` during `task install` | Sections "PORT-01 -- ZDOTDIR Write" + "Idempotency Landmines" + "v1 Source Template (literal)" |
| PORT-02 | Every "keep" item from AUDIT.md is implemented in v2 in the file the audit named as v2 owner; no PORT items remain | Sections "PORT-02 -- shell:validate" + "Include Strategy for shell.yml" + "Root validate Aggregator Integration" + "AUDIT.md Row Amend Specification" |
| PORT-03 | A fresh-machine install produces a fully-functional first shell: prompt, theme, aliases, functions, MOTD, `_dotfiles_feature`. Verified via real fresh-machine OR documented smoke procedure | Sections "PORT-03 -- Smoke Procedure Sketch" + "Smoke Procedure Location" |

## Project Constraints (from CLAUDE.md)

These project-root rules constrain every implementation in this phase and are referenced repeatedly below.

| Directive | Source | Application to Phase 10 |
|-----------|--------|------------------------|
| **LINT-02:** status blocks use `{{.X}}` template vars only, never `$X` shell vars | CLAUDE.md "Every install task has a `status:` block" | PORT-01 status block MUST use `{{.ZDOTDIR}}` -- not `$ZDOTDIR`. The lint rule (`taskfiles/lint.yml:140-155`) actively scans `taskfiles/*.yml` (maxdepth 1) for `\$[A-Za-z_]` in status blocks and excludes lines containing `{{`. Violations exit non-zero. |
| **LINT-03b:** symlinks via `_:safe-link` only; no bare `ln -s` outside `helpers.yml` | CLAUDE.md "Symlinks via `_:safe-link` only" | PORT-01 does NOT create a symlink (`/etc/zshenv` is a regular file with sudo-write). LINT-03b does not apply but mention in code review. |
| **LINT-04:** `set -euo pipefail` on every executable `.zsh` | CLAUDE.md "`set -euo pipefail` on every executable `.zsh`" | Phase 10 does not add any new `.zsh` files. PORT-01 lives in a taskfile `cmd:` block. **The root Taskfile.yml declares `set: [errexit, pipefail]`** (line 31) which inherits to all included taskfiles -- so the inline `cmd:` already runs under errexit+pipefail (no need to re-declare; `-u` is intentionally NOT set globally for taskfile cmd blocks because go-task injects task vars that may be empty). |
| **No emojis** in any file (markdown included) | `.claude/CLAUDE.md` "No emojis in any file" | The smoke procedure doc must use ASCII status indicators (the `messages.zsh` library uses `check`/`cross` which render `✓` / `✗` -- those are Unicode glyphs already shipped, not emojis, so they're fine in operator output but should not appear in the markdown source). Markdown body must avoid emojis entirely. |
| **No AI attribution** in commits or source | CLAUDE.md + `.claude/CLAUDE.md` | Hook-enforced at commit time; planner must not include AI attribution in commit messages or source comments. |
| **One concept per file** | CLAUDE.md "One concept per file" | PORT-01 inline option keeps `links:zsh` cohesive (one concept: "wire up the zsh startup chain"). Separate `zdotdir:` task option splits the concern but adds a task to `links.yml` -- a judgment call, but inline preserves one-task-per-file-section symmetry. |
| **kebab-case feature keys use `index`** | CLAUDE.md "kebab-case feature names need `index` access" | Phase 10 does not introduce a new feature flag (ZDOTDIR write is unconditional on every machine -- it is a precondition for ANY zsh-based first shell). No `index` usage required. |
| **XDG everywhere** | CLAUDE.md "XDG everywhere" | `shell:validate` checks all four XDG dirs (XDG_CONFIG_HOME / DATA_HOME / STATE_HOME / CACHE_HOME) per D-05. All four are already defined as `{{.X}}` template vars in root `Taskfile.yml:36-39`. |
| **No hardcoded `/opt/homebrew` or `/usr/local`** | CLAUDE.md "No hardcoded `/opt/homebrew`" | Not applicable -- Phase 10 does not reference brew paths. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Write `/etc/zshenv` ZDOTDIR export | OS / shell-startup layer (sudo write) | Install graph (taskfile orchestration) | The write itself is OS-level (root-owned file); the orchestration that decides when to write it lives in the install taskfile graph -- both tiers are involved. |
| Validate XDG dirs + /etc/zshenv contents | Validation layer (`taskfiles/shell.yml`) | -- | Pure read-only assertions over filesystem state; symmetric with every other component validate (manifest, identity, links, macos, packages, claude). |
| AUDIT.md row reclassification | Planning artifact (`.planning/phases/09-v1-drop-audit/AUDIT.md`) | -- | Pure documentation edit; no code change. Mirrors the "amend in-place" model from CONTEXT.md deferred-ideas section. |
| PORT-03 smoke procedure documentation | Documentation tier | -- | Operator-facing procedure for first-shell verification. ROADMAP P10 SC#3 explicitly names `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` as the location. |

## Standard Stack

This phase does not introduce new libraries or external packages. It edits existing taskfiles and one markdown file.

### Tools already present (no new installs)

| Tool | Version (min) | Purpose | Source |
|------|---------------|---------|--------|
| `go-task` | 3.37+ | Task orchestrator; provides `{{.TEMPLATE_VAR}}` rendering and `status:` idempotency | [CITED: CLAUDE.md "Tooling Versions"], already installed |
| `sudo` + `tee` | system | sudo-write `/etc/zshenv` (D-03 literal v1 port) | macOS-native |
| `grep -qF` | system | status-block idempotency check (sudo-free) | macOS-native |
| `install/messages.zsh` | n/a | `info`/`success`/`check`/`cross`/`error` helpers sourced via `{{.DOTFILES_MESSAGES}}` | [VERIFIED: read at install/messages.zsh:1-71] |
| `taskfiles/helpers.yml` `_:check-dir` | n/a | XDG dir presence checks for `shell:validate` | [VERIFIED: read at taskfiles/helpers.yml:75-83] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `sudo tee` (D-03) | `sudo bash -c 'echo ... >> /etc/zshenv'` | Heredoc-into-sudo-bash is brittle; `sudo tee` is the idiomatic macOS-script pattern and matches v1 literally. **Decision pinned by D-03; do not revisit.** |
| Inline `cmd:` in `links:zsh` (D-02 sub-question) | Separate `zdotdir:` task in `links.yml` referenced via `task: zdotdir` | See "PORT-01 -- ZDOTDIR Write" section below for recommendation and tradeoff analysis. |
| Dual-alias include (D-06 option b) | Rename `perf:` -> `shell:` (option a) or split file (option c) | See "Include Strategy for shell.yml" section below for recommendation and tradeoff analysis. |

**No package installs in this phase** -- skipping Package Legitimacy Audit (no external packages to verify).

## Architecture Patterns

### System Architecture Diagram

```
Phase 10 changes flow through three independent artifacts:

  +---------------------------+
  | taskfiles/links.yml       |
  |   zsh: task               |
  |   +- _:safe-link x 5      |
  |   +- NEW: ZDOTDIR write   |  <-- PORT-01 (D-02, D-03, D-04)
  +---------------------------+
              |
              | runs during `task install`
              v
        /etc/zshenv          <-- sudo-written; world-readable; idempotent

  +---------------------------+
  | taskfiles/shell.yml       |
  |   shell: (existing)       |  <-- SHEL-12 cold-start gate (unchanged)
  |   NEW: validate: task     |  <-- PORT-02 (D-05, D-06)
  +---------------------------+
              |
              | invoked by root validate: aggregator
              v
  +---------------------------+
  | Taskfile.yml              |
  |   validate: aggregator    |
  |   +- loops at :215 :222   |  <-- ADD `shell` token to both loops
  |   +- include: perf+shell  |  <-- dual-alias (D-06 recommendation)
  +---------------------------+

  +---------------------------+
  | AUDIT.md                  |
  |   row #3 (Things)         |  <-- keep -> drop reclassification
  |   counts: 3->2, 99->100   |  <-- D-07
  +---------------------------+

  +---------------------------+
  | 10-SMOKE.md (NEW)         |  <-- D-08 smoke procedure
  +---------------------------+
```

### Pattern 1: Three-branch idempotent sudo write (PORT-01)

**What:** The literal v1 shape from `taskfiles/common.yml:42-53`. File absent -> `sudo tee` creates it. Line absent -> `sudo tee -a` appends. Line present -> info no-op.

**When to use:** Any task that must place a single line in a system-owned file that the operator may also have edited manually.

**Example:**
```yaml
# Source: VERIFIED taskfiles/common.yml:36-57 (v1 zdotdir: task)
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
    if [[ ! -f /etc/zshenv ]]; then
      info "Creating /etc/zshenv with ZDOTDIR export..."
      echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null
      success "ZDOTDIR configured in /etc/zshenv"
    elif ! grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
      info "Adding ZDOTDIR export to /etc/zshenv..."
      echo "$ZDOTDIR_EXPORT" | sudo tee -a /etc/zshenv > /dev/null
      success "ZDOTDIR added to /etc/zshenv"
    else
      info "ZDOTDIR already configured in /etc/zshenv"
    fi
status:
  - |
    ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
    grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv
```

### Pattern 2: Aggregator-loop integration (PORT-02)

**What:** Root `task validate` (Taskfile.yml:160-233) runs each per-component validate in a for-loop, tees output to a tempfile, captures exit code, and renders a summary. Adding a component is **one token in each of two loops**.

**Where:**
- Loop 1 -- execution: `Taskfile.yml:215` -- `for component in manifest identity links macos packages claude; do`
- Loop 2 -- summary: `Taskfile.yml:222` -- same token list

**Add `shell`:**
- `for component in manifest identity links macos packages claude shell; do` (both lines)

**Order rationale:** Current ordering is "manifest first (keystone), remaining alphabetical EXCEPT `claude` is last." Per CONTEXT.md D-05, planner picks placement -- recommendation is to add `shell` alphabetically (after `packages`, before `claude` -> `manifest identity links macos packages shell claude`) OR keep `claude` last and append `shell` at the end (`manifest identity links macos packages claude shell`). The second is lower-risk because it preserves existing relative ordering and only adds a single token at the tail. [ASSUMED: planner picks "append at end" per least-churn principle.]

### Pattern 3: New validate task body (PORT-02)

**What:** A `validate:` task with `status: [false]` (always-rerun per LINT-03a; matches every other `*:validate` task) that uses `_:check-dir` for the four XDG dirs + ZDOTDIR, plus an inline `grep -qF` block for `/etc/zshenv` rendered via `check`/`cross` from messages.zsh.

**Example (sketch -- this is the planned body):**
```yaml
# Source: VERIFIED taskfiles/common.yml:63-88 (v1 validate: task) + 
#         VERIFIED taskfiles/macos.yml:256-307 (v2 validate: pattern)
# lint-allow: cmds-without-status
validate:
  desc: "Validate shell layer (XDG dirs, ZDOTDIR dir, /etc/zshenv contents)"
  status: [false]
  cmds:
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_CONFIG_HOME}}", NAME: "XDG config home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_DATA_HOME}}", NAME: "XDG data home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_STATE_HOME}}", NAME: "XDG state home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_CACHE_HOME}}", NAME: "XDG cache home" }
    - task: _:check-dir
      vars: { TARGET: "{{.ZDOTDIR}}", NAME: "ZDOTDIR" }
    - |
      {{.DOTFILES_MESSAGES}}
      ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
      if [[ -f /etc/zshenv ]] && grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
        check "ZDOTDIR configured in /etc/zshenv"
      else
        cross "ZDOTDIR not configured in /etc/zshenv"
        exit 1
      fi
```

Note the explicit `exit 1` on the failure branch -- without it, the aggregator's exit-code capture would see the loop's final `task` exit code as success (the `cross` line itself does not exit non-zero). Mirrors the `exit "$failures"` pattern at `taskfiles/links.yml:382`.

### Anti-Patterns to Avoid

- **`$ZDOTDIR` in status block:** The v1 `macos:shell:145` bug class. Always re-runs because the shell var is unset in status-eval context. Use `{{.ZDOTDIR}}` (template var). LINT-02 enforces this at lint time -- but only on lines that do NOT also contain `{{` (the regex at `taskfiles/lint.yml:147` excludes `{{`-containing lines to avoid false positives on legitimate template usage). A line containing both `$ZDOTDIR` and `{{.OTHER_VAR}}` would slip past LINT-02 -- so be conservative.
- **`sudo` inside the `status:` block:** Would prompt for password on every `task install` invocation. D-03 + D-04 explicitly require sudo-free status (`/etc/zshenv` is world-readable on macOS).
- **Touching `links:zsh`'s outer `status:` block:** The current `status:` checks 5 symlinks (`test -L "{{.ZDOTDIR}}/.zshenv"` etc.). If the planner adds the ZDOTDIR write as an INLINE step inside `links:zsh`, that step's idempotency must be expressed somehow:
  - Option A: extend the outer `status:` to also include the `grep -qF` check (clean but couples shell-state and link-state into one aggregate).
  - Option B: leave outer `status:` unchanged; add an inline `[[ ... ]] && exit 0` guard at the top of the new `cmd:` block (per-step early-return).
  - Option C: extract the ZDOTDIR write to its own internal `zdotdir:` task within `links.yml` with its own `status:` block, called via `task: zdotdir` from `links:zsh`.
  
  **Recommendation:** Option C (extracted internal task) -- isolates the idempotency check, mirrors the `configs:ghostty:` extraction pattern at `taskfiles/links.yml:269-277` (precedent in the same file), and avoids coupling unrelated state into one outer `status:`. The slight cost (one extra task name in the file) is worth the cohesion gain. [ASSUMED: planner adopts this; see "PORT-01 -- ZDOTDIR Write" recommendation below.]
- **Adding `set -euo pipefail` to the inline cmd body:** Redundant and potentially harmful. Root `Taskfile.yml:31` declares `set: [errexit, pipefail]` which inherits to all included taskfiles. Adding `set -u` would break go-task's empty-var template injection (CLAUDE.md mentions `-u` for executable `.zsh` files only -- NOT for taskfile cmd blocks). [VERIFIED: root Taskfile.yml:31 + no `set -u` in any existing taskfile cmd block; cross-checked against macos.yml/links.yml.]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Idempotency for `/etc/zshenv` line | A pre-write sentinel file (`~/.local/state/dotfiles/zdotdir-written`) | `grep -qF` against `/etc/zshenv` directly (D-04) | Sentinel file lies if operator manually edits `/etc/zshenv`; direct grep is single-source-of-truth. |
| XDG dir + ZDOTDIR existence assertion | Hand-rolled `[[ -d ... ]] && echo ... || echo ...` lines | `_:check-dir` helper from `taskfiles/helpers.yml:75-83` | Consistent operator output (sources messages.zsh, renders `check`/`cross`); one source of truth for the check shape. |
| Component-aggregator wiring | A new dispatcher in `taskfiles/shell.yml` | Two-token-edit in root `Taskfile.yml:215` and `:222` for-loops | Aggregator already does per-component tee + exit-code capture + summary rendering; adding a new component is one token per loop. |
| Sudo cred priming | Wrapping `task install` in `sudo -v` then trusting timeout | Let sudo prompt mid-install (D-03) | Mid-install prompt is the documented v1 behavior; out-of-scope to redesign. |

**Key insight:** This phase is almost entirely "copy the v1 shape verbatim into the v2 location, swap shell vars for template vars in the status block." Custom solutions are a smell -- if the planner is writing anything novel, re-read CONTEXT.md decisions.

## Runtime State Inventory

Phase 10 includes a rename-adjacent edit (AUDIT.md row #3 reclassification) but does not rename any runtime-stored identifier. Walking the five categories explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None -- no DB / store / persistent ID change. The MAS id `904280696` is unchanged (D-07); only the AUDIT.md display-name row is reclassified. | None |
| Live service config | None -- no UI-managed or DB-stored service config is renamed. `mas` resolves apps by id, not by name, so the Things3 entry already works on personal-laptop. | None |
| OS-registered state | `/etc/zshenv` itself is OS-registered state that this phase MODIFIES (PORT-01 writes the ZDOTDIR export line). After the phase: `/etc/zshenv` exists and contains the line. Fresh-machine: absent until PORT-01 runs. Re-run: idempotent no-op. | The PORT-01 task itself IS the action; no other OS-registered state changes. |
| Secrets / env vars | None -- no env var name change. `ZDOTDIR` itself is exported by both the write to `/etc/zshenv` (PORT-01 lands the export) and by `shell/.zshenv:41` (defensive `${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}` default). No rename of the var name itself. | None |
| Build artifacts | None -- no installed-package artifact carries the renamed name (Things vs Things3 is a UI display string from `mas list`; functional install is correct on both). | None |

**Nothing-found rationale:** Phase 10 is a remediation phase that ADDS infrastructure (write to /etc/zshenv, add validate task) rather than renaming or migrating anything. The single "rename-shaped" item (Things vs Things3) is purely a documentation edit per D-07. Confirmed by reading the personal-laptop.toml lines 65-68 (MAS array unchanged) and the AUDIT row at line 79.

## Recommended Implementations

### PORT-01 -- ZDOTDIR Write

**Recommended shape:** **Option C (extracted internal task)** -- add a new internal `zdotdir:` task in `taskfiles/links.yml` with its own status block, called via `task: zdotdir` from `links:zsh`.

**Rationale:**
1. Mirrors the existing `configs:ghostty:` extraction pattern at `links.yml:269-277` -- precedent in the same file for "extract a step whose idempotency is independent of the parent task's outer status."
2. Keeps the outer `links:zsh` status block (currently `test -L` for 5 symlinks) unchanged -- avoids coupling shell-state (`/etc/zshenv` contents) and link-state into one aggregate that would re-run both when only one drifts.
3. Status block is single-line and clean: `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null` (the `2>/dev/null` suppresses stderr when `/etc/zshenv` is absent -- which is the desired "run the cmd" signal).

**Exact task body (sketch -- planner refines wording):**
```yaml
zsh:
  desc: "Link zsh configuration files and configure /etc/zshenv ZDOTDIR"
  cmds:
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zprofile", TARGET: "{{.ZDOTDIR}}/.zprofile" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshrc", TARGET: "{{.ZDOTDIR}}/.zshrc" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zlogin", TARGET: "{{.ZDOTDIR}}/.zlogin" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zlogout", TARGET: "{{.ZDOTDIR}}/.zlogout" }
    - task: zdotdir
  status:
    - test -L "{{.ZDOTDIR}}/.zshenv"
    - test -L "{{.ZDOTDIR}}/.zprofile"
    - test -L "{{.ZDOTDIR}}/.zshrc"
    - test -L "{{.ZDOTDIR}}/.zlogin"
    - test -L "{{.ZDOTDIR}}/.zlogout"
    - grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null

zdotdir:
  desc: "Configure ZDOTDIR in /etc/zshenv (sudo write, idempotent)"
  internal: true
  cmds:
    - |
      {{.DOTFILES_MESSAGES}}
      ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
      if [[ ! -f /etc/zshenv ]]; then
        info "Creating /etc/zshenv with ZDOTDIR export..."
        echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null
        success "ZDOTDIR configured in /etc/zshenv"
      elif ! grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
        info "Adding ZDOTDIR export to /etc/zshenv..."
        echo "$ZDOTDIR_EXPORT" | sudo tee -a /etc/zshenv > /dev/null
        success "ZDOTDIR added to /etc/zshenv"
      else
        info "ZDOTDIR already configured in /etc/zshenv"
      fi
  status:
    - grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null
```

**Notes on the sketch:**
- The outer `zsh:` task gets the `grep -qF` line appended to its status -- this is a single-line addition that ensures the aggregate `zsh:` task re-runs (and dispatches the new `task: zdotdir`) if `/etc/zshenv` drifts independently of the symlinks.
- The new `zdotdir:` internal task is structurally identical to v1 `common.yml:36-57` modulo template-var hardening.
- `internal: true` keeps `zdotdir` out of `task --list` output (matches `safe-link`, `check-dir`, `configs:ghostty:` precedent).
- LINT-02: the status block uses ONLY `{{.ZDOTDIR}}` -- zero `$VAR` references. Verified safe.
- LINT-03a: the `zdotdir:` task has a `status:` block -- compliant.
- `task --list` description is concrete enough to be operator-useful.

**Alternative (Option A -- inline `cmd:` block):** Single fewer task name in `links.yml`, but couples /etc/zshenv state with symlink state in one outer status. Acceptable but less hygienic. Planner picks; recommendation is Option C.

### PORT-02 -- shell:validate

**Recommended task body:** see Pattern 3 above.

**Recommended placement in `taskfiles/shell.yml`:** Append after the existing `shell:` task (perf gate). Both tasks are file-scope sibling tasks.

**`set -euo pipefail` requirement:** Not applicable to the cmd block -- the root `Taskfile.yml:31` declares `set: [errexit, pipefail]` globally. The inline `grep -qF` block + explicit `exit 1` on failure gives the aggregator a clean exit code.

**Optional D-08 discretion (DOTFILES_MACHINE check):** A first-shell smoke would also verify `DOTFILES_MACHINE` is exported. Adding it to `shell:validate`:
```yaml
- |
  {{.DOTFILES_MESSAGES}}
  if [[ -r "{{.XDG_STATE_HOME}}/dotfiles/machine" ]]; then
    check "DOTFILES_MACHINE state file present ({{.XDG_STATE_HOME}}/dotfiles/machine)"
  else
    cross "DOTFILES_MACHINE state file missing -- run: task setup -- <machine-name>"
    exit 1
  fi
```
Recommendation: **include it**. It's two extra lines, catches a real fresh-install pitfall (operator forgets `task setup`), and the cutover gate already requires the machine file before `task install`. Symmetric with the rest of `shell:validate`'s "first-shell preconditions" theme.

### Include Strategy for shell.yml (D-06)

**Recommendation:** **Option B -- dual-alias the include in root Taskfile.yml.**

Replace:
```yaml
perf:     ./taskfiles/shell.yml
```

With:
```yaml
perf:     ./taskfiles/shell.yml   # legacy alias for `task perf:shell` (SHEL-12 cold-start gate)
shell:    ./taskfiles/shell.yml   # primary alias for `task shell:validate` (PORT-02)
```

**Tradeoff analysis:**

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **(a) Rename** `perf:` -> `shell:` | One include line; one canonical alias. | Breaks every external reference: `taskfiles/README.md:27`, `:54`; `taskfiles/shell.yml:12-13`; `shell/README.md:43`; `.planning/ROADMAP.md:83`, `:93`. CI gate would surface as `shell:shell` (awkward double-noun). | REJECT -- 6+ doc references to update for a cosmetic win. |
| **(b) Dual-alias** | Zero changes to existing references. Both `perf:shell` and `shell:validate` work. New users learn the canonical `shell:` namespace; legacy callers keep working. | Two include lines for one file. Minor: looks duplicative until you read the comment. | **SELECT** -- minimum churn. |
| **(c) Split** into `perf.yml` + `shell.yml` | Cleanest semantic separation. | Two physical files for two tasks. Violates "one taskfile per concern" -- both tasks are shell-layer concerns. | REJECT -- splitting adds a file without solving anything dual-alias doesn't. |

**Verified references that depend on `perf:shell`:**
- `taskfiles/README.md:27` -- documentation
- `taskfiles/README.md:54` -- documentation
- `taskfiles/shell.yml:12` -- self-referencing comment (would need editing under option (a))
- `taskfiles/shell.yml:13` -- self-referencing comment (would need editing under option (a))
- `shell/README.md:43` -- documentation
- `.planning/ROADMAP.md:83` (SC#2) -- historical record (don't edit -- it's the audit trail)
- `.planning/ROADMAP.md:93` -- historical record

`grep -rn "perf:shell"` against `.github/` returns nothing (the CI surface is the lint suite + manual gate, not a perf gate hook in CI yet). So the runtime impact of any rename is currently just doc-text, but the principle holds: option (b) makes zero churn.

### Root validate Aggregator Integration (D-05)

**Exact two-line edit to `Taskfile.yml`:**

Line 215 (execution loop) -- change:
```
for component in manifest identity links macos packages claude; do
```
to:
```
for component in manifest identity links macos packages claude shell; do
```

Line 222 (summary loop) -- same change.

**Placement rationale:** Append `shell` at the tail rather than insert alphabetically. The current ordering is documented as "manifest first (keystone), remaining alphabetical, claude last" (Taskfile.yml:176-178) -- the existing exception (claude appears AFTER `packages` despite alphabetical order requiring it before `identity`) signals the ordering is "manifest first then by some other heuristic." Tail-append is the lowest-friction choice and preserves the existing six-token order verbatim.

**Tee-output integration:** No special handling needed. The aggregator at `Taskfile.yml:218` runs `task "${component}:validate" 2>&1 | tee "${cache_dir}/${component}"` -- as long as the new `shell:validate` task name exists (which it will, via the dual-alias `shell:` include), the aggregator will pick it up identically to every other component.

**Sentinel pattern compatibility:** The aggregator at `Taskfile.yml:224` checks for `"feature disabled -- skipped"` to render an `n/a` row. `shell:validate` is unconditional (every machine needs it -- per CONTEXT.md "feature-flagged sub-tasks: no feature flag applies to PORT-01/02"), so it will always render `check`/`cross`, never `n/a`. No new sentinel handling needed.

### AUDIT.md Row Amend Specification (D-07)

**Current text at AUDIT.md line 79:**
```
| install/Brewfile-personal.rb:72 | mas 'Things' (id 904280696) declared in v1 personal-profile Brewfile | partially-ported | keep | v2 personal-laptop manifest declares `{ id = 904280696, name = "Things3" }` -- same MAS id (904280696), but name drifted from 'Things' (v1) to 'Things3' (v2). Per-machine effective-set diff flags Things as missing from v2 effective set. The id is what `mas` resolves on; functional install is correct, but the audit-display name should be reconciled. Phase 10 should normalize the v2 manifest name to match v1 ('Things') for the audit-trail and AUDIT.md row alignment. | manifests/machines/personal-laptop.toml |
```

**Proposed replacement text (per D-07):**
```
| install/Brewfile-personal.rb:72 | mas 'Things' (id 904280696) declared in v1 personal-profile Brewfile | ported | drop | Ported under canonical App Store name -- v1 used short name 'Things'; v2 uses canonical 'Things3' (the name `mas list` returns for id 904280696). The install primitive is the id (904280696), which is unchanged across v1 and v2 manifests; mas-list-name drift is a display-string concern, not an install concern. Functional install is correct on both. Phase 10 (D-07) chose to leave the v2 manifest name as the canonical 'Things3' rather than revert to the v1 short name. | manifests/machines/personal-laptop.toml |
```

**Diff summary:** changes the 3rd column from `partially-ported` -> `ported`, the 4th column from `keep` -> `drop`, and rewrites the rationale text in the 5th column. The `file:line`, `purpose`, and `v2 owner` columns are unchanged.

**Counts-table edit (AUDIT.md lines 11-14):**

Current:
```
| Metric | Count |
|--------|-------|
| Tasks audited | 102 |
| Keep | 3 |
| Drop | 99 |
| Already-ported | 70 |
```

Proposed:
```
| Metric | Count |
|--------|-------|
| Tasks audited | 102 |
| Keep | 2 |
| Drop | 100 |
| Already-ported | 70 |
```

**Keep-list bullet removal (AUDIT.md line 22):**

Remove the entire bullet:
```
- `install/Brewfile-personal.rb:72` → **manifests/machines/personal-laptop.toml** — mas 'Things' (id 904280696) declared in v1 personal-profile Brewfile
```

The remaining two keep-list bullets (rows for `taskfiles/common.yml:36-57` and `taskfiles/common.yml:63-88`) are unchanged.

**Why amend in-place vs creating AUDIT-V2.md:** Per CONTEXT.md deferred-ideas (`<deferred>` "AUDIT.md update mechanism"), the amend is a single row reclassification + counts adjustment; preserves AUDIT.md as the single source of truth for Phase 11.

### PORT-03 -- Smoke Procedure Sketch

**Recommended location:** `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` -- a new file alongside `10-CONTEXT.md` and `10-RESEARCH.md`.

**Rationale:** ROADMAP P10 SC#3 explicitly names this path ("procedure and pass result recorded in `.planning/phases/10-v1-drop-remediation/10-SMOKE.md`"). The other discretionary options (`docs/MIGRATION.md` section, `shell/README.md` section) would mix transient verification procedure with permanent operator-facing docs. `10-SMOKE.md` is the natural sibling to `09-AUDIT.md` -- per-phase deliverable.

**Sketch body:**

```markdown
# Phase 10: First-Shell Smoke Procedure

**Recorded:** <date>
**Procedure run on:** <machine-name> (existing v2-cut-over machine, NOT a real fresh install)
**Result:** PASS / FAIL

## What this is

A documented smoke procedure that exercises the fresh-machine first-shell guarantee
(PORT-03). v2.1 phase 10 accepts a procedure-based satisfaction of PORT-03 per
ROADMAP P10 SC#3; a real fresh-machine install is deferred to a later milestone.

## Procedure

Run on an existing v2-cut-over machine after Phase 10's PORT-01 has landed.

### Pre-step setup
1. Verify `/etc/zshenv` contains the ZDOTDIR export:
   `grep -F 'export ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv`
2. Verify `task validate` exits 0 end-to-end: `task validate; echo "exit: $?"`.
3. Verify the new `shell:validate` row appears in the validate summary.

### First-shell assertions
Launch a fresh terminal (Ghostty, Terminal.app, or `zsh -li`). The new shell MUST satisfy:

- [ ] `echo "$ZDOTDIR"` prints `<HOME>/.config/zsh` (from `/etc/zshenv`)
- [ ] `echo "$DOTFILES_MACHINE"` prints the active machine name (from `shell/.zshenv`)
- [ ] The alanpeabody-derived prompt renders (user, pwd, git branch tokens visible)
- [ ] `type _dotfiles_feature` shows `_dotfiles_feature is a function`
- [ ] `alias` lists the expected ported aliases (at minimum: `reload`, `path`, `ll`, `t`)
- [ ] MOTD output appears (or cache file `$XDG_CACHE_HOME/dotfiles/motd.cache` exists)
- [ ] No "command not found" errors during the shell init

### Pass criteria

Every checkbox above ticked. Record date, machine, and result at the top of this file.

## Result Record

| Date | Machine | Result | Notes |
|------|---------|--------|-------|
| <date> | <machine> | PASS / FAIL | <any deviations> |
```

**`set -euo pipefail` for smoke procedure:** N/A -- this is markdown, not an executable script. The operator runs commands by hand.

## Idempotency Landmines

These are the specific failure modes the planner must verify against.

### Landmine 1 -- `$ZDOTDIR` in status block (the v1 macos:shell:145 bug class)

**Symptom:** `task install` re-runs the ZDOTDIR-write cmd on every invocation; sudo prompts every time.

**Cause:** The status block uses `$ZDOTDIR` (shell var, empty in status-eval context) instead of `{{.ZDOTDIR}}` (template var, resolved at task-graph build time).

**Prevention:** D-04 mandates `{{.ZDOTDIR}}`. LINT-02 lints for this at `taskfiles/lint.yml:140-155` -- specifically: `yq '.tasks[] | select(.status) | .status' "$f" | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' | ggrep -vE '\{\{'`. Any `$VAR` reference in a status block that is NOT on a line containing `{{` fails the lint. The status sketch above uses `'export ZDOTDIR="{{.ZDOTDIR}}"'` which embeds the template var directly in the single-quoted grep pattern -- zero shell vars in the status block.

**Verification:** Run `task lint:taskfile` after the change. Run `task install` twice; second invocation must not prompt for sudo.

### Landmine 2 -- `[[ ! -f /etc/zshenv ]]` initial-creation branch

**Symptom:** On a fresh machine where `/etc/zshenv` does not exist, `sudo tee -a` (append mode) would write the line but `tee -a` of a non-existent file behaves slightly differently across systems.

**Prevention:** D-04 mandates handling the `[[ ! -f /etc/zshenv ]]` case explicitly via `sudo tee` (no `-a`) for the file-absent branch. v1 `common.yml:43-50` already implements this; the recommended sketch above preserves it.

**Verification:** Test by `sudo rm /etc/zshenv` followed by `task install`; the install must succeed and write a new `/etc/zshenv`.

### Landmine 3 -- `/etc/zshenv` exists but ZDOTDIR line is malformed

**Symptom:** Operator has manually edited `/etc/zshenv` and the ZDOTDIR export is present but with different quoting (e.g., `export ZDOTDIR=$HOME/.config/zsh` without quotes). `grep -qF` against the canonical form does not match; task appends a SECOND line.

**Mitigation:** This is an accepted limitation per D-03 (literal v1 port). The duplicate-line case is benign -- both lines export the same value, the last one wins, and re-runs converge after the second invocation. v1 has this same behavior.

**Documentation:** Should be mentioned in the smoke procedure ("if /etc/zshenv was manually edited, verify only one ZDOTDIR export line is present after install").

### Landmine 4 -- `_:check-dir` exit code

**Symptom:** `_:check-dir` always exits 0 even when the directory is missing -- it just prints `cross "..."`. The aggregator's exit-code capture would see success for a `shell:validate` task that prints `cross` for every XDG dir.

**Verified:** Reading `taskfiles/helpers.yml:75-83`, `_:check-dir` is:
```yaml
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    test -d "{{.TARGET}}" && check "{{.NAME}} exists" || cross "{{.NAME}} missing"
```
The `&&` / `||` chain produces a non-zero exit when `cross` runs (the right-hand-side of `||` is the last command, but `cross` itself exits 0 -- meaning the WHOLE expression exits with the exit code of `cross` -- which is 0. So `_:check-dir` always exits 0 even on missing dir.

**Mitigation:** The planner must either:
- (a) Add an explicit `|| exit 1` after each `_:check-dir` invocation in `shell:validate`, OR
- (b) Inline the dir checks (skipping `_:check-dir`) with explicit exit-1 on failure, OR
- (c) Accept that `shell:validate` will print `cross` lines but exit 0 on missing-dir failures.

Option (c) matches the broader v2 behavior -- look at `links:validate` at `taskfiles/links.yml:382` which explicitly tallies `$failures` and `exit "$failures"`. The same pattern in `shell:validate` would be cleanest. **Recommendation:** Follow `links:validate`'s pattern -- maintain a `failures` counter, increment on each failed check, `exit "$failures"` at the end. Rewrite the per-dir checks as direct `[[ -d ... ]] || (cross "..."; failures=$((failures+1)))` instead of using `_:check-dir`.

This is a meaningful planner decision: do we (a) use `_:check-dir` for shape consistency and accept the broken-exit-code behavior, or (b) inline the checks with proper exit-code aggregation? Recommendation: **(b)** -- but the planner should call this out as a design choice in PLAN.md.

### Landmine 5 -- Aggregator loop edit drift

**Symptom:** The planner edits `Taskfile.yml:215` but forgets `:222`, or vice versa. The summary table omits the new component (or shows it without ever having run).

**Prevention:** Both loops use the IDENTICAL token list. Search-and-replace the literal string `manifest identity links macos packages claude` -> `manifest identity links macos packages claude shell` (occurs exactly twice in the file -- one in execution loop, one in summary loop). Verify with `grep -c "manifest identity links macos packages claude shell" Taskfile.yml` returns `2`.

### Landmine 6 -- `set: [errexit, pipefail]` interaction with new cmd

**Behavior:** Root `Taskfile.yml:31` declares `set: [errexit, pipefail]`. This inherits to all included taskfiles, including `links.yml`'s new `zdotdir:` task. The inline cmd body's `if/elif/else` is safe under errexit (the conditions themselves are exempt). The `echo ... | sudo tee` pipeline is safe under pipefail because both `echo` and `sudo tee` exit 0 on success.

**Verified:** No `set -u` is active for taskfile cmd blocks (only the executable `.zsh` files need it per LINT-04). Templated empty vars do not trigger unbound-variable failures.

### Landmine 7 -- `links:zsh` status block re-run threshold

**Symptom:** The recommended Option C sketch appends `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null` to the outer `links:zsh` status block. This means `links:zsh` will re-dispatch (and re-run `_:safe-link` x5 + `task: zdotdir`) every time `/etc/zshenv` drifts -- not just when the ZDOTDIR write drifts. Acceptable because `_:safe-link` is itself idempotent (`ln -sfn` is a no-op on existing correct symlinks), but the operator will see "re-linking shell files" output on a /etc/zshenv-only drift.

**Mitigation:** If the planner finds this undesirable, drop the status-block addition and rely solely on the inner `zdotdir:` status block. The outer `links:zsh` would never re-trigger on /etc/zshenv drift, but `task: zdotdir` (always dispatched) would still consult its own status and run only when needed. This is actually CLEANER. **Updated recommendation:** Do NOT add the `grep` line to the outer `links:zsh` status; let the inner `zdotdir:` task carry its own status independently. Each task evaluates its own status when dispatched -- so the outer status only governs whether the CMDS block runs, but each `task: <name>` inside the cmds block still consults the called task's own status.

Re-verifying: in go-task, when a parent task's status is `up-to-date` (all status entries return 0), go-task SKIPS the entire cmds block. So if `links:zsh`'s outer status returns 0 (all 5 symlinks exist), `task: zdotdir` is NEVER dispatched, and the ZDOTDIR drift goes uncorrected.

**Correct conclusion:** The grep line MUST be appended to the outer `links:zsh` status block, OR the planner must use Option A (inline cmd within `links:zsh` body). Option C only works if the outer status is extended to ALSO check /etc/zshenv state. The minor cost (re-linking on /etc/zshenv drift) is acceptable because the `_:safe-link` operations are idempotent.

**Final landmine summary:** Planner must extend the outer `links:zsh` status block to include the `/etc/zshenv` check. The recommended Option C sketch above already shows this (line `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null`). Verified correct.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | go-task tasks themselves (no separate test runner for this phase) |
| Config file | `Taskfile.yml` (root) + `taskfiles/lint.yml` + new `taskfiles/shell.yml` body |
| Quick run command | `task validate` (component-level) + `task lint` (LINT-02 enforcement) |
| Full suite command | `task validate && task lint && task test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| PORT-01 | `/etc/zshenv` contains ZDOTDIR export line after `task install` | integration | `task install && grep -F 'export ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv` | YES (existing install task) |
| PORT-01 | Re-running `task install` does NOT re-prompt for sudo (idempotency) | integration | `task install; task install 2>&1 \| grep -c 'ZDOTDIR already configured\|sudo:'` -- second run produces no sudo prompt | YES |
| PORT-01 | LINT-02 passes on the new status block | static | `task lint:taskfile` -- must exit 0 | YES (existing lint task) |
| PORT-02 | `task shell:validate` exits 0 on a properly-set-up machine | integration | `task shell:validate; echo "exit: $?"` -- exit 0 | NEW (this phase creates `shell:validate`) |
| PORT-02 | `task shell:validate` exits non-zero when `/etc/zshenv` is missing | integration | `sudo mv /etc/zshenv /tmp/zshenv.bak; task shell:validate; ec=$?; sudo mv /tmp/zshenv.bak /etc/zshenv; [[ $ec -ne 0 ]]` | NEW (this phase) |
| PORT-02 | `task validate` includes `shell` in its summary table | integration | `task validate 2>&1 \| grep -E '(check\|cross) shell'` | NEW (after Taskfile.yml:215/:222 edit) |
| PORT-03 | The smoke procedure passes on personal-laptop | manual | Operator runs through `10-SMOKE.md` checklist; records result | NEW (this phase creates `10-SMOKE.md`) |

### Sampling Rate

- **Per task commit:** `task lint:taskfile` (catches LINT-02 regressions in the new status block)
- **Per wave merge:** `task validate` (catches `shell:validate` integration regressions)
- **Phase gate:** Full `task validate && task lint && task test` green + smoke procedure manually run with PASS recorded in `10-SMOKE.md`

### Wave 0 Gaps

- [ ] None -- this phase requires NO new test infrastructure. Existing `task lint`, `task validate`, `task test` cover the automated validation surface. The smoke procedure is the only "test artifact" introduced (PORT-03) and it IS the validation file itself.

## Code Examples

### v1 Source Template (literal)

```yaml
# Source: VERIFIED taskfiles/common.yml:36-57 (the v1 zdotdir: task)
zdotdir:
  desc: "Configure ZDOTDIR in /etc/zshenv"
  run: once
  cmds:
    - |
      {{.DOTFILES_MESSAGES}}
      ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
      if [[ ! -f /etc/zshenv ]]; then
        info "Creating /etc/zshenv with ZDOTDIR export..."
        echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null
        success "ZDOTDIR configured in /etc/zshenv"
      elif ! grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
        info "Adding ZDOTDIR export to /etc/zshenv..."
        echo "$ZDOTDIR_EXPORT" | sudo tee -a /etc/zshenv > /dev/null
        success "ZDOTDIR added to /etc/zshenv"
      else
        info "ZDOTDIR already configured in /etc/zshenv"
      fi
  status:
    - |
      ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
      grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv
```

### v1 Validate Template (literal)

```yaml
# Source: VERIFIED taskfiles/common.yml:63-88 (the v1 validate: task)
validate:
  desc: "Validate common components (XDG, ZDOTDIR)"
  cmds:
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_CONFIG_HOME}}", NAME: "XDG config home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_DATA_HOME}}", NAME: "XDG data home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_STATE_HOME}}", NAME: "XDG state home" }
    - task: _:check-dir
      vars: { TARGET: "{{.XDG_CACHE_HOME}}", NAME: "XDG cache home" }
    - task: _:check-dir
      vars: { TARGET: "{{.ZDOTDIR}}", NAME: "ZDOTDIR" }
    - |
      {{.DOTFILES_MESSAGES}}
      ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
      if [[ -f /etc/zshenv ]] && grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
        check "ZDOTDIR configured in /etc/zshenv"
      else
        cross "ZDOTDIR not configured in /etc/zshenv"
      fi
```

The v2 port preserves this shape verbatim modulo:
1. Template-var hardening in the status block (LINT-02).
2. Optional explicit `exit 1` on the cross branch (so aggregator captures non-zero exit).
3. Optional explicit `failures` counter pattern (matches `links:validate`).
4. Optional addition of `DOTFILES_MACHINE` state-file presence check (D-08 discretionary extension).

### v2 Aggregator Excerpt (where shell goes)

```yaml
# Source: VERIFIED Taskfile.yml:215, :222 (root validate: aggregator loops)
# CURRENT:
for component in manifest identity links macos packages claude; do
  task "${component}:validate" 2>&1 | tee "${cache_dir}/${component}"
  eval "rc_${component}=\${PIPESTATUS[0]}"
done
# ...
for component in manifest identity links macos packages claude; do
  # render summary row
done

# AFTER PORT-02 EDIT:
for component in manifest identity links macos packages claude shell; do
  task "${component}:validate" 2>&1 | tee "${cache_dir}/${component}"
  eval "rc_${component}=\${PIPESTATUS[0]}"
done
# ...
for component in manifest identity links macos packages claude shell; do
  # render summary row
done
```

## State of the Art

This phase ports a v1 implementation verbatim. There is no "state of the art" question -- the v1 pattern was working and the v2 silently dropped it. The remediation is to put the working v1 logic into the v2 file layout with the v2 hardening conventions (template-var status blocks).

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| v1 `taskfiles/common.yml` had a single big "common" file | v2 splits by concern: shell-layer concerns in `taskfiles/shell.yml`, link concerns in `taskfiles/links.yml` | v2 refactor (Phases 1-8) | Phase 10 places PORT-01 in `links.yml` (D-02) and PORT-02 in `shell.yml` (D-06) per the v2 file-per-concern model |
| v1 status blocks used `$VAR` shell vars (the macos:shell:145 bug) | v2 status blocks use `{{.X}}` template vars (LINT-02 enforced) | v2 lint rule landed in Phase 2 | PORT-01's status block MUST use `{{.ZDOTDIR}}` not `$ZDOTDIR` |
| v1 had no automated lint for status-block conventions | v2 has `task lint:taskfile` enforcing LINT-02 / LINT-03a / LINT-03b | Phase 2 lint suite | Any PORT-01 regression caught at CI lint time |

**Deprecated / outdated:** N/A -- this phase introduces nothing new.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Tail-appending `shell` to the aggregator loops (after `claude`) is the lowest-friction placement | "Root validate Aggregator Integration" | LOW -- alphabetical insertion would also work; planner can pick either |
| A2 | Option B (dual-alias include) is lowest churn for D-06 | "Include Strategy for shell.yml" | LOW -- tradeoff analysis is explicit; planner may override based on aesthetic preference |
| A3 | Option C with the outer `links:zsh` status block extended is the right idempotency design for PORT-01 | "PORT-01 -- ZDOTDIR Write" + Landmine 7 | MEDIUM -- if the planner picks Option A (inline cmd), the implementation is functionally equivalent but couples shell/symlink state. Both options work; recommendation is C. |
| A4 | The `_:check-dir` always-exits-0 behavior is real and the planner should use a `failures` counter pattern in `shell:validate` | "Don't Hand-Roll" + Landmine 4 | MEDIUM -- verified by reading `taskfiles/helpers.yml:75-83`. Planner must decide whether to use `_:check-dir` (shape consistency, broken exit) or inline checks (correct exit, slightly more code). Recommendation is inline with `failures` counter. |
| A5 | Adding `DOTFILES_MACHINE` state-file check to `shell:validate` is a worthwhile discretionary extension | "PORT-02 -- shell:validate" | LOW -- explicitly Claude's-discretion per CONTEXT.md; planner picks |
| A6 | `10-SMOKE.md` is the right location for the PORT-03 procedure | "PORT-03 -- Smoke Procedure Sketch" | LOW -- ROADMAP P10 SC#3 explicitly names this path; high confidence |
| A7 | Phase 10 does not require any new test infrastructure | "Wave 0 Gaps" | LOW -- `task lint`, `task validate`, `task test` already exist; this phase only ADDS items they check |
| A8 | The `2>/dev/null` on `grep -qF '...' /etc/zshenv 2>/dev/null` is necessary when `/etc/zshenv` is absent | "PORT-01 -- ZDOTDIR Write" sketch | LOW -- `grep` on a non-existent file prints to stderr; the `2>/dev/null` suppresses noise without changing exit code |

**The planner should confirm A3 and A4 explicitly in PLAN.md** -- they are the two non-trivial implementation choices in this otherwise-mechanical phase.

## Open Questions

1. **Should PLAN-01 split or remain monolithic?**
   - What we know: CONTEXT.md recommends one plan (entire phase is ~30-50 lines YAML + one TOML row unchanged + short doc section). All five workstreams (PORT-01, PORT-02, AUDIT.md amend, smoke doc, aggregator wire-up) touch unrelated files except PORT-01 and PORT-02 both involve a `task validate` round-trip.
   - What's unclear: whether the planner prefers atomic-commit-per-concern (4 plans) or one-plan-many-edits.
   - Recommendation: **one plan** with clearly-separated tasks. The phase is small enough that one plan with 4-6 tasks is more maintainable than 4 micro-plans.

2. **Should `shell:validate` include the discretionary `DOTFILES_MACHINE` check?**
   - What we know: CONTEXT.md lists this as Claude's discretion.
   - What's unclear: operator preference.
   - Recommendation: **include it** -- it's two extra lines, catches a real fresh-install failure mode, and is symmetric with the rest of `shell:validate`'s "first-shell preconditions" theme.

3. **Does the planner need to update `taskfiles/README.md` and `shell/README.md` references after the include alias change?**
   - What we know: Option B (dual-alias) keeps every existing reference (`task perf:shell`) working unchanged. New `task shell:validate` works alongside.
   - What's unclear: whether the planner should also add a `task shell:validate` reference to the relevant READMEs.
   - Recommendation: **optional** -- the new task surfaces automatically in `task --list`; documentation referrals are nice-to-have but not blocking.

## Environment Availability

This phase requires no new external tools. Every dependency is already present.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `go-task` | All task work | YES | 3.37+ assumed (project minimum) | none -- blocks all task work |
| `sudo` | PORT-01 `/etc/zshenv` write | YES | macOS-native | none |
| `tee` | PORT-01 `/etc/zshenv` write | YES | macOS-native | none |
| `grep -qF` | PORT-01 status + PORT-02 validate | YES | macOS-native | none |
| `messages.zsh` | `info`/`success`/`check`/`cross` helpers | YES | install/messages.zsh:1-71 verified present | none |
| `_:check-dir` helper | PORT-02 (if planner uses it) | YES | taskfiles/helpers.yml:75-83 verified present | inline `[[ -d ... ]]` |
| `yq`/`ggrep` | LINT-02 verification of PORT-01 status block | YES | Phase 1 / Phase 5 stack | none |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

## Sources

### Primary (HIGH confidence)
- `taskfiles/common.yml:36-88` -- v1 source-of-truth for the zdotdir: and validate: tasks (PORT-01 + PORT-02 literal templates)
- `taskfiles/links.yml:139-157` -- existing v2 `zsh:` sub-task (PORT-01's physical home)
- `taskfiles/links.yml:269-277` -- `configs:ghostty:` internal-task extraction pattern (PORT-01 Option C precedent)
- `taskfiles/links.yml:382` -- `links:validate` `exit "$failures"` pattern (PORT-02 exit-code aggregation pattern)
- `taskfiles/shell.yml:1-83` -- current shell.yml hosting `perf:shell` (PORT-02 physical home)
- `taskfiles/macos.yml:256-307` -- v2 `validate:` reference implementation (PORT-02 shape model)
- `taskfiles/helpers.yml:30-103` -- `_:safe-link`, `_:check-dir`, `_:check-file` helpers (verified for PORT-02 viability)
- `Taskfile.yml:31, :80-122, :160-233` -- root taskfile structure: errexit/pipefail global set, includes block, validate aggregator
- `install/messages.zsh:1-71` -- `info`/`success`/`warn`/`error`/`check`/`cross`/`step`/`header`/`debug` helpers
- `manifests/machines/personal-laptop.toml:65-68` -- MAS array containing Things3 (D-07: unchanged)
- `.planning/phases/09-v1-drop-audit/AUDIT.md:11-14, :22, :79` -- counts table + keep-list bullet + row #3 (D-07 amend targets)
- `.planning/phases/10-v1-drop-remediation/10-CONTEXT.md` -- all decisions D-01 through D-08
- `CLAUDE.md` (project root) -- LINT-02, LINT-03b, LINT-04, kebab-case `index` rules, XDG rules, no-AI-attribution, no-emojis
- `.claude/CLAUDE.md` -- conventions, where-to-add-things tables
- `taskfiles/lint.yml:130-201` -- LINT-02 regex and exemption rules (verified safe for PORT-01 status block)
- `docs/MANIFEST.md:1-100` -- schema reference (verified for Things3 row context)

### Secondary (MEDIUM confidence)
- `.planning/ROADMAP.md` -- Phase 10 SC#1 + SC#3 path naming (`10-SMOKE.md`)
- `.planning/REQUIREMENTS.md` -- PORT-01, PORT-02, PORT-03 verbatim
- `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` -- D-09 behavior-equivalence threshold

### Tertiary (LOW confidence)
- None -- every source above is a verified file-read, not WebSearch/training-data inference.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new packages; every tool/helper verified present in codebase
- Architecture: HIGH -- all decisions pinned by CONTEXT.md D-01..D-08; implementation choices analyzed against verified file structure
- Pitfalls: HIGH -- Landmines 1-7 each cross-referenced against specific file lines

**Research date:** 2026-05-17
**Valid until:** 2026-06-17 (30 days; stable target -- no external dependencies that change)
