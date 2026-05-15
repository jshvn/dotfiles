---
phase: 04-identity-layer-git-ssh-per-machine
plan: "03"
subsystem: manifest-test-coverage
tags: [test, negative-fixtures, validator-coverage, manifest-test]
dependency_graph:
  requires: [five-value-identity-enum, cross-field-validation]
  provides: [negative-fixture-coverage-for-d05-d16, manifest-test-five-of-five-failure-paths]
  affects: []
tech_stack:
  added: []
  patterns: [neg-copies-cleanup-trap, fixture-isolated-failure-mode]
key_files:
  created:
    - manifests/test/fixtures/_invalid-identity-without-opssh/machine.toml
    - manifests/test/fixtures/_invalid-identity-without-opsign/machine.toml
    - manifests/test/fixtures/_invalid-bad-identity/machine.toml
  modified:
    - taskfiles/manifest.yml
decisions:
  - "D-05: enum rejection covered by _invalid-bad-identity (alice value)"
  - "D-16: cross-field opssh covered by _invalid-identity-without-opssh"
  - "D-16: cross-field opsign covered by _invalid-identity-without-opsign"
metrics:
  duration: "~5 minutes (inline orchestrator execution after worktree-agent permission failure)"
  completed: "2026-05-15T04:45:00Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 04 Plan 03: Negative Test Fixture Coverage Summary

Authored three new negative test fixtures and extended `manifest:test` so the resolver's Plan 01 cross-field rules and expanded enum are covered by automated tests. With the pre-existing `_invalid-missing-desc` and `_invalid-bad-os` fixtures, `manifest:test` now exercises all five validator failure paths (6 positive + 5 negative = 11 fixtures total).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author three negative-fixture TOML files | 8e806e9 | manifests/test/fixtures/_invalid-identity-without-opssh/machine.toml, manifests/test/fixtures/_invalid-identity-without-opsign/machine.toml, manifests/test/fixtures/_invalid-bad-identity/machine.toml |
| 2 | Extend manifest:test with three new negative-fixture blocks; negative_count 2 -> 5 | c3904e1 | taskfiles/manifest.yml |

## What Was Built

### Task 1: Three negative fixtures

Each fixture isolates exactly one validator failure mode by declaring every other required field correctly:

- **_invalid-identity-without-opssh** -- `identity.ssh = "personal"` with `one-password-ssh = false` and `one-password-signing = true`. Trips ONLY the D-16 opssh cross-field rule; resolver stderr contains `one-password-ssh`.
- **_invalid-identity-without-opsign** -- `identity.git = "personal"` with `one-password-signing = false` and `one-password-ssh = true`. Trips ONLY the D-16 opsign cross-field rule; resolver stderr contains `one-password-signing`.
- **_invalid-bad-identity** -- `identity.ssh = "alice"` (not in the five-value enum). Trips D-05 enum rejection; resolver stderr contains `server-1|server-2|none`.

All three are valid TOML (yq parses each).

### Task 2: manifest:test extension

Inserted three new fixture blocks after the existing `_invalid-bad-os` block, each in the exact `neg_copies+=()`/cp/resolver/rm/grep shape used by the existing two blocks (CR-01 contract: `neg_copies` registers BEFORE `cp`, so the EXIT trap cleans up even if cp fails). Bumped `negative_count` from 2 to 5.

## Verification Results

`task manifest:test` output:

| Fixture | Status |
|---------|--------|
| 01-map-over-map through 06-extra-packages-concat | 6 PASS (positive) |
| _invalid-missing-desc | PASS (meta.description in stderr) |
| _invalid-bad-os | PASS (darwin in stderr) |
| _invalid-identity-without-opssh | PASS (one-password-ssh in stderr) |
| _invalid-identity-without-opsign | PASS (one-password-signing in stderr) |
| _invalid-bad-identity | PASS (expanded enum in stderr) |
| Summary | `fixtures: 11 total, 11 passed, 0 failed` |
| Post-run leak check | `find manifests/machines -name "_invalid-*"` returns 0 |

## Deviations from Plan

### Inline orchestrator execution

The wave-2 worktree agent reported losing Bash access mid-execution before committing Task 1. The orchestrator verified the fixture files were present and well-formed in the main tree (the agent's Write calls had succeeded under a Read-precondition glitch), ran the resolver against each fixture to confirm the expected stderr fragments, then committed Task 1 (`8e806e9`) and applied Task 2's `manifest.yml` edits directly (`c3904e1`).

## Known Stubs

None.

## Threat Flags

None. Tests are read-only against fixtures + a controlled cp/rm into `manifests/machines/` that the EXIT trap cleans up; no new code paths, network endpoints, or trust-boundary changes.

## Self-Check: PASSED

All four key files exist; both task commits are reachable in `git log`; `manifest:test` reports 11/11 pass.
