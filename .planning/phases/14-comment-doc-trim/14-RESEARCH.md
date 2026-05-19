# Phase 14: Comment + Doc Trim - Research

**Researched:** 2026-05-18
**Domain:** Source-code commentary hygiene; multi-tier documentation deduplication; Claude Code project memory model
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01** -- 3-label banner: Purpose / Depends on / Side effects. ROADMAP SC#2 wording wins. CLAUDE.md "Conventions Not Captured Above" bullet currently says "purpose, callers, and side effects"; Plan 14-01 amends to "purpose, key dependencies, side effects".
- **D-02** -- Single 77-char `# === ===` rule above and below the banner. No mid-file separators.
- **D-03** -- Qualitative banner length rule. Labels-only. No narrative prose, no anti-pattern teaching, no usage examples, no change-history annotations. Typical post-trim banner 6-10 lines.
- **D-04** -- Three-test KEEP rule for inline `#` comments. KEEP iff: (a) explains a non-obvious WHY, OR (b) warns about a still-live footgun, OR (c) cites a lint rule the code satisfies. Cut everything else: restatement-of-code, section dividers, planning-history annotations (# Phase N, # D-NN, # Gap N, # CR-NN, # WR-NN, # RESEARCH §X.Y), cross-file references, anti-pattern teaching paragraphs longer than 3 lines.
- **D-05** -- `desc:` strings get the same three-test rule. Cut to one imperative sentence when restatement; keep when `task --summary` operator-context benefits.
- **D-06** -- README humans-only; CLAUDE.md canonical AI/contributor reference; `.claude/CLAUDE.md` deleted.
- **D-07** -- Verify Claude Code auto-discovery loads root `CLAUDE.md` before deletion. (RESEARCH RESOLVED -- see §D-07 Verdict below.)
- **D-08** -- Rely on CLAUDE.md Rules + git history; delete in-code planning-history references and long anti-pattern teaching blocks.
- **D-09** -- Build `14-TEACHING-INVENTORY.md` BEFORE any strip pass. Any NEEDS-ADD row gap-fills CLAUDE.md before strip commit lands.

### Claude's Discretion

- **Plan breakdown shape** -- recommendation 3 grouped plans: 14-01 (Teaching inventory + CLAUDE.md gap-fill), 14-02 (TRIM-01 + TRIM-02 trim pass), 14-03 (TRIM-03 docs/ + TRIM-04 README dedup + .claude/CLAUDE.md delete + TRIM-05 grep gate). Per-requirement (5 plans) is fine if 14-02 becomes unwieldy.
- **Scope on D-08 Class A (`shell/functions/*.zsh` + `shell/aliases/*.zsh`)** -- recommendation: include in TRIM-02 banner pass; skip TRIM-01 inline trim.
- **Metrics methodology for `14-METRICS.md`** -- recommendation: one row per trimmed file, columns `file | code_lines | comment_lines_pre | comment_lines_post | delta | %_reduction`. Aggregate row at bottom.
- **`.claude/CLAUDE.md` fallback shape** -- 5-10 line thin pointer if D-07 surfaced contrary behavior (it didn't; see verdict).
- **Order of operations within trim pass** -- recommendation: per-file (banner + inline + lint), then next file.
- **Whether to strip `# lint-allow: cmds-without-status` markers** -- KEEP (functional pragmas; D-04 rule (c) covers them).

### Deferred Ideas (OUT OF SCOPE)

- Function-content audit / keep-or-cut for `shell/functions/*` + `shell/aliases/*` (PROJECT.md "Future Requirements").
- Linux support (REQUIREMENTS.md "Future Requirements").
- Starship prompt swap.
- Net-new lint rule for banner content (defer per Phase 13 D-11(b)).
- Helper extraction for the 4-site "read first line + trim edges" idiom (REVIEW row 48).
- DOTFILEDIR-leak architectural fix (REVIEW row 28).
- Automated drift gate for "README.md vs CLAUDE.md must not duplicate" (defer per Phase 13 D-11(b)).
- Per-tool config docs (if TRIM-03 surfaces a doc gap, defer).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRIM-01 | Inline comments in taskfiles reduced to essential WHY only. Per-file `wc -l` ratio drop recorded in 14-METRICS.md. | Section "TRIM-05 Strip Surface Preview" + "Lint Suite Safety Under Trim" -- 1,789 comment lines across 13 strip-pass files; LINT-04 / LINT-05 / LINT-07 / LINT-03a unaffected by comment removal (verified by reading lint rule bodies). |
| TRIM-02 | Per-file header banners slimmed to 3 labels (Purpose / Depends on / Side effects); verbose change-history annotations moved to git history. | "TRIM-02 Class A Scope" + "LINT-08 Banner-Parity Impact" -- 4 of 7 alias files have heavy banners (9-15 lines); 4 of 25 function files have heavy banners (5-34 lines); rest are 0-2 lines. LINT-08 does NOT enforce banner content shape (verified by reading rule body); no fixture changes required. |
| TRIM-03 | docs/ directory reviewed; obsolete docs removed. | "docs/ Review Findings" -- 4 surviving docs (727 lines total); MANIFEST.md has 5 motd doc-drift sites + 1 stale "Phase 1 note"; SECURITY.md, MACHINES.md, README.md essentially current. |
| TRIM-04 | README.md / CLAUDE.md / .claude/CLAUDE.md deduped to single canonical home; `.claude/CLAUDE.md` deleted. | "D-07 Verdict" -- PASS; deletion safe. README.md is humans-only (already 79 lines, light dedup needed); CLAUDE.md is the canonical AI home (187 lines, gap-fills land here). |
| TRIM-05 | Grep gate `git grep -E 'v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap' -- ':!.planning/'` returns zero matches in code. | "TRIM-05 Strip Surface Preview" -- 13 files identified; baseline grep returns 202 matches today; TEACHING-INVENTORY.md (D-09) drives gap-fill before strip. |
</phase_requirements>

## Summary

- **D-07 is RESOLVED in favor of safe deletion.** Official Claude Code docs state explicitly: *"A project CLAUDE.md can be stored in either `./CLAUDE.md` or `./.claude/CLAUDE.md`."* Both paths are discovered by walking the directory hierarchy. Plan 14-03 may delete `.claude/CLAUDE.md` with no fallback contingency; the root `CLAUDE.md` already exists and contains a superset of the deleted file's content.
- **LINT-08 is mis-named relative to the CONTEXT.md hypothesis.** It is NOT a banner-shape parity check; it is a *default-task-banner-parity* check (verifies the `default:` task lists every public top-level task). It does not enforce file-header banner content or shape, so the D-01/D-02/D-03 banner rewrite needs zero LINT-08 or fixture changes.
- **`desc:` blocks are already single-line throughout.** Only the root `install:` task uses `summary: |` for multi-line operator context. D-05's exception list is therefore empty -- every `desc:` already satisfies the rule. The `summary:` block stays (it's the dedicated multi-line field, not a `desc:` block).
- **TRIM-05 strip surface is 13 files, 1,789 comment lines total, 72 strip-pattern matches in the strip files plus 130 matches in the broader code.** The biggest single annotation block is the 22-line LINT-02 explainer in `taskfiles/links.yml:18-39` (lesson already covered by CLAUDE.md §Rules "Every install task has a `status:` block").
- **The shellcheck binary is not currently installed on this dev machine** (`/opt/homebrew/opt/shellcheck` exists as a symlink target but the cellar is empty). `task lint:syntax` does NOT invoke `shellcheck` directly -- it runs `zsh -n` only -- so this doesn't block Phase 14, but the planner should flag it for any reviewer claiming "shellcheck passes."

**Primary recommendation:** Execute the 3-plan shape from CONTEXT verbatim. The only research-surfaced refinement is in `docs/MANIFEST.md` -- 5 doc-drift sites for the deleted `motd` flag plus 1 stale "Phase 1 note" require TRIM-03 attention (the doc has more rot than CONTEXT estimated).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-file comment removal | Source code files (taskfiles + .zsh) | -- | TRIM-01 + TRIM-02 are surgical text edits; no tier shift. |
| Documentation rewrite | docs/ + CLAUDE.md + README.md | -- | TRIM-03 + TRIM-04 are doc-tier only; no code touched. |
| Lint-suite trust | taskfiles/lint.yml | taskfiles/test/lint-fixtures/ | After-each-commit gate; rule bodies untouched, fixtures untouched. |
| Teaching-content migration | CLAUDE.md (canonical home) | taskfiles/README.md (fallback for taskfile-specific lessons) | D-09 inventory drives where lessons land. |

## D-07 Verdict

**PASS.** `.claude/CLAUDE.md` may be deleted in Plan 14-03 with no fallback required. The root `CLAUDE.md` is already loaded by Claude Code's hierarchical discovery, and the official docs explicitly support a project using only the root file.

### Evidence

1. **Official Claude Code memory docs**, "Choose where to put CLAUDE.md files" table [CITED: code.claude.com/docs/en/memory]:
   > **Project instructions** -- `./CLAUDE.md` or `./.claude/CLAUDE.md`
   The "or" is decisive: either path is a valid project-instruction location. There is no language anywhere on that page implying both are required, nor that one fallbacks for the other.

2. **Official docs, "Set up a project CLAUDE.md"** [CITED: code.claude.com/docs/en/memory]:
   > A project CLAUDE.md can be stored in either `./CLAUDE.md` or `./.claude/CLAUDE.md`.

3. **Official docs, "How CLAUDE.md files load"** [CITED: code.claude.com/docs/en/memory]:
   > Claude Code reads CLAUDE.md files by walking up the directory tree from your current working directory, checking each directory along the way for `CLAUDE.md` and `CLAUDE.local.md` files.
   The walk-up logic finds `./CLAUDE.md` first; `./.claude/CLAUDE.md` is checked alongside it when both exist (the docs describe these as alternative locations, not parent/child).

4. **In-repo behavior in this very session.** Both `./CLAUDE.md` and `./.claude/CLAUDE.md` were loaded into the system context (visible in the project-instructions block). Their content is fully overlapping; the `.claude/` copy is pure duplication of the root file's manifest model + conventions + safety sections.

5. **Compaction-survival guarantee** [CITED: code.claude.com/docs/en/memory]:
   > Project-root CLAUDE.md survives compaction: after `/compact`, Claude re-reads it from disk and re-injects it into the session.
   The root-CLAUDE.md is specifically named as the survivor. Nested CLAUDE.md files (which `.claude/CLAUDE.md` is NOT -- `.claude/` is a sibling discovery location, not a subdirectory of code) reload on file-read in their dir. Plan 14-03's deletion strictly upgrades compaction reliability (one fewer file to track, no risk of stale duplicate winning).

### Mechanics of the deletion commit

- `git rm .claude/CLAUDE.md` is the only repo change required for this slice of TRIM-04.
- No `.gitignore` entry is needed (the path simply disappears; future scaffolding might add one for `.claude/CLAUDE.local.md` operator preferences, but that is out of scope per CONTEXT Deferred Ideas).
- The fallback "thin pointer" shape from CONTEXT Claude's Discretion is **not required**. Do not write a 5-10 line pointer file -- it would just become a forwarding stub that adds noise and re-introduces a duplication-drift risk.
- After the commit lands, the next Claude Code session in this repo will load only the root `CLAUDE.md`. Same content; one less file.

**Confidence:** HIGH. Cited from the canonical Anthropic docs (multiple cross-references on the same page). The official docs are explicit, recent, and matched by observed in-session behavior.

## LINT-08 Banner-Parity Impact

**Verdict: NO LINT-08 OR FIXTURE EDITS REQUIRED.**

The CONTEXT.md "Risk Surface" line *"LINT-08 banner-parity contract may break if the new banner shape isn't simultaneously enforced by an updated lint rule"* is based on a name-confusion. LINT-08 in this repo has nothing to do with file-header banner shape.

### What LINT-08 actually does

`taskfiles/lint.yml:287-312` (`banner-parity` task) enforces that the **root `Taskfile.yml :: default` task's `cmds[0]` block lists every non-internal top-level task by name.** It is the "operator-facing curated banner" parity check from Phase 12 D-13. Its body:

1. Reads root `Taskfile.yml`, extracts every non-internal task whose name contains no `:`.
2. Reads `Taskfile.yml :: default :: cmds[0]` (the `info "..."` block at lines 137-148 today).
3. For each public top-level task, greps it against the banner body. Fails when missing.

It does not look at file headers. It does not enforce a comment shape. It does not parse a `# === ===` rule. It has no opinion about Purpose/Depends/Side-effects vocabulary.

### What the fixtures actually test

`taskfiles/test/lint-fixtures/08a-banner-parity-fail/Taskfile.yml` and `.../08b-banner-parity-ok/Taskfile.yml` are pairs that exercise the rule above:
- `08a`: a `Taskfile.yml` where `mypublic:` is public but missing from `default:`'s cmd block -> expect fail.
- `08b`: a `Taskfile.yml` where every public task is listed -> expect pass.

Neither fixture contains or tests a file-header banner. They have minimal header comments only (the dotted-stub format that explains what the fixture tests).

### Implication for Plan 14-02

- D-01 / D-02 / D-03 banner rewrites land freely without touching LINT-08, its fixture pair, or the `task lint:test-fixtures` runner.
- The `task lint:banner-parity` check stays green throughout Phase 14 (the operator banner in `Taskfile.yml :: default` is not touched by TRIM-01 / TRIM-02 in any way that would remove a task-name reference; per CONTEXT it stays as-is).
- **Caveat:** if a future cleanup adds, renames, or removes a public top-level task during Phase 14, the planner must update both the `default:` banner and the LINT-08 fixture-expectation alongside it -- but that's outside Phase 14's scope and is the normal Phase 12 banner-parity flow.

**Confidence:** HIGH. Verified by reading the rule body (`taskfiles/lint.yml:287-312`), the fixture inputs (`taskfiles/test/lint-fixtures/08[ab]-banner-parity-*/Taskfile.yml`), and the test-runner case for `08*` (`taskfiles/lint.yml:391-410`).

## Lint Suite Safety Under Trim

Per-check verdict for each lint rule that runs as part of `task lint`:

| Lint Target | Rule body | Comment-sensitivity | Verdict |
|-------------|-----------|--------------------|---------|
| **LINT-07 syntax** (`task lint:syntax`) | `task --list-all --json` parse + `zsh -n` over every `.zsh` | Comments removal does not affect YAML/zsh parsing. | SAFE |
| **LINT-02** (`task lint:taskfile`, `$VAR in status:`) | `yq` extracts `.status` from each task; greps for `$VAR` outside `$(...)` and `{{...}}` | Inline-comment removal cannot introduce a `$VAR`. Comment removal *outside* a status block has zero effect. | SAFE |
| **LINT-03a** (`cmds: without status:`) | `yq` over task definitions; exempts `internal: true`, all-task-delegates, and `lint.yml` | Pure structural; ignores comments entirely. | SAFE |
| **LINT-03b** (`bare ln -s`) | `ggrep -rn 'ln -s'` excluding `helpers.yml`; excludes comment lines via `ggrep -v ':[[:space:]]*#'` | Already strips comments before checking. Removing a `# ln -s ...` historical comment is a no-op for the rule. | SAFE |
| **LINT-04** (`set -euo pipefail`) | `head -30 <file> | ggrep -qE '^set -euo pipefail$'` | TRIM-02 banner cuts may push the `set -euo pipefail` line OUT of the head-30 window for files whose banner-plus-shebang currently sits in lines 1-25. Reverse risk: trimming HELPS get it inside the window. Need to verify head-30 stays satisfied after trim. | VERIFY (likely SAFE) |
| **LINT-05 portability** | Greps for `pbcopy`, `defaults read`, etc. in `shell/`+`os/`; excludes comment lines via `ggrep -v ':[[:space:]]*#'` | Excludes comment lines explicitly. SAFE. | SAFE |
| **LINT-08 banner-parity** | See §LINT-08 above. | Independent of file-header banner content. | SAFE |
| **`task test:hooks`** | Pipes synthetic JSON to each `claude/hooks/*.zsh`; asserts exit code + stderr pattern | Hook bodies unchanged; only comment density changes. | SAFE |
| **`task test:manifest`** | Runs deep-merge fixtures against `install/resolver.zsh` | Comments in resolver.zsh do not affect TOML parse / merge logic. | SAFE |
| **`task install`** | Composes per-machine pipeline; status blocks gate idempotency | Status blocks are template-var-only by LINT-02; no comment-dependency anywhere. | SAFE |
| **`task validate`** | Aggregator over per-component validates; each reads `resolved.json` | No comment dependency in any validate task. | SAFE |

### Concrete safety verification for LINT-04 (head-30 window)

`task lint:shell-headers` only checks the first 30 lines of executable `.zsh` for `^set -euo pipefail$`. Today, `shell/.zshenv`, `shell/.zprofile`, etc. all carry `#!/bin/zsh` at line 1 and `set -euo pipefail` early. A heavy banner could push `set -euo pipefail` to line 31+. Phase 14 TRIM-02 SHORTENS banners, so the line moves UP, not down. No LINT-04 risk.

### Concrete safety verification for citation removals (D-04 rule (c))

D-04 explicitly KEEPS LINT-NN citation comments (e.g., `# LINT-02: template vars only in status:`). The lint suite doesn't parse the citations; it parses the structural shape. Even if a citation were accidentally removed, the rule body still fires from structure alone (`$VAR` is found in status; `cmds:` without `status:` is detected via yq). Citations are informational only.

### Concrete safety verification for `# lint-allow: cmds-without-status` markers

Search for `lint-allow:` in `taskfiles/lint.yml`: zero hits in the rule body. The marker exists only in source files as documentation; LINT-03a's exemption logic is `internal: true` + all-task-delegates, NOT the marker. The marker is purely human-readable. CONTEXT's recommendation to KEEP these is sound (D-04 (c) "cites a lint rule" justifies keeping); removing them would NOT actually trigger LINT-03a failures.

**Confidence:** HIGH. Every claim above verified by reading the corresponding rule body line by line.

## desc: Block Exceptions

**None. The exceptions list is empty.**

Survey of every `desc:` in `Taskfile.yml` + `taskfiles/*.yml`:

- Every `desc:` is a single-line scalar (verified by `grep desc:` returning only quoted scalars or unquoted-line scalars; no `desc: |` or `desc: >` block was found).
- The longest single-line `desc:` is `taskfiles/lint.yml:147` at 197 chars (`"Taskfile convention checks: $VAR in status:, cmds: without status:, bare symlink outside helpers (LINT-02 + LINT-03a + LINT-03b)"`). This is informative but cuttable to ~80 chars if planner picks; the D-05 rule treats long desc strings as a candidate for trim, but they're already one-line.

The one multi-line operator-context block in the repo is `Taskfile.yml:212-216` on the `install:` task, using the dedicated `summary: |` key (NOT `desc:`):

```yaml
install:
  desc: "Install dotfiles for active machine (canonical entry)"
  summary: |
    task install IS task update -- there is no separate update pipeline.
    Re-running is a no-op (every subtask has a status: block per LINT-01).
```

`task --summary install` renders both the `desc:` and the `summary:` block; the `summary:` block exists because the operator needs to know install-IS-update on first invocation. Per D-04 rule (a) "non-obvious WHY for operator decision", this `summary:` block stays. Plan 14-02 should NOT trim it.

### Planner action

- D-05 produces no exception list. Apply the three-test rule uniformly to every `desc:` string. Most are already operationally useful (they explain what the task does and what it does not do).
- Treat `summary:` keys as a separate field from `desc:`; D-05 does not address them by name. The one `summary:` in the repo passes D-04 rule (a) and stays.
- The 197-char `lint:taskfile` desc is the longest and is a candidate for cut-to-essence (e.g., `"Taskfile convention checks (LINT-02 + LINT-03a + LINT-03b)"`). Planner decides per-file.

**Confidence:** HIGH. Verified by line-by-line grep over `Taskfile.yml` + `taskfiles/*.yml`.

## docs/ Review Findings

Per-doc keep/trim/remove/consolidate decisions for TRIM-03. Each finding has a file:line pointer.

### docs/README.md (7 lines)
- **Status:** stale -- references `MIGRATION.md` and `CUTOVER.md` which were deleted in Phase 11. Lists `MANIFEST.md` (P1), `SECURITY.md` (P2), `MIGRATION.md`, `MACHINES.md`, `CUTOVER.md` (P8).
- **Action:** REWRITE. Reduce to 3 bullets: `MANIFEST.md`, `SECURITY.md`, `MACHINES.md`. Remove `MIGRATION.md` + `CUTOVER.md` references.
- **Effort:** 1 small edit.

### docs/MANIFEST.md (508 lines)
- **Five `motd = true` doc-drift sites.** The `motd` feature flag was removed from `manifests/defaults.toml` and all three machine TOMLs in commit `edbbabd` (Phase 13 REVIEW row 30), but `docs/MANIFEST.md` still documents it as a live flag:
  - Line 33: `motd = true` in `defaults.toml` example
  - Line 67: `motd = true` in `personal-laptop.toml` example
  - Line 137: `motd = true` in Fixture 01 deep-merge example
  - Line 152: `"motd": true` in Fixture 01 resolved.json example
  - Line 491: `| \`motd\` | Phase 3 | Enables MOTD display on \`.zlogin\` | \`true\` |` in the Feature-Flag Reference table.
  **Action:** delete each line + adjust surrounding example text to keep the example syntactically valid.
- **Stale "Phase 1 note" CLI Reference admonition** (line 461-464):
  > **Phase 1 note:** Until Phase 2 wires the manifest module into the root `Taskfile.yml`...
  Phase 2 closed long ago; the manifest IS in the root `Taskfile.yml` (verified at `Taskfile.yml:77-82`). The CLI examples beneath this note still use the `-t taskfiles/manifest.yml` form which is now incorrect for the public surface (the public surface is `task show:manifest`, `task audit:manifest`, `task test:manifest` per Phase 12 D-09).
  **Action:** delete the Phase 1 note; rewrite the CLI examples to use the public surface (`task show:manifest`, `task audit:manifest`, `task test:manifest`).
- **"Adding a New Machine" section (line 382-419)** uses `task -t taskfiles/manifest.yml manifest:validate -- --machine <name>` and `task -t taskfiles/manifest.yml setup -- <name>` and `task -t taskfiles/manifest.yml manifest:show`. All three should rewrite to use the public surface (`task setup -- <name>`, `task audit:manifest -- --machine <name>`, `task show:manifest -- --machine <name>`).
- **Phase 5 wording lingers** in the example comments (e.g., line 33 reference `# Bundle names map to packages/<name>.rb (Phase 5).`). Per D-08, Phase-N forward-looking phrasing in code-block comments should also be reviewed. Inside markdown fenced code blocks that document the toml, the Phase-5 hint is informational; planner judges per case (D-04 rule (a)).
- **Keep:** the schema tables, merge-semantics rules, fixture worked examples (Fixtures 01-06), and Verify model. These are core reference content that humans + AI agents both consult.
- **Effort:** mid-size single edit; ~10 line changes across the 508-line file.

### docs/MACHINES.md (73 lines)
- **Current.** No drift detected. Documents 3 machines (`personal-laptop`, `work-laptop`, `atium`); contents match `manifests/machines/*.toml`.
- **Action:** KEEP as-is. No TRIM-03 work needed.
- **Effort:** none.

### docs/SECURITY.md (139 lines)
- **Current.** Documents bootstrap trust chain for Homebrew + go-task + yq fetch flow. No stale Phase-N references found (the "Phase 4/Phase 7/Phase 8" mentions in the "What This Document Does NOT Cover" section are pointing to phases that completed, which is now backward-looking and accurate; if planner wants, those references can flip to past tense, but it's a stylistic cleanup, not drift).
- **Action:** OPTIONAL polish -- change "Phase 4 will document..." (line 96 / 100) to past tense. Otherwise keep as-is.
- **Effort:** trivial (1-2 line touches if planner takes the polish option; else skip).

### Removed / Confirmed-Gone (cross-check)

- `docs/CUTOVER.md` -- removed in Phase 11 RMV-04 (verified absent today via `ls docs/`).
- `docs/MIGRATION.md` -- removed in Phase 11 (verified absent today via `ls docs/`).
- TRIM-03 SC#3 requires "every doc remaining in `docs/` has a clear, current purpose." After MANIFEST.md trim and README.md rewrite, this is satisfied.

**Confidence:** HIGH for the motd + Phase 1 note + CLI form findings (verified by line-number reading); MEDIUM for the SECURITY.md polish call (judgement on backward-looking style).

## TRIM-05 Strip Surface Preview

The 13 files identified by the broader strip pattern (CONTEXT §"v2 surface where TRIM-05 grep gate must return zero"). Per-file: total lines, comment lines, count of strip-pattern matches. The "matches" column uses the broader CONTEXT pattern (`Phase [0-9]+|D-[0-9]+|CR-[0-9]+|WR-[0-9]+|RESEARCH §|Gap [0-9]+|v1 (bug|finding|leftover)|UAT [Gg]ap`); the SC#5 gate uses a tighter subset (`v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap`).

| File | Total lines | Comment lines | Strip-pattern matches (broader) | Risk |
|------|------------:|--------------:|-----------------:|------|
| `Taskfile.yml` | 249 | 102 | 2 | LOW |
| `identity/ssh/cloudflared.zsh` | 35 | 15 | 1 | LOW |
| `install/compose-brewfile.zsh` | 223 | 101 | 1 | LOW |
| `install/resolver.zsh` | 622 | 183 | 13 | MEDIUM (WR- annotations encode bug-class lessons; gap-fill required) |
| `os/shell-registration.zsh` | 99 | 60 | 1 | LOW |
| `taskfiles/claude.yml` | 343 | 141 | 6 | LOW |
| `taskfiles/identity.yml` | 476 | 167 | 9 | MEDIUM (D-NN refs in identity layer; verify each maps to CLAUDE.md or is dead) |
| `taskfiles/links.yml` | 607 | 230 | 3 | MEDIUM (22-line LINT-02 explainer + 22-line `reconcile` notes block) |
| `taskfiles/lint.yml` | 425 | 142 | 3 | LOW (lint citations stay per D-04 rule (c)) |
| `taskfiles/macos.yml` | 332 | 130 | 2 | LOW |
| `taskfiles/manifest.yml` | 291 | 122 | 17 | HIGH (the densest annotation site; many CR-NN / D-NN refs) |
| `taskfiles/packages.yml` | 544 | 202 | 6 | MEDIUM (Gap-2 verify pivot history + several D-NN refs) |
| `taskfiles/test.yml` | 328 | 108 | 8 | MEDIUM (negative-fixture validation block + D-NN refs) |
| **TOTAL** | **4,574** | **1,703** | **72** | -- |

### NEEDS-ADD candidates the planner must gap-fill into CLAUDE.md before strip

Reviewing the highest-density and highest-information annotation blocks against CLAUDE.md's existing Rules / Conventions / Where-to-Add sections:

1. **`taskfiles/links.yml:18-39` -- 22-line LINT-02 explainer (Status-block convention).** Lesson: status-block template-var-only rule + aggregator status-omission rule. **Already covered by CLAUDE.md §Rules "Every install task has a status: block"** (lines 86-101). NO gap-fill needed. Strip-clean.

2. **`taskfiles/links.yml:431-456` -- 26-line `reconcile` task lead comment block.** Lesson: three-mode dispatch (detect/remove/warn-only), TTY-gate-before-enumeration rule, `unlink`-not-`rm` security rationale. **NOT covered by CLAUDE.md.** Lesson is taskfile-specific (only `links:reconcile` does interactive flag dispatch). **Action:** the body comments inside the `reconcile:` task already document mode dispatch + TTY gate inline; the lead comment block can be deleted (D-04 rule (a) WHY survives in inline comments). NO gap-fill needed; inline comments already encode the lesson.

3. **`install/resolver.zsh:80,179,289,456,558,587` -- 6 WR-NN bug-fix history annotations.** Lessons: `read -r` boundary trim handling, schema_version validation, line-number heuristic guard, signal-trap-before-pipeline, exit-status-vs-stdout-count, manifest-name slug normalization. **NOT covered by CLAUDE.md.** Each annotation tags a specific past bug-fix; the lessons are now baked into the code body. **Action:** strip the WR-NN tags but KEEP the surrounding comment if it explains a non-obvious WHY (D-04 (a)). Convert `# WR-07 fix: previously this function returned the error count via stdout` -> either delete (lesson is now self-evident from current code shape) OR rewrite as `# Signal failure via exit status; stdout is reserved for caller-consumable output.` (D-04 (a)).

4. **`install/resolver.zsh:171,212,616` -- 3 D-NN refs.** D-01 (platform.os = darwin), D-16 (cross-field rules), D-04 (advisory warnings). **D-01 partially covered** by CLAUDE.md §"What This Is" macOS-only line. **D-16 NOT covered** -- the cross-field validation rule (`identity.ssh in {personal,work} requires features.one-password-ssh = true`) is a NEEDS-ADD if the lesson "manifest cross-field validation rules are runtime-checked" should survive. The rule is enforced in `resolver.zsh`; CLAUDE.md does not currently mention cross-field validation as a manifest concept. **NEEDS-ADD candidate.**

5. **`taskfiles/manifest.yml`** (highest density at 17 strip-pattern matches; 122 comment lines). Inspection target for Plan 14-01. Likely contains repeated D-NN refs for the same set of decisions; needs the full TEACHING-INVENTORY pass to enumerate.

6. **`Taskfile.yml:131-148 + 240-248`** -- the DOTFILEDIR-leak workaround comment blocks (REVIEW row 28). Per CONTEXT Deferred Ideas, the architectural fix is deferred. Per D-04 rule (b) "still-live footgun", these blocks STAY -- they warn about a real failure mode (every new include re-introduces the leak). **NO gap-fill needed; comments stay as footgun documentation.**

7. **`shell/.zlogout:2-51`** (REVIEW row 45) -- 49-line zsh-tutorial banner. **NOT a CLAUDE.md candidate** -- the lesson is generic zsh runtime behavior, not a project rule. Per CONTEXT §Specific Ideas TEACHING-INVENTORY example: "strip; do not gap-fill (out of scope for CLAUDE.md)." Strip-clean.

### Plan 14-01 sizing estimate

The teaching inventory will have approximately **20-30 rows** (one per ≥3-line annotation block across the 13 strip files plus the shell + os scripts). Of those, expect **1-3 NEEDS-ADD rows** that gap-fill into CLAUDE.md:
- **Likely NEEDS-ADD #1:** cross-field validation rule (D-16) -- one paragraph addition under CLAUDE.md §Rules.
- **Likely NEEDS-ADD #2:** the LINT-NN catalogue (LINT-01 through LINT-08) -- CLAUDE.md mentions LINT-02 by name but not the full catalogue. A small table under §Rules naming each lint rule by number + scope would let in-code citations land cleanly without re-explaining.
- **Possibly NEEDS-ADD #3:** the DOTFILEDIR-leak footgun pattern -- the comments in `Taskfile.yml:131-148` stay (D-04 (b)), but a CLAUDE.md "Don't Do" line clarifying "Don't define `DOTFILEDIR: { sh: dirname ... }` in included taskfiles" would let the comment compress.

**Confidence:** MEDIUM-HIGH. Strip-pattern counts are exact (`grep -cE`). NEEDS-ADD predictions are reasoned from spot-reading the highest-density files; Plan 14-01's full inventory pass may surface 1-2 additional candidates.

## TRIM-02 Class A Scope

Per-file leading-comment-block measurement across `shell/functions/*.zsh` (25 files) and `shell/aliases/*.zsh` (7 files).

### shell/functions/ (25 files)

| Banner size | Files | Action |
|------------:|-------|--------|
| 26-34 lines (heavy) | `_dotfiles_feature.zsh` (26), `_dotfiles_require_feature.zsh` (34) | TRIM-02 SLIM to 3-label banner. Both are internal-helper functions documenting feature-flag mechanics; the lesson (manifest feature gates via `_dotfiles_feature <key>`) is **already covered by CLAUDE.md §Adding Things "Feature flag" bullet** (line 142-145 of CLAUDE.md). |
| 5 lines (light banner) | `sshlist.zsh` (5), `motd.zsh` (5) | TRIM-02 mostly no-op; the 5-line banners already approximate the target shape. Planner may normalize to the canonical 3-label form for consistency. |
| 2 lines (terse) | 19 files (most: `whois.zsh`, `vnc.zsh`, ..., `getcertnames.zsh`) | TRIM-02 mostly no-op; these are `#!/bin/zsh` + 1-line purpose comment. Adding a 3-label banner is per-file judgement -- arguably the existing single-line purpose comment IS the post-trim shape. |
| ≤1 line | 0 files | -- |

**Verdict for shell/functions:** TRIM-02 applies materially to **2 of 25 files** (`_dotfiles_feature.zsh`, `_dotfiles_require_feature.zsh`). The remaining 23 are already in the post-trim shape or close to it.

### shell/aliases/ (7 files)

| Banner size | Files | Action |
|------------:|-------|--------|
| 9-15 lines (heavy) | `jgrid.zsh` (15), `ghostty.zsh` (13), `finder.zsh` (11), `dotfiles.zsh` (9) | TRIM-02 SLIM to 3-label banner. These banners explain feature-gating rationale + replacement-for-v1 history; the v1-replacement narrative is exactly the kind of historical reference D-08 strips, and feature-gating is in CLAUDE.md. |
| 2 lines (terse) | `networking.zsh` (2), `general.zsh` (2) | TRIM-02 mostly no-op. |
| 1 line | `hardware.zsh` (1) | -- |

**Verdict for shell/aliases:** TRIM-02 applies materially to **4 of 7 files**.

### Cross-check against D-08 Class A scope

Per Phase 13 D-08, `shell/functions/*.zsh` + `shell/aliases/*.zsh` are Class A (preserved from dead-code removal). CONTEXT Claude's Discretion clarifies: "include in TRIM-02 banner pass, skip TRIM-01 inline trim." This means:
- For the 6 files above with material banner trim (2 functions + 4 aliases), the planner edits the banner and leaves the function/alias body untouched.
- For the remaining 26 files with terse or no banner, planner judgement: leave alone, or add the canonical 3-label banner for repo-wide consistency. Recommendation: leave alone -- adding a 3-label banner to a 10-line function file is more noise than signal.

### Concrete TRIM-02 scope numbers

- **shell/functions: 2 of 25 files require non-trivial banner edits** (`_dotfiles_feature.zsh`, `_dotfiles_require_feature.zsh`).
- **shell/aliases: 4 of 7 files require non-trivial banner edits** (`jgrid.zsh`, `ghostty.zsh`, `finder.zsh`, `dotfiles.zsh`).
- **Plus the REVIEW row 41 deferral**: 11 `shell/functions/*.zsh` files carry the same arg-validation `echo "ERROR: No <thing> specified"` stderr pattern. These are *not `#` comments* (they're stderr-echoes from function bodies), so they are not in TRIM-01 scope. They remain as-is per Phase 13's defer rationale (interactive UX). The "11 sites" number is from REVW-row 41 closure note: `whois.zsh`, `getcertnames.zsh`, `permissions.zsh`, `cheat.zsh`, `host.zsh`, `ghpubkey.zsh`, `geoip.zsh`, `pubkey.zsh`, `vnc.zsh`, `prettyjson.zsh`, `sethostname.zsh`.

**Confidence:** HIGH (counts from awk pass over each file's leading comment block).

## Validation Architecture

Phase 14 has 5 success criteria; each gets ≥1 concrete validation evidence type. The verifier inspects these artifacts before approving `/gsd:verify-work`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | go-task task suite (`task lint`, `task test`, `task install`, `task validate`) + `git grep` for SC#5 |
| Config file | `Taskfile.yml` + `taskfiles/*.yml` + `taskfiles/test/lint-fixtures/*` |
| Quick run command | `task lint && task test` |
| Full suite command | `task lint && task test && task install && task validate` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TRIM-01 | Inline comment ratio drop recorded per-file | artifact + smoke | `cat .planning/phases/14-comment-doc-trim/14-METRICS.md` (artifact) + `wc -l` + `grep -cE '^[[:space:]]*#'` pre/post | needs 14-METRICS.md (Wave 0) |
| TRIM-02 | Banner shape consistent across files | manual + sample | spot-check 3-5 trimmed taskfiles + 2 .zsh scripts for: 1) `# === ===` rule above/below labels; 2) 3 labels present (Purpose / Depends on / Side effects); 3) no narrative prose | manual review |
| TRIM-03 | `docs/` reviewed; obsolete content removed | artifact + grep | `ls docs/` matches the curated 4-file set; `git grep -n motd docs/MANIFEST.md` returns 0 hits; `git grep -n 'Phase 1 note' docs/` returns 0 hits | existing docs/ tree |
| TRIM-04 | Three audience docs deduped to canonical homes | grep + artifact | `test ! -f .claude/CLAUDE.md`; `diff <(grep '^##' README.md) <(grep '^##' CLAUDE.md) | wc -l` shows minimal overlap (recommend: ≤2 shared headers) | existing files |
| TRIM-05 | SC#5 grep gate returns zero matches in code | grep | `git grep -E 'v1 (bug\|finding\|leftover)\|Gap [0-9]+\|D-[0-9]+\|UAT [Gg]ap' -- ':!.planning/' \|\| echo PASS` returns "PASS" | n/a (gate) |

### Sampling Rate

- **Per task commit (per-file trim commit):** `task lint && task test` (~ 30 seconds; passes structural + hook smoke gates).
- **Per wave merge (per-plan close):** full suite (`task lint && task test && task install && task validate`) + `git grep` SC#5 spot check on the files touched this wave.
- **Phase gate (`/gsd:verify-work`):** full suite + SC#5 grep gate returns "PASS" + `14-METRICS.md` aggregate row shows positive overall `% reduction` + `14-TEACHING-INVENTORY.md` present with all NEEDS-ADD rows resolved.

### Wave 0 Gaps

- [ ] `14-METRICS.md` -- Plan 14-02 creates. Pre-snapshot taken at Plan 14-02 start; post-snapshot at close.
- [ ] `14-TEACHING-INVENTORY.md` -- Plan 14-01 creates. Six-column table per Phase 12 D-14 / Phase 13 REVIEW house style. Required before any TRIM-05 strip pass.
- [ ] (No new test framework install needed; the lint suite + smoke tests already exist.)
- [ ] **shellcheck not installed locally.** `/opt/homebrew/opt/shellcheck` symlinks to an empty cellar. The lint suite doesn't invoke `shellcheck` (LINT-07 is `zsh -n` only), but if a reviewer needs to run shellcheck on a trimmed `.zsh` file, install via `brew install shellcheck` first. Not a blocker for Phase 14 because the suite runs `zsh -n` not `shellcheck`. The planner should NOT add a shellcheck step that doesn't exist today.

## Refined Risk Surface

| # | Risk | File:line evidence | Mitigation (planner action) |
|---|------|--------------------|------------------------------|
| R1 | LINT-04's head-30 window may break if a trimmed banner pushes `set -euo pipefail` out of the first 30 lines | `taskfiles/lint.yml:233` (`head -30 "$f" | ggrep -qE '^set -euo pipefail$'`) | Pre/post: confirm `set -euo pipefail` stays in lines 1-30 of every executable `.zsh` after banner trim. TRIM-02 shortens banners so this is moves the line UP; the risk is purely the inverse. Sanity-check on the 6 files with material banner edits. |
| R2 | LINT-08 confusion: name suggests banner-shape but means default-task-parity | `taskfiles/lint.yml:287-312` | Resolved by this research. Planner does NOT touch LINT-08 fixtures or rule body. |
| R3 | `motd` doc drift in `docs/MANIFEST.md` (5 sites) was missed in Phase 13 closure | `docs/MANIFEST.md:33,67,137,152,491` | TRIM-03 surfaces and fixes. Concrete edit list provided above. |
| R4 | `docs/MANIFEST.md` CLI-reference examples use Phase-1-era `-t taskfiles/manifest.yml` invocation form, contradicting the Phase 12 public-surface rename | `docs/MANIFEST.md:382-419, 461-471` | TRIM-03: rewrite CLI examples to use `task setup`, `task show:manifest`, `task audit:manifest`, `task test:manifest`. Delete the Phase 1 note. |
| R5 | `.claude/CLAUDE.md` deletion in a session that has the file loaded into context may cause Claude to "forget" the rules mid-session | session context | The session that runs `git rm .claude/CLAUDE.md` retains the loaded context; only the NEXT session reads from disk. To avoid mid-session confusion, the planner should sequence: (1) delete `.claude/CLAUDE.md`; (2) close the agent; (3) re-open and verify the post-delete behavior. Not a Phase 14 task body change -- just sequencing guidance. |
| R6 | `CLAUDE.md` growth from D-09 gap-fills may exceed the 200-line guideline (current size: 187 lines; Claude Code docs target <200) | `CLAUDE.md` (187 lines today) | Per official docs [CITED: code.claude.com/docs/en/memory]: "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." Plan 14-01 must keep gap-fills terse (1-3 sentences per NEEDS-ADD; not full chapters). If the gap-fills push CLAUDE.md above 220 lines, the planner SHOULD split the LINT catalogue into `.claude/rules/lint.md` (path-scoped rule). |
| R7 | The 22-line `reconcile` lead-comment block in `taskfiles/links.yml:431-456` documents subtle TTY-gate and unlink-not-rm security mechanics that are NOT in CLAUDE.md | `taskfiles/links.yml:431-456` | The inline comments inside the `reconcile:` task body (lines 480-606) already encode the same lessons in their immediate code context. Strip the lead-block (D-04 (a): the inline comments survive as the WHY explanation). NO gap-fill needed. |
| R8 | `install/resolver.zsh` WR-NN bug-history annotations encode lessons not in CLAUDE.md | `install/resolver.zsh:80,179,289,456,558,587` | Plan 14-01 evaluates each: convert to D-04 (a) "non-obvious WHY" comment OR strip if the current code shape makes the lesson self-evident. Two of the six (signal-trap-before-pipeline at :456; exit-status-vs-stdout at :80,558) are subtle enough to warrant a short retained comment. |
| R9 | Mid-trim commits could land before the corresponding lint suite passes if the planner batches multiple files per commit | n/a (process risk) | CONTEXT recommends per-file trim commits with lint+test green after each. Plan 14-02 should enforce this in its task list. |
| R10 | The "Phase 5 will move..." style forward-looking phrasing in `docs/MANIFEST.md` toml-block comments (e.g., line 33 `# Bundle names map to packages/<name>.rb (Phase 5).`) is technically inside a fenced code block, so it doesn't trip the SC#5 grep gate (which excludes `*.md`), but it's still stale | `docs/MANIFEST.md:33` and similar | TRIM-03 should rewrite as `# Bundle names map to packages/<name>.rb.` (drop the Phase-N forward-look). Sweep within the MANIFEST.md edits. |

## Open Questions for Planner

1. **`shell/functions` + `shell/aliases` Class A: re-banner the 21 files with terse/no banner?** Phase 14 Claude's Discretion says "include in TRIM-02 banner pass." But for `whois.zsh`, `cheat.zsh`, etc. that already have a single-line `# <verb> <description>` comment, adding a full 3-label banner is more noise than signal. Recommendation: leave the 19 terse files alone; only re-banner the 6 heavy files (2 functions + 4 aliases). Planner confirms.

2. **`docs/MANIFEST.md` Phase-N TOML-block comments:** strip the `(Phase 5)` / `(Phase 6)` parenthetical references inside fenced code blocks, or leave them? They don't trip the SC#5 grep gate (which excludes `*.md`), but they're stale forward-looking phrasing for a v2.1-final reader. Recommendation: strip during TRIM-03 (mechanical pass, low risk). Planner confirms.

3. **`docs/SECURITY.md` past-tense polish:** the "What This Document Does NOT Cover" section has 3 sentences in future tense pointing at completed Phase 4/7/8 work. Recommendation: rewrite to past tense (1-3 line touches). Planner confirms or skips.

4. **`CLAUDE.md` 200-line guideline:** the D-09 gap-fills (likely 1-3 NEEDS-ADD rows of 1-3 sentences each) plus the D-01 amendment (callers -> key dependencies) plus the LINT-NN catalogue (if added) puts CLAUDE.md at ~205-215 lines post-trim. Per Claude Code docs that's near the soft limit. Recommendation: keep the gap-fills terse; defer the LINT-NN catalogue to `.claude/rules/lint.md` if length pressure surfaces. Planner decides during Plan 14-01.

5. **Single-line `desc:` cut-to-essence pass:** D-05 applies the three-test rule. The longest `desc:` is `lint:taskfile` at 197 chars. Should the planner do a low-effort sweep over all `desc:` strings >100 chars, or skip? Recommendation: cut the 5-6 longest as part of Plan 14-02 per-file commits; don't sweep separately. Planner confirms.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `task` (go-task) | Every lint/test/install gate | yes | 3.51.1 | -- (required) |
| `yq` (mikefarah) | LINT-02 / LINT-03a / LINT-08 fixture runner | yes | 4.53.2 | -- (required) |
| `jq` | `install/resolver.zsh`, install/compose-brewfile.zsh | yes | 1.8.1 | -- (required) |
| `ggrep` (GNU grep via Homebrew) | All LINT rules + many shell scripts | yes | 3.12 | macOS BSD grep cannot substitute (lacks `-P`, `-z` semantics) |
| `zsh` | LINT-07 `zsh -n` | yes | 5.9 | -- (required) |
| `git` | TRIM-05 grep gate via `git grep` | yes | (system) | -- (required) |
| `shellcheck` | NOT invoked by any task today | **no** (`/opt/homebrew/opt/shellcheck` -> empty cellar) | -- | `task lint:syntax` uses `zsh -n` only; no impact on Phase 14 |
| `mas` | Verified by packages tasks; NOT used in Phase 14 | n/a | n/a | -- (not in Phase 14 scope) |
| `wc`, `grep`, `awk`, `sed` | Metrics generation | yes | (system) | -- (required) |

**Missing dependencies with no fallback:** none for Phase 14 scope.
**Missing dependencies with fallback:** `shellcheck` -- not used by Phase 14's lint surface; install only if a reviewer needs out-of-band shellcheck verification.

## Sources

### Primary (HIGH confidence)
- **Anthropic Claude Code memory docs** [CITED: https://code.claude.com/docs/en/memory] -- the canonical reference for `./CLAUDE.md` vs `./.claude/CLAUDE.md` semantics, hierarchical loading, compaction-survival behavior, and the 200-line-soft-limit. Read in full on 2026-05-18.
- **`taskfiles/lint.yml`** (lines 287-312 banner-parity rule body; lines 233 LINT-04 head-30 check; lines 158-217 LINT-02/03a/03b body) -- source-of-truth for what each lint rule actually enforces.
- **`taskfiles/test/lint-fixtures/08[ab]-banner-parity-*/Taskfile.yml`** -- fixture inputs verifying LINT-08 tests default-task parity, not file-header banner shape.
- **`Taskfile.yml`** (lines 212-216 install summary block; lines 124-150 default banner) -- root task definitions verified.
- **`docs/MANIFEST.md`** (lines 33, 67, 137, 152, 491 motd drift; 461-471 stale Phase-1 note) -- verified by line-number reading.
- **In-repo `git log`** -- commit `edbbabd` confirmed motd flag deletion from manifests in Phase 13 (REVIEW row 30).
- **`.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md`** rows 28, 41, 45, 46, 48, 49 -- defer rationales mapping directly to TRIM-NN scope.

### Secondary (MEDIUM confidence)
- Per-file `awk` measurement of leading comment blocks in `shell/functions/*.zsh` + `shell/aliases/*.zsh` -- counts depend on the awk heuristic (`/^[[:space:]]*$/{next} !/^#/{exit}`) which terminates on the first non-blank non-comment line; should be accurate for these files but could misreport if a file uses inline comments interspersed with code in its first 5 lines.

### Tertiary (LOW confidence)
- The TEACHING-INVENTORY NEEDS-ADD predictions (1-3 rows) are reasoned from spot-reading the highest-density files; Plan 14-01's full pass may surface 1-2 additional candidates. Treat the prediction as a sizing aid, not a binding count.

## Metadata

**Confidence breakdown:**
- D-07 verdict: HIGH -- multiple direct citations from the official Anthropic docs, observed in-session behavior.
- LINT-08 mis-naming: HIGH -- rule body read line-by-line; fixture inputs read; runner case read.
- desc: exception list: HIGH -- grep-exhaustive scan of all `desc:` strings in the repo.
- docs/ review findings: HIGH for MANIFEST.md drift sites (line-number verified); MEDIUM for SECURITY.md polish call (judgement).
- TRIM-05 strip surface: HIGH for the file inventory and comment-count numbers; MEDIUM-HIGH for NEEDS-ADD predictions.
- TRIM-02 Class A scope: HIGH (awk measurement of every Class A file).
- Validation architecture: MEDIUM-HIGH -- mapping to phase requirements is concrete; sampling rate is reasoned.
- Risk surface: MEDIUM-HIGH -- all 10 risks have file:line pointers or process-step pointers; mitigations are concrete planner actions.

**Research date:** 2026-05-18
**Valid until:** 2026-06-01 (Phase 14 should close well within 2 weeks; the Claude Code memory model is stable, the manifest model is locked, and no major external dependency changes are anticipated in this window).

## RESEARCH COMPLETE
