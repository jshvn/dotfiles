# Phase 2: Install Engine — Bootstrap, Idempotency, Lint - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the hardened install engine that every later phase relies on:
- A `bootstrap.zsh` that acquires the trust anchors (Homebrew, go-task, yq) on a fresh macOS machine, with documented trust boundaries
- An enforced idempotency contract — `task install` re-run is structurally a no-op (every task has a working `status:` block)
- `task install` as the single canonical entry — `task update` removed
- A lint suite that catches the v1 bug classes before any later phase ports content (the `$VAR-in-status:` bug, the bare-`ln -s` bug, the missing-`set -euo pipefail` bug, the `local`-at-script-scope bug)
- A `task cutover:ack` gate enforced in `bootstrap.zsh` and `task install` — protects working machines from accidental v2-branch installs while v1 is still operational on `master`
- `docs/SECURITY.md` documenting the bootstrap trust chain

**In scope:**
- `bootstrap.zsh` rewrite (`set -euo pipefail`, best-effort brew install with audit logging, inline `brew install go-task yq`, prints next-step hint, NO `task setup` invocation)
- Cutover-acknowledgement gate (read `$XDG_STATE_HOME/dotfiles/cutover-ack`; refuse destructive ops without a valid sentinel)
- `taskfiles/lint.yml` — all checks inlined as `cmds:` blocks under task names per LINT requirement (LINT-02 through LINT-07)
- `task install` body — composed from later-phase tasks (links, brew, claude, macos) but those bodies are stubs in P2; P2 establishes the call graph and idempotency contract
- Removal of `task update` from v2 Taskfile.yml (canonical entry: `task install` only)
- `docs/SECURITY.md` — bootstrap trust chain only (SSH defers to P4, hooks defer to P7)

**Out of scope (deferred to later phases):**
- Shell content (Phase 3)
- Git/SSH identity tasks (Phase 4)
- Brewfile composition / package verification (Phase 5)
- macOS defaults tasks (Phase 6)
- Claude install / hook smoke tests / tool config helpers (Phase 7)
- `task validate` composition / `task links:reconcile` / `docs/CUTOVER.md` (Phase 8)
- The `task cutover:ack` task that *writes* the sentinel — owned by Phase 8 (CUTV-03). P2 only enforces the gate.

**Required ROADMAP edits (planner action items):**
- Remove Phase 2 SC#6 (5s timing test) — LINT-01's structural `status:` requirement is the actual idempotency guarantee. Speed is a consequence, not a measured contract.
- Revise Phase 2 SC#5 — drop "in CI" qualifier. The lint suite runs manually (`task lint`); no CI infrastructure is added in P2.

