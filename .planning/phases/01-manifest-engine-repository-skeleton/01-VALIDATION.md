---
phase: 1
slug: manifest-engine-repository-skeleton
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-13
last_updated: 2026-05-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell-native fixture testing (no bats/zunit — keep dep surface small) |
| **Config file** | none — fixtures live under `manifests/test/fixtures/<NN>-<name>/` (golden-output files) |
| **Quick run command** | `task -t taskfiles/manifest.yml manifest:test` |
| **Full suite command** | `task -t taskfiles/manifest.yml manifest:test && task -t taskfiles/manifest.yml manifest:validate -- --machine personal-laptop` |
| **Estimated runtime** | ~2 seconds (six positive fixtures + two negative fixtures + one validate) |

Invocation prefix `task -t taskfiles/manifest.yml ...` is required for Phase 1 because the new module is NOT yet wired into the root `Taskfile.yml` (parallel-rewrite invariant — Phase 2 owns the root rewrite and adds the one-line include).

---

## Sampling Rate

- **After every task commit:** Run `task -t taskfiles/manifest.yml manifest:test` (positive + negative fixtures)
- **After every plan wave:** Run quick suite + `manifest:validate -- --machine personal-laptop`
- **Before `/gsd-verify-work`:** Full suite + all eleven requirement commands from RESEARCH §11.2 must pass + the end-to-end acceptance sequence from Plan 03 Task 2 acceptance criteria
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

> Populated by the planner. Each row maps a PLAN task to its automated verify command and the requirement it satisfies.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | MFST-03, MFST-05 (cases 1-6) | — | six positive fixtures encode D-06 merge rules correctly | unit (static) | `for d in manifests/test/fixtures/0[1-6]-*; do yq '.' "$d/defaults.toml" > /dev/null && yq '.' "$d/machine.toml" > /dev/null && jq '.' "$d/expected.json" > /dev/null; done` | ❌ W0 (Plan 01) | ⬜ pending |
| 01-01-02 | 01 | 1 | MFST-08, T-MAN-01 | T-MAN-01 | two negative fixtures (missing-desc, bad-os) on disk; README documents fixture layout | unit (static) | `test -f manifests/test/fixtures/_invalid-missing-desc/machine.toml && test -f manifests/test/fixtures/_invalid-bad-os/machine.toml && [ "$(yq -r '.platform.os' manifests/test/fixtures/_invalid-bad-os/machine.toml)" = "linux" ] && test -f manifests/test/README.md` | ❌ W0 (Plan 01) | ⬜ pending |
| 01-02-01 | 02 | 2 | MFST-04, MFST-08, T-MAN-01, T-MAN-02, T-MAN-03 | T-MAN-01, T-MAN-02, T-MAN-03 | resolver.zsh implements three modes (resolve/validate/stdout); rejects path-traversal; writes atomically; validates D-03 fields | smoke + unit | `zsh -n install/resolver.zsh && DOTFILEDIR=$(pwd) XDG_STATE_HOME=$(mktemp -d) zsh install/resolver.zsh 2>&1 \| grep -q 'no machine selected'` | ❌ W0 (Plan 02) | ⬜ pending |
| 01-02-02 | 02 | 2 | MFST-01, MFST-02 | — | defaults.toml + four machine manifests on disk; all validate clean | smoke | `for m in personal-laptop work-laptop server-1 server-2; do DOTFILEDIR=$(pwd) zsh install/resolver.zsh --validate-only --machine "$m"; done` | ❌ W0 (Plan 02) | ⬜ pending |
| 01-03-01 | 03 | 3 | MFST-06, MFST-07, T-MAN-02 | T-MAN-02 | go-task fromJson loads resolved.json; setup task path-traversal-guarded; manifest:show prints resolved JSON; manifest:resolve idempotent via BSD-find status | smoke | `STATE=$(mktemp -d) && DOTFILEDIR=$(pwd) XDG_STATE_HOME="$STATE" task -t taskfiles/manifest.yml setup -- personal-laptop && DOTFILEDIR=$(pwd) XDG_STATE_HOME="$STATE" task -t taskfiles/manifest.yml manifest:show \| jq -re '.identity.git' \| grep -q '^personal$'` | ❌ W0 (Plan 03) | ⬜ pending |
| 01-03-02 | 03 | 3 | MFST-05, MFST-08, MFST-09, T-MAN-01 | T-MAN-01 | manifest:test runs all positive + negative fixtures; manifest:test:add-machine proves MFST-09 with cleanup-on-failure | smoke (throwaway) | `STATE=$(mktemp -d) && DOTFILEDIR=$(pwd) XDG_STATE_HOME="$STATE" task -t taskfiles/manifest.yml setup -- personal-laptop && DOTFILEDIR=$(pwd) XDG_STATE_HOME="$STATE" task -t taskfiles/manifest.yml manifest:test && DOTFILEDIR=$(pwd) XDG_STATE_HOME="$STATE" task -t taskfiles/manifest.yml manifest:test:add-machine` | ❌ W0 (Plan 03) | ⬜ pending |
| 01-04-01 | 04 | 3 | DOCS-03 | — | repo-root CLAUDE.md replaced with v2 conventions document; v1 patterns scrubbed | static | `test -f CLAUDE.md && grep -q "manifest model" CLAUDE.md && grep -q "kebab-case" CLAUDE.md && grep -q "index" CLAUDE.md && ! grep -qE 'DOTFILES_PROFILE\|aliases/common' CLAUDE.md` | ❌ W0 (Plan 04) | ⬜ pending |
| 01-04-02 | 04 | 3 | DOCS-04 | — | docs/MANIFEST.md with required sections; five stub READMEs in placeholder dirs; docs/README.md index | static | `test -f docs/MANIFEST.md && grep -q "^## Merge Semantics" docs/MANIFEST.md && grep -q "^## Adding a New Machine" docs/MANIFEST.md && for d in shell identity packages configs os; do test -f "$d/README.md" && grep -q "Populated by Phase" "$d/README.md" && [ "$(wc -l < "$d/README.md")" -le 12 ]; done` | ❌ W0 (Plan 04) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirement → Task Coverage

