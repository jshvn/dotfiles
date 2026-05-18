---
phase: 10
plan: 01
subsystem: v1-drop-remediation
tags: [PORT-01, PORT-02, PORT-03, AUDIT-amend, shell-layer, /etc/zshenv, ZDOTDIR]
status: partial
checkpoint_pending: task-6-human-verify
requires:
  - .planning/phases/09-v1-drop-audit/AUDIT.md (keep rows #1, #2, #3 per Phase 9)
provides:
  - taskfiles/links.yml:zdotdir (internal task; PORT-01)
  - taskfiles/shell.yml:validate (PORT-02)
  - Taskfile.yml:validate aggregator wired with shell component (D-05)
  - .planning/phases/10-v1-drop-remediation/10-SMOKE.md (PORT-03)
affects:
  - .planning/phases/09-v1-drop-audit/AUDIT.md (counts table + Things3 row + bullet)
tech-stack:
  added: []
  patterns:
    - "Internal-task extraction precedent (configs:ghostty at links.yml:269-277) reused for zdotdir"
    - "failures-counter + exit \"$failures\" pattern from links.yml:382 reused in shell:validate"
    - "Dual-alias include (perf: + shell:) keeps both legacy SHEL-12 gate and new shell:validate"
    - "Tail-append into the aggregator's six-token loop (Landmine 5 protection)"
key-files:
  created:
    - .planning/phases/10-v1-drop-remediation/10-SMOKE.md
    - .planning/phases/10-v1-drop-remediation/10-01-SUMMARY.md
  modified:
    - taskfiles/links.yml
    - taskfiles/shell.yml
    - Taskfile.yml
    - .planning/phases/09-v1-drop-audit/AUDIT.md
decisions:
  - "D-01..D-08 (CONTEXT.md): all honored verbatim — zdotdir lives in links.yml (D-02), {{.ZDOTDIR}} in status block (D-04, LINT-02), dual-alias include (D-06), shell row appended to aggregator (D-05), Things3 stays as canonical mas-list name (D-07), documented smoke procedure (D-08)."
  - "RESEARCH.md Option C (extracted internal zdotdir: task) chosen over inline-cmd (Option A) — mirrors configs:ghostty precedent in same file; isolates idempotency check; the outer zsh: status block is extended with the grep check so /etc/zshenv drift re-triggers cmds (Landmine 7)."
  - "RESEARCH.md Pattern 3 inline failures-counter (NOT _:check-dir helper) used in shell:validate per Landmine 4: _:check-dir always exits 0 even on missing dirs; failures-counter + 'exit \"$failures\"' is the only way the aggregator captures a real non-zero exit."
metrics:
  duration: ~25min execution (read + edit + verify per task)
  completed: 2026-05-17
  tasks_completed: 5
  tasks_pending_checkpoint: 1
  files_modified: 4
  files_created: 1
---

# Phase 10 Plan 01: v1-Drop Remediation Summary

PORT-01 ZDOTDIR write to /etc/zshenv + PORT-02 shell:validate + AUDIT.md
row-3 reclassification + PORT-03 fresh-shell smoke procedure — five tasks
landed, the Task 6 human-verify checkpoint awaits the operator running three
sudo / fresh-terminal checks.

## One-line summary

Ported the v1 `/etc/zshenv` ZDOTDIR write (the milestone-driver finding) and
the v1 shell-layer validate body into v2, reclassified the Things3 audit row
to drop, and authored the fresh-shell smoke document — closing every
remaining Phase-9 "keep" item that v2 had silently dropped.

## Files

| File | Type | Purpose |
|------|------|---------|
| `taskfiles/links.yml` | modified | New internal `zdotdir` task + `task: zdotdir` dispatch from `links:zsh` + grep line in outer `zsh:` status (PORT-01). |
| `taskfiles/shell.yml` | modified | New `validate` task: four XDG dirs + ZDOTDIR + /etc/zshenv ZDOTDIR line + DOTFILES_MACHINE state file (PORT-02). |
| `Taskfile.yml` | modified | Dual-alias `perf:` + `shell:` include of `./taskfiles/shell.yml`; `shell` token appended to both aggregator for-loops (D-05, D-06). |
| `.planning/phases/09-v1-drop-audit/AUDIT.md` | modified | Counts Keep 3->2 and Drop 99->100; Things3 row reclassified `partially-ported / keep` -> `ported / drop`; keep-list bullet removed (D-07). |
| `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` | created | Fresh-shell smoke procedure with 7 first-shell assertions + Run Log table (PORT-03, D-08, ROADMAP P10 SC#3). |

## Per-task results

### Task 1: Add internal `zdotdir` task to taskfiles/links.yml — DONE (commit eedd3b0)

- Verify command: `task lint:taskfile`.
- Result: my new code (zdotdir task body + status block + outer zsh: status grep) introduces ZERO LINT-02 / LINT-03a / LINT-03b violations. Confirmed by `yq '.tasks.zdotdir.status' taskfiles/links.yml | grep -cE '\$[A-Za-z_]'` returning `0`. The overall `task lint:taskfile` invocation exits non-zero ONLY due to pre-existing v1 leftover files (common.yml, profile.yml, brew.yml, claude.yml, manifest.yml, packages.yml, profile-tasks.yml, shell.yml's pre-existing `cmds-without-status` on the shell task which carries the lint-allow marker but the LINT-03a regex appears not to honor inline comments next to the task name). These are scope-excluded from Phase 10 — Phase 11 deletes the v1 files and Phase 13 REVW-* cleanup will revisit linter regex hygiene. Pre-existing failure inventory recorded below under "Pre-existing lint failures (out of scope)."
- Pattern verification:
  - `grep -n "zdotdir:" taskfiles/links.yml` -> 2 hits (cmds entry + task definition).
  - `grep -c 'export ZDOTDIR="{{.ZDOTDIR}}"' taskfiles/links.yml` -> 3 (cmds heredoc assignment + zdotdir status + outer zsh status). Acceptance >= 3 satisfied.
  - `internal: true` + `sudo tee /etc/zshenv` + `sudo tee -a /etc/zshenv` all present.
- PORT-01 operational test (fresh-write + idempotency, two-invocation sudo check): DEFERRED to Task 6 operator checkpoint.

### Task 2: Add `validate` task to taskfiles/shell.yml — DONE (commit a83b5b4)

- Verify command: `task lint:taskfile && task -t taskfiles/shell.yml validate`.
- Result: `task -t taskfiles/shell.yml validate` runs and prints seven green check marks (all four XDG dirs + ZDOTDIR dir + /etc/zshenv ZDOTDIR line + DOTFILES_MACHINE state file) and exits 0 on the developer's machine (the existing v1 /etc/zshenv already carries the ZDOTDIR line).
- Pattern verification:
  - `failures=` appears 8 times (init + 7 increment branches).
  - `exit "$failures"` appears 1 time in code (and 1 in a comment).
  - `status: [false]` satisfies LINT-03a and forces always-rerun.
  - Zero `$VAR` shell-var references in the cmds heredoc thanks to template-var embedding.
- PORT-02 negative test (`sudo mv /etc/zshenv ...; task shell:validate; ec=$?; ...`): DEFERRED to Task 6 operator checkpoint.

### Task 3: Dual-alias the include and wire shell into root validate aggregator — DONE (commit 983fdb7)

- Verify command: `grep -c 'manifest identity links macos packages claude shell' Taskfile.yml` returns `2`; `task --list-all` lists both `shell:validate` and `perf:shell`.
- Result: Confirmed. Both aggregator loops (lines 216 and 223) now end with `claude shell; do`. `task --list-all` shows BOTH `perf:shell` (legacy CI gate preserved) and `shell:validate` (new primary alias). The dual-alias also surfaces `perf:validate` and `shell:shell` as expected side-effects (Option B documented trade-off — accepted per D-06).
- Aggregator behavior: `task validate` invocation now prints a `shell` row in the Validation Summary; on the developer's machine all seven components (manifest, identity, links, macos, packages, claude, shell) report green check marks.

### Task 4: Amend AUDIT.md row 3 (Things3) and counts table per D-07 — DONE (commit 904348c)

- Verify command: counts `Keep 2 / Drop 100`; row `| ported | drop |`; keep-list bullet removed; manifest unchanged.
- Result: All semantically satisfied. Note on the plan's automated `<automated>` grep: the literal command `grep -q "^| install/Brewfile-personal.rb:72 |.*| ported |.*| drop |" AUDIT.md` returned non-zero on macOS BSD grep, but the SAME row in awk-parsed-by-column comparison shows `F[3]=[ported]` and `F[4]=[drop]` exactly. Cross-verified via fixed-string pipeline grep: `grep -F '| install/Brewfile-personal.rb:72 |' AUDIT.md | grep -qF '| ported |'` returns 0 AND `| grep -qF '| drop |'` returns 0. Counts table reads exactly `| Keep | 2 |` and `| Drop | 100 |`. Bullet removal verified: `grep -nF "install/Brewfile-personal.rb:72" AUDIT.md` returns ONE line (the install-assets row), zero keep-list bullets remain. Two remaining keep-list bullets are the PORT-01 and PORT-02 rows.
- Row 3 new content (verbatim): `| install/Brewfile-personal.rb:72 | mas 'Things' (id 904280696) declared in v1 personal-profile Brewfile | ported | drop | Ported under canonical App Store name -- v1 used short name 'Things'; v2 uses canonical 'Things3' (the name `mas list` returns for id 904280696). The install primitive is the id (904280696), which is unchanged across v1 and v2 manifests; mas-list-name drift is a display-string concern, not an install concern. Functional install is correct on both. Phase 10 (D-07) chose to leave the v2 manifest name as the canonical 'Things3' rather than revert to the v1 short name. | manifests/machines/personal-laptop.toml |`
- `manifests/machines/personal-laptop.toml` is UNCHANGED — `git diff manifests/machines/personal-laptop.toml` returns empty; Things3 entry (id 904280696) still present at line 67 (D-07 honored).

### Task 5: Author 10-SMOKE.md (PORT-03) — DONE (commit fc12f3b)

- Verify command: `test -f 10-SMOKE.md && grep ... # H1 + Run Log + 7 checkboxes + no AI attribution`.
- Result: All seven first-shell assertions present verbatim as `- [ ]` checkboxes; H1 `# Phase 10: First-Shell Smoke Procedure` present; `## Run Log` table with `| Date | Machine | Result | Notes |` header present; zero emojis; zero AI attribution.
- Checkbox count: 7 (matches the acceptance criterion exactly).
- Run Log header line: present.

### Task 6: Operator runs PORT-01 idempotency + PORT-02 negative test + PORT-03 smoke — PENDING (human-verify checkpoint)

This task gate-blocks plan completion. See the Checkpoint Payload section below.

## Decision tracking

| Decision | Outcome |
|----------|---------|
| D-01 (PORT-01 pipeline slot: write in same step as zsh symlinks) | Honored — `task: zdotdir` is the sixth cmds entry of `links:zsh`, after the five `_:safe-link` invocations. |
| D-02 (PORT-01 code in taskfiles/links.yml, not shell.yml — amends AUDIT row #1's owner) | Honored — new `zdotdir:` task lives in `taskfiles/links.yml`. AUDIT.md row #1's v2 owner column still reads `taskfiles/shell.yml` but is now superseded by the implementation; updating that column is out of scope (Phase 11 deletes the v1 source-of-truth row anyway). |
| D-03 (PORT-01 sudo handling: literal v1 port; no `sudo -v` priming) | Honored — `echo "$ZDOTDIR_EXPORT" | sudo tee` / `sudo tee -a`; status block stays sudo-free since /etc/zshenv is world-readable. |
| D-04 (PORT-01 status block uses `{{.ZDOTDIR}}` template var) | Honored — status block: `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null`. Zero shell-var references. |
| D-05 (PORT-02 new shell component joins root validate aggregator) | Honored — `shell` is the seventh token in both Taskfile.yml:216 and :223 for-loops. |
| D-06 (PORT-02 lives in shell.yml; dual-alias include picked) | Honored — Option B (dual-alias) chosen per RESEARCH.md tradeoff analysis. `perf:` legacy alias preserved; `shell:` primary alias added. |
| D-07 (Things3 stays as canonical mas-list name; AUDIT row reclassified keep->drop) | Honored — manifest unchanged; AUDIT row + counts + bullet edited verbatim per RESEARCH.md `### AUDIT.md Row Amend Specification`. |
| D-08 (PORT-03 documented smoke procedure, not real fresh install) | Honored — `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` carries the procedure and Run Log table; ROADMAP P10 SC#3 path matches exactly. |

## Deviations from Plan

### Auto-fixed Issues

None.

### Non-auto-fixed pre-existing issues (out of scope per Rule SCOPE BOUNDARY)

**1. [pre-existing] `task lint:taskfile` exits 24 due to v1 leftover files**

- **Found during:** Task 1 verification.
- **Issue:** The repo currently has lint failures in eight v1 leftover files (`taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/brew.yml`, `taskfiles/claude.yml`, `taskfiles/manifest.yml`, `taskfiles/packages.yml`, plus the LINT-03a regex flagging the lint-allow-tagged `shell` task in `taskfiles/shell.yml`). The pre-existing failure inventory matches byte-for-byte with my changes applied vs the stash-cleared base commit; my Phase 10 edits introduce zero new lint failures.
- **Why not auto-fixed:** The v1 files are scope-locked for deletion in Phase 11 (RMV-01); fixing them in Phase 10 would either (a) delete them prematurely or (b) modify v1 source-of-truth that Phase 9's audit was based on. The pre-existing LINT-03a hit on `shell:` in taskfiles/shell.yml is a known false-positive (the file's `# lint-allow: cmds-without-status` marker is on a comment line, and the LINT-03a regex appears to scan `.tasks.*` without consulting per-task lint-allow comments) — Phase 13 REVW-* cleanup is the right place to either tighten the regex or move the marker into a yq-readable form.
- **Files NOT modified:** all the listed v1 files.

### Deferred issues

None for Plan 10-01. The PORT-01 operational test (fresh-write + idempotency)
and the PORT-02 negative test require root-level mutation of `/etc/zshenv`
and are deferred to the Task-6 human-verify checkpoint by design (those
checks cannot be cleanly automated inside a worktree-agent context — they
require the operator's interactive sudo + a fresh-terminal launch).

## Pre-existing lint failures (recorded for the Phase 13 cleanup pass)

| File | LINT rule | Note |
|------|-----------|------|
| `taskfiles/claude.yml` | LINT-02 false-positive | The match is a comment line `# and validate body (line 277), both of which use `.id == $i`. Plugin` inside the validate body description — `.id == $i` is a yq expression, not a status block. Regex needs awareness of yq-expression context. |
| `taskfiles/common.yml` | LINT-02 (genuine) | v1 file; status uses `$ZDOTDIR_EXPORT` shell var. Phase 11 deletes this file. |
| `taskfiles/manifest.yml` | LINT-02 false-positive | `[ -z "$out" ]` is a status check using a heredoc-local var assigned in the same status block. Regex needs awareness of intra-status assignments. |
| `taskfiles/packages.yml` | LINT-02 (same pattern) | Same `[ -z "$out" ]` pattern as manifest.yml. |
| `taskfiles/brew.yml`, `profile.yml`, `profile-tasks.yml` | LINT-03a (genuine) | v1 files marked for Phase 11 deletion (RMV-01); they aren't on the v2 install graph. |
| `taskfiles/shell.yml` (`shell` task) | LINT-03a (lint-allow not honored) | The `# lint-allow: cmds-without-status` marker is on the comment line above the task, but the LINT-03a regex (`yq '.tasks.*'` based) does not consult the comment. Phase 13 should either move the marker into a yq-accessible annotation or teach the regex about adjacent comments. |
| `taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` | LINT-03b fixture | This is a deliberate negative-fixture used by `lint:test-fixtures`. Not a real violation. |

## Self-Check

- [x] `taskfiles/links.yml` contains `zdotdir:` task (commit eedd3b0) — verified via `grep -n 'zdotdir:' taskfiles/links.yml`.
- [x] `taskfiles/shell.yml` contains `validate:` task (commit a83b5b4) — verified via `grep -n 'validate:' taskfiles/shell.yml`.
- [x] `Taskfile.yml` includes both `perf:` and `shell:` aliases (commit 983fdb7) — verified via `grep -n 'shell.yml' Taskfile.yml`.
- [x] `Taskfile.yml` aggregator loops end with `claude shell; do` (count = 2) — verified.
- [x] `AUDIT.md` counts table reads Keep 2 / Drop 100 (commit 904348c) — verified.
- [x] `AUDIT.md` row 3 reads `| ported | drop |` — verified via awk-parsed columns.
- [x] `AUDIT.md` keep-list bullet for Brewfile-personal.rb:72 -> personal-laptop.toml is GONE — verified.
- [x] `manifests/machines/personal-laptop.toml` UNCHANGED — `git diff` returns empty.
- [x] `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` exists with 7 checkboxes + Run Log header (commit fc12f3b).
- [x] All five new commits exist in `git log --oneline`.

## Self-Check: PASSED (for Tasks 1-5)

Tasks 1-5 are atomically committed and verified. Task 6 is pending the
human-verify checkpoint (operator runs three real-environment checks).

## Checkpoint Payload (Task 6 — human-verify)

**Type:** human-verify
**Plan:** 10-01
**Progress:** 5/6 tasks complete

### Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add zdotdir task to taskfiles/links.yml (PORT-01) | eedd3b0 | taskfiles/links.yml |
| 2 | Add validate task to taskfiles/shell.yml (PORT-02) | a83b5b4 | taskfiles/shell.yml |
| 3 | Dual-alias include + wire shell into root aggregator | 983fdb7 | Taskfile.yml |
| 4 | Reclassify Brewfile-personal.rb:72 Things3 keep->drop (D-07) | 904348c | .planning/phases/09-v1-drop-audit/AUDIT.md |
| 5 | Author 10-SMOKE.md (PORT-03) | fc12f3b | .planning/phases/10-v1-drop-remediation/10-SMOKE.md |

### Current Task

**Task 6:** Operator runs PORT-01 idempotency + PORT-02 negative test + PORT-03 smoke procedure
**Status:** awaiting verification
**Blocked by:** three operator-only environment mutations (sudo write to /etc/zshenv; sudo mv /etc/zshenv; fresh terminal launch)

### Checkpoint Details

Three operator checks. Record observations in the SUMMARY decision log; the
smoke-procedure result also lands in 10-SMOKE.md's Run Log table.

**1. PORT-01 fresh-write + idempotency** (VALIDATION rows 10-01-01, 10-01-02)

- Back up the current file: `sudo cp /etc/zshenv /tmp/zshenv.bak` (skip if absent).
- Force fresh-write path: `sudo rm -f /etc/zshenv && task links:zsh` — sudo prompt is expected once; the file should be created.
- Confirm the line landed: `grep -F 'export ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv` should match.
- Idempotency: `task links:zsh` again — must NOT prompt for sudo (the inner `zdotdir` task's status block short-circuits via `grep -qF`).
- Restore if you had a backup: `sudo mv /tmp/zshenv.bak /etc/zshenv` (only if you backed up a non-trivial file).

**2. PORT-02 negative test** (VALIDATION row 10-01-05)

- `sudo mv /etc/zshenv /tmp/zshenv.bak; task shell:validate; echo "exit: $?"; sudo mv /tmp/zshenv.bak /etc/zshenv`
- Expected: `task shell:validate` prints a `cross` line for "ZDOTDIR not configured in /etc/zshenv" and exits non-zero.
- Also confirm: `task validate` summary table shows a `shell` row (VALIDATION row 10-01-06).

**3. PORT-03 smoke procedure** (VALIDATION row 10-01-08)

- Open 10-SMOKE.md and follow the procedure section.
- Launch a fresh terminal (Ghostty, Terminal.app, or `zsh -li`).
- Tick each of the seven first-shell assertions.
- Record date, machine, and PASS/FAIL in the Run Log table at the bottom of 10-SMOKE.md.

### Awaiting

`"approved"` signal from the operator after they run the three checks and
update 10-SMOKE.md's Run Log. If any assertion fails, operator describes the
failure (which assertion, what was observed) and which task to revisit.
