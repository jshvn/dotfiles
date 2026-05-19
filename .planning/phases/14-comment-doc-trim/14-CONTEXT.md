# Phase 14: Comment + Doc Trim - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

The Phase 13 surface (HIGH fixed, dead code removed, duplication consolidated, `links:*` `readlink -f` bug fixed) is now trimmed for readability. The phase produces five mechanical passes against the v2 code + doc surface, each backed by a locked rule:

1. **Header banners** (TRIM-02) — every taskfile + every executable `.zsh` file gets a 3-label header block (Purpose / Depends on / Side effects). One `# === ===` 77-char rule above/below the labels; no mid-file separators. Length is qualitative (labels-only, no narrative prose, no anti-pattern explainers, no examples). Replaces the 41-line links.yml banner, the 51-line `.zlogout` banner, and similar.
2. **Inline-comment trim** (TRIM-01) — every `#` comment in `Taskfile.yml` + `taskfiles/*.yml` (1,800+ lines today) evaluated against the three-test KEEP rule: (a) explains non-obvious WHY, OR (b) warns about still-live footgun, OR (c) cites a lint rule the code satisfies. Restatement-of-code, planning-history annotations (`# Phase N`, `# D-NN`, `# Gap N`, `# RESEARCH §X.Y`), section dividers inside files, and stale "what will happen in Phase N" notes get cut. Multi-line `desc:` strings get the same three-test rule (cut restatement; keep when `task --summary` actually benefits).
3. **docs/ review** (TRIM-03) — `docs/CUTOVER.md` and `docs/MIGRATION.md` are already gone (Phase 11). Remaining docs (`MACHINES.md` 73, `MANIFEST.md` 508, `README.md` 7, `SECURITY.md` 139) get reviewed for current accuracy + clear purpose; any obsolete content is removed.
4. **README dedup** (TRIM-04) — `README.md` becomes humans-only (install + 5-command surface). `CLAUDE.md` (project root) becomes the canonical reference for everything an AI agent needs (manifest model, rules, conventions, where-to-add). `.claude/CLAUDE.md` is **deleted** (Claude Code auto-loads root CLAUDE.md on project entry; the duplicate copy in `.claude/` is pure overlap).
5. **TRIM-05 grep gate** (final) — `git grep -E 'v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap'` returns zero matches in code (only `.planning/` retains those). Prereq: build `14-TEACHING-INVENTORY.md` mapping every in-code annotation block to the CLAUDE.md section that covers it; gap-fill CLAUDE.md before stripping any code; only then strip the in-code references.

Zero net-new features. Zero functional change. `task install`, `task validate`, `task lint`, `task test` all pass green after every commit. `14-METRICS.md` records the comment-to-code ratio per file pre/post per SC#1.

</domain>

<decisions>
## Implementation Decisions

### Header banner shape (TRIM-02)

- **D-01 (3 labels — Purpose / Depends on / Side effects):** ROADMAP SC#2 wording wins. The project-root `CLAUDE.md` "Conventions Not Captured Above" bullet currently says "purpose, callers, and side effects" — Plan 14 amends this bullet to "purpose, key dependencies, side effects" to match the locked decision (single commit; no in-code impact). Rationale: dependencies are derivable from `includes:` blocks and `task --summary` already, but the banner makes them scannable without leaving the file; callers are best discovered via `git grep` / `task --summary` (push lookup out of the banner). The two existing project sources disagreed; this resolves the contradiction in favor of the roadmap.
- **D-02 (single `# === ===` 77-char header rule; no mid-file separators):** One banner per file at the top, framed by a 77-character `# === ===` rule above and below the labels. No `# === <section> ===` dividers inside the file. Mid-file structure is conveyed by go-task's own section keywords (`includes:`, `vars:`, `tasks:`) and by `.zsh` function definitions. Trade-off accepted: long taskfiles (links.yml, packages.yml) lose visual scan-bars; reader compensates with editor folding / outline view.
- **D-03 (qualitative length rule — no fixed cap):** Banner is "as long as it needs to be" but: labels-only, no narrative prose, no anti-pattern teaching, no usage examples, no change-history annotations. Length falls out of content discipline. Trade-off: not grep-able for violations; planner uses judgement per file. Typical post-trim banner expected: 6-10 lines (header rule + 3 labels each on 1-3 lines + closing rule).

### Inline-comment trim (TRIM-01)

