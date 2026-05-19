# Phase 14: Comment + Doc Trim - Pattern Map

**Mapped:** 2026-05-18
**Phase shape:** mechanical trim (not net-new code). Patterns map analog *target shapes* (post-trim references) and *anti-patterns* (sites to cut).
**Files analyzed:** 5 plan artifacts + 6 trim categories
**Analogs found:** 6 / 6 categories (every trim category has at least one concrete in-repo analog)

## Phase Boundary Reminder

This phase produces NEW planning artifacts (`14-TEACHING-INVENTORY.md`, `14-METRICS.md`) and MODIFIES existing code/docs (taskfiles, .zsh files, README.md, CLAUDE.md, docs/MANIFEST.md). It DELETES one file (`.claude/CLAUDE.md`). No net-new feature code. "Analog" here means "the file the planner names as the target shape in `<read_first>` and `<acceptance_criteria>`".

## File Classification

| Phase 14 Artifact / Edit Target | Role | Trim Category | Closest Analog (in-repo) | Match Quality |
|---|---|---|---|---|
| `14-TEACHING-INVENTORY.md` (new) | planning artifact | D-09 prereq table | `13-REVIEW.md` (six-column house style) | exact format-match |
| `14-METRICS.md` (new) | planning artifact | TRIM-01 SC#1 evidence | `13-REVIEW.md` table shape | role-match |
| `Taskfile.yml` (modify) | root taskfile | TRIM-01 + TRIM-02 banner + still-live footgun keep | `taskfiles/helpers.yml` (lean post-trim shape) | role-match (heavy-banner anti-pattern at present) |
| `taskfiles/links.yml` (modify) | included taskfile | TRIM-01 + TRIM-02 (biggest delta) | `taskfiles/helpers.yml` (target shape) | role-match (currently anti-pattern; 41-line banner) |
| `taskfiles/manifest.yml` (modify) | included taskfile | TRIM-01 (highest D-NN annotation density) | `taskfiles/audit.yml` (3-label exemplar) | role-match |
| `taskfiles/{audit,show,refresh}.yml` (verify) | included taskfile | TRIM-02 (already at target shape) | (already-exemplar; verify pass only) | exact (themselves the references) |
| `shell/.zlogout` (modify) | startup script | TRIM-02 (51-line banner over 2-line body) | `shell/functions/_dotfiles_feature.zsh` banner head (lines 1-26) | role-match |
| `shell/aliases/{jgrid,ghostty,finder,dotfiles}.zsh` (modify) | alias file | TRIM-02 Class A banner pass | `taskfiles/audit.yml` 3-label shape (adapted to `#!/bin/zsh`) | role-match |
| `shell/functions/_dotfiles_feature.zsh` + `_dotfiles_require_feature.zsh` (modify) | helper function | TRIM-02 Class A banner trim | `taskfiles/helpers.yml` (3-label shape) | role-match |
| `docs/MANIFEST.md` (modify) | doc | TRIM-03 (motd drift + Phase-1 note + CLI rewrite) | `docs/MACHINES.md` (already-current exemplar) | role-match |
| `docs/README.md` (modify) | doc index | TRIM-03 (stale MIGRATION + CUTOVER refs) | (no analog; surgical rewrite) | n/a |
| `README.md` (modify) | top-level README | TRIM-04 humans-only | (no in-repo analog; built per D-06 + CONTEXT §Specifics shape) | n/a |
| `CLAUDE.md` (modify) | canonical AI ref | TRIM-04 D-01 amend + D-09 gap-fill | (file is itself the canonical reference being amended) | n/a |
| `.claude/CLAUDE.md` (DELETE) | duplicate AI ref | TRIM-04 D-06/D-07 | n/a -- deletion | n/a |
| Per-file trim commits | git operation | TRIM-01 + TRIM-02 process | Phase 13 commits `6f23c01`, `12af5b9`, `f37c6a0`, `2cb8c34` | exact |

## Pattern 1 -- Banner Shape Target (D-01 / D-02 / D-03)

### Primary analog: `taskfiles/helpers.yml` (post-trim reference)

**Why this is the analog:** RESEARCH §"Reusable Assets" calls this the lean reference (103 lines, 27 comment lines, ~26% ratio). CONTEXT line 110 quotes the same numbers. CONTEXT §canonical_refs: "useful as the reference for what a post-trim taskfile looks like." Currently the closest in-repo file to the target post-D-01/D-02/D-03 shape, though it still narrates usage. The narrative portion (lines 12-23) gets cut under D-03 and the banner condenses to 3 labels.

**Excerpt -- `taskfiles/helpers.yml:1-23` (the existing lean state):**
```yaml
version: '3'

# =============================================================================
# Shared Helper Tasks
# =============================================================================
#
# This file contains reusable helper tasks that are included by other taskfiles.
# It provides a single source of truth for common operations like:
#   - Creating symlinks with parent directory creation
#   - Validating symlinks, directories, files, and commands
#
# Usage in other taskfiles:
#   includes:
#     _: ./helpers.yml
#
#   tasks:
#     my-task:
#       cmds:
#         - task: _:safe-link
#           vars: { SOURCE: "...", TARGET: "..." }
#
# The underscore (_) namespace is a convention indicating internal/helper tasks.
# =============================================================================
```