**Requirements addressed:** BTSP-01, BTSP-02, BTSP-03, BTSP-04, BTSP-05, BTSP-06, LINT-01, LINT-02, LINT-03, LINT-04, LINT-05, LINT-06, LINT-07, LINT-08 (deprecated — see SC#6 removal note), DOCS-07

</domain>

<decisions>
## Implementation Decisions

### Bootstrap Trust Chain

- **D-01: Best-effort brew auto-install with audit logging.** When `command -v brew` fails, `bootstrap.zsh` runs the brew installer via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`. Stderr emits an explicit audit line before the call (`AUDIT: about to fetch and execute brew install script from raw.githubusercontent.com/Homebrew/install`). No checksum pin. Trade-off: accepts the same supply-chain trust boundary the wider macOS dev ecosystem accepts; the alternative (pinned checksum) creates manual maintenance work for marginal security gain. Documented in `docs/SECURITY.md` as a known trust boundary.
- **D-02: Bootstrap is the explicit trust-anchor sequence.** After ensuring brew, `bootstrap.zsh` directly runs `brew install go-task yq` — NOT delegated to a `task bootstrap:tools` task. Rationale: `task install` itself depends on `manifest:resolve` which depends on `yq`; we cannot bootstrap a system that needs `yq` using a tool that needs `yq`. Bootstrap is the pre-`task` sequence; everything after is go-task driven.
- **D-03: Bootstrap is tools-only.** `./bootstrap.zsh` does NOT take a machine name and does NOT invoke `task setup`. After installing brew + go-task + yq, it prints (to stdout):
  ```
  Bootstrap complete. Next steps:
    task setup -- <machine-name>     # write machine state
    task install                     # install dotfiles
  Available machines: personal-laptop, work-laptop, server-1, server-2
  ```
  Two-step user flow keeps the bootstrap script minimal (one job: acquire trust anchors) and avoids requiring bootstrap to know about manifest internals.
- **D-04: `set -euo pipefail` on bootstrap.zsh** (BTSP-01). Replaces v1's `set -e` (the silently-ignored-unbound-vars bug class).
- **D-05: Bootstrap is resumable (BTSP-03).** Each step has a guard:
  - brew install: `command -v brew >/dev/null && skip`
  - go-task install: `command -v task >/dev/null && skip`
  - yq install: `command -v yq >/dev/null && skip` (also asserts version >= 4.52.1 via `yq --version` regex)

### Parallel-Rewrite Collision

- **D-06: Branch-only isolation.** v2 lives on `josh/dotfiles-v2-refactor`; v1 stays at primary names on `master`. Each new file in P2+ lands at its final v2 path (e.g., P2 will overwrite root `bootstrap.zsh` and `Taskfile.yml`). The branch is NOT installable on a working machine until per-machine cutover (Phase 8). v1 stays byte-stable on `master`.
- **D-07: Cutover-ack gate is enforced in P2.** `bootstrap.zsh` and `task install` (and other destructive tasks) check `$XDG_STATE_HOME/dotfiles/cutover-ack`. Missing or stale sentinel produces:
  ```
  error: machine 'personal-laptop' is not cut over to v2.

  This branch is v2-only. v1 lives on master.
  To cut this machine over, run:
    task cutover:ack -- personal-laptop

  See docs/CUTOVER.md for the full procedure.
  ```
  Exits 1. The `task cutover:ack` task that *writes* the sentinel is owned by Phase 8 (CUTV-03); P2 only enforces the gate.
- **D-08: Cutover sentinel format.** `$XDG_STATE_HOME/dotfiles/cutover-ack` — single line: `<machine-name> <ISO-8601-UTC-timestamp>`. Gate validates by reading the line, splitting on whitespace, and asserting the machine name matches `$(cat $XDG_STATE_HOME/dotfiles/machine)`. Lives in machine-local state alongside `machine` and `resolved.json` — matches the P1 state-surface convention.
- **D-09: Cutover gate scope — destructive ops only.** The gate blocks: `task install`, `task update` (if it ever returns), `task links:*` (when those land in P7), `task brew:install` (P5), `task claude:install` (P7), `task macos:defaults` (P6). The gate does NOT block: `task lint`, `task manifest:test`, `task manifest:show`, `task manifest:validate`, `task validate` (P8), `task test` (P7). Read-only and test commands work without the sentinel — keeps dev iteration on the v2 branch unblocked.

### install ≡ update Unification

- **D-10: Drop `task update` from v2 Taskfile.yml.** No `tasks: update:` block. `task install` is documented as the single canonical entry — `task install` IS `task update`. Trivially satisfies SC#2 because there is nothing to compare. The shell alias `update='task install'` (preserving v1 muscle memory) lands in Phase 3 with the `shell/aliases/` port.
- **D-11: SC#6 (5s timing test) is removed.** LINT-01's structural `status:` block requirement already guarantees idempotent re-runs are no-ops. Speed is a consequence of correctness, not a measured contract. ROADMAP edit captured in deferred items.

### Lint Architecture & Severity

- **D-12: All lint logic inlined in `taskfiles/lint.yml`.** No separate scripts under `install/lint/`. Each check is a `cmds:` block (grep/find/awk pipelines) under a sub-task name (`task lint:taskfile`, `task lint:headers`, `task lint:syntax`, `task lint:portability`). `task lint` (default) runs all sub-tasks. Trade-off: lint.yml will be one of the larger files; gain is single-file readability and fewer files to track.
- **D-13: Severity model — roadmap-aligned.** Blocking (exit non-zero on detection): LINT-02 (`$VAR` in `status:` blocks), LINT-03a (`cmds:` without `status:`), LINT-03b (bare `ln -s` outside `taskfiles/helpers.yml`), LINT-04 (executable `.zsh` missing `set -euo pipefail`), LINT-07 (`zsh -n` parse errors). Warn-only (stderr message, exit 0): LINT-05 (portability hints — `pbcopy`, `osascript`, `defaults` in flat `shell/`/`os/` dirs).
- **D-14: Lint scope — every `.zsh` under repo.** `find . -name '*.zsh' -not -path './.git/*'` is the file selector. LINT-04 (`set -euo pipefail`) further filters to executable files (`-perm +111`); sourced-only files like `shell/aliases/*.zsh` are exempt. Simplest scope, no per-dir bookkeeping.
- **D-15: No CI.** `task lint` runs manually. No `.github/workflows/lint.yml` is added in P2. ROADMAP SC#5 wording "in CI" is removed (see deferred items).

### Claude's Discretion

- **`task install` body composition** — The exact list of subtasks `task install` calls (e.g., `task: links:all`, `task: brew:install`, `task: claude:install`, `task: macos:defaults`) is a planner concern. P2 only needs to establish the call graph and the idempotency contract; the actual subtask bodies are owned by their respective phases (P3-P7). Planner can stub them as no-op tasks with a `desc:` comment pointing to the owning phase.
- **Audit-line format in stderr** — D-01's "AUDIT: about to fetch and execute brew install script" is a sketch; planner may refine wording, add timestamp, or add a 5-second pause for user to ctrl-C.
- **Lint output format** — Planner picks one-line-per-error vs grouped-by-check report. Use `install/messages.zsh` `error()` / `warn()` / `check` / `cross` for consistency with v1 messaging style.
- **Bare-`ln` exception list** — D-13 names `taskfiles/helpers.yml` as the only allowed location for bare `ln`. If a second helper file legitimately needs bare `ln`, planner can extend the allowlist (e.g., `install/resolver.zsh` is exempt by virtue of being non-taskfile).
- **`zsh -n` invocation strategy** — `find ... | xargs zsh -n {}` is straightforward; alternative is a parallel run (`xargs -P 4`) for speed. Planner picks based on actual file count.
- **Bootstrap pre-flight checks** — planner may add: macOS version check (`sw_vers`), Xcode CLT detection (`xcode-select -p`), arch detection (`uname -m` writes to a debug log). All optional polish on top of D-01..D-05.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints (parallel rewrite, no curl|sh, no AI attribution), key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements list (BTSP-01..06, LINT-01..08, DOCS-07 in scope for P2)
- `.planning/ROADMAP.md` Phase 2 section — Goal, success criteria (note: SC#5 and SC#6 require edits per D-11 and D-15), requirement mapping
- `.planning/STATE.md` — Pre-Phase blockers (yq sequencing on Linux deferred to v2)

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md` — Phase 1 decisions binding on P2:
  - D-14 (auto-rebuild via task precondition) — every downstream task declares `deps: [manifest:resolve]`
  - D-16 (missing-state hard-fail with actionable error) — pattern P2 should reuse for the cutover-ack gate
  - The `_:safe-link` / `_:check-link` helpers pattern (lives in `taskfiles/helpers.yml`)

### Domain Research (already on disk)
- `.planning/research/SUMMARY.md` — Synthesized research findings
- `.planning/research/STACK.md` — Tool versions (yq v4.53+, go-task v3.50+)
- `.planning/research/PITFALLS.md` — Pitfalls relevant to P2: idempotency drift class (`macos:shell` `$VAR` bug), supply-chain risk

### Existing Codebase (v1 patterns — port what works, fix what doesn't)
- `.planning/codebase/CONCERNS.md` — Live v1 bugs that LINT must catch:
  - `taskfiles/macos.yml:145` (`$BREW_ZSH` instead of `{{.BREW_ZSH}}`) → LINT-02 must catch this
  - `bootstrap.zsh:2` (`set -e` instead of `set -euo pipefail`) → LINT-04 must catch executable-script equivalent
  - `bootstrap.zsh:33` (curl|sh) → P2 rewrite + SECURITY.md document
  - `taskfiles/links.yml:66-70` (raw `ln -sf` outside helpers) → LINT-03b must catch
  - `taskfiles/claude.yml:211-219` (gsd-install no `status:`) → LINT-03a must catch
  - `claude/hooks/agent-transparency.zsh` (`local` at script scope) → LINT-07 (`zsh -n` doesn't catch this; future shellcheck integration would; not in P2 scope)
- `.planning/codebase/CONVENTIONS.md` — v1 naming/scripting conventions (zsh `set -euo pipefail`, kebab-case files, no AI attribution)
- `.planning/codebase/INTEGRATIONS.md` — External integrations P2 must NOT break for v1 users on master

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — v2 conventions for AI-assisted maintenance
- `.claude/CLAUDE.md` — Project-level Claude instructions
- `~/.config/claude/CLAUDE.md` — Global conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (v1 patterns to port — keep what works)
- **`install/messages.zsh`** — colored output library (info/success/warn/error/check/cross). Keep its `DOTFILES_MESSAGES_LOADED` guard pattern. v2 lint and bootstrap both source it for consistent output. Phase 1 already preserved this.
- **Root `Taskfile.yml` `vars:` block pattern** — global vars (`HOMEBREW_PREFIX`, `XDG_*`, `DOTFILES_MESSAGES`) — v2 reuses the pattern with manifest values injected via `fromJson` (Phase 1's `MANIFEST_JSON` / `MANIFEST` vars).
- **`taskfiles/helpers.yml` `_:safe-link`** — the *only* sanctioned symlink location. LINT-03b enforces this by allowlisting `taskfiles/helpers.yml` as the sole permitted file containing bare `ln -s`. Phase 7 hardens the helper itself; P2 just enforces the rule.

### Established Patterns (binding on P2)
- **Idempotency via `status:`** — every install task in v1 already does this (with bugs LINT-02 catches). v2 P2 enforces structurally via lint.
- **`set -euo pipefail`** — every executable `.zsh` (LINT-04 enforces). Bootstrap rewrite must do this (BTSP-01).
- **No hardcoded `/opt/homebrew` or `/usr/local`** — detect via `uname -m` and `$HOMEBREW_PREFIX`. Bootstrap must follow this when running `brew install`.
- **`$XDG_STATE_HOME/dotfiles/` is the machine-local state surface** — P1 owns `machine` and `resolved.json`; P2 adds `cutover-ack`. Same dir, same convention (single-line text files), no nesting.

### Integration Points
- **Bootstrap → `task setup` → `task install` flow** — bootstrap exits cleanly leaving go-task + yq installed; user runs `task setup -- <name>` (P1) which writes `$XDG_STATE_HOME/dotfiles/machine` and triggers `manifest:resolve`; then user runs `task install` which P2 owns the entry of (and which delegates to subtasks owned by P3-P7).
- **Cutover-ack gate is checked at `bootstrap.zsh` AND inside `task install`** — defense in depth: even if user invokes `task install` directly (skipping bootstrap), the gate fires.
- **Lint reads from disk only** — no manifest dependency, no `resolved.json` dependency. `task lint` runs without ever invoking `manifest:resolve`. Cleanly composable for the dev iteration loop on the v2 branch.

</code_context>

<specifics>
## Specific Ideas

- **Bootstrap audit-line format** (D-01 sketch):
  ```
  AUDIT: about to fetch and execute brew install script
    source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    trust:  HTTPS only, no checksum pin
    ctrl-C now to abort
  ```
  Optional 3-second sleep after the audit line gives a real abort window without being annoying.

- **Cutover-ack sentinel format** (D-08): single line
  ```
  personal-laptop 2026-05-15T10:23:00Z
  ```

- **Cutover-ack gate error** (D-07):
  ```
  error: machine 'personal-laptop' is not cut over to v2.

  This branch is v2-only. v1 lives on master.
  To cut this machine over, run:
    task cutover:ack -- personal-laptop

  See docs/CUTOVER.md for the full procedure.
  ```

- **LINT-02 grep pattern** (catches the `macos:shell:145` bug class):
  ```bash
  # In every taskfile, find any status: block, then check inside it for $VAR (not {{.VAR}})
  yq eval '.. | select(has("status")) | .status[]' taskfiles/*.yml \
    | grep -nE '\$[A-Z_]+\b' \
    | grep -v '{{\.' && exit 1
  ```
  (Sketch — planner verifies exact yq + grep syntax.)

- **LINT-03b allowlist:**
  ```bash
  # bare ln -s outside taskfiles/helpers.yml is a violation
  grep -rn 'ln -s' taskfiles/ \
    | grep -v 'helpers.yml' \
    | grep -v ':_:safe-link' && exit 1
  ```

- **LINT-04 executable-script check:**
  ```bash
  find . -name '*.zsh' -perm +111 -not -path './.git/*' \
    | while read f; do
        head -3 "$f" | grep -q 'set -euo pipefail' \
          || { error "missing set -euo pipefail: $f"; exit 1; }
      done
  ```

- **Reference SECURITY.md outline:**
  1. What `bootstrap.zsh` downloads (brew install script, then formula tarballs via `brew install go-task yq`)
  2. From where (raw.githubusercontent.com/Homebrew, then Homebrew's CDN)
  3. How verified (HTTPS only for brew install script — KNOWN gap; brew formula bottles are SHA256-signed by Homebrew)
  4. Trust anchors (brew.sh TLS, GitHub mirror, Homebrew's signing infrastructure)
  5. Threat model (CDN compromise → arbitrary code execution; mitigation accepted as cost of pragmatic install)
  6. What is NOT done (no checksum pin on the brew install script; no verification of formula provenance beyond what brew already does)

</specifics>

<deferred>
## Deferred Ideas

### REQUIRED ROADMAP EDITS (planner action items)
- Remove Phase 2 SC#6 (5s timing test) from `.planning/ROADMAP.md`. LINT-01's structural `status:` requirement is the actual idempotency guarantee.
- Revise Phase 2 SC#5: drop the "in CI" qualifier. The lint suite runs manually only.
- Revise Phase 2 SC#1: `./bootstrap.zsh` clarification — bootstrap installs *brew* via brew.sh's installer (not "via Homebrew" since brew is what gets installed). Then `brew install go-task yq`.
- Add a new Phase 2 success criterion for the cutover-ack gate: `bootstrap.zsh` and `task install` both fail with an actionable error message when `$XDG_STATE_HOME/dotfiles/cutover-ack` is missing or its machine name doesn't match the active machine.

### Owned by other phases (do not pull into P2 scope)
- `task cutover:ack` implementation — the task that *writes* the sentinel. Owned by Phase 8 (CUTV-03). P2 only reads/enforces.
- `docs/CUTOVER.md` content — Phase 8 owns. The cutover-ack gate's error message just references the doc; it doesn't need to exist for P2 to ship.
- `task validate` composition — Phase 8 (CUTV-01).
- `task test` aggregator + hook smoke tests — Phase 7 (TEST-01, TEST-02).
- v1 modifications during P2-P7 — none expected; v1 lives untouched on `master`.

### v2 branch merge-to-master timing
- Open question: when does `josh/dotfiles-v2-refactor` merge back to master? After all four machines cut over (Phase 8), or earlier? Planner does not need to answer this for P2 — but the cutover-ack gate's existence presumes the answer is "the branch may be merged to master while not all machines are cut over, and the gate prevents accidental installs on the not-yet-cut-over machines."

### Future hardening (out of v1 scope)
- Pinned-checksum brew installer (D-01 alternative) — revisit if supply-chain incidents on brew.sh become a concern.
- Bundled brew installer (D-01 alternative) — vendoring `install.sh` at a pinned commit. Same logic — defer until it matters.
- shellcheck integration — would catch `local`-at-script-scope (the `agent-transparency.zsh:11` bug) which `zsh -n` doesn't. Defer to a future hardening phase; v1's hook fix in Phase 7 handles the immediate occurrence.
- `--strict` mode for lint that escalates LINT-05 warnings to errors — useful when Linux returns in v2.
- GitHub Actions CI — defer until regression frequency justifies the cost (manual `task lint` is the v1 contract).
- Pre-commit hook for `task lint` — same reasoning; can be added later via `task lint:install-hook` if useful.

### Reference machine list (carried from P1)
- `personal-laptop`, `work-laptop`, `server-1`, `server-2` — all macOS, mixed roles. Cutover-ack must work for any of these names.

</deferred>

---

*Phase: 02-install-engine-bootstrap-idempotency-lint*
*Context gathered: 2026-05-13*