- **D-04 (three-test KEEP rule):** A `#` comment line stays iff at least one of: (a) it explains a **non-obvious WHY** (the code itself does not reveal the rationale); (b) it warns about a **still-live footgun** (a real failure mode the next maintainer would re-introduce); (c) it **cites a lint rule** the code satisfies (e.g., `# LINT-02: template vars only in status:` — one line). Everything else is cut: restatement-of-code, section dividers inside files (`# === Vars block ===`), planning-history annotations (`# Phase N`, `# D-NN`, `# Gap N`, `# CR-NN`, `# WR-NN`, `# RESEARCH §X.Y` — also caught by TRIM-05 grep gate), "this is the same pattern as X.yml:42" cross-references, anti-pattern teaching paragraphs longer than 3 lines (covered by TRIM-05 teaching-inventory migration).
- **D-05 (`desc:` strings get the same three-test rule):** Multi-line `desc:` blocks (links:all's 3-line desc, `manifest:test:add-machine`'s explainer, etc.) are kept when `task --summary <task>` actually benefits — when the operator needs context to decide whether to invoke. Restatement `desc:` lines get cut to one imperative sentence. Internal `_:` helpers may carry `desc:` but only if `task --list --filter=_:` users (rare) genuinely need it. Phase 12 D-Discretion is now resolved.

### README / CLAUDE.md / .claude/CLAUDE.md (TRIM-04)

- **D-06 (canonical-home rule — three audiences, two files):** `README.md` is **humans-only** (install / 5-command task surface / "what is this repo" / link to CLAUDE.md for contribution rules). `CLAUDE.md` (project root) is the **canonical reference for everything an AI agent or contributor needs**: manifest model, rules (LINT-01..08, kebab-case index, `set -euo pipefail`, no AI attribution, no emojis), conventions, where-to-add tables, tooling versions, the v2 lessons currently scattered as in-code teaching. `.claude/CLAUDE.md` is **deleted** — Claude Code auto-loads root `CLAUDE.md` on project entry, so the duplicate is pure overlap (the loaded-context evidence from this very session already shows both files present, with `.claude/CLAUDE.md` content fully subsumed by `CLAUDE.md`). Trade-off accepted: a human reading only the README misses the rules — they're directed to CLAUDE.md by the README's contribution-rules link.
- **D-07 (verify `.claude/CLAUDE.md` deletion is safe in research):** Before Plan 14-X deletes the file, the planner's research step must confirm Claude Code's project-CLAUDE.md auto-discovery loads `CLAUDE.md` from the project root without requiring `.claude/CLAUDE.md`. This is the documented Claude Code convention but a 5-minute spike against this repo (or Claude Code docs) is the gate. If the spike surfaces any contrary behavior, fallback is the "thin pointer (5-10 lines)" shape from the discussion (single-line "see ../CLAUDE.md" + 5-command surface).

### TRIM-05 grep gate + teaching preservation

- **D-08 (rely on CLAUDE.md Rules + git history; delete in-code references):** All real rules survive in `CLAUDE.md` (LINT-01..08 anti-pattern catalogue, kebab-case index access, `_:safe-link` mandate, `set -euo pipefail`, no AI attribution, no emojis, file-level comment block expectation, XDG-everywhere, no hostname inference, no profile suffixes). In-code planning-history annotations were Phase-history breadcrumbs to keep AI agents oriented during the build — they're no longer needed once the build is done. The long anti-pattern teaching blocks (the 22-line LINT-02 explainer in links.yml:18-39 being the biggest) get cut; their rationale is in CLAUDE.md's Rules section already. Contributors editing `links.yml` are expected to read CLAUDE.md (the README directs them there).
- **D-09 (build `14-TEACHING-INVENTORY.md` as a Plan 14-X prereq before stripping):** Before any `git grep`-driven strip pass, the planner produces `14-TEACHING-INVENTORY.md`: a table enumerating every annotation block ≥3 comment lines or ≥1 `# Phase|D-|Gap|CR-|WR-|RESEARCH §` reference, mapped to the `CLAUDE.md §X` section that covers it. Columns: `file:line` | `annotation snippet` | `lesson encoded` | `covered by CLAUDE.md §X` (or `NEEDS-ADD: <what to add>`). Any `NEEDS-ADD` row is gap-filled into `CLAUDE.md` (or, if the lesson is taskfile-specific, into the appropriate `taskfiles/README.md`) **before** the strip pass runs. The strip commit then enforces SC#5's grep gate. Trade-off: extra plan step + extra artifact, but lowest risk of lesson loss. SC#5's `git grep` command is the final gate; the inventory is the safety net.

### Claude's Discretion

