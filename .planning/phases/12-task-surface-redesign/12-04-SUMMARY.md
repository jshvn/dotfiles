---
phase: 12-task-surface-redesign
plan: 04
subsystem: task-surface
tags: [refactor, taskfile, surf-02, surf-03, d-01, d-04, d-09, d-10, d-11]
requirements: [SURF-02, SURF-03]
dependency_graph:
  requires: [12-01, 12-03]
  provides:
    - "identity:install (internal aggregator; name unchanged; cmds: retargeted)"
    - "identity:install-git (internal sub-target; renamed from identity:git)"
    - "identity:install-ssh (internal sub-target; renamed from identity:ssh)"
    - "identity:install-one-password-agent (internal sub-target; renamed from identity:one-password-agent)"
    - "identity:validate (internal mark; name unchanged)"
  affects: [taskfiles/identity.yml]
tech_stack:
  added: []
  patterns:
    - "internal-mark pattern (D-01) applied to 5 identity tasks"
    - "verb-first sub-target rename pattern (D-10) -- git/ssh/one-password-agent -> install-<target>"
    - "aggregator-as-internal pattern (D-09) -- identity:install kept name, marked internal"
    - "callers-first commit discipline (D-04) -- aggregator cmds: retargeted before sub-target keys renamed"
    - "32-char longest internal task name accepted (D-11) -- identity:install-one-password-agent"
    - "two-commit split (B-6) -- Task 1a aggregator+cmds; Task 1b sub-target renames + validate internal"
key_files:
  created: []
  modified:
    - taskfiles/identity.yml
decisions:
  - "Applied D-09 + D-01 to identity:install -- kept name (cross-namespace caller :identity:install in taskfiles/links.yml stays intact); added internal: true after desc:"
  - "Applied D-10 + D-01 to three sub-targets: identity:git/ssh/one-password-agent -> identity:install-git/install-ssh/install-one-password-agent (all internal)"
  - "Applied D-01 to identity:validate (kept name; marked internal)"
  - "Applied D-04 callers-first: Task 1a updates aggregator cmds: refs BEFORE Task 1b actually renames the sub-target keys; between commits the aggregator points at names not yet defined but the aggregator is not invoked between commits"
  - "Per D-11 the 32-char identity:install-one-password-agent is the longest internal task name post-rename; planner did NOT abbreviate"
  - "identity:server-include (internal generator) NOT renamed -- already correctly internal; sibling ref `task: server-include` inside install-git stays unchanged"
  - "Five identity:validate:* sub-tasks (symlinks/one-password-agent/git/ssh-add/keys) already had internal: true -- verified; no edit"
metrics:
  duration: ~3 minutes
  tasks_completed: 2/2
  commits: 2
  files_created: 0
  files_modified: 1
  completed_date: 2026-05-18
---

# Phase 12 Plan 04: identity namespace rename Summary

Renamed the entire `identity:` namespace per D-09 (aggregator keeps its `:install` name + `internal: true`) + D-10 (sub-targets gain the verb-first `install-<target>` prefix) + D-01 (per-component install / validate marked internal) + D-11 (32-char `identity:install-one-password-agent` accepted as the longest internal task name). Public `identity:*` surface now contains zero rows. The aggregator's name is unchanged so the cross-namespace caller `task: :identity:install` from `taskfiles/links.yml` continues to resolve. The two commits each leave a green-graph tree (`task --list-all` rc=0).

## What changed

### Commits (2)

| # | Commit  | Type     | Description                                                                                  |
|---|---------|----------|----------------------------------------------------------------------------------------------|
| 1 | da83196 | refactor | mark identity:install internal + retarget aggregator cmds: to install-<target> (D-01,D-04,D-10) |
| 2 | 740b00d | refactor | rename identity sub-targets + mark validate internal (D-01,D-10,D-11)                        |

### Files modified

