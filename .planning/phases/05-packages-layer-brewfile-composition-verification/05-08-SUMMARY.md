---
phase: 05-packages-layer-brewfile-composition-verification
plan: "08"
subsystem: packages
tags: [packages, verify, brew-info, gap-closure, diagnosability, silent]
dependency_graph:
  requires: [05-07-SUMMARY.md]
  provides: [brew-info-verify-task, gap-2-closure, gap-3-closure]
  affects: [taskfiles/packages.yml]
tech_stack:
  added: []
  patterns: [brew-info-two-layer-verify, enumerate-all-hard-fail, task-level-silent-override]
key_files:
  created: []
  modified:
    - taskfiles/packages.yml
decisions:
  - "Gap-2 closure: drop per-line # verify: dispatch; replace with brew info --installed --json=v2 artifact-path probe"
  - "Gap-3 closure: add silent: false task-level override to packages:verify (root global silent:true unchanged)"
  - "Always-fresh design: no brew-artifacts.json cache file; v2 PERF-V2 deferred"
  - "D-04 superseded: cask verify is now data-driven from brew info artifacts[], not per-line comment"
  - "D-05 preserved as defense-in-depth: # verify: <bin> formula override pathway retained for future use"
metrics:
  duration: "~30 minutes"
  completed: "2026-05-16"
  tasks: 1
  files: 1
---

# Phase 5 Plan 8: Verify-pivot task rewrite Summary

Rewrote the `verify` task in `taskfiles/packages.yml` to the brew-info-driven two-layer model
decided during Phase 5 UAT (Gap 2 closure, 2026-05-15). Dropped the per-line `# verify:`
comment dispatch introduced in Plan 05-04. Added `silent: false` task-level override to close
Gap 3 (verify output invisible in non-TTY contexts).

## Tasks Completed

| Task | Commit | Files |
|------|--------|-------|
| 1: Rewrite packages:verify to brew-info two-layer model + silent:false | e46b053 | taskfiles/packages.yml |

## Architecture: New Two-Layer Verify Model

### Layer 1 (install-state gate)
`brew bundle check --no-upgrade --file={{.COMPOSED_BREWFILE}}`

Reuses the EXACT same command as the `packages:install` task's status block (D-09). If the
install-state gate fails, the failure is recorded and Layer 2 continues (enumerate-all, D-07).
No first-failure short-circuit.

### Layer 2 (artifact-state gate)
Single bulk `brew info --installed --json=v2` call (~200ms on local metadata). JSON output
captured to `$brew_info_json`. Hard-fail if the call produces no parseable JSON.

**Cask path:** For each `cask '<name>'` line in the composed Brewfile:
- Look up `.casks[] | select(.token == $name)` in the bulk JSON
- Walk `.artifacts[]` for `.app` entries -> assert `/Applications/<target>` exists (test -d)
- Walk `.artifacts[]` for `.binary` entries -> assert `command -v <basename>` resolves
- Skip `.pkg`, `.manpage`, `.uninstall`, `.zap`, and other informational artifact kinds
- Empty or non-checkable artifacts -> pass (Layer 1 confirmed install)

**Formula path:** For each `brew '<name>'` line in the composed Brewfile:
- Look up `.formulae[] | select(.name == $name)` in the bulk JSON
- Assert `.installed[0].linked_keg` is non-null (formula built and linked)
- D-05 escape hatch preserved: if the bundle line carries `# verify: <bin>`, also run
  `command -v <bin>` as defense-in-depth (no bundle lines carry overrides post-Gap-2 pivot)

**MAS path (D-06):** `mas list | awk '{print $1}'` for installed ids + `/Applications/<name>.app`
probe. Skips gracefully if `mas` not on PATH (warn + continue).

### Why brew-info Fixes the Gap 2 Issues Mechanically

The brew-info model uses Homebrew's own artifact records (`brew info --installed --json=v2`)
which always reflect the actual installed app bundle name, not the hand-typed verify annotation.
The 7 verify-comment correctness issues from Gap 2 are resolved because:

| Package | Old problem | How brew-info fixes it |
|---------|-------------|------------------------|
| `tlrc` (formula) | binary name mismatch | `.linked_keg` presence is the check; no bin name needed |
| `antidote` (formula) | zsh function, not PATH binary | `.linked_keg` presence confirms formula linkage; no `command -v` required |
| `miniconda` (cask) | no .app bundle; needed bin: verify | brew info `.artifacts[].binary[0]` returns the actual binary artifact |
| `nvidia-geforce-now` (cask) | app-name mismatch in verify comment | brew info `.artifacts[].app[0]` returns the actual installed bundle name |
| `protonvpn` (cask) | app-name mismatch in manifest | brew info `.artifacts[].app[0]` returns the actual installed bundle name |
| `Things` (mas) | installed as Things3.app, verify commented as Things | MAS layer uses the declared `name` which doubles as the app bundle (D-06 preserved) |
| `1password-cli` (cask) | binary-only cask; needed bin: prefix | brew info `.artifacts[].binary[0]` = `op`; command -v check handles it automatically |

## Gap 3 Closure Mechanism

Added `silent: false` as a task-level key on `packages:verify`. Root `Taskfile.yml` declares
`silent: true` globally; this task-level override restores stdout/stderr visibility for the
verify task only. No change to root `Taskfile.yml`.

