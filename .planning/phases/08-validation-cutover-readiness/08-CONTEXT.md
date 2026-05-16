# Phase 8: Validation + Cutover Readiness - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 8 ships the engineering deliverables and cutover-readiness docs that make
per-machine v1→v2 cutover possible:

1. **Composed `task validate`** — root aggregator that runs every per-component
   validate (manifest + identity + packages + packages:verify + macos + claude +
   links + tool configs) in run-all-aggregate shape with a final check/cross
   summary table (CUTV-01).
2. **Two-mode `task links:reconcile`** — detect-mode default (CUTV-02:
   non-zero exit if orphans, CI-safe) and `-- --remove` interactive mode
   (CUTV-07: y/N per orphan).
3. **Install-time orphan warning** — `task install` runs `links:reconcile` in
   warn-only mode as the very last step after `packages:verify` (CUTV-08:
   non-fatal warning via `messages.zsh warn()`).
4. **Four cutover-readiness docs** — `docs/CUTOVER.md` (DOCS-08 + CUTV-03),
   `docs/MIGRATION.md` (DOCS-05), `docs/MACHINES.md` (DOCS-06), top-level
   `README.md` (DOCS-01).

**Explicitly out of phase:** real-world per-machine cutover execution
(CUTV-04 four-machine installs, CUTV-05 7-day soak, CUTV-06 v1 archive). Those
requirements stay **Pending** in `REQUIREMENTS.md` and are tracked
operationally inside `docs/CUTOVER.md`. They get marked done by the user
manually as each machine completes its soak — outside the Phase 8 verifier and
outside the GSD plan model (a 7-day soak cannot live inside a numbered plan).

**Key architectural tone (sets the rest of the phase):** engineering-only
phase, run-all-aggregate composed validate built on pure go-task with
`ignore_error: true`, single `EXPECTED_TARGETS` source of truth in
`taskfiles/links.yml` (which fixes the lingering `template: :1: unexpected EOF`
bug in `links:validate` flagged by `07-VERIFICATION.md` as a byproduct),
thin docs that defer to existing source-of-truth artifacts (manifests, README
tables, MANIFEST.md), and a tutorial-walkthrough top-level `README.md` that
replaces the emoji-heavy v1 README entirely.

</domain>

<decisions>
## Implementation Decisions

### Phase 8 Scope

- **D-01: Engineering-only phase; cutover execution is post-phase.** Phase 8
  ships engineering deliverables + the four cutover-readiness docs. CUTV-04,
  CUTV-05, CUTV-06 (real-world per-machine installs, 7-day soak, v1 archive)
  become a documented post-phase procedure inside `docs/CUTOVER.md`. Phase 8
  verifies + closes once engineering is green; per-machine cutover happens at
  human cadence. CUTV-04/05/06 stay **Pending** in `REQUIREMENTS.md` until
  manually marked done after each machine completes its 7-day soak.
  **Rationale (user-led):** "Engineering-only phase (Recommended)." A
  multi-week real-world soak cannot live inside a numbered plan; conflating
  engineering completion with operational cutover would keep Phase 8 "in
  progress" for weeks and corrupt the GSD phase model.

- **D-02: Pre-flight personal-laptop + server-1 manifest pair during
  verification.** Phase verifier runs `task validate` against both manifests
  (representative of the feature-gate matrix: laptop has
  `claude-marketplace = true` + GUI features on; server-1 has
  `claude-marketplace = false` + GUI features off). Server-2 and work-laptop
  are exercised during their actual cutover, not during phase verify. Pattern:
  temporary state-file swap (`task setup -- server-1` → `task validate` →
  restore via `task setup -- personal-laptop`), borrowing the shape from
  `manifest:test:add-machine` from Phase 1. **Rationale (user-led):** "Active +
  one server manifest pre-flight." Two representative manifests cover the
  feature-gate matrix without the full 4-way matrix and without leaving the
  laptop.

