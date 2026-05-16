---
created: 2026-05-15
discovered_in_phase: 06
resolves_phase: 08
owner: ""
severity: low
category: bug
---

# task manifest:resolve does not invalidate on active-machine change

## Problem

`task manifest:resolve` uses an mtime-based `status:` block to cache the output `resolved.json`. When the user runs `task manifest:setup -- <other-machine>` to change the active machine, the machine-selection file at `$XDG_STATE_HOME/dotfiles/machine` is rewritten, but the existing `resolved.json` (generated for the previous active machine) is older than the source TOML files in `manifests/` so the status block thinks it's fresh and skips regeneration.

Result: `cat $XDG_STATE_HOME/dotfiles/machine` correctly shows the new machine name, but `resolved.json` still reflects the *previous* machine's resolved features and packages. Every taskfile that reads `{{.MANIFEST}}` via `ref: 'fromJson .MANIFEST_JSON'` sees the stale data.

## Discovered

Phase 6 UAT Test 2 (`.planning/phases/06-os-defaults-macos-configuration/06-HUMAN-UAT.md`). Phase 6 server-mode contract was provable only by bypassing the cache with `zsh install/resolver.zsh --machine server-1 --stdout`. Documented in `06-01-SUMMARY.md` deviation note.

## Reproduction

```bash
CURRENT=$(cat "$XDG_STATE_HOME/dotfiles/machine")

task manifest:setup -- server-1
task manifest:resolve

# active machine is now server-1 -- confirmed:
cat "$XDG_STATE_HOME/dotfiles/machine"   # server-1

# but resolved.json is STILL the previous machine's resolved state:
jq -r '.identity.git' "$XDG_STATE_HOME/dotfiles/resolved.json"
# expected: server-1
# actual:   personal-laptop (or whatever was active before)

# rollback
task manifest:setup -- "$CURRENT"
task manifest:resolve
```

## Fix Strategy (Phase 8 candidate)

Options, in order of preference:

1. **Add the active-machine file to the status:'s mtime input list.** Whichever file lists the resolver currently checks should also include `$XDG_STATE_HOME/dotfiles/machine` so a rewrite invalidates the cache.
2. **Add active-machine identity to a sentinel-file check.** The status block computes the expected machine identity from `$XDG_STATE_HOME/dotfiles/machine` and compares it to the resolved-machine identity in `resolved.json`; mismatch -> regenerate.
3. **Remove the status block entirely.** Resolver is fast enough (~100ms); the cache buys little and risks correctness.

Option 1 is the smallest fix; option 2 is the most correct; option 3 is the safest. Pick one during Phase 8 cleanup.

## Acceptance criteria

After `task manifest:setup -- <other-machine>` runs, the next `task manifest:resolve` MUST regenerate `resolved.json` and the resolved identity / features / packages MUST match the new active machine's expected resolved state (verifiable by comparing against `zsh install/resolver.zsh --machine <other-machine> --stdout`).

## Workaround until fixed

Use `zsh install/resolver.zsh --machine <name> --stdout` for ad-hoc cross-machine resolution checks; this bypasses the task-level cache.
