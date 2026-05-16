---
phase: 08-validation-cutover-readiness
plan: 05
subsystem: documentation
tags: [docs, migration, readme, v1-to-v2, rollback, d-13, d-15]
requires:
  - docs/MANIFEST.md (cited from MIGRATION.md "Profile suffix" concept section; cross-linked from README.md doc pointers)
  - docs/CUTOVER.md (cited from MIGRATION.md "What This Is" and "Archiving v1" for the cutover state model; cross-linked from README.md)
  - docs/SECURITY.md (cited from MIGRATION.md "Hostname-based Match exec" section for the key-handling context; cross-linked from README.md)
  - docs/MACHINES.md (cross-linked from README.md doc pointers for the per-machine list)
  - install/cutover-gate.zsh (procedure-correctness anchor for README.md 5-command setup block; the install: precondition that demands `task cutover:ack`)
  - Taskfile.yml lines 138-152 (install: cutover_gate_check precondition that the README setup block must satisfy)
  - .planning/phases/08-validation-cutover-readiness/08-CONTEXT.md D-13 (seven-concept list + rollback requirement)
  - .planning/phases/08-validation-cutover-readiness/08-CONTEXT.md D-15 (tutorial-walkthrough + where-to-add table)
  - .planning/phases/08-validation-cutover-readiness/08-PATTERNS.md (structural templates for both files)
  - .planning/phases/08-validation-cutover-readiness/08-04-SUMMARY.md (CUTOVER.md + MACHINES.md predecessors shipped in wave 4)
provides:
  - docs/MIGRATION.md (DOCS-05; per-concept narrative + path-mapping tables for the seven v1-to-v2 concept shifts + Rollback + Archiving v1 procedures)
  - root README.md (DOCS-01; v2 tutorial walkthrough fully replacing the v1 emoji-heavy README)
affects:
  - docs/MIGRATION.md
  - README.md
tech-stack:
  added: []
  patterns:
    - 'per-concept H2 narrative paired with closing two-column old/new path table (one mapping table per concept, scannable by grep-by-old-path)'
    - 'thin-doc cross-reference (cite docs/MANIFEST.md, docs/CUTOVER.md, docs/SECURITY.md from MIGRATION.md per-concept sections without duplicating their content)'
    - 'tutorial-walkthrough README shape: H1 + What This Is + Fresh Machine Setup fenced block + Where to Add Things table + Documentation pointers (analog: docs/MANIFEST.md heading style; sub-dir READMEs for inline-code + section conventions)'
    - 'procedure-correctness gate: README Fresh Machine Setup fenced block contains the required `task cutover:ack` step matching Taskfile.yml install: precondition (otherwise a user copy-paste install hits cutover_gate_check hard-fail)'
    - 'mirror-from-source table: README "Where to Add Things" mirrors CLAUDE.md "Adding Things" 1:1 (single source of truth in CLAUDE.md, README is the public-facing surface)'
key-files:
  created:
    - docs/MIGRATION.md
  modified:
    - README.md
decisions:
  - "MIGRATION.md keeps the seven D-13 concepts in the exact order listed in CONTEXT.md (Profile suffix -> Antigen -> Brewfile -> zsh/ -> gsd-install -> Hostname -> macos:shell). Order matches the operator's mental model: identity-of-state first (profile suffix is the keystone shift), then runtime layers (Antigen / Brewfile / zsh /), then operational details (gsd-install / hostname / status-block bug class). Avoided alphabetical or impact-ranked reorderings -- the CONTEXT.md ordering is the authoritative narrative spine."
  - "Rollback section is non-destructive throughout: `rm` only on machine-local state files under $XDG_STATE_HOME (machine + cutover-ack), never on v1 repo files. Matches CUTV-06 archive-not-delete intent and the plan's threat-register entry T-08-15 (mitigate: rollback uses only non-destructive operations). Operator can re-cut by running `task cutover:ack` again, no v1 changes required."
  - "Archiving v1 procedure uses the canonical `.archive` suffix on the directory rename (e.g., `dotfiles-v1 -> dotfiles-v1.archive`). Rationale: the suffix is reversible by a literal rename-back, the suffix is grep-friendly for an operator running a one-liner audit of which machines still have v1 on disk, and matches the project convention that 'archive' is reversible state distinct from 'deleted'."
  - "README 'What This Is' framing references docs/MIGRATION.md for historical context but does NOT itself use any v1 vocabulary (no DOTFILES_PROFILE substring, no 'profile suffix' phrase). The acceptance criterion is strict mechanical match (`! grep -q 'DOTFILES_PROFILE'`); v1 history is fully delegated to MIGRATION.md so the README stays a v2-only tutorial. Caught and corrected one initial framing-paragraph mention of DOTFILES_PROFILE before commit -- not a Rule 1 deviation because the catch happened pre-commit during the acceptance-verify pass."
  - "README 'Fresh Machine Setup' fenced block uses `zsh` fence label to match the project's primary shell. The acceptance criteria do not specify a fence label, but the project convention (per docs/CUTOVER.md step 1 fence and shell/README.md fences) is zsh. Avoided plain fences for consistency with sibling docs."
  - "README 'Documentation' section is a flat bullet list with one-line descriptions per doc (not a table). The plan's Action text says 'bullet list of doc pointers with one-line descriptions'; the bullet shape stays scannable and matches the 'thin doc with pointers' style of `docs/README.md`."