- **D-03: Read-only verify + real `task install` end-to-end on
  personal-laptop.** Phase verifier runs (a) `task validate` +
  `task links:reconcile` (detect-only) against both manifests as read-only
  checks, and (b) a real `task install` end-to-end on personal-laptop as the
  final verify step. The install exercises the full pipeline including the
  LINT-08 <5s idempotency timing gate and mutates state idempotently. The
  server-1 manifest stays validate-only (no install on the laptop with server
  config). **Rationale (user-led):** "Read-only + real `task install` on
  personal-laptop." Catches install-pipeline integration bugs during verify;
  the daily-machine install is already running anyway.

### `task validate` Shape

- **D-04: Run-all-and-aggregate; non-zero exit on any failure.** Composed
  `task validate` runs every per-component validate to completion regardless
  of individual failures. Each component prints its own check/cross output
  during the run; the aggregator prints a final summary table after every
  component has finished. Exit code is non-zero if any component fails. On
  cutover day you see every broken thing in one run, not a whack-a-mole
  sequence. **Rationale (user-led):** "Run-all, aggregate at end
  (Recommended)."

- **D-05: Pure go-task with `ignore_error: true` — no helper script.**
  Aggregation lives in `Taskfile.yml` (or a new `taskfiles/validate.yml`
  aggregator — planner decides). Each component validate is invoked via
  `task: <component>:validate` with `ignore_error: true` so failures don't
  abort the chain. Per-component validates already print check/cross via
  `messages.zsh`. A final shell cmd re-runs each component's status check
  (cheap, already idempotent) to compute the summary table and bubble up the
  aggregate exit code. No new helper script; no second source of truth for
  what "pass" means. **Rationale (user-led):** "Pure go-task with
  `ignore_error: true` (Recommended)."

- **D-06: Skip silently when feature off; show as 'n/a' in summary.** Each
  per-component validate feature-gates its own body (e.g., `claude:validate`
  exits 0 with one info line when `claude-marketplace = false`). Composed
  validate calls every component every time; feature-off components print
  `"<component>: feature disabled — skipped"` and return 0. Summary table
  shows skipped components as `n/a` so feature-off is visibly distinct from
  passing. Matches the existing `identity:validate` pattern from Phase 4.
  **Rationale (user-led):** "Skip silently when feature off (Recommended)."

- **D-07: `task validate` stays Tier-1 runtime-only; `task lint` and
  `task test` stay separate.** `task validate` = "is this machine's installed
  state correct?" (Tier 1 in `REQUIREMENTS.md` testing-tiers table).
  `task lint` (Tier 0 static checks) and `task test` (Tier 3 smoke tests via
  TEST-02) remain as separate top-level entries. They run on different signals
  — lint/test on every commit/CI; validate on cutover day. No `task check`
  umbrella in v1. **Rationale (user-led):** "Validate stays runtime-only;
  lint + test separate (Recommended)." Preserves the documented tier model
  and avoids a 30-second `task validate` that mostly re-runs cached lint.

### `links:reconcile` Algorithm + `links.yml` Refactor

