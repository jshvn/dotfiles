---
phase: 11
plan: 01
subsystem: v1-removal
tags: [RMV-01, RMV-02, RMV-03, RMV-04, RMV-05, RMV-06, RMV-07, cutover-retire, v1-cleanup]
status: complete
requires:
  - .planning/phases/09-v1-drop-audit/AUDIT.md (canonical keep/drop classification)
  - .planning/phases/10-v1-drop-remediation/10-VERIFICATION.md (PORT-03 PASS upstream gate)
provides:
  - .planning/phases/11-v1-removal/11-VERIFICATION.md (steady-state install capture + SC#5 grep gate report)
  - configs/motd/motd_sysinfo.jsonc + motd_tron.txt (live motd-asset location)
  - simplified Taskfile.yml install: pipeline (no preconditions, no cutover-ack)
  - tools-only bootstrap.zsh (4 steps; brew + go-task + yq + next-step hint)
  - Phase 14 TRIM-03 / TRIM-04 deferred-residue handoff (install/README.md + .claude/CLAUDE.md)
affects:
  - Taskfile.yml (cutover:ack task removed, install: preconditions removed, v1-leftover comment block removed)
  - bootstrap.zsh (cutover-ack gate step removed, Step 5 renumbered to Step 4)
  - README.md (Fresh Machine Setup section rewritten; CUTOVER/MIGRATION doc bullets dropped)
  - docs/SECURITY.md (cutover-ack scope sentence replaced with manifest-model boundary sentence)
  - taskfiles/lint.yml (read-only banner trimmed of cutover-ack-gate clause)
  - taskfiles/README.md (intro rewritten to v2 concerns; Phase 3 bullet rewritten; Phase 4-7 stubs bullet dropped)
  - shell/functions/motd.zsh (zsh/configs/ paths rewritten to configs/motd/)
  - os/defaults/dock.zsh, finder.zsh, input.zsh, screenshots.zsh, security.zsh, os/shell-registration.zsh (LINT-05 citation cleanup)
tech-stack:
  added: []
  patterns:
    - "Callers-first deletion ordering (D-04): simplify Taskfile.yml + bootstrap.zsh BEFORE git rm install/cutover-gate.zsh so the green-tree-per-commit invariant holds"
    - "Two-commit split for zsh/ tree removal (motd-asset path rewrite first, git rm -r zsh/ second) to keep shell/functions/motd.zsh sourceable at every intermediate state"
    - "Pre-flight grep checks before every git rm to catch missed callers (Tasks 3, 4, 5, 6)"
    - "Documented-residue grep gate (Option A hard-zero outside install/README.md) instead of strict zero across whole repo"
    - "Per-task single-commit boundaries (one commit per RMV) for review tractability"
key-files:
  created:
    - .planning/phases/11-v1-removal/11-VERIFICATION.md
    - .planning/phases/11-v1-removal/11-01-SUMMARY.md
  modified:
    - Taskfile.yml
    - bootstrap.zsh
    - README.md
    - docs/SECURITY.md
    - taskfiles/lint.yml
    - taskfiles/README.md
    - shell/functions/motd.zsh
    - os/defaults/dock.zsh
    - os/defaults/finder.zsh
    - os/defaults/input.zsh
    - os/defaults/screenshots.zsh
    - os/defaults/security.zsh
    - os/shell-registration.zsh
  deleted:
    - install/cutover-gate.zsh
    - install/Brewfile.rb
    - install/Brewfile-personal.rb
    - install/Brewfile-server.rb
    - install/Brewfile-work.rb
    - taskfiles/common.yml
    - taskfiles/profile.yml
    - taskfiles/brew.yml
    - taskfiles/profile-tasks.yml
    - taskfiles/claude-stub.yml
    - taskfiles/brew-stub.yml
    - taskfiles/links-stub.yml
    - taskfiles/macos.v1.yml.bak
    - docs/CUTOVER.md
    - docs/MIGRATION.md
    - zsh/ (38 files: aliases, configs, functions, styles, theme.zsh, .zshrc / .zshenv / .zprofile / .zlogin / .zlogout)
decisions:
  - "D-01..D-11 (CONTEXT.md): all honored. D-01 MIGRATION.md deleted outright (not trimmed); D-02 AUDIT.md is the canonical v1-to-v2 record (no replacement doc); D-03 single plan with multiple commits (12 commits); D-04 callers-first green-tree-per-commit ordering; D-05 11-VERIFICATION.md captures steady-state install + SC#5 grep gate; D-06 LINT-05 citation drops cutover-gate clause; D-07 SSH-key rewrite scope verified empty (no commit); D-08 doc-drift triple-edit folded into one commit; D-09 README minimal-edit; D-10 install IS update."
  - "Task 5 implemented MANDATORY two-commit split (per WRN-04): Commit A (motd.zsh path rewrite) before Commit B (git rm -r zsh/). Inter-commit verification gate passed before Commit B: configs/motd/ assets present, motd.zsh no longer references zsh/configs/, zsh -n shell/functions/motd.zsh exits 0."
  - "Auto-fix applied to Taskfile.yml setup: comment in Task 7 (Rule 1 bug): the comment referenced docs/CUTOVER.md and docs/MIGRATION.md which were deleted in the same commit; rewrote to reference README.md instead. Folded into commit b3c4a76."
  - "Steady-state install (RMV-07) verified by Taskfile.yml inspection rather than a literal exit-0 run: the system has a pre-existing regular file at /Users/josh/.config/claude/hooks/post-compact.zsh where _:safe-link expects a symlink. That blocker pre-dates Phase 11 and is unrelated to the cutover-gate deletion. The simplified install pipeline composition (no preconditions, no cutover:ack, no cutover_gate_check) is present in Taskfile.yml and task --list parses it cleanly."
  - "SC#5 grep gate hard-zero (Option A) excludes documented residue set: 4 hits in install/README.md (lines 5, 23, 24, 42) all `cutover` matches; deferred to Phase 14 TRIM-03. The plan anticipated 5 hits but `git grep -E` does not honor `\\b` as a word boundary in POSIX ERE — the `v1` token on install/README.md:30 is not caught by the gate (also deferred to Phase 14 TRIM-03)."
metrics:
  duration: ~13min execution
  completed: 2026-05-17
  tasks_completed: 12
  files_modified: 13
  files_created: 2
  files_deleted: 52
  commits: 12
---

# Phase 11 Plan 01: v1 Removal Summary

The simplify-then-delete pass that closes v2.1 Cleanup. Twelve atomic
commits land RMV-01..RMV-07: 8 v1 leftover taskfiles deleted, the v1
`zsh/` tree (38 files) deleted with motd-asset migration to `configs/motd/`,
4 v1 install Brewfiles deleted, the cutover-gate library + cutover:ack
task + install: preconditions + docs/CUTOVER.md + docs/MIGRATION.md
deleted, the per-machine 7-day-soak model retired entirely, and the
operator-facing docs (README, SECURITY, taskfiles/README, lint banner,
6 LINT-05 pattern citations in os/*.zsh) scrubbed of cutover phrasing.

## One-line summary

Deleted every v1 leftover and the cutover infrastructure that bridged
v1->v2; v2 IS the dotfiles now.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Simplify Taskfile.yml (drop cutover:ack task, install precondition, v1-leftovers comment) | 3c5b061 | Taskfile.yml |
| 2 | Simplify bootstrap.zsh (drop Step 4 cutover-ack gate, renumber Step 5 -> Step 4) | 858a07d | bootstrap.zsh |
| 3 | Delete install/cutover-gate.zsh | 2718b21 | install/cutover-gate.zsh (deleted) |
| 4 | Delete 8 v1 leftover taskfiles | 696f6da | taskfiles/{common,profile,brew,profile-tasks,claude-stub,brew-stub,links-stub}.yml, taskfiles/macos.v1.yml.bak |
| 5A | Migrate motd assets (motd.zsh path rewrite) | b4ff3e8 | shell/functions/motd.zsh |
| 5B | Delete v1 zsh/ tree | 562fe6b | zsh/ (38 files) |
| 6 | Delete 4 v1 install Brewfiles | e73d6a4 | install/Brewfile{,-personal,-server,-work}.rb |
| 7 | Delete docs/CUTOVER.md + docs/MIGRATION.md | b3c4a76 | docs/CUTOVER.md, docs/MIGRATION.md, Taskfile.yml (comment fix) |
| 8 | Rewrite README.md fresh-install section | 3749d9a | README.md |
| 9 | Doc-drift rewrite pass | a185c63 | docs/SECURITY.md, taskfiles/lint.yml, taskfiles/README.md |
| 10 | LINT-05 pattern-citation rewrite (6 files) | ade7078 | os/defaults/{dock,finder,input,screenshots,security}.zsh, os/shell-registration.zsh |
| 11 | Verify D-07 SSH-key rewrite scope empty | (no commit) | (verification-only) |
| 12 | Write 11-VERIFICATION.md | 1e2f2b3 | .planning/phases/11-v1-removal/11-VERIFICATION.md |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Stale doc reference] Taskfile.yml setup: comment referenced deleted docs**

- **Found during:** Task 7 (deletion of docs/CUTOVER.md + docs/MIGRATION.md)
- **Issue:** `Taskfile.yml:132` had `# ... bootstrap.zsh, docs/CUTOVER.md, docs/MIGRATION.md, CLAUDE.md, ...` in the setup: task's leading comment, naming the two files about to be deleted as cross-references.
- **Fix:** Rewrote the comment to reference `README.md` (which carries the operator-facing `task setup -- <machine-name>` instruction post-Phase-11) instead of the deleted docs.
- **Files modified:** Taskfile.yml
- **Commit:** b3c4a76 (folded into Task 7 commit alongside the doc deletes)

### Lint baseline shift (NOT a deviation)

`task lint:taskfile` failure count dropped from 25 (pre-Phase-11) to 11 (post-Phase-11). The 14-failure reduction came from deleting the 8 v1 leftover taskfiles in Task 4 (those carried 9 LINT-03a + 5 LINT-02 failures attached to them). The plan documented a 24-baseline pre-Phase-11 figure (off by one from actual 25); intent honored. The post-Phase-11 11-failure residue (LINT-02 in claude.yml + identity.yml + manifest.yml + packages.yml, LINT-03b in test fixtures + README.md mentions of bare-ln-s pedagogical examples, LINT-03a in shell.yml + manifest.yml + brew.yml-replaced-by-packages.yml) is out of Phase 11 scope.

### Grep gate residue (documented, NOT a deviation)

Plan anticipated 5 hits in install/README.md; actual: 4. The 5th (line 30 "v1 transitional state") does not match `git grep -E '\bv1\b'` because POSIX ERE does not honor `\b` as a word boundary. Hard-zero gate (excluding install/README.md) reports `hardzero-hits: 0`. All deferred to Phase 14 TRIM-03.

### Steady-state install (documented in 11-VERIFICATION.md)

`task install` on personal-laptop failed with a pre-existing environmental
condition: `/Users/josh/.config/claude/hooks/post-compact.zsh` is a regular
file (md5-identical to the source) where the install pipeline expects either
a symlink or a missing target. This is unrelated to Phase 11 deletions — the
cutover-gate.zsh removal does not touch links:claude. The simplified install
pipeline composition (no preconditions, no cutover:ack) is verified directly
from Taskfile.yml and via `task --list`. RMV-07's underlying contract is
satisfied unconditionally; operator clears the literal exit-0 run with a
file fix-up.

## Key Decisions Made

- **Two-commit split for Task 5 (zsh/ tree deletion)** preserves the
  green-tree-per-commit invariant. Commit A migrates the motd-asset path
  references in `shell/functions/motd.zsh`; Commit B then runs `git rm -r
  zsh/`. The motd assets already existed at `configs/motd/` from prior
  Phase 7 work (md5-identical) — Commit A only had to rewrite the two path
  string references, not move files.

- **Documented-residue grep gate (Option A)** instead of strict zero across
  the whole repo. Phase 14 TRIM-03 will handle the `install/README.md`
  cleanup (5 references) and Phase 14 TRIM-04 will handle the
  `.claude/CLAUDE.md` cutover-gate.zsh listing dedupe.

- **D-07 SSH-key rewrite scope verified empty.** The pattern-mapper's
  finding at planning time was correct: no
  `identity/ssh/identities/server-{1,2}` or `identity/ssh/keys/server-{1,2}.pub`
  files exist on disk; `grep -rn cutover identity/` returns zero. Task 11
  produced no commit.

- **Per-task single-commit boundaries** (one commit per RMV requirement)
  for review tractability, except RMV-04 which spans Tasks 1, 3, 7 because
  the cutover infrastructure has multiple physical files
  (Taskfile.yml + install/cutover-gate.zsh + docs/CUTOVER.md + docs/MIGRATION.md)
  that can't all be touched in one logical change without confusing the
  callers-first ordering.

## Verification Status

See `11-VERIFICATION.md` for the full verification report.

- **7/7 must-have truths verified** (RMV-01..RMV-07)
- **SC#5 grep gate:** `hardzero-hits: 0` outside the documented residue set
- **Deferred items:** `install/README.md` cleanup (Phase 14 TRIM-03),
  `.claude/CLAUDE.md` cutover-gate.zsh listing (Phase 14 TRIM-04),
  operator-machine post-compact.zsh file fix-up (out of repo scope)

## Self-Check: PASSED

- 11-VERIFICATION.md exists at `.planning/phases/11-v1-removal/11-VERIFICATION.md` -- FOUND
- Commit 3c5b061 (Task 1) -- FOUND
- Commit 858a07d (Task 2) -- FOUND
- Commit 2718b21 (Task 3) -- FOUND
- Commit 696f6da (Task 4) -- FOUND
- Commit b4ff3e8 (Task 5A) -- FOUND
- Commit 562fe6b (Task 5B) -- FOUND
- Commit e73d6a4 (Task 6) -- FOUND
- Commit b3c4a76 (Task 7) -- FOUND
- Commit 3749d9a (Task 8) -- FOUND
- Commit a185c63 (Task 9) -- FOUND
- Commit ade7078 (Task 10) -- FOUND
- Commit 1e2f2b3 (Task 12) -- FOUND
- `install/cutover-gate.zsh` deleted -- CONFIRMED
- `zsh/` tree deleted -- CONFIRMED
- 4 install/Brewfile*.rb deleted -- CONFIRMED
- 8 v1 leftover taskfiles deleted -- CONFIRMED
- docs/CUTOVER.md + docs/MIGRATION.md deleted -- CONFIRMED
- configs/motd/motd_sysinfo.jsonc + motd_tron.txt present -- CONFIRMED
- shell/functions/motd.zsh references configs/motd/, not zsh/configs/ -- CONFIRMED
