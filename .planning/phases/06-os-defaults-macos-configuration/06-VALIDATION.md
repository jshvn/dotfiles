---
phase: 06
slug: os-defaults-macos-configuration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `06-RESEARCH.md ## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task task-level invocations (no separate test framework) + `task lint` + `task macos:validate` |
| **Config file** | `Taskfile.yml` (root, edited in P6 to flip `includes.macos`) + `taskfiles/macos.yml` (P6 deliverable, replaces `macos-stub.yml`) + `taskfiles/lint.yml` (existing P2 surface, no edits required) |
| **Quick run command** | `task lint && zsh -n os/defaults/<edited-file>.zsh` |
| **Full suite command** | `task lint && task macos:validate` (on a converged test machine; full `task install` round-trip reserved for HUMAN-UAT) |
| **Estimated runtime** | ~10 s for lint + 5 s for `macos:validate` on a converged machine (every concern enabled) |

---

## Sampling Rate

- **After every task commit:** Run `task lint && zsh -n <edited-file>.zsh` (~10 s)
- **After every plan wave:** Run `task lint && task macos:validate` (on the developer's converged personal-laptop or work-laptop)
- **Before `/gsd-verify-work`:** Full suite + HUMAN-UAT (server-mode + laptop-mode + idempotency + bug-class regression + deliberate-mismatch checks) — see `06-HUMAN-UAT.md` (planner creates)
- **Max feedback latency:** 15 s (per-commit); 60 s (per-wave incl. HUMAN-UAT smoke)

---

## Per-Task Verification Map

> Filled by the planner per Wave / Plan / Task. The skeleton below maps requirements to verification commands; planner assigns Task IDs.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| {06-NN-NN} | NN | 0 | OSCF-01 | — | concern scripts and `os/shell-registration.zsh` exist | smoke | `for f in os/defaults/{dock,finder,input,screenshots,security}.zsh os/shell-registration.zsh; do test -f "$f"; done` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 0 | OSCF-01 | — | each concern script declares `<CONCERN>_DEFAULTS` array + `apply_<concern>` + `verify_<concern>` | smoke | `for c in dock finder input screenshots security; do grep -q "^typeset -ga ${c:u}_DEFAULTS=" "os/defaults/$c.zsh" && grep -q "^apply_$c()" "os/defaults/$c.zsh" && grep -q "^verify_$c()" "os/defaults/$c.zsh"; done` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 1 | OSCF-02 | — | `macos:defaults:<concern>` tasks are feature-gated via `index .MANIFEST.features "macos-<concern>"` | unit | `for c in dock finder input screenshots security; do yq ".tasks.\"defaults:$c\".status" taskfiles/macos.yml \| grep -q "index .MANIFEST.features \"macos-$c\""; done` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 0 | OSCF-02 | — | `manifests/defaults.toml` declares the 4 new kebab-case feature keys | unit | `for k in macos-dock macos-input macos-screenshots macos-security; do grep -q "^$k = " manifests/defaults.toml; done` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 0 | OSCF-02 | — | server TOMLs declare `macos-security = true` | unit | `grep -q '^macos-security = true' manifests/machines/server-1.toml && grep -q '^macos-security = true' manifests/machines/server-2.toml` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 2 | OSCF-03 | T-06-IDEMP | every `defaults write` line in `os/defaults/*.zsh` has a matching `defaults read` in the script's `verify_<concern>` | integration | `for f in os/defaults/*.zsh; do writes=$(grep -c "defaults.*write" "$f"); reads=$(grep -c "defaults.*read" "$f"); [[ "$writes" -le "$reads" ]]; done` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 2 | OSCF-03 | T-06-IDEMP | re-running `task macos:defaults` performs zero `defaults write` operations | manual / integration | HUMAN-UAT: run `task macos:defaults` twice on a converged laptop; second invocation prints no "writing ..." info lines | ❌ W0 (manual UAT) | ⬜ pending |
| {06-NN-NN} | NN | 1 | OSCF-04 | T-06-BUG145 | `task macos:shell` status uses `{{.BREW_ZSH}}` template var only — NO `$BREW_ZSH` shell var | unit (LINT-02 regression) | `yq '.tasks.shell.status' taskfiles/macos.yml \| grep -qE '\$BREW_ZSH\b'` MUST exit non-zero | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 1 | OSCF-04 | — | `os/shell-registration.zsh` exposes `apply_shell_registration` and `verify_shell_registration` | smoke | `grep -q '^apply_shell_registration()' os/shell-registration.zsh && grep -q '^verify_shell_registration()' os/shell-registration.zsh` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 2 | OSCF-04 | T-06-SERVER | server install runs only `macos:shell` + `macos:defaults:security`; other 4 concern tasks skip at the feature-gate level | manual UAT | HUMAN-UAT: simulate server-1 machine selection, run `task install`, observe only shell + security tasks execute | ❌ W0 (manual UAT) | ⬜ pending |
| {06-NN-NN} | NN | 2 | OSCF-05 | — | `task macos:validate` sources every enabled concern script and calls each `verify_<concern>` | integration | HUMAN-UAT: run on personal-laptop (5 concerns) — full check/cross output for all 5 + shell-registration; run on server-1 (only `macos-security` enabled) — check/cross output for security + shell-registration only | ❌ W0 (manual UAT) | ⬜ pending |
| {06-NN-NN} | NN | 2 | OSCF-05 | — | `task macos:validate` exits non-zero on any key mismatch | unit | Deliberately bork a defaults value (`defaults write com.apple.dock orientation -string "left"`), run `task macos:validate`, assert exit ≠ 0, then restore via `apply_dock` | ❌ W0 | ⬜ pending |
| {06-NN-NN} | NN | 1 | (regression) | — | `task lint` passes LINT-01..09 against the new `taskfiles/macos.yml` | static | `task lint` exits 0 (LINT-05 warnings on `defaults`/`dscl` are expected and warn-only) | ✅ existing | ⬜ pending |
| {06-NN-NN} | NN | 1 | (regression) | T-06-BUG145 | `task macos:shell` is idempotent — zero re-runs on a converged machine | manual UAT (LINT-08 deprecated per P2 D-11) | HUMAN-UAT: time `task install`; second run prints no `[INFO]` lines from `macos:*` | ✅ existing | ⬜ pending |
| {06-NN-NN} | NN | 1 | (regression) | T-06-BUG145 | `grep '\$BREW_ZSH' taskfiles/macos.yml` finds nothing in `status:` lines (LINT-02 contract) | static | `task lint:taskfile` exits 0 | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

The phase has no pre-existing automated test infrastructure for OS defaults — every verification is a shell-level invocation against either the new scripts, the new taskfile, or the resolver's `resolved.json`. Wave 0 ships every artifact the verification surface needs:

- [ ] `taskfiles/macos.yml` — Wave 0 deliverable; the regression-test surface for OSCF-01..05 (replaces `macos-stub.yml`)
- [ ] `os/defaults/dock.zsh` — concern script; `apply_dock` + `verify_dock` + `DOCK_DEFAULTS` tuples
- [ ] `os/defaults/finder.zsh` — concern script; same shape (Finder concerns)
- [ ] `os/defaults/input.zsh` — concern script (planner picks: Option A starter / Option B empty stub)
- [ ] `os/defaults/screenshots.zsh` — concern script (planner picks: Option A starter / Option B empty stub)
- [ ] `os/defaults/security.zsh` — concern script; includes `SECURITY_DEFAULTS` (global) + `SECURITY_DEFAULTS_CURRENTHOST` arrays; `sysadminctl -guestAccount off` apply path with sudo
- [ ] `os/shell-registration.zsh` — `apply_shell_registration` + `verify_shell_registration`; uses `${BREW_ZSH}` shell var (set from `{{.BREW_ZSH}}` task template)
- [ ] `manifests/defaults.toml` `[features]` — 4 new kebab-case keys (`macos-dock`, `macos-input`, `macos-screenshots`, `macos-security`)
- [ ] `manifests/machines/server-1.toml` + `server-2.toml` — `macos-security = true`
- [ ] `os/README.md` — sibling-README pattern (mirrors `shell/README.md`, `packages/README.md`)
- [ ] `Taskfile.yml` root — `includes.macos:` flips from `./taskfiles/macos-stub.yml` to `./taskfiles/macos.yml`
- [ ] `06-HUMAN-UAT.md` — manual UAT plan (planner creates) covering server-mode install, laptop-mode install, re-run idempotency, bug-class regression (`\$BREW_ZSH`), deliberate-mismatch + `task macos:validate` exits non-zero

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `killall Dock` / `killall Finder` / `killall SystemUIServer` side-effects do not regress the user's running UI session past acceptable | OSCF-03 | macOS-side-effect; can't be asserted from script alone | Run `task macos:defaults:dock` on a fresh machine, observe Dock relaunch; on a converged machine, observe NO relaunch (the status block gated the re-run) |
| Server-mode install: server-1.toml machine with only `macos-security = true` runs only `macos:shell` + `macos:defaults:security` | OSCF-04 / SC#4 | Requires switching `$XDG_STATE_HOME/dotfiles/machine` to a server name; not a single shell assertion | `task setup -- server-1 && task install` — observe `macos:defaults:dock`/`:finder`/`:input`/`:screenshots` print "task is up to date" (status gate); only `macos:shell` + `macos:defaults:security` print apply output |
| `sysadminctl -guestAccount off` sudo prompt on a fresh server | OSCF-04 (security.zsh) | Sudo prompt is an interactive flow; idempotent thereafter | First install on a fresh server triggers the prompt; second install is silent (verify returns 0 immediately) |
| `chsh -s` reflects in `dscl . -read /Users/$USER UserShell` immediately (no logout required for verify path) | OSCF-04 (shell-registration) | macOS DirectoryServices behavior; not a shell-script-internal assertion | After `chsh -s`, re-run `task macos:shell` — status block should pass (no re-apply) |
| Round-trip idempotency: `task macos:defaults` on a converged machine performs zero `defaults write` operations | OSCF-03 / SC#2 | Requires observing process behavior across two invocations | Manual: `time task macos:defaults` twice; second run completes in <1s with all sub-tasks reporting "up to date" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify command or a Wave 0 dependency referenced in this map
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify command (planner enforces)
- [ ] Wave 0 covers all MISSING references in the Per-Task Verification Map
- [ ] No watch-mode flags (go-task tasks run-to-completion; no `--watch` in any P6 task)
- [ ] Feedback latency < 15 s per-commit; < 60 s per-wave
- [ ] `nyquist_compliant: true` set in frontmatter after the planner fills in Task IDs and the executor flips ⬜ pending → ✅ green

**Approval:** pending
