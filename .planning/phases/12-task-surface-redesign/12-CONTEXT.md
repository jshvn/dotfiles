# Phase 12: Task Surface Redesign - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit every task currently surfaced by `task --list` (44 visible entries on the post-Phase-11 v2-only surface), classify each as keep / rename / mark-internal / remove, apply the verdicts across `Taskfile.yml` + every included taskfile + shell aliases + docs, and ensure the bare `task` invocation prints a curated two-tier menu.

Concrete shape (locked by SURF-01..04 and the decisions below):

- The classification table covers every row in today's `task --list` output. Six-column shape mirroring Phase 9's AUDIT.md house style: `task name (current)`, `verdict`, `new name (if renamed)`, `internal: true?`, `rationale`, `callsites to update`. Lives at `.planning/phases/12-task-surface-redesign/SURFACE.md`.
- Curation rule (D-01): only `task install`, `task setup`, `task validate`, `task test`, `task lint` are top-level operator commands. Every per-component install/validate goes `internal: true`. Diagnostics surface under three namespaces -- `show:` (state), `audit:` (drift), `refresh:` (explicit manual refresh). Lint and test sub-checks go internal; only their aggregators are public.
- `perf:` namespace is dropped (the dual-aliased include from Phase 10 D-06 retires). The cold-start gate task becomes `shell:startup-time`. `shell:validate` stays.
- Naming normalization runs across BOTH public and internal tasks (D-08). Aggregator pattern locks to `<ns>:install` everywhere (`links:all` -> `links:install`; new `macos:install` aggregates `macos:apply-defaults` + `macos:install-shell`). Sub-target tasks become `<ns>:install-<target>` (`links:install-zsh`, `identity:install-ssh`, etc.); `macos` uses `apply-` for non-install actions.
- Bare `task` prints a hand-rendered two-tier menu: top-level commands prominent, namespaces summarized one-line each. A new lint check enforces banner-vs-public-task-list parity so the menu cannot silently drift.

Zero net-new features. Phase 13 (Code Review + Dead-Code Cleanup) depends on Phase 12 leaving a coherent task surface for the language-aware reviewers to read.

</domain>

<decisions>
## Implementation Decisions

### Curation criteria -- the verdict rule

- **D-01 (strict pipeline-vs-operator split):** Top-level operator commands are exclusively `install`, `setup`, `validate`, `test`, `lint`. Every per-component install (`claude:install`, `packages:install`, `identity:install`, `links:install` (renamed from `links:all`), `macos:install` (new aggregator)) gets `internal: true`. Every per-component validate (`claude:validate`, `identity:validate`, `links:validate`, `macos:validate`, `packages:validate`, `manifest:validate`, `shell:validate`) gets `internal: true`. The `task validate` aggregator already iterates them by name (Taskfile.yml:206, 213); the iteration loop continues to work because go-task's `internal: true` only affects `task --list` visibility, not task invocability.
- **D-02 (diagnostics public under show: + audit:):** Diagnostics fall into two families and get two namespaces. State-printers go under `show:` -- `show:manifest` (renamed from `manifest:show`), `show:claude` (renamed from `claude:status`). Drift-checkers go under `audit:` -- `audit:packages` (renamed from `packages:audit`), `audit:links` (renamed from `links:reconcile`), `audit:manifest` (new public delegate of internal `manifest:validate`). Operator learns one verb prefix and discovers the rest.
- **D-03 (dual-shape for pipeline/operator straddlers):** Two tasks have both a pipeline role and a manual-operator role. `manifest:validate` stays as the internal aggregator-callee; a public `audit:manifest` delegates to it. `claude:update` (explicit refresh, NOT in `task install`) gets a new `refresh:` namespace -- the public name becomes `refresh:claude`. The `refresh:` namespace is the only one created for this single task today; the shape is reserved for future explicit-refresh operations.
- **D-04 (lint + test aggregator-only):** `task lint` (currently aliased from `lint:default`) and `task test` (top-level alias) are public; every individual lint check (`lint:syntax`, `lint:taskfile`, `lint:portability`, `lint:shell-headers`, `lint:test-fixtures`) and test group (`test:default`, `test:hooks`) goes `internal: true`. Operator drives the aggregator; sub-checks exist for the aggregator's benefit.

