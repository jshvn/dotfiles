# Phase 2: Install Engine — Bootstrap, Idempotency, Lint - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 02-install-engine-bootstrap-idempotency-lint
**Areas discussed:** Bootstrap trust chain, Parallel-rewrite collision, install ≡ update unification, Lint architecture + CI

---

## Bootstrap trust chain

### Q1: On a fresh Mac with no Homebrew installed, what should `./bootstrap.zsh` do?

| Option | Description | Selected |
|--------|-------------|----------|
| Treat brew as prereq | Fail fast with clear error if `command -v brew` is missing. SECURITY.md documents brew as the trust anchor. | |
| Auto-install brew (verified curl-bash) | Bootstrap downloads brew install script, verifies SHA-256 against pinned hash, then executes. Manual pin maintenance. | |
| Auto-install brew (best-effort) | Same `/bin/bash -c "$(curl -fsSL ...)"` invocation that brew.sh recommends, with audit line in stderr. No checksum pin. | ✓ |
| Bundled brew installer | Vendor brew's install.sh into repo at pinned commit. Removes runtime network dependency for brew install step. | |

**User's choice:** Auto-install brew (best-effort)
**Notes:** Pragmatic; accepts the same supply-chain trust boundary the wider macOS dev ecosystem accepts. Documented in SECURITY.md as a known trust boundary.

### Q2: When and where does bootstrap install yq + go-task?

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in bootstrap.zsh | Bootstrap installs brew (if missing), then `brew install go-task yq` directly in bootstrap.zsh BEFORE any `task` command. | ✓ |
| Defer to a `task bootstrap:tools` task | Bootstrap installs brew + go-task only; `task install` has a `task bootstrap:tools` step that installs yq before manifest:resolve. | |
| Brewfile-driven (`packages/bootstrap.rb`) | Tiny purpose-bundle lists go-task, yq, etc. Bootstrap installs brew, then `brew bundle --file=packages/bootstrap.rb`. | |

**User's choice:** Inline in bootstrap.zsh
**Notes:** Bootstrap is the explicit trust-anchor sequence: ensure_brew → brew install go-task yq. Everything after is go-task driven. Cannot bootstrap a system that needs yq using a tool that needs yq.

### Q3: How should `bootstrap.zsh` interact with `task setup`?

| Option | Description | Selected |
|--------|-------------|----------|
| Required positional arg | `./bootstrap.zsh personal-laptop` — machine name is required, validated, then bootstrap runs `task setup -- $1` then `task install`. | |
| Optional arg, prompt if missing | If `$1` set, validate and use it. If empty AND interactive, prompt. Empty AND non-interactive = fail. | |
| Bootstrap installs tools only; user runs setup separately | Bootstrap only installs brew + go-task + yq. Then prints next-step hint. | ✓ |

**User's choice:** Bootstrap installs tools only; user runs setup separately
**Notes:** Bootstrap does ONE thing: acquire trust anchors. Two-step user flow keeps bootstrap minimal and predictable.

### Q4: What scope should `docs/SECURITY.md` cover in Phase 2?

| Option | Description | Selected |
|--------|-------------|----------|
| Bootstrap trust chain only | Tight scope per DOCS-07 wording. ~1-2 pages. SSH-key handling and hooks defer to phases that own them. | ✓ |
| Bootstrap + SSH key handling | Adds SSH-key-storage policy so security policy has a single home from day one. P4 references SECURITY.md. | |
| Full security policy from day one | Bootstrap + SSH + Claude hooks + repo-level secrets policy. One canonical doc that grows lightly each phase. | |

**User's choice:** Bootstrap trust chain only
**Notes:** Tight scope per DOCS-07 wording. SSH defers to P4, hooks defer to P7.

---

## Parallel-rewrite collision

### Q1: Where do new v2 root-level files live during phases 2-7 while v1 stays operational?

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel files at root | v1 keeps `bootstrap.zsh`, `Taskfile.yml`. v2 lands as `bootstrap2.zsh`, `Taskfile2.yml`. At P8 cutover: rename v2 → primary names. | |
| Move v1 to a sub-directory | Move v1 root files to `.v1/`. Update v1 entry points to delegate. v2 takes primary names from day one. | |
| Overwrite v1 in place | Treat v2 as authoritative from P2 onward. v1 breaks for any not-yet-migrated phase. Riskiest day-to-day. | |
| Branch-only isolation | Stay on `josh/dotfiles-v2-refactor` branch; v1 at primary names is inherited from `master`. Each new file lands at its final v2 path. | ✓ |

**User's choice:** Branch-only isolation
**Notes:** v2 lives on the branch; v1 stays at primary names on master. Each new file lands at its final v2 path. Implies the branch is NOT installable on a working machine until per-machine cutover (Phase 8).