- **D-08: Single `EXPECTED_TARGETS` top-level var in `taskfiles/links.yml`.**
  Add a vars entry listing every declared symlink target path (newline-
  separated, optionally annotated with a feature gate). Refactor
  `links:validate` and the new `links:reconcile` to iterate over that one
  list. Single source of truth; eliminates the duplicate-shape between
  cmds:-block link declarations and the validate-block `_:check-link`
  iteration. **Byproduct:** the `template: :1: unexpected EOF` bug noted in
  `07-VERIFICATION.md` (lines 124-127, "benign warning") gets fixed in
  transit. The cmds-spanning `{{if}} ... {{end}}` wrappers (5 spots in
  `links.yml`: `claude:` lines 133/160, `configs:` lines 186/189, `validate:`
  line 234) plus the bare `manifest:resolve` deps (2 spots at lines 131/184)
  go away as the feature gates collapse into per-iteration inline ternaries
  (the same pattern proven in `taskfiles/claude.yml install:` during this
  session's debugging). **Rationale (user-led):** "Single EXPECTED_TARGETS
  var in links.yml (Recommended)." One source of truth; a refactor that
  retires the bug class with it.

- **D-09: Orphan detection walks EXPECTED_TARGETS' parent dirs only.** Derive
  the set of parent dirs from EXPECTED_TARGETS (e.g.,
  `$XDG_CONFIG_HOME/claude`, `$XDG_CONFIG_HOME/ghostty`, `$ZDOTDIR`,
  `$XDG_CONFIG_HOME/git`, `$HOME/.ssh`). For each parent dir,
  `find <dir> -maxdepth 2 -type l` and check `readlink -f` against
  `$DOTFILEDIR`. Symlinks that point into the repo but are absent from
  `EXPECTED_TARGETS` are orphans. Bounded surface; fast; predictable.
  Intentional trade-off: misses orphans created by manually `ln -s`ing a
  custom path outside the known parent dirs — those aren't drift from the
  manifest. **Rationale (user-led):** "Walk EXPECTED_TARGETS' parent dirs
  only (Recommended)."

- **D-10: Interactive `--remove` uses plain `read -r REPLY` per orphan,
  TTY-gated.** For each orphan, print path + target + `Remove? [y/N]: `,
  read one char from stdin via `read -r REPLY`, default `N` on empty/Enter.
  Magic words: `y`/`yes` removes (idempotent `unlink`), anything else
  skips. The `--remove` mode requires `[[ -t 0 ]]` (TTY check); non-TTY
  contexts print a clear error and exit non-zero so CI/scripts can't
  accidentally enter interactive mode. Idiomatic zsh; matches the project's
  existing zsh-script style; no new runtime dependencies (no `gum`).
  **Rationale (user-led):** "Plain `read -r REPLY` per orphan
  (Recommended)."

- **D-11: Install-time orphan warning runs as the very last step of
  `task install`.** Root `task install` ends with: ... `packages:install` →
  `claude:install` → `macos:defaults` → `macos:shell` → `packages:verify`
  → `links:reconcile` (warn-only, exits 0 with stderr warning). Non-fatal:
  `task install` exits 0 even when orphans are found. Standalone
  `task links:reconcile` (the user-invoked entry per CUTV-02) keeps the
  non-zero-exit-on-orphans contract for CI use; the install-time call uses
  an internal mode flag (`--warn-only`) that swallows the non-zero exit and
  emits via `messages.zsh warn()` to stderr. Final position mirrors the
  VRFY-04 pattern (`packages:verify` as final step from Phase 5).
  **Rationale (user-led):** "Very last step, after packages:verify
  (Recommended)."

### Cutover Docs Shape

- **D-12: `docs/CUTOVER.md` is one doc with two halves (procedure + state).**
  Top half: the shared fresh-machine verification procedure as a numbered
  checklist (bootstrap → `task setup` → `task install` → `task validate` →
  soak period → archive v1 once final machine cuts over). Bottom half: a
  markdown table with one row per machine (`machine` | `status` |
  `cutover-date` | `last-validate-pass` | `days-on-v2` | `notes`). State
  updated manually as you cut over each machine. No separate state file; no
  auto-generated doc. One source for both DOCS-08 (procedure) and CUTV-03
  (state tracking). **Rationale (user-led):** "Top procedure + per-machine
  table (Recommended)."

- **D-13: `docs/MIGRATION.md` is per-concept narrative + per-section
  path-mapping tables.** Open with per-concept sections explaining what
  changed and why: Profile suffix → Machine manifest; Antigen → Antidote;
  `Brewfile-<profile>.rb` → `packages/<purpose>.rb` + `extra_packages`;
  `zsh/` → `shell/` (flat); `gsd-install` → sentinel-gated `claude:gsd` +
  explicit `claude:update`; `hostname`-based `Match exec` → manifest-driven
  identity gates; `macos:shell` `$BREW_ZSH` → `{{.BREW_ZSH}}`; etc. Each
  concept section ends with a small old-path → new-path table for the
  affected files. Doc closes with a rollback section: how to fall back to
  v1 if v2 has a regression on machine X (v1 stays installed during the
  cutover window per the CUTV-06 "archive not delete" rule). Reads
  top-to-bottom on first cutover; greps by old path later.
  **Rationale (user-led):** "Per-concept narrative + path mapping table
  (Recommended)."

- **D-14: `docs/MACHINES.md` is a thin doc; manifests are source of truth.**
  One H2 section per machine (`personal-laptop`, `work-laptop`, `server-1`,
  `server-2`). Each section captures what the TOML can't: machine purpose
  (e.g., "primary dev box", "home media server"), hardware (Apple Silicon
  vs Intel), role narrative, hostname (only if non-default), special
  handling (e.g., "external display setup", "remote access via Tailscale").
  For features/identity/packages, each section has a single line:
  *"See `manifests/machines/<name>.toml` for declarative state."* No
  duplication; the manifest stays the authority. Doc cadence: update when
  a machine's role narrative changes, not when a feature flag flips.
  **Rationale (user-led):** "Thin doc, manifest is source of truth
  (Recommended)." Avoids the doc-drift class that motivated dropping
  profile suffixes in the first place.

- **D-15: Top-level `README.md` is tutorial walkthrough + where-to-add
  table.** Replaces the v1 README entirely (current is emoji-heavy and
  v1-specific). Opens with a short framing of the manifest model (what +
  why; ~2 paragraphs). Then the fresh-machine flow: clone →
  `./bootstrap.zsh` → `task setup -- <machine>` → `task install` (one
  fenced block, runnable end-to-end). Then a "where to add things" table
  mirroring the table in project `CLAUDE.md`. Closes with pointers to
  `docs/MANIFEST.md`, `docs/SECURITY.md`, `docs/CUTOVER.md`,
  `docs/MIGRATION.md`, `docs/MACHINES.md`, `.claude/CLAUDE.md`. No emojis,
  no AI attribution. Door for humans + AI agents.
  **Rationale (user-led):** "Tutorial walkthrough + where-to-add table
  (Recommended)."

### Phase Plan Sequencing (preliminary — planner finalizes)

- The `links.yml` template-EOF bug fix is folded into the reconcile plan
  via the D-08 refactor — NOT a separate pre-Phase-8 cleanup plan. The
  EXPECTED_TARGETS refactor naturally rewrites the cmds: blocks that carry
  the bug.
- Engineering plans precede docs plans: validate + reconcile produce the
  surface area that the cutover-readiness docs describe; docs land on top
  of the engineering once it's verifiable.

### Claude's Discretion

- Per-component validate ordering inside the composed `task validate` —
  alphabetical or topological by deps; not a user-meaningful gray area.
- Final summary table format — match the existing `messages.zsh`
  check/cross style; rich box-drawn vs plain text is a small visual
  choice.
- `links:reconcile` output format (one-line-per-orphan vs
  grouped-by-parent-dir) — both work; planner picks the cleaner one.
- Exact ordering of the four cutover docs inside Phase 8 — engineering
  plans precede docs plans, but the four docs can be interleaved with each
  other freely.
- Optional cleanup of dead `taskfiles/claude-stub.yml` (lingers from
  Phase 7 deferred deletion) — fold into a doc/cleanup plan if convenient,
  not a required deliverable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 Requirements + Roadmap

- `.planning/REQUIREMENTS.md` §Cutover (CUTV-01..08) — required behavior
  contract for `task validate`, `task links:reconcile`, install-time
  orphan-warn, and per-machine cutover sequencing.
- `.planning/REQUIREMENTS.md` §Documentation (DOCS-01, DOCS-05, DOCS-06,
  DOCS-08) — required doc deliverables (top-level README, MIGRATION.md,
  MACHINES.md, CUTOVER.md fresh-machine procedure).
- `.planning/REQUIREMENTS.md` §"Testing tiers (covered by these
  requirements)" table — Tier 1 / Tier 2 / Tier 4 classifications that
  inform D-07.
