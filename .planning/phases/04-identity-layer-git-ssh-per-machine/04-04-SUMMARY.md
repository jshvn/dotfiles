---
phase: 04-identity-layer-git-ssh-per-machine
plan: "04"
subsystem: identity-install-wiring
tags: [taskfile, identity, install, links-aggregator, docs-02]
dependency_graph:
  requires:
    [
      five-value-identity-enum,
      cross-field-validation,
      git-identities-flat-tree,
      ssh-identities-flat-tree,
    ]
  provides: [identity-install-taskfile, identity-validate-task, links-all-extended-p4, identity-readme]
  affects: []
tech_stack:
  added: []
  patterns:
    [
      "manifest-driven-symlink-install",
      "server-include-materialization",
      "ssh-active-symlink-swap",
      "validate-as-internal-delegation",
    ]
key_files:
  created:
    - taskfiles/identity.yml
  modified:
    - Taskfile.yml
    - taskfiles/links.yml
    - identity/README.md
decisions:
  - "D-08: server-include.config materialized at install time only on server machines"
  - "D-10: SSH config carries a single `Include ~/.ssh/identities/active` directive (no Match exec)"
  - "D-12: active SSH identity selected via symlink swap, not file edit"
  - "D-14: cloudflared wrapper deployed on every machine via _:safe-link"
metrics:
  duration: "~10 minutes (inline orchestrator execution after worktree-agent permission failure)"
  completed: "2026-05-15T05:05:00Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 04 Plan 04: Identity Install Wiring Summary

Built the manifest-driven `taskfiles/identity.yml` that composes every Phase-4 symlink, materializes `~/.config/git/server-include.config` on server machines, and ships `task identity:validate` with the four success-criteria assertions. Wired it into the install pipeline by adding `identity:` to the root `Taskfile.yml` includes block and appending `task: identity:install` to `taskfiles/links.yml`'s `all:` aggregator. Replaced the Phase 1 `identity/README.md` stub with the DOCS-02-shaped README.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create taskfiles/identity.yml with install/git/ssh/server-include/validate subtasks | 8e6a731 | taskfiles/identity.yml |
| 2 | Wire identity.yml into root Taskfile.yml + links.yml all:, replace identity/README.md stub | c8e4efb | Taskfile.yml, taskfiles/links.yml, identity/README.md |

## What Was Built

### Task 1: taskfiles/identity.yml

A 353-line manifest-driven taskfile with these public tasks:

- **`identity:install`** (aggregator, lint-allow marker, `deps: [manifest:manifest:resolve]`) -- composes `task: git` + `task: ssh`.
- **`identity:git`** -- seven `_:safe-link` calls for the `git/config`, `git/ignore`, and the five flat per-identity files; final cmd delegates to `server-include`. `status:` block lists seven `test -L "{{.GIT_CONFIG_DIR}}/..."` assertions.
- **`identity:server-include`** (`internal: true`) -- shell-case generator that, when `{{.MANIFEST.identity.git}}` is `server-1` or `server-2`, writes `~/.config/git/server-include.config` with `[includeIf "gitdir:~/"] path = identities/<id>`; otherwise removes any stale copy. Status uses `case "{{.MANIFEST.identity.git}}" in ...` (template var only — no shell `$identity` in status).
- **`identity:ssh`** -- 11 `_:safe-link` calls for ssh config, five identities, three pub keys, the cloudflared wrapper, plus the active-symlink swap (`SOURCE: "{{.SSH_IDENTITIES_DIR}}/{{.MANIFEST.identity.ssh}}" -> TARGET: ...active`). Status asserts every symlink plus `test "$(readlink ...)/active" = ...` for the active target.
- **`identity:validate`** (aggregator, lint-allow marker) -- delegates to four `internal: true` sub-tasks: `validate:symlinks`, `validate:git`, `validate:ssh-add`, `validate:keys`. Each sub-task carries the assertion logic per IDNT-07.

Key design choices:
- The `validate` task uses task-delegation rather than inline shell blocks so LINT-03a's "all cmds are task: delegations" exemption applies cleanly.
- `vars:` block mirrors `taskfiles/manifest.yml` exactly for the `MANIFEST_JSON` + `MANIFEST ref: fromJson` pattern with `WR-03` stderr-warn fallback.
- Status blocks use `{{.X}}` template vars only; shell vars appear only inside rendered cmds blocks (case statements that destructure `{{.MANIFEST.identity.git}}` into a local `$identity`).