- **Plan breakdown shape** — five requirements, mostly independent (TRIM-01 inline comments, TRIM-02 banners, TRIM-03 docs/ review, TRIM-04 README dedup, TRIM-05 grep gate). Planner picks the shape. Recommendation: 3 grouped plans:
  - **Plan 14-01: Teaching inventory + CLAUDE.md gap-fill** (D-09 prereq). Produces `14-TEACHING-INVENTORY.md` + amends `CLAUDE.md` (including the "callers" → "key dependencies" amendment from D-01). One commit, single artifact, zero code change. This plan is the sequential bottleneck.
  - **Plan 14-02: Trim pass** (TRIM-01 inline comments + TRIM-02 banners + Class-A scope decision applied). Per-file commits or per-subsystem commits (planner picks). Each commit keeps `task lint`, `task test` green. `14-METRICS.md` recorded incrementally or in one final commit.
  - **Plan 14-03: Dedup + final gate** (TRIM-03 docs/ review + TRIM-04 README dedup + `.claude/CLAUDE.md` delete + TRIM-05 final grep gate verification). The grep gate is the closing gate; if it fails, the plan iterates.
  Per-requirement (5 plans) is fine too if 14-02 becomes unwieldy. Sequential within each plan is fine. Phase 13's wave-parallelism does not apply (these passes mostly touch the same files).
- **Scope on D-08 Class A (`shell/functions/*.zsh` + `shell/aliases/*.zsh`)** — Phase 13 D-08 preserved these from dead-code removal; the question is whether TRIM-01/TRIM-02 touch their comment/banner content. Recommendation: **include them in TRIM-02 (banner consistency across repo)**, **skip them for TRIM-01 (inline comment density)** — most of these files have minimal comments anyway; the 11 arg-validation `# ERROR: No <thing> specified` lines deferred from 13-REVIEW to TRIM-02 are stderr-echoes not `#` comments, so they're not in TRIM-01's scope at all. Banner pass over `shell/functions/*` may turn out to be a no-op for many files (most have no banner today); planner can verify per-file.
- **Metrics methodology for `14-METRICS.md`** — SC#1 says "comment-to-code ratio falls measurably, recorded pre/post by `wc -l` on commented vs code lines per file". Planner picks the exact table shape. Recommendation: one row per trimmed file, columns: `file | code_lines | comment_lines_pre | comment_lines_post | delta | %_reduction`. Aggregate row at the bottom. Pre measurements taken at Plan 14-02 start (before any commits land); post measurements taken at Plan 14-02 close. Files not touched by the trim pass omitted (or shown with delta=0 for completeness — planner picks).
- **`.claude/CLAUDE.md` fallback shape (if D-07 research surfaces unexpected Claude-Code behavior)** — if auto-load doesn't happen from root, fall back to the "5-10 line thin pointer" shape: `# Dotfiles\nSee [project CLAUDE.md](../CLAUDE.md) for full conventions.\n\n## 5-command surface\n- task install\n- task setup -- <name>\n- task validate\n- task test\n- task lint`. Planner does not need to commit to this shape unless research forces it.
- **Order of operations within the trim pass (TRIM-01 first, TRIM-02 second, or interleaved)** — recommendation: per-file (trim banner + trim inline comments + run lint, then move to next file). Avoids two passes over the same file; the lint suite gate after each file catches accidental rule-violation introductions.
- **Whether to strip `# lint-allow: cmds-without-status` markers** — these are functional pragmas, not comments. Keep. The three-test rule (c) "cites a lint rule the code satisfies" covers them explicitly.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specs (locked decisions that bound the phase)

- `.planning/ROADMAP.md` §"Phase 14: Comment + Doc Trim" — goal, depends-on Phase 13, requirements TRIM-01..05, five success criteria. SC#1 demands measurable comment-to-code ratio drop recorded in `14-METRICS.md`; SC#2 demands the 3-label banner shape; SC#3 demands `docs/` review; SC#4 demands README/CLAUDE.md/.claude/CLAUDE.md dedup with each piece in one canonical home; SC#5 is the `git grep` zero-match gate.
- `.planning/REQUIREMENTS.md` §"Trim (comment/doc trim)" — TRIM-01, TRIM-02, TRIM-03, TRIM-04, TRIM-05 exact text. TRIM-04 explicitly names the three files for dedup.
- `.planning/REQUIREMENTS.md` §"Future Requirements" — Linux support, Starship swap, function-content audit explicitly deferred past v2.1; ensures Phase 14 does not creep into them.
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" — Phase 14 closes the v2.1 cleanup milestone. After Phase 14, the codebase reads cleanly for a new contributor with zero v2-history context.

