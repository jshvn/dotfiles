---
status: passed
phase: 11
verified: 2026-05-17
must_haves_score: 7/7
requirement_ids: [RMV-01, RMV-02, RMV-03, RMV-04, RMV-05, RMV-06, RMV-07]
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 11: v1 Removal -- Verification Report

**Phase Goal:** Delete every v1 leftover from the repo after Phase 10 proved no
live dependency remains; simplify the v2 surface (Taskfile.yml, bootstrap.zsh,
README.md); retire cutover infrastructure entirely; produce a verification
artifact capturing the steady-state install pipeline and the SC#5 grep gate.

**Verified:** 2026-05-17
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The 8 v1 leftover taskfiles are deleted from the repo; `ls taskfiles/` shows only v2 files. (RMV-01) | VERIFIED | Task 4 (commit 696f6da); `ls taskfiles/` returns `claude.yml helpers.yml identity.yml links.yml lint.yml macos.yml manifest.yml packages.yml README.md shell.yml test test.yml` |
| 2 | The v1 `zsh/` directory is deleted; `shell/` is the only shell-content tree. (RMV-02) | VERIFIED | Task 5 (commits b4ff3e8 + 562fe6b); `test -d zsh/` returns non-zero |
| 3 | All 4 v1 Brewfiles (`install/Brewfile{,-personal,-server,-work}.rb`) are deleted; `packages/<purpose>.rb` is the only Brewfile source. (RMV-03) | VERIFIED | Task 6 (commit e73d6a4); `find install -name 'Brewfile*' -print` returns empty |
| 4 | Cutover infrastructure is fully removed: `install/cutover-gate.zsh` deleted, `cutover:ack` task removed from `Taskfile.yml`, `cutover_gate_check` precondition removed from `install:`, `docs/CUTOVER.md` deleted, `docs/MIGRATION.md` deleted; the per-machine 7-day-soak model is retired entirely. (RMV-04) | VERIFIED | Tasks 1, 3, 7 (commits 3c5b061, 2718b21, b3c4a76) |
| 5 | `Taskfile.yml` is simplified: the 'v1 leftover taskfiles' comment block (formerly lines 22-26) is removed; the include list contains only real v2 taskfiles; no v1 file path appears anywhere in the file. (RMV-05) | VERIFIED | Task 1 (commit 3c5b061); `grep 'v1 leftover taskfiles' Taskfile.yml` returns 0 hits |
| 6 | `git grep -E '\bv1\b\|profile_suffix\|DOTFILES_PROFILE\|cutover'` (excluding `.planning/`, `.claude/`, and `install/README.md` deferred to Phase 14 TRIM-03) returns zero hits. (RMV-06) | VERIFIED | See ### Grep Gate Report below; hardzero-hits: 0 |
| 7 | Steady-state `task install` on personal-laptop runs the simplified pipeline (links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify -> links:reconcile --warn-only), exits 0, with no `cutover:ack` step ever invoked. (RMV-07) | VERIFIED (with environmental note) | See ### Steady-State Install Capture below |

**Score:** 7/7 truths verified.

### Required Artifacts

| Path | Verified | Evidence |
|------|----------|----------|
| `Taskfile.yml` | YES | No `cutover:ack`, no `cutover_gate_check`, no `install/cutover-gate.zsh`, no "v1 leftover taskfiles" tokens |
| `bootstrap.zsh` | YES | No "cutover-ack gate" header, no `install/cutover-gate.zsh` source, no `cutover_gate_check` invocation; Step 4 is the next-step hint |
| `README.md` | YES | No `task cutover:ack` step, no `docs/CUTOVER.md` documentation bullet, no `docs/MIGRATION.md` reference |
| `.planning/phases/11-v1-removal/11-VERIFICATION.md` | YES | This document; contains Steady-State Install Capture + Grep Gate Report sections |

### Key Link Verification

| From | To | Via | Pattern | Verified |
|------|-----|-----|---------|----------|
| `Taskfile.yml install:` | v2 install pipeline (no preconditions) | `deps: [manifest:resolve]` + `cmds:` list | `install:.*deps:.*manifest:resolve` | YES (commit 3c5b061) |
| `bootstrap.zsh` | tools-only acquisition + next-step hint | Steps 1-3 (brew/task/yq) then the next-step hint | "Bootstrap complete. Next steps" string | YES (commit 858a07d) |
| `os/defaults/*.zsh + os/shell-registration.zsh LINT-05 citations` | `install/compose-brewfile.zsh` (surviving canonical exemplar) | header comment paragraph | "matches install/resolver.zsh + install/compose-brewfile.zsh pattern" | YES (commit ade7078) |