- `.planning/ROADMAP.md` §Phase 8 (lines 161-172) — goal, depends-on,
  success criteria (`SC#1` aggregator, `SC#2` reconcile two-mode,
  `SC#3` install-time warn, `SC#4` four-machine pass, `SC#5` 7-day soak,
  `SC#6` v1 archive + finalized docs).

### Project-Level Conventions

- `.planning/PROJECT.md` §Constraints + §Key Decisions — no AI
  attribution, no emojis, `task install` is canonical entry, idempotency,
  <5s converged re-run, manifest-driven feature gates.
- `CLAUDE.md` (project root) — v2 conventions: kebab-case feature-key
  `index` access, `{{.X}}` not `$X` in status: blocks, `_:safe-link` only
  outside helpers.yml, no hardcoded HOMEBREW_PREFIX, XDG everywhere,
  `set -euo pipefail` on every executable zsh.
- `.claude/CLAUDE.md` — Project structure, zsh startup order, safety rules
  for AI agents working in this repo.

### Prior Phase Context

- `.planning/phases/07-claude-tool-configs-smoke-tests/07-CONTEXT.md`
  §Decisions — D-01..D-12 from Phase 7 (Claude config tree ownership,
  GSD sentinel D-09/D-11, marketplace status D-12, tool config layout
  D-05/D-06/D-07/D-08). Phase 8's `claude:validate` and `links:validate`
  composition must respect those patterns.
