# Phase 13: Code Review + Dead-Code Cleanup - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

A repo-wide code review of the post-Phase-12 v2 surface, run by language-aware reviewers, produces a single classified finding list. HIGH-severity findings are fixed in this phase; dead code (per a nuanced rule) is removed with `git grep`-verified zero hits; duplicated logic (3+ occurrences) consolidates into shared helpers; the 27-entry `links:*` `test -L` target-match bug is fixed; orphan test fixtures referencing removed v1 code are updated or removed. The phase produces six artifacts in order:

1. `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` — the classified finding list (single file, six-column house style: file:line | severity | category | finding | remediation | commit/PLAN ref). Becomes the spine; later plans cite finding rows.
2. HIGH-severity fix commits — each commit annotated in REVIEW.md with the closing SHA.
3. Dead-code removal commits — each commit lists every symbol/task/fixture it dropped, with the `git grep` evidence inline.
4. Duplication consolidation commits — shared helpers extracted into `taskfiles/helpers.yml` / `install/messages.zsh` / a new shared location where appropriate.
5. `links:*` `readlink -f` fix + `.planning/phases/13-code-review-dead-code-cleanup/13-SMOKE.md` — manual procedure documenting the deliberately-corrupted-symlink test.
6. MEDIUM/LOW triage commit — applies "fix now" verdicts and annotates "defer with rationale" for the rest, all reflected in REVIEW.md.

Review surface is the repo's authored content only: bootstrap.zsh, `install/*.zsh`, `shell/functions/*.zsh`, `shell/aliases/*.zsh`, `shell/theme.zsh`, `os/*.zsh`, `identity/**/*.zsh`, `Taskfile.yml`, `taskfiles/*.yml`, `manifests/defaults.toml`, `manifests/machines/*.toml`, `claude/hooks/*` (lib.zsh + any hook scripts), and `configs/*` (per-tool config files this repo authors). Marketplace-symlinked content under `claude/agents/`, `claude/commands/`, `claude/skills/` is out of scope (not our code).

Zero net-new features. Phase 14 (Comment + Doc Trim) inherits the cleaned surface; SC#5's "green tree after every fix" gate (task lint, task lint:taskfile, every shellcheck invocation, task test — all pass green) prevents regressions from compounding into Phase 14.

</domain>

<decisions>
## Implementation Decisions

### Reviewer mix and review surface

- **D-01 (zsh surface = shellcheck + ecc:code-reviewer):** No zsh-specific reviewer agent exists. Closest match per the global rule "Always use the language-specific reviewer agent if exists" is `ecc:code-reviewer` (general expert reviewer). Two-tier coverage: `task lint:syntax` (which already invokes shellcheck) for mechanical correctness; `ecc:code-reviewer` over the zsh surface (`bootstrap.zsh`, `install/*.zsh`, `shell/functions/*.zsh`, `shell/aliases/*.zsh`, `shell/theme.zsh`, `os/*.zsh`, `identity/**/*.zsh`, `claude/hooks/*.zsh`) for higher-level findings — duplication, dead branches, idiom violations, unsafe patterns shellcheck does not catch.
- **D-02 (YAML surface = task lint:taskfile + ecc:code-reviewer):** `task lint:taskfile` already enforces structural rules (LINT-01 status-block presence, LINT-02 template vars vs shell vars, LINT-03 bare `ln`, LINT-08 banner parity, etc.). Add an `ecc:code-reviewer` pass over `Taskfile.yml` + `taskfiles/*.yml` for semantic findings: near-duplicate status blocks across taskfiles, redundant cmd patterns, orphan internal tasks, drift between taskfiles, unreferenced `deps:`/`task:` references.
- **D-03 (TOML surface = manifest:validate + ecc:code-reviewer):** `manifest:validate` is the schema gate; `install/resolver.zsh` enforces deep-merge invariants. Add an `ecc:code-reviewer` pass over `manifests/defaults.toml` + `manifests/machines/*.toml` for cross-file consistency findings: features declared in `defaults.toml` with zero consumers, inconsistent `extra_packages` shapes between machines, kebab-case adherence in feature keys, identity placeholder drift.
- **D-04 (aux surfaces — claude/hooks and configs in scope; marketplace out):** `claude/hooks/*` is repo-authored zsh — reviewed under D-01. `configs/*` (ghostty, glow, eza, etc.) is repo-authored tool configuration — included with a lightweight review pass for dead config blocks and obsolete settings. `claude/agents/`, `claude/commands/`, `claude/skills/` are symlinked from the external marketplace via `task claude:install` — out of scope (not authored here). README files inside each top-level dir are reviewed as part of the YAML/zsh pass (they document the directory's purpose; doc-text trimming is Phase 14's job, but findings about *inaccuracy* belong here).