### Prior phase decisions that bind Phase 14

- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` — **the highest-value input.** Contains explicit defer rows pointing to TRIM-01, TRIM-02, TRIM-05 with file:line and rationale. Specifically:
  - Row 41 — 11 `shell/functions/*.zsh` arg-validation patterns deferred to TRIM-02 (interactive UX rationale; D-08 Class A).
  - Row 45 — `shell/.zlogout:2-51` 51-line comment block over 2-line body deferred to TRIM-01.
  - Row 46 — `shell/theme.zsh + multiple` decoration banner comments deferred to TRIM-02.
  - Row 48 — `install/resolver.zsh + taskfiles/manifest.yml + taskfiles/test.yml` 4-site "read first line + trim edges" idiom deferred to TRIM-02 (LOW; shared-helper extraction optional).
  - Row 49 — `(general)` `# Phase N` / `# D-NN` / `# CR-NN` / `# WR-NN` / `# RESEARCH §X.Y` annotations across 13 files deferred to TRIM-01 + TRIM-05.
  - Row 28 — `Taskfile.yml:131-148 + 240-248` DOTFILEDIR-leak workaround comment blocks deferred to TRIM-04 / future-phase infra. (TRIM-04 in REVIEW means doc rewrite, not the README dedup — re-read REVIEW remediation column to confirm which TRIM key applies.)
  - Row 15 — `install/README.md:5-7,23-28,...` stale cutover/Brewfile references — already closed (`1ffd04c`) but documents the kind of stale-content review TRIM-03 + TRIM-04 perform.
- `.planning/phases/13-code-review-dead-code-cleanup/13-CONTEXT.md` §D-08 — Class A allowlist (`shell/functions/*.zsh`, `shell/aliases/*.zsh`) preserved from dead-code removal. TRIM-01/02 scope on Class A is Claude's discretion per this CONTEXT (D-08 only constrained removal, not commentary).
- `.planning/phases/13-code-review-dead-code-cleanup/13-CONTEXT.md` §D-11(a) — defer policy that produced REVIEW.md's TRIM-NN defer rows. The defer rationale column is the input to Plan 14 prioritization.
- `.planning/phases/12-task-surface-redesign/12-CONTEXT.md` §D-14 — six-column REVIEW/AUDIT table house style; `14-METRICS.md` and `14-TEACHING-INVENTORY.md` adopt the same column-discipline (one row per file/annotation, clear headers, sorted).
- `.planning/phases/11-v1-removal/11-CONTEXT.md` §RMV-04 — confirms `docs/CUTOVER.md` was removed in Phase 11; TRIM-03 verifies it stays gone.
- `.planning/phases/09-v1-drop-audit/09-CONTEXT.md` §AUDIT-05 — `docs/MIGRATION.md` removal/rewrite decision; current state (file does not exist) implements "remove" outcome; TRIM-03 verifies.

### Convention docs (the destination for teaching migration + the rules every commit must satisfy)

- `CLAUDE.md` (project root, 187 lines) — **the canonical home** per D-06. Sections: "What This Is", "The Manifest Model", "Common Tasks", "Rules" (LINT enforcement, status-block template vars, `set -euo pipefail`, no hardcoded Homebrew prefix, `_:safe-link` mandate, XDG everywhere, kebab-case index access), "Where to Add Things" table, "Conventions Not Captured Above" (no AI attribution, no emojis, file-level comment block, section separators, errors-to-stderr), "Tooling Versions" (yq 4.52.1, go-task 3.37, jq 1.7), "Don't Do" list. Plan 14-01 amends this file (D-01 "callers" → "key dependencies"; D-09 teaching gap-fills).
- `.claude/CLAUDE.md` (125 lines) — **target for deletion** per D-06/D-07. Verify auto-discovery first; then delete.
- `README.md` (79 lines, project root) — **target for humans-only simplification** per D-06. Becomes install + 5-command surface + contribution-rules pointer to CLAUDE.md. Currently overlaps with CLAUDE.md on manifest model + task surface; dedup removes overlap.
- `docs/MANIFEST.md` (508 lines) — manifest schema reference; kept in `docs/`; TRIM-03 reviews for current-accuracy only.
- `docs/MACHINES.md` (73 lines) — per-machine inventory; TRIM-03 reviews for accuracy.
- `docs/SECURITY.md` (139 lines) — security conventions; TRIM-03 reviews for current-accuracy.
- `docs/README.md` (7 lines) — `docs/` directory index; TRIM-03 reviews; possibly updates if a doc is removed.

### v2 surface to be trimmed (TRIM-01 / TRIM-02 targets — pre-trim line counts)

- `Taskfile.yml` (249 lines, 102 comment lines).
- `taskfiles/links.yml` (607 lines, 230 comment lines, 41-line header banner — biggest delta opportunity).
- `taskfiles/packages.yml` (544 lines, 202 comment lines).
- `taskfiles/identity.yml` (476 lines, 167 comment lines).
- `taskfiles/lint.yml` (425 lines, 142 comment lines — citation comments expected to mostly survive D-04 rule (c)).
- `taskfiles/claude.yml` (343 lines, 141 comment lines).
- `taskfiles/macos.yml` (332 lines, 130 comment lines).
- `taskfiles/manifest.yml` (291 lines, 122 comment lines).
- `taskfiles/test.yml` (328 lines, 108 comment lines).
- `taskfiles/shell.yml` (158 lines, 68 comment lines).
- `taskfiles/helpers.yml` (103 lines, 27 comment lines — already lean; minimal delta expected).
- `taskfiles/audit.yml` (42 lines, 14 comment lines — already minimal).
- `taskfiles/show.yml` (32 lines, 12 comment lines — already minimal).
- `taskfiles/refresh.yml` (24 lines, 11 comment lines — already minimal).
- Total taskfiles: ~3,954 lines / ~1,476 comment lines (37% ratio); target post-trim ratio implicit in SC#1 ("measurably falls").
- Shell startup files (`shell/.zshenv` 47, `shell/.zprofile` 46, `shell/.zshrc` 71, `shell/.zlogin` 15, `shell/.zlogout` 53 — comment-line counts) — `.zlogout` is the heaviest target (51-line banner over 2-line body, REVIEW row 45).
- `install/*.zsh` (resolver, messages, bootstrap, compose-brewfile, test-hooks) — banner pass + inline trim apply.
- `os/defaults/*.zsh`, `os/shell-registration.zsh`, `identity/ssh/cloudflared.zsh` — banner pass applies (REVIEW row 46 cited some as heavy-banner offenders).
- `claude/hooks/*` (lib.zsh + hook scripts) — repo-authored; banner pass + inline trim apply.
- `shell/functions/*.zsh` + `shell/aliases/*.zsh` (D-08 Class A) — banner pass in scope (Claude's discretion); inline trim skipped per Claude's-discretion recommendation.

### v2 surface where TRIM-05 grep gate must return zero

Files identified by `git grep -lE '# Phase [0-9]+|# D-[0-9]+|# CR-[0-9]+|# WR-[0-9]+|# RESEARCH §|Gap [0-9]+|v1 (bug|finding|leftover)|UAT [Gg]ap'` excluding `.planning/` and `*.md`:

- `Taskfile.yml`
- `identity/ssh/cloudflared.zsh`
- `install/compose-brewfile.zsh`, `install/resolver.zsh`, `install/test-hooks.zsh`
- `os/shell-registration.zsh`
- `taskfiles/claude.yml`, `taskfiles/identity.yml`, `taskfiles/links.yml`, `taskfiles/lint.yml`, `taskfiles/macos.yml`, `taskfiles/manifest.yml`, `taskfiles/packages.yml`, `taskfiles/test.yml`

These 13 files are the strip-pass surface for TRIM-05 + the teaching-inventory surface for D-09. (Files matched the broader pattern that also includes some legitimate occurrences in `.gitignore`, identity files, etc. — planner runs the SC#5 grep command exactly to scope the gate, not this broader one.)

### Out-of-scope surfaces (do not trim)

- `.planning/` directory — planning artifacts; the `# D-NN` / `# Gap N` annotations there are part of the planning record, not code; TRIM-05's grep gate explicitly excludes `.planning/`.
- `claude/agents/`, `claude/commands/`, `claude/skills/` — symlinked from external marketplace; not repo-authored.
- `packages/*.rb` (Brewfiles) — `brew`/`cask`/`tap` lines with conventional descriptors are not Phase 14 scope.
- `manifests/defaults.toml` + `manifests/machines/*.toml` — comment content (the few there are) is operator-readable identity placeholder context; not trim target unless it duplicates `docs/MANIFEST.md` content (TRIM-03 may surface this).

### Tooling references

- `git grep` — primary tool for SC#5 enforcement + D-09 inventory enumeration.
- `wc -l` + `grep -cE '^[[:space:]]*#'` — `14-METRICS.md` pre/post measurement.
- `task lint && task test && task install` — green-tree gate after every trim commit (matches Phase 13 D-Discretion green-tree definition).
- `shellcheck` (via `task lint:syntax`), `task lint:taskfile` (LINT-01..08) — confirm trim doesn't drop a comment whose absence would now violate a lint rule (LINT-08 banner-parity in particular, given TRIM-02 banner edits).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`CLAUDE.md` (project root)** is already the de-facto canonical reference for AI agents — it has Rules, Where-to-Add tables, Tooling Versions, and Don't-Do lists. D-06 promotes it to the explicit single home. The D-09 teaching gap-fill extends sections that already exist; no new top-level structure needed.
- **Phase 13 REVIEW.md defer rows are pre-built work tickets.** Plan 14 doesn't need to discover what to trim — REVIEW rows 41, 45, 46, 48, 49 (and possibly 28) name the exact targets with file:line. Treat them as inputs to Plan 14-02.
- **`taskfiles/lint.yml`'s LINT-08 (banner-parity)** already enforces a banner contract. After D-01/D-02 lock the new banner shape, LINT-08's fixtures (`08a-banner-parity-fail`, `08b-banner-parity-ok`) may need updating to match. Planner verifies.
- **`taskfiles/helpers.yml` is already lean** (103 lines, 27 comment lines, ~26%); useful as the reference for what a post-trim taskfile looks like.
- **The six-column table house style** (Phase 12 D-14, Phase 13 REVIEW.md) is the format for `14-METRICS.md` and `14-TEACHING-INVENTORY.md`. No new format invention; reuse.

### Established Patterns

- **Per-file commit discipline (Phase 11/12 D-04, Phase 13 D-Discretion):** each commit leaves `task lint && task test && task install` green. Plan 14's per-file trim approach (Claude's discretion recommendation) inherits this.
- **`git grep`-driven enforcement (Phase 11 RMV gate, Phase 13 D-08 dead-code verification):** SC#5's grep gate is the same pattern. The strip commit message lists the grep command + "0 matches in code" evidence.
- **Internal-by-default for new helpers (Phase 12, Phase 13 D-09):** TRIM-01 row-48 deferral mentions a possible `read_machine_state_file <path>` helper consolidating a 4-site idiom. If Plan 14-02 extracts it, the helper lands in `taskfiles/helpers.yml` with `internal: true` per the established pattern.
- **Six-column AUDIT/SURFACE table style (Phase 9, 12, 13):** `14-METRICS.md` columns `file | code_lines | comment_lines_pre | comment_lines_post | delta | %_reduction`; `14-TEACHING-INVENTORY.md` columns `file:line | snippet | lesson | covered by CLAUDE.md §X | NEEDS-ADD?`.

### Integration Points

- **`task install` pipeline** — TRIM-01 (inline comments) and TRIM-02 (banners) edit files in the install path. Smoke-test: run `task install` after each file's trim commit (or per-plan batch); should be a no-op idempotent re-run.
- **`task lint` aggregator** — LINT-01..08 enforcement runs every commit. LINT-08 banner-parity in particular needs to stay green; new banner shape may require LINT-08 fixture updates (a sub-commit within Plan 14-02 if needed).
- **`task test` (manifest fixtures + lint fixtures + hook smoke tests)** — must pass green. Fixture content with comments is its own surface; Plan 14-02 decides whether to trim fixture comments (recommendation: skip — fixtures are testing artifacts, not production code).
- **Claude Code's project-CLAUDE.md auto-discovery** — D-07 research gate. The session-loaded context shows the convention works (both files were loaded); planner verifies by reviewing Claude Code docs and/or a quick spike.
- **README.md ↔ CLAUDE.md cross-reference** — after dedup, README.md has a "Contributing / Conventions: see [CLAUDE.md](CLAUDE.md)" pointer; CLAUDE.md does not back-reference README (humans read README first; AI agents read CLAUDE.md first).
- **`.gitignore` entry for `.claude/CLAUDE.md`** — once deleted, the path is gone; no `.gitignore` entry needed (deletion is committed, not gitignored). Verify no `.gitignore` line currently points to it (likely not).

### Surface Inventory Snapshots

- Taskfiles total: 14 files (`Taskfile.yml` + 13 `taskfiles/*.yml`), 3,954 lines, ~1,476 comment lines (37%).
- Shell startup: 5 files (`shell/.z*`), 232 lines, ~232 comment lines (varies wildly per file; `.zlogout` is the outlier at 51/53).
- `install/*.zsh`: 5 files, ~1.2K lines.
- `os/defaults/*.zsh` + `os/shell-registration.zsh`: 7 files; banner pass applies.
- Repo-authored hooks under `claude/hooks/`: lib.zsh + per-hook scripts; banner pass + inline trim apply.
- `shell/functions/*.zsh`: 25 files (~570 lines, mostly minimal comments — D-08 Class A preserved; TRIM-02 banner pass applies, TRIM-01 mostly no-op).
- `shell/aliases/*.zsh`: 7 files (~170 lines, no banners today — TRIM-02 may add the 3-label banner where missing; TRIM-01 mostly no-op).
- Docs: 4 files in `docs/` (727 lines total).
- READMEs to dedup: `README.md` (79) + `CLAUDE.md` (187) + `.claude/CLAUDE.md` (125 — will be deleted) = 391 lines; post-trim target ≈ 220-260 lines split README/CLAUDE.md.

### Risk Surface

- **LINT-08 banner-parity contract** may break if the new banner shape isn't simultaneously enforced by an updated lint rule. Plan 14-02 either (a) updates LINT-08 + its fixtures to match D-01/D-02, or (b) deliberately keeps the banner-parity rule loose and validates via lint suite at the end. Planner picks; recommendation (a).
- **`task lint:taskfile` may flag comment-citation removals** if it expects certain `# LINT-NN:` annotations to exist. Verify the lint suite's expectations vs. D-04 rule (c) — citations are *kept*, so this should be a non-issue.
- **CLAUDE.md growth from D-09 gap-fills** may exceed practical AI-context loading sizes for some agents. Mitigate by keeping gap-fills terse (one paragraph per rule, not full chapters).
- **`.claude/CLAUDE.md` deletion in a session where the file is currently loaded** — the session that runs `git rm .claude/CLAUDE.md` will have the file in its loaded context. After the commit, next session loads only root CLAUDE.md. Verify zero downstream skills or commands hard-code the `.claude/CLAUDE.md` path (grep before delete).

</code_context>

<specifics>
## Specific Ideas

- **Banner shape template** (D-01/D-02/D-03 applied):
  ```yaml
  version: '3'

  # =============================================================================
  # taskfiles/links.yml -- symlink orchestration
  #
  # Purpose:      All symlink creation across shell/, identity/, configs/.
  # Depends on:   taskfiles/helpers.yml (_:safe-link, _:check-link).
  # Side effects: writes symlinks under $ZDOTDIR, $XDG_CONFIG_HOME, $HOME.
  # =============================================================================

  includes:
    _: ./helpers.yml
  ```
  (Single 77-char `# === ===` rule above and below; 3 labels; no mid-file separators; no narrative prose; no anti-pattern explainers.)

- **Three-test rule cheat-sheet** for D-04 (the planner can paste this into Plan 14-02's task body for reviewer alignment):
  ```
  KEEP a `#` comment iff at least one is true:
    (a) Explains a non-obvious WHY (the code doesn't reveal the rationale)
    (b) Warns about a still-live footgun (a real failure the next maintainer would re-introduce)
    (c) Cites a lint rule the code satisfies (e.g., `# LINT-02: template vars only in status:`)
  CUT otherwise:
    - Restatement-of-code ("# Set MACHINE to the value from manifest")
    - Section dividers inside files ("# === Vars block ===")
    - Planning-history annotations (# Phase N, # D-NN, # Gap N, # CR-NN, # WR-NN, # RESEARCH §X.Y)
    - Cross-references to other files for context only ("# same pattern as X.yml:42")
    - Anti-pattern teaching paragraphs longer than 3 lines (migrate per D-09)
  ```

- **`14-TEACHING-INVENTORY.md` row shape** (D-09):
  ```
  | file:line | snippet | lesson encoded | covered by | action |
  |-----------|---------|----------------|------------|--------|
  | taskfiles/links.yml:18-39 | "Status-block convention (LINT-02 enforcement)..." (22 lines) | $X in status: causes re-run; status uses {{.X}} only | CLAUDE.md §Rules > "status: block" | strip after Plan 14-01 |
  | shell/.zlogout:2-51 | "Examples / typical contents / safety notes..." (49 lines) | when zsh logout fires; what fc -W does | none (lesson is zsh tutorial content, not project rule) | strip; do not gap-fill (out of scope for CLAUDE.md) |
  ```

- **`14-METRICS.md` table shape** (SC#1 + Claude's discretion):
  ```
  | file | code_lines | comments_pre | comments_post | delta | % reduction |
  |------|-----------:|-------------:|--------------:|------:|------------:|
  | Taskfile.yml | 147 | 102 | 38 | -64 | 63% |
  | taskfiles/links.yml | 377 | 230 | 72 | -158 | 69% |
  | ... | ... | ... | ... | ... | ... |
  | **Total** | **3,954** | **1,476** | **TBD** | **TBD** | **TBD** |
  ```
  (Pre snapshot at Plan 14-02 start; post at Plan 14-02 close; aggregate row at bottom.)

- **CLAUDE.md amendment for D-01 contradiction resolution** (planner's first edit in Plan 14-01):
  Current line (project-root CLAUDE.md, §"Conventions Not Captured Above"):
  > File-level comment block at the top of every script explaining its purpose, callers, and side effects.

  Amend to:
  > File-level comment block at the top of every script: Purpose / Depends on / Side effects (3 labels; one `# === ===` 77-char rule above and below; no narrative prose, no examples).

- **TRIM-05 grep command** (the SC#5 gate exactly):
  ```bash
  git grep -E 'v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap' -- ':!.planning/'
  ```
  Must return zero lines. Planner runs this as Plan 14-03's closing assertion.

- **README.md humans-only shape** (D-06):
  ```
  # Dotfiles

  macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.

  ## Install
  ./bootstrap.zsh

  ## Common Tasks
  - task install   — install dotfiles for the active machine
  - task setup -- <machine-name>  — set the active machine
  - task validate  — validate full installation state
  - task test      — run all smoke tests
  - task lint      — run all lint checks

  ## Where things live
  (link to MANIFEST.md / MACHINES.md / SECURITY.md)

  ## Contributing
  See [CLAUDE.md](CLAUDE.md) for conventions, rules, and where-to-add tables.
  ```

</specifics>

<deferred>
## Deferred Ideas

- **Function-content audit / keep-or-cut for `shell/functions/*` + `shell/aliases/*`** — PROJECT.md "Future Requirements" + REQUIREMENTS.md §"Future Requirements" explicitly defer this past v2.1. Phase 14 trims their banners (TRIM-02, Claude's discretion) but does not audit their content.
- **Linux support** — REQUIREMENTS.md "Future Requirements"; defers. TRIM-05 does not preserve any "Linux branch" comments because there are none after Phase 13 (REVIEW row 32 closed in `ebccf47`).
- **Starship prompt swap** — REQUIREMENTS.md "Future Requirements"; defers. `shell/theme.zsh` banner gets trimmed (TRIM-02) but no theme-engine change.
- **Net-new lint rule for banner content** — if D-01/D-02 banner shape needs stricter enforcement than LINT-08's parity check, a new lint rule could enforce the 3-label vocabulary. Defer per Phase 13 D-11(b) (needs-new-infra); LINT-08 + planner review is the v2.1 gate.
- **Helper extraction for the 4-site "read first line + trim edges" idiom** (REVIEW row 48) — Phase 13 D-09 rule-of-three says 3+ occurrences extract; this idiom is at 4 sites. Plan 14-02 is the natural home if planner finds spare cycles; otherwise defers to a future cleanup phase per Phase 13 D-11(b).
- **DOTFILEDIR-leak architectural fix** (REVIEW row 28) — the long Taskfile.yml comment blocks explaining the `TASKFILE_DIR` workaround stay until the underlying var-rename happens across 8 taskfile includes. That's needs-new-infra-grade work and defers to a future phase. TRIM-01 applies the three-test rule to the comment blocks (they cite a still-live footgun under rule (b); likely kept).
- **`.claude/CLAUDE.md` deletion safety verification beyond a doc-spike** — if the spike surfaces ambiguity, a fuller test (run Claude Code in this repo with the file removed; confirm context loads correctly) defers to the planner's research step.
- **Automated drift gate for "README.md vs CLAUDE.md must not duplicate"** — SC#4 says `diff <(grep '^##' README.md) <(grep '^##' CLAUDE.md)` shows minimal overlap. Could become a `task lint:doc-dedup` rule; defer per Phase 13 D-11(b).
- **Per-tool config docs** (`configs/<tool>/README.md`) — if TRIM-03 surfaces a doc gap (e.g., `configs/ghostty/` has no README explaining its presence), defer to a per-tool documentation pass; do not creep into Phase 14.

</deferred>

---

*Phase: 14-comment-doc-trim*
*Context gathered: 2026-05-18*