**Post-trim target shape (D-01/D-02/D-03 applied, per CONTEXT §specifics):**
```yaml
version: '3'

# =============================================================================
# taskfiles/helpers.yml -- shared reusable helper tasks
#
# Purpose:      Single source of truth for symlink creation + validation helpers.
# Depends on:   nothing.
# Side effects: none (each helper is invoked with explicit SOURCE/TARGET vars).
# =============================================================================
```

Planner usage: quote both excerpts side-by-side in Plan 14-02 task body so the executor sees "before/after" clearly.

### Secondary analog: `taskfiles/audit.yml` (already at target shape)

**Why this is the analog:** Created in Phase 12 with the 3-label banner already in place. RESEARCH §"Reusable Assets" describes audit/show/refresh as "already-minimal." This is the shape Plan 14-02 normalizes other taskfiles to.

**Excerpt -- `taskfiles/audit.yml:1-13` (already matches D-01/D-02/D-03 target):**
```yaml
version: '3'

# =============================================================================
# taskfiles/audit.yml -- Phase 12 public diagnostics: drift detection.
#
# Purpose: Public delegates for diagnostic audit operations across all namespaces.
# Callers: Invoked directly by operator; included by Taskfile.yml.
# Side effects: Read-only -- these tasks print state or detect drift; no mutations.
# Tasks:
#   - links -- delegate to :links:reconcile (orphan symlink detection; D-02)
#   - packages -- delegate to :packages:audit (brew/cask/mas drift detection; D-02)
#   - manifest -- delegate to :manifest:validate (schema check; D-03)
# =============================================================================
```

**Diff against D-01 target:** This banner says "Callers" rather than "Depends on". Plan 14-01 amends CLAUDE.md's bullet to "Purpose / Depends on / Side effects" (D-01), then Plan 14-02 normalizes the `Callers:` label to `Depends on:` here as well -- audit.yml has no dependencies, so the resulting label collapses to "Depends on: nothing." The "Tasks:" sub-list (lines 9-12) is borderline-narrative under D-03; planner judges whether to retain it given `task --list` is the canonical operator surface for that info. Also flags inline-comment-internal `D-02 / D-03` planning-history annotations on lines 11-12 -- those get stripped under D-04 + TRIM-05 grep gate.

### Tertiary analog: `taskfiles/show.yml` and `taskfiles/refresh.yml`

Both follow the same shape as `audit.yml` (see `taskfiles/show.yml:1-13` and `taskfiles/refresh.yml:1-13` already read in the planning research). Their banners follow the audit.yml pattern verbatim and serve as additional confirmation that the target shape is internally consistent.

### Counter-example (anti-pattern, the CUT target)

**File:** `taskfiles/links.yml:1-39`
**Why this is the counter-example:** CONTEXT line 11 names it as "the 41-line banner" anchor; RESEARCH §"Surface Inventory Snapshots" notes "biggest delta opportunity." Quoting this contrast in Plan 14-02's task body for `links.yml` makes the trim target concrete.

**Excerpt -- `taskfiles/links.yml:1-15` (first 15 lines of the heavy banner):**
```yaml
version: '3'

# =============================================================================
# taskfiles/links.yml -- Phase 3 link orchestration (real implementation)
#
# Purpose:
#   Replaces taskfiles/links-stub.yml as the real implementation of links:all.
#   P3 + P4 currently included; later phases extend the `all:` aggregator with
#   their own subtasks:
#     - P3 shell startup files (already wired)
#     - P4 git/ssh/identity (already wired via `task: identity:install`)
#     - P5 adds packages/brew (none in links.yml; package install lives in brew.yml)
#     - P6 adds macos (none in links.yml; defaults live in macos.yml)
#     - P7 adds tools/claude
```

**What gets cut:** lines 5-15 are change-history narrative ("Replaces taskfiles/links-stub.yml" is past-tense scaffolding; the phase-by-phase enumeration is exactly the "anti-pattern teaching" / planning-history form D-08 strips). Lines 16-39 continue with status-block convention prose + LINT-03b prose that D-09 confirms are already covered in CLAUDE.md §Rules.

## Pattern 2 -- Inline-Comment Three-Test KEEP/CUT Rule (D-04)

### KEEP example (a) -- non-obvious WHY

**Source:** `taskfiles/manifest.yml:71-77`
**Why this is the analog:** WR-08 fix comment explains the subtle stdin-handling rationale that `head -n1 | sed` doesn't reveal on its own (why not `cat | tr -d '[:space:]'`). The WHY is in the comment; the code is mechanical sed. Plus, removing it risks the next maintainer re-introducing the silent-whitespace-stripping bug.

**Excerpt -- `taskfiles/manifest.yml:71-79`:**
```yaml
  # RESEARCH §6.1: sh: block evaluated at task invocation time.
  # WR-08 / IN-02 fix: previous `cat | tr -d '[:space:]'` would silently
  # rewrite "bad name\n" -> "badname" by stripping ALL whitespace, not
  # just edges. Read just the first line of the state file (it is
  # single-line by contract) and trim leading/trailing whitespace via
  # sed; this preserves any embedded whitespace so the downstream
  # MACHINE_NAME_RE check rejects malformed values cleanly.
  MACHINE:
    sh: head -n1 '{{.STATE_FILE}}' 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
```

