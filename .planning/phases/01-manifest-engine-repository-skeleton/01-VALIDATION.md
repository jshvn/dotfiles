---
phase: 1
slug: manifest-engine-repository-skeleton
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell-native fixture testing (no bats/zunit — keep dep surface small) |
| **Config file** | none — fixtures live under `manifests/test/fixtures/<NN>-<name>/` (golden-output files) |
| **Quick run command** | `task manifest:test` |
| **Full suite command** | `task manifest:test && task manifest:validate -- --machine personal-laptop` |
| **Estimated runtime** | ~2 seconds (six fixtures + one validate) |

---

## Sampling Rate

- **After every task commit:** Run `task manifest:test`
- **After every plan wave:** Run `task manifest:test && task manifest:validate -- --machine personal-laptop`
- **Before `/gsd-verify-work`:** Full suite + all eleven requirement commands from §11.2 of RESEARCH.md must pass
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

> Populated by the planner during PLAN.md generation. Each row maps a PLAN task to its automated verify command and the requirement it satisfies.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 0 | MFST-03/05 | — | merge produces expected.json for fixture | unit | `task manifest:test` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | MFST-01/02/04 | — | resolver compiles defaults + machine | smoke | `task setup -- personal-laptop && test -f $XDG_STATE_HOME/dotfiles/resolved.json` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | MFST-08 | T-MAN-01 | invalid machine TOML rejected | unit | `task manifest:validate -- --machine _invalid-missing-desc` (expect non-zero) | ❌ W0 | ⬜ pending |
| TBD | 01 | 2 | MFST-06/07 | — | go-task reads resolved.json via fromJson | smoke | sanity task asserts `{{.MANIFEST.identity.git}}` non-empty | ❌ W0 | ⬜ pending |
| TBD | 01 | 3 | DOCS-03 | — | project-level CLAUDE.md on disk | static | `test -f CLAUDE.md && grep -q "manifest model" CLAUDE.md` | ❌ W0 | ⬜ pending |
| TBD | 01 | 3 | DOCS-04 | — | docs/MANIFEST.md on disk with sections | static | `test -f docs/MANIFEST.md && grep -q "## Merge Semantics" docs/MANIFEST.md` | ❌ W0 | ⬜ pending |
| TBD | 01 | 4 | MFST-09 | — | adding a 5th machine is one TOML + setup | smoke (throwaway) | `task manifest:test:add-machine` (creates `_addmachine-test`, asserts, cleans up) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All test infrastructure is NEW in Phase 1. None of these files exist yet:

- [ ] `manifests/test/fixtures/01-map-over-map/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 1: map-over-map deep-merge)
- [ ] `manifests/test/fixtures/02-list-replace/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 2: array replace)
- [ ] `manifests/test/fixtures/03-scalar-override/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 3: scalar replace)
- [ ] `manifests/test/fixtures/04-nested-table/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 4: nested table deep-merge)
- [ ] `manifests/test/fixtures/05-missing-keys/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 5: missing-in-defaults, missing-in-machine)
- [ ] `manifests/test/fixtures/06-extra-packages-concat/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 6: extra_packages concat + dedupe)
- [ ] `manifests/test/fixtures/_invalid-missing-desc/machine.toml` (no expected.json — must fail validation) — covers MFST-08
- [ ] `manifests/test/fixtures/_invalid-bad-os/machine.toml` (platform.os = "linux") — covers MFST-08 and D-01
- [ ] `install/resolver.zsh` — unit under test
- [ ] `taskfiles/manifest.yml` — `manifest:test` task driver

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AI-collaboration legibility | DOCS-03, project value | Subjective — must be confirmed by a human reading `CLAUDE.md` + `docs/MANIFEST.md` to determine an AI agent can reach correctness without inferring intent | After Wave 3, point a fresh Claude session at the repo with no other context; ask it to "add a new machine named `staging-laptop`"; confirm it reads the manifest model docs and produces a correct TOML on first try |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (six fixtures + two invalid fixtures + resolver + task driver)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner fills Per-Task Verification Map)

**Approval:** pending