### Plan breakdown

- **D-05 (six plans, strictly sequential):** Six plans, one per logical unit, one wave per plan. Order matters because each plan reads REVIEW.md state committed by the prior plan; sequentiality keeps the dependency chain clean and makes resume-after-interrupt trivial. Trade-off accepted: slower wall-clock vs. Phase 12's wave parallelism, in exchange for reviewability and ease of auditing.

  | Plan | Scope | Output |
  |------|-------|--------|
  | 13-01 | Review pass — spawn `ecc:code-reviewer` (potentially in parallel within the plan, planner picks) over zsh / YAML / TOML / aux surfaces; merge + normalize into REVIEW.md (six-column table, severity + category + remediation per row). Also amend ROADMAP.md SC#1 path to match the actual REVIEW.md location. | `13-REVIEW.md`, ROADMAP.md path correction |
  | 13-02 | HIGH-severity fixes — for each HIGH finding in REVIEW.md, apply the remediation. Each fix commit annotates the corresponding REVIEW.md row with the commit SHA (planner picks SHA format vs. `[plan:13-02]` reference style). Commit per logical fix; multiple fixes can share a commit if they touch the same file and are conceptually related. | HIGH rows annotated in REVIEW.md with closing SHA |
  | 13-03 | Dead-code removal — apply the D-08 nuanced rule. Each removal commit lists every symbol/task/fixture dropped, with the `git grep` evidence inline (the actual command + output, or "verified: 0 hits"). | Removed symbols, REVIEW.md dead-code rows annotated |
  | 13-04 | Duplication consolidation — extract per the D-09 rule-of-three. Helpers land in `taskfiles/helpers.yml` for taskfile-shared logic, `install/messages.zsh` or a new `install/<area>.zsh` for shell-shared logic. Each extraction commit names the call sites it consolidated. | Shared helpers, REVIEW.md duplication rows annotated |
  | 13-05 | `links:*` `readlink -f` fix + `13-SMOKE.md` — replace `test -L` target-existence checks in `links:*` status blocks with `readlink -f` target-match checks (the exact fix shape — inline-per-entry vs. extending `_:check-link` helper — is Claude's discretion; planner picks). Write `13-SMOKE.md` with the manual reproduction steps. | `taskfiles/links.yml` status blocks updated, `13-SMOKE.md` committed |
  | 13-06 | MEDIUM/LOW triage — apply "fix now" verdicts to remaining findings; for "defer with rationale" rows, write the rationale into REVIEW.md per D-10. Final REVIEW.md state: every row has a verdict and a closing reference or defer rationale. | REVIEW.md complete; phase ready for verify |

- **D-06 (REVIEW.md path):** `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` is the canonical path. Roadmap SC#1 cites `.planning/phases/13-code-review/REVIEW.md` — a near-miss from before the slug was finalized. Plan 13-01 amends ROADMAP.md SC#1 to match the actual filename (single commit, alongside the REVIEW.md write). The amended path uses the `{padded_phase}-REVIEW.md` naming convention consistent with `{padded_phase}-CONTEXT.md`, `{padded_phase}-SUMMARY.md`, `{padded_phase}-VERIFICATION.md`.
- **D-07 (smoke test = manual only):** `13-SMOKE.md` documents the manual reproduction steps for the `links:*` corruption test. Matches SC#4 verbatim ("verified via a manual test recorded in 13-SMOKE.md"). No new `test:links-smoke` automated task — automating would touch real filesystem state during `task test`, requires careful TMPDIR + cleanup-trap discipline, and the manual procedure is run once per phase, not continuously. Automated version deferred (see `<deferred>`).

### Dead-code rule

- **D-08 (nuanced rule: interactive surfaces preserved, internals strict):** Two classes of code with different rules.
  - **Class A — Interactive user surfaces (PRESERVED):** `shell/functions/*.zsh` and `shell/aliases/*.zsh`. These are autoloaded for interactive shell use via the `.zshrc` glob; "no callsites in repo" does not mean dead. Functions like `whois`, `geoip`, `pubkey`, `cheat` are user-facing tools, invoked at the prompt, never by other repo code. The allowlist is the two glob paths — explicit and auditable.
  - **Class B — Internal surfaces (STRICT):** taskfile tasks (anything under `taskfiles/*.yml`), `_:` helpers in `taskfiles/helpers.yml`, helper functions inside `install/*.zsh`, test fixtures (under `taskfiles/test/`), internal functions inside `claude/hooks/lib.zsh`, and any `os/*.zsh` / `identity/**/*.zsh` helper. For each Class B candidate, run `git grep -rn '<symbol>' --include='*.zsh' --include='*.yml' --include='*.toml' --include='*.rb' --include='Brewfile*' --include='*.md'`. Zero hits across the repo => remove. The removal commit message lists every symbol it drops with the grep command and a one-line result note (e.g., `dropped _:check-binary (0 grep hits)`).
- **D-09 (duplication rule-of-three):** A near-duplicate pattern (e.g., a status block that checks "link exists and points to expected source", a brewfile composition snippet, a message formatting block) extracted into a shared helper when it appears in 3+ places. Two occurrences = keep inline. Phase 12's `_:check-*` helpers (`_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`) are the existing pattern; new helpers join `taskfiles/helpers.yml` and follow its `internal: true` + arg-passing convention. The extraction commit lists the call sites it consolidated.
- **D-10 (orphan fixture detection via per-fixture grep):** For each fixture in `taskfiles/test/lint-fixtures/*`, `taskfiles/test/manifest/*` (if exists), and any hook-test fixture, identify the code path or pattern the fixture exercises (the file the fixture references, the lint rule it asserts, the v1 pattern it tests). Cross-check against current v2 code: if the pattern/path no longer exists, the fixture is orphan. Remove orphan fixtures in the same commit they're identified; update fixtures that test live code but reference renamed symbols (Phase 12's renames may have invalidated fixture references).
- **D-11 (MEDIUM/LOW defer policy — two explicit defer reasons):**
  - **(a)** Anything that's a comment/docstring/doc-text trim concern defers to **Phase 14** (TRIM-01..05). REVIEW.md row notes `defer: Phase 14 TRIM-NN — <why>` (the most-specific TRIM key, e.g., `TRIM-01` for inline-comment density, `TRIM-04` for README/CLAUDE.md dedup).
  - **(b)** Anything that needs new infrastructure (a new lint rule, a new task, structured logging) defers to a **future phase** with explicit roadmap entry. REVIEW.md row notes `defer: needs-new-infra — <one-line rationale>` and the planner adds a corresponding entry to the v2.x backlog section of `ROADMAP.md` (or PROJECT.md "Active" requirements if cross-phase).
  - Everything else with severity MEDIUM or LOW gets `fix now` in Plan 13-06. The defer policy is bounded — every defer row has one of the two explicit reasons. Auditable in REVIEW.md.