metrics:
  duration: 4m
  completed: 2026-05-16
---

# Phase 08 Plan 05: Migration Guide + README Replacement Summary

## One-liner

Ship the two final cutover-readiness documents: `docs/MIGRATION.md` (per-concept v1-to-v2 narrative + path tables + rollback + archive procedures, per D-13) and a fully-replaced root `README.md` (v2 tutorial walkthrough with the required five-command fresh-machine block per D-15) -- closes DOCS-05 and DOCS-01.

## What This Plan Delivered

| Deliverable | Location | Verified |
|-------------|----------|----------|
| `docs/MIGRATION.md` H1 `# Migration Guide: v1 to v2` + `## What This Is` framing paragraph | `docs/MIGRATION.md` lines 1-13 | `grep -q '^# Migration Guide: v1 to v2'` passes |
| Seven concept H2 sections in D-13 order (Profile suffix, Antigen, Brewfile, zsh/, gsd-install, Hostname, macos:shell) | `docs/MIGRATION.md` H2 headings | `grep -E '^## '` shows all 7 concept H2s + `## What This Is`, `## Rollback`, `## Archiving v1` |
| Per-concept old/new path-mapping table for each of the 7 concepts | `docs/MIGRATION.md` table sections | `grep -c '^|' docs/MIGRATION.md` returns 38 table rows (>= 7 minimum, well above) |
| `## Rollback` H2 with non-destructive 4-step procedure (rm state files only; v1 stays on disk) | `docs/MIGRATION.md` Rollback section | `grep -q '^## Rollback'` passes; `grep -q 'CUTV-06'` passes |
| `## Archiving v1` H2 with 3-step rename procedure (`.archive` suffix; never delete) | `docs/MIGRATION.md` Archiving v1 section | `grep -q '^## Archiving v1'` passes; references `docs/CUTOVER.md` per-machine state |
| Cross-references to `docs/MANIFEST.md`, `docs/CUTOVER.md`, `docs/SECURITY.md` | `docs/MIGRATION.md` | all three substrings found via grep |
| Root `README.md` H1 `# dotfiles` (no emoji, replaces v1 emoji header) | `README.md` line 1 | `head -1 README.md` returns `# dotfiles` |
| README H2 sections: What This Is / Fresh Machine Setup / Where to Add Things / Documentation | `README.md` H2 headings | all four found |
| README Fresh Machine Setup fenced block with the required 5 commands including `task cutover:ack` (procedure-correctness gate) | `README.md` Fresh Machine Setup | `grep -A 10 'Fresh Machine Setup' README.md | grep -q 'task cutover:ack'` passes |
| README Where to Add Things table mirrors CLAUDE.md Adding table (8 rows: alias, function, machine, brew package, macos defaults, feature flag, tool config, Claude hook) | `README.md` Where to Add Things | `grep -E '^\|'` shows the 8 mirrored rows + header + separator |
| README Documentation bullet list with one-line descriptions for all six target docs | `README.md` Documentation | all six paths present (`docs/MANIFEST.md`, `docs/SECURITY.md`, `docs/CUTOVER.md`, `docs/MIGRATION.md`, `docs/MACHINES.md`, `.claude/CLAUDE.md`) |
| Both files contain zero emojis and zero AI attribution | `docs/MIGRATION.md` + `README.md` | `ggrep -P` BMP-emoji scan returns 0; `Co-Authored-By`/`Generated by`/`Generated with` greps return 0 |
| README contains zero v1 vocabulary (no DOTFILES_PROFILE; no "profile suffix" phrase) | `README.md` | both anti-grep checks pass; v1 history fully delegated to MIGRATION.md |

