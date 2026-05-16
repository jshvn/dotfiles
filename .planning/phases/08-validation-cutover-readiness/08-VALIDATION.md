---
phase: 8
slug: validation-cutover-readiness
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-16
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `08-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task (task runner as test runner; no dedicated test framework) |
| **Config file** | `Taskfile.yml` (root) |
| **Quick run command** | `task lint` |
| **Full suite command** | `task lint && task test && task validate` |
| **Estimated runtime** | ~30 seconds (lint + test); +~10s for full `task validate` after components land |

---

## Sampling Rate

- **After every task commit:** Run `task lint`
- **After every plan wave:** Run `task lint && task test`
- **Before `/gsd:verify-work`:** Full suite must be green: `task lint && task test && task validate`, plus a real `task install` run on `personal-laptop`
- **Max feedback latency:** ~30 seconds for the per-task lint loop

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-T1 | 08-01-PLAN.md | 1 | CUTV-02 | T-08-01 | EXPECTED_TARGETS var added; bare manifest:resolve deps flipped to leading-colon form; no LINT-02/03a/03b violations | static + integration | `grep -n 'EXPECTED_TARGETS:' taskfiles/links.yml && grep -c 'deps: \[":manifest:resolve"\]' taskfiles/links.yml | awk '{ if ($1 >= 2) exit 0; else exit 1 }' && grep -v '^[[:space:]]*#' taskfiles/links.yml | grep -c 'deps: \[manifest:resolve\]' | awk '{ if ($1 == 0) exit 0; else exit 1 }' && task lint` | yes | pending |
| 08-01-T2 | 08-01-PLAN.md | 1 | CUTV-02 | T-08-01 | Zero standalone `{{if}}`/`{{end}}` cmds: entries; feature gating preserved via inline-ternary status: blocks | static + integration | `grep -nE "^[[:space:]]*-[[:space:]]*'\{\{(if|end)" taskfiles/links.yml | wc -l | awk '{ if ($1 == 0) exit 0; else exit 1 }' && task lint && task --list-all --json >/dev/null` | yes | pending |
| 08-01-T3 | 08-01-PLAN.md | 1 | CUTV-02 | T-08-01, T-08-02 | links:validate exits non-zero on broken symlink; exits 0 on healthy; consumes EXPECTED_TARGETS as single source of truth | integration (mutation) | `task --list-all --json >/dev/null && task lint && bash -c 'task links:validate >/tmp/links-validate-healthy.log 2>&1; healthy_exit=$?; target="$HOME/.config/zsh/.zsh_plugins.txt"; if [[ -L "$target" ]]; then src="$(readlink "$target")"; unlink "$target"; task links:validate >/tmp/links-validate-broken.log 2>&1; broken_exit=$?; ln -sfn "$src" "$target"; else broken_exit=99; fi; [[ $healthy_exit -eq 0 ]] && [[ $broken_exit -ne 0 ]]'` | yes | pending |
| 08-02-T1 | 08-02-PLAN.md | 2 | CUTV-01 | T-08-04 | Probe verifies go-task 3.37 supports per-entry `ignore_error: true`; mechanism committed before aggregator implementation | integration (probe) | `bash -c 'cat >/tmp/probe.yml <<EOF\nversion: "3"\nsilent: true\ntasks:\n  default:\n    cmds:\n      - task: fail\n        ignore_error: true\n      - task: ok\n  fail:\n    cmds: [exit 1]\n  ok:\n    cmds: [echo OK-RAN]\nEOF\ntask -t /tmp/probe.yml 2>&1 | grep -q OK-RAN'` | yes | pending |
| 08-02-T2 | 08-02-PLAN.md | 2 | CUTV-01 | T-08-04 | claude:validate emits D-06 sentinel `feature disabled -- skipped` and exits 0 when claude-marketplace=false; original body preserved when on | integration (manifest swap) | `task lint && task --list-all --json >/dev/null && bash -c 'task claude:validate 2>&1 | grep -c "feature disabled -- skipped" | awk "{ if (\$1 == 0) exit 0; else exit 1 }"'` | yes | pending |
| 08-02-T3 | 08-02-PLAN.md | 2 | CUTV-01 | T-08-04, T-08-05, T-08-06 | Root `task validate` aggregator runs all six per-component validates with run-all-aggregate semantics; prints summary; exits non-zero on any failure; injected dual failures produce TWO cross lines (proves run-all) | integration (mutation + dual-failure) | `task --list 2>&1 | grep -q '^\* validate:' && task lint && task validate --dry 2>&1 | grep -qi 'manifest:resolve' && bash -c 'task validate >/tmp/validate-healthy.log 2>&1; h_exit=$?; target="$HOME/.config/zsh/.zsh_plugins.txt"; if [[ -L "$target" ]]; then src=$(readlink "$target"); unlink "$target"; task validate >/tmp/validate-broken.log 2>&1; b_exit=$?; ln -sfn "$src" "$target"; else b_exit=99; fi; [[ $h_exit -eq 0 ]] && [[ $b_exit -ne 0 ]] && grep -q "links" /tmp/validate-broken.log'` | yes | pending |
| 08-03-T1 | 08-03-PLAN.md | 3 | CUTV-02, CUTV-07, CUTV-08 | T-08-07, T-08-11 | links:reconcile three-mode dispatch; TTY-gate on --remove; uses `unlink` only (never `rm`); detects orphans bounded to EXPECTED_TARGETS parent dirs | integration (4 behavior modes) | `task --list 2>&1 | grep -q '^\* links:reconcile:' && task lint && bash -c 'task links:reconcile >/tmp/reconcile-clean.log 2>&1; clean_exit=$?; orphan_path="$HOME/.config/glow/glow-orphan-test.yml"; ln -sfn "$(pwd)/configs/glow/glow.yml" "$orphan_path"; task links:reconcile >/tmp/reconcile-orphan.log 2>&1; orphan_exit=$?; task links:reconcile -- --warn-only >/tmp/reconcile-warn.log 2>&1; warn_exit=$?; echo "" | task links:reconcile -- --remove >/tmp/reconcile-noTTY.log 2>&1; noTTY_exit=$?; unlink "$orphan_path" 2>/dev/null || true; [[ $clean_exit -eq 0 ]] && [[ $orphan_exit -ne 0 ]] && [[ $warn_exit -eq 0 ]] && [[ $noTTY_exit -ne 0 ]] && grep -q "orphan" /tmp/reconcile-orphan.log'` | yes | pending |
| 08-03-T2 | 08-03-PLAN.md | 3 | CUTV-02, CUTV-07, CUTV-08 | T-08-08, T-08-09, T-08-23 | cutover:ack writer with regex validation + active-machine match + ISO-8601 UTC sentinel; install pipeline ends with `links:reconcile -- --warn-only`; install non-fatal on orphan | integration (5 behaviors) | `task --list 2>&1 | grep -q '^\* cutover:ack:' && task lint && bash -c 'ack="$HOME/.local/state/dotfiles/cutover-ack"; backup="$(mktemp)"; cp "$ack" "$backup" 2>/dev/null || rm -f "$backup"; task cutover:ack >/tmp/cutover-noarg.log 2>&1; noarg_exit=$?; task cutover:ack -- "BAD NAME WITH SPACES" >/tmp/cutover-badname.log 2>&1; badname_exit=$?; task cutover:ack -- _nonexistent-machine >/tmp/cutover-mismatch.log 2>&1; mismatch_exit=$?; active=$(head -n1 "$HOME/.local/state/dotfiles/machine" | tr -d "[:space:]"); task cutover:ack -- "$active" >/tmp/cutover-ok.log 2>&1; ok_exit=$?; written_ok=0; if [[ -f "$ack" ]]; then read -r ack_machine ack_ts < "$ack"; [[ "$ack_machine" == "$active" ]] && [[ -n "$ack_ts" ]] && written_ok=1; fi; [[ -f "$backup" ]] && cp "$backup" "$ack" && rm -f "$backup"; [[ $noarg_exit -ne 0 ]] && [[ $badname_exit -ne 0 ]] && [[ $mismatch_exit -ne 0 ]] && [[ $ok_exit -eq 0 ]] && [[ $written_ok -eq 1 ]]'` | yes | pending |
| 08-04-T1 | 08-04-PLAN.md | 4 | CUTV-03, DOCS-08 | T-08-13 | docs/CUTOVER.md exists with `## Fresh-machine verification` numbered procedure + `## Per-machine cutover state` table; cross-refs SECURITY/MANIFEST; no emojis | static | `test -f docs/CUTOVER.md && grep -q '^## Fresh-machine verification' docs/CUTOVER.md && grep -q '^## Per-machine cutover state' docs/CUTOVER.md && grep -q 'task cutover:ack' docs/CUTOVER.md && grep -q 'docs/SECURITY.md' docs/CUTOVER.md && grep -q 'docs/MANIFEST.md' docs/CUTOVER.md && grep -q 'personal-laptop' docs/CUTOVER.md && grep -q 'work-laptop' docs/CUTOVER.md && grep -q 'server-1' docs/CUTOVER.md && grep -q 'server-2' docs/CUTOVER.md && ! ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/CUTOVER.md` | yes | pending |
| 08-04-T2 | 08-04-PLAN.md | 4 | DOCS-06 | T-08-12 | docs/MACHINES.md exists with H2 per machine; deference line to manifests/machines/<name>.toml; no tables; no emojis | static | `test -f docs/MACHINES.md && grep -q '^# Machine Reference' docs/MACHINES.md && grep -q '^## personal-laptop' docs/MACHINES.md && grep -q '^## work-laptop' docs/MACHINES.md && grep -q '^## server-1' docs/MACHINES.md && grep -q '^## server-2' docs/MACHINES.md && [ "$(grep -c 'manifests/machines/' docs/MACHINES.md)" -ge 4 ] && ! ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/MACHINES.md` | yes | pending |
| 08-05-T1 | 08-05-PLAN.md | 5 | DOCS-05 | T-08-15, T-08-18 | docs/MIGRATION.md exists with 7 concept H2 sections + Rollback + Archiving v1; cross-refs MANIFEST/CUTOVER; no emojis | static | `test -f docs/MIGRATION.md && grep -q '^# Migration Guide: v1 to v2' docs/MIGRATION.md && grep -q '^## Profile suffix' docs/MIGRATION.md && grep -q '^## Antigen' docs/MIGRATION.md && grep -q '^## Brewfile' docs/MIGRATION.md && grep -q '^## zsh/' docs/MIGRATION.md && grep -q '^## gsd-install' docs/MIGRATION.md && grep -q '^## Hostname' docs/MIGRATION.md && grep -q '^## macos:shell' docs/MIGRATION.md && grep -q '^## Rollback' docs/MIGRATION.md && grep -q '^## Archiving v1' docs/MIGRATION.md && grep -q 'docs/MANIFEST.md' docs/MIGRATION.md && grep -q 'docs/CUTOVER.md' docs/MIGRATION.md && ! ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/MIGRATION.md` | yes | pending |
| 08-05-T2 | 08-05-PLAN.md | 5 | DOCS-01 | T-08-17 | README.md replaced; H1 `# dotfiles`; 4 H2 sections; Fresh Machine Setup fenced block contains the 5-command sequence including `task cutover:ack`; no v1 vocabulary; no emojis | static (with structural anti-tests) | `head -1 README.md | grep -q '^# dotfiles$' && grep -q '^## What This Is' README.md && grep -q '^## Fresh Machine Setup' README.md && grep -q '^## Where to Add Things' README.md && grep -q '^## Documentation' README.md && grep -A 10 'Fresh Machine Setup' README.md | grep -q 'task cutover:ack' && grep -q 'docs/MANIFEST.md' README.md && grep -q 'docs/SECURITY.md' README.md && grep -q 'docs/CUTOVER.md' README.md && grep -q 'docs/MIGRATION.md' README.md && grep -q 'docs/MACHINES.md' README.md && grep -q '.claude/CLAUDE.md' README.md && grep -q 'task setup --' README.md && grep -q './bootstrap.zsh' README.md && ! grep -q 'DOTFILES_PROFILE' README.md && ! grep -q -i 'profile suffix' README.md && ! ggrep -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' README.md` | yes | pending |
| 08-06-T1 | 08-06-PLAN.md | 6 | CUTV-04, CUTV-05 | T-08-19, T-08-20 | personal-laptop row in docs/CUTOVER.md shows status `cut-over` after 7-day soak; commit references personal-laptop cutover | manual (operator-driven; 7-day calendar gate) | n/a (checkpoint:human-action) | yes | pending |
| 08-06-T2 | 08-06-PLAN.md | 6 | CUTV-04, CUTV-05 | T-08-19, T-08-20 | server-1 row in docs/CUTOVER.md shows status `cut-over` after 7-day soak | manual (operator-driven; 7-day calendar gate) | n/a (checkpoint:human-action) | yes | pending |
| 08-06-T3 | 08-06-PLAN.md | 6 | CUTV-04, CUTV-05 | T-08-19, T-08-20 | server-2 row in docs/CUTOVER.md shows status `cut-over` after 7-day soak | manual (operator-driven; 7-day calendar gate) | n/a (checkpoint:human-action) | yes | pending |
| 08-06-T4 | 08-06-PLAN.md | 6 | CUTV-04, CUTV-05 | T-08-19, T-08-20, T-08-21 | work-laptop row in docs/CUTOVER.md shows status `cut-over` after 7-day soak | manual (operator-driven; 7-day calendar gate) | n/a (checkpoint:human-action) | yes | pending |
| 08-06-T5 | 08-06-PLAN.md | 6 | CUTV-06 | T-08-19, T-08-22 | All four rows in docs/CUTOVER.md show status `archived`; archive branch exists on origin; v1 renamed (not deleted) | manual (operator-driven; cross-repo git op) | n/a (checkpoint:human-action) | yes | pending |

