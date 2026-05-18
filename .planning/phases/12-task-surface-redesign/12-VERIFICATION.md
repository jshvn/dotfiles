---
phase: 12-task-surface-redesign
verified: 2026-05-18T00:00:00Z
status: passed
score: 12/12 must-haves verified
overrides_applied: 0
---

# Phase 12: Task Surface Redesign Verification Report

**Phase Goal:** Redesign the `task --list` public surface for v2.1 by classifying every task, marking per-component tasks `internal: true`, adding curated public delegate namespaces (`audit:`, `show:`, `refresh:`), renaming pipeline tasks for clarity, and adding banner + lint enforcement.

**Verified:** 2026-05-18
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every public task in today's `task --list` has a classification row in SURFACE.md (SC #1) | VERIFIED | `SURFACE.md` contains 55 rows across 11 namespace tables (Summary table reports 55 classified) — every namespace covered (top-level, claude:, identity:, links:, lint:, macos:, manifest:, packages:, perf:, shell:, test:) |
| 2 | Every rename verdict is applied in the source taskfiles + Taskfile.yml + docs; `task --list` reflects new names (SC #2) | VERIFIED | `task --list` output shows curated names: `audit:links`, `audit:manifest`, `audit:packages`, `refresh:claude`, `shell:startup-time`, `show:claude`, `show:manifest`. No legacy names (`perf:shell`, `links:all`, `claude:status`, `manifest:show`, `packages:audit`, `links:reconcile`) appear |
| 3 | Every "mark-internal" verdict applies `internal: true`; running `task --list` does not show those tasks (SC #3) | VERIFIED | `grep -nE "internal: true"` confirms internal markers on all per-component install/validate tasks: claude.yml (6), identity.yml (8), links.yml (7), macos.yml (8), manifest.yml (4), packages.yml (5), shell.yml (1), test.yml (4), lint.yml (5 sub-checks + banner-parity) |
| 4 | Bare `task` invocation prints curated two-tier banner; README.md + CLAUDE.md reference canonical surface (SC #4) | VERIFIED | `task` outputs the D-12 banner: header "Dotfiles -- common tasks", lists 5 top-level commands (install/setup/validate/test/lint), Diagnostics section names show:*/audit:*/refresh:*, closes with `task --list` hint. README.md:23-59 and CLAUDE.md:23-40 reference the surface as canonical |
| 5 | `task --list` shows only curated public tasks (no `links:*`, `identity:*`, `macos:*`, `packages:*`, `claude:*`, `manifest:*` internal rows leak) | VERIFIED | `task --list` shows: default, install, setup, test, validate, audit:links, audit:manifest, audit:packages, lint:default (alias lint), refresh:claude, shell:startup-time, show:claude, show:manifest — exactly the curated surface |
| 6 | `task --list-all` exits 0 (graph parse gate) | VERIFIED | `task --list-all 2>&1 > /dev/null; echo $?` → 0. (Note: go-task 3.51.1's `--list-all` shows tasks with-or-without descriptions, NOT internal tasks; internal still hidden) |
| 7 | `task validate` exits 0 end-to-end after the aggregator dispatches via `task:` keyword (3cd756d fix) | VERIFIED | `task validate` runs all 7 per-component validates and exits 0. Aggregator uses `- task: <ns>:validate` with `ignore_error: true` (Taskfile.yml:195-209), bypassing go-task's CLI-level internal gate |
| 8 | `task install` succeeds end-to-end on idempotent re-run | VERIFIED | `task install` exits 0; pipeline calls `links:install`, `packages:install`, `claude:install`, `macos:install`, `packages:verify`, `audit:links --warn-only`, ending with `success "install complete"` |
| 9 | `task lint:banner-parity` rule exists and is invoked by `task lint` (D-13) | VERIFIED | `taskfiles/lint.yml:289-314` defines `banner-parity` task with yq-extraction + grep-check logic. `lint:default` aggregator (line 97) invokes it. `task lint` output shows: `LINT-08: setup/test/validate/install in banner` checks pass |
| 10 | `taskfiles/audit.yml`, `taskfiles/show.yml`, `taskfiles/refresh.yml` exist with public delegates | VERIFIED | Three files exist: audit.yml (3 delegates: links/packages/manifest), show.yml (2 delegates: claude/manifest), refresh.yml (1 delegate: claude). All use `task: :<ns>:<target>` cross-namespace dispatch |
| 11 | Banner-parity lint fixtures present (D-13 paired positive + negative) | VERIFIED | `taskfiles/test/lint-fixtures/08a-banner-parity-fail/{Taskfile.yml,expect}` and `taskfiles/test/lint-fixtures/08b-banner-parity-ok/{Taskfile.yml,expect}` exist. `test-fixtures` case-switch has `08*)` branch (lint.yml:393-) |
| 12 | `test:manifest` and `test:add-machine` moved from manifest.yml to test.yml | VERIFIED | `taskfiles/test.yml:95-128` (manifest) and :291- (add-machine). Both marked `internal: true`. `task test` aggregator at Taskfile.yml:169-171 invokes `test:manifest` + `test:hooks`; runs green |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/phases/12-task-surface-redesign/SURFACE.md` | SURF-01 classification table, 6-column shape | VERIFIED | 55 rows; columns match D-14: task name (current) / verdict / new name / internal: true? / rationale / callsites; decisions cross-reference at bottom maps D-01..D-15 |
| `Taskfile.yml` | `default:` two-tier banner; `validate:` aggregator using `task:` dispatch; `install:` calling renamed targets | VERIFIED | default: lines 124-150 (banner via messages.zsh helpers); validate: lines 174-209 (task: dispatch w/ ignore_error: true); install: lines 212-249 invokes links:install, packages:install, claude:install, macos:install, packages:verify, audit:links |
| `taskfiles/audit.yml` | NEW file; public delegates `links`, `packages`, `manifest` | VERIFIED | 43 lines; 3 delegates implemented as thin pass-throughs forwarding CLI_ARGS |
| `taskfiles/show.yml` | NEW file; public delegates `claude`, `manifest` | VERIFIED | 33 lines; 2 delegates |
| `taskfiles/refresh.yml` | NEW file; public delegate `claude` | VERIFIED | 27 lines; 1 delegate |
| `taskfiles/lint.yml` | Banner-parity check + `default:` aggregator includes it; sub-checks internal | VERIFIED | banner-parity at line 289 (internal: true); default aggregator at line 78 (public); syntax/taskfile/shell-headers/portability/test-fixtures all `internal: true` |
| `taskfiles/shell.yml` | `startup-time` task (renamed from shell:shell/perf:shell); `validate` marked internal | VERIFIED | startup-time at line 62 (public); validate at line 97 (internal: true) |
| `taskfiles/links.yml` | All per-component tasks internal; renamed to install-<target> | VERIFIED | install/install-zsh/install-claude/install-configs/validate/reconcile all internal; sub-target rename complete |
| `taskfiles/identity.yml` | install-git/install-ssh/install-one-password-agent (verb-first); all internal | VERIFIED | 5 install* tasks + 5 validate* tasks all marked internal; cross-namespace caller uses `task: :identity:install` from links.yml |
| `taskfiles/macos.yml` | NEW `install` aggregator + apply-defaults:* + install-shell; all internal | VERIFIED | install aggregator at line 121 (internal); apply-defaults parent + 5 sub-tasks (dock/finder/input/screenshots/security); install-shell at 246; validate at 282 |
| `taskfiles/packages.yml` | install/compose/verify/audit/validate all internal | VERIFIED | All 5 tasks marked internal: true |
| `taskfiles/claude.yml` | install/marketplace/gsd/update/status/validate/ensure-cli all internal | VERIFIED | All 7 tasks marked internal: true |
| `taskfiles/manifest.yml` | setup/resolve/show/validate all internal; test* moved out | VERIFIED | All 4 tasks marked internal: true; `manifest:test` + `manifest:test:add-machine` removed (now in test.yml) |
| `taskfiles/test.yml` | Hosts test:manifest + test:add-machine (moved); default/hooks internal | VERIFIED | manifest task at line 95, add-machine task at line 291; default/hooks/manifest/add-machine all internal: true |
| `taskfiles/test/lint-fixtures/08a-banner-parity-fail/` | Paired positive fixture | VERIFIED | Taskfile.yml + expect=fail present |
| `taskfiles/test/lint-fixtures/08b-banner-parity-ok/` | Paired negative fixture | VERIFIED | Taskfile.yml + expect=pass present |
| `README.md` | References canonical bare-`task` banner as operator surface | VERIFIED | README.md:23-59 documents the table; lines 47-51 list 5 top-level commands; line 59 hints `task --list` for full graph |
| `CLAUDE.md` | Project CLAUDE.md aligned with canonical surface | VERIFIED | CLAUDE.md:23 explicitly says "Bare `task` prints the curated two-tier banner"; table at 28-32 enumerates the 5 commands |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Taskfile.yml` validate: aggregator | per-component `<ns>:validate` tasks | `task:` keyword dispatch with `ignore_error: true` | WIRED | Lines 195-209 dispatch 7 components; bypasses internal-gate (commit 3cd756d documented fix) |
| `Taskfile.yml` install: pipeline | renamed callees (links:install, macos:install, etc.) | `- task: <name>` cmds | WIRED | Lines 220-238; final cmd source-messages and prints `success "install complete"` |
| `taskfiles/audit.yml` `links:` delegate | `taskfiles/links.yml` `reconcile:` task | `task: :links:reconcile` with CLI_ARGS forwarding | WIRED | audit.yml:25 cross-namespace absolute form; `task install` line 238 invokes with `--warn-only` |
| `taskfiles/audit.yml` `packages:` delegate | `taskfiles/packages.yml` `audit:` task | `task: :packages:audit` | WIRED | audit.yml:33 |
| `taskfiles/audit.yml` `manifest:` delegate | `taskfiles/manifest.yml` `validate:` task | `task: :manifest:validate` | WIRED | audit.yml:41 (D-03 dual-shape: aggregator-callee internal, public delegate) |
| `taskfiles/show.yml` `claude:` delegate | `taskfiles/claude.yml` `status:` task | `task: :claude:status` | WIRED | show.yml:24 |
| `taskfiles/show.yml` `manifest:` delegate | `taskfiles/manifest.yml` `show:` task | `task: :manifest:show` | WIRED | show.yml:31 |
| `taskfiles/refresh.yml` `claude:` delegate | `taskfiles/claude.yml` `update:` task | `task: :claude:update` | WIRED | refresh.yml:26 |
| `taskfiles/links.yml` `install:` aggregator | `taskfiles/identity.yml` `install:` task | `task: :identity:install` cross-namespace | WIRED | links.yml:131; deep-call works (verified by `task install` exit 0) |
| `taskfiles/lint.yml` `default:` aggregator | `lint:banner-parity` sub-check | `- task: banner-parity` with `ignore_error: true` | WIRED | lint.yml:97-98; banner-parity then yq-extracts public top-level tasks from Taskfile.yml + greps against `default.cmds[0]` |
| `Taskfile.yml` `default:` banner | `install/messages.zsh` helpers | `source ... && header / info / echo` | WIRED | Lines 132-150 source-and-call (header, info x8, echo, header, info x3, echo) |
| `Taskfile.yml` `test:` aggregator | `test:manifest` + `test:hooks` (now in test.yml) | `- task: test:manifest` + `- task: test:hooks` | WIRED | Lines 167-171 |
| `Taskfile.yml` `setup:` alias | `manifest:setup` (now internal) | `- task: manifest:setup` with CLI_ARGS forwarding | WIRED | Lines 159-164; D-01 marks manifest:setup internal but invocability preserved |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Curated public surface | `task --list` | Shows exactly 13 entries: default/install/setup/test/validate + 3 audit:* + lint:default(lint) + refresh:claude + shell:startup-time + 2 show:* | PASS |
| Graph parses without error | `task --list-all > /dev/null; echo $?` | 0 | PASS |
| Bare task prints banner | `task` | Renders D-12 two-tier banner with all 5 top-level commands + 3 diagnostic namespaces | PASS |
| Validate aggregator runs all per-component validates | `task validate` | Exits 0; per-component check/cross output rendered inline; ZDOTDIR verified, packages verified, claude/marketplace/GSD verified | PASS |
| Install pipeline succeeds idempotently | `task install` | Exits 0; `success "install complete"` printed | PASS |
| Test aggregator runs all smoke tests | `task test` | Exits 0; 11 manifest fixtures + 8 hook tests all pass | PASS |
| Banner-parity rule blocks drift | `task lint` (incl. banner-parity) | Exits 0; "LINT-08: setup/test/validate/install in banner" all check | PASS |
| Public delegates round-trip | `task show:manifest` / `task audit:manifest` / `task refresh:claude` | All exit 0 (manifest delegates print/validate; refresh runs npx claude plugin update) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SURF-01 | 12-01 | Every task in `task --list` is reviewed and classified | SATISFIED | `SURFACE.md` enumerates 55 classified rows; D-14 6-column shape satisfied |
| SURF-02 | 12-02..12-08 | Renames applied across Taskfile.yml + included taskfiles + docs | SATISFIED | All renames present in code (`shell:startup-time`, `audit:*`, `show:*`, `refresh:*`, `links:install`, `links:install-zsh/claude/configs`, `identity:install-git/ssh/one-password-agent`, `macos:install`, `macos:apply-defaults`, `macos:install-shell`, `test:manifest`, `test:add-machine`); doc references updated in README.md, CLAUDE.md, taskfiles/README.md, shell/README.md, docs/MANIFEST.md, docs/MACHINES.md, .claude/CLAUDE.md |
| SURF-03 | 12-02..12-07 | Tasks marked internal-only carry `internal: true`; absent from `task --list` | SATISFIED | All per-component install/validate tasks marked internal across 9 taskfiles; `task --list` output cleanly excludes them |
| SURF-04 | 12-08 | Bare `task` prints curated list; README + CLAUDE.md document the canonical surface | SATISFIED | `default:` task at Taskfile.yml:124 renders banner via messages.zsh; README.md:23-59 documents 5-command table; CLAUDE.md:23 calls out bare task as the operator landing page |

All four phase-12 requirements satisfied. No orphans — REQUIREMENTS.md traceability table maps SURF-01..04 to Phase 12 exclusively.

### Data-Flow Trace (Level 4)

Phase 12 produces no rendered data; artifacts are taskfile DSL definitions consumed by go-task's execution graph. Level 4 (data flow) is not applicable to this phase. Behavioral spot-checks (above) exercise the same flow at runtime.

### Probe Execution

Phase 12 declares no probes (no `scripts/*/tests/probe-*.sh` referenced in PLAN/SUMMARY/CONTEXT). The lint-fixture self-tests under `taskfiles/test/lint-fixtures/08*/` act as the analog; they are exercised via `task lint:test-fixtures` (invoked indirectly through `task lint`'s downstream chain).

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| Lint fixtures (incl. 08*-banner-parity-*) | `task lint` | Exit 0; LINT-08 fixtures recognized by case-switch | PASS |
| Banner parity check | `task lint` (banner-parity sub-step) | Exit 0; 4 public top-level tasks confirmed in banner | PASS |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | TBD/FIXME/XXX | - | No debt markers in phase-12-modified files |
| (none) | - | TODO/HACK/PLACEHOLDER | - | No warning-level cleanup markers |

No anti-patterns surfaced in the modified files (Taskfile.yml, taskfiles/audit.yml, taskfiles/show.yml, taskfiles/refresh.yml, plus the 9 namespace taskfiles edited in-place).

### Human Verification Required

(none — every must-have is grep-verifiable or covered by a behavioral spot-check that ran green)

### Gaps Summary

No gaps. The phase goal is achieved end-to-end:

1. **SURFACE.md** (Plan 01) — 55-row classification table is the source-of-truth iterated by Plans 02-08.
2. **Per-component internal marks** (Plans 02-07) — every per-component install/validate carries `internal: true` (D-01); the validate aggregator was rewritten in commit `3cd756d` to use `task:` dispatch (which bypasses go-task's CLI-level internal gate), preserving aggregator semantics after the marks landed.
3. **Curated public delegates** (Plans 03/06/07) — three new taskfiles (audit.yml, show.yml, refresh.yml) expose the diagnostic surface as thin pass-throughs.
4. **Renames** (Plans 02-07) — every rename in SURFACE.md is reflected in code, with `task --list` matching the new surface.
5. **Banner + lint enforcement** (Plan 08) — bare `task` renders the D-12 two-tier banner; `lint:banner-parity` (D-13) parses the banner and asserts every public top-level task appears.

The critical aggregator break documented in 12-02-SUMMARY (silent no-op on internal validates) was fixed in commit `3cd756d` before Plans 03-08 landed; `task validate` now runs all 7 components end-to-end with per-component check/cross output.

`task install` exits 0 idempotently after the rename + internal-mark cascade. `task test` and `task lint` both exit 0 green.

---

_Verified: 2026-05-18_
_Verifier: Claude (gsd-verifier)_
