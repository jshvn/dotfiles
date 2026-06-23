# Lint Fixes -- Path to a Perfectly Clean `task lint`

The lint suite (LINT-02..12; 01 and 06 intentionally absent) reports **zero
failures**. The only remaining output is LINT-05's warn-only portability hints,
which are intentional macOS-only code paths. This document inventories those
hints and their remediation. Nothing here blocks `task lint` (it exits 0 by
design); "perfectly clean" means zero warnings as well. The LINT-02..12 rule
catalogue lives in `../CLAUDE.md`; the rule bodies live in `taskfiles/lint.yml`.

## LINT-05 portability hints (warn-only, 5 patterns / 10 lines)

These are deliberate macOS-only commands. LINT-05 is a forward signal that
flags platform-specific calls; on a macOS-only repo, accepting these
warnings is the documented default (`os/README.md` §expected LINT-05
warnings).

| Location | Command | Platform-guard remediation |
|----------|---------|--------------------------------------|
| `shell/functions/pubkey.zsh:23` | `pbcopy` | Dispatch on `$OSTYPE`: `pbcopy` (darwin) vs `xclip -selection clipboard` / `wl-copy` (linux). |
| `os/defaults/appearance.zsh:45` | `osascript` | Whole file is a macOS defaults concern; gate the file at the taskfile layer (only run `os/defaults/*` on darwin) rather than per-line. |
| `os/defaults/_apply_verify.zsh:41,67` | `defaults write` / `defaults read` | Same as above -- the apply/verify engine is inherently `defaults`-based; platform-gate the caller. |
| `shell/aliases/finder.zsh:23,28` | `defaults write` | Finder-specific aliases; wrap the alias definitions in a darwin guard via `_dotfiles_feature` or `$OSTYPE` check. |
| `os/shell-registration.zsh:39,56` | `dscl` | macOS directory services; Linux equivalent is `chsh`/`getent`. Platform-gate the script. |

To silence them (not recommended -- the warnings are a useful inventory of
platform-specific calls): the rule is warn-only and exits 0, so the only
"fix" is the real platform guard above. There is deliberately no
`lint-allow` escape for LINT-05.

Self-test: `task test` runs `lint:test-fixtures` (33 fixtures, positive and
negative cases per rule). Any change to a rule body in `taskfiles/lint.yml`
must keep the mirrored fixture-branch logic in `lint:test-fixtures` aligned
and should add a fixture pinning the new behavior.