### `perf:` vs `shell:` dual alias retirement

- **D-05 (drop `perf:`):** `Taskfile.yml:82-83` currently includes `taskfiles/shell.yml` under two aliases (`perf:` and `shell:`). Drop the `perf:` include line. The remaining `shell:` include is the only path.
- **D-06 (cold-start gate becomes `shell:startup-time`):** Inside `taskfiles/shell.yml`, rename the cold-start task (today surfaced as `perf:shell`/`shell:shell`) to `shell:startup-time`. Discoverable name; less symbol-y than `shell:perf`. SHEL-12's 200ms gate behavior is unchanged.
- **D-07 (in-repo SHEL-12 references update):** No `.github/workflows/` exists -- the SHEL-12 references to migrate are entirely in-repo: `Taskfile.yml:82` (drop the alias), `taskfiles/README.md:24, 46` (rewrite to `task shell:startup-time`), `taskfiles/shell.yml:12` (header comment), `shell/README.md:43` (the `hyperfine` invocation note). No external migrations.

### Naming convention -- normalize across the board

- **D-08 (normalize internal names too):** While every taskfile is being edited anyway, internal task names normalize during this pass. Higher commit churn now; lower confusion forever for future maintainers and AI agents reading the taskfile shape.
- **D-09 (aggregator pattern: `<ns>:install`):** Aggregator-of-installs is uniformly `<ns>:install`. Rename `links:all` -> `links:install`. Add a new `macos:install` aggregator that calls `macos:apply-defaults` + `macos:install-shell` (today `task install` calls both as separate steps; the aggregator centralizes the pair). The install pipeline can either invoke `macos:install` (recommended -- adds a real aggregator) or keep calling the two sub-tasks (acceptable -- aggregator just exists for symmetry); planner picks.
- **D-10 (sub-target pattern: verb-first `<ns>:install-<target>`):** Sub-install task names get a verb. Concrete renames: `links:zsh` -> `links:install-zsh`; `links:claude` -> `links:install-claude`; `links:configs` -> `links:install-configs`; `identity:git` -> `identity:install-git`; `identity:ssh` -> `identity:install-ssh`; `identity:one-password-agent` -> `identity:install-one-password-agent`. macOS uses `apply-` for non-install actions: `macos:defaults` -> `macos:apply-defaults`. The Homebrew zsh login-shell registration is still an install action: `macos:shell` -> `macos:install-shell`.
- **D-11 (`identity:install-one-password-agent` length tolerated):** The longest renamed internal task name. Acceptable cost of the verb-first convention. Planner does NOT shorten to `identity:install-1p-agent` or similar; readability beats brevity for internal tasks.

### Bare `task` -- two-tier curated menu

- **D-12 (two-tier menu, hand-rendered):** `default:`'s cmds use `echo` / `info` / messages.zsh helpers to print a curated two-tier banner. Top tier: top-level commands (`install`, `setup`, `validate`, `test`, `lint`) with their descs. Bottom tier: one line per namespace summarizing the available verbs (e.g., `Diagnostics: task show:* (state), task audit:* (drift), task refresh:* (manual refresh)`). Closing line: `Run 'task --list' for the full task graph including internals.` -- omit the "internals" framing if planner prefers; intent is operator hint that more exists.
- **D-13 (lint-check enforces banner parity):** New lint rule in `taskfiles/lint.yml`: grep `default:`'s cmd block for every non-`internal: true` top-level task name (where "top-level" = no `:` in the name) and fail if any are missing from the banner. Catches drift the moment someone adds a top-level command without updating the banner. Implementation lives next to LINT-01 (status-block check) and follows the same lint-fixture pattern.

### Classification table -- the SURF-01 deliverable

