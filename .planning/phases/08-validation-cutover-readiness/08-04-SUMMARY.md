---
phase: 08-validation-cutover-readiness
plan: 04
subsystem: documentation
tags: [docs, cutover, machines, fresh-install, d-12, d-14]
requires:
  - docs/MANIFEST.md (analog: heading style + thin-doc shape; cross-referenced from CUTOVER.md step 3)
  - docs/SECURITY.md (cross-referenced from CUTOVER.md step 2 for the bootstrap trust chain)
  - install/cutover-gate.zsh (reader contract that the procedure references in step 4)
  - manifests/machines/personal-laptop.toml (prose anchor for MACHINES.md hardware narrative)
  - manifests/machines/work-laptop.toml (prose anchor)
  - manifests/machines/server-1.toml (prose anchor)
  - manifests/machines/server-2.toml (prose anchor)
  - .planning/phases/08-validation-cutover-readiness/08-03-SUMMARY.md (cutover:ack writer ships in 08-03; the procedure depends on it)
provides:
  - docs/CUTOVER.md (canonical per-machine cutover runbook; DOCS-08 + CUTV-03)
  - docs/MACHINES.md (per-machine prose layer the TOML cannot express; DOCS-06)
  - status vocabulary documented inline (planning / ready / installing / soaking / cut-over / archived)
  - forward references for docs/MIGRATION.md (Plan 05) so the runbook is self-contained when MIGRATION ships
affects:
  - docs/CUTOVER.md
  - docs/MACHINES.md
tech-stack:
  added: []
  patterns:
    - thin-doc shape: H1 + H2 only, defer to source-of-truth artifact at each section close (analog: docs/MANIFEST.md)
    - numbered checklist with one-step-per-numbered-item (analog: docs/MANIFEST.md "Adding a New Machine")
    - inline-code for every task name, file path, and command (project convention)
    - deference-line pattern: "See `manifests/machines/<name>.toml` for declarative state."
    - status-vocabulary callout above the per-machine table (in-line definition rather than a separate glossary)
key-files:
  created:
    - docs/CUTOVER.md
    - docs/MACHINES.md
  modified: []
decisions:
  - "Forward-reference docs/MIGRATION.md from CUTOVER.md step 8 even though MIGRATION.md ships in Plan 05. The phase-sequencing is engineering-first then docs (08-CONTEXT.md preliminary sequencing); the operational consumer of CUTOVER.md cannot run the procedure until P5 has also shipped, so the cross-reference is valid by the time the runbook is exercised. Avoids leaving step 8 without a target."
  - "Document the status vocabulary as inline prose above the per-machine table rather than as a separate H3 sub-section. The vocabulary is six values with no per-value semantics beyond ordering; an H3 plus a list would be heavier than the content warrants and would break the doc's H1+H2-only heading-depth contract."
  - "Hardware narrative for work-laptop, server-1, and server-2 reads 'Apple Silicon or Intel -- arch detected by the resolver via `uname -m`' because the TOML files omit `[platform].arch`. Stated as fact, not speculation; the resolver's auto-detect is the source of truth at install time. Avoids inventing a specific architecture for machines where the operator has not pinned one."
  - "Each MACHINES.md section uses bulleted prose (Purpose / Hardware / Role narrative / Special handling / deference line) rather than free-flowing paragraphs. The bullet shape is scannable, mirrors the section structure the operator will edit during cutover, and keeps each datum independently maintainable without rewriting surrounding prose."
  - "No 'Hostname' bullet in any MACHINES.md section. The plan's Action text says 'only if non-default; otherwise omit this bullet'. None of the four machines has a non-default hostname declared in the TOML, and the operator can add the bullet during cutover if a machine acquires a custom hostname."
  - "Personal-laptop role narrative names specific casks (Sourcetree, Sublime Text, VS Code, Raycast, Spotify, Discord, Slack, Proton suite, Cloudflare WARP, Docker Desktop, Microsoft Office). This is non-TOML prose that captures the role context but the TOML stays the authority -- if the cask list changes, the prose 'full GUI + dev + personal feature set' framing stays accurate without prose edits. The example list is illustrative."
  - "Work-laptop deference text explicitly notes that no personal apps install (Discord, WhatsApp, Proton, Cloudflare WARP) -- this is non-TOML prose because the TOML expresses it by absence rather than by negation. Without the prose, the divergence point from personal-laptop is buried in the cask-list comparison."