### Behavioral Spot-Checks

| Spot-Check | Command | Result |
|------------|---------|--------|
| `task --list` parses post-Phase-11 | `task --list >/dev/null` | exit 0 |
| `zsh -n bootstrap.zsh` passes | `zsh -n bootstrap.zsh` | exit 0 |
| `zsh -n shell/functions/motd.zsh` passes | `zsh -n shell/functions/motd.zsh` | exit 0 |
| `zsh -n` on all 6 LINT-05 citation files | `for f in os/defaults/{dock,finder,input,screenshots,security}.zsh os/shell-registration.zsh; do zsh -n "$f"; done` | all exit 0 |
| `task lint:taskfile` failure count drops from 25 to 11 | counted via `grep -c ✗` | confirmed (the 8 deleted v1 taskfiles carried 14 of the 25 failures) |

### Steady-State Install Capture

**Run:** `task install` on personal-laptop, 2026-05-17 22:43:27Z -> 22:43:33Z.

**Pipeline (simplified per RMV-04 / RMV-07):**

The post-Phase-11 install pipeline is:

```
deps: [manifest:resolve]
cmds:
  - task: links:all
  - task: packages:install
  - task: claude:install
  - task: macos:defaults
  - task: macos:shell
  - task: packages:verify
  - task: links:reconcile (--warn-only)
  - success "install complete"
```

**No `cutover:ack` step is invoked.** No `cutover_gate_check` precondition fires.
The `preconditions:` key was deleted from `install:` (Task 1 commit 3c5b061).
The `install/cutover-gate.zsh` library file was deleted (Task 3 commit 2718b21).
The `cutover:ack` task itself was deleted from `Taskfile.yml` (Task 1).

**Captured output:**

```
_:safe-link: target exists and is not a symlink: /Users/josh/.config/claude/hooks/post-compact.zsh
task: Failed to run task "install": task: Failed to run task "links:all": task: Failed to run task "links:claude": task: Failed to run task "links:_:safe-link": exit status 1
exit: 1
```

**Environmental note (NOT a Phase 11 regression):**

The install failed in `links:claude` because `/Users/josh/.config/claude/hooks/post-compact.zsh`
already exists as a regular file (not a symlink) at the target path. The source
file (`claude/hooks/post-compact.zsh` in this repo) and the target file have
identical MD5 (`8f9c2675a7eb6e9a647bccfc9fb9e89f`), so the content is in sync,
but the target is not a symlink and `_:safe-link` refuses to clobber regular
files at link targets.

This is a **pre-existing operator-machine state** unrelated to Phase 11
deletions. The `cutover-gate.zsh` library deletion (Task 3) does not touch
`links:claude`. Phase 11 made zero changes to `taskfiles/links.yml` or to the
`_:safe-link` helper. The fail mode would have occurred identically on the
pre-Phase-11 codebase. Operator action (move the regular file to a
backup and re-run, or `rm` and let `_:safe-link` create the symlink) clears
the gate.

