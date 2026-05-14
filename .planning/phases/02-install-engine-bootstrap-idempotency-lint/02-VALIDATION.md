---
phase: 02
slug: install-engine-bootstrap-idempotency-lint
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-13
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `02-RESEARCH.md` section 10 (Validation Architecture).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell-native fixture testing (no bats/zunit — consistent with Phase 1 `manifest:test`) |
| **Config file** | none — lint fixtures live under `taskfiles/test/lint-fixtures/<NN>-<name>/` |
| **Quick run command** | `task lint` |
| **Full suite command** | `task lint && task lint:test-fixtures` |
| **Estimated runtime** | < 5 seconds (lint suite is sub-second on this repo size; fixture self-test adds ~1-2s) |

---

## Sampling Rate

- **After every task commit:** Run `task lint`
- **After every plan wave:** Run `task lint && task lint:test-fixtures`
- **Before `/gsd-verify-work`:** Full suite must be green (all 18 phase-requirement assertions pass)
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

> Plan/Wave/Task IDs are placeholders until `gsd-planner` finalizes plan numbering. The Requirement and Automated Command columns are authoritative — they map directly to phase requirements and will not change.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | bootstrap | 1 | BTSP-01 | T-02-bootstrap-trust | bootstrap.zsh has `set -euo pipefail` | static | `head -30 bootstrap.zsh \| ggrep -q '^set -euo pipefail$'` | ❌ W0 | ⬜ pending |
| TBD | bootstrap | 1 | BTSP-02 | T-02-bootstrap-trust | bootstrap installs go-task via `brew install`, never `curl \| sh` | static | `! ggrep -E 'curl.*\| *(sh\|bash)' bootstrap.zsh && ggrep -q 'brew install go-task' bootstrap.zsh` | ❌ W0 | ⬜ pending |
| TBD | bootstrap | 2 | BTSP-03 | — | `./bootstrap.zsh` re-run is a no-op | smoke (live) | `./bootstrap.zsh > /tmp/run1.txt; ./bootstrap.zsh > /tmp/run2.txt; ! ggrep -E 'Installing (brew\|go-task\|yq)' /tmp/run2.txt` | ❌ W0 | ⬜ pending |
| TBD | install | 2 | BTSP-04 | — | `task setup -- <name>` writes machine state (Phase 1 already covers) | unit (P1) | `task setup -- personal-laptop && test -f $XDG_STATE_HOME/dotfiles/machine` | ✅ (P1) | ⬜ pending |
| TBD | docs | 3 | BTSP-05 | T-02-bootstrap-trust | `docs/SECURITY.md` documents trust chain (Bootstrap Trust Chain, Threat Model, Trust Anchors) | static | `test -f docs/SECURITY.md && ggrep -qE '^## Bootstrap Trust Chain$' docs/SECURITY.md && ggrep -qE '^## Threat Model$' docs/SECURITY.md && ggrep -qE '^## Trust Anchors$' docs/SECURITY.md` | ❌ W0 | ⬜ pending |
| TBD | install | 1 | BTSP-06 | — | `task install` is canonical; no `task update` exists | static | `task --list-all --json \| jq -e '.tasks \| map(.name) \| index("update") == null'` | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-01 | — | every task in `task install` call graph has `status:` | unit | `task lint:taskfile` exits 0 against the v2 Taskfile.yml + included taskfiles | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-02 (pos) | — | `$VAR` in `status:` block is detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/02a-shell-var-in-status/Taskfile.yml` exits non-zero | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-02 (neg) | — | `{{.X}}` in `status:` block does NOT trigger | unit (negative fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/02b-template-var-in-status/Taskfile.yml` exits 0 | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-03a | — | `cmds:` without `status:` detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/03a-cmds-no-status/Taskfile.yml` exits non-zero | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-03b | — | bare `ln -s` outside `helpers.yml` detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` exits non-zero | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-04 | — | executable `.zsh` missing `set -euo pipefail` detected | unit (positive fixture) | `task lint:shell-headers` against fixture .zsh missing the line exits non-zero | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-05 | — | portability patterns warn but exit 0 (non-blocking) | unit (positive fixture) | `task lint:portability` against shell file with `pbcopy` prints warning AND exits 0 | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-06 | — | `task lint` aggregates all sub-checks (syntax, taskfile, shell-headers, portability) | smoke | `task lint` runs `lint:syntax`, `lint:taskfile`, `lint:shell-headers`, `lint:portability` sequentially | ❌ W0 | ⬜ pending |
| TBD | lint | 1 | LINT-07 | — | `zsh -n` parse error detected | unit (positive fixture) | `task lint:syntax` against fixture `.zsh` with intentional syntax error exits non-zero | ❌ W0 | ⬜ pending |
| TBD | — | — | LINT-08 | — | DEPRECATED — not implemented per CONTEXT.md decision D-11 | n/a | — | n/a | n/a |
| TBD | docs | 3 | DOCS-07 | T-02-bootstrap-trust | `docs/SECURITY.md` present with bootstrap trust chain section | static | (same as BTSP-05) | ❌ W0 | ⬜ pending |
| TBD | install | 2 | (gate) | T-02-cutover-bypass | bootstrap fails actionably without cutover-ack sentinel | unit | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && ./bootstrap.zsh` — expect exit 1 + actionable error referencing `task cutover:ack` | ❌ W0 | ⬜ pending |
| TBD | install | 2 | (gate) | T-02-cutover-bypass | `task install` fails actionably without cutover-ack sentinel | unit | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && task install` — expect exit 1 + actionable error | ❌ W0 | ⬜ pending |
| TBD | install | 2 | (gate) | T-02-cutover-bypass | Read-only tasks NOT blocked by missing cutover-ack | smoke | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && task lint && task manifest:show` — both succeed | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**Lint fixtures** (each has a `Taskfile.yml` or `*.zsh` plus an `expect` file containing `pass` or `fail`):

- [ ] `taskfiles/test/lint-fixtures/02a-shell-var-in-status/` — positive: status block uses `$VAR`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/02b-template-var-in-status/` — negative: status uses `{{.X}}`. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/02c-command-substitution-in-status/` — negative: status uses `$(cmd)`. Expect PASS (legitimate).
- [ ] `taskfiles/test/lint-fixtures/03a-cmds-no-status/` — positive: task has `cmds:` but no `status:`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/03a-internal-no-status-ok/` — negative: `internal: true` task with `cmds:` and no `status:`. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/03b-bare-ln/` — positive: taskfile has `ln -sf` outside `helpers.yml`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/03b-helpers-allowed/` — negative: `helpers.yml` has `ln -sfn`. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/04a-missing-set-euo/` — positive: executable `.zsh` has only `set -e`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/04b-non-exec-no-set/` — negative: non-executable `.zsh` has no `set` line. Expect PASS (sourced-only files exempt).
- [ ] `taskfiles/test/lint-fixtures/05a-pbcopy-warn/` — positive (warn): shell file uses `pbcopy`. Expect WARN + exit 0.
- [ ] `taskfiles/test/lint-fixtures/07a-syntax-error/` — positive: `.zsh` with deliberate syntax error. Expect FAIL.

