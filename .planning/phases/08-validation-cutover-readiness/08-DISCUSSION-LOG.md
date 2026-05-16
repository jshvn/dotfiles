# Phase 8: Validation + Cutover Readiness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 08-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 8-Validation-Cutover-Readiness
**Areas discussed:** Scope (cutover execution), `task validate` shape, `links:reconcile` algorithm, Cutover docs shape

---

## Area Selection (initial gray-area pick)

| Option | Description | Selected |
|--------|-------------|----------|
| Scope: cutover execution | Is Phase 8 engineering-only or does it include per-machine cutover plans? | ✓ |
| task validate shape | Composed validate run-all vs stop-on-fail vs parallel | ✓ |
| links:reconcile algorithm | Manifest-derived vs walk-and-check; folds in links.yml template-EOF fix | ✓ |
| Cutover docs shape | CUTOVER.md, MIGRATION.md, MACHINES.md, top README structure | ✓ |

**User's choice:** All four areas selected (multiSelect).
**Notes:** First four picked because they cover engineering scope, the central engineering artifact (validate), the second engineering artifact (reconcile + the pending links.yml bug), and the four cutover-readiness docs in one bucket. No areas deferred.

---

## Scope: cutover execution

### Question 1: Should CUTV-04/05/06 be plans inside Phase 8, or a separate post-phase activity?

| Option | Description | Selected |
|--------|-------------|----------|
| Engineering-only phase | Phase 8 ships engineering + docs; CUTV-04/05/06 become documented post-phase procedure in CUTOVER.md. Phase 8 verifies + closes as soon as engineering + docs are green. | ✓ |
| Cutover plans inside Phase 8 | Engineering + docs plans, then one plan per machine that completes only after its 7-day soak. Phase 8 stays in progress for weeks. | |
| Hybrid: engineering this phase, cutover next milestone | Engineering in P8; CUTV-04/05/06 in a new P9 / cutover milestone with per-machine plans. | |

**User's choice:** Engineering-only phase.
**Notes:** Confirms that 7-day soak cannot live inside a numbered plan and that operational cutover is human-cadence work. CUTV-04/05/06 stay Pending in REQUIREMENTS.md until manually marked done.

### Question 2: Verification surface — just personal-laptop, or pre-flight all four manifests?

| Option | Description | Selected |
|--------|-------------|----------|
| Active machine only | Verify against personal-laptop only; other machines tested during their cutover. | |
| Pre-flight all 4 manifests via state-file swap | Loop `task setup -- <name>` → `task validate` → capture → restore for all four machines. | |
| Active + one server manifest pre-flight | Verify personal-laptop AND server-1 (covers feature-gate matrix without 4-way matrix). | ✓ |

**User's choice:** Active + one server manifest pre-flight (personal-laptop + server-1).
**Notes:** Two representative manifests cover the feature-gate matrix (laptop has claude-marketplace=true + GUI on; server-1 has claude-marketplace=false + GUI off) without requiring all four machines to be exercised from the laptop.

### Question 3: Read-only verify, or include real `task install` end-to-end?

