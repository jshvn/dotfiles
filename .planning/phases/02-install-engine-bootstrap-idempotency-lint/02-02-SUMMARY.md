---
phase: 02-install-engine-bootstrap-idempotency-lint
plan: "02"
subsystem: taskfiles
tags: [stub, taskfile, install-engine, call-graph]
dependency_graph:
  requires:
    - 02-01 (lint.yml -- LINT-03a structural check that validates these stubs)
  provides:
    - taskfiles/links-stub.yml (Phase 3 SHEL-01..03 placeholder)
    - taskfiles/brew-stub.yml (Phase 5 PKGS-01..05, VRFY-01..04 placeholder)
    - taskfiles/claude-stub.yml (Phase 7 CLDE-01..04 placeholder)
    - taskfiles/macos-stub.yml (Phase 6 OSCF-01..05 placeholder)
  affects:
    - 02-04 (Taskfile.yml root -- includes these stubs in the call graph)
tech_stack:
  added: []
  patterns:
    - stub-taskfile (status: [true] idempotent no-op with STUB marker + stderr trace)
    - go-task v3 taskfile structure (version/header/tasks)
key_files:
  created:
    - taskfiles/links-stub.yml
    - taskfiles/brew-stub.yml
    - taskfiles/claude-stub.yml
    - taskfiles/macos-stub.yml
  modified: []
decisions:
  - Stubs use status: [true] so LINT-03a passes structurally without exempting them
  - desc: starts with "STUB (Phase N" so grep -r 'STUB (Phase ' taskfiles/ enumerates outstanding work
  - cmds: block emits a single stderr trace line per RESEARCH §4.1 visible-trace pattern
  - No vars:, includes:, or internal: -- stubs are intentionally minimal; phases replace the file wholesale
metrics:
  duration: "79s"
  completed: "2026-05-14"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 02 Plan 02: Stub Taskfiles for v2 Call Graph Summary

Four stub taskfiles providing the complete `task install` call graph for Phase 2: `links-stub.yml`, `brew-stub.yml`, `claude-stub.yml`, and `macos-stub.yml`, each structurally lint-clean with `status: [true]` and `STUB (Phase N)` grep markers.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author taskfiles/links-stub.yml and taskfiles/brew-stub.yml | af5e3db | taskfiles/links-stub.yml, taskfiles/brew-stub.yml |
| 2 | Author taskfiles/claude-stub.yml and taskfiles/macos-stub.yml | e770042 | taskfiles/claude-stub.yml, taskfiles/macos-stub.yml |

## Verification Results

All plan verification checks pass:

- All four stub files exist under `taskfiles/`
- All five stub tasks (`links:all`, `brew:install`, `claude:install`, `macos:defaults`, `macos:shell`) have `status: [true]`
- All five `desc:` lines start with `STUB (Phase`
- `grep -r 'STUB (Phase ' taskfiles/ | wc -l` returns 5 (one per stub task)
- Each stub parses with `task --list-all --json` with zero errors

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

These files ARE the stubs. By design:

| File | Task | Reason | Resolution Phase |
|------|------|--------|-----------------|
| taskfiles/links-stub.yml | all | Placeholder until Phase 3 ships links.yml | Phase 3 (SHEL-01..03) |
| taskfiles/brew-stub.yml | install | Placeholder until Phase 5 ships brew.yml | Phase 5 (PKGS-01..05, VRFY-01..04) |
| taskfiles/claude-stub.yml | install | Placeholder until Phase 7 ships claude.yml | Phase 7 (CLDE-01..04) |
| taskfiles/macos-stub.yml | defaults | Placeholder until Phase 6 ships macos.yml | Phase 6 (OSCF-01..03, OSCF-05) |
| taskfiles/macos-stub.yml | shell | Placeholder until Phase 6 ships macos.yml | Phase 6 (OSCF-04) |

All stubs are intentional and tracked. The plan goal (complete call graph for Plan 02-04's Taskfile.yml) is fully achieved.

## Self-Check: PASSED

Files confirmed present:
- taskfiles/links-stub.yml: FOUND
- taskfiles/brew-stub.yml: FOUND
- taskfiles/claude-stub.yml: FOUND
- taskfiles/macos-stub.yml: FOUND

Commits confirmed:
- af5e3db: FOUND (feat(02-02): add links-stub.yml and brew-stub.yml)
- e770042: FOUND (feat(02-02): add claude-stub.yml and macos-stub.yml)