### Q2: Do we want a guardrail to prevent accidental v2-branch installs on not-yet-cutover machines?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, cutover gate in bootstrap | bootstrap.zsh and task install check `$XDG_STATE_HOME/dotfiles/cutover-ack` sentinel. Missing/stale = fail with clear next-step message. | ✓ |
| Yes, but as a pre-commit / pre-push hook | Repo-level hook prevents pushing v2-branch installs accidentally. Doesn't help if someone clones the branch and runs bootstrap. | |
| No guardrail — discipline only | Document in README + CLAUDE.md: 'do not run task install from this branch on a working machine.' Trust the workflow. | |

**User's choice:** Yes, cutover gate in bootstrap
**Notes:** Cheap, explicit, prevents the foot-gun. The sentinel is part of the per-machine cutover register Phase 8 owns; P2 just enforces it.

### Q3: Where does the cutover sentinel live, and how does the gate check it?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-machine state file | `$XDG_STATE_HOME/dotfiles/cutover-ack` (one-line: machine name + ISO timestamp). Lives in machine-local state alongside `machine` and `resolved.json`. | ✓ |
| Sentinel committed to repo (per-machine) | `docs/cutover-acks/<machine>.md` is committed when each machine cuts over. Visible in git history. | |
| Branch-detection only (no sentinel) | Gate detects current branch via `git rev-parse`. If branch matches v2 pattern, refuses install unless `CUTOVER_OVERRIDE=1`. | |

**User's choice:** Per-machine state file
**Notes:** Matches the P1 state-surface convention.

### Q4: Cutover gate scope — which `task` commands does it block?

| Option | Description | Selected |
|--------|-------------|----------|
| Only destructive ops | Gate blocks task install/update, links, brew install, macos defaults, claude install. Read-only/test commands work without sentinel. | ✓ |
| All `task install`-derived commands | Gate blocks anything reachable from `task install`'s task graph. Read-only/test commands always work. | |
| Bootstrap entrypoint only | Gate lives only in `./bootstrap.zsh`. `task install` itself is unguarded. | |

**User's choice:** Only destructive ops
**Notes:** Lets dev iteration run unblocked.

---

## install ≡ update unification

### Q1: How does `task update` resolve to the same body as `task install`?

| Option | Description | Selected |
|--------|-------------|----------|
| Drop `task update` entirely | Remove `task update` from v2 Taskfile.yml. Add zsh function alias `update='task install'` in `shell/aliases/` (Phase 3). | ✓ |
| `task update` is a literal alias | Keep `task update` for muscle memory but make it a one-liner: `tasks: update: { cmds: [task: install] }`. Verify byte-identity by `diff`. | |
| Aliases via `aliases:` keyword | go-task v3.37+ supports `aliases:` as first-class field. `tasks: install: { aliases: [update], cmds: [...] }`. | |

**User's choice:** Drop `task update` entirely
**Notes:** Simplest — no second task to drift, satisfies SC#2 trivially because there's nothing to compare. Shell alias lands in Phase 3.

### Q2: SC#6 wants 'task install fast on re-run' but the 5s number is shaky. What's the actual contract?

| Option | Description | Selected |
|--------|-------------|----------|
| Drop the seconds metric, assert no-op behavior | Replace 'under 5 seconds' with structural assertion: `task install` re-run performs ZERO mutating operations. Test via filesystem snapshot. | |
| Keep timing but raise the budget + scope it | Re-run budget is `< 30s`, measured locally only. Documented as 'rule-of-thumb' not hard CI gate. | |
| Drop SC#6 entirely | Remove the timing claim from the roadmap. LINT-01 already structurally guarantees re-runs are no-ops. | ✓ |
| Keep as-is, document caveats in PLAN | Keep SC#6's wording; PLAN documents that 'converged' specifically means second-run-after-first-success. | |

**User's choice:** Drop SC#6 entirely
**Notes:** User pushback (verbatim): "task install will take a long time when installing brew packages because they must be installed over the internet. it could take hours on a slow connection. the timing mechanism doesnt make sense." LINT-01 covers structural idempotency; speed is a consequence. ROADMAP edit captured in deferred items.

---

## Lint architecture + CI