**KEEP rationale:** rule (a) (non-obvious WHY). **However**, this same comment contains both `RESEARCH §6.1` and `WR-08 / IN-02` planning-history annotations that TRIM-05 grep-gate strips. Planner action: rewrite to keep the WHY, drop the planning tags. Target form (~3 lines):
```yaml
  # Read first line + trim edges only: a `cat | tr -d '[:space:]'` would
  # silently strip embedded whitespace (e.g., "bad name" -> "badname")
  # and let malformed state-file values bypass MACHINE_NAME_RE.
  MACHINE:
    sh: head -n1 '{{.STATE_FILE}}' 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
```

### KEEP example (b) -- still-live footgun

**Source:** `Taskfile.yml:131-148` (and the sibling block at lines 240-248)
**Why this is the analog:** CONTEXT line 80 calls these out explicitly. The DOTFILEDIR-leak via `sh: dirname "{{.TASKFILE_DIR}}"` in included taskfiles is a still-live footgun -- per REVIEW row 28 the underlying architectural fix is deferred, so the comment warns the next contributor not to swap `{{.TASKFILE_DIR}}` for `{{.DOTFILEDIR}}` here.

**Excerpt -- `Taskfile.yml:131-136`:**
```yaml
      - |
        # Source messages.zsh via TASKFILE_DIR (NOT the DOTFILES_MESSAGES var)
        # per the documented DOTFILEDIR pollution workaround -- same pattern
        # as install: and validate: above. Banner stays render-stable
        # regardless of include-merge ordering.
        source '{{.TASKFILE_DIR}}/install/messages.zsh'
```

**KEEP rationale:** rule (b) (still-live footgun). The comment encodes a real failure mode the next maintainer would re-introduce; CONTEXT Deferred Ideas confirms the architectural fix defers. Planner action: keep verbatim. The "same pattern as install: and validate: above" cross-reference (CONTEXT line 32 explicitly cuts this style) can be trimmed -- the comment stands on its own.

### KEEP example (c) -- lint rule citation

**Source:** `taskfiles/audit.yml:20`, `:28`, `:36` (and 19+ siblings across `claude.yml`, `identity.yml`, `links.yml`, `macos.yml`)
**Why this is the analog:** `# lint-allow: cmds-without-status` is a functional pragma that the lint rule body reads (well, technically RESEARCH §"Lint Suite Safety" line 165 verifies it's purely human-readable today, but CONTEXT §Claude's Discretion explicitly keeps these as "citations" under rule (c)). Best concrete example of rule (c).

**Excerpt -- `taskfiles/audit.yml:19-26`:**
```yaml
tasks:
  # lint-allow: cmds-without-status
  links:
    desc: "Audit symlink drift (detect orphans); -- --remove for interactive cleanup"
    status: [false]
    cmds:
      - task: :links:reconcile
        vars: { CLI_ARGS: '{{.CLI_ARGS}}' }
```

**KEEP rationale:** rule (c) (cites a lint rule the code satisfies). Per CONTEXT decision D-09 last bullet ("Whether to strip `# lint-allow: cmds-without-status` markers -- these are functional pragmas, not comments. Keep.")

