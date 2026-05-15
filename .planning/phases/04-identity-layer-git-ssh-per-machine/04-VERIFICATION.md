---
phase: 04-identity-layer-git-ssh-per-machine
phase_number: "04"
status: human_needed
verified_at: "2026-05-15T16:00:00Z"
requirements_total: 8
requirements_passed: 7
requirements_human_needed: 1
requirements_failed: 0
plan_count: 7
summary_count: 7
re_verification:
  previous_status: human_needed
  previous_score: 7/8
  gaps_closed:
    - "UAT gap 1: manifest namespace double-prefix (task manifest:resolve etc. emit 'Task X does not exist') -- fixed by plan 04-05 (commit d94168e)"
    - "UAT gap 2: resolver warn-fallback emits bare-slash /resolved.json warning -- fixed by plan 04-06 (commit 36925a0)"
    - "UAT gap 3: cascading identity:install dep-resolution failure -- fixed by plan 04-05 (commit d94168e)"
    - "UAT gap 4: validate:git probes parent directory instead of a real repo -- fixed by plan 04-07 (commit f6b6c94)"
  gaps_remaining:
    - "IDNT-07 personal/work branch: email assertion requires a converged personal-laptop or work-laptop to exercise (code is correct; server-2 skip-path verified live)"
  regressions: []
human_verification:
  - test: "Run 'task identity:validate' on a converged personal-laptop (machine manifest identity.git = personal)"
    expected: "All five checks pass including 'git user.email matches identity (josh@vaughen.net)'; exit 0"
    why_human: "The active machine is server-2; running git config user.email inside ~/git/personal/* returns the server-2 email because the active git config is the server-2 overlay. The [includeIf gitdir/i:~/git/personal/] block in identity/git/config only fires when the git config symlink points to the personal identity (personal-laptop). Cannot exercise from server-2."
  - test: "Run 'task identity:validate' on a converged work-laptop (machine manifest identity.git = work)"
    expected: "All five checks pass including 'git user.email matches identity (work email)'; exit 0"
    why_human: "Same structural reason as above -- requires an active work-laptop machine."
---

# Phase 04 Verification: Identity Layer (Git + SSH Per Machine) — Re-verification

Phase 04 delivers the manifest-driven per-machine git + SSH identity layer (IDNT-01..IDNT-08). All seven plans have SUMMARY.md. Wave 1 (04-05) and Wave 2 (04-06, 04-07) gap-closure plans closed all four UAT-diagnosed gaps. Seven of eight requirements are statically verified in the codebase; IDNT-07 remains `human_needed` for the personal/work branch because the email assertion requires exercising the [includeIf] block from inside a personal-laptop identity, which cannot be done from the current server-2 machine.

## Requirements Traceability

| ID | Description | Status | Evidence |
|----|-------------|--------|----------|
| IDNT-01 | Git identity tree: one shared config + flat per-identity overlays | PASS | `identity/git/config` exists; `identity/git/identities/` lists exactly five files: none, personal, server-1, server-2, work. `[includeIf "gitdir/i:~/git/personal/"]` and `[includeIf "gitdir/i:~/git/work/"]` blocks present plus universal `[include] path = server-include.config` hook (D-08). |
| IDNT-02 | SSH identity tree: one shared config + flat per-identity overlays | PASS | `identity/ssh/config` exists with single `Include ~/.ssh/identities/active` directive (no `Match exec`). `identity/ssh/identities/` lists exactly five files: none, personal, server-1, server-2, work. `identity/ssh/cloudflared.zsh` carries `set -euo pipefail` and uses `$HOMEBREW_PREFIX`. |
| IDNT-03 | Per-machine identity values declared in machine TOMLs | PASS | `personal-laptop.toml` -> identity.git/ssh = "personal"; `work-laptop.toml` -> identity.git/ssh = "work"; `server-1.toml` -> "server-1"; `server-2.toml` -> "server-2". All four machines validate clean via `resolver.zsh --validate-only`. |
| IDNT-04 | One-Password split feature flags | PASS | `features.one-password-ssh` (existing) + `features.one-password-signing` (new, default false in defaults.toml) split per D-15. Both laptops carry `one-password-signing = true`; servers leave it false. |
| IDNT-05 | Resolver enforces the five-value enum + cross-field rules | PASS | `install/resolver.zsh validate_manifest()` lists `personal\|work\|server-1\|server-2\|none` and rejects unknown values. Cross-field rules: `identity.ssh in {personal,work}` requires `features.one-password-ssh = true`; `identity.git in {personal,work}` requires `features.one-password-signing = true`. Five new negative fixtures + two pre-existing all trigger the right stderr fragments; `task manifest:test` reports `11 total, 11 passed, 0 failed` (live-verified 2026-05-15). |
| IDNT-06 | Private keys never enter the repo (allowlist) | PASS | `identity/ssh/keys/.gitignore` contains `*\n!*.pub\n!.gitignore`. Only `personal.pub`, `server-1.pub`, `server-2.pub` (and the `.gitignore` itself) are tracked. |
| IDNT-07 | `task identity:validate` exits 0 on a converged machine | HUMAN_NEEDED | Code is verified correct and live `task identity:validate` exits 0 on server-2 (skip path: `$HOME` is not a git work tree -> info message -> exit 0). Commits: d94168e (task:install cascade fix), f6b6c94 (validate:git find+rev-parse rewrite). The personal-laptop email assertion -- where the `[includeIf gitdir/i:~/git/personal/]` block must fire and return `josh@vaughen.net` -- requires exercising from a machine with `identity.git=personal` active. Confirmed probe repo exists at `~/git/personal/professional/.git`. |
| IDNT-08 | Install pipeline is manifest-driven (no hostname inference) | PASS | `taskfiles/identity.yml:111` uses `deps: [":manifest:resolve"]` (leading-colon absolute form, commit d94168e). `task identity:install` exits 0 live (verified 2026-05-15). `task --list` shows zero `manifest:manifest:*` double-prefixed entries. `task manifest:resolve` runs without bare-slash warning (commit 36925a0). No hostname-literal in identity/ or taskfiles/identity.yml. |