## Implementation Walkthrough

### Task 1: Create docs/MIGRATION.md

Wrote `docs/MIGRATION.md` in a single Write tool call following the D-13 + 08-PATTERNS.md `docs/MIGRATION.md (new, P5)` structural template:

- H1 `# Migration Guide: v1 to v2`
- H2 `## What This Is` -- a single-paragraph framing of the doc's use cases (read top-to-bottom on first cutover, grep-by-old-path on later visits) followed by a CUTV-06 archive-not-delete reminder so the operator knows v1 stays on disk during the cutover window.
- Seven concept H2 sections in the exact D-13 order:
  1. `## Profile suffix -> Machine manifest` -- narrates the v1 profile-variable + filename-suffix scheme and the v2 manifest-driven model; cites `docs/MANIFEST.md` for the schema. Path table has 4 rows mapping common v1 paths to v2 equivalents.
  2. `## Antigen -> Antidote` -- captures the plugin-manager swap and the v1 prompt port-as-is decision. Path table has 3 rows.
  3. `## Brewfile-<profile>.rb -> packages/<purpose>.rb + extra_packages` -- explains the bundle/purpose split and the cask isolation rationale (server machines decline gui bundle). Path table has 3 rows.
  4. `## zsh/ -> shell/ (flat layout)` -- captures the platform-nesting collapse and the deferred-Linux acknowledgement. Path table has 5 rows.
  5. `## gsd-install -> sentinel-gated claude:gsd + explicit claude:update` -- narrates the v1 always-runs npx pattern and the v2 sentinel-idempotency split. Path table has 3 rows.
  6. `## Hostname-based Match exec -> manifest-driven identity gates` -- documents the `.zprofile:55-56` literal-`"server"` bug class and the v2 manifest-`[identity]`-driven replacement; cites `docs/SECURITY.md` for the key-handling context. Path table has 4 rows.
  7. `## macos:shell $BREW_ZSH -> {{.BREW_ZSH}}` -- captures the LINT-02 bug class (shell vars in status: blocks always render empty) and the v2 template-var fix that LINT-02 enforces structurally. Path table has 2 rows.
- `## Rollback` H2 -- 4-step non-destructive procedure: stop using v2 -> rm state files under $XDG_STATE_HOME -> re-source v1 zsh from the still-on-disk v1 repo -> record regression in `docs/CUTOVER.md` per-machine state column. Cites CUTV-06 archive-not-delete explicitly.
- `## Archiving v1` H2 -- 3-step terminal procedure after the last machine reaches cut-over: rename v1 directory with `.archive` suffix -> push v1 branch tip to `archive/v1` remote ref -> update `docs/CUTOVER.md` per-machine state column to `archived`.

All commands are formatted as inline code. Tables use the standard markdown `| Old (v1) | New (v2) |` two-column form. Heading depth strictly limited to H1 + H2. No emojis, no AI attribution.

**Commit:** `eec8ffd`

### Task 2: Replace README.md

Overwrote `README.md` entirely (the existing v1 emoji-heavy file at lines 1-76 was discarded; no content survived). Wrote the v2 replacement in a single Write tool call following the D-15 + 08-PATTERNS.md `README.md (root replacement, P6)` structural template:

- H1 `# dotfiles` (no emoji; the v1 H1 with a man-technologist emoji prefix is gone).
- H2 `## What This Is` -- two paragraphs framing the v2 manifest model. Paragraph 1 introduces go-task + manifest-driven TOML + XDG layout and points new readers at `docs/MANIFEST.md` for the schema and `docs/MIGRATION.md` for historical context. Paragraph 2 walks through the per-machine TOML + defaults inheritance + resolver compile-to-JSON model, with the explicit-`task setup` claim and the no-hostname-inference claim.
- H2 `## Fresh Machine Setup` -- one short prose paragraph stating that the `task cutover:ack` step is required (not optional), followed by a fenced `zsh` code block with exactly the 5 commands in order: `git clone <repo-url>` -> `./bootstrap.zsh` -> `task setup -- <machine-name>` -> `task cutover:ack -- <machine-name>` -> `task install`. Below the block, a closing paragraph cites `docs/CUTOVER.md` section "Fresh-machine verification" for the full procedure (soak window, state tracking) and `docs/MACHINES.md` for the per-machine name list and context.
- H2 `## Where to Add Things` -- a markdown table with three columns (`Adding | Where | Naming`) and eight rows mirroring the project `CLAUDE.md` Adding table exactly: alias, function, new machine, brew package, macOS defaults concern, feature flag, tool config, Claude hook.
- H2 `## Documentation` -- a flat bullet list with one-line descriptions for all six target docs (`docs/MANIFEST.md`, `docs/SECURITY.md`, `docs/CUTOVER.md`, `docs/MIGRATION.md`, `docs/MACHINES.md`, `.claude/CLAUDE.md`).

