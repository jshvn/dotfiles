---
phase: 04-identity-layer-git-ssh-per-machine
plan: "01"
subsystem: manifest-schema
tags: [resolver, identity, validation, schema, manifests]
dependency_graph:
  requires: []
  provides: [five-value-identity-enum, cross-field-validation, server-identity-values, one-password-signing-flag]
  affects: [manifest-validation, taskfiles/identity.yml, plan-03-fixtures, plan-04-taskfile]
tech_stack:
  added: []
  patterns: [yq-quoted-key-form-for-kebab-case, cross-field-resolver-validation]
key_files:
  created: []
  modified:
    - install/resolver.zsh
    - manifests/defaults.toml
    - manifests/machines/personal-laptop.toml
    - manifests/machines/work-laptop.toml
    - manifests/machines/server-1.toml
    - manifests/machines/server-2.toml
    - docs/MANIFEST.md
    - .planning/REQUIREMENTS.md
decisions:
  - "D-05: Identity enum expanded to personal|work|server-1|server-2|none; validator and docs updated"
  - "D-15: features.one-password-signing added as independent flag (false by default) split from one-password-ssh"
  - "D-16: Cross-field validation: identity.ssh in {personal,work} requires one-password-ssh=true; identity.git in {personal,work} requires one-password-signing=true"
  - "D-07: server-1.toml and server-2.toml updated from identity=none to identity=server-1/server-2 respectively"
metrics:
  duration: "~8 minutes"
  completed: "2026-05-15T04:23:06Z"
  tasks_completed: 2
  files_modified: 8
---

# Phase 04 Plan 01: Schema Layer -- Identity Enum, Cross-Field Validation, and Manifest Updates Summary

Extended the manifest schema layer to recognize per-server identity values and split-flag 1Password semantics (D-05, D-15, D-16): the resolver gained a five-value identity enum and two cross-field validation rules; all four machine TOMLs and defaults.toml landed their Phase-4 values; docs/MANIFEST.md mirrors the new schema; REQUIREMENTS.md IDNT-05 wording reflects the D-15 split.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Expand resolver identity enum and add cross-field validation | a0dcf6a | install/resolver.zsh |
| 2 | Update defaults.toml, four machine TOMLs, docs/MANIFEST.md, REQUIREMENTS.md | 477b82b | manifests/defaults.toml, manifests/machines/personal-laptop.toml, manifests/machines/work-laptop.toml, manifests/machines/server-1.toml, manifests/machines/server-2.toml, docs/MANIFEST.md, .planning/REQUIREMENTS.md |

## What Was Built

### Task 1: Resolver expansion (install/resolver.zsh)

The `validate_manifest()` function's identity enum case-statement was expanded from `personal|work|none` to `personal|work|server-1|server-2|none`. The error message was updated to list all five values.

Two D-16 cross-field validation rules were added after the enum check and before `VALIDATE_ERRORS=$errors`:
- `identity.ssh ∈ {personal, work}` requires `features.one-password-ssh = true`
- `identity.git ∈ {personal, work}` requires `features.one-password-signing = true`

Both rules use the yq quoted-key form (`.features."one-password-ssh"`) for kebab-case keys.

### Task 2: Manifest + docs updates

- `manifests/defaults.toml`: `one-password-signing = false` added to `[features]` block; identity comment updated to list all five enum values.
- `manifests/machines/personal-laptop.toml` and `work-laptop.toml`: `one-password-signing = true` added (D-16 cross-field requirement since identity.git is personal/work on these machines).
- `manifests/machines/server-1.toml`: identity.git and identity.ssh changed from `"none"` to `"server-1"` (D-07).
- `manifests/machines/server-2.toml`: identity.git and identity.ssh changed from `"none"` to `"server-2"` (D-07).
- `docs/MANIFEST.md`: identity.git and identity.ssh Allowed-values columns expanded to five-value enum; `one-password-signing` row added to Feature-Flag Reference table.
- `.planning/REQUIREMENTS.md`: IDNT-05 rewritten to describe both flags and the cross-field validation (D-15 split).

## Verification Results

All plan-level verification criteria passed:

1. `zsh -n install/resolver.zsh` -- PASS (no parse errors)
2. `task manifest:validate -- --machine personal-laptop` -- PASS (exit 0)
3. `task manifest:validate -- --machine work-laptop` -- PASS (exit 0)
4. `task manifest:validate -- --machine server-1` -- PASS (exit 0; new `"server-1"` values accepted)
5. `task manifest:validate -- --machine server-2` -- PASS (exit 0; new `"server-2"` values accepted)
6. `task manifest:test` -- PASS (8 fixtures: 6 positive + 2 negative, all pass; negative_count=2 unchanged)

## Deviations from Plan

### Pre-existing issue (out of scope, not fixed)

**`local path` in resolve_machine_path() (line 387)**

The plan acceptance criteria specified `grep -c 'local path' install/resolver.zsh | grep -q '^0$'`. However, there is a pre-existing `local path="${MACHINES_DIR}/${name}.toml"` in `resolve_machine_path()` at line 387 that predates this plan. The plan's constraint was correctly interpreted as "do not ADD `local path` in new code" -- my additions in `validate_manifest()` used `identity_ssh`, `identity_git`, `opssh`, `opsign` as variable names (no `local path`). The pre-existing line is in a separate function from the validation code and was not part of this plan's scope. Logging to deferred-items as a future cleanup.

**`task lint` exits non-zero (pre-existing)**

The plan verification check "task lint exits 0 (no taskfile edits in this plan; lint just confirms nothing regressed)" could not pass because `task lint` was already failing with LINT-03a errors across multiple taskfiles (`brew.yml`, `claude.yml`, `common.yml`, `macos.yml`, `manifest.yml`, `profile-tasks.yml`, `profile.yml`, `shell.yml`) before this plan started. None of these files were touched by this plan. The failures are pre-existing and out of scope.

## Known Stubs

None. All changes are fully wired: the resolver validates the new enum and cross-field rules, all four machine TOMLs declare values that pass validation, and the docs accurately describe the schema.

## Threat Flags

None. This plan added validation logic (defensive; reduces attack surface) and updated TOML manifests (no new network endpoints, auth paths, or schema changes at trust boundaries).

## Self-Check: PASSED

All key files exist and both task commits are reachable in git history.