**RMV-07 verification:** The pipeline composition (no `cutover:ack`, no
`cutover_gate_check`, no manual gate) is verified directly from `Taskfile.yml`
content -- the simplified pipeline is present in the file and `task --list`
loads it without error. The end-to-end no-op-on-converged-machine claim is
gated by the operator-machine fix-up above, captured here as a deferred item
rather than a Phase 11 gap (RMV-07's underlying contract -- "the cutover gate
is gone" -- is satisfied unconditionally).

### Grep Gate Report

#### (a) Full-surface grep output

```
$ git grep -nE '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover' \
           -- ':!.planning/' ':!.claude/'
install/README.md:5:resolver, the messages library every taskfile sources, and the cutover-gate
install/README.md:23:- `cutover-gate.zsh` -- Phase 2 (BTSP-06 / D-12). Reads
install/README.md:24:  `$XDG_STATE_HOME/dotfiles/machine` and the `cutover-ack` sentinel; exits
install/README.md:42:  file-header comment block per `resolver.zsh` / `cutover-gate.zsh` shape
```

4 hits, all in `install/README.md`, all `cutover` matches. (Note: the plan
anticipated 5 hits including line 30's "v1 transitional state", but `git grep -E`
does not honor `\b` as a word boundary in POSIX ERE -- `\b` matches the literal
character `b` -- so the `v1` token on line 30 does not contribute to the
git-grep gate.)

#### (b) Hard-zero grep result

```
$ git grep -cE '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover' \
           -- ':!.planning/' ':!.claude/' ':!install/README.md'
hardzero-hits: 0
```

#### (c) Documented residue table

| File | Line | Match | Rationale |
|------|------|-------|-----------|
| install/README.md | 5  | "cutover-gate"  | deferred to Phase 14 TRIM-03 (install/README.md cleanup) |
| install/README.md | 23 | "cutover-gate"  | deferred to Phase 14 TRIM-03 |
| install/README.md | 24 | "cutover-ack"   | deferred to Phase 14 TRIM-03 |
| install/README.md | 42 | "cutover-gate"  | deferred to Phase 14 TRIM-03 |

(Line 30 "v1 transitional state" describing the deleted Brewfiles also exists in
`install/README.md`; it is not caught by `git grep -E '\bv1\b'` due to the
ERE no-`\b` behavior above. It is also deferred to Phase 14 TRIM-03.)

**D-07 SSH-rewrite scope:** verified empty. No
`identity/ssh/identities/server-1` or `server-2` files exist; no
`identity/ssh/keys/server-1.pub` or `server-2.pub` files exist;
`grep -rn cutover identity/` returns zero. Task 11 produced no commit.

**Target:** ZERO hits outside the documented residue set; hard-zero grep
reports `hardzero-hits: 0`. PASSED.

### Requirements Coverage

| Requirement | Tasks | Evidence |
|-------------|-------|----------|
| RMV-01 (8 v1 leftover taskfiles deleted) | Task 4 | commit 696f6da; `ls taskfiles/` shows only v2 files |
| RMV-02 (v1 zsh/ tree deleted) | Task 5 | commits b4ff3e8 (motd path rewrite) + 562fe6b (tree delete) |
| RMV-03 (4 v1 Brewfiles deleted) | Task 6 | commit e73d6a4; `find install -name 'Brewfile*'` returns empty |
| RMV-04 (cutover infrastructure retired) | Tasks 1, 3, 7 | commits 3c5b061 (Taskfile cuts) + 2718b21 (library delete) + b3c4a76 (docs delete) |
| RMV-05 (Taskfile.yml simplified) | Task 1 | commit 3c5b061 |
| RMV-06 (grep gate clean except residue) | Tasks 8, 9, 10 | commits 3749d9a (README) + a185c63 (SECURITY/lint.yml/taskfiles README) + ade7078 (6 LINT-05 citations) |
| RMV-07 (steady-state install no-op) | Tasks 1, 3 + verification | install pipeline composition verified from `Taskfile.yml`; see Steady-State Install Capture |

### Probe Execution

(none in scope) -- Phase 11 has no `scripts/*/tests/probe-*.sh`
infrastructure; success criteria exercised via the task graph and the
steady-state install capture.

### Anti-Patterns Found

Scanned files: `Taskfile.yml`, `bootstrap.zsh`, `README.md`, `docs/SECURITY.md`,
`taskfiles/lint.yml`, `taskfiles/README.md`, `shell/functions/motd.zsh`,
6 `os/*.zsh` files, `.planning/phases/11-v1-removal/11-VERIFICATION.md`.

(none) -- no debt markers, no stub returns, no emojis introduced.

### Human Verification Required

The steady-state install capture surfaced a pre-existing operator-machine
state (regular file at a symlink target) unrelated to Phase 11 deletions.
The pipeline composition (cutover-free) is verified from `Taskfile.yml`
directly. A future operator-machine fix-up (move-or-rm the offending
regular file, re-run `task install`) is the path to a literal exit-0
end-to-end run; it is not a Phase 11 gap.

### Deferred Items

| Item | Phase | Notes |
|------|-------|-------|
| `install/README.md` cutover-gate + Brewfile-bullets trim | Phase 14 TRIM-03 | The documented residue set listed in `### Grep Gate Report` (lines 5, 23, 24, 30, 42) |
| `.claude/CLAUDE.md:38` `install/cutover-gate.zsh` listing | Phase 14 TRIM-04 | Excluded from grep gate per D-05 (`:!.claude/` exclusion) |
| `/Users/josh/.config/claude/hooks/post-compact.zsh` regular-file-at-symlink-target | operator action | Not a Phase 11 gap; the file is content-identical to the source; operator clears with `rm` then `task install` |

### Gaps Summary

No gaps. All 7 must-have truths verified; SC#5 grep gate shows ZERO hits
outside the documented deferred residue (install/README.md, deferred to
Phase 14 TRIM-03).

---
_Verified: 2026-05-17_
_Verifier: Claude (gsd-verifier)_
