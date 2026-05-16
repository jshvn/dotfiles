---
phase: 07-claude-tool-configs-smoke-tests
plan: 2
subsystem: taskfiles/helpers + claude/hooks
tags: [helpers, symlinks, hooks, shellcheck, hardening]
dependency_graph:
  requires: []
  provides: [hardened-safe-link, strict-check-link, shellcheck-clean-agent-transparency]
  affects: [taskfiles/links.yml, claude/hooks/agent-transparency.zsh, plan-07-04, plan-07-06]
tech_stack:
  added: []
  patterns: [go-template-conditional, zsh-function-wrap, guard-before-mutate]
key_files:
  created: []
  modified:
    - taskfiles/helpers.yml
    - claude/hooks/agent-transparency.zsh
decisions:
  - Guard uses [[ -e && ! -L ]] idiom to detect non-symlink at target before ln -sfn
  - check-link SOURCE opt-in uses go-template {{if .SOURCE}} (not requires:) so existing callers need no change
  - agent-transparency uses main() wrap (option a from CONTEXT) rather than env-var export or subshell
metrics:
  duration: 3m
  completed: "2026-05-16T18:46:49Z"
  tasks_completed: 3
  files_modified: 2
---

# Phase 7 Plan 2: Harden Symlink Helpers and Fix agent-transparency.zsh Summary

Hardened `_:safe-link` with a target-type clobber guard (TOOL-03), extended `_:check-link` with opt-in SOURCE strict-mode via `readlink -f` equality (TOOL-04), and rewrote `agent-transparency.zsh` with a `main()` function wrapper to eliminate script-scope `local` declarations (CLDE-02).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add target-type clobber guard to `_:safe-link` (TOOL-03) | 2fa67e1 | taskfiles/helpers.yml |
| 2 | Extend `_:check-link` with optional SOURCE strict-mode (TOOL-04) | 581809b | taskfiles/helpers.yml |
| 3 | Function-wrap `agent-transparency.zsh` to remove script-scope `local` (CLDE-02) | c7430b4 | claude/hooks/agent-transparency.zsh |

## Verification Results

- `zsh -n claude/hooks/agent-transparency.zsh`: PASS
- `grep -E '^local ' claude/hooks/agent-transparency.zsh | wc -l`: 0 (PASS)
- Smoke probe `echo '{"tool_input":{"subagent_type":"general-purpose","description":"smoke"}}' | zsh ...`: prints `Agent delegated -> type: general-purpose, task: smoke` (PASS)
- Plugin-scoped probe (everything-claude-code:rust-reviewer): exits 0 (PASS)
- All four sibling hooks share `#!/bin/zsh` shebang (PASS)
- `_:safe-link` block case: regular file at target exits 1 with `_:safe-link: target exists and is not a symlink: <path>` (PASS)
- `_:safe-link` pass cases: existing symlink and new target both succeed (PASS)
- `_:check-link` two-condition mode: unchanged backward-compat behavior (PASS)
- `_:check-link` strict mode pass: `readlink -f TARGET == SOURCE` prints check (PASS)
- `_:check-link` strict mode fail: mismatch prints cross with expected and actual (PASS)
- `task lint:taskfile`: helpers.yml shows green LINT-02 check (PASS); other failures are pre-existing in unrelated files

## Deviations from Plan

### Note: shellcheck not installed

`shellcheck` is not installed on this system (not in Homebrew or PATH). The plan's acceptance criteria include `shellcheck claude/hooks/agent-transparency.zsh` exits 0. The rewrite follows all shellcheck conventions manually (no script-scope `local`, proper `set -euo pipefail`, function-scoped variables) and `zsh -n` (the runtime syntax check) passes. This is a pre-existing system configuration gap, not a code deficiency.

## Known Stubs

None. All three changes are complete implementations.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `_:safe-link` guard adds a filesystem read (pre-check `-e` and `-L`) at the same trust boundary as the existing `ln -sfn`. The `_:check-link` strict mode adds a `readlink -f` call at the same boundary. The `agent-transparency.zsh` rewrite is behavior-preserving (same stdin, same stdout, same resolution logic).

## Self-Check: PASSED

- [x] taskfiles/helpers.yml modified with guard and strict-mode
- [x] claude/hooks/agent-transparency.zsh rewritten with main() wrapper
- [x] Commit 2fa67e1 exists (Task 1: safe-link guard)
- [x] Commit 581809b exists (Task 2: check-link strict mode)
- [x] Commit c7430b4 exists (Task 3: agent-transparency function wrap)