Every phase requirement ID appears in at least one plan/task:

| Requirement | Plan(s) | Task ID(s) |
|---|---|---|
| MFST-01 | 02 | 01-02-02 |
| MFST-02 | 02 | 01-02-02 |
| MFST-03 | 01 | 01-01-01 |
| MFST-04 | 02 | 01-02-01 |
| MFST-05 | 01, 03 | 01-01-01, 01-03-02 |
| MFST-06 | 03 | 01-03-01 |
| MFST-07 | 03 | 01-03-01 |
| MFST-08 | 01, 02, 03 | 01-01-02, 01-02-01, 01-03-02 |
| MFST-09 | 03 | 01-03-02 |
| DOCS-03 | 04 | 01-04-01 |
| DOCS-04 | 04 | 01-04-02 |

All 11 requirements covered. No gaps.

---

## Threat → Mitigation Coverage

| Threat | Plan(s) | Mitigation |
|---|---|---|
| T-MAN-01 (malformed manifest) | 01 (fixtures), 02 (validator), 03 (test wiring) | Negative fixtures + hand-rolled validator + manifest:test runner |
| T-MAN-02 (path traversal) | 02 (resolver --machine guard), 03 (setup preconditions) | Defense-in-depth: kebab-case regex enforced at both taskfile and resolver layers |
| T-MAN-03 (atomic write) | 02 | mktemp + mv atomic-write pattern; single-writer to resolved.json |

---

## Wave 0 Requirements

All test infrastructure is NEW in Phase 1. Plan dependency order ensures Wave 0 (= Plan 01) lands first:

- [x] (Plan 01) `manifests/test/fixtures/01-map-over-map/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/02-list-replace/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/03-scalar-override/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/04-nested-table/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/05-missing-keys/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/06-extra-packages-concat/{defaults.toml,machine.toml,expected.json}`
- [x] (Plan 01) `manifests/test/fixtures/_invalid-missing-desc/machine.toml`
- [x] (Plan 01) `manifests/test/fixtures/_invalid-bad-os/machine.toml`
- [x] (Plan 02) `install/resolver.zsh` — unit under test
- [x] (Plan 03) `taskfiles/manifest.yml` — `manifest:test` task driver

(Checkboxes track plan ASSIGNMENT, not completion — completion is tracked in each plan's SUMMARY.md after execute-phase runs.)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AI-collaboration legibility | DOCS-03, project value | Subjective — must be confirmed by a human reading `CLAUDE.md` + `docs/MANIFEST.md` to determine an AI agent can reach correctness without inferring intent | After Wave 3 completes, point a fresh Claude session at the repo with no other context; ask it to "add a new machine named `staging-laptop`"; confirm it reads the manifest model docs and produces a correct TOML on first try |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has an automated verify command)
- [x] Wave 0 covers all MISSING references (six positive fixtures + two negative fixtures + resolver + task driver)
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** plans authored 2026-05-13; awaiting `/gsd-execute-phase 1` invocation.