| Option | Description | Selected |
|--------|-------------|----------|
| Read-only verify | `task validate` + `task links:reconcile` detect-only, no install during verify. | |
| Read-only + real `task install` on personal-laptop | Verifier also runs `task install` end-to-end on personal-laptop (mutates state idempotently, exercises LINT-08 <5s gate). | ✓ |
| Read-only + dry-run install | Verifier runs validate + reconcile + `DRY_RUN=1 task install` — adds scope (PERF-02 isn't built). | |

**User's choice:** Read-only + real `task install` on personal-laptop.
**Notes:** Idempotent re-run on the daily-driver machine catches install-pipeline integration bugs during verify. Server-1 stays validate-only — no install on the laptop with server config.

**Continue/next-area gate:** User chose "Next area" — Scope is locked.

---

## task validate shape

### Question 1: Failure-handling semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Run-all, aggregate at end | Each per-component validate runs to completion; final summary table; non-zero exit if any failed. | ✓ |
| Sequential, stop on first failure | Fast-fail; cleaner per-component diagnosis but hides total work. | |
| Parallel with aggregated output | Components run in parallel via deps; output reordered into sections. Adds complexity. | |

**User's choice:** Run-all, aggregate at end.
**Notes:** Cutover-day reporting goal — see every broken thing in one run, not whack-a-mole.

### Question 2: Where does the aggregation logic live?

| Option | Description | Selected |
|--------|-------------|----------|
| Pure go-task with `ignore_error: true` | Each component invoked with `ignore_error: true`; final summary cmd recomputes via cheap status: checks. No new helper. | ✓ |
| Helper script in install/ | New `install/validate-aggregator.zsh` does the orchestration. Cleaner output control; second source of truth for "pass". | |
| Inline shell in root validate cmd | Single shell block in Taskfile.yml calls each `task <component>:validate \|\| true`; collects in array; prints summary. | |

**User's choice:** Pure go-task with `ignore_error: true`.
**Notes:** Per-component validates already own their own check/cross output via messages.zsh. No new helper script; no duplicate "pass" definition.

### Question 3: Feature-off component behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Skip silently when feature off | Each component feature-gates its own body; prints one info line + returns 0; summary shows 'n/a'. Matches identity:validate from P4. | ✓ |
| Skip the task entirely when feature off | Root validate reads resolved.json itself; conditionally invokes only feature-on components. | |
| Always run, mark feature-off as PASS | Components always exit 0 when their feature is off — quiet but misleading. | |

**User's choice:** Skip silently when feature off.
**Notes:** Visibly-distinct n/a status preserves the difference between "passed" and "didn't run".

### Question 4: Does composed validate include lint + test?

| Option | Description | Selected |
|--------|-------------|----------|
| Validate stays runtime-only; lint + test separate | Tier-1 only; lint (Tier 0) and test (Tier 3) stay as separate top-level entries. | ✓ |
| Compose everything into `task validate` | Single "is everything ok?" entry point; slower; duplicates CI. | |
| Add `task check` as the umbrella | New aggregator that runs lint + test + validate; preserves tier separation. | |

**User's choice:** Validate stays runtime-only; lint + test separate.
**Notes:** Preserves the documented tier model (REQUIREMENTS.md "Testing tiers" table). Cutover day uses validate; commit/CI signals use lint/test.

**Continue/next-area gate:** User chose "Next area" — Validate is locked.

---

## links:reconcile algorithm

### Question 1: Source of truth for expected symlinks

| Option | Description | Selected |
|--------|-------------|----------|
| Single EXPECTED_TARGETS var in links.yml | Top-level vars entry listing every declared target path; validate + reconcile both iterate it. As a byproduct, the template-EOF bug retires. | ✓ |
| Extract from existing `_:check-link` cmds in links:validate | Parse links:validate cmds at runtime via yq; pure DRY but coupled to exact YAML structure. | |
| Separate `manifests/links-expected.toml` declarative list | New TOML with `{source, target, feature_gate}` per symlink; third source-of-truth. | |

**User's choice:** Single EXPECTED_TARGETS var in links.yml.
**Notes:** One source of truth + retirement of the template-EOF bug class in the same refactor. The bug was noted "benign" in 07-VERIFICATION.md but actually blocks `task links:validate`.

### Question 2: Filesystem walk algorithm

| Option | Description | Selected |
|--------|-------------|----------|
| Walk EXPECTED_TARGETS' parent dirs only | Derive parent dirs from the list; `find -maxdepth 2 -type l`; check readlink against $DOTFILEDIR. Bounded, fast. | ✓ |
| Walk all of $XDG_CONFIG_HOME + $HOME dotfiles | Wider net; catches manually-created symlinks but slower; false-positive risk. | |
| Walk $DOTFILEDIR for inverse mapping | Reverse-lookup via mdfind or a state cache; complex invalidation. | |

**User's choice:** Walk EXPECTED_TARGETS' parent dirs only.
**Notes:** Intentional trade-off — misses manually-created stray symlinks outside the known parent dirs (those aren't drift from the manifest). Bounded surface preferred over wide net.

### Question 3: Interactive `--remove` prompt UX

| Option | Description | Selected |
|--------|-------------|----------|
| Plain `read -r REPLY` per orphan | y/N per orphan; TTY-gated via `[[ -t 0 ]]`; idiomatic zsh; no deps. | ✓ |
| Batch confirm at the end | Print all orphans, single "Remove all? [y/N]"; loses per-orphan judgment. | |
| `gum confirm` / fancy TUI | Prettier UX; adds runtime dep on `gum` for inner loop. | |

**User's choice:** Plain `read -r REPLY` per orphan.
**Notes:** Matches project zsh-script style. TTY check prevents non-interactive contexts from blocking on stdin.

### Question 4: CUTV-08 install-time orphan-warn placement

| Option | Description | Selected |
|--------|-------------|----------|
| Very last step, after packages:verify | Append to root install cmds after the existing final step; mirrors VRFY-04 pattern. | ✓ |
| Embedded in `links:all` | Runs right after links land; misses orphans created later in the pipeline. | |
| Standalone aggregator slot at root | New `task install:post-checks` groups packages:verify + links:reconcile. | |

**User's choice:** Very last step, after packages:verify.
**Notes:** Natural "after everything settled" position. Non-fatal — uses internal `--warn-only` mode that swallows non-zero exit and emits via warn() to stderr.

**Continue/next-area gate:** User chose "Next area" — Reconcile is locked.

---

## Cutover docs shape

### Question 1: docs/CUTOVER.md structure

| Option | Description | Selected |
|--------|-------------|----------|
| Top procedure + per-machine table | Two halves: shared verification procedure on top; per-machine state table at bottom. Manual updates. | ✓ |
| Per-machine sections + frontmatter blocks | One H2 per machine with YAML frontmatter status block + inline verification log. | |
| State file + auto-generated doc | Per-machine JSON state + `task cutover:render` generates the doc. Cleanest separation; adds tooling. | |

**User's choice:** Top procedure + per-machine table.
**Notes:** Single doc serves both DOCS-08 (procedure) and CUTV-03 (state). Status values are human-managed; days-on-v2 computed manually.

### Question 2: docs/MIGRATION.md structure

| Option | Description | Selected |
|--------|-------------|----------|
| Per-concept narrative + path mapping table | Per-concept sections with "what changed / why" + small old→new tables; rollback section closes. | ✓ |
| Single big path-mapping table | One large table; compact; tells "what" not "why". | |
| Concept-only narrative, no path table | Pure narrative; weakest for AI-agent migration. | |

**User's choice:** Per-concept narrative + path mapping table.
**Notes:** Reads top-to-bottom on first cutover; greps by old path later. Rollback section anchors on the CUTV-06 "archive not delete" rule.

### Question 3: docs/MACHINES.md vs source-of-truth manifests

| Option | Description | Selected |
|--------|-------------|----------|
| Thin doc, manifest is source of truth | One section per machine with purpose/hardware/role/special-handling prose; "See manifests/machines/<name>.toml" for declarative state. | ✓ |
| Full duplication for grep-friendliness | Each section lists every feature/identity/package; two places to update. | |
| Auto-generated from manifests at validate time | `task docs:machines` renders the doc; clean sync but loses prose. | |

**User's choice:** Thin doc, manifest is source of truth.
**Notes:** Avoids the doc-drift class that motivated dropping profile suffixes. Doc cadence: update on role narrative change, not on feature flag flip.

### Question 4: Top-level README.md shape

| Option | Description | Selected |
|--------|-------------|----------|
| Tutorial walkthrough + where-to-add table | Manifest model framing + fresh-machine flow + where-to-add table + doc pointers; replaces v1 README entirely. | ✓ |
| Reference-style pointers | Very short; just a paragraph + links table; lean on docs/MANIFEST.md. | |
| Hybrid: short intro + commands + doc index | Intro + command quick-reference + docs index; no walkthrough. | |

**User's choice:** Tutorial walkthrough + where-to-add table.
**Notes:** No emojis, no AI attribution. Mirrors the where-to-add table from project `CLAUDE.md`.

**Continue/done gate:** User chose "Ready for context" — discussion complete.

---

## Claude's Discretion

- Per-component validate ordering inside the composed `task validate` (alphabetical or topological by deps).
- Final summary table format (rich box-drawn vs plain text) — match existing `messages.zsh` style.
- `links:reconcile` output format (one-line-per-orphan vs grouped-by-parent-dir).
- Exact ordering of the four cutover docs within Phase 8 (engineering plans precede docs plans; the four docs interleave freely).
- Optional cleanup of dead `taskfiles/claude-stub.yml` (Phase 7 deferred deletion).

## Deferred Ideas

- `DRY_RUN=1 task install` (PERF-02) — surfaced during validate-shape discussion; rejected (would expand P8 scope). v2 work item.
- Per-component drift detection beyond VRFY-03 + reconcile (PERF-01) — v2.
- `task cutover:soak-check` helper — rejected; 7-day soak stays manually tracked in CUTOVER.md.
- Auto-generated `docs/MACHINES.md` — rejected in D-14.
- `task check` umbrella (lint + test + validate) — rejected in D-07.
- All v2 work items (LINUX-V2-*, PERF-*, TOOL-V2-*).