### Task 2: Install pipeline wiring + README

- **`Taskfile.yml`**: extended `includes:` block with `identity:` mapped to `./taskfiles/identity.yml`, with explicit `DOTFILEDIR` / `XDG_STATE_HOME` / `DOTFILES_MESSAGES` forwarding (mirrors the `manifest:` block since `identity.yml` also reads `resolved.json`). Updated includes-comment table to add `#   - identity (P4, real)`.
- **`taskfiles/links.yml`**: extended `all:` aggregator with `- task: identity:install`; updated `desc:` from "P3: shell only" to "P3+P4: shell + identity"; updated file banner narrative to reflect P4 wiring.
- **`identity/README.md`**: replaced the 10-line Phase 1 stub with the DOCS-02-shaped 67-line README (H1 title, one-paragraph intro, `## Key files`, `## Adding a pattern`, `## References`, trailer `Satisfies DOCS-02 for identity/.`).

## Verification Results

| Check | Result |
|-------|--------|
| `zsh -n install/resolver.zsh` | PASS |
| `task manifest:test` | 11/11 PASS (no regression from Plan 03) |
| `task lint:taskfile` for `identity.yml` | LINT-02 + LINT-03a clean (only pre-existing v1 leftover taskfiles error) |
| `grep -c "ln -s" taskfiles/identity.yml` (real code refs) | 0 (LINT-03b clean; 2 mentions are file-header comments) |
| `task --list` shows `identity:install` | PASS |
| `task --list` shows `links:all` with P3+P4 desc | PASS |
| Hostname-literal audit (IDNT-05) in `identity/` | clean (the `--hostname %h` flag in cloudflared ProxyCommand is the cloudflared CLI argument, not hostname-based machine detection) |
| `Taskfile.yml` includes-comment table contains `#   - identity (P4, real)` | PASS |
| `identity/README.md` >= 40 lines with required sections + trailer | PASS (67 lines) |

## Deviations from Plan

### Inline orchestrator execution

The wave-2 worktree agent bailed within 10 seconds reporting it lacked Bash access. The worktree HEAD was found to be at an unrelated old commit (`a321531`) rather than the orchestrator's `a0e8918` base; the agent never executed its HEAD assertion. The orchestrator removed the broken worktree and executed Plan 04-04 inline against the main working tree.

### `validate` task refactored to task delegation

The plan's PATTERNS.md called for inline shell blocks in `validate`'s `cmds:` with a `# lint-allow: cmds-without-status` marker, but `lint.yml`'s LINT-03a check honors only "ALL cmds are `task:` delegations" — the marker comment is documentation-only. The orchestrator split the four assertion blocks into `internal: true` sub-tasks (`validate:symlinks`, `validate:git`, `validate:ssh-add`, `validate:keys`) and made `validate` a pure delegator. Semantics preserved; lint clean.

### Phase-end BLOCKING task gate deferred to manual run

Acceptance criterion: `task identity:validate` exits 0 on a real machine after `task install`. This is the IDNT-07 BLOCKING gate; it requires a live machine with `task setup -- <machine> && task install` already run (resolved.json materialized, symlinks created). The taskfile, sub-tasks, and assertion logic are in place and the validate sub-tasks each handle their absent-state-skip case (silent skip when gitdir absent, when one-password-ssh = false, or when the pub-key is a placeholder). Running the BLOCKING validation is part of the cutover acceptance work, not orchestrator-side verification.

## Known Stubs

None. The validate logic intentionally short-circuits on absent state (workstation gitdirs not yet created, placeholder pub keys) so the task is callable on a fresh machine without false negatives.

## Threat Flags

None. The taskfile reads resolved.json (project-local), writes symlinks (idempotent via `_:safe-link`), and on server machines writes a single static-content file `~/.config/git/server-include.config`. No network paths, no new trust boundaries, no privileged operations.

## Self-Check: PASSED

All four key files exist; both task commits are reachable in `git log`; lint and resolver parse pass; `task --list` shows `identity:install` and `identity:validate` in the root namespace.