### Claude's Discretion

- The `links:*` `readlink -f` fix shape — **inline per-entry** (rewrite each of the 27 status block entries to add `readlink -f <link> = <expected source>`) vs. **extend `_:check-link` helper** (single helper edit; every status block calls `task: helpers:_:check-link link=... expected=...`). User did not select this gray area for discussion; planner picks. Recommendation if planner picks: extend the helper. Rationale: single source of truth, smaller diff, matches the established `_:check-*` pattern. Caveat: go-task `status:` blocks with `task:` invocations have constraints (task can't be `internal: true` in some go-task versions, or status block must be `cmd:` not `task:`); planner verifies the helper-from-status pattern is viable in `taskfiles/helpers.yml`'s current go-task version. If not viable, fall back to inline.
- Reviewer execution order within Plan 13-01 — parallel agent spawns (faster wall-clock) vs. sequential (smaller blast radius if one agent's findings invalidate another's). Recommendation: parallel — the reviewers operate on disjoint surfaces (zsh / YAML / TOML / aux) with no cross-dependency.
- HIGH-fix annotation format in REVIEW.md — short SHA (`abc1234`), full SHA, or `[plan:13-02]` plan reference. Recommendation: short SHA — matches `git log --oneline` style operators already use.
- Severity-threshold definitions for HIGH / MEDIUM / LOW. Recommendation:
  - **HIGH:** correctness bug that breaks `task install` / `task lint` / `task test` in some configuration; security issue (e.g., unsafe pipe-to-shell, missing TLS, command injection); known-broken idempotency (a v1-era `macos:shell:145` class bug surviving Phase 11).
  - **MEDIUM:** portability issue (hardcoded `/opt/homebrew`, hostname literal); idempotency issue that doesn't break correctness (slow re-install); status-block misuse not caught by LINT-01..08; duplication candidate per D-09.
  - **LOW:** clarity, naming, docstring inaccuracy, dead-comment annotation, file-header banner drift. Most LOW findings defer to Phase 14 per D-11(a).
- "Green tree" definition for this phase. Recommendation: after every fix-plan commit, `task lint && task test` both exit 0. Plan 13-03 (dead-code) adds an extra gate: every removed symbol verified zero `git grep` hits in the post-commit tree.
- Commit granularity within fix plans — one finding per commit vs. logical batches per commit. Recommendation: logical batches — a "fix all HIGH findings in `install/resolver.zsh`" commit, with REVIEW.md row annotations for each finding closed by that commit. Matches Phase 11/12's per-logical-unit commit discipline.
- Planner picks whether to spawn `ecc:code-reviewer` as a single multi-surface call (one agent, longer prompt, all surfaces in one REVIEW.md generation) or one-per-surface (four agents in parallel, planner merges outputs). Recommendation: one-per-surface — surfaces are distinct, agent context windows are well-suited per-surface, parallelism reduces wall-clock.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specs (locked decisions that bound the phase)

- `.planning/ROADMAP.md` §"Phase 13: Code Review + Dead-Code Cleanup" — goal, depends-on Phase 12, requirements REVW-01..06, five success criteria. SC#1 demands the classified REVIEW.md; SC#2 demands HIGH-fixed-in-phase + MEDIUM/LOW triaged; SC#3 demands dead-code removed with grep-verified zero hits; SC#4 demands the `links:*` `readlink -f` fix + 13-SMOKE.md; SC#5 demands green-tree after every fix.
- `.planning/REQUIREMENTS.md` §"Review (code review + dead-code cleanup)" — REVW-01, REVW-02, REVW-03, REVW-04, REVW-05, REVW-06 exact text. REVW-05 specifically calls out the 27-entry `test -L` bug from prior surface inspection.
- `.planning/REQUIREMENTS.md` §"Trim (comment/doc trim)" — TRIM-01..05 — Phase 14's scope, referenced by D-11(a) as the defer target for LOW findings about comment/doc density.
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" — "Code review + dead-code cleanup" bullet at line 22; Phase 13 implements it.
- `CLAUDE.md` (project root) §"Rules" — LINT-01 (status-block presence), LINT-02 (template vars), LINT-03 (no bare `ln`), kebab-case `index` rule for feature keys. Every Phase 13 fix must continue to satisfy these.
- `CLAUDE.md` (project root) §"Conventions Not Captured Above" — no AI attribution; no emojis (stricter than global); `set -euo pipefail` on every executable `.zsh`; file-level comment block at the top of every script. Every commit in this phase respects these.
- `.claude/CLAUDE.md` §"Conventions" + §"Quick Reference" — task surface invariants (`task install` is canonical, machine selection via `task setup -- <name>`, `show:/audit:/refresh:` namespaces). REVIEW.md findings about the public surface must respect these (changing them is Phase 12 territory, not Phase 13).
- `~/.config/claude/CLAUDE.md` (user global) §"Code" — functions <50 lines, files <800 lines, immutable-by-default, validate at boundaries. Useful HIGH/MEDIUM threshold reference.
- `~/.config/claude/CLAUDE.md` §"Agent Delegation" — "Always use the language-specific reviewer agent if exists" — D-01/D-02/D-03 reference this rule.

### Prior phase decisions that bind Phase 13

- `.planning/phases/12-task-surface-redesign/12-CONTEXT.md` §D-14 — the six-column AUDIT/SURFACE table house style that REVIEW.md adopts (file:line | severity | category | finding | remediation | commit/PLAN ref).
- `.planning/phases/12-task-surface-redesign/12-CONTEXT.md` §"Established Patterns" — per-namespace plan split, callers-first commit ordering, `git grep` as the callsite-audit tool. D-05/D-08 inherit these.
- `.planning/phases/11-v1-removal/11-CONTEXT.md` §SC#5 grep gate — proven `git grep`-based dead-symbol verification pattern. D-08 reuses verbatim.
- `.planning/phases/10-v1-drop-remediation/10-CONTEXT.md` and `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` — context for the v1-removed surface that REVW-06 / D-10 cross-check fixtures against.

### v2 surface to be reviewed (the targets)

- `bootstrap.zsh` (115 lines) — entry script; pipe-to-shell + `set -e` historical concerns; mostly resolved in Phase 2 but re-audit under D-01.
- `Taskfile.yml` (~10K) — root orchestration; default banner (Phase 12 D-12); five top-level tasks; `install:` pipeline. Review surface for D-02.
- `taskfiles/*.yml` (13 files: audit, claude, helpers, identity, links, lint, macos, manifest, packages, refresh, shell, show, test). 0.4K–18K each. Review surface for D-02.
- `install/*.zsh` (4 files: bootstrap, messages, resolver, test-hooks, compose-brewfile). Compiled-at-load by go-task variables; reviewed under D-01.
- `os/shell-registration.zsh`, `identity/ssh/cloudflared.zsh` — repo-authored zsh helpers; reviewed under D-01.
- `shell/theme.zsh` — alanpeabody-based prompt (locked-keep per PROJECT.md "Out of Scope"); reviewed for correctness only, no idiom-policing.
- `shell/functions/*.zsh` (25 files) + `shell/aliases/*.zsh` (7 files) — reviewed for correctness but PRESERVED under D-08 Class A allowlist.
- `manifests/defaults.toml` + `manifests/machines/*.toml` — reviewed under D-03.
- `packages/core.rb`, `packages/gui.rb` — Brewfile bundles; reviewed for stale entries / removed-formula references during D-08 dead-code pass.
- `claude/hooks/lib.zsh` + any hook scripts under `claude/hooks/` — repo-authored; reviewed under D-01/D-04.
- `configs/*` — repo-authored tool configs; light review under D-04.

### Out-of-scope surfaces (don't review)

- `claude/agents/`, `claude/commands/`, `claude/skills/` — symlinked from external marketplace via `task claude:install`. Not authored here. Out of scope per D-04.
- `.planning/` directory — planning artifacts; doc-text Phase 14 trim concern, not Phase 13 code review.

### Convention docs (rules every fix must follow)

- `CLAUDE.md` (project root) §"Don't Do" — explicit anti-pattern list (no hostname inference, no profile-suffixed files, no `$VAR` in `status:`, no bare `ln -s`). Every HIGH/MEDIUM fix verified against this list.
- `taskfiles/lint.yml` LINT-01..08 — the lint rules that every fix continues to satisfy. The lint suite is the green-tree gate per D-Discretion "green tree definition".
- `install/resolver.zsh` — the deep-merge invariants. D-03 TOML findings must not break resolver output stability.

### Tooling references

- `shellcheck` — invoked via `task lint:syntax`. Stable interface; output mineable.
- `yq` (mikefarah) ≥ 4.52.1 — for taskfile YAML inspection (per `CLAUDE.md` "Tooling Versions").
- `go-task` ≥ 3.37 — for `--list`, `--summary`, and `task <name> --dry` to confirm task wiring during review.
- `jq` ≥ 1.7 — for `resolved.json` inspection during D-03.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`taskfiles/helpers.yml`** already contains `_:safe-link`, `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command`. D-09 duplication extractions extend this file; the pattern is established. Likely landing spots for new helpers: anything that's currently inlined 3+ times across taskfiles (status-block patterns, message-formatting helpers, brewfile composition snippets).
- **`install/messages.zsh`** provides `header`, `info`, `success`, `check`, `warn`, `error` helpers (~70 lines). Loaded via `{{.DOTFILES_MESSAGES}}` template var. If shell-side duplication exists across `install/*.zsh` (e.g., similar coloring logic, similar prompt patterns), this is the shared landing spot.
- **`task lint:taskfile`** already enforces LINT-01..08 structurally. D-02 builds on this, not around it. Fixes for LINT-01-class findings must keep the lint suite passing.
- **`install/resolver.zsh`** — proven TOML deep-merge engine. D-03 TOML findings can be tested by running `task manifest:resolve` and inspecting `resolved.json` deltas before/after.
- **Fixture pattern in `taskfiles/test/lint-fixtures/`** — paired positive (`-ok`) and negative (`-fail`) fixtures per LINT rule. D-10 orphan-fixture detection cross-checks fixture contents against current code; any new lint rule added during this phase joins the same pattern (though net-new infra defers per D-11(b)).
- **`git grep`-driven callsite audit** — Phase 11/12 proven workflow. D-08 dead-code verification and D-09 duplication detection both rely on `git grep -n` against the post-Phase-12 surface.

### Established Patterns

- **Six-column classification table (Phase 9/12 house style):** `what` | `verdict` | `severity/category` | `rationale` | `remediation` | `commit/PLAN ref`. REVIEW.md adopts this verbatim per D-05.
- **Per-logical-unit commit discipline (Phase 11/12 D-04):** each commit leaves a green tree; multiple findings in the same file can share a commit if conceptually related; callers update before/with callee in dead-code removals.
- **Internal-by-default helper pattern (`_:check-*` in helpers.yml):** new shared helpers from D-09 follow the same shape — `internal: true`, args via `vars:`, status block where applicable, file-level comment block.
- **`internal: true` already in use across 5 taskfiles** (helpers, links, macos, claude, lint internal sub-checks). Phase 12 expanded the internal set; Phase 13 doesn't change which tasks are internal — that's Phase 12's job, done.

### Integration Points

- **`task install` pipeline (`Taskfile.yml` ~lines 235-265):** the canonical install path. Every D-08 dead-code removal in this path requires re-running `task install` (in worktree or against a sandbox manifest) to verify the install pipeline still works. Plan 13-03's verification gate includes a dry-run of `task install`.
- **`task validate` aggregator (`Taskfile.yml` ~lines 206-220):** iterates per-component `<ns>:validate` tasks. D-08 internal-task removals in this loop's call set break validation; the loop body itself is stable (just iterates by name).
- **`taskfiles/links.yml` (592 lines, largest taskfile):** the 27-entry `test -L` bug per REVW-05 / D-Discretion. Plan 13-05 is the only plan that materially edits this file; other plans treat it read-only.
- **`task lint` aggregator:** runs every lint check. Plan 13-02 (HIGH fixes) and Plan 13-03 (dead-code) must keep all lint checks green after every commit per D-Discretion green-tree definition. Plan 13-04 (duplication) may add new lint fixtures for new shared helpers, but the lint suite itself isn't extended (that would be new infrastructure per D-11(b)).
- **`task test` aggregator:** runs manifest deep-merge fixtures + hook smoke tests + lint fixtures. D-10 orphan-fixture detection runs within Plan 13-03; orphan removals land in the same commit as the symbol/task they were testing.
- **Phase 14 hand-off:** Phase 14 (Comment + Doc Trim) inherits a code surface with HIGH fixed, dead code removed, duplication consolidated. Phase 14 then operates on comment/doc density. D-11(a) routes LOW findings to Phase 14's TRIM-01..05 backlog with explicit defer rationale, giving Phase 14 a head start on scope.

### Surface Inventory (rough counts for planner reference)

- 4 install zsh scripts: bootstrap.zsh (115), messages.zsh (70), resolver.zsh (625), compose-brewfile.zsh (218), test-hooks.zsh (181). Total ~1.2K lines.
- 13 taskfile YAMLs: ~3.7K total lines (largest: packages.yml 544, identity.yml 476, lint.yml 427, claude.yml 343, macos.yml 333, links.yml 592, manifest.yml 294, test.yml 379, shell.yml 165, helpers.yml 103, audit.yml 42, refresh.yml 26, show.yml 32).
- 25 shell functions (~570 total lines) + 7 alias files (~170 total lines) — all PRESERVED under D-08 Class A.
- 1 defaults.toml + N machine TOMLs in `manifests/machines/` (count from planner — likely 1–4).
- 2 brewfiles: core.rb + gui.rb.
- claude/hooks: lib.zsh + any hook scripts (planner enumerates).
- configs/: ~7 per-tool directories (conda, eza, ghostty, glow, motd, tlrc, trippy).

Estimated finding volume: 40–80 total findings across all severities, mostly LOW. HIGH expected to be small (≤5 — Phase 11 cleared the worst v1-era bugs, Phase 12 normalized the surface). MEDIUM dominated by duplication candidates + portability nits.

</code_context>

<specifics>
## Specific Ideas

- REVIEW.md table shape (D-05): six columns, one row per finding. Column order: `file:line` | `severity` (HIGH/MEDIUM/LOW) | `category` (correctness / portability / security / clarity / dead-code / duplication) | `finding` (one-line description) | `remediation` (one-line action) | `closed by` (commit SHA or `defer: <reason>`). Markdown table with pipe delimiters; sorted by severity desc then category.
- `13-SMOKE.md` (D-07) target shape: a section per scenario with numbered steps. At minimum: the "deliberately-corrupted symlink" scenario with `ln -sfn /tmp/wrong-target <link>` setup, the `task install` invocation, and the `readlink -f <link>` assertion. Optional: additional scenarios planner discovers worth manual-recording (broken parent dir, manifest-changed feature flag, etc.).
- Commit message shape per fix (D-Discretion "commit granularity" recommendation): `fix(13-NN): <one-line> — closes REVIEW.md row(s) <line>:<line>` where NN is the plan number. Per-batch commits annotate every closed row in the body.
- Class B `git grep` command shape (D-08 strict rule): `git grep -nE '\b<symbol>\b' -- '*.zsh' '*.yml' '*.toml' '*.rb' 'Brewfile*' '*.md' ':!.planning/' ':!.git/'`. Excludes the planning directory (descriptions of removed symbols are fine; we care about live code). Word boundary anchors prevent false positives on substring matches.
- The `links:*` fix's helper-vs-inline gray area (D-Discretion): if the planner picks helper-based, the helper signature would be something like `_:check-link-target` taking `link=<path>` + `expected=<path>` vars and exit-coding 0 when `readlink -f link == expected`. Stays under helpers.yml; joins the existing `_:check-*` family.

</specifics>

<deferred>
## Deferred Ideas

- **Automated `test:links-smoke` task** — discussed in D-07 question, deferred. Manual SMOKE.md sufficient per SC#4. Revisit if the manual procedure becomes a regular maintenance burden (e.g., regression caught manually >1 time).
- **Net-new lint rule for `readlink -f` target-match** — if Plan 13-05 inlines per-entry rather than helper-based, a future lint rule could enforce "every `links:*` status block uses `readlink -f` not `test -L`". Defers per D-11(b) (needs new lint infrastructure).
- **Structured logging in install/messages.zsh** — possible MEDIUM finding (current messages.zsh is `echo`-based, fine for human output but no JSON/structured mode). Defers per D-11(b); not REVW-01..06 scope.
- **`shellcheck` directive coverage audit** — checking whether every `set -euo pipefail` script has a `# shellcheck shell=zsh` directive. Likely surfaces in D-01 zsh review; if it's a 0-line trivial fix, lands in Plan 13-02 or 13-06; if it requires new shellcheck wrapping logic, defers per D-11(b).
- **A dead-code static-analysis tool (e.g., a custom `unused-helpers.zsh` script)** — D-08 verifies via ad-hoc `git grep`. A reusable script could automate this for future phases. Defers per D-11(b); the one-shot grep is sufficient for Phase 13.
- **TOML schema enforcement beyond `manifest:validate`** — e.g., a strict schema-document file describing every valid key. D-03 catches drift content-wise; a stricter schema would need new tooling. Defers per D-11(b).
- **Per-task `desc:` string audit** — Phase 12 D-Discretion left this open; Phase 14 TRIM-01 picks up `desc:` density. D-11(a) routes any `desc:`-style LOW finding to Phase 14 explicitly.
- **README/CLAUDE.md/`.claude/CLAUDE.md` dedup** — Phase 14 TRIM-04 scope. D-11(a) routes accordingly.
- **Inline-comment density audit** — Phase 14 TRIM-01 scope. D-11(a) routes accordingly.

</deferred>

---

*Phase: 13-code-review-dead-code-cleanup*
*Context gathered: 2026-05-18*