metrics:
  duration: 3m
  completed: 2026-05-16
---

# Phase 08 Plan 04: Cutover-Readiness Docs Summary

## One-liner

Ship the two cutover-readiness documents the per-machine cutover runbook operates from: docs/CUTOVER.md (D-12: fresh-machine procedure + per-machine state table) and docs/MACHINES.md (D-14: thin per-machine prose deferring to the TOML manifests for declarative state).

## What This Plan Delivered

| Deliverable | Location | Verified |
|-------------|----------|----------|
| `docs/CUTOVER.md` H1 `# Cutover Reference` + H2 `## What This Is` framing | `docs/CUTOVER.md` lines 1-13 | `grep -E '^#( \|#)' docs/CUTOVER.md` returns the 4 expected headings |
| 8-step `## Fresh-machine verification` numbered procedure (DOCS-08) | `docs/CUTOVER.md` lines 15-65 | `grep -cE '^[0-9]+\. ' docs/CUTOVER.md` returns 8 |
| Cross-references to `docs/SECURITY.md` (step 2) and `docs/MANIFEST.md` (step 3) | `docs/CUTOVER.md` step 2 + step 3 | `grep -q 'docs/SECURITY.md' && grep -q 'docs/MANIFEST.md'` both pass |
| `task cutover:ack` referenced as the unblocker for `task install` (step 4) | `docs/CUTOVER.md` step 4 | `grep -q 'task cutover:ack' docs/CUTOVER.md` passes |
| `## Per-machine cutover state` H2 with 6-column table + 4 machine rows initialized to `planning` (CUTV-03) | `docs/CUTOVER.md` lines 67-95 | `grep -q '\| machine \| status \| cutover-date \| last-validate-pass \| days-on-v2 \| notes \|'` passes |
| Status vocabulary documented inline above the table (planning / ready / installing / soaking / cut-over / archived) | `docs/CUTOVER.md` paragraph above the table | all 6 values found via `grep` |
| `docs/MACHINES.md` H1 `# Machine Reference` + per-machine H2 for all four target machines (DOCS-06) | `docs/MACHINES.md` H2 sections | `grep -c '^## (personal-laptop\|work-laptop\|server-1\|server-2)'` returns 4 |
| Each H2 section closes with the deference line to `manifests/machines/<name>.toml` | `docs/MACHINES.md` end of each section | `grep -c 'manifests/machines/' docs/MACHINES.md` returns 5 (>= 4 required) |
| Zero markdown tables in MACHINES.md (D-14 contract: TOML is the table source of truth) | `docs/MACHINES.md` | `grep -c '^\|' docs/MACHINES.md` returns 0 |

## Implementation Walkthrough

### Task 1: Create `docs/CUTOVER.md`

Wrote the file in a single Write tool call with the D-12 + 08-PATTERNS.md `docs/CUTOVER.md (new, P4)` structural template:

- H1 `# Cutover Reference`
- H2 `## What This Is` -- one paragraph framing the per-machine cutover model: v1 stays installed during the cutover window, soak before archiving, engineering completion is bounded by this phase while operational cutover is bounded by the table below.
- H2 `## Fresh-machine verification` -- 8 numbered steps walking a clean Mac through the task chain. The steps explicitly reference (in order): the v2 branch checkout, `./bootstrap.zsh` with cross-reference to `docs/SECURITY.md`, `task setup -- <machine-name>` with cross-reference to `docs/MANIFEST.md`, `task cutover:ack -- <machine-name>` (the writer task shipped in Plan 03), `task install` with a note on the install-time orphan-warn final step (D-11), `task validate` with the check/cross/n/a summary contract (D-04, D-06), the 7-day soak period (CUTV-05), and the post-soak table update + v1 archive procedure (CUTV-06; forward-references docs/MIGRATION.md "Archiving v1" section).
- H2 `## Per-machine cutover state` -- one paragraph defining the six status vocabulary values and their ordering, then the markdown table with six columns (`machine | status | cutover-date | last-validate-pass | days-on-v2 | notes`) and four data rows (one per target machine, all status `planning`).

