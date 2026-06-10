# Lint Fixes -- Path to a Perfectly Clean `task lint`

Status as of 2026-06-09. The lint suite (LINT-02..12; 01 and 06 intentionally
absent) reports **zero failures**. The only remaining output is LINT-05's
warn-only portability hints, which are intentional macOS-only code paths.
This document lists each remaining item and the exact remediation, plus the
rules for keeping the suite clean. Nothing here blocks `task lint` (it exits
0 by design); "perfectly clean" means zero warnings as well.

## Resolved during the 2026-06-09 lint hardening (no action needed)

| Item | Resolution |
|------|------------|
| LINT-09 drift (`model` key written by the `/model` CLI command) | `model` is now a preserved CLI-managed key in `claude:settings-compose` and `claude:audit`, alongside `enabledPlugins` and `extraKnownMarketplaces`. Drift from `/model` use can no longer occur. |
| LINT-02 silently broken on macOS (BSD awk rejected multi-line `-v` allow-lists) | Allow-list is now space-separated before the awk handoff. Fixture `02f-multi-local-vars-violation` pins the bug class. |
| LINT-02 false positive on `read`-defined vars (`taskfiles/links.yml` `install-claude` status block) | Surfaced by the awk fix; the allow-list now recognizes `read [-flags] VAR` alongside `VAR=` and `for VAR in`. Fixture `02g-read-var-ok` pins it. Zero genuine `$VAR`-in-status violations remain. |
| LINT-05 flagged markdown prose (`os/README.md`) | Scan scoped to `--include='*.zsh'`. |

## Remaining: LINT-05 portability hints (warn-only, 5 patterns / 10 lines)

These are deliberate macOS-only commands. LINT-05 exists as a forward signal
for a future Linux port (see `PROJECT.md`); until a Linux machine enters
scope, accepting these warnings is the documented default
(`os/README.md` §expected LINT-05 warnings, deferred to `LINUX-V2-05` /
`LINUX-V2-06`).

| Location | Command | Remediation when Linux enters scope |
|----------|---------|--------------------------------------|
| `shell/functions/pubkey.zsh:23` | `pbcopy` | Dispatch on `$OSTYPE`: `pbcopy` (darwin) vs `xclip -selection clipboard` / `wl-copy` (linux). |
| `os/defaults/appearance.zsh:45` | `osascript` | Whole file is a macOS defaults concern; gate the file at the taskfile layer (only run `os/defaults/*` on darwin) rather than per-line. |
| `os/defaults/_apply_verify.zsh:41,67` | `defaults write` / `defaults read` | Same as above -- the apply/verify engine is inherently `defaults`-based; platform-gate the caller. |
| `shell/aliases/finder.zsh:23,28` | `defaults write` | Finder-specific aliases; wrap the alias definitions in a darwin guard via `_dotfiles_feature` or `$OSTYPE` check. |
| `os/hostname.zsh:64` | `defaults write` (SMB NetBIOSName) | macOS hostname stack (`scutil`/`defaults`); Linux port would swap in `hostnamectl`. Platform-gate the script. |
| `os/shell-registration.zsh:39,56` | `dscl` | macOS directory services; Linux equivalent is `chsh`/`getent`. Platform-gate the script. |

To silence them today (not recommended -- the warnings are the inventory the
future Linux port will work from): the rule is warn-only and exits 0, so the
only "fix" is the real platform guard above. There is deliberately no
`lint-allow` escape for LINT-05.

## How to keep the suite clean

| Rule | What trips it | Fix |
|------|---------------|-----|
| LINT-02 | `$VAR` in a `status:` block that is not assigned in the same entry (`VAR=`, `for VAR in`, `read -r VAR`) | Use `{{.VAR}}` template vars for go-task values; shell vars only when defined inside the same status entry. |
| LINT-03a | Task with `cmds:` but no `status:` | Add a `status:` block, mark `internal: true`, or make every cmd a `task:` delegation. |
| LINT-03b | Bare `ln -s` outside `taskfiles/helpers.yml` | Use the `_:safe-link` helper. |
| LINT-04 | Executable `.zsh` without `set -euo pipefail` in the first 30 lines | Add the line; `set -e` alone is not accepted. |
| LINT-05 | macOS-only command in `shell/`/`os/` `.zsh` | Warn-only; see table above. |
| LINT-07 | `zsh -n` / taskfile YAML parse failure | Fix the syntax error it prints. |
| LINT-08 | Public top-level task missing from the bare-`task` banner | Add the task name to `default:`'s banner block in `Taskfile.yml`. |
| LINT-09 | `claude/settings.json` drifts from composed fragments | Edit `claude/settings.d/*.json` and run `task claude:settings-compose`; never hand-edit `settings.json`. `enabledPlugins`, `extraKnownMarketplaces`, and `model` are preserved from the live file automatically. |
| LINT-10 | Hardcoded `/opt/homebrew` or `/usr/local` in `.zsh`/`.yml` | Use `$HOMEBREW_PREFIX` / `{{.HOMEBREW_PREFIX}}`. A genuine arch-dispatch site gets a same-line `# lint-allow: hardcoded-prefix`. |
| LINT-11 | Kebab-case feature key via template dot-access (`.MANIFEST.features.foo-bar`) | Use the index form: `{{if index .MANIFEST.features "foo-bar"}}`. |
| LINT-12 | `.zsh` file missing the header banner | Add the Purpose / Depends on / Side effects block between two `# ===` 77-char rules within the first 30 lines. |

Self-test: `task test` runs `lint:test-fixtures` (33 fixtures, positive and
negative cases per rule). Any change to a rule body in `taskfiles/lint.yml`
must keep the mirrored fixture-branch logic in `lint:test-fixtures` aligned
and should add a fixture pinning the new behavior.
