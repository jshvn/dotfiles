---
phase: 03-shell-layer-flat-content-port
plan: 02
subsystem: shell
tags: [shell, zsh, startup-files, antidote, compinit, manifest]
status: complete
completed: 2026-05-14
requirements: [SHEL-01, SHEL-02, SHEL-03, SHEL-04, SHEL-05, SHEL-10]
dependency_graph:
  requires: [03-01]
  provides:
    - shell/.zshenv (DOTFILES_MACHINE source surface; consumed by .zshrc warning)
    - shell/.zprofile (HOMEBREW_PREFIX exported via brew shellenv for .zshrc antidote block)
    - shell/.zshrc (runtime spine; consumes shell/aliases/*.zsh and shell/functions/*.zsh from Plans 03/04)
    - shell/.zlogin (motd dispatch; consumes motd function from Plan 03)
    - shell/.zlogout (history flush; standalone)
    - shell/theme.zsh (prompt + grc + man colors; sourced by .zshrc)
  affects: [shell/]
tech_stack:
  added:
    - antidote (zsh plugin manager; consumed via $HOMEBREW_PREFIX/share/antidote/antidote.zsh)
    - jq (inline read of resolved.json in .zprofile for one-password-ssh feature gate)
  patterns:
    - manifest-driven feature gating (CONCERNS.md hostname bug fix replacement)
    - compinit daily-rebuild cache (24h TTL, -C fast path otherwise)
    - flat aliases/functions globs with (.N) nullglob qualifier
    - graceful degrade on missing state (CF-05)
key_files:
  created:
    - shell/.zshenv
    - shell/.zprofile
    - shell/.zshrc
    - shell/.zlogin
    - shell/.zlogout
    - shell/theme.zsh
  modified: []
decisions:
  - "Used inline jq read in .zprofile for features.one-password-ssh (not _dotfiles_feature helper) because .zprofile runs BEFORE .zshrc sources the functions glob"
  - "Restructured .zshrc to set DOTFILEDIR before the antidote block so $_antidote_src can reference it"
  - "Used BSD stat -f %m with fallback to GNU stat -c %Y for portable mtime in compinit daily-cache age computation"
  - "Verbatim byte-identical copy for .zlogin, .zlogout, and theme.zsh (CF-02 / SHEL-05 verbatim port requirement)"
metrics:
  duration_minutes: 12
  tasks_completed: 4
  files_created: 6
  files_modified: 0
  bytes_added: 549 (lines: shell/.zshenv 80; .zprofile 68; .zshrc 127; .zlogin 20; .zlogout 57; theme.zsh 99 ~= 451 + comments)
---

# Phase 3 Plan 2: Shell Startup Files Port Summary

Ported v1 zsh startup files (.zshenv, .zprofile, .zshrc, .zlogin, .zlogout) and the alanpeabody-based theme into flat shell/ layout with three architectural changes: DOTFILES_PROFILE -> DOTFILES_MACHINE (state-file driven), antigen -> antidote (lazy bundle-cache), and profile-conditional alias/function loops -> flat globs.

## One-liner

Replaced v1 zsh startup files with manifest-driven, antidote-based, flat-globbed v2 equivalents while fixing the hostname-check CONCERNS bug and adding SHEL-10 compinit daily-rebuild caching.

## What landed

| File | Lines | Notes |
|------|-------|-------|
| `shell/.zshenv` | 80 | XDG/locale/HISTFILE block verbatim; DOTFILES_PROFILE block replaced with conditional read of `$XDG_STATE_HOME/dotfiles/machine`. Graceful degrade on missing state (no crash under set -u). |
| `shell/.zprofile` | 68 | Verbatim `uname -m` Homebrew shellenv with new `[[ -x DIRECTORY ]]` guard (SHEL-02). Replaces v1 hostname=='server' check (CONCERNS bug zsh/.zprofile:55-56) with inline jq read of `features."one-password-ssh"` from resolved.json. |
| `shell/.zshrc` | 127 | Heavy rewrite. Replaces antigen block with antidote bundle-cache logic (D-01..D-05); collapses v1's profile-subdir alias/function loops into flat globs (D-09); adds SHEL-10 compinit daily-rebuild cache; adds CF-05 interactive-only missing-machine warning. |
| `shell/.zlogin` | 20 | Byte-identical verbatim port (motd function-existence dispatch). |
| `shell/.zlogout` | 57 | Byte-identical verbatim port (fc -W history flush). |
| `shell/theme.zsh` | 99 | Byte-identical verbatim port per CF-02 / SHEL-05 (alanpeabody-based prompt unchanged). |

## Bug Fixes In Transit

- **Hostname-based SSH agent dispatch** (`zsh/.zprofile:55-56`): replaced literal `hostname -s != "server"` with manifest-driven `jq -r '.features."one-password-ssh"'` read. The new check evaluates only when `resolved.json` is readable; missing-state shells default to the system ssh-agent (graceful degrade per CF-05).
- **Antigen plugin manager** (`zsh/.zshrc:52-72`): replaced with antidote bundle-cache (SHEL-04). Cache rebuilds only when `configs/antidote/zsh_plugins.txt` is newer.
- **DOTFILES_PROFILE references** (`zsh/.zshrc:105-129`): collapsed into two flat `for file in shell/{aliases,functions}/*.zsh(.N)` loops (D-09).

## Bug Fixes NOT in scope

- `pubkey.zsh` docstring fix (cosmetic; Plan 03 owns shell/functions/*.zsh).
- aliaslist.zsh, functionlist.zsh, sshlist.zsh profile-subdir walk removal (Plan 03 owns those rewrites).
- motd.zsh SHEL-11 caching (Plan 03 owns the function body; .zlogin dispatch unchanged here).

## Deviations from Plan

None - plan executed exactly as written. All 4 tasks completed in order; all per-task acceptance criteria and the plan-level success criteria pass.

## Commits

| Task | Commit  | Files |
|------|---------|-------|
| 1    | 9618d04 | shell/.zshenv, shell/.zlogout |
| 2    | 5b49b4d | shell/.zprofile, shell/.zlogin |
| 3    | 7258c59 | shell/.zshrc |
| 4    | 613d8fd | shell/theme.zsh |

## Self-Check: PASSED

- All six files exist under shell/ and pass `zsh -n`.
- `grep -rE 'DOTFILES_PROFILE|antigen|ADOTDIR|hostname -s' shell/` returns no matches.
- `diff zsh/theme.zsh shell/theme.zsh`, `diff zsh/.zlogin shell/.zlogin`, `diff zsh/.zlogout shell/.zlogout` all empty.
- `grep -c '86400' shell/.zshrc` >= 1; `grep -c 'compinit -C -d' shell/.zshrc` >= 1 (SHEL-10).
- `grep -c 'antidote bundle' shell/.zshrc` >= 1 (SHEL-04).
- `XDG_STATE_HOME=/nonexistent zsh -c '. shell/.zshenv && . shell/.zprofile'` does not crash (graceful degrade verified).
- Commit hashes 9618d04, 5b49b4d, 7258c59, 613d8fd all present in `git log`.