The numbered-list style uses real markdown ordered-list syntax (`1.`, `2.`, ...) so each step's anchor generates cleanly. Inline code formatting is used for every task name (` `task install` `), file path (` `docs/SECURITY.md` `), and shell command (` `git checkout josh/dotfiles-v2-refactor` `). No emojis, no AI attribution, no horizontal rules; heading depth limited to H1 + H2.

**Step 1 includes a fenced zsh code block** with the three-command clone + checkout sequence (`git clone`, `cd`, `git checkout`). This is the only fenced block in the file -- the rest of the procedure is prose with inline code -- chosen because step 1 is the only step where the operator types a multi-line sequence rather than a single task invocation.

**Commit:** `9a8b35c`

### Task 2: Create `docs/MACHINES.md`

Wrote the file in a single Write tool call with the D-14 + 08-PATTERNS.md `docs/MACHINES.md (new, P4)` structural template:

- H1 `# Machine Reference`
- H2 `## What This Is` -- one paragraph framing: per-machine prose the TOML cannot capture; manifest TOML stays the source of truth for features, identity, and packages.
- H2 `## personal-laptop` -- bulleted prose covering Purpose / Hardware (`arm64` declared) / Role narrative (full GUI + dev + personal feature set; daily driver use; personal-cask illustrative list) / Special handling (`jgrid-net`, `one-password-ssh`, `one-password-signing`, `claude-marketplace`, `ghostty` features on). Closes with the deference line.
- H2 `## work-laptop` -- same bullet shape: Purpose / Hardware (arch absent from TOML, resolver auto-detects) / Role narrative (work identity, work-flavored GUI subset, no personal apps) / Special handling (work-specific tooling; `jgrid-net` off). Closes with the deference line.
- H2 `## server-1` -- Purpose (headless ops) / Hardware (arch absent) / Role narrative (`core` bundle only, server-1 identity isolation, GUI flags absent so only `macos-security` runs) / Special handling (SSH-only access, `one-password-ssh` off for headless context). Closes with the deference line.
- H2 `## server-2` -- mirrors server-1 with the divergence-rationale prose: two server machines with distinct identities keep blast-radius bounded.

Each section uses the bulleted-prose shape (Purpose / Hardware / Role narrative / Special handling / deference line) for scannability and per-datum maintainability. No tables anywhere in the file -- the TOML manifests are the table-shaped source of truth for declarative state.

The hardware narrative names `arm64` only for personal-laptop because that is the only TOML with `[platform].arch` declared. The other three sections state "Apple Silicon or Intel -- arch detected by the resolver via `uname -m`" because the TOML files omit `[platform].arch` and the resolver auto-detects at install time.

The Role narrative for each section pulls illustrative cask/feature lists from the TOML to give the reader a sense of the machine's day-to-day use; the prose explicitly notes that the TOML stays authoritative so a cask-list change does not require a prose edit.