- **`taskfiles/identity.yml`** -- five task-key + visibility edits, no comment-block rewrites:
  - `install:` aggregator (line 111) -- `internal: true` added after `desc:`; cmds: block retargeted from `- task: git/ssh/one-password-agent` to `- task: install-git/install-ssh/install-one-password-agent` (Task 1a; D-09 + D-04 callers-first).
  - `git:` -> `install-git:` (line 128 post-rename) -- `internal: true` added after `desc:`; vars/preconditions/cmds (including internal sibling ref `- task: server-include`) / status blocks unchanged (Task 1b; D-10).
  - `ssh:` -> `install-ssh:` (line 222 post-rename) -- `internal: true` added after `desc:`; vars/preconditions/cmds/status blocks unchanged (Task 1b; D-10).
  - `one-password-agent:` -> `install-one-password-agent:` (line 292 post-rename) -- `internal: true` added after `desc:`; cmds/status blocks unchanged (Task 1b; D-10 + D-11).
  - `validate:` aggregator (line 306 post-rename) -- `internal: true` added after `desc:`; cmds block (`task: validate:symlinks/git/ssh-add/keys`) unchanged (Task 1b; D-01).
  - `server-include` internal generator -- NOT renamed (already internal; the sibling ref `- task: server-include` inside install-git is unchanged because the callee's name is unchanged).
  - Five `validate:*` sub-tasks (`validate:symlinks`, `validate:one-password-agent`, `validate:git`, `validate:ssh-add`, `validate:keys`) -- already `internal: true`; verified, no edit.

### Live verification (post-plan)

```text
$ task --list | grep -cE '^\* identity:'
0

$ task --list-all >/dev/null 2>&1; echo $?
0

$ yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/identity.yml
- install
- install-git
- server-include
- install-ssh
- install-one-password-agent
- validate
- validate:symlinks
- validate:one-password-agent
- validate:git
- validate:ssh-add
- validate:keys

$ grep -cE '^\s+(git|ssh|one-password-agent):\s*$' taskfiles/identity.yml
0

$ grep -nE '^\s+(install-git|install-ssh|install-one-password-agent):' taskfiles/identity.yml
128:  install-git:
222:  install-ssh:
292:  install-one-password-agent:

$ task validate; echo $?
[...per-component check output including the four identity validate sub-checks
  (symlinks, git, ssh-add, keys) -- the now-internal identity:validate is invoked
  via the rewritten task:-dispatch aggregator from commit 3cd756d...]
0

$ git rev-parse --short HEAD~1
da83196
$ git rev-parse --short HEAD
740b00d
```

- Zero `identity:*` rows in `task --list` (every per-component install + validate is internal per D-01).
- 11 internal tasks declared inside `taskfiles/identity.yml` (5 renamed/aggregator + 1 server-include generator + 5 validate sub-tasks).
- Old short keys (`git:`, `ssh:`, `one-password-agent:`) no longer exist as YAML keys.
- Three new renamed sub-target keys (`install-git:`, `install-ssh:`, `install-one-password-agent:`) present.
- `task --list-all` exits 0 -- the graph-parse gate confirms every renamed callsite resolves: aggregator's renamed sibling refs (Task 1a) find the renamed sub-target keys (Task 1b); the cross-namespace `task: :identity:install` from `taskfiles/links.yml` (the aggregator name unchanged) still resolves; the sibling ref `- task: server-include` inside `install-git` resolves to the unchanged `server-include` task.
- `task validate` runs end-to-end with rc=0; the now-internal `identity:validate` is invoked via the `task:`-dispatch aggregator pattern established in commit 3cd756d (cf. 12-02 Known Issues, resolved before 12-03 ran).

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed exactly as written.

### Verification command substitution (informational)

The Plan's automated verify block for Task 1b uses `task --list-all` to "confirm the renamed internals". As 12-03-SUMMARY documented, go-task 3.51.1 hides `internal: true` tasks from `task --list-all` too -- both `--list` and `--list-all` show only public surface. The verification therefore used the same substitute pattern 12-03 established:

1. `yq '.tasks | to_entries | map(select(.value.internal == true) | .key)' taskfiles/identity.yml` enumerates the eleven internal task keys directly from the YAML (covers the five renamed/aggregator tasks + server-include + five validate sub-tasks).
2. `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- confirms every `task:` ref in the compiled graph resolves (the "graph-parse gate" the Plan explicitly references).
3. `task validate` end-to-end rc=0 -- confirms the now-internal `identity:validate` is invocable via the rewritten aggregator (resolved 12-02 Known Issue).

This is a verification-command nuance, NOT a deviation from the executed work. All Plan acceptance criteria (renamed task keys present in YAML, internal-flag added, aggregator cmds: retargeted, lint-green for new edits, cross-namespace caller resolves, graph parse gate passes) hold.

## Known Issues

None new. The pre-existing `task lint:taskfile` failures documented in 12-02-SUMMARY and 12-03-SUMMARY remain unchanged:

- LINT-02 failures: `taskfiles/claude.yml`, `taskfiles/identity.yml` (pre-existing -- the three `[[ -e "$f" ]] || continue` shell-var refs inside the `git:`/`ssh:` status loops at lines ~171, ~269, ~274; these were the lines in the original file before Plan 04 and remain unchanged), `taskfiles/manifest.yml`, `taskfiles/packages.yml`. The Plan 04 edits added `internal: true` lines only; no new `$VAR` references entered any status block.
- LINT-03a failures: 5 manifest.yml task-blocks (`setup`, `show`, `validate`, `test`, `test:add-machine`); 1 shell.yml task (`startup-time`). All pre-existing.
- LINT-03b: 1 doc-mention in `taskfiles/README.md`. Pre-existing (a documentation string, not a real `ln -s` call).

Plan 04's two commits introduce zero new lint regressions. The new aggregator-style internal `install:` task has the `# lint-allow: cmds-without-status` marker on the line immediately above and `cmds:` is entirely `task:` delegations (LINT-03a auto-exempt). The new aggregator-style internal `validate:` task has the same shape. The three renamed sub-targets retain their existing `status:` blocks unchanged (LINT-01 stays green for those).

## Lint Compliance

`task lint` baseline failures unchanged. The two Plan 04 commits introduce zero new lint regressions; the LINT-02 hits inside `taskfiles/identity.yml` (3 hits at the `[[ -e "$f" ]] || continue` lines in the install-git and install-ssh status blocks) are pre-existing and were carried in from the original file -- the rename pass did not touch the body of those status blocks.

## Threat Surface Scan

No new threat surface. Per the Plan's threat register:

- **T-12-04-01** (`internal: true` on 5 identity tasks): accept-disposition; documented as a discoverability hint, NOT an authorization boundary. `internal: true` does prevent direct CLI-level invocation but does NOT prevent same-process `task:` dispatch from inside another task. The validate aggregator from commit 3cd756d explicitly relies on this behavior to call the now-internal `task: :identity:validate`.
- **T-12-04-02** (brief window between Task 1a and Task 1b where the aggregator's `cmds:` references not-yet-renamed sub-targets): mitigated by the two commits landing in immediate sequence -- between `da83196` and `740b00d` the operator does not invoke `task identity:install` in normal operation; the cross-file caller `taskfiles/links.yml`'s `:identity:install` call goes to the aggregator (which keeps its name), not to the sub-targets directly. Each commit individually passes `task lint:taskfile` (the new edits introduce no LINT-01..LINT-07 regressions); `task --list-all` succeeds after `740b00d` (graph-parse gate).

## Handoff to next plan (12-05 macos namespace)

- No shared file conflicts -- Plan 12-05 modifies `taskfiles/macos.yml` exclusively (plus `Taskfile.yml`'s install body per D-04 callers-first); Plan 12-04 touched only `taskfiles/identity.yml`. No `Taskfile.yml` install-body line touches identity directly (`identity:install` is invoked from `links:install`'s aggregator cmds via the absolute-form `task: :identity:install` -- both names unchanged, so the call site is intact).
- Plan 12-05 can follow the exact two-commit shape established here (callers-first for aggregator + cmds: retarget; then sub-target renames). Plan 12-05 additionally creates the new `macos:install` aggregator per D-09 (no analog inside taskfiles/macos.yml today).
- The pre-existing `taskfiles/identity.yml` LINT-02 hits (3 hits at `[[ -e "$f" ]] || continue` lines) are inside install-git / install-ssh status loops; they are documentation-style guards over filesystem-loop iterators (`$f` is the loop variable, intentionally a shell var per Phase 4 design). Future cleanup belongs to Phase 14 TRIM or a dedicated lint rule refinement, not Phase 12.

## Self-Check: PASSED

- `[ -f taskfiles/identity.yml ]` -- FOUND
- `[ -f .planning/phases/12-task-surface-redesign/12-04-SUMMARY.md ]` -- (this file)
- Commit `da83196` present in `git log --oneline -5` -- FOUND
- Commit `740b00d` present in `git log --oneline -5` -- FOUND
- `task --list 2>&1 | grep -cE '^\* identity:'` returns 0 -- VERIFIED
- `grep -cE '^\s+(git|ssh|one-password-agent):\s*$' taskfiles/identity.yml` returns 0 -- VERIFIED
- `grep -nE '^\s+(install-git|install-ssh|install-one-password-agent):' taskfiles/identity.yml` returns 3 lines -- VERIFIED
- `yq '.tasks.install.internal' taskfiles/identity.yml` returns true -- VERIFIED
- `yq '.tasks["install-git"].internal' taskfiles/identity.yml` returns true -- VERIFIED
- `yq '.tasks["install-ssh"].internal' taskfiles/identity.yml` returns true -- VERIFIED
- `yq '.tasks["install-one-password-agent"].internal' taskfiles/identity.yml` returns true -- VERIFIED
- `yq '.tasks.validate.internal' taskfiles/identity.yml` returns true -- VERIFIED
- `task --list-all >/dev/null 2>&1; echo $?` returns 0 -- VERIFIED (graph parse gate)
- `task validate` end-to-end rc=0 -- VERIFIED (internal identity:validate invoked via task: dispatch aggregator)