- `.planning/phases/07-claude-tool-configs-smoke-tests/07-VERIFICATION.md`
  §Known Issues (lines 110-127) — flags the `links:validate`
  `template: :1: unexpected EOF` bug as "benign"; D-08 actually fixes it
  during the EXPECTED_TARGETS refactor. Also flags 19 LINT-03a violations
  in pre-Phase-7 taskfiles as carry-forward debt (NOT a Phase 8
  deliverable).
- `.planning/phases/05-packages-layer-brewfile-composition-verification/05-CONTEXT.md`
  — VRFY-04 final-step pattern that CUTV-08 install-time orphan-warn
  mirrors (D-11).

### Repo Codebase Maps

- `.planning/codebase/ARCHITECTURE.md` — five clean layers; cutover-doc
  narrative in MIGRATION.md should anchor on this.
- `.planning/codebase/CONCERNS.md` — 2026-05-13 v1 issues list; MIGRATION
  rollback section references the issue-by-issue mapping.
- `.planning/codebase/STRUCTURE.md` — top-level directory map; READMEs
  point to source-of-truth.
- `.planning/codebase/TESTING.md` — tier model; D-07 inherits from here.

### Existing Code Surfaces (read for current state)

- `Taskfile.yml` (lines 154-159) — root `install:` cmds list; D-11
  install-time orphan warn slots after line 165 (`packages:verify`).
- `taskfiles/helpers.yml` — `_:safe-link`, `_:check-link` (TOOL-03 +
  TOOL-04 hardened in P7); `links:reconcile` invokes `_:check-link` for
  verification.
- `taskfiles/links.yml` — current source for the EXPECTED_TARGETS refactor
  in D-08; has the template-EOF bug at 5 spots and the bare
  `manifest:resolve` dep at 2 spots that D-08 retires.
- `taskfiles/claude.yml` — production model for inline-ternary status
  gates after this session's fix (lines 91-103 post-fix); D-08's
  feature-gate handling adopts the same pattern.
- `taskfiles/identity.yml` §validate, `validate:symlinks`, `validate:git`,
  `validate:ssh-add`, `validate:keys` (lines 279-466) — pattern for
  per-component validate sub-tasks that the composed `task validate`
  aggregates over.
- `taskfiles/packages.yml` §validate, `taskfiles/macos.yml` §validate,
  `taskfiles/manifest.yml` §validate, `taskfiles/claude.yml` §validate —
  the per-component validates that compose into root `task validate`.
- `install/messages.zsh` — `check`/`cross`/`info`/`warn`/`success`;
  composed validate summary + `links:reconcile` orphan output reuse this.

### Docs Surfaces (cross-reference, no copy)

- `docs/MANIFEST.md` — manifest schema; cited from MIGRATION.md per-concept
  sections (Profile suffix → Machine manifest) and from CUTOVER.md
  (`task setup` step references manifest selection).
- `docs/SECURITY.md` — bootstrap trust chain; cited from CUTOVER.md
  fresh-machine procedure (`./bootstrap.zsh` step).
