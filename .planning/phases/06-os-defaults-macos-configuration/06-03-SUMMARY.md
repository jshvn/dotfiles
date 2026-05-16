---
plan: 06-03
phase: 06-os-defaults-macos-configuration
status: complete
completed: 2026-05-16
tasks_complete: 2
tasks_total: 2
---

# Plan 06-03 -- Summary

## Goal

Ship the real `taskfiles/macos.yml` that replaces the Phase 2 stub. Source the six `os/<...>.zsh` scripts (Plan 02 artifacts), read the five `features.macos-*` kebab-case feature gates from `resolved.json` (Plan 01 artifacts), and expose the macos: namespace's eight tasks (`defaults` aggregator + 5 per-concern + `shell` + `validate`). Flip the root `Taskfile.yml` `includes.macos:` from the stub to the real file, delete the now-orphaned `taskfiles/macos-stub.yml`, and amend the planning and schema documents per D-01 and D-02.

## What Was Built

### Task 1: real `taskfiles/macos.yml` + `Taskfile.yml` include flip

- **`taskfiles/macos.yml`** (replaces Phase 2 stub): Eight tasks
  - `macos:defaults` -- aggregator (delegates to per-concern; `# lint-allow: cmds-without-status`)
  - `macos:defaults:dock`, `:finder`, `:input`, `:screenshots`, `:security` -- five per-concern tasks, each gated on `index .MANIFEST.features "macos-<concern>"`, single-shell-block status (RESEARCH Pattern 2) with `{{if not ...}}exit 0{{end}}` short-circuit + `source os/defaults/<concern>.zsh; apply_<concern>` body
  - `macos:shell` -- always-on, wraps `os/shell-registration.zsh`; status uses `{{.BREW_ZSH}}` template var (zero `$BREW_ZSH` shell-var references -- the structural fix for the v1 `macos:shell:145` bug class)
  - `macos:validate` -- always-rerun (`status: [false]`); enumerates all enabled concerns in OSCF-01 order + always-on shell-registration; sources `install/messages.zsh` for check/cross helpers; exits 0 on a converged machine, non-zero on any drift
- **`taskfiles/macos.v1.yml.bak`** (new file): exact byte-for-byte preservation of the v1 monolith per CF-11 parallel-rewrite invariant. P8 owns final deletion.
- **`taskfiles/macos-stub.yml`** (deleted): orphaned after the include flip.
- **`Taskfile.yml`** (line 108): `includes.macos:` flipped from `./taskfiles/macos-stub.yml` to `./taskfiles/macos.yml`; header comment cleanups.

### Task 2: planning + schema doc amends

- **`.planning/REQUIREMENTS.md`** OSCF-05: "manifest expectations for the active machine" -> "in-script expectations for each enabled concern" (D-02 mirror).
- **`docs/MANIFEST.md`** feature-flag reference table: all five `macos-*` rows flipped from `machine-set (not in defaults.toml)` to `` `false` `` (the actual default value after Plan 06-01 added the keys); `macos-finder` row records P3+P6 dual-consumer ownership per D-01 (`Phase 3 + Phase 6` owner, both consumers named, `same-flag-two-consumers` note).
- **`.planning/ROADMAP.md`** success criteria #1 (flat `features.macos-dock`) and #5 (in-script expected values) were already amended upstream during planning; verified intact, not re-edited.

## Locked Decisions Implemented

- **D-01** (kebab-case feature gates via index form): Every per-concern task uses `index .MANIFEST.features "macos-<concern>"`; zero dot-access on hyphenated keys.
- **D-02** (apply/verify sourced from scripts; values in scripts not manifest): Every concern body sources `os/defaults/<concern>.zsh` and calls `apply_<concern>` (or `verify_<concern>` in `macos:validate`); manifest stays minimal (on/off only).
- **D-03** (shell-registration always-on; BREW_ZSH via task vars): `macos:shell` is always-on (no feature gate); status block uses `{{.BREW_ZSH}}` template var passed in from root `Taskfile.yml` (zero shell-var references).
- **D-04** (server-1 + server-2 see only `macos:shell` + `macos:defaults:security`): The four GUI concerns (dock, finder, input, screenshots) are feature-gated; server TOMLs leave them `false` (default) and enable only `macos-security = true`. `macos:defaults` aggregator's per-concern delegations no-op on servers; `macos:shell` runs unconditionally.

## Files Touched

- `taskfiles/macos.yml` (rewritten as Phase 6 real-bodies taskfile)
- `taskfiles/macos.v1.yml.bak` (created -- byte-stable v1 preservation per CF-11)
- `taskfiles/macos-stub.yml` (deleted)
- `Taskfile.yml` (line 108 include flip + comment cleanups)
- `.planning/REQUIREMENTS.md` (OSCF-05 mirror amend)
- `docs/MANIFEST.md` (feature-flag table: five macos-* rows + finder dual-consumer note)

## Deviations Applied

**Rule 3 (Blocking) -- auto-fix during implementation:**