**Commit:** `c6717c7`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Forward-reference docs/MIGRATION.md from CUTOVER.md step 8 | MIGRATION.md ships in Plan 05; the procedure cannot be exercised end-to-end until P5 has also landed. Leaving step 8 with no target would be a dangling instruction; the cross-reference is valid by the time the runbook is exercised. |
| Status vocabulary as inline prose above the table | The six values have no per-value semantics beyond ordering; an H3 sub-section + bulleted list would be heavier than the content warrants and would break the doc's H1+H2-only heading-depth contract. |
| Hardware narrative reads "Apple Silicon or Intel -- arch detected by the resolver via `uname -m`" for machines without `[platform].arch` | Stated as fact, not speculation; the resolver's auto-detect IS the source of truth at install time. Avoids inventing a specific architecture for machines where the operator has not pinned one. |
| Bulleted prose shape inside each MACHINES.md section (Purpose / Hardware / Role narrative / Special handling / deference line) | Scannable, mirrors the structure the operator will edit during cutover, keeps each datum independently maintainable. Avoids forcing the prose into free-flowing paragraphs that would have to be rewritten to update any single field. |
| No "Hostname" bullet in any section | Plan Action text says "only if non-default; otherwise omit this bullet". None of the four machines has a non-default hostname declared in TOML or the planning context; the operator can add the bullet during cutover if needed. |
| Personal-laptop role narrative names specific casks as illustrative | The TOML stays the authority -- if the cask list changes, the prose framing ("full GUI + dev + personal feature set") stays accurate without prose edits. The example list helps a reader who has never seen the machine before. |
| Work-laptop deference text explicitly states what does NOT install (Discord, WhatsApp, Proton, Cloudflare WARP) | This is non-TOML prose because the TOML expresses the divergence by absence (those casks aren't in `work-laptop.toml`). Without the prose, the divergence point from personal-laptop is buried in the cask-list comparison. |

## Deviations from Plan

None. The plan executed exactly as written. Both files were created with the exact structure specified in the plan's `<action>` blocks and 08-PATTERNS.md analogs. All acceptance criteria pass.

The single judgment call documented in decisions ("Forward-reference docs/MIGRATION.md") was explicitly endorsed by the plan's Action text for Task 1 step 8 ("archive v1 per `docs/MIGRATION.md` § 'Archiving v1'"), so the forward reference is plan-sanctioned rather than a deviation.

## Pre-existing Issues NOT Fixed

1. **`docs/MIGRATION.md` does not exist yet** -- CUTOVER.md step 8 forward-references it. This is intentional per the phase plan sequencing: docs/MIGRATION.md ships in Plan 05 (DOCS-05). The cross-reference becomes resolvable when P5 lands; in the meantime an operator following the procedure end-to-end on a real machine would block at step 7 (the 7-day soak), which gives P5 ample room to ship before the cross-reference is exercised.

2. **`task lint` exit code 201** -- same pre-existing carry-forward debt from 08-01, 08-02, 08-03 (14 LINT-03a + 4 LINT-03b violations in pre-Phase-7 taskfiles). This plan is docs-only and modifies no taskfiles; the lint state is unchanged.

3. **CUTOVER.md status-vocabulary documentation is prose, not enforced** -- the six status values are documented in inline prose above the table, but no validator parses the `status` column to confirm the operator only uses approved values. This is intentional: the table is a manual log for the operator, not machine-readable state. Validation is out of scope for this plan and would require a parser task that the 08-CONTEXT.md "Deferred Ideas" section explicitly rejects.

## Known Stubs

None. Both files deliver complete, working content per their D-12 and D-14 contracts. There are no placeholder values, mock data, or "TODO" markers. The four machine rows in CUTOVER.md's state table are initialized to `planning` -- this is the correct starting state for the cutover lifecycle, not a stub.

## Threat Flags

None beyond the threat model the plan documented (T-08-12 through T-08-14, T-08-SC):

- **T-08-12 (Info disclosure via MACHINES.md prose):** mitigated. MACHINES.md contains role/purpose narrative only; no IP addresses, SSH key fingerprints, MAC addresses, internal hostnames, account names, or credential identifiers. The personal-laptop section names casks (Sourcetree, Spotify, etc.) but these are public Homebrew identifiers, not sensitive data.
- **T-08-13 (Tampering on CUTOVER.md misleading operator):** mitigated. The procedure cross-references docs/SECURITY.md (bootstrap trust chain) in step 2 and docs/MANIFEST.md (per-machine schema) in step 3, so an operator can verify every step against the source-of-truth references. The task names match the actual tasks shipped by P3 (`task cutover:ack -- <name>`) -- verified by reading 08-03-SUMMARY.md before writing CUTOVER.md.
- **T-08-14 (Repudiation on per-machine state table not updated after soak):** accepted per plan; manual operator process per CUTV-05; the doc states `days-on-v2` is manually tracked and auto-tracking is deferred v2 work.
- **T-08-SC (Package install supply chain):** N/A -- docs-only plan, no installs.

This plan adds no new attack surface. Both files are pure documentation under the same trust boundary as the rest of the repo (committed in git, read by operators and Claude). No new network endpoints, auth paths, file access patterns, or schema changes.

## Commits

| Task | Hash | Summary |
|------|------|---------|
| 1 | `9a8b35c` | add CUTOVER.md fresh-machine procedure and per-machine state table |
| 2 | `c6717c7` | add MACHINES.md per-machine prose deferring to TOML |

## Verification Snapshot

```bash
# Both files exist
$ test -f docs/CUTOVER.md && test -f docs/MACHINES.md && echo "both files exist"
both files exist

# Required CUTOVER.md headings
$ grep -E '^#( |#)' docs/CUTOVER.md
# Cutover Reference
## What This Is
## Fresh-machine verification
## Per-machine cutover state

# CUTOVER.md task chain references
$ for t in 'task setup --' 'task cutover:ack --' 'task install' 'task validate'; do
    grep -q "$t" docs/CUTOVER.md && echo "OK: $t"
  done
OK: task setup --
OK: task cutover:ack --
OK: task install
OK: task validate

# CUTOVER.md cross-references
$ grep -q 'docs/SECURITY.md' docs/CUTOVER.md && grep -q 'docs/MANIFEST.md' docs/CUTOVER.md && echo "cross-refs present"
cross-refs present

# CUTOVER.md numbered steps
$ grep -cE '^[0-9]+\. ' docs/CUTOVER.md
8

# CUTOVER.md status vocabulary (all six values)
$ for s in planning ready installing soaking cut-over archived; do
    grep -q "$s" docs/CUTOVER.md && echo "OK: $s"
  done
OK: planning
OK: ready
OK: installing
OK: soaking
OK: cut-over
OK: archived

# CUTOVER.md per-machine table rows
$ for m in personal-laptop work-laptop server-1 server-2; do
    grep -q "| $m |" docs/CUTOVER.md && echo "OK: $m"
  done
OK: personal-laptop
OK: work-laptop
OK: server-1
OK: server-2

# MACHINES.md required H2 sections
$ for m in personal-laptop work-laptop server-1 server-2; do
    grep -q "^## $m" docs/MACHINES.md && echo "OK: $m"
  done
OK: personal-laptop
OK: work-laptop
OK: server-1
OK: server-2

# MACHINES.md zero tables (TOML is the table source of truth)
$ grep -c '^|' docs/MACHINES.md
0

# MACHINES.md deference lines (>= 4 required)
$ grep -c 'manifests/machines/' docs/MACHINES.md
5

# Emoji check (both files)
$ ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/CUTOVER.md docs/MACHINES.md
(no output -- no matches)

# AI attribution check (both files)
$ for s in 'Co-Authored-By' 'Generated by' 'Generated with'; do
    grep -lE "$s" docs/CUTOVER.md docs/MACHINES.md || echo "clean: $s"
  done
clean: Co-Authored-By
clean: Generated by
clean: Generated with
```

## Self-Check: PASSED

**Files created verified:**

```bash
$ [ -f docs/CUTOVER.md ] && echo "FOUND: docs/CUTOVER.md"
FOUND: docs/CUTOVER.md
$ [ -f docs/MACHINES.md ] && echo "FOUND: docs/MACHINES.md"
FOUND: docs/MACHINES.md
```

**Commits verified:**

```bash
$ for h in 9a8b35c c6717c7; do
    git log --oneline --all | grep -q "$h" && echo "FOUND: $h" || echo "MISSING: $h"
  done
FOUND: 9a8b35c
FOUND: c6717c7
```