Heading depth strictly limited to H1 + H2. No emojis (the v1 README had emojis in every H2 -- those are explicitly gone). No AI attribution. No `DOTFILES_PROFILE` substring anywhere; no "profile suffix" phrase (an initial draft used the phrase in the framing paragraph as historical context, but the acceptance criterion is strict and v1 history is fully delegated to MIGRATION.md per the plan's Action text -- corrected pre-commit during the acceptance-verify pass; see Decisions Made).

**Commit:** `d0e9ecc`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keep the seven D-13 concepts in the exact order listed in CONTEXT.md | The CONTEXT.md ordering is the authoritative narrative spine -- identity-of-state first (profile suffix), then runtime layers (Antigen / Brewfile / zsh /), then operational details. Reordering alphabetically or by impact-ranking would obscure the operator's mental model. |
| Rollback uses only non-destructive operations (rm on state files only; v1 stays on disk) | Matches CUTV-06 archive-not-delete intent and the plan's threat-register entry T-08-15. Operator can re-cut by running `task cutover:ack` again; rollback is fully reversible. |
| Archive procedure uses `.archive` directory-suffix on the v1 rename | Suffix is reversible by literal rename-back; suffix is grep-friendly for an operator running a one-liner audit ("which machines still have v1?"); matches project convention that 'archive' is reversible state distinct from 'deleted'. |
| README 'What This Is' framing does NOT itself use v1 vocabulary | Acceptance criterion is strict mechanical match (`! grep -q 'DOTFILES_PROFILE'`); v1 history is fully delegated to MIGRATION.md so the README stays a v2-only tutorial. Initial draft used the substring in framing -- corrected pre-commit during the acceptance-verify pass. |
| README Fresh Machine Setup fenced block uses `zsh` fence label | Matches project convention (docs/CUTOVER.md step 1, shell/README.md fences). The accept criteria don't specify a label but consistency with sibling docs argues for `zsh`. |
| README Documentation section is a bullet list, not a table | Plan Action text specifies "bullet list of doc pointers with one-line descriptions"; bullets stay scannable and match the 'thin doc with pointers' style of `docs/README.md`. |

## Deviations from Plan

None. The plan executed exactly as written.

**Pre-commit refinements documented (not deviations):**

- An initial draft of the README "What This Is" framing paragraph used the substring `DOTFILES_PROFILE` to position v2 against v1. The acceptance criterion is a strict mechanical anti-pattern grep (`! grep -q 'DOTFILES_PROFILE' README.md`), so the substring was removed before commit. v1 history is fully delegated to `docs/MIGRATION.md`; the README stays v2-only per the plan's Action text. This catch happened during the post-Write acceptance-verify pass, before the commit -- not a post-commit Rule 1 deviation.

## Pre-existing Issues NOT Fixed

This plan is docs-only and modifies no taskfiles, scripts, or repo machinery. The carry-forward debt list from 08-01-SUMMARY, 08-02-SUMMARY, 08-03-SUMMARY, 08-04-SUMMARY is unchanged:

1. **`task lint` exit code 201** -- 14 LINT-03a + 4 LINT-03b violations in pre-Phase-7 taskfiles. No taskfile changes in this plan; lint state unchanged.
2. **Root-scope `DOTFILEDIR` pollution from include-merge** -- documented carry-forward debt from 08-02-SUMMARY decision #2 and Rule 3 fix #3. No Taskfile.yml changes in this plan.
3. **Three bare-form `deps: [manifest:resolve]` in `taskfiles/claude.yml`** -- documented carry-forward debt from 08-02-SUMMARY. No claude.yml changes in this plan.

## Known Stubs

None. Both files deliver complete, working content per their D-13 and D-15 contracts. The MIGRATION.md path tables are populated with real v1 paths from the v1 architecture survey (ARCHITECTURE.md / CONCERNS.md as the v1 "before" source) mapped to real v2 paths from the implemented taskfile/shell/identity surface. The README's where-to-add table mirrors CLAUDE.md Adding rows verbatim; the documentation bullet list points at real existing files (MANIFEST.md / SECURITY.md / CUTOVER.md / MIGRATION.md / MACHINES.md / .claude/CLAUDE.md all confirmed on disk).

## Threat Flags

None beyond the threat model the plan documented (T-08-15 through T-08-18, T-08-SC):

- **T-08-15 (Tampering on MIGRATION.md rollback steps):** mitigated. Rollback uses only non-destructive operations: `rm` on machine-local state files under `$XDG_STATE_HOME` (`machine` + `cutover-ack`), never on the v1 repo. v1 stays installed per CUTV-06; rollback can be reverted by re-running `task cutover:ack`. Verified at the verb level inside the Rollback section: only `rm` and `record-in-CUTOVER.md` actions, no `rm -rf`, no v1-repo file deletions.
- **T-08-16 (Information disclosure in README.md examples):** accepted. The fenced fresh-machine block uses `<repo-url>` and `<machine-name>` as placeholders -- no secrets, no internal URLs, no real machine names appear in the fenced block. The Documentation bullet list contains repo-relative doc paths only.
- **T-08-17 (Spoofing -- wrong first-impression README):** mitigated. The v1 emoji-heavy README is replaced ENTIRELY; structural anti-tests verified: zero emojis (BMP-emoji ggrep returns 0); no `DOTFILES_PROFILE` substring; no "profile suffix" phrase; no `cd dotfiles && zsh bootstrap.zsh` v1 install pattern; no H2 line beginning with an emoji character.
- **T-08-17b (Tampering -- README fresh-machine block missing `task cutover:ack`):** mitigated by the procedure-correctness acceptance gate. `grep -A 10 'Fresh Machine Setup' README.md | grep -q 'task cutover:ack'` exits 0 -- the cutover:ack step is in the fenced block; without it the install: precondition gate would hard-fail on a fresh machine and the documented procedure would be objectively broken.
- **T-08-18 (Repudiation -- path-mapping tables drift from reality):** accepted per plan; doc-drift class. Each row in the seven concept mapping tables was cross-checked against the v1 ARCHITECTURE.md survey for the "old" column and against the v2 CLAUDE.md + shipped taskfile/shell/identity surface for the "new" column. Operator confirms each row against the actual repo during cutover; tables are a snapshot, not a runtime invariant.
- **T-08-SC (Package install supply chain):** N/A -- docs-only plan, no installs.

This plan adds no new attack surface. Both files are pure documentation under the same trust boundary as the rest of the repo (committed in git, read by operators and AI agents). No new network endpoints, auth paths, file access patterns, or trust-boundary surface introduced.

## Commits

| Task | Hash | Summary |
|------|------|---------|
| 1 | `eec8ffd` | add v1-to-v2 migration guide with rollback and archive sections |
| 2 | `d0e9ecc` | replace v1 emoji README with v2 tutorial walkthrough |

## Verification Snapshot

```bash
# Both files exist + targets
$ test -f docs/MIGRATION.md && test -f README.md && echo "both exist"
both exist

# MIGRATION.md required headings (H1 + 7 concept H2s + Rollback + Archiving v1)
$ grep -E '^# Migration Guide: v1 to v2|^## ' docs/MIGRATION.md
# Migration Guide: v1 to v2
## What This Is
## Profile suffix -> Machine manifest
## Antigen -> Antidote
## Brewfile-<profile>.rb -> packages/<purpose>.rb + extra_packages
## zsh/ -> shell/ (flat layout)
## gsd-install -> sentinel-gated claude:gsd + explicit claude:update
## Hostname-based Match exec -> manifest-driven identity gates
## macos:shell $BREW_ZSH -> {{.BREW_ZSH}}
## Rollback
## Archiving v1

# MIGRATION.md cross-references
$ for d in docs/MANIFEST.md docs/CUTOVER.md docs/SECURITY.md; do
    grep -q "$d" docs/MIGRATION.md && echo "OK: $d"
  done
OK: docs/MANIFEST.md
OK: docs/CUTOVER.md
OK: docs/SECURITY.md

# MIGRATION.md CUTV-06 rollback rationale citation
$ grep -q 'CUTV-06' docs/MIGRATION.md && grep -q 'archive-not-delete' docs/MIGRATION.md && echo "OK: rollback rationale"
OK: rollback rationale

# MIGRATION.md table-row count (>= 7 minimum; 1 minimum per concept)
$ grep -c '^|' docs/MIGRATION.md
38

# README.md H1 + H2 sections
$ head -1 README.md
# dotfiles
$ grep -E '^## ' README.md
## What This Is
## Fresh Machine Setup
## Where to Add Things
## Documentation

# README.md procedure-correctness gate (the load-bearing acceptance check)
$ grep -A 10 'Fresh Machine Setup' README.md | grep -q 'task cutover:ack' && echo "OK: cutover:ack in setup block"
OK: cutover:ack in setup block

# README.md fresh-machine fenced block contents
$ awk '/^## Fresh Machine Setup/,/^## Where to Add Things/' README.md | grep -E '^(git|\.|task)'
git clone <repo-url>
./bootstrap.zsh
task setup -- <machine-name>
task cutover:ack -- <machine-name>
task install

# README.md doc pointers (all six)
$ for d in docs/MANIFEST.md docs/SECURITY.md docs/CUTOVER.md docs/MIGRATION.md docs/MACHINES.md .claude/CLAUDE.md; do
    grep -q "$d" README.md && echo "OK: $d"
  done
OK: docs/MANIFEST.md
OK: docs/SECURITY.md
OK: docs/CUTOVER.md
OK: docs/MIGRATION.md
OK: docs/MACHINES.md
OK: .claude/CLAUDE.md

# README.md zero v1 vocabulary (anti-pattern grep)
$ ! grep -q 'DOTFILES_PROFILE' README.md && echo "OK: no DOTFILES_PROFILE"
OK: no DOTFILES_PROFILE
$ ! grep -q -i 'profile suffix' README.md && echo "OK: no 'profile suffix'"
OK: no 'profile suffix'
$ ! grep -q 'cd dotfiles && zsh bootstrap.zsh' README.md && echo "OK: no v1 install pattern"
OK: no v1 install pattern

# Neither file contains emojis (BMP-emoji ggrep)
$ ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/MIGRATION.md README.md
(no output -- no matches)

# Neither file contains AI attribution
$ for s in 'Co-Authored-By' 'Generated by' 'Generated with'; do
    if grep -l "$s" docs/MIGRATION.md README.md 2>/dev/null; then
      echo "FAIL: $s"
    else
      echo "OK: no $s"
    fi
  done
OK: no Co-Authored-By
OK: no Generated by
OK: no Generated with
```

## Self-Check: PASSED

**Files created/modified verified:**

```bash
$ [ -f docs/MIGRATION.md ] && echo "FOUND: docs/MIGRATION.md"
FOUND: docs/MIGRATION.md
$ [ -f README.md ] && echo "FOUND: README.md"
FOUND: README.md
```

**Commits verified:**

```bash
$ for h in eec8ffd d0e9ecc; do
    git log --oneline --all | grep -q "$h" && echo "FOUND: $h" || echo "MISSING: $h"
  done
FOUND: eec8ffd
FOUND: d0e9ecc
```