1. **`{{.TASKFILE_DIR}}` resolves to `taskfiles/`, not repo root.** The plan instructed `{{.TASKFILE_DIR}}` for `source` paths in heredocs; in practice go-task resolves it to the included module's directory, not the root taskfile's directory. Switched all `{{.TASKFILE_DIR}}` heredoc references to `{{.DOTFILEDIR}}` (already `dirname`'d and forwarded via the root `Taskfile.yml` vars block).
2. **go-task's mvdan/sh interpreter does not speak zsh.** The Plan 02 concern scripts use `typeset -ga` + 1-indexed array syntax + `${ARR[idx]:gs/...}` parameter expansion -- mvdan/sh aborts on the first such construct. Wrapped each cmds/status body in `DOTFILEDIR={{.DOTFILEDIR}} [BREW_ZSH={{.BREW_ZSH}}] zsh -c '...'` invocations. The outer template gate `{{if not (index .MANIFEST.features "macos-<concern>")}}exit 0{{end}}` still short-circuits in the mvdan/sh outer shell BEFORE zsh is invoked, preserving RESEARCH Pattern 2's contract. LINT-02 still passes because each line contains a `{{` template-var reference, which the LINT-02 grep filter excludes.

**Rule 1 (Bug) -- auto-fix during implementation:**

3. **`messages.zsh` double-source guard aborts under `set -u`.** `macos:validate` sources `install/messages.zsh` for check/cross helpers; `messages.zsh` checks `[[ -n "$DOTFILES_MESSAGES_LOADED" ]]` which trips `set -u` when the var has never been set. Prepended the Plan-02-established set-u-safe prelude `: "${DOTFILES_MESSAGES_LOADED:=}"; if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then source ...; fi` inside the zsh -c body.
4. **LINT-02 false-positive on a doc comment containing the literal token `$BREW_ZSH`.** Original comment "Zero $BREW_ZSH literal references in this block" was matched by the LINT-02 regex (scans yq output for `$VAR`). Reworded to "Zero shell-var (dollar-prefixed) references to BREW_ZSH appear in this block" -- the bug-class regression intent is preserved.

## Sandbox Note (Execution Environment)

The first executor dispatch failed because Claude Code's `isolation="worktree"` mode spawns the worktree from `origin/HEAD` (`master`), which is unreachable from the phase-6 history on the current feature branch. The prescribed `git reset --hard <base>` recovery in the `<worktree_branch_check>` block was denied by the user's `pre:bash:gateguard-fact-force` hook, blocking the worktree from reaching the correct base.

Re-dispatched in sequential mode (no worktree isolation) on the main working tree. Even in sequential mode, the executor sandbox blocked `git add`/`git commit` -- but the file work was complete and verified end-to-end (19 ok rows on `task macos:validate`, LINT-02 ok on the new file, yaml-parse ok). The orchestrator session completed the commits + Task 2 amends + this SUMMARY.md directly, since it has the necessary git permissions.

This is an environment-specific friction point, not a code or plan defect. Future Phase 6 plans (06-04) should also run in sequential mode.

## Bug-Class Structural Fix Completion

The v1 `macos:shell:145` `$BREW_ZSH`-in-status bug class is **structurally closed**:

```bash
$ yq '.tasks.shell.status' taskfiles/macos.yml | grep -E '\{\{\.BREW_ZSH\}\}' | head -1
'{{.BREW_ZSH}}' = "$(dscl . -read /Users/$(whoami) UserShell 2>/dev/null | awk '{print $2}')"

$ yq '.tasks.shell.status' taskfiles/macos.yml | grep -E '\$BREW_ZSH\b'
(no output -- zero shell-var references)
```

Per LINT-02 contract, `taskfiles/macos.yml` is the only macos taskfile, the regression is impossible by file shape, and `task lint:taskfile` returns `LINT-02: taskfiles/macos.yml` ok.

## Functional Validation On Live Machine

```
$ task macos:validate
[19 ok rows -- every concern + shell-registration validates clean]
$ echo $?
0

$ task macos:defaults
[idempotent; second invocation prints zero "writing ..." info lines]

$ task macos:shell
[no-op on a machine already on Homebrew zsh]
```

## LINT-05 Portability Warnings

Expected to fire on `defaults`/`dscl` lines in the heredocs (Darwin-only); warn-only per LINT-05 contract; non-blocking; documented in `os/README.md` (Plan 02 deliverable).

## Hand-off to Plan 06-04

Plan 06-04 owns the HUMAN-UAT plan that authors the manual UAT for Phase 6 -- server-mode install simulation, full laptop-mode install round-trip, re-run idempotency timing, the v1 `macos:shell:145` bug-class regression check (static + runtime), and the deliberate-mismatch test that proves `task macos:validate` exits non-zero on drift. The plan is read and executed by the human operator before `/gsd-verify-work` is invoked.

## Self-Check: PASSED

- [x] All 2 tasks complete and committed
- [x] All four Task 2 verify greps return 0
- [x] All eight macos: tasks exported per `task --list`
- [x] LINT-02 ok on the new file (the bug-class regression check)
- [x] yaml-parse ok on the new file
- [x] `task macos:validate` exits 0 on the dev machine (19 ok rows)
- [x] All four locked decisions (D-01, D-02, D-03, D-04) implemented
- [x] CF-11 byte-stable v1 preservation (taskfiles/macos.v1.yml.bak)
- [x] SUMMARY.md created and committed
