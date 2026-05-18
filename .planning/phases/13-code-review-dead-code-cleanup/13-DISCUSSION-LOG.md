# Phase 13: Code Review + Dead-Code Cleanup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** 13-code-review-dead-code-cleanup
**Areas discussed:** Reviewer mix & review surface, Plan breakdown shape, Dead-code rule scope

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Reviewer mix & review surface | Which language-aware reviewers run over which paths | ✓ |
| Plan breakdown shape | How to split the phase into plans | ✓ |
| links:* readlink-f fix shape | Inline target-match per entry vs _:check-link helper extension | (not selected — Claude's discretion) |
| Dead-code rule scope | Strict zero-callsite rule vs nuanced interactive-surface preservation | ✓ |

**User's choice:** Three of four areas selected. The `links:*` fix shape was deferred to Claude's discretion in CONTEXT.md (planner picks).

---

## Reviewer mix & review surface

### Q1: ZSH review approach (no zsh-specific reviewer exists)

| Option | Description | Selected |
|--------|-------------|----------|
| shellcheck + ecc:code-reviewer (Recommended) | Two-tier: mechanical (shellcheck) + semantic (code-reviewer). Closest language-specific agent per global rule. | ✓ |
| shellcheck only | Faster turnaround; misses higher-level patterns | |
| ecc:code-reviewer only | Skip shellcheck; single agent; risks missing zsh-specific gotchas | |

**Notes:** D-01 in CONTEXT.md. Surface: bootstrap.zsh, install/*.zsh, shell/functions/*.zsh, shell/aliases/*.zsh, os/*.zsh, identity/*.zsh, claude/hooks/lib.zsh.

### Q2: YAML taskfile review approach

| Option | Description | Selected |
|--------|-------------|----------|
| task lint:taskfile + ecc:code-reviewer (Recommended) | Structural lint (LINT-01..08) + semantic agent pass | ✓ |
| task lint:taskfile only + manual planner review | Faster; relies on planner's read-through | |
| Just task lint:taskfile | Trust lint suite; misses semantic findings | |

**Notes:** D-02 in CONTEXT.md. Targets Taskfile.yml + 13 taskfiles in taskfiles/.

### Q3: TOML manifest review approach

| Option | Description | Selected |
|--------|-------------|----------|
| manifest:validate + planner audit | Schema gate + planner read-through; no subagent | |
| manifest:validate + ecc:code-reviewer (chosen) | Schema + agent pass for cross-file consistency | ✓ |
| manifest:validate only | Smallest scope; risks content-level findings | |

**Notes:** D-03 in CONTEXT.md. Targets manifests/defaults.toml + manifests/machines/*.toml. User chose the maximum-coverage option (not the marked recommendation), accepting marginal-value tradeoff for symmetry with zsh/YAML passes.

### Q4: Aux surface scope (claude/, configs/)

| Option | Description | Selected |
|--------|-------------|----------|
| claude/hooks/* + configs/ in scope; agents/commands/skills out (Recommended) | Repo-authored content in scope; marketplace-symlinked out | ✓ |
| claude/hooks/* only; configs/ + agents/commands/skills out | Smallest aux surface | |
| Full claude/ + configs/ in scope, including marketplace files | Massive surface, low signal-to-noise | |

**Notes:** D-04 in CONTEXT.md.

---

## Plan breakdown shape

### Q1: Plan split shape

| Option | Description | Selected |
|--------|-------------|----------|
| Review-first, then fix-by-category (Recommended) | 6 plans: review -> HIGH -> dead-code -> duplication -> links+smoke -> M/L triage | ✓ |
| Per-language review+fix bundles | Coherent language slices; HIGH list materializes incrementally | |
| One review-and-triage plan, then fix plans emerge from triage | Adaptive; breaks Phase 12's plan-everything-before-execute discipline | |

**Notes:** D-05 in CONTEXT.md.

### Q2: REVIEW.md path

| Option | Description | Selected |
|--------|-------------|----------|
| Use 13-code-review-dead-code-cleanup/13-REVIEW.md (Recommended) | Match init slug; amend ROADMAP SC#1 to align | ✓ |
| Use 13-code-review/REVIEW.md per roadmap SC#1 literally | Honor exact path; deviates from auto-derived slug convention | |
| Update ROADMAP SC#1 to match init slug | Same effective result as option 1 | |

**Notes:** D-06 in CONTEXT.md. Plan 13-01 amends ROADMAP.md SC#1 path in the same commit as the REVIEW.md write.

### Q3: Wave structure

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential (chosen) | One plan per wave; clean dependency chain; easy resume | ✓ |
| Reviewer-batched parallel after review pass (Recommended) | ~2x faster wall-clock; requires careful files_modified mapping | |
| Fully sequential by default; planner parallelizes if clean isolation | Conservative; favors correctness | |

**Notes:** D-05 in CONTEXT.md. User chose sequential over the recommended parallel option, accepting slower wall-clock for cleaner dependency chain.

### Q4: Smoke test format

| Option | Description | Selected |
|--------|-------------|----------|
| Manual procedure in 13-SMOKE.md only (Recommended) | Matches SC#4 verbatim; no new go-task task | ✓ |
| Both: manual doc + automated test:links-smoke task | Higher coverage; goes beyond SC#4 | |
| Both, but automated test in separate Phase 13.1 plan | Defers automated test; risks never materializing | |

**Notes:** D-07 in CONTEXT.md. Automated version captured as deferred idea.

---

## Dead-code rule scope

### Q1: Dead-code rule shape

| Option | Description | Selected |
|--------|-------------|----------|
| Nuanced: interactive surfaces preserved, internals strict (Recommended) | Class A (shell/functions, shell/aliases) preserved; Class B (taskfile tasks, helpers, install/*.zsh helpers, fixtures, hook internals) strict zero-grep | ✓ |
| Strict everywhere: zero grep hits => remove | Cleanest mechanical rule; removes user-facing interactive functions | |
| Manual judgement per finding | Slowest; most accurate | |

**Notes:** D-08 in CONTEXT.md.

### Q2: Orphan fixture detection

| Option | Description | Selected |
|--------|-------------|----------|
| Per-fixture grep against current code (Recommended) | Identify exercised code path; check if it still exists in v2 | ✓ |
| Run all fixtures, look for failures | Failing fixtures as orphan candidates; less reliable | |
| Manual catalog: list every fixture + purpose; cross-check | Most thorough; slowest | |

**Notes:** D-10 in CONTEXT.md.

### Q3: Duplication consolidation threshold

| Option | Description | Selected |
|--------|-------------|----------|
| 3+ near-identical occurrences (Recommended) | Rule of three; matches existing _:check-* helper pattern | ✓ |
| 2+ occurrences | More aggressive; marginal value for 2-caller helpers | |
| Case-by-case | No mechanical threshold | |

**Notes:** D-09 in CONTEXT.md.

### Q4: MEDIUM/LOW defer policy

| Option | Description | Selected |
|--------|-------------|----------|
| Defer if: (a) Phase 14 trim covers it, OR (b) needs new infrastructure (Recommended) | Two explicit defer reasons; bounded and auditable | ✓ |
| Defer if not strictly required by REVW-01..06 | Strict scope reading; misses opportunistic small wins | |
| Fix everything in scope of this phase | No defer; phase scope balloons | |

**Notes:** D-11 in CONTEXT.md.

---

## Claude's Discretion

The following decisions were left to the planner / executor:

- **`links:*` `readlink -f` fix shape** — inline per-entry (27 status block edits) vs extend `_:check-link` helper. User did not select this area for discussion. Recommendation captured in CONTEXT.md: extend the helper (smaller diff, single source of truth, matches `_:check-*` pattern); fall back to inline if go-task `status:`-block `task:` invocation constraints prevent helper use.
- **Reviewer execution order within Plan 13-01** — parallel agent spawns (faster) vs sequential (smaller blast radius). Recommendation: parallel — surfaces are disjoint.
- **HIGH-fix annotation format in REVIEW.md** — short SHA vs full SHA vs `[plan:13-NN]` reference. Recommendation: short SHA.
- **Severity-threshold definitions for HIGH/MEDIUM/LOW** — recommended thresholds in CONTEXT.md (correctness/security = HIGH; portability/idempotency/duplication = MEDIUM; clarity/comments = LOW with Phase 14 defer).
- **"Green tree" definition** — recommended: `task lint && task test` exit 0 after every commit; Plan 13-03 adds the `git grep` zero-hit verification gate.
- **Commit granularity within fix plans** — one finding per commit vs logical batches. Recommendation: logical batches with REVIEW.md row annotations per batch.
- **Single-agent multi-surface call vs one-agent-per-surface in Plan 13-01** — recommendation: one-per-surface for parallelism and context-window fit.

---

## Deferred Ideas

Captured in CONTEXT.md `<deferred>` section:

- Automated `test:links-smoke` task — manual SMOKE.md sufficient for SC#4.
- Net-new lint rule for `readlink -f` target-match — defers per D-11(b).
- Structured logging in `install/messages.zsh` — defers per D-11(b).
- `shellcheck` directive coverage audit — likely surfaces in D-01; lands in Plan 13-02/06 if trivial, defers otherwise.
- Dead-code static-analysis tool — one-shot grep sufficient for Phase 13.
- TOML schema enforcement beyond `manifest:validate` — defers per D-11(b).
- Per-task `desc:` string audit — Phase 14 TRIM-01 scope per D-11(a).
- README/CLAUDE.md dedup — Phase 14 TRIM-04 scope per D-11(a).
- Inline-comment density audit — Phase 14 TRIM-01 scope per D-11(a).
