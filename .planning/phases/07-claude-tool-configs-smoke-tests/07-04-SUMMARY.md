---
phase: 07-claude-tool-configs-smoke-tests
plan: "04"
subsystem: test
tags: [smoke-test, hooks, task-test, TEST-01, TEST-02, CLDE-02]
dependency_graph:
  requires: [07-02, 07-03]
  provides: [install/test-hooks.zsh, taskfiles/test.yml, task test]
  affects: [Taskfile.yml, install/messages.zsh, claude/hooks/secret-scan.zsh]
tech_stack:
  added: []
  patterns:
    - inline-fixture smoke-test runner (install/ script invoked by taskfile)
    - explicit DOTFILEDIR forwarding in included taskfile (matches manifest:/identity: pattern)
key_files:
  created:
    - install/test-hooks.zsh
    - taskfiles/test.yml
  modified:
    - Taskfile.yml
    - install/messages.zsh
    - claude/hooks/secret-scan.zsh
decisions:
  - Use explicit var forwarding (DOTFILEDIR + DOTFILES_MESSAGES) on test: include, matching manifest:/identity:/packages: pattern — taskfiles with sh: DOTFILEDIR vars resolve incorrectly when included
  - status: [false] on hooks task (diagnostic; always-rerun) with lint-allow marker on default task (all-task-delegations exemption)
metrics:
  duration: "~30 minutes"
  completed: "2026-05-16T19:22:03Z"
  tasks_completed: 3
  files_changed: 5
---

# Phase 07 Plan 04: Hook Smoke-Test Surface Summary

Single-command Tier-3 smoke-test entry point (`task test`) combining P1 manifest deep-merge fixtures with eight inline hook fixtures (pass + block/warn per hook) covering the four CLDE-02 named hooks via `install/test-hooks.zsh`.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create install/test-hooks.zsh runner | 84c5962 | install/test-hooks.zsh (created), install/messages.zsh (bug fix), claude/hooks/secret-scan.zsh (bug fix) |
| 2 | Create taskfiles/test.yml | 9e98ed3 | taskfiles/test.yml (created) |
| 3 | Wire test: include + root test aggregator | 30c3fa2 | Taskfile.yml (modified) |

## What Was Built

`install/test-hooks.zsh` is a self-contained zsh smoke-test runner with eight inline JSON fixtures — two per hook (D-16: one pass + one block/warn scenario). It pipes synthetic payloads matching Claude Code's hook stdin contract to each of the four CLDE-02 named hooks and asserts expected exit codes and stderr patterns. The runner exits 0 when all fixtures pass and non-zero (total failure count) otherwise, allowing complete feedback rather than aborting on first failure.

`taskfiles/test.yml` exposes `test:hooks` (invokes the runner) and `test:default` (local aggregator). Included from the root as the `test:` namespace with explicit `DOTFILEDIR` + `DOTFILES_MESSAGES` forwarding (required to avoid the dirname-resolution bug affecting included taskfiles).

Root `Taskfile.yml` now exposes `task test` as the single-command Tier-3 smoke-test aggregator, sequencing `manifest:test` (P1 deep-merge fixtures) then `test:hooks` (P7 hook fixtures).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed DOTFILES_MESSAGES_LOADED unbound variable in messages.zsh**
- **Found during:** Task 1 (first end-to-end run of test-hooks.zsh)
- **Issue:** `install/messages.zsh` line 20 used `"$DOTFILES_MESSAGES_LOADED"` without a `:-` default. Under `set -u` (which test-hooks.zsh enables via `set -euo pipefail`), sourcing messages.zsh on a fresh shell exited 1 with "parameter not set".
- **Fix:** Changed to `"${DOTFILES_MESSAGES_LOADED:-}"` — standard unbound-var guard.
- **Files modified:** `install/messages.zsh`
- **Commit:** 84c5962

