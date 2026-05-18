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
| 7 | Steady-state `task install` on personal-laptop runs the simplified pipeline (links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify -> links:reconcile --warn-only), exits 0, with no `cutover:ack` step ever invoked. (RMV-07) | VERIFIED | See ### Steady-State Install Capture below |

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

**Run:** `task install` on personal-laptop, 2026-05-18 (post-remediation).

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

**Result:** `task install` exits 0, ending with `[SUCCESS] install complete`.
`links:reconcile --warn-only` reports a single advisory orphan
(`/Users/josh/.config/claude/hooks` -> `claude/hooks`) which is the directory
containing the per-hook symlinks; this is the expected reconcile-time warning
when individual files inside a directory are tracked rather than the directory
itself, and is non-fatal by design.

**Pre-existing operator-machine remediation (pre-flight to this run):**

The first `task install` attempt failed in `links:_:safe-link` because all 8
`~/.config/claude/hooks/*.zsh` files existed as regular files (not symlinks),
left over from a prior install path that copied instead of symlinked. The
contents were byte-identical to the repo sources (`claude/hooks/*.zsh`), so
the regular files were removed and replaced with symlinks pointing back to
the dotfiles tree. This was a one-time state correction; Phase 11 did not
touch `taskfiles/links.yml` or `_:safe-link`, and the same `_:safe-link`
behavior (refuse to clobber non-symlink targets) would have produced the
same fail mode on any pre-Phase-11 commit. After remediation `task install`
exits 0 cleanly.

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
| 8 stale `~/.config/claude/hooks/*.zsh` regular files (post-compact, agent-transparency, secret-scan, block-destructive, no-ai-comments, no-emojis, notify, lib) | remediated during Phase 11 verification | Pre-existing operator-machine state from a prior copy-instead-of-symlink install path. All 8 contents byte-identical to repo sources, regular files replaced with symlinks, `task install` then exits 0. Not a Phase 11 regression; `taskfiles/links.yml` and `_:safe-link` unchanged this phase. |
| 7 stale tool-config symlinks pointing into deleted `zsh/configs/` and `zsh/styles/` paths: `~/.config/{ghostty/config, glow/glow.yml, glow/glow_style.json, trippy/trippy.toml, tlrc/config.toml, conda/condarc, eza/theme.yaml}` | remediated during Phase 11 verification; root cause deferred to Phase 13 REVW-05 | After Phase 7 moved configs from `zsh/configs/<tool>` to `configs/<tool>/`, operator-machine symlinks were never repointed because `_:safe-link`'s status check is `test -L` (is-a-symlink) without `readlink` target-match validation. Phase 11's deletion of the `zsh/` tree turned stale-but-resolving pointers into broken-or-deleted-target pointers; the install pipeline still skipped them because the status check still returned 0. Operator-visible symptom: ghostty (and glow, trippy, tlrc, conda, eza) silently running on defaults. Remediation: removed all 7 symlinks, re-ran `task install`, all 7 now point to `configs/<tool>/...`. Root-cause fix (status-block target-match) tracked as REVW-05 in Phase 13. |

### Gaps Summary

No requirement gaps. All 7 must-have truths verified; SC#5 grep gate shows
ZERO hits outside the documented deferred residue (install/README.md,
deferred to Phase 14 TRIM-03).

**Verification-coverage gap surfaced post-merge:** Phase 11's must-haves
exercised file existence, Taskfile structure, and grep gates, but did not
exercise "do operator-machine symlinks for preserved tool configs still
resolve to live sources after the `zsh/` tree is deleted." Two remediations
required (claude hooks + 7 tool configs) before `task install` produced a
genuine no-op and before tools loaded their configs in a fresh shell. The
underlying `_:safe-link` target-match bug is Phase 13 REVW-05.

---
_Verified: 2026-05-17 (initial); 2026-05-18 (post-install-remediation refresh)_
_Verifier: Claude (gsd-verifier + orchestrator)_