Verified through three invocation forms:
- TTY: `task packages:verify` -- check/cross enumeration visible
- Pipe: `task packages:verify | cat` -- full output visible (no buffering loss)
- Redirect: `task packages:verify >/tmp/v.log 2>&1; cat /tmp/v.log` -- full output captured

## Design Decision: Always-Fresh (No Cache)

Open design question from 05-UAT.md resolved: NO `$XDG_CACHE_HOME/dotfiles/brew-artifacts.json`
cache file. `brew info --installed --json=v2` is invoked fresh on every verify run.

Rationale: The `--installed` flag hits local Homebrew metadata only (no network); the call
completes in ~200ms on a converged machine. Caching introduces a stale-cache failure class
(verify passes for a removed package until the cache expires) with no offsetting latency gain
at v1 scale. Caching deferred to v2 PERF-V2 if measured latency becomes a problem.

## Verification Results

### Static checks
- `yq -r '.tasks.verify.silent' taskfiles/packages.yml` -> `false` (Gap 3 closure confirmed)
- `yq '.tasks.verify.preconditions | length' taskfiles/packages.yml` -> `4`
- `yq '.tasks.verify.cmds | length' taskfiles/packages.yml` -> `1` (single inline shell block)
- `ggrep -c "brew info --installed --json=v2" <<< $(yq -r ...)` -> `1` (no per-package fan-out)
- `task -t taskfiles/packages.yml --list` -> exits 0 (all 5 tasks discoverable)
- `task manifest:test` -> 11/11 fixtures pass (no manifest-path change)
- LINT-02: `taskfiles/packages.yml` passes (no `$VAR` in status blocks)
- LINT-03a: verify + audit + validate carry `# lint-allow: cmds-without-status` markers
- No emojis; no AI attribution

### End-to-end smokes (to be run by user after merge)
Tests 2 and 3 from 05-HUMAN-UAT.md are now unblocked by the gap closures in plans 05-07 + 05-08:

**Test 2 (VRFY-03 negative-path smoke):** Renaming `/Applications/Slack.app` will surface a
`cross "cask slack -> /Applications/Slack.app NOT FOUND"` row. The brew-info model returns
`Slack.app` as the actual artifact (`.artifacts[].app[0]`) rather than relying on a hand-typed
verify comment.

**Test 3 (End-to-end task install smoke):** `task install` runs through
`links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify`
and should exit 0 with the success banner on a fully-installed personal-laptop.

## Decision References

- **D-04 (cask verify MANDATORY) -- SUPERSEDED** by Gap-2 closure 2026-05-15 (Plan 05-07 +
  Plan 05-08). Per-line `# verify:` annotations no longer authored; cask artifact probes are
  data-driven from `brew info --installed --json=v2 .casks[].artifacts[]`.

- **D-05 (formula verify via # verify: comment) -- PRESERVED as defense-in-depth** in the
  formula loop. The parsing pathway remains so future bundle lines with `# verify: <bin>`
  overrides will trigger a `command -v <bin>` check. No current bundle lines carry overrides
  post-Gap-2 pivot, but the path is preserved for schema defense.

- **D-06 (MAS name doubles as verify target) -- PRESERVED** unchanged. The MAS layer uses
  `mas list | awk '{print $1}'` for installed-ids and `/Applications/<name>.app` for artifact
  presence. Apple App Store has no `brew info` equivalent; per-entry name is still the only
  verify handle available.

- **D-07 (enumerate-all) -- PRESERVED**. Every declared package (formula, cask, MAS) gets a
  check or cross row before the summary. No first-failure short-circuit.

- **D-09 (install task status block) -- UNCHANGED**. The install task's two-condition status
  block (`test -f` + `brew bundle check`) was not touched. Layer 1 of the verify task reuses
  the exact same `brew bundle check --no-upgrade --file=...` invocation for semantics parity.

- **D-10 (hard-fail) -- PRESERVED**. Verify exits non-zero with the failure count on any miss.
  No escape hatch. `task install` fails at the verify step if any artifact is missing.

- **VRFY-01 (formula bin/linked_keg checks) -- IMPLEMENTED** under the post-pivot model via
  `.installed[0].linked_keg` probe in the formula loop.

- **VRFY-02 (cask/mas .app + binary checks) -- IMPLEMENTED** under the post-pivot model via
  `brew info .artifacts[]` walk (casks) and `/Applications/<name>.app` probe (MAS).

- **VRFY-03 (negative-path smoke) -- UNBLOCKED** by this plan. Test 2 in 05-HUMAN-UAT.md can
  now be run and is expected to pass.

- **VRFY-04 (task install ends with packages:verify) -- PRESERVED**. Root `Taskfile.yml` was
  not touched; `task install` already chains to `packages:verify` as the final step.

## Deviations from Plan

None. Plan executed exactly as written. The only minor adjustment was restructuring the comment
block above the `verify:` key so the `# lint-allow: cmds-without-status` marker appears
immediately above `verify:` (matching the pattern used by audit: and validate:) rather than
buried within a larger comment block.

## Known Stubs

None. The brew-info two-layer model is fully wired. No placeholder data or hardcoded values.

## Self-Check: PASSED

Files verified present:
- taskfiles/packages.yml: FOUND (modified)

Commits verified present:
- e46b053: FOUND (feat(05-08): rewrite packages:verify to brew-info two-layer model)