**2. [Rule 1 - Bug] Fixed secret-scan.zsh api_key pattern — \x27 not a hex escape in ggrep -E mode**
- **Found during:** Task 1 (secret-scan.block fixture returned exit 0 instead of exit 2)
- **Issue:** The pattern `["\x27]` in secret-scan.zsh uses `\x27` (hex escape for `'`) inside a `-E` (ERE) character class. GNU grep's `-E` mode does not interpret `\x27` as a hex escape — only PCRE (`-P`) does. The character class `["\x27]` was matching literal `x`, `2`, `7` characters, not single-quote, so the `api_key='...'` fixture never triggered the block.
- **Fix:** Changed the pattern to use `$'...'` ANSI-C quoting: `$'(api[_-]?key|...)\\s*[:=]\\s*["\\'"][A-Za-z0-9+/=_-]{20,}["\']'`. This embeds a literal single-quote byte in the string before it reaches ggrep, making the ERE character class `["'"]` work correctly.
- **Files modified:** `claude/hooks/secret-scan.zsh`
- **Commit:** 84c5962

**3. [Rule 3 - Blocking] Fixed test: include path resolution by using explicit var forwarding**
- **Found during:** Task 3 (task test failed with wrong messages.zsh path)
- **Issue:** Using `test: ./taskfiles/test.yml` as a simple string include caused `taskfiles/test.yml`'s `DOTFILEDIR sh: dirname "{{.TASKFILE_DIR}}"` to resolve `TASKFILE_DIR` as the `taskfiles/` directory, producing `dirname taskfiles/` = repo parent (`/Users/josh/Git/personal`) instead of the repo root.
- **Fix:** Changed the `test:` include to the explicit object form with `DOTFILEDIR: '{{.DOTFILEDIR}}'` and `DOTFILES_MESSAGES: '{{.DOTFILES_MESSAGES}}'` forwarding — matching the established `manifest:`, `identity:`, and `packages:` pattern documented in Taskfile.yml's comments.
- **Files modified:** `Taskfile.yml`
- **Commit:** 30c3fa2

**4. [Rule 2 - Missing fixture] Block fixture for secret-scan uses api_key pattern (not synthetic sk- prefix)**
- **Found during:** Task 1 design
- **Issue:** The plan's suggested fixture used `export API_KEY=sk-abc123def456ghi789jkl012mno345` which does not match any pattern in secret-scan.zsh. The hook has no `sk-` pattern — it uses the `(api[_-]?key)[:=]["'][20+ chars]["']` pattern, AWS AKIA prefix, GitHub token prefixes, PEM keys, and URL credentials.
- **Fix:** Changed the block fixture to `api_key='aaaabbbbccccddddeeee1234'` (synthetic value matching the api_key pattern). Documented in code comment that `AKIA`, `ghp_`, etc. are not used to avoid triggering real provider scanners.
- **Files modified:** `install/test-hooks.zsh`
- **Commit:** 84c5962

## Verification Results

End-to-end `task test` output (2026-05-16):
- manifest:test: 11 fixtures, 11 passed (positive 01-06, negative 5 invalid cases)
- test:hooks: 8 fixtures, 8 passed (secret-scan x2, no-emojis x2, no-ai-comments x2, agent-transparency x2)
- task lint: test.yml passes LINT-02 and LINT-03a; pre-existing failures in v1 taskfiles unchanged

Regression check for Plan 02 (agent-transparency.zsh function-wrap rewrite):
- `agent-transparency.general-purpose` fixture: PASS (exit 0, "Agent delegated ->" in output)
- `agent-transparency.plugin-scoped` fixture: PASS (exit 0, "type: some-plugin:some-agent" and "task: test" in output — exercises the plugin-scoped resolution branch)

## Known Stubs

None. All four hook fixtures exercise real hook code paths end-to-end.

## Threat Flags

None. All T-07-17 through T-07-22 mitigations applied:
- T-07-18 (emoji in source): emoji injected at runtime via `printf '\U1F600'` — no literal bytes in source
- T-07-19 (ai-attribution in source): fixture string flows only through test runner stdin pipe, not through Write/Edit
- T-07-20 (HOOK_DIR path): `set -u` fails immediately if DOTFILEDIR unset; verified manually

## Self-Check: PASSED

Files exist:
- install/test-hooks.zsh: FOUND
- taskfiles/test.yml: FOUND
- Taskfile.yml (modified): FOUND

Commits exist:
- 84c5962: FOUND
- 9e98ed3: FOUND
- 30c3fa2: FOUND