### Q1: Where does the lint suite's logic live?

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone zsh scripts under `install/lint/` | One script per check; taskfiles/lint.yml is a thin dispatcher. Each script testable in isolation. | |
| All inline in `taskfiles/lint.yml` | Each lint check is a `cmds:` block (grep one-liners, find pipelines) directly in lint.yml. Simpler file count. | ✓ |
| Hybrid — simple in YAML, complex in scripts | Trivial one-liner checks in lint.yml; multi-line in install/lint/*.zsh. Pragmatic split. | |

**User's choice:** All inline in `taskfiles/lint.yml`
**Notes:** Single-file readability, fewer files to track. Tradeoff: lint.yml will be one of the larger taskfiles.

### Q2: Lint severity model — which checks block (exit non-zero) vs warn (exit 0 with stderr)?

| Option | Description | Selected |
|--------|-------------|----------|
| Roadmap-aligned | Block: LINT-02/03/04/07. Warn-only: LINT-05 (portability). Matches ROADMAP SC#3 and SC#4. | ✓ |
| Roadmap-aligned + --strict mode | Same defaults as option 1, but `task lint -- --strict` escalates LINT-05 warnings to errors. Useful for v2 cross-platform work. | |
| Conservative — all warn first, block in P3+ | P2 ships everything as warn-only; later phases escalate each check to blocking once the corresponding code area is clean. | |

**User's choice:** Roadmap-aligned
**Notes:** No surprises, exactly matches roadmap wording.

### Q3: Where does `task lint` run automatically?

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Actions on push/PR | Add `.github/workflows/lint.yml` that runs `task lint` on every push and PR. macos-latest runner. | |
| Pre-commit hook (local only) | Install git pre-commit hook that runs `task lint --staged` before each commit. Bypassable with `--no-verify`. | |
| Both — pre-commit + CI | Pre-commit hook for fast local feedback + GitHub Actions for authoritative gate. Defense in depth. | |
| Manual only | Run `task lint` by hand or before commits. No automation in P2. | ✓ |

**User's choice:** Manual only
**Notes:** No CI infrastructure in P2. Lint exists; you run it when you remember to. ROADMAP SC#5 wording 'in CI' needs revising (captured in deferred items).

### Q4: What's the scope of LINT-07 (`zsh -n`) and LINT-04 (`set -euo pipefail`)?

| Option | Description | Selected |
|--------|-------------|----------|
| Every .zsh file under the repo | `find . -name '*.zsh' -not -path './.git/*'` for both checks. LINT-04 further filters to executable files. | ✓ |
| Phase-owned dirs only | Each phase's lint targets only the dirs it owns. Avoids accidentally lint-ing v1 files still around. | |
| Allowlist of dirs in lint config | `install/lint/config.zsh` lists the dirs in scope. Most explicit; risks the list going stale. | |

**User's choice:** Every .zsh file under the repo
**Notes:** Simplest scope, no per-dir bookkeeping. Sourced-only files like `shell/aliases/*.zsh` are exempt from LINT-04 by virtue of not being executable.

---

## Claude's Discretion

These items were explicitly left for the planner to decide based on implementation context:

- **`task install` body composition** — exact list of subtasks `task install` calls (planner stubs them as no-op tasks pointing to owning phases P3-P7)
- **Audit-line format in stderr** — D-01 sketch can be refined (timestamp, abort delay)
- **Lint output format** — one-line-per-error vs grouped-by-check report
- **Bare-`ln` exception list** — `taskfiles/helpers.yml` is the only initial allowlisted location; planner can extend if a second helper legitimately needs bare `ln`
- **`zsh -n` invocation strategy** — sequential vs parallel (`xargs -P 4`)
- **Bootstrap pre-flight checks** — optional polish: macOS version check, Xcode CLT detection, arch detection logging

---

## Deferred Ideas

### REQUIRED ROADMAP EDITS (planner action items)
- Remove Phase 2 SC#6 (5s timing test). LINT-01 covers structural idempotency.
- Revise Phase 2 SC#5: drop "in CI" qualifier. The lint suite runs manually only.
- Revise Phase 2 SC#1: bootstrap installs *brew* via brew.sh's installer, then `brew install go-task yq`.
- Add a new Phase 2 success criterion for the cutover-ack gate.

### Owned by other phases (do not pull into P2)
- `task cutover:ack` implementation — Phase 8 (CUTV-03)
- `docs/CUTOVER.md` content — Phase 8
- `task validate` composition — Phase 8 (CUTV-01)
- `task test` aggregator + hook smoke tests — Phase 7 (TEST-01, TEST-02)
- v1 modifications during P2-P7 — none expected; v1 lives untouched on master

### v2 branch merge-to-master timing
- Open question: when does `josh/dotfiles-v2-refactor` merge back to master? The cutover-ack gate's existence presumes the answer is "may be merged before all machines are cut over; gate prevents accidental installs."

### Future hardening (out of v1 scope)
- Pinned-checksum brew installer
- Bundled brew installer (vendoring install.sh)
- shellcheck integration (would catch `local`-at-script-scope, which `zsh -n` doesn't)
- `--strict` mode for lint that escalates LINT-05 warnings to errors
- GitHub Actions CI
- Pre-commit hook for `task lint`