- `docs/README.md` — existing docs/ index; top-level README.md links to
  this and to MANIFEST.md/SECURITY.md/etc.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`install/messages.zsh`** (sourced via `{{.DOTFILES_MESSAGES}}` in every
  taskfile) provides `check`/`cross`/`info`/`warn`/`success` ANSI-styled
  print helpers. Composed `task validate` summary uses these for the
  per-component lines; `links:reconcile` uses `warn()` for orphan
  reporting and the install-time non-fatal banner.
- **`_:safe-link`** and **`_:check-link`** in `taskfiles/helpers.yml`
  (hardened in Phase 7: TOOL-03 target-type clobber guard,
  TOOL-04 strict-mode SOURCE check). `links:reconcile` calls
  `_:check-link` to verify symlinks during its detect pass; the
  `--remove` mode calls `unlink` directly (no helper) on confirmation.
- **Per-component validate tasks** already exist with `messages.zsh`
  check/cross output: `manifest:validate` (`taskfiles/manifest.yml`),
  `identity:validate` + 4 sub-validates (`taskfiles/identity.yml`),
  `packages:validate` (`taskfiles/packages.yml`),
  `macos:validate` (`taskfiles/macos.yml`),
  `claude:validate` (`taskfiles/claude.yml`),
  `links:validate` (`taskfiles/links.yml` — currently broken;
  D-08 refactor fixes it). Composed `task validate` is the
  aggregator; no per-component validate needs rewriting.
- **`task install` final-step pattern** — Phase 5 (VRFY-04) wired
  `packages:verify` as the last step of `task install`. CUTV-08
  install-time orphan warn slots immediately after, using the same shape:
  a non-fatal final check that surfaces drift without blocking.
- **`manifest:test:add-machine`** (`taskfiles/manifest.yml`) — Phase 1
  pattern that temporarily swaps the machine state file to validate against
  a synthetic fixture machine. D-02 pre-flight reuses the same shape for
  server-1 validation from personal-laptop.