- **D-14 (single SURFACE.md table, 6 columns):** `SURFACE.md` lives at `.planning/phases/12-task-surface-redesign/SURFACE.md`. One row per public task in today's `task --list` output. Columns: `task name (current)` | `verdict (keep-as-is / rename / mark-internal / remove)` | `new name (if renamed)` | `internal: true?` | `rationale (one line, cites D-NN where applicable)` | `callsites to update`. House style mirrors Phase 9's `AUDIT.md`. The table IS the source-of-truth that the rename plan iterates -- planner walks rows top-to-bottom, applies verdicts, commits per logical batch.
- **D-15 (callsites column is the planner's modification map):** The `callsites to update` column lists exact `path:line` references for every doc/taskfile/alias that mentions the task being renamed. Pre-populated by the planner via `git grep` during plan-time. Same role as Phase 9's AUDIT.md "v2 owner" column.

### Claude's Discretion

- Whether `task install` invokes `macos:install` (the new aggregator) or continues calling `macos:apply-defaults` + `macos:install-shell` as two separate cmd-block steps (D-09). Recommendation: use the aggregator -- removes a near-duplicate cmd in `Taskfile.yml:238-239`.
- Exact wording of every renamed task's `desc:` string. Phase 14 (TRIM) handles desc-string trimming separately; this phase's planner can carry phase-marker references (P5/P7/SHEL-12/etc.) through unchanged or strip them at discretion. Recommendation: strip phase markers from desc strings as part of the rename touch since each line is already being edited.
- Plan breakdown (one big plan vs split by namespace). Recommendation: split by namespace boundary for review clarity -- one plan per namespace renamed, with `taskfiles/lint.yml` extension as its own plan, and the `default:` banner + lint-check as a final plan. Expected ~6-8 plans.
- Whether to additionally update `.claude/CLAUDE.md`'s "Quick Reference" section (lines 14-20) to reflect the new public surface. Recommendation: yes -- the surface-redesign phase is the right moment, before Phase 14 TRIM-04 dedupes README.md/CLAUDE.md.
- Whether `setup` (top-level) keeps its `manifest:setup` delegation or absorbs the body inline. Recommendation: keep the delegation -- `manifest:setup` becomes `internal: true` (per D-01) but stays as the actual implementation; the top-level `setup` alias survives unchanged.
- Whether `manifest:resolve` is internal (called by `task install` deps and other tasks) or public (operator-callable when debugging stale `resolved.json`). Recommendation: internal -- operator can still invoke directly when needed; the audit:* / show:* split covers the diagnostic use case via `audit:manifest` and `show:manifest`.
- Whether `manifest:test` and `manifest:test:add-machine` move under the `test:` namespace (`test:manifest`, `test:add-machine`) or stay under `manifest:`. Recommendation: move to `test:` namespace -- consistent with `test:hooks`. Even if they go `internal: true` (per D-04), the namespace alignment helps future maintainers.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specs (locked decisions that bound the phase)

- `.planning/ROADMAP.md` §"Phase 12: Task Surface Redesign" -- goal, depends-on Phase 11, requirements SURF-01..04, four success criteria. SC#1 demands the classification table; SC#2 demands rename application across all callsites; SC#3 demands `internal: true` for marked tasks; SC#4 demands the curated bare-task surface.
- `.planning/REQUIREMENTS.md` §"Surface (task surface redesign)" -- SURF-01, SURF-02, SURF-03, SURF-04 exact text.
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" -- "Task surface redesign" bullet at line 22; Phase 12 implements it.

### Prior phase decisions that bind Phase 12

- `.planning/phases/10-v1-drop-remediation/10-CONTEXT.md` §D-06 -- the dual-aliased `perf:` / `shell:` include strategy. D-05/D-06 above retire this.
- `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` §D-01..D-04 -- the six-column AUDIT.md table house style that D-14 above adopts.
- `.planning/phases/11-v1-removal/11-CONTEXT.md` §"Integration Points" -- explicitly hand-off line: "Phase 12's classification table can ignore [`cutover:ack`]" -- confirms the post-Phase-11 surface is the audit input.

### v2 surface to be audited / modified (the targets)

- `Taskfile.yml:70-113` -- the includes block. D-05 drops the `perf:` line (Taskfile.yml:82); D-09 may or may not add a `macos:install` aggregator (lives inside `taskfiles/macos.yml` regardless).
- `Taskfile.yml:120-265` -- the root tasks block (`default`, `setup`, `test`, `validate`, `install`). D-12 rewrites `default:`'s cmd body. The four top-level wrapper tasks stay public; their descs may be tightened (Claude's discretion).
- `Taskfile.yml:206, 213` -- the `task validate` aggregator's iteration list (`manifest identity links macos packages claude shell`). Continues to work after per-component `validate` tasks go `internal: true` (D-01) -- internal only affects `task --list` visibility.
- `Taskfile.yml:235-255` -- the `task install` pipeline. D-09 recommendation: replace lines 238-239 (`macos:defaults` + `macos:shell`) with a single `macos:install` task call.
- `taskfiles/manifest.yml` -- contains `manifest:resolve`, `manifest:setup`, `manifest:show`, `manifest:test`, `manifest:test:add-machine`, `manifest:validate`. Most become internal; `manifest:show` becomes `show:manifest`; `manifest:validate` keeps its internal name + gains `audit:manifest` public delegate.
- `taskfiles/lint.yml` -- contains `lint:default`, `lint:syntax`, `lint:taskfile`, `lint:portability`, `lint:shell-headers`, `lint:test-fixtures`. Sub-checks go internal; `lint:default` stays as the aggregator (top-level `lint` already aliases it). New lint check D-13 is implemented here.
- `taskfiles/links.yml` -- contains `links:all`, `links:zsh`, `links:claude`, `links:configs`, `links:validate`, `links:reconcile`. All renamed per D-09/D-10; `links:reconcile` becomes public `audit:links` per D-02.
- `taskfiles/identity.yml` -- contains `identity:install`, `identity:git`, `identity:ssh`, `identity:one-password-agent`, `identity:validate`. All renamed per D-09/D-10 (sub-targets get `install-` prefix); `internal: true` per D-01 except where surfaced via show:/audit:.
- `taskfiles/packages.yml` -- contains `packages:install`, `packages:compose`, `packages:verify`, `packages:audit`, `packages:validate`. `packages:audit` becomes public `audit:packages` per D-02; rest go internal.
- `taskfiles/claude.yml` -- contains `claude:install`, `claude:status`, `claude:update`, `claude:validate`. `claude:status` becomes `show:claude`; `claude:update` becomes `refresh:claude`; `claude:install` / `claude:validate` go internal.
- `taskfiles/macos.yml` -- contains `macos:defaults`, `macos:shell`, `macos:validate`. All renamed per D-10; D-09 adds the `macos:install` aggregator.
- `taskfiles/shell.yml` -- single-file home for the dual-include `perf:` / `shell:` namespaces. D-05/D-06 collapse to `shell:` only; cold-start task becomes `shell:startup-time`.
- `taskfiles/test.yml` -- contains `test:default`, `test:hooks`. D-04 marks both internal.
- `taskfiles/helpers.yml` -- already entirely `internal: true`. No changes needed beyond verifying the audit captures this (the file is excluded from the rename pass because every task is already correctly internal).

