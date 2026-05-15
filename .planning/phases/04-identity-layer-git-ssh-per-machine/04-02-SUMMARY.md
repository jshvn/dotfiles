---
phase: 04-identity-layer-git-ssh-per-machine
plan: "02"
subsystem: identity-content
tags: [identity, git, ssh, content-layer, cloudflared, includeIf]
dependency_graph:
  requires: []
  provides:
    [
      git-identities-flat-tree,
      ssh-identities-flat-tree,
      server-include-hook,
      cloudflared-wrapper,
      ssh-keys-allowlist,
    ]
  affects: [plan-04-taskfile-symlinks, plan-04-server-include-materialization]
tech_stack:
  added: []
  patterns:
    [
      "gitdir/i-includeIf-pattern",
      "ssh-active-symlink-pattern",
      "homebrew-prefix-runtime-resolve",
      "pub-key-allowlist-gitignore",
    ]
key_files:
  created:
    - identity/git/config
    - identity/git/ignore
    - identity/git/identities/personal
    - identity/git/identities/work
    - identity/git/identities/server-1
    - identity/git/identities/server-2
    - identity/git/identities/none
    - identity/ssh/config
    - identity/ssh/identities/personal
    - identity/ssh/identities/work
    - identity/ssh/identities/server-1
    - identity/ssh/identities/server-2
    - identity/ssh/identities/none
    - identity/ssh/keys/personal.pub
    - identity/ssh/keys/server-1.pub
    - identity/ssh/keys/server-2.pub
    - identity/ssh/keys/.gitignore
    - identity/ssh/cloudflared.zsh
  modified: []
decisions:
  - "D-07: server identities materialized as flat per-identity files (no profile suffix)"
  - "D-08: server-include.config is a universal [include] hook -- absent on workstations is a silent no-op"
  - "D-13: SSH IdentityFile paths scoped under ~/.ssh/identities/keys/"
  - "D-14: cloudflared wrapper moved to ~/.ssh/identities/cloudflared.zsh"
  - "D-16: SSH config Include points to ~/.ssh/identities/active symlink (replaces v1 Match exec / profile-file-exec pattern)"
metrics:
  duration: "~12 minutes (resumed after orchestrator-side commit)"
  completed: "2026-05-15T04:30:00Z"
  tasks_completed: 2
  files_modified: 18
---

# Phase 04 Plan 02: Identity Content Layer (Git + SSH per Identity) Summary

Materialized the entire identity content layer: one shared `identity/git/config`, one shared `identity/ssh/config`, five flat per-identity files on each side, the personal public key, two server pub-key placeholders, the cloudflared ProxyCommand wrapper, and the `.gitignore` allowlist. Direct ports of v1 source files with the documented divergences (drop `[includeIf gitdir:~/git/server/]`, drop `Match exec` blocks, add `[include] path = server-include.config`, update SSH key paths to `~/.ssh/identities/keys/`, add per-server git emails and IdentityFile paths).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Git side: identity/git/config + ignore + five flat identity files | 6263102 | identity/git/config, identity/git/ignore, identity/git/identities/{personal,work,server-1,server-2,none} |
| 2 | SSH side: config + five flat identity files + keys + cloudflared wrapper | 63a08c4 | identity/ssh/config, identity/ssh/identities/{personal,work,server-1,server-2,none}, identity/ssh/keys/{personal,server-1,server-2}.pub, identity/ssh/keys/.gitignore, identity/ssh/cloudflared.zsh |

## What Was Built

### Task 1: Git identity tree

- `identity/git/config` -- main git config with two workstation `[includeIf "gitdir/i:..."]` blocks (personal, work) and a universal `[include] path = server-include.config` block that is absent on workstations (D-08 silent no-op pattern). No v1 server `[includeIf "gitdir/i:~/git/server/"]` block.
- `identity/git/identities/` -- five flat per-identity files (personal, work, server-1, server-2, none). Server identities carry per-server `[user] email` (`server-1@jgrid.net`, `server-2@jgrid.net`) and disable commit signing.
- `identity/git/ignore` -- global gitignore (excludesfile), ported from v1.

### Task 2: SSH identity tree

- `identity/ssh/config` -- main SSH config containing a single `Include ~/.ssh/identities/active` directive plus shared global directives (TERM SetEnv). No `Match exec` blocks (replaced by install-time identity resolution via the active symlink).
- `identity/ssh/identities/` -- five flat per-identity files. `personal` and `work` route through the 1Password agent (`IdentityAgent`); server identities use the local system ssh-agent with deploy keys `id_ed25519_server-{1,2}` (D-09 -- generated at cutover, never committed). All `IdentityFile` and `ProxyCommand` references use the new scoped paths under `~/.ssh/identities/keys/` (D-13) and `~/.ssh/identities/cloudflared.zsh` (D-14).
- `identity/ssh/keys/` -- contains the personal public key plus two server pub-key placeholders, and a `.gitignore` allowlist (`*` / `!*.pub` / `!.gitignore`) enforcing IDNT-06 (no private keys in the repo).
- `identity/ssh/cloudflared.zsh` -- ProxyCommand wrapper with `set -euo pipefail`; `exec`s `$HOMEBREW_PREFIX/bin/cloudflared "$@"`.

## Verification Results

All must_have truth checks pass in the worktree:

| Check | Result |
|-------|--------|
| identity/git/config contains both workstation `gitdir/i:` blocks | PASS (2 matches) |
| identity/git/config contains universal `[include] path = server-include.config` hook | PASS |
| identity/git/config does NOT contain v1 `[includeIf gitdir/i:~/git/server/]` | PASS (0 matches) |
| identity/git/identities/ has exactly five flat files | PASS |
| identity/ssh/config has exactly one `Include` directive | PASS |
| identity/ssh/config has NO `Match exec` blocks | PASS (0 matches) |
| identity/ssh/identities/ has exactly five flat files | PASS |
| identity/ssh/identities/personal references `~/.ssh/identities/keys/personal.pub` and `~/.ssh/identities/cloudflared.zsh` | PASS |
| identity/ssh/keys/ contains only `*.pub` files and `.gitignore` | PASS |
| identity/ssh/cloudflared.zsh uses `$HOMEBREW_PREFIX` and has `set -euo pipefail` | PASS |

## Deviations from Plan

### Mid-plan permission interruption

The subagent reported running out of Bash permission during Task 2 verification and exited before committing. The orchestrator inspected the worktree, confirmed the 11 SSH-side files matched the plan's must_haves, staged them, and committed Task 2 (`63a08c4`) on behalf of the agent. Task 1 (git side) had already committed cleanly (`6263102`) during the agent's run.

## Known Stubs

- `identity/ssh/keys/server-1.pub` and `identity/ssh/keys/server-2.pub` are placeholder public keys -- the real server deploy keys are generated locally on each server at cutover (D-09) and the workstation copies are updated at that point.

## Threat Flags

- `identity/ssh/cloudflared.zsh` invokes a Homebrew-installed binary at `$HOMEBREW_PREFIX/bin/cloudflared`. The script must run in an environment where `HOMEBREW_PREFIX` is set; SSH invokes ProxyCommand via the user's login shell on personal/plex hosts where the shell init sets `HOMEBREW_PREFIX` via `brew shellenv`. The runtime expectation is documented inline in the wrapper.

## Self-Check: PASSED

All 18 key files exist on disk in the worktree; both task commits are reachable in `git log`.