- **Inline-ternary status-block pattern** — `taskfiles/claude.yml install:`
  (lines 91-103 after this session's fix):
  `'{{if not (index .MANIFEST.features "<feature>")}}true{{else}}false{{end}}'`.
  The D-08 `links.yml` refactor adopts the same pattern for feature-gated
  EXPECTED_TARGETS entries; the existing broken cmds-spanning
  `{{if}} ... {{end}}` wrappers retire with the refactor.

### Established Patterns

- **`# lint-allow: cmds-without-status`** marker — aggregator tasks whose
  cmds: are entirely `task:` delegations carry this marker to satisfy
  LINT-03a (CLAUDE.md `.claude/CLAUDE.md` Conventions). Composed
  `task validate` is one such aggregator; D-05's pure-go-task approach
  uses this marker.
- **Status-block template var rule (LINT-02)** — `{{.X}}` only inside
  status: blocks; never `$X`. The composed validate summary's status
  block (if any) and the install-time warn integration follow this.
- **`":manifest:resolve"` dep form** — leading-colon root-namespace form
  for cross-taskfile deps (proven across identity.yml, packages.yml,
  macos.yml, and the post-fix claude.yml). D-08's `links.yml` refactor
  flips its two bare `manifest:resolve` deps to this form.
- **Sentinel-idempotency pattern (D-09/D-11 from Phase 7)** — touchfile
  in `$XDG_STATE_HOME/dotfiles/` gates expensive operations. Not
  directly used in Phase 8 (validate + reconcile are read-only), but
  the pattern context informs the install-time orphan-warn's
  "no sentinel needed — read-only check" framing.

### Integration Points

- **Root `Taskfile.yml install:`** (lines 154-159) — install graph. D-11
  appends `task: links:reconcile` (warn-only mode) after line 165's
  `packages:verify`.
- **Existing per-component `validate:` tasks** — composed `task validate`
  invokes each via `task: <component>:validate` with `ignore_error: true`;
  no rewrites needed.
- **`taskfiles/links.yml` (D-08 refactor target)** — current cmds-block
  shape for `claude:` and `configs:` sub-tasks needs the EXPECTED_TARGETS
  refactor + inline-ternary feature gates; `validate:` block needs the
  same treatment so the template-EOF bug retires.
- **`.gitignore`** — already covers GSD-installer runtime artifacts
  (`claude/agents/gsd-*.md`, `claude/skills/gsd-*/`,
  `claude/commands/gsd-*`, `claude/hooks/gsd-*`). No Phase 8 additions
  expected; if reconcile produces a state-cache file (it shouldn't per
  D-09), it would need a new entry.

</code_context>

<specifics>
## Specific Ideas

- **`links:reconcile` is one task with mode flags, not two separate tasks.**
  Default mode: detect-only, non-zero exit on orphans (CUTV-02, CI gate).
  `-- --remove` flag: interactive TTY mode with y/N per orphan (CUTV-07,
  user-driven cleanup). `--warn-only` (internal): swallows non-zero exit
  and emits via `warn()` (CUTV-08, install-time call). One task, three
  invocation shapes; cleaner than three duplicated tasks.
- **`docs/CUTOVER.md` per-machine table columns:** `machine` | `status`
  (planning / ready / installing / soaking / cut-over / archived) |
  `cutover-date` | `last-validate-pass` | `days-on-v2` | `notes`. Status
  values are human-managed; `days-on-v2` is computed manually (no helper
  task in v1; that's a deferred PERF-style enhancement).
- **Carry-forward technical debt explicitly documented in Phase 8 verify
  report (not fixed in Phase 8):**
  - 19 LINT-03a violations in pre-Phase-7 taskfiles (`brew.yml`,
    `common.yml`, `manifest.yml`, `profile-tasks.yml`, `profile.yml`,
    `shell.yml`) — Phase 7 reduced count from 23 to 19; Phase 8 doesn't
    introduce new ones. Note: per-validate-task call from composed
    `task validate` should not trip these (they're cmds-without-status
    on non-validate tasks).
  - Dead `taskfiles/claude-stub.yml` (deletion deferred from Phase 7). Can
    optionally delete in Phase 8 as housekeeping (Claude's discretion);
    not a deliverable.
- **`task install` re-run timing on personal-laptop verify** — should pass
  the LINT-08 <5s gate even with the new `links:reconcile` warn-only step
  appended. Reconcile detect-only walks bounded parent dirs (D-09) so it
  should complete in tens of milliseconds; verifier records the timing
  alongside the existing measurement.

</specifics>

<deferred>
## Deferred Ideas

Items raised during discussion but explicitly out of Phase 8 scope:

- **`DRY_RUN=1 task install`** (PERF-02) — floated during the validate-shape
  discussion as an option for verifier; rejected (would expand Phase 8
  scope by adding a dry-run mode). v2 work item.
- **Per-component drift detection beyond VRFY-03 + reconcile** (PERF-01) —
  broader manifest-declared-vs-deployed diff; v2.
- **`task cutover:soak-check`** — helper that reads CUTOVER.md state and
  reports days-on-v2 for the active machine. Considered for CUTV-05
  enforcement; rejected — soak stays manually tracked via the CUTOVER.md
  table.
- **Auto-generated `docs/MACHINES.md`** (via a `task docs:machines`
  rendered from manifests) — explicitly rejected in D-14 because the doc's
  value is the per-machine prose the TOML can't express.
- **`task check` umbrella** (lint + test + validate) — considered in D-07;
  rejected. Tier separation stays; CI invokes each tier independently.
- **Manual cleanup of `taskfiles/claude-stub.yml` and other Phase-2-era
  stubs** — incidental work, can fold into a doc/cleanup plan if
  convenient but not a Phase 8 deliverable.
- **v2 work items (LINUX-V2-*, PERF-*, TOOL-V2-*)** from `REQUIREMENTS.md`
  §"v2 Requirements" — all deferred to a follow-up milestone after v1
  cutover stabilizes (which is bounded by Phase 8 + the operational
  cutover that follows it).

</deferred>

---

*Phase: 8-Validation-Cutover-Readiness*
*Context gathered: 2026-05-16*