**New artifacts (none exist yet):**

- [ ] `bootstrap.zsh` (rewrite — replaces v1)
- [ ] `Taskfile.yml` (rewrite — replaces v1; drops `update:` per D-10)
- [ ] `taskfiles/install.yml` — v2 install orchestration (or inline in root Taskfile per planner preference)
- [ ] `taskfiles/lint.yml` — the lint suite (`lint:syntax`, `lint:taskfile`, `lint:shell-headers`, `lint:portability`, `lint:test-fixtures`)
- [ ] `taskfiles/links-stub.yml`, `brew-stub.yml`, `claude-stub.yml`, `macos-stub.yml` — stub files for Phases 3/5/6/7
- [ ] `install/cutover-gate.zsh` — sourced helper enforcing cutover-ack sentinel
- [ ] `docs/SECURITY.md` — bootstrap trust chain documentation

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh-machine bootstrap on a never-before-set-up macOS install | BTSP-01, BTSP-02, BTSP-03 | Cannot reliably automate without disposable VMs/CI runners that boot from clean macOS | On a fresh macOS machine (or VM with no Homebrew installed): clone repo, `./bootstrap.zsh`, then re-run and verify second run is no-op (`./bootstrap.zsh` second invocation prints only "already installed" lines, completes in <1s) |
| Cutover-ack acknowledgement workflow | (gate) | Requires user attention to dotfiles change-window | `task cutover:ack` writes `$XDG_STATE_HOME/dotfiles/cutover-ack`; verify file contents `<machine-name> <iso-ts>` and that subsequent `task install` no longer errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (11 lint fixtures + 7 new artifacts)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter (planner sets this after task IDs are filled in)

**Approval:** pending
