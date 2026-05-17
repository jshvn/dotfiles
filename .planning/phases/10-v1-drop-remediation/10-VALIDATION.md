---
phase: 10
slug: v1-drop-remediation
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-17
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `10-RESEARCH.md` `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task tasks themselves (no separate test runner for this phase) |
| **Config file** | `Taskfile.yml` (root) + `taskfiles/lint.yml` + new/edited `taskfiles/shell.yml` |
| **Quick run command** | `task lint:taskfile` (LINT-02 static check on the new status block) |
| **Full suite command** | `task validate && task lint && task test` |
| **Estimated runtime** | ~5-15 seconds for `task validate`; ~30 seconds for full suite |

---

## Sampling Rate

- **After every task commit:** Run `task lint:taskfile` (catches LINT-02 template-var regressions in the new `/etc/zshenv` status block)
- **After every plan wave:** Run `task validate` (catches `shell:validate` integration regressions; verifies the new `shell` component is wired into the root aggregator)
- **Before `/gsd:verify-work`:** Full suite must be green AND the smoke procedure in `10-SMOKE.md` recorded as PASS
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | PORT-01 | — | `/etc/zshenv` contains `export ZDOTDIR="$HOME/.config/zsh"` after `task install` | integration | `task install && grep -qF 'export ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv` | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | PORT-01 | — | Re-running `task install` is a no-op (sudo not re-invoked once `/etc/zshenv` line is present) | integration | `task install; task install 2>&1 \| grep -cE 'sudo:'` returns 0 on the second run | ✅ | ⬜ pending |
| 10-01-03 | 01 | 1 | PORT-01 | — | The new status block uses `{{.ZDOTDIR}}` template var, not `$ZDOTDIR` (LINT-02) | static | `task lint:taskfile` exits 0 | ✅ | ⬜ pending |
| 10-01-04 | 01 | 1 | PORT-02 | — | `task shell:validate` exits 0 on a correctly set-up machine | integration | `task shell:validate; [[ $? -eq 0 ]]` | ❌ W0 (task does not yet exist) | ⬜ pending |
| 10-01-05 | 01 | 1 | PORT-02 | — | `task shell:validate` exits non-zero when `/etc/zshenv` is missing the ZDOTDIR line | integration | `sudo mv /etc/zshenv /tmp/zshenv.bak; task shell:validate; ec=$?; sudo mv /tmp/zshenv.bak /etc/zshenv; [[ $ec -ne 0 ]]` | ❌ W0 | ⬜ pending |
| 10-01-06 | 01 | 1 | PORT-02 | — | `task validate` includes `shell` row in its component summary | integration | `task validate 2>&1 \| grep -E '(check\|cross) shell'` exits 0 | ❌ W0 (aggregator not yet wired) | ⬜ pending |
| 10-01-07 | 01 | 1 | (audit) | — | `.planning/phases/09-v1-drop-audit/AUDIT.md` row #3 (`install/Brewfile-personal.rb:72`) reclassified `keep` → `drop`; counts table reads Keep 2 / Drop 100 | static | `grep -E '^\| install/Brewfile-personal.rb:72' .planning/phases/09-v1-drop-audit/AUDIT.md \| grep -q '\| drop \|'` exits 0 | ✅ | ⬜ pending |
| 10-01-08 | 01 | 1 | PORT-03 | — | `10-SMOKE.md` exists in the phase dir, documents the fresh-shell smoke procedure, and records a PASS result for the executing operator's machine | manual | Operator walks the checklist in `10-SMOKE.md` and records PASS/FAIL with date and machine name | ❌ W0 (smoke doc not yet created) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] No new test infrastructure required — existing `task lint`, `task validate`, `task test`, and `task lint:taskfile` cover the automated validation surface.
- [x] The smoke procedure is the only "test artifact" introduced (PORT-03) and the document IS the validation artifact — no framework wiring needed.

*This phase introduces no new test infrastructure; existing go-task-based validation covers all PORT-01/PORT-02 surfaces. PORT-03 is satisfied by an operator-run documented smoke procedure (D-08).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh-shell smoke procedure passes on the operator's personal machine | PORT-03 | The procedure asserts behavior in a brand-new interactive shell, which cannot be reliably reproduced by an automated test runner inside an already-loaded shell (assertions like "the antidote prompt renders" and "`alias` lists ported aliases" depend on `.zshrc` having sourced cleanly in a fresh process). D-08 explicitly accepts a documented smoke procedure in lieu of a real fresh-machine install. | Walk through `10-SMOKE.md`: bootstrap → setup → install → open a new terminal → confirm `$ZDOTDIR` resolves, the alanpeabody prompt renders, `which _dotfiles_feature` resolves, `alias` lists the ported aliases, and `motd` prints. Record PASS/FAIL with operator initials, date, and machine name in `10-SMOKE.md` `## Run Log`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (one manual-only task: smoke procedure, justified above)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (smoke procedure is the only manual; sandwich it between automated lint + validate runs)
- [ ] Wave 0 covers all MISSING references (none — no new framework needed)
- [ ] No watch-mode flags (go-task tasks run once and exit; no `--watch`)
- [ ] Feedback latency < 30s (validate + lint complete in ~15s typical)
- [ ] `nyquist_compliant: true` set in frontmatter (flip after plan-checker confirms `<automated>` blocks reference these verifications)

**Approval:** pending