*Status: pending / green / red / flaky*

*Source-of-truth: each row's "Automated Command" column is the verbatim `<verify><automated>` from the corresponding PLAN.md task. Plan 06 tasks are `checkpoint:human-action` and are intentionally exempt from `<automated>` per the Nyquist contract (calendar-driven 7-day soaks cannot live inside a numbered plan); they appear here for completeness with test type "manual" and automated command "n/a".*

---

## Wave 0 Requirements

- [x] No new test files needed — Phase 8 validates itself through the existing `task lint` / `task test` / `task validate` pipeline and the D-03 real-install run on `personal-laptop`

*Existing infrastructure (taskfile lint, helper checks, real install on personal-laptop) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `task validate` prints summary table with per-component check/cross | CUTV-01 | Output format is operator-readable; visual confirmation is the spec | Run `task validate` on a healthy machine; confirm one row per component with check (green) markers |
| Orphan-warning text appears at end of `task install` | CUTV-08 | Install output is human-facing; we want to see the exact warning text | Create an orphan symlink under `$DOTFILEDIR`, run `task install`, confirm warning prints and exit code is 0 |
| `links:reconcile -- --remove` interactive y/N prompts work at a TTY | CUTV-07 | Interactive prompt cannot be fully scripted without a pty wrapper | Create 2 orphans, run `task links:reconcile -- --remove`, answer y to first / N to second, confirm only the y'd link is removed |
| Per-machine fresh-install verification procedure works on a clean Mac | DOCS-08 / CUTV-04 | Requires a clean macOS install; cannot be automated in CI | Follow steps in `docs/CUTOVER.md` § "Fresh-machine verification" on a freshly imaged Mac |
| 7-day soak per machine before declaring cut over | CUTV-05 | Calendar-driven; not a test command | Update `docs/CUTOVER.md` per-machine state table as each machine crosses its 7-day mark |
| v1 repo archive (renamed, not deleted) after last machine cuts over | CUTV-06 | Cross-repo manual git operation; out of scope for taskfile automation | Run the documented `git remote rename` / directory move sequence in `docs/MIGRATION.md` § "Archiving v1" |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Plan 06 tasks are checkpoint:human-action and exempt by Nyquist contract)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (within plans 01-05; plan 06 is operator-driven)
- [x] Wave 0 covers all MISSING references (no Wave 0 needed for Phase 8)
- [x] No watch-mode flags
- [x] Feedback latency < 30s for per-task lint loop
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-05-16