## Plan Coverage

| Plan | SUMMARY | Status | Requirements Touched |
|------|---------|--------|----------------------|
| 04-01 | 04-01-SUMMARY.md | PASS | IDNT-05 |
| 04-02 | 04-02-SUMMARY.md | PASS | IDNT-01, IDNT-02, IDNT-03, IDNT-04, IDNT-06 |
| 04-03 | 04-03-SUMMARY.md | PASS | IDNT-05 (regression coverage for validator failure modes) |
| 04-04 | 04-04-SUMMARY.md | PASS | IDNT-07, IDNT-08 |
| 04-05 | 04-05-SUMMARY.md | PASS | IDNT-07 (cascade unblock), IDNT-08 (manifest namespace fix) |
| 04-06 | 04-06-SUMMARY.md | PASS | IDNT-08 (bare-slash warning fix) |
| 04-07 | 04-07-SUMMARY.md | PASS | IDNT-07 (validate:git probe-repo rewrite) |

All seven PLAN.md requirement IDs are accounted for; no orphan requirements remain.

## Gap-Closure Evidence (Wave 1 + Wave 2)

### UAT Gap 1 + Gap 3 (manifest namespace + cascade) -- CLOSED

Plan 04-05 (commit d94168e) renamed five public task keys in `taskfiles/manifest.yml` from `manifest:foo` to bare `foo`, removing the double-prefix produced by the include alias. Fixed `taskfiles/identity.yml:111` from `manifest:manifest:resolve` to `":manifest:resolve"` (leading-colon quoted for YAML validity). Updated `Taskfile.yml:126` from `manifest:manifest:resolve` to `manifest:resolve` and removed the deferred-fix comment block.

Live check 2026-05-15:
- `task --list | grep manifest:manifest:` -> 0 lines (zero double-prefix entries)
- `task manifest:resolve`, `task manifest:show`, `task manifest:validate`, `task manifest:test` all exit 0
- `task identity:install` exits 0

### UAT Gap 2 (bare-slash /resolved.json warning) -- CLOSED

Plan 04-06 (commit 36925a0) changed `taskfiles/manifest.yml:53` from `'{{.STATE_DIR}}/resolved.json'` (two-hop chain, collapses to `/resolved.json` under include-vars eval) to `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'` (one-hop, matching the working pattern in identity.yml). `STATE_DIR` retained for `cmds:` blocks.

Live check 2026-05-15:
- `task identity:git --force 2>&1 | grep -F 'warning: /resolved.json'` -> no output (warning gone)
- `task manifest:resolve 2>&1 | grep -F 'warning:'` -> no output

### UAT Gap 4 (validate:git empty user.email) -- CODE FIXED; PERSONAL BRANCH HUMAN_NEEDED

Plan 04-07 (commit f6b6c94) rewrote the `validate:git` workstation branches to use `find "$root" -maxdepth 2 -name .git -type d -print -quit` to locate a real probe repo and `git -C "$probe_dir" rev-parse --is-inside-work-tree` as the work-tree guard. Replaced the broken `gitdir="$HOME/git/personal"` parent-directory probe.

Live check 2026-05-15 (active machine: server-2):
- `task identity:validate` exits 0; server branch: `$HOME` not a git work tree, skips cleanly with info message
- Probe repo confirmed: `/Users/josh/git/personal/professional/.git` exists for future personal-laptop exercise
- Running `git -C /Users/josh/git/personal/professional config user.email` returns `server-2@jgrid.net` (server overlay active -- correct behavior while identity=server-2)

## Live Codebase Spot-Checks

- `task --list` -> zero `manifest:manifest:*` entries
- `task manifest:test` -> `fixtures: 11 total, 11 passed, 0 failed`
- `task identity:install` -> exit 0
- `task identity:validate` -> exit 0 (server-2 skip path)
- `task manifest:resolve` -> exit 0, no bare-slash warning
- `task identity:git --force` -> exit 0, no bare-slash warning
- `grep -c "manifest:manifest:" taskfiles/manifest.yml taskfiles/identity.yml Taskfile.yml` -> 0 in all three files

## Outstanding Gates

- **IDNT-07 personal/work branch** -- `task identity:validate` with `identity.git=personal` (email assertion must pass via `[includeIf]`). Code is correct. Exercise on a converged personal-laptop or work-laptop.
- **`/gsd-code-review 04`** -- code-review subagent gate was skipped for the original wave. Plans 04-05..04-07 changes are small and mechanical (rename, one-line, targeted rewrite); recommend running before merge.
- **`/gsd-secure-phase 04`** -- no SECURITY.md exists yet. Plans 04-05..04-07 introduce no new network paths, auth surfaces, or privilege escalation. Low threat surface but gate should run before phase advance.

## Verification Status: human_needed

Phase 04 has delivered every requirement that can be verified statically and on the current server-2 machine. All four UAT gaps are closed in code. IDNT-07's personal/work branch requires a converged personal-laptop or work-laptop for final exercise.

## Next-Step Routing

```
/gsd-code-review 04        # advisory; never blocks
/gsd-secure-phase 04       # threat model + SECURITY.md
task identity:validate     # on a converged personal-laptop -- must exit 0 to complete IDNT-07
```

Once `task identity:validate` exits 0 on a personal-laptop (showing `git user.email matches identity (josh@vaughen.net)`), update this VERIFICATION.md status to `passed` and advance to Phase 05.