### Doc references that must update (SURF-02)

- `README.md:33-34` -- "task setup -- <machine-name>" / "task install" fresh-install lines. Stay correct (top-level commands unchanged).
- `README.md:46, 49` -- table rows referencing `task setup`. Stay correct.
- `.claude/CLAUDE.md:14-20` -- "Quick Reference" section. Update `Resolve manifest` (was `task manifest:resolve` -- if it goes internal per Claude's discretion, drop the bullet or rewrite). Update `Show manifest` to `task show:manifest`.
- `CLAUDE.md:116, 119` -- table rows referencing `task setup`. Stay correct.
- `docs/MANIFEST.md:468-472` -- the manifest task surface table. Update `task manifest:resolve` / `task manifest:show` / `task manifest:validate` / `task manifest:test` to reflect new names per D-02 and Claude's discretion item.
- `docs/SECURITY.md:138` -- references `task lint`. Stays correct (top-level alias).
- `docs/MANIFEST.md:418` -- references `task install`. Stays correct.
- `docs/MACHINES.md:67` -- references `task macos:defaults`. Updates to `task macos:apply-defaults` per D-10 (if doc surfaces the internal name) OR drops the reference if surfacing internal names in operator docs is undesirable -- planner picks.
- `taskfiles/README.md` -- update every namespace section header / task reference to match the renamed surface. Phase 14 TRIM-04 may further dedupe this against CLAUDE.md; Phase 12 just refreshes the names.
- `shell/README.md:43` -- update the cold-start gate reference from `task perf:shell` to `task shell:startup-time` per D-07.

### Convention docs (rules every implementation must follow)

- `CLAUDE.md` (project root) §"Rules" -- LINT-01 (every install task has a `status:` block); LINT-02 (template vars `{{.X}}` in status blocks); kebab-case feature `index` rule. Every renamed task keeps its existing `status:` block; the lint suite continues to enforce.
- `.claude/CLAUDE.md` §"Conventions" -- no AI attribution; no emojis in any file; file-level comment block at top of every script. Renamed task headers retain their file-level comment blocks (updated for the new task names).
- `taskfiles/lint.yml` itself -- D-13 extends this file with the banner-parity check. The new check follows LINT-01..LINT-07's lint-fixture-driven pattern (positive + negative cases under `taskfiles/test/`).

### Codebase maps (for context)

- `.planning/codebase/STRUCTURE.md` §"Naming Conventions" / "Tasks" -- the v1-era naming notes. D-09/D-10's verb-first / aggregator-`install` pattern supersedes any v1 conventions captured there.
- `.planning/codebase/CONVENTIONS.md` -- file/directory conventions. The task naming convention is documented IN Taskfile.yml + CLAUDE.md, not in CONVENTIONS.md; no edit needed there.
- `.planning/codebase/ARCHITECTURE.md` -- five-layer model. The renamed surface still reflects the same layering (links / packages / identity / macos / claude / shell + manifest keystone); no architectural change.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `internal: true` is already in active use across 5 taskfiles (helpers.yml, links.yml, macos.yml, claude.yml, plus implicit guidance in lint.yml comments). Pattern is established and lint-verified -- Phase 12 just applies it to more rows. No new infrastructure needed.
- `task --list` filter behavior: go-task already hides `internal: true` tasks from `task --list` output without needing any custom filter. The D-12 banner can rely on this: bare `task` prints the banner; operator who wants details runs `task --list` and sees only public tasks.
- `taskfiles/lint.yml`'s LINT-01..LINT-07 fixture-driven shape (positive + negative test cases under `taskfiles/test/`) is the template D-13 follows. New banner-parity check joins the same fixture suite.
- `install/messages.zsh` `header` / `info` / `success` / `check` helpers are already used in `default:`-style output blocks; D-12's hand-rendered banner uses the same helpers for visual consistency with `task validate`'s summary block (Taskfile.yml:212-223).
- `git grep` is the primary callsite-finder (already proven in Phase 11's SC#5 grep gate). D-15's callsites column is pre-populated via `git grep -n '<old-task-name>'` per row -- no new tooling.

### Established Patterns

- Phase 9's six-column classification table (AUDIT.md house style): one row per discrete unit, six columns covering `what` / `current status` / `verdict` / `rationale` / `next owner`. D-14 adopts this shape verbatim for SURFACE.md.
- Phase 10/11's commit shape: one logical unit per commit, every commit leaves a green tree (`task lint` passes, `task --list` is invokable). Phase 12 follows the same shape -- each rename batch is its own commit; the lint suite is the green-tree gate after every commit.
- Phase 11 D-04's callers-first ordering: rename callers before renaming the callee (otherwise the rename breaks the call). Same pattern applies here -- if `task install` calls `task: links:all`, the cmd reference updates BEFORE or IN THE SAME commit as the `links:all` -> `links:install` rename.
- The "internal: true marks intent, lint enforces structure" pattern from helpers.yml + the LINT-01..03 rules. Phase 12 expands the internal set; the structural rules continue to work unchanged.

### Integration Points

- `Taskfile.yml`'s `validate:` aggregator iteration loop (lines 206, 213) iterates by namespace name (`manifest identity links macos packages claude shell`); each iteration invokes `task <ns>:validate`. After D-01 marks every per-component validate `internal: true`, the loop continues to work because `internal:` only affects `--list` visibility. No code change to the loop body required.
- `Taskfile.yml`'s `install:` task body (lines 235-255) directly calls `task: links:all`, `task: packages:install`, `task: claude:install`, etc. by name. Every rename in D-09/D-10 must update these inline `task:` references in the same commit OR a callers-first commit per D-04 discipline.
- Operator shell alias `alias update='task install'` (Phase 3 / PROJECT.md D-10) does NOT need updating -- `task install` stays public and named the same. No shell aliases need migration in this phase.
- The lint suite (`task lint`) runs on every plan completion in v2's commit discipline. D-13's banner-parity check joins this loop; banner drift fails CI/local-lint immediately, not at next `task` invocation.
- Phase 13 (Code Review + Dead-Code Cleanup) reads from Phase 12's renamed surface. Reviewer agents see consistent task naming, making it easier to spot unused-task / duplicate-task patterns. Phase 12 leaves the surface in the shape Phase 13 audits against.
- Phase 14 (Comment + Doc Trim) inherits Phase 12's renamed-task references in every README/CLAUDE.md/docs/* file. Phase 14's TRIM-04 (README/CLAUDE.md dedup) operates on the already-renamed surface; no additional rename churn needed in Phase 14.

</code_context>

<specifics>
## Specific Ideas

- The full classification table will have ~44 rows (one per public task in today's `task --list`) plus internal tasks the planner chooses to also list for completeness. Verdict distribution (rough estimate from this discussion): ~5 keep-as-is (top-level commands), ~20 mark-internal (per-component install/validate), ~12 rename (diagnostics moving to `show:*` / `audit:*` / `refresh:*` + aggregator + sub-target renames), ~0 remove (Phase 11 already removed the deletion-worthy tasks).
- The `default:` banner concrete shape (D-12) -- planner builds the actual echo block; example shape:
  ```
  Dotfiles -- common tasks:

    install     Install dotfiles for the active machine
    setup       Set the active machine: task setup -- <machine-name>
    validate    Validate full installation state
    test        Run all smoke tests
    lint        Run all lint checks

  Diagnostics:
    task show:*      Inspect current state (manifest, claude)
    task audit:*     Detect drift (manifest, packages, links)
    task refresh:*   Manually refresh a layer (claude)

  Run 'task --list' for the full task graph including internals.
  ```
  Wording is planner-discretion; intent is two-tier + namespace summary + escape hatch to `--list`.
- The D-13 lint check's failure message should name the missing task explicitly, e.g., `lint: 'task <name>' is public but missing from default:'s banner -- update the banner in Taskfile.yml`. Matches the LINT-01..03 message style (action + location).
- `identity:install-one-password-agent` (D-11) is 32 characters -- the longest internal task name post-rename. Planner does NOT abbreviate. Future task name additions can use this as the implicit length budget.
- The `audit:manifest` public delegate (D-03) is a thin wrapper -- one cmd block: `task: manifest:validate`. Same pattern can apply to any other future audit:* dual-shape.

</specifics>

<deferred>
## Deferred Ideas

- Renaming `manifest:resolve` to fit the new namespace scheme (e.g., `manifest:compile` or `setup:resolve`): not addressed in this discussion; planner's discretion per D-01. If renamed, the rename joins the same lint-cycle commit discipline as the rest of Phase 12.
- Adding a `task help` or `task doctor` top-level command: out of scope. `task --list` + the bare-task banner already covers discovery; a `doctor` command would be net-new functionality.
- Renaming top-level commands (`install` -> `apply`, etc.): explicitly rejected -- `task install` is the canonical entry per PROJECT.md key decisions, and operator muscle memory is the strongest argument against any top-level rename.
- Adding a `task uninstall` or rollback command: out of scope; the dotfiles model has no uninstall path (symlinks unlinked via direct rm; no in-tree command). Would be a v2.x feature.
- A `task surface:audit` task that programmatically checks `task --list` against an expected-public-set fixture: rejected for this phase. D-13's banner-parity check covers the most common drift class (operator forgets to update `default:`). A broader surface-fixture audit could be added in v2.x but adds non-trivial fixture maintenance overhead.
- Phase 14 TRIM-04 README.md/CLAUDE.md/`.claude/CLAUDE.md` dedup: explicitly deferred to Phase 14 -- this phase only updates references to renamed tasks, not the broader doc-dedup work.
- `desc:` string trimming (removing P5/P7/SHEL-12/TOOL-04 phase markers): partially Claude's discretion in this phase (D-Claude's-Discretion item); fully scoped in Phase 14 TRIM-01. If planner chooses to strip phase markers during the Phase 12 touch, the diff lands here; if not, Phase 14 picks it up.
- Adding shell-completion (zsh `_task` completion) tuned to the curated surface: out of scope; if added later, it reads from `task --list` JSON output and inherits the curated public set automatically.

</deferred>

---

*Phase: 12-task-surface-redesign*
*Context gathered: 2026-05-18*