**Sibling rule-(c) example:** `taskfiles/links.yml:20` "# Status-block convention (LINT-02 enforcement):" is a citation header introducing a 22-line teaching block. The citation HEADER may stay if rewritten to one line; the 22-line explainer below (lines 20-39) gets stripped (D-08 + RESEARCH §"NEEDS-ADD candidates" #1 confirms lesson is covered by CLAUDE.md §Rules).

### CUT example (restatement of code)

**Source:** `taskfiles/manifest.yml:43-46`
**Why this is the analog:** Comments restate exactly what the `sh: dirname "{{.TASKFILE_DIR}}"` line below them does -- the code is already self-documenting.

**Excerpt -- `taskfiles/manifest.yml:43-55`:**
```yaml
  # Resolve DOTFILEDIR from this taskfile's parent directory.
  # go-task 3.37+ provides {{.TASKFILE_DIR}} as the directory containing
  # the invoked taskfile. For taskfiles/manifest.yml, dirname once goes
  # from <repo>/taskfiles to <repo>.
  # NOTE: the prior `dirname dirname realpath ${TASKFILE:-$0}` pattern
  # silently fell back to cwd when $TASKFILE is not exported (it is not
  # exported by go-task; only the {{.TASKFILE}} template var is). The
  # double-dirname of cwd produced a path one segment above the repo
  # root, which broke resolver.zsh invocation on fresh machines that had
  # no XDG_STATE/resolved.json cache to short-circuit the task. This sh:
  # pattern matches lint.yml:59 and links.yml:61.
  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"
```

**CUT rationale:** Lines 43-46 restate the code. Lines 47-53 are change-history (the prior pattern + bug detail). Line 53 "This sh: pattern matches lint.yml:59 and links.yml:61" is exactly the "cross-references to other files for context only" form CONTEXT line 32 cuts. The actual WHY (TASKFILE_DIR not TASKFILE because TASKFILE isn't exported) is documented in CLAUDE.md §Tooling Versions / go-task 3.37 row already; this comment block can compress to one line:
```yaml
  # DOTFILEDIR fallback for direct `task -t taskfiles/manifest.yml` invocation;
  # leaks to root scope when included -- see Taskfile.yml:131 footgun comment.
  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"
```

### CUT example (planning-history annotation)

**Source:** `taskfiles/links.yml:170` (and 12 siblings flagged by RESEARCH §TRIM-05 table)
**Why this is the analog:** Contains `LINT-02` (legitimate citation that stays) bundled with a `D-04` planning-tag (cut by TRIM-05 grep gate). The mixed style shows the planner the surgical line: keep the citation, strip the decision tag.

**Excerpt -- `taskfiles/links.yml:167-183`:**
```yaml
  # ---------------------------------------------------------------------------
  # PORT-01: ZDOTDIR write to /etc/zshenv (sudo, idempotent).
  #
  # Direct port of v1 taskfiles/common.yml:36-57 with the LINT-02 hardening
  # from D-04: status block uses the {{.ZDOTDIR}} template var rather than a
  # shell $ZDOTDIR reference, so the idempotency check evaluates correctly at
  # task-graph build time (not the v1 macos:shell:145 bug class).
  #
  # Three-branch cmd body mirrors v1 verbatim: file-absent -> `sudo tee` to
  # create; line-absent -> `sudo tee -a` to append; line-present -> info no-op.
  # /etc/zshenv is world-readable on macOS so the grep -qF check in status
  # runs without sudo and re-runs never prompt (D-03).
  #
  # Marked internal: true to keep it out of `task --list`; dispatched via
  # `task: zdotdir` from the outer `zsh:` task (precedent: configs:ghostty
  # extraction at lines 269-277 below).
  # ---------------------------------------------------------------------------
```

**CUT rationale:** `PORT-01`, `D-04`, `v1 taskfiles/common.yml:36-57`, `v1 macos:shell:145 bug class`, `(D-03)` all trip TRIM-05 grep gate (`Phase|D-|Gap|CR-|WR-|RESEARCH §|v1 (bug|finding|leftover)|UAT [Gg]ap` -- the last block matches `v1 ... bug`). The "cross-reference to lines 269-277" is the cut-style cross-reference. Three-branch cmd description restates the cmd body. Mid-file `# ---------------------------------------------------------------------------` separators violate D-02 ("no mid-file separators").

Post-trim shape (~3-4 lines, keeping the LINT-02 footgun warning + the world-readable rationale):
```yaml
  # /etc/zshenv ZDOTDIR write. Status uses {{.ZDOTDIR}} (template var) not
  # $ZDOTDIR -- shell vars in status: re-run every invocation (LINT-02).
  # /etc/zshenv is world-readable so grep -qF runs without sudo on re-checks.
  zdotdir:
```

## Pattern 3 -- `desc:` Block Reference (D-05)

### Single-line `desc:` exemplar (every `desc:` in the repo today)

**Why this is the analog:** RESEARCH §"desc: Block Exceptions" verdict: "None. The exceptions list is empty." Every `desc:` in `Taskfile.yml` + `taskfiles/*.yml` is single-line. This is already the target shape -- no `desc:` block trim needed.

**Excerpt -- `taskfiles/links.yml:122` (the `links:install` aggregator):**
```yaml
    desc: "Create all symlinks (P3+P4+P7: shell + identity + claude + configs)"
```

**Diff against D-05:** The `(P3+P4+P7: shell + identity + claude + configs)` parenthetical contains TRIM-05 planning-history tags (`P3`, `P4`, `P7`). Planner action: rewrite to:
```yaml
    desc: "Create all symlinks (shell + identity + claude + configs)"
```

**Excerpt -- `taskfiles/test.yml:240-241` (the `add-machine` smoke test):**
```yaml
  add-machine:
    desc: "Smoke test: adding a new machine is one TOML + task setup (MFST-09)"
```

**Diff against D-05:** Already single-line and passes D-04 rule (a) -- explains WHY it exists (smoke test). The `(MFST-09)` requirement citation is grep-gate-safe (TRIM-05 pattern doesn't include `MFST-NN`). Leave as-is OR drop the citation per the planner's call. RESEARCH §"desc: Block Exceptions" recommends low-effort sweep of the 5-6 longest `desc:` strings during Plan 14-02 (longest is `taskfiles/lint.yml:147` at 197 chars).

### Multi-line `summary:` exemplar (the one operator-context block in the repo)

**Source:** `Taskfile.yml:212-216`
**Why this is the analog:** RESEARCH §"desc: Block Exceptions" identifies this as the only multi-line operator-context block in the repo, using the dedicated `summary: |` key (not `desc:`). Per D-04 rule (a), it stays. Planner names it explicitly in Plan 14-02 as "do not touch."

**Excerpt -- `Taskfile.yml:212-216`:**
```yaml
  install:
    desc: "Install dotfiles for active machine (canonical entry)"
    summary: |
      task install IS task update -- there is no separate update pipeline.
      Re-running is a no-op (every subtask has a status: block per LINT-01).
```

**KEEP rationale:** `task --summary install` renders both fields; the `summary:` block exists because operators need to know install-IS-update on first invocation. Rule (a) (non-obvious WHY) -- the fact that there's no `task update` is non-obvious until the operator tries it.

## Pattern 4 -- Doc Shape Analogs for TRIM-03 / TRIM-04

### `README.md` current state (TRIM-04 D-06 humans-only rewrite target)

**Source:** `README.md:1-30`
**Why this is the analog:** The "before" reference. RESEARCH confirms README.md is already 79 lines and largely humans-only; the dedup is light. CONTEXT §specifics gives the exact post-trim shape.

**Excerpt -- `README.md:1-30` (current head):**
```markdown
# dotfiles

## What This Is

macOS dotfiles managed with go-task, manifest-driven per-machine
configuration via TOML, and an XDG base directory layout throughout.
New contributors and AI agents working on this repo should read this
README and `docs/MANIFEST.md` to understand the v2 manifest model.

A single TOML file per machine under `manifests/machines/<name>.toml`
inherits from a shared baseline at `manifests/defaults.toml`. The
resolver (`install/resolver.zsh`) deep-merges the two TOMLs and compiles
the result to `$XDG_STATE_HOME/dotfiles/resolved.json` once per setup;
every go-task task reads from that JSON via `fromJson`. Active machine
selection is stored at `$XDG_STATE_HOME/dotfiles/machine` and set
explicitly via `task setup -- <machine-name>`. There is no hostname
inference, no environment variable to remember, and no hidden profile
branching anywhere in the pipeline. The complete schema for both TOML
files (sections, types, deep-merge rules, worked examples) lives in
`docs/MANIFEST.md`.

## Fresh Machine Setup

Run these commands in order on a clean Mac. `bootstrap.zsh` acquires
Homebrew, go-task, and yq and then prints the next-step hint.
`task setup` writes the active machine name to
`$XDG_STATE_HOME/dotfiles/machine`; `task install` runs the full install
pipeline (links + packages + claude + macos + verify + reconcile).

```zsh
git clone <repo-url>
./bootstrap.zsh
```

**Diff against D-06 humans-only target:** "What This Is" repeats CLAUDE.md content (manifest model explanation) -- this becomes a 2-3 sentence summary + link to CLAUDE.md per D-06. "Where to Add Things" table at line 61-72 is duplicate of CLAUDE.md:135-144 -- removed in dedup; cross-link replaces it. "AI agents" reference in line 7 gets cut (CLAUDE.md is the AI-agent home now). Line 79 reference to `.claude/CLAUDE.md` deletes (that file is being deleted).

### `CLAUDE.md` "Conventions Not Captured Above" -- D-01 amendment site

**Source:** `CLAUDE.md:152-153`
**Why this is the analog:** This is the exact bullet the planner amends in Plan 14-01 (D-01 contradiction resolution: "callers" -> "key dependencies").

**Excerpt -- `CLAUDE.md:146-156`:**
```markdown
## Conventions Not Captured Above

- No AI attribution in commits or source — no attribution trailers, no "written by AI" comments,
  anywhere. Hooks enforce this at commit time.
- No emojis in any file — including markdown. Project convention is stricter than the global
  "no emojis in non-markdown" rule.
- File-level comment block at the top of every script explaining its purpose, callers, and
  side effects.
- Section separators in YAML files use `# ===` or `# ---` banner style.
- Errors go to stderr (`echo "..." >&2` or `error "..."` from the messages library in
  `install/messages.zsh`).
```

**Plan 14-01 amendment (D-01):** lines 152-153 ("File-level comment block ... purpose, callers, and side effects") -> "File-level comment block at the top of every script: Purpose / Depends on / Side effects (3 labels; one `# === ===` 77-char rule above and below; no narrative prose, no examples)." Per CONTEXT §specifics. Concurrently, line 154 "Section separators in YAML files use `# ===` or `# ---` banner style" gets reviewed -- D-02 disallows mid-file separators, so the bullet either narrows to "the file header banner uses `# === ===`" or gets removed entirely.

### `.claude/CLAUDE.md` current state -- D-06/D-07 deletion verification target

**Source:** `.claude/CLAUDE.md:1-30`
**Why this is the analog:** Confirms content is fully subsumed by root `CLAUDE.md` (the deletion rationale per D-06). RESEARCH §"D-07 Verdict" PASS confirms safe to delete.

**Excerpt -- `.claude/CLAUDE.md:1-30`:**
```markdown
# Dotfiles Project

## Overview

macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.
Per-machine TOML manifests under `manifests/machines/<name>.toml` inherit from
`manifests/defaults.toml`. Active machine selection is stored at
`$XDG_STATE_HOME/dotfiles/machine` and exported as `$DOTFILES_MACHINE`. No
hostname inference, no profile suffixes, no per-profile env var. Schema
reference: `docs/MANIFEST.md`.

## Quick Reference

- Fresh install: `./bootstrap.zsh`
- Re-install / update: `task install` (D-10: install IS update; single canonical pipeline)
- Validate: `task validate`
- Show tasks: `task --list`
- Set machine: `task setup -- <machine-name>` (BTSP-04; writes `$XDG_STATE_HOME/dotfiles/machine`)
- Show manifest: `task show:manifest` (prints the post-merge structure for debugging)

## Structure

- `Taskfile.yml` -- root orchestration; defines global vars (XDG paths,
  `ZDOTDIR`, `DOTFILEDIR`, `HOMEBREW_PREFIX`, `DOTFILES_MESSAGES`,
  `RESOLVED_JSON_PATH`, `MANIFEST`) and includes per-concern taskfiles.
- `taskfiles/<concern>.yml` -- modular taskfiles (helpers, manifest, lint,
  links, shell, brew, claude, macos). See `taskfiles/README.md`.
- `taskfiles/helpers.yml` -- reusable `_:safe-link`, `_:check-link`,
  `_:check-dir`, `_:check-file`, `_:check-command`.
- `manifests/defaults.toml` -- shared duplication of root `CLAUDE.md` content.
```

**Deletion verification:** Every section above is duplicated in root `CLAUDE.md`. The "Quick Reference" maps to root §"Common Tasks", "Structure" maps to root §"The Manifest Model" + §"Adding Things", "Conventions" maps to root §"Rules", etc. The `D-10`, `BTSP-04` planning-history tags would trip TRIM-05 grep gate if kept anyway. Plan 14-03 verifies one final read confirming no unique content survives, then `git rm .claude/CLAUDE.md`. (RESEARCH R5 process-sequencing guidance: run the delete commit, close session, re-open to verify next-session loads only root CLAUDE.md.)

### `docs/MANIFEST.md` motd drift sites (TRIM-03 surgical targets)

**Source:** `docs/MANIFEST.md:33, 67, 137, 152, 491`
**Why this is the analog:** RESEARCH §"docs/ Review Findings" R3 enumerates these 5 sites. Each is a one-line surgical edit. Planner pastes these into Plan 14-03 (TRIM-03 task) as the literal edit list.

**Excerpt 1 -- `docs/MANIFEST.md:28-40` (around line 33):**
```markdown
[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in a later phase.
# Conservative defaults (mostly off). kebab-case keys MUST be accessed via
# {{index .MANIFEST.features "name"}} in taskfiles (Go-template parser rejects "-" in dot-access).
one-password-ssh = false
motd = true
claude-marketplace = true

[packages.brew]
# Bundle names map to packages/<name>.rb (Phase 5).
bundles = ["core"]
# Additive escape hatch -- resolver computes the dedupe union of defaults plus machine extras.
extra_packages = []
```

**Edit:** Delete line 33 (`motd = true`). Line 37 `(Phase 5)` is RESEARCH §"Open Question 2" -- planner confirms strip (mechanical, low-risk).

**Excerpt 2 -- `docs/MANIFEST.md:62-71` (around line 67):**
```markdown
macos-dock = true
macos-finder = true
macos-input = true
macos-screenshots = true
macos-security = true
motd = true
claude-marketplace = true

[packages.brew]
bundles = ["core", "gui"]
```

**Edit:** Delete line 67 (`motd = true`).

**Excerpt 3 -- `docs/MANIFEST.md:130-157` (around lines 137 + 152):**
```markdown
### Worked examples

#### Fixture 01 -- map-over-map (deep-merge preserves siblings)

`defaults.toml`:
```toml
[features]
motd = true
claude-marketplace = true
```

`machine.toml`:
```toml
[features]
one-password-ssh = true
macos-dock = true
```

`resolved.json`:
```json
{
  "features": {
    "motd": true,
    "claude-marketplace": true,
    "one-password-ssh": true,
    "macos-dock": true
  }
}
```
```

**Edit:** Delete line 137 (`motd = true` in toml) and line 152 (`"motd": true,` in json). The fixture-01 example shrinks by one entry on each side; that's fine -- the deep-merge demonstration still works with `claude-marketplace = true` carrying the "siblings preserved" lesson.

**Excerpt 4 -- `docs/MANIFEST.md:487-496` (around line 491, Feature-Flag Reference table):**
```markdown
| Feature | Owner phase | What it does | Default in `defaults.toml` |
|---------|-------------|--------------|---------------------------|
| `one-password-ssh` | Phase 4 | Enables 1Password SSH agent integration | `false` |
| `one-password-signing` | Phase 4 | Enables git commit signing via 1Password op-ssh-sign | `false` |
| `motd` | Phase 3 | Enables MOTD display on `.zlogin` | `true` |
| `claude-marketplace` | Phase 7 | Installs Claude marketplace plugins | `true` |
| `macos-dock` | Phase 6 | Runs `os/defaults/dock.zsh` | `false` |
```

**Edit:** Delete line 491 (the `motd` row). The "Owner phase" column also carries `Phase 3 / Phase 4 / Phase 6 / Phase 7` references -- these are inside fenced markdown so they don't trip the SC#5 grep gate, but RESEARCH §"Open Question 2" recommends stripping them as stale forward-looking phrasing. Planner confirms scope.

## Pattern 5 -- Six-Column AUDIT/SURFACE/REVIEW Table House Style

### `13-REVIEW.md` (Phase 13) -- the exemplar

**Source:** `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md:11-13`
**Why this is the analog:** CONTEXT line 84 explicitly cites "six-column REVIEW/AUDIT table house style; `14-METRICS.md` and `14-TEACHING-INVENTORY.md` adopt the same column-discipline (one row per file/annotation, clear headers, sorted)." This is the literal column-shape Phase 14's artifacts follow.

**Excerpt -- `13-REVIEW.md:11-13`:**
```markdown
| file:line | severity | category | finding | remediation | closed by |
|-----------|----------|----------|---------|------------|-----------|
| shell/aliases/general.zsh:24 | HIGH | correctness | `alias ls="$(command -v eza) --time-style long-iso"` evaluates `command -v eza` at source time; if eza is uninstalled (or PATH is unprimed), expansion yields ` --time-style long-iso` which masks the system `ls` entirely (every directory listing fails). Same class at networking.zsh:7 for `trip`. | Replace with `alias ls='eza --time-style long-iso'` (lazy expansion) gated on `command -v eza >/dev/null 2>&1 \|\| return 0` source-time guard; apply identical fix to `networking.zsh:7`. Fix in Plan 13-02. | d5b21a0 |
```

**Adaptation for `14-TEACHING-INVENTORY.md` (per CONTEXT §specifics + RESEARCH §"TRIM-05 Strip Surface Preview"):**
```markdown
| file:line | snippet | lesson encoded | covered by CLAUDE.md §X | action | NEEDS-ADD? |
|-----------|---------|----------------|-------------------------|--------|------------|
| taskfiles/links.yml:18-39 | "Status-block convention (LINT-02 enforcement)..." (22 lines) | $X in status: causes re-run; status uses {{.X}} only | CLAUDE.md §Rules > "Every install task has a status: block" (lines 86-101) | strip after Plan 14-01 | no |
| install/resolver.zsh:171,212,616 | D-01/D-04/D-16 cross-field-validation refs | manifest cross-field rules are runtime-checked | CLAUDE.md §Rules (D-16 not present) | strip after gap-fill | yes -- add cross-field-validation paragraph |
| shell/.zlogout:2-51 | "Examples / typical contents / safety notes..." (49 lines) | when zsh logout fires; what fc -W does | none (zsh tutorial content, not project rule) | strip; do not gap-fill | no |
```

**Adaptation for `14-METRICS.md` (per CONTEXT §specifics):**
```markdown
| file | code_lines | comments_pre | comments_post | delta | % reduction |
|------|-----------:|-------------:|--------------:|------:|------------:|
| Taskfile.yml | 147 | 102 | 38 | -64 | 63% |
| taskfiles/links.yml | 377 | 230 | 72 | -158 | 69% |
| ... | ... | ... | ... | ... | ... |
| **Total** | **3,954** | **1,476** | **TBD** | **TBD** | **TBD** |
```

Pre snapshot at Plan 14-02 start (before first trim commit); post snapshot at Plan 14-02 close; aggregate row at bottom. Right-aligned numeric columns via the `---:` markdown idiom.

## Pattern 6 -- Per-File Commit Discipline (Phase 11/12/13)

### Plan 13-06 / Plan 13-04 commit-shape exemplars

**Why this is the analog:** Phase 13 ran the same "trim one file + commit + green tree" discipline Phase 14 needs. The commit messages encode the row-closure pattern that Plan 14-02 commits can match. CONTEXT line 162 ("Per-file commit discipline (Phase 11/12 D-04, Phase 13 D-Discretion): each commit leaves `task lint && task test && task install` green").

**Exemplar 1 -- Phase 13 READMEs dedup (closest to Phase 14 TRIM-03/04 work):**
```
6f23c01 docs(13-06): drop stale antidote references across READMEs -- closes REVIEW.md rows 16,47
```
Body:
```
- configs/README.md: drop the antidote table row (no configs/antidote/ dir exists; .zshrc:75 uses antigen)
- shell/README.md: replace antidote->antigen with Phase 3 D-01 revert citation
- taskfiles/README.md: clarify antigen is live plugin manager; cite .zshrc:75 revert comment
- packages/README.md: core.rb describes antigen (with Phase 3 D-01 antidote revert citation)

Row 16 (MEDIUM/clarity): nonexistent configs/antidote/ table row removed.
Row 47 (LOW/clarity): three sibling READMEs (taskfiles/README.md, shell/README.md, packages/README.md) no longer describe antidote as live. Batched in same commit per row-47 plan remediation.
```

**Exemplar 2 -- Phase 13 dead-code single-file removal:**
```
edbbabd refactor(13-03): drop dead motd feature flag from manifests -- closes REVIEW.md row 30
cdbab32 refactor(13-03): drop dead commit-task1.yml exemption from lint.yml -- closes REVIEW.md row 31
ebccf47 refactor(13-03): drop unreachable Linux branch from .zprofile -- closes REVIEW.md row 32
```

**Exemplar 3 -- Phase 13 surgical inline fix:**
```
4322d13 fix(13-06): set-u-safe DOTFILES_DEBUG ref in messages.zsh debug() -- closes REVIEW.md row 18
f37c6a0 fix(13-06): preserve XDG_DATA_DIRS/CONFIG_DIRS + guard BROWSER export -- closes REVIEW.md rows 34,35
2cb8c34 fix(13-06): drop script-scope local + guard VSCode shell-integration source -- closes REVIEW.md rows 36,37
```

**Adaptation for Plan 14-02 commits (per-file trim):**
```
docs(14-02): trim taskfiles/links.yml banner + planning-history annotations
  -- 41-line banner -> 6 lines (D-01/D-02/D-03 target shape)
  -- 22-line LINT-02 explainer cut (covered by CLAUDE.md §Rules)
  -- 5 # Phase N / # D-NN / # CR-NN annotations stripped (TRIM-05 gate)
  -- task lint && task test green; 14-METRICS.md row updated
```

The naming scheme (`<type>(<plan-id>): <imperative summary> -- <one-line rationale or row reference>`) follows the global commit-format rule (`<type>(<scope>): <summary>` <75 chars, imperative mood) plus the Phase 13 convention of citing what the commit closes.

**Trim commit type:** `refactor` for code/comment trim that doesn't change behavior; `docs` for doc-tier edits (`docs/`, `README.md`, `CLAUDE.md`, planning artifacts). `fix` is reserved for behavior-change commits which Phase 14 does not produce.

## Shared Patterns

### Status-block convention (LINT-02 enforcement)
**Source:** `CLAUDE.md:86-101` (already canonical home)
**Apply to:** All taskfiles being trimmed. Citation `# LINT-02:` comments survive (D-04 rule (c)). Long teaching prose like `taskfiles/links.yml:18-39` strips (covered by CLAUDE.md).

### Symlink-creation convention (LINT-03b)
**Source:** `CLAUDE.md:115-119` (already canonical home)
**Apply to:** All taskfiles being trimmed. Inline `# LINT-03b: bare ln -s ...` citations survive; teaching prose strips.

### Kebab-case feature flags need `index` access
**Source:** `CLAUDE.md:68-84` (already canonical home)
**Apply to:** All taskfiles + .zsh files. The convention is comprehensively documented in CLAUDE.md; in-code cross-references can compress to one-line citations.

### Set -euo pipefail on every executable .zsh
**Source:** `CLAUDE.md:103-106` (already canonical home)
**Apply to:** All `.zsh` files being trimmed. RESEARCH R1 flags head-30 LINT-04 risk: ensure `set -euo pipefail` stays inside lines 1-30 after banner trim. Plan 14-02 sanity-check on the 6 Class A files with material banner edits.

### No AI attribution / no emojis
**Source:** `CLAUDE.md:148-151` (already canonical home) + global `~/.config/claude/CLAUDE.md` user-level rule
**Apply to:** Every commit message and every edited file. Commit hooks enforce this; the trim pass does not introduce attribution or emojis. (Note: CONTEXT line 32 plus user-instruction global rule.)

### Per-file commit gate
**Source:** Phase 13 D-Discretion + CONTEXT line 162
**Apply to:** Every Plan 14-02 commit. `task lint && task test` minimum gate; `task install` for any commit touching the install pipeline (links.yml, packages.yml, claude.yml, macos.yml).

## No Analog Found

| Phase 14 Artifact / Edit | Reason no in-repo analog exists |
|---|---|
| `14-TEACHING-INVENTORY.md` | New artifact type; closest format-match is `13-REVIEW.md` six-column shape -- adopt that. Action column drives the strip-or-gap-fill decision per row. |
| `README.md` post-trim humans-only shape | No existing humans-only README in repo at the project root. Build per CONTEXT §specifics shape (Install / Common Tasks / Where things live / Contributing pointer to CLAUDE.md). |
| `CLAUDE.md` post-amend canonical shape | CLAUDE.md is itself the canonical reference being amended (D-01 bullet + D-09 gap-fills). No analog -- the file is the analog. |
| `.claude/CLAUDE.md` deletion | One-shot `git rm` operation; no analog needed. RESEARCH §"D-07 Verdict" PASS confirms safe deletion. |
| Plan 14-03 closing grep gate | SC#5 grep command `git grep -E 'v1 (bug\|finding\|leftover)\|Gap [0-9]+\|D-[0-9]+\|UAT [Gg]ap' -- ':!.planning/'` is its own gate. Phase 11's `git grep '\bv1\b\|profile_suffix\|DOTFILES_PROFILE\|cutover'` pattern (ROADMAP Phase 11 SC#5) is the closest precedent for the discipline. |

## Metadata

**Analog search scope:** `taskfiles/*.yml`, `Taskfile.yml`, `shell/{functions,aliases}/*.zsh`, `shell/.z*`, `install/*.zsh`, `docs/*.md`, `README.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md`
**Files scanned for analogs:** 14 (helpers/audit/show/refresh/links/lint/manifest taskfiles + Taskfile.yml + 2 doc files + 2 CLAUDE files + resolver.zsh + .zlogout + _dotfiles_feature.zsh)
**Pattern extraction date:** 2026-05-18
**Phase research input:** `14-CONTEXT.md` (D-01..D-09), `14-RESEARCH.md` (D-07 PASS, LINT-08 verdict, 13 strip-file inventory, 4 doc-drift sites in MANIFEST.md, Class A scope numbers), `13-REVIEW.md` rows 28/41/45/46/48/49 (defer rows that named Phase 14 TRIM-NN as remediation), `ROADMAP.md` Phase 14 SC#1-5

## PATTERN MAPPING COMPLETE
