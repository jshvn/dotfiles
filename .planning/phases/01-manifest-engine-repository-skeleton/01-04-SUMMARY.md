---
phase: 01-manifest-engine-repository-skeleton
plan: "04"
subsystem: docs
tags: [docs, claude-md, manifest-md, stub-readme, repository-skeleton]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [DOCS-03, DOCS-04, D-09-skeleton]
  affects: []
tech_stack:
  added: []
  patterns: [hand-authored-project-instructions, schema-reference-doc, stub-readme-template]
key_files:
  created:
    - CLAUDE.md (replaced)
    - docs/MANIFEST.md
    - docs/README.md
    - shell/README.md
    - identity/README.md
    - packages/README.md
    - configs/README.md
    - os/README.md
  modified: []
decisions:
  - "CLAUDE.md is hand-authored v2 conventions document; GSD auto-generation markers stripped permanently"
  - "docs/MANIFEST.md uses actual Plan 01 fixture files and Plan 02 manifest files as worked examples (not synthetic data)"
  - "Stub READMEs use exact template from RESEARCH §8.2 with verbatim per-directory binding"
metrics:
  duration: ~15min
  completed: "2026-05-13"
  tasks_completed: 2
  files_modified: 8
---

# Phase 01 Plan 04: Documentation and Repository Skeleton Summary

Replaced the auto-generated v1 `CLAUDE.md` with the hand-authored v2 conventions document. Authored `docs/MANIFEST.md` — the schema/merge/walkthrough reference every downstream phase links into. Created five stub READMEs that materialize the full v2 directory skeleton (D-09, D-10, D-11). Created `docs/README.md` directory index.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Replace repo-root CLAUDE.md with v2 conventions document | db4d513 |
| 2 | Author docs/MANIFEST.md, docs/README.md, and five stub READMEs | 0ced29c |

## What Was Built

### CLAUDE.md (replaced)

The v1 auto-generated file (with `<!-- GSD:project-start -->` markers, v1 profile references, and Antigen mentions) was wholesale replaced with the v2 conventions document. The new file covers:

- The manifest model (keystone table with source files, compiled output, and active machine paths)
- Nine rules: manifests as source of truth; one concept per file; flat directories in v1; kebab-case `index` access for feature keys; status-block template vars; `set -euo pipefail`; no hardcoded Homebrew paths; `_:safe-link` only; XDG everywhere
- "Where to Add Things" table (8 rows: alias, function, machine, brew package, macOS defaults, feature flag, tool config, Claude hook)
- Tooling version floors (yq >= 4.52.1, go-task >= 3.37, jq >= 1.7)
- Don't Do list and GSD workflow entry points

### docs/MANIFEST.md

416-line schema reference document with all required sections:
- Schema section with side-by-side `defaults.toml` and `personal-laptop.toml` examples
- Required fields table (7 rows, per D-03) and optional fields table
- Merge Semantics section with rules table and six worked examples drawn from actual Plan 01 fixtures
- "Adding a New Machine" seven-step walkthrough
- CLI Reference table with Phase 1 invocation note (`task -t taskfiles/manifest.yml ...`)
- State Files table
- Feature-Flag Reference table seeded with all Phase 1 features
- Known Limitations (v1) section

### docs/README.md

5-line directory index listing MANIFEST.md (Phase 1), SECURITY.md (Phase 2), and MIGRATION.md / MACHINES.md / CUTOVER.md (Phase 8).

### Five stub READMEs

Each follows the verbatim template from RESEARCH §8.2. All are under 12 lines per D-11.

| File | Phase | Requirements |
|------|-------|--------------|
| `shell/README.md` | 3 | SHEL-01..SHEL-12, DOCS-02 |
| `identity/README.md` | 4 | IDNT-01..08 |
| `packages/README.md` | 5 | PKGS-01..05, VRFY-01..04 |
| `configs/README.md` | 7 | TOOL-01..04 |
| `os/README.md` | 6 | OSCF-01..05 |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

The five stub READMEs (`shell/`, `identity/`, `packages/`, `configs/`, `os/`) are intentional D-11 deliverables, not accidental stubs. Each is a placeholder that will be replaced by the appropriate phase. This plan's goal is specifically to create these stubs to materialize the full D-09 skeleton.

## Self-Check: PASSED

Files verified:

- `CLAUDE.md` — exists, 164 lines (>= 80, <= 350)
- `docs/MANIFEST.md` — exists, 416 lines (>= 100, <= 600)
- `docs/README.md` — exists
- `shell/README.md` — exists, 10 lines (<= 12)
- `identity/README.md` — exists, 10 lines (<= 12)
- `packages/README.md` — exists, 10 lines (<= 12)
- `configs/README.md` — exists, 10 lines (<= 12)
- `os/README.md` — exists, 10 lines (<= 12)

Commits verified:

- db4d513 — `docs(01-04): replace v1 CLAUDE.md with v2 conventions document`
- 0ced29c — `docs(01-04): add MANIFEST.md, docs index, and five stub READMEs`

DOCS-03 anchor: `test -f CLAUDE.md && grep -q "manifest model" CLAUDE.md` — PASS
DOCS-04 anchor: `test -f docs/MANIFEST.md && grep -q "## Merge Semantics" docs/MANIFEST.md && grep -q "## Adding a New Machine" docs/MANIFEST.md` — PASS
