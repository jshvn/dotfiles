# Audit Drift Remediation Hints — Design

**Date:** 2026-07-19
**Status:** Approved (Approach A — per-domain hint lines)

## Problem

When `task audit` (or a direct `task <domain>:audit`) detects drift, two of the
five audit domains report the drift but do not tell the operator how to remove
it. The operator has to already know the remediation command.

Current state per domain:

| Domain | On drift today | Auto-fix command |
|--------|----------------|------------------|
| `manifest:audit` | resolver schema errors (self-describing) | none — manual TOML edit |
| `packages:audit` | `N drift item(s) detected`, no hint | none yet (`packages:prune` planned, not built) |
| `links:audit` | orphan list, exit 1, no hint | `task links:audit -- --remove` (exists) |
| `claude:audit` | prints `run 'task claude:settings-compose' to fix` | exists |
| `claude-addons:audit` | prints `run 'task claude-addons:remove -- <name>'` | exists |

The gap is `packages:audit` and `links:audit`.

## Design

Add a remediation line inside each gap domain's audit task at the point drift
is reported, matching the pattern `claude:audit` and `claude-addons:audit`
already use. Because the hints live in the domain tasks, they appear
identically under bare `task audit` and direct `task <domain>:audit` runs. No
changes to the root aggregate.

### 1. `taskfiles/links.yml` — `audit` task

In the `detect` and `warn` mode branches, after the orphan warn loop and
before the `exit`, add one line via the existing messages helper:

```
info "run 'task links:audit -- --remove' for interactive cleanup"
```

The `remove` branch needs nothing (the operator is already in cleanup).

### 2. `taskfiles/packages.yml` — `audit` task

In the non-zero-drift path, before both exits (`--strict` exit 1 and the
non-blocking exit 0), add one line:

```
info "to fix: declare in manifests/bundles/*.toml (or the machine manifest) if wanted, or uninstall if not"
```

When the planned `packages:prune` task lands (see
`docs/superpowers/plans/2026-07-18-packages-prune.md`), this hint switches to
reference `task packages:prune`. That switch is part of the prune plan's
scope, not this change.

### 3. Out of scope

- `manifest:audit` — resolver errors are already self-describing and there is
  no automatic fix; no hint added.
- `claude:audit`, `claude-addons:audit` — already print remediation hints;
  unchanged.
- Aggregate-level summary footer in the root `audit:` task — rejected
  (Approach B): `ignore_error: true` dispatch does not expose exit codes, a
  footer would duplicate domain knowledge in the root Taskfile, and hints
  would be missing on direct domain-audit runs.
- Implementing `packages:prune` — separate plan, separate branch.

## Constraints

- Output via `messages.zsh` helpers (`info`); no emojis; errors to stderr
  (hints are informational, so `info` to stdout is correct).
- Editing existing `cmds:` bodies only — no new tasks, no new lint
  exemptions.
- Hint lines print only when drift exists (they sit inside the
  drift-detected branches).

## Verification

- Run `task links:audit` and `task packages:audit` on a machine with drift
  (or temporarily induce drift) and confirm the hint line appears; confirm it
  does not appear on a clean run.
- `task test` — the links-audit smoke tests
  (`install/test-links-audit.zsh`) assert scanner output, not task output, so
  they must still pass unchanged.
- `task lint` — exit 0.
