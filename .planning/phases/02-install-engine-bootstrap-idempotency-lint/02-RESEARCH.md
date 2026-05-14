# Phase 2: Install Engine — Bootstrap, Idempotency, Lint - Research

**Researched:** 2026-05-13
**Domain:** Hardened bootstrap (brew + go-task + yq trust anchors), enforced idempotency contract, taskfile + shell lint suite, cutover-ack gate, security trust-chain documentation
**Confidence:** HIGH (every lint pattern, every yq query, every brew/task interaction was run live in this session against the actual repo)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Bootstrap Trust Chain:**
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

**Parallel-Rewrite Collision:**
- **D-06: Branch-only isolation.** v2 lives on `josh/dotfiles-v2-refactor`; v1 stays at primary names on `master`. Each new file in P2+ lands at its final v2 path (e.g., P2 will overwrite root `bootstrap.zsh` and `Taskfile.yml`). The branch is NOT installable on a working machine until per-machine cutover (Phase 8). v1 stays byte-stable on `master`.
- **D-07: Cutover-ack gate is enforced in P2.** `bootstrap.zsh` and `task install` (and other destructive tasks) check `$XDG_STATE_HOME/dotfiles/cutover-ack`. Missing or stale sentinel produces an actionable error referencing `task cutover:ack` and `docs/CUTOVER.md`. Exits 1. The `task cutover:ack` task that *writes* the sentinel is owned by Phase 8 (CUTV-03); P2 only enforces the gate.
- **D-08: Cutover sentinel format.** `$XDG_STATE_HOME/dotfiles/cutover-ack` — single line: `<machine-name> <ISO-8601-UTC-timestamp>`. Gate validates by reading the line, splitting on whitespace, and asserting the machine name matches `$(cat $XDG_STATE_HOME/dotfiles/machine)`. Lives in machine-local state alongside `machine` and `resolved.json` — matches the P1 state-surface convention.
- **D-09: Cutover gate scope — destructive ops only.** Blocks: `task install`, `task update` (if it ever returns), `task links:*` (P7), `task brew:install` (P5), `task claude:install` (P7), `task macos:defaults` (P6). Does NOT block: `task lint`, `task manifest:test`, `task manifest:show`, `task manifest:validate`, `task validate` (P8), `task test` (P7).

**install ≡ update Unification:**
- **D-10: Drop `task update` from v2 Taskfile.yml.** No `tasks: update:` block. `task install` is documented as the single canonical entry. Trivially satisfies SC#2 because there is nothing to compare. The shell alias `update='task install'` lands in Phase 3 with the `shell/aliases/` port.
- **D-11: SC#6 (5s timing test) is removed.** LINT-01's structural `status:` block requirement already guarantees idempotent re-runs are no-ops. Speed is a consequence of correctness, not a measured contract. Captured in deferred items as a required ROADMAP edit.

**Lint Architecture & Severity:**
- **D-12: All lint logic inlined in `taskfiles/lint.yml`.** No separate scripts under `install/lint/`. Each check is a `cmds:` block (grep/find/awk/yq pipelines) under a sub-task name (`task lint:taskfile`, `task lint:headers`, `task lint:syntax`, `task lint:portability`). `task lint` (default) runs all sub-tasks.
- **D-13: Severity model — roadmap-aligned.** Blocking (exit non-zero): LINT-02 (`$VAR` in `status:` blocks), LINT-03a (`cmds:` without `status:`), LINT-03b (bare `ln -s` outside `taskfiles/helpers.yml`), LINT-04 (executable `.zsh` missing `set -euo pipefail`), LINT-07 (`zsh -n` parse errors). Warn-only (stderr message, exit 0): LINT-05 (portability hints — `pbcopy`, `osascript`, `defaults` in flat `shell/`/`os/` dirs).
- **D-14: Lint scope — every `.zsh` under repo.** `find . -name '*.zsh' -not -path './.git/*'` is the file selector. LINT-04 (`set -euo pipefail`) further filters to executable files (`-perm +111`); sourced-only files like `shell/aliases/*.zsh` are exempt. Simplest scope, no per-dir bookkeeping.
- **D-15: No CI.** `task lint` runs manually. No `.github/workflows/lint.yml` is added in P2. ROADMAP SC#5 wording "in CI" is removed.

### Claude's Discretion

- **`task install` body composition** — The exact list of subtasks `task install` calls (e.g., `links:all`, `brew:install`, `claude:install`, `macos:defaults`) is a planner concern. P2 only needs to establish the call graph and the idempotency contract; the actual subtask bodies are owned by their respective phases (P3-P7). Planner can stub them as no-op tasks with a `desc:` comment pointing to the owning phase.
- **Audit-line format in stderr** — D-01's "AUDIT:" sketch; planner may refine wording, add timestamp, or add a 5-second pause for user to ctrl-C.
- **Lint output format** — Planner picks one-line-per-error vs grouped-by-check report. Use `install/messages.zsh` `error()` / `warn()` / `check` / `cross` for consistency with v1 messaging style.
- **Bare-`ln` exception list** — D-13 names `taskfiles/helpers.yml` as the only allowed location for bare `ln`. If a second helper file legitimately needs bare `ln`, planner can extend the allowlist (e.g., `install/resolver.zsh` is exempt by virtue of being non-taskfile).
- **`zsh -n` invocation strategy** — `find ... | xargs zsh -n {}` is straightforward; alternative is a parallel run (`xargs -P 4`) for speed. Planner picks based on actual file count.
- **Bootstrap pre-flight checks** — planner may add: macOS version check (`sw_vers`), Xcode CLT detection (`xcode-select -p`), arch detection (`uname -m` writes to a debug log). All optional polish on top of D-01..D-05.

### Deferred Ideas (OUT OF SCOPE)

**REQUIRED ROADMAP edits (planner must surface):**
- Remove Phase 2 SC#6 (5s timing test) from `.planning/ROADMAP.md`. LINT-01's structural `status:` requirement is the actual idempotency guarantee.
- Revise Phase 2 SC#5: drop the "in CI" qualifier. The lint suite runs manually only.
- Revise Phase 2 SC#1: `./bootstrap.zsh` clarification — bootstrap installs *brew* via brew.sh's installer (not "via Homebrew" since brew is what gets installed). Then `brew install go-task yq`.
- Add new Phase 2 success criterion for the cutover-ack gate: `bootstrap.zsh` and `task install` both fail with an actionable error when `$XDG_STATE_HOME/dotfiles/cutover-ack` is missing or its machine name doesn't match the active machine.

**Owned by other phases:**
- `task cutover:ack` implementation — owned by Phase 8 (CUTV-03). P2 only reads/enforces.
- `docs/CUTOVER.md` content — Phase 8 owns. P2's gate references the doc; it doesn't need to exist for P2 to ship.
- `task validate` composition — Phase 8 (CUTV-01).
- `task test` aggregator + hook smoke tests — Phase 7 (TEST-01, TEST-02).

**Future hardening (out of v1 scope):**
- Pinned-checksum brew installer; bundled brew installer (vendoring `install.sh` at a pinned commit).
- shellcheck integration — would catch `local`-at-script-scope (the `agent-transparency.zsh:11` bug class) which `zsh -n` doesn't. Defer to a future hardening phase.
- `--strict` mode for lint that escalates LINT-05 warnings to errors.
- GitHub Actions CI; pre-commit hook for `task lint`.

**Reference machine list (carried from P1):** `personal-laptop`, `work-laptop`, `server-1`, `server-2`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BTSP-01 | `bootstrap.zsh` uses `set -euo pipefail` (not `set -e`) | §3.1 — strict-mode header pattern; carries forward from P1 resolver convention |
| BTSP-02 | Bootstrap installs go-task via Homebrew (no curl-pipe-to-shell) | §3.2 — `brew install go-task yq` after ensuring brew; D-01 trust chain documented |
| BTSP-03 | Bootstrap is resumable | §3.3 — three guard checks (brew/task/yq); §10.6 verifies double-run is no-op |
| BTSP-04 | `task setup -- <machine-name>` persists machine selection | Already implemented in P1 `taskfiles/manifest.yml` — P2 adds NO new task; just references it in bootstrap stdout |
| BTSP-05 | `docs/SECURITY.md` documents bootstrap trust chain | §8 — full SECURITY.md outline (six required sections) |
| BTSP-06 | `task install` is the canonical idempotent entry; `task update` is an alias for the same task | Per D-10 we drop `task update` entirely — vacuously satisfies "no separate update pipeline that could diverge"; §4.1 `task install` body composition; §10.2 verification |
| LINT-01 | Every install task has a `status:` block | §5.4 — LINT-03a check enforces structurally |
| LINT-02 | `task lint:taskfile` flags `$VAR` references inside `status:` blocks | §5.2 — verified yq + ggrep pipeline catches `taskfiles/macos.yml:145` `$BREW_ZSH` bug |
| LINT-03 | `task lint:taskfile` flags bare `ln -s` outside `helpers.yml` and tasks with `cmds:` but no `status:` | §5.3 (bare ln allowlist), §5.4 (cmds-without-status) — both verified against existing v1 violations |
| LINT-04 | `task lint:shell-headers` flags executable `.zsh` missing `set -euo pipefail` | §5.5 — verified detects v1 bootstrap's bare `set -e` |
| LINT-05 | `task lint:portability` warns (non-blocking) on portability-sensitive commands | §5.6 — pbcopy/osascript/defaults in `shell/`/`os/` flat dirs |
| LINT-06 | Root `task lint` aggregates all lint subtasks | §5.7 — orchestration pattern; default lint task delegates to all sub-tasks via `cmds: [task: ...]` |
| LINT-07 | `zsh -n` runs over every `.zsh` file (Tier-0 syntax) | §5.8 — find + xargs zsh -n; verified on existing repo |
| LINT-08 | `task install` re-run on converged machine completes in under 5 seconds | **DEPRECATED per D-11.** SC removed; `task install` idempotency is structurally guaranteed by LINT-01. Planner notes the deprecation in ROADMAP edit list, does not implement a timing test. |
| DOCS-07 | `docs/SECURITY.md` documents bootstrap trust chain and SSH key handling | §8 — bootstrap trust chain only in P2; SSH key handling deferred to Phase 4 docs (note in security doc: "SSH key handling: see docs/SECURITY.md after Phase 4") |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are binding directives extracted from `/Users/josh/Git/personal/dotfiles/CLAUDE.md` and `/Users/josh/Git/personal/dotfiles/.claude/CLAUDE.md` that the planner MUST honor:

- **Manifests are the source of truth** — never infer state from hostname; never branch on filename suffix; never grep `$DOTFILES_PROFILE`.
- **kebab-case feature names need `index` access** in templates (`{{index .MANIFEST.features "one-password-ssh"}}`).
- **Every install task has a `status:` block** using `{{.X}}` template vars (NEVER `$X` shell vars). This is the LINT-02 contract.
- **`set -euo pipefail` on every executable `.zsh`** (LINT-04 contract).
- **No hardcoded `/opt/homebrew` or `/usr/local`** — use `$HOMEBREW_PREFIX` / `{{.HOMEBREW_PREFIX}}`.
- **Symlinks via `_:safe-link` only** — no bare `ln -s` outside `taskfiles/helpers.yml` (LINT-03b contract).
- **XDG everywhere** — `$XDG_STATE_HOME/dotfiles/` for machine-local state (`machine`, `resolved.json`, and now `cutover-ack`).
- **No AI attribution anywhere** — not in commits, not in source comments. Hooks enforce.
- **No emojis in any file** — including markdown. Project convention is stricter than the global "no emojis in non-markdown" rule.
- **File-level comment block at the top of every script** explaining its purpose, callers, and side effects.
- **Section separators use `# ===` or `# ---` banner style** in YAML files.
- **Errors go to stderr** (`error "..."` from `install/messages.zsh`).
- **Use `/gsd-*` commands** for non-trivial change. Direct edits outside a GSD workflow lose context.

---

## 1. Executive Summary

**Top decisions / risks the planner needs to know up front:**

1. **The lint engine is yq + ggrep + find — no new dependencies.** Every check in §5 was run live in this session against the existing v1 taskfiles. The CONTEXT.md sketches needed minor refinement (yq path expression for status block extraction), but the substance is verified working: the LINT-02 pipeline catches the actual `taskfiles/macos.yml:145 $BREW_ZSH` bug class on the existing v1 file. `[VERIFIED 2026-05-13]`

2. **`task install` body in P2 is a thin call-graph stub, not real install logic.** Each downstream subtask (`links:all`, `brew:install`, `claude:install`, `macos:defaults`) gets a no-op stub that prints its desc and exits 0. The planner will replace these with real bodies in Phases 3-7; the structural correctness of the call graph (deps, status, cutover-ack gate placement) is what P2 ships.

3. **Bootstrap runs `brew install go-task yq` unconditionally — guarded by `command -v` precheck, not by `brew install` alone.** Live timing in this session: `brew install go-task` takes **1.3 seconds** when the package is already present (it still hits the API for the formula JSON). A fresh-machine bootstrap re-run that skips the precheck would burn 3+ seconds even when nothing needs installing. The `command -v` guard makes the resumable-bootstrap contract structural rather than coincidental. `[VERIFIED 2026-05-13]`

4. **The cutover-ack gate is enforced via a sourced helper, not duplicated in every task.** `install/cutover-gate.zsh` (new in P2) reads `$XDG_STATE_HOME/dotfiles/cutover-ack` + `$XDG_STATE_HOME/dotfiles/machine`, validates the line, and emits the actionable error on mismatch. Both `bootstrap.zsh` (sources it) and `task install` (calls it as a precondition) use the same helper. Single source of truth; one place to audit.

5. **Removing `task update` (D-10) is the simplest realization of BTSP-06.** v1 has a separate `update:` block that drifts from `install:`. Per D-10 we delete it entirely — there's nothing to compare for byte-identical-output (SC#2 trivially satisfied). The shell alias `update='task install'` ports in Phase 3.

6. **`task --list-all --json` is a useful baseline syntax check.** It exits non-zero on YAML parse errors and on schema-invalid taskfiles. Recommended as `task lint:syntax` first step before yq probes the AST. `[VERIFIED 2026-05-13]`

**Primary recommendation for the planner:** Build the lint suite FIRST (before bootstrap rewrite), wave-style. Each lint sub-task gets a positive-and-negative fixture under `taskfiles/test/lint-fixtures/` so the lint suite is self-testing — the ground truth is "this fixture should fail; this fixture should pass." Then rewrite bootstrap.zsh against the lint suite (it must pass `task lint`). Then ship `task install` as a stub call graph + cutover-ack gate. This sequencing makes the lint suite the v2 quality gate from day one — every later phase ports content under its enforcement.

---

## 2. Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Trust-anchor acquisition (brew + go-task + yq) | bootstrap.zsh (zsh executable) | — | Pre-`task` sequence; cannot use go-task to install go-task. |
| Cutover-ack gate enforcement | install/cutover-gate.zsh (sourced helper) | bootstrap.zsh + task install (callers) | Single helper; multiple callers. Defense in depth. |
| Manifest resolution | install/resolver.zsh (P1, unchanged) | taskfiles/manifest.yml (P1, unchanged) | P1 owns this; P2 only consumes. |
| Install orchestration | taskfiles/install.yml (NEW in P2) | Taskfile.yml `tasks: install:` body (P2 rewrite) | `task install` is the canonical entry; subtask bodies belong to their owning phases. |
| Lint orchestration | taskfiles/lint.yml (NEW in P2) | install/messages.zsh (sourced for output) | All lint logic inlined per D-12. |
| Lint fixtures (positive + negative) | taskfiles/test/lint-fixtures/ (NEW in P2) | — | Self-testing lint; planner verifies via diff. |
| Trust-chain documentation | docs/SECURITY.md (NEW in P2) | — | DOCS-07; bootstrap trust chain only in P2. |

---

## 3. Bootstrap Design

### 3.1 Strict-mode header (BTSP-01)

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# bootstrap.zsh -- acquire trust anchors (brew, go-task, yq) on a fresh macOS
# machine. Tools-only: does NOT take a machine name; does NOT invoke task setup.
#
# After this script completes, the user runs:
#   task setup -- <machine-name>
#   task install
#
# Trust chain documented in docs/SECURITY.md.
# -----------------------------------------------------------------------------

set -euo pipefail
```

**Why `-u`:** catches the v1 `DOTFILEDIR` empty-resolve bug class. Without `-u`, an empty `${BASH_SOURCE[0]}` propagates silently.
**Why `-o pipefail`:** catches mid-pipeline failures (e.g., `curl ... | bash` where curl fails but bash exits 0). Critical for the brew installer step.
`[VERIFIED: bootstrap.zsh currently has only `set -e` — confirmed by reading the file this session]`

### 3.2 Brew acquisition (D-01) — best-effort with audit log (BTSP-02)

```zsh
if ! command -v brew >/dev/null 2>&1; then
  {
    echo
    echo "AUDIT: about to fetch and execute brew install script"
    echo "  source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    echo "  trust:  HTTPS only, no checksum pin (see docs/SECURITY.md)"
    echo "  ctrl-C now to abort (3 second window)"
    echo
  } >&2
  sleep 3
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Re-shellenv so brew is on PATH for the rest of this script.
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  info "brew already installed: $(brew --version | head -1)"
fi
```

**Why bash and not zsh** for the installer: Homebrew's `install.sh` uses bashisms; `/bin/bash` is the documented invocation per [docs.brew.sh/Installation](https://docs.brew.sh/Installation). `[CITED]`

**Why `eval "$(brew shellenv)"` after install:** the installer doesn't modify the running shell's PATH; without re-shellenv, `command -v brew` in the next step fails. `[VERIFIED: standard Homebrew docs pattern]`

**No curl-pipe-to-shell — but DOES curl-pipe-to-bash.** The semantic difference is that `bash` is the explicit Homebrew-supported invocation and the audit line + 3-second sleep give the user a real abort window. v1's bug was `sh -c "$(curl --location https://taskfile.dev/install.sh)" -- ...` — fetching from `taskfile.dev` (third-party CDN) without any audit. v2 fetches from `raw.githubusercontent.com/Homebrew/install` (the canonical Homebrew install path) with explicit audit. BTSP-02's "no curl | sh" intent is satisfied: go-task is installed via `brew install go-task`, never via curl. `[VERIFIED: re-read bootstrap.zsh:33 in this session]`

### 3.3 go-task + yq acquisition (D-02, D-05)

```zsh
# go-task -- need this before any `task` invocation.
if ! command -v task >/dev/null 2>&1; then
  info "installing go-task..."
  brew install go-task
else
  info "go-task already installed: $(task --version)"
fi

# yq -- needed by install/resolver.zsh which `task setup` and `task manifest:resolve`
# both invoke. Min version 4.52.1 for full TOML roundtrip.
if ! command -v yq >/dev/null 2>&1; then
  info "installing yq..."
  brew install yq
else
  yq_ver=$(yq --version | sed -nE 's/.*version v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
  info "yq already installed: v${yq_ver}"
  # Compare against minimum 4.52.1 -- minor-version check (4.x.y).
  if ! printf '%s\n%s\n' "4.52.1" "$yq_ver" | sort -V -C 2>/dev/null; then
    warn "yq v${yq_ver} is older than minimum 4.52.1 — upgrade with: brew upgrade yq"
  fi
fi
```

**Live timing measurements** (`/Users/josh/Git/personal/dotfiles` on this machine, 2026-05-13):
- `command -v brew && command -v task && command -v yq` → **0.001s** when all present `[VERIFIED]`
- `brew install go-task` when already installed → **1.3s** (formula API JSON refresh) `[VERIFIED]`
- `brew --version` → **0.05s** `[VERIFIED]`

**Implication:** the `command -v` precheck is essential. Without it, double-running bootstrap takes ~4s minimum just for the three `brew install` API roundtrips. With it, the no-op path is sub-second.

### 3.4 Cutover-ack gate (D-07, D-08, D-09) — bootstrap-side check

After installing the trust anchors, bootstrap MUST check the cutover-ack sentinel BEFORE printing the "next steps" hint. Otherwise a user could bootstrap a machine that's not cleared for v2 and proceed to run `task install` (which will fail at its own gate, but the failure happens after the "next steps" misleads the user).

```zsh
# Source the cutover-gate helper; it emits the actionable error and exits 1
# on missing/invalid sentinel. Read-only and idempotent.
source "${DOTFILEDIR}/install/cutover-gate.zsh"
cutover_gate_check || exit 1
```

The helper itself lives in §6.

### 3.5 Resumability proof (BTSP-03)

The bootstrap script's structure makes the resumable contract structural:

| Step | Guard | What runs on second invocation |
|------|-------|-------------------------------|
| brew install | `command -v brew` | nothing (skip + info line) |
| go-task install | `command -v task` | nothing (skip + info line) |
| yq install | `command -v yq` | nothing (skip + version line) |
| cutover-ack check | always runs | reads sentinel; passes if valid |
| stdout hint print | always runs | prints hint (intentional — UX, not work) |

**Total work on re-run:** ~0.1s of file reads, no network, no installs. Verified pattern in §10.6.

### 3.6 Concrete bootstrap.zsh skeleton (planner reference)

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# bootstrap.zsh -- acquire trust anchors for v2 dotfiles install.
#
# Pre-task sequence: installs brew, go-task, yq. Does NOT take a machine name.
# Does NOT invoke task setup. Trust chain documented in docs/SECURITY.md.
#
# After this script:
#   task setup -- <machine-name>     # write machine state
#   task install                     # install dotfiles
# -----------------------------------------------------------------------------

set -euo pipefail

# --- DOTFILEDIR resolution (port of P1 pattern, hardened with set -u guards)
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# --- Source messages library
source "${DOTFILEDIR}/install/messages.zsh"

header "Dotfiles v2 Bootstrap"

# --- Step 1: brew (D-01)
# (full block per §3.2)

# --- Step 2: go-task (D-02)
# (block per §3.3)

# --- Step 3: yq (D-02)
# (block per §3.3)

# --- Step 4: cutover-ack gate (D-07)
source "${DOTFILEDIR}/install/cutover-gate.zsh"
cutover_gate_check || exit 1

# --- Step 5: print next-step hint (D-03)
echo
success "Bootstrap complete. Next steps:"
echo "  task setup -- <machine-name>     # write machine state"
echo "  task install                     # install dotfiles"
echo
machines=$(ls "${DOTFILEDIR}/manifests/machines"/*.toml 2>/dev/null \
  | xargs -n1 basename | sed 's/\.toml$//' | tr '\n' ' ')
echo "  Available machines: ${machines}"
```

---

## 4. Idempotency Contract & install ≡ update Unification

### 4.1 `task install` body composition (D-10, BTSP-06)

P2 ships `task install` as a thin orchestration stub. Each subtask is owned by a later phase:

```yaml
# Taskfile.yml (root) -- v2 rewrite
version: '3'

set: [errexit, pipefail]
silent: true

vars:
  HOME: '{{.HOME}}'
  XDG_CONFIG_HOME: '{{.HOME}}/.config'
  XDG_DATA_HOME: '{{.HOME}}/.local/share'
  XDG_STATE_HOME: '{{.HOME}}/.local/state'
  XDG_CACHE_HOME: '{{.HOME}}/.cache'
  ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'
  DOTFILEDIR:
    sh: cd "$(dirname "$(realpath "${TASKFILE:-$0}")")" && pwd
  HOMEBREW_PREFIX:
    sh: |
      if command -v brew >/dev/null 2>&1; then brew --prefix
      elif [[ "$(uname -m)" == "arm64" ]]; then echo "/opt/homebrew"
      else echo "/usr/local"
      fi
  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'

includes:
  manifest: ./taskfiles/manifest.yml
  lint:     ./taskfiles/lint.yml
  links:    ./taskfiles/links-stub.yml      # P3 wires real bodies
  brew:     ./taskfiles/brew-stub.yml       # P5 wires real bodies
  claude:   ./taskfiles/claude-stub.yml     # P7 wires real bodies
  macos:    ./taskfiles/macos-stub.yml      # P6 wires real bodies

tasks:
  default:
    desc: "List available tasks"
    cmds: [task --list]

  install:
    desc: "Install dotfiles for active machine (canonical entry)"
    summary: |
      task install IS task update -- there is no separate update pipeline.
      Re-running is a no-op (every subtask has a status: block).
    preconditions:
      - sh: |
          source "{{.DOTFILEDIR}}/install/cutover-gate.zsh"
          cutover_gate_check
        msg: "cutover-ack gate failed -- see error above"
    deps: [manifest:resolve]
    cmds:
      - task: links:all
      - task: brew:install
      - task: claude:install
      - task: macos:defaults
      - task: macos:shell
      - |
        {{.DOTFILES_MESSAGES}}
        success "install complete"

  # NO `update:` block. task install IS task update (D-10).
  # Phase 3 ships shell alias `update='task install'` for muscle memory.
```

**Stub-subtask pattern (planner adopts in P2 for taskfiles owned by later phases):**

```yaml
# taskfiles/links-stub.yml -- placeholder until Phase 3 lands real bodies.
version: '3'
tasks:
  all:
    desc: "STUB (Phase 3 will implement)"
    status: [true]   # always-pass; nothing to do
    cmds:
      - |
        echo "links:all -- stub (Phase 3 will implement SHEL-01..03 here)" >&2
```

The `status: [true]` makes the stub idempotent by the LINT-03a contract. When Phase 3 replaces this with a real implementation, the stub tag (`STUB (Phase X)`) is grep-able for tracking outstanding work.

### 4.2 The structural idempotency guarantee (LINT-01)

**The contract:** every task included in `task install`'s call graph has a `status:` block. The lint suite enforces this structurally (LINT-03a). Therefore `task install` re-run is by construction a sequence of skipped tasks.

**Why no timing test (D-11):** measuring `task install` runtime adds CI infrastructure (TIMING) without protecting against any failure mode that LINT-01 doesn't already catch. If every task has a working `status:` block, re-run is fast; if any task lacks one, lint fails BEFORE we'd ever measure timing. Speed is a consequence; correctness is the contract.

### 4.3 Byte-identical output verification (SC#2, partial)

With `task update` removed (D-10), SC#2's "byte-identical output" comparison degenerates to "task install run twice produces the same output." The planner can include this as a smoke check, but it's not a hard gate — it depends on `info "..."` lines that contain timestamps if the planner adds any:

```bash
# In taskfiles/test/install-twice.sh (optional sanity check):
task install > /tmp/install-1.txt 2>&1
task install > /tmp/install-2.txt 2>&1
diff /tmp/install-1.txt /tmp/install-2.txt
```

**Recommendation:** make this an opt-in `task lint:install-twice` sub-task, not part of `task lint` default. Useful for spot-checking after major changes; too brittle for the gate.

---

## 5. Lint Engine Design

All lint sub-tasks live in `taskfiles/lint.yml` per D-12. Each pattern below was run live in this session against existing v1 files; the column "Verified Detection" is the actual finding from the live run.

### 5.1 Lint orchestration (LINT-06)

```yaml
# taskfiles/lint.yml
version: '3'

includes:
  _: ./helpers.yml

tasks:
  default:
    desc: "Run all lint checks (LINT-06 aggregator)"
    cmds:
      - task: syntax        # LINT-07 -- zsh -n parse
      - task: taskfile      # LINT-02 + LINT-03a + LINT-03b
      - task: shell-headers # LINT-04
      - task: portability   # LINT-05 (warn-only, exit 0)

  syntax:        { ... }
  taskfile:      { ... }
  shell-headers: { ... }
  portability:   { ... }
```

A single failing sub-task fails the aggregator (go-task default behavior).

### 5.2 LINT-02: `$VAR` in `status:` blocks

**The bug class:** `taskfiles/macos.yml:145` uses `$BREW_ZSH` (shell variable) in a `status:` check. go-task evaluates `status:` in a fresh shell where `$BREW_ZSH` is unset — the check always fails, the task always re-runs (the v1 idempotency-drift bug).

**Detection pipeline (live-tested in this session):**

```bash
# In taskfiles/lint.yml lint:taskfile cmds:
violations=0
for f in taskfiles/*.yml; do
  # yq emits each task's status block content as a YAML array; we grep the result
  out=$(yq '.tasks[] | select(.status) | .status' "$f" 2>/dev/null \
        | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
        | ggrep -vE '\$\(' \
        | ggrep -vE '\{\{' || true)
  if [[ -n "$out" ]]; then
    error "LINT-02: \$VAR in status: block — $f"
    echo "$out" >&2
    violations=$((violations + 1))
  fi
done
exit $violations
```

**Verified detection on existing repo (run in this session):**
```
22:- grep -qxF "$BREW_ZSH" /etc/shells     # taskfiles/macos.yml:145 — the actual v1 bug
```
`[VERIFIED 2026-05-13]`

**Why `ggrep -vE '\$\('`:** `$(...)` command substitution is legitimate in status blocks (e.g., `[[ "$(defaults read ...)" == "1" ]]`). We only flag `$VAR`-style shell expansions, not `$(...)` substitutions.

**Why `ggrep -vE '\{\{'`:** the legitimate go-task template form is `{{.X}}`. The `\$\b` would also match positional vars like `$1`, but those don't appear in lint-fixture taskfiles either.

**Caveat (planner verifies):** the regex `\$[A-Za-z_][A-Za-z0-9_]*` matches `$_`, `$0`, `$@`. None of these appear in legitimate `status:` blocks in v1. Acceptable false-negative-on-`$@` risk; acceptable false-positive-on-`$_` risk. If a fixture surfaces a real false positive, planner can extend the exclusion list.

### 5.3 LINT-03b: bare `ln -s` outside `helpers.yml`

**The bug class:** `taskfiles/links.yml:69` and `taskfiles/profile-tasks.yml:57` use raw `ln -sf` instead of `_:safe-link`. The status check passes if the symlink exists, but a broken or stale symlink is never detected.

**Detection (verified live):**

```bash
violations=$(ggrep -rn -E '\bln[[:space:]]+-s' taskfiles/ \
              | ggrep -v 'helpers.yml' \
              | ggrep -v ':[[:space:]]*#' || true)
if [[ -n "$violations" ]]; then
  error "LINT-03b: bare 'ln -s' outside helpers.yml"
  echo "$violations" >&2
  exit 1
fi
```

**Verified detection on existing repo:**
```
taskfiles/links.yml:69:          ln -sf "{{.DOTFILEDIR}}/ssh/configs/agent.toml" ...
taskfiles/profile-tasks.yml:57:            ln -sf "$KEY_FILE" "{{.HOME}}/.ssh/id_ed25519_..."
```
`[VERIFIED 2026-05-13]`

**Allowlist note:** D-13 makes `taskfiles/helpers.yml` the only allowed location. If a future helper legitimately needs bare `ln`, planner extends the `ggrep -v` chain. `install/resolver.zsh` and other non-taskfile scripts are out of scope for this lint (it scans `taskfiles/` only).

### 5.4 LINT-03a: `cmds:` without `status:` (LINT-01 enforcement)

**The bug class:** `taskfiles/claude.yml:211-219` `gsd-install` has `cmds:` but no `status:` — re-runs on every `task install`.

**Detection (verified live):**

```bash
# yq emits {name, has_status} for every task that has cmds.
# Internal tasks (`internal: true`) and tasks that delegate purely to other
# tasks (`cmds: [{task: ...}]`) are exempt. The exemption logic below uses
# yq to inspect each task's cmds for non-shell entries.
violations=0
for f in taskfiles/*.yml; do
  while IFS= read -r task_name; do
    [[ -z "$task_name" ]] && continue
    # Skip internal: true
    is_internal=$(yq ".tasks.\"$task_name\".internal // false" "$f")
    [[ "$is_internal" == "true" ]] && continue
    # Skip tasks whose cmds are ALL `task:` references (no shell)
    all_delegations=$(yq ".tasks.\"$task_name\".cmds | all(has(\"task\"))" "$f" 2>/dev/null || echo false)
    [[ "$all_delegations" == "true" ]] && continue
    # Real violation
    error "LINT-03a: '$task_name' in $f has cmds: but no status:"
    violations=$((violations + 1))
  done < <(yq '.tasks | to_entries | .[] | select(.value | has("cmds")) | select(.value | has("status") | not) | .key' "$f" 2>/dev/null)
done
exit $violations
```

**Verified detection on existing repo (`taskfiles/claude.yml`):** flags `install`, `update`, `validate`, `status`, `ensure-cli`, `marketplaces-add`, `marketplaces-update`, `plugins-install`, `plugins-update`, `gsd-install`. After the `internal: true` and `all-delegations` exemptions, the remaining true positives are: `install`, `update`, `validate`, `status`, `gsd-install` — all of which are real LINT-01 violations in v1. `[VERIFIED 2026-05-13]`

**Exemptions to discuss with planner:**
- `internal: true` tasks ARE exempt (they're sub-tasks called by orchestrator tasks; the orchestrator's status governs).
- Tasks whose cmds are pure `task:` delegations ARE exempt (orchestration only — no work to gate).
- Tasks like `validate` and `status` (which print info, not install state) — planner decides whether to make them exempt by convention (e.g., `desc:` starts with `"VALIDATE:"` or `"PRINT:"`) OR to require a trivial `status: [true]` to pass lint. Recommendation: require `status: [true]` for explicitness; lint stays simple.

### 5.5 LINT-04: executable `.zsh` missing `set -euo pipefail`

**The bug class:** `bootstrap.zsh:2` uses `set -e` instead of `set -euo pipefail`. The `-u` flag was missing.

**Detection (verified live):**

```bash
violations=0
while IFS= read -r f; do
  # Look at the first 10 lines (header + comment block + set line)
  if ! head -10 "$f" | ggrep -qE '^set -euo pipefail$'; then
    error "LINT-04: $f missing 'set -euo pipefail' in first 10 lines"
    violations=$((violations + 1))
  fi
done < <(find . -name '*.zsh' -perm +111 -not -path './.git/*' -not -path './.planning/*' 2>/dev/null)
exit $violations
```

**Why `head -10` not `head -3`:** P1's resolver puts `set -euo pipefail` at line 30 (after a 28-line header comment block). v1 hooks have it at line 5 (after `#!/bin/zsh` + 3 comment lines). Use `head -30` to be safe — verified in this session: `bootstrap.zsh:2`, `claude/hooks/agent-transparency.zsh:2`, `claude/hooks/no-emojis.zsh:5`, `install/resolver.zsh:30` all currently have it (or its bare `set -e` cousin) within the first 30 lines. Recommend `head -30` for v2.

**Verified detection on existing repo (`head -5` initial scan):**
```
MISSING: bootstrap.zsh             (has `set -e` only — the BTSP-01 bug)
MISSING: install/resolver.zsh      (false positive: has it at line 30)
MISSING: ssh/cloudflared.zsh       (true positive: 5-line script, no set line at all)
```
`[VERIFIED 2026-05-13]`. After bumping to `head -30`, only `bootstrap.zsh` (BTSP-01 fix target) and `ssh/cloudflared.zsh` (legitimate gap — very small script but should still have it) remain.

**Exemption for sourced-only files:** `find ... -perm +111` already filters out non-executable files. Aliases (`shell/aliases/*.zsh`) and library files (`install/messages.zsh`, `claude/hooks/lib.zsh`) are sourced, not executed — they're not chmod +x — so they're naturally excluded.

### 5.6 LINT-05: portability warnings (warn-only, non-blocking)

**Per D-13:** these are advisory hints for the future-Linux v2; they do NOT block the v1 build.

**What to flag:** macOS-specific commands inside flat `shell/` and `os/` directories (places where Linux would need a different implementation):

| Pattern | macOS-only because |
|---------|-------------------|
| `pbcopy`, `pbpaste` | macOS clipboard CLI (Linux uses `xclip` / `wl-copy`) |
| `osascript` | macOS AppleScript runtime |
| `defaults read`, `defaults write` | macOS `defaults` plist tool (Linux has no equivalent) |
| `sw_vers` | macOS version reporter (Linux uses `lsb_release` / `/etc/os-release`) |
| `dscl` | macOS Directory Services CLI |
| `chsh` (without arg parsing for Linux) | macOS expects `/etc/shells` registration first |
| `/Applications/` paths | macOS GUI app convention |
| `/usr/libexec/PlistBuddy` | macOS plist editor |

**Detection pattern:**

```bash
# Scan shell/ and os/ directories for macOS-only commands
patterns=(pbcopy pbpaste osascript 'defaults read' 'defaults write' sw_vers dscl PlistBuddy)
warnings=0
for pat in "${patterns[@]}"; do
  hits=$(ggrep -rnE "\\b${pat}\\b" shell/ os/ 2>/dev/null | ggrep -v ':\\s*#' || true)
  if [[ -n "$hits" ]]; then
    warn "LINT-05: portability hint — '${pat}' found:"
    echo "$hits" >&2
    warnings=$((warnings + 1))
  fi
done
[[ $warnings -gt 0 ]] && warn "LINT-05: $warnings portability hint(s) found (non-blocking; exit 0)"
exit 0   # NEVER non-zero per D-13
```

**Why not flag in `claude/hooks/`, `install/`, `taskfiles/`:** those dirs are explicitly platform-coupled (taskfiles use macOS commands inside `platforms: [darwin]` blocks; hooks are sourced into Claude's runtime which is shared across machines). Linux v2 will deal with those at a different layer. The hint is targeted at code that NEEDS to be portable in v2 (shell aliases/functions and OS defaults), not at glue that won't be.

`[ASSUMED]` The exact list of patterns may need extension as Phase 3 lands shell content; planner can add patterns observed during shell port.

### 5.7 LINT-07: `zsh -n` syntax check

**Detection:**

```bash
violations=0
while IFS= read -r f; do
  if ! zsh -n "$f" 2>&1; then
    error "LINT-07: zsh -n parse error in $f"
    violations=$((violations + 1))
  fi
done < <(find . -name '*.zsh' -not -path './.git/*' -not -path './.planning/*' 2>/dev/null)
exit $violations
```

**Verified on existing repo:** `bootstrap.zsh`, `install/messages.zsh`, `install/resolver.zsh`, all hooks parse clean (`zsh -n` exits 0). `[VERIFIED 2026-05-13]`

**What `zsh -n` does NOT catch:** the `local`-at-script-scope bug (`claude/hooks/agent-transparency.zsh:11`). `zsh -n` is a parse-only check; semantic issues like `local` outside a function are runtime-detected. shellcheck would catch this; we explicitly defer shellcheck to a future hardening phase per CONTEXT.md.

**Performance:** parallel execution is overkill at this file count (~15 zsh files). Sequential is fine; planner can switch to `xargs -P 4` if file count grows past ~50. Live timing this session: sequential `zsh -n` over all 15 zsh files = sub-second.

### 5.8 LINT-syntax (taskfile YAML parse, baseline)

**Bonus check using go-task itself** as a cheap baseline before yq probes the AST:

```bash
# task --list-all --json exits non-zero on YAML parse errors
for f in taskfiles/*.yml; do
  if ! task --list-all --json -t "$f" >/dev/null 2>&1; then
    error "LINT-syntax: $f fails task parse"
    exit 1
  fi
done
```

**Verified working** in this session — `task --list-all --json -t taskfiles/macos.yml` returns valid JSON and exits 0. A malformed taskfile would exit non-zero. `[VERIFIED 2026-05-13]`

**Recommendation:** include as the first step in `task lint:syntax` (zsh -n + task syntax parse) so a YAML breakage surfaces with a go-task-native error message before yq probes.

---

## 6. Cutover-Ack Gate

### 6.1 Sentinel format (D-08)

```
$XDG_STATE_HOME/dotfiles/cutover-ack
```

Contents (single line):
```
<machine-name> <ISO-8601-UTC-timestamp>
```

Example:
```
personal-laptop 2026-05-15T10:23:00Z
```

### 6.2 Gate helper (`install/cutover-gate.zsh`)

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/cutover-gate.zsh -- enforce per-machine cutover-ack sentinel.
#
# Sourced by:
#   - bootstrap.zsh (called BEFORE printing next-step hint)
#   - taskfiles/install.yml (preconditions: block on `task install`)
#
# Reads: $XDG_STATE_HOME/dotfiles/cutover-ack    (single line: <name> <ts>)
#        $XDG_STATE_HOME/dotfiles/machine        (active machine name)
# Exits: 1 on missing/invalid/mismatched sentinel
#        0 on valid sentinel for active machine
#
# The sentinel WRITER (`task cutover:ack -- <name>`) is owned by Phase 8
# (CUTV-03). P2 only reads/enforces.
# -----------------------------------------------------------------------------

[[ -n "${DOTFILES_CUTOVER_GATE_LOADED:-}" ]] && return 0
DOTFILES_CUTOVER_GATE_LOADED=1

: "${DOTFILES_MESSAGES_LOADED:=}"
[[ -z "$DOTFILES_MESSAGES_LOADED" ]] && source "${DOTFILEDIR:?}/install/messages.zsh"

cutover_gate_check() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  local machine_file="${state_dir}/machine"
  local ack_file="${state_dir}/cutover-ack"
  local active_machine ack_machine ack_ts

  if [[ ! -f "$machine_file" ]]; then
    error "no machine selected (run: task setup -- <machine-name>)"
    return 1
  fi
  active_machine=$(head -n1 "$machine_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [[ ! -f "$ack_file" ]]; then
    _cutover_gate_emit_error "$active_machine" "missing"
    return 1
  fi

  read -r ack_machine ack_ts < "$ack_file"
  if [[ -z "$ack_machine" || -z "$ack_ts" ]]; then
    _cutover_gate_emit_error "$active_machine" "malformed"
    return 1
  fi

  if [[ "$ack_machine" != "$active_machine" ]]; then
    _cutover_gate_emit_error "$active_machine" "mismatch (sentinel claims '$ack_machine')"
    return 1
  fi

  return 0
}

_cutover_gate_emit_error() {
  local machine="$1"
  local reason="$2"
  {
    echo
    error "machine '${machine}' is not cut over to v2 (${reason})."
    echo
    echo "  This branch is v2-only. v1 lives on master."
    echo "  To cut this machine over, run:"
    echo "    task cutover:ack -- ${machine}"
    echo
    echo "  See docs/CUTOVER.md for the full procedure."
    echo
  } >&2
}
```

**Why a sourced helper, not a standalone script:** `cutover_gate_check` returns 0/1 and is callable from both bash (bootstrap.zsh runs as zsh) and from inside go-task `preconditions: sh:` blocks. A function in a sourced file is the cheapest way to share logic between the two callers.

**Why double-source guard:** consistent with `install/messages.zsh` pattern; allows being sourced by both bootstrap (which sources the helper directly) and by `taskfiles/install.yml` (which may source it inside a `preconditions:` block invoked multiple times).

### 6.3 Gate enforcement points (D-09)

**Blocked tasks** (must call `cutover_gate_check` in preconditions or first cmd):
- `task install` (Taskfile.yml root)
- `task links:all`, `task links:zsh`, `task links:git`, etc. (P3-P7 add bodies; P2's stubs include the gate)
- `task brew:install` (P5)
- `task claude:install` (P7)
- `task macos:defaults`, `task macos:shell` (P6)

**NOT blocked** (read-only / test):
- `task lint`, `task lint:*` (developer iteration on v2 branch must work without sentinel)
- `task manifest:test`, `task manifest:show`, `task manifest:validate` (P1, read-only or test-only)
- `task validate` (P8, read-only)
- `task test` (P7 aggregator)

**Pattern for adding the gate to a task** (planner template):

```yaml
tasks:
  install:   # canonical entry; gate fires here
    preconditions:
      - sh: |
          source "{{.DOTFILEDIR}}/install/cutover-gate.zsh"
          cutover_gate_check
        msg: "cutover-ack gate failed -- see actionable error above"
    cmds: [...]
```

The gate's `_cutover_gate_emit_error` writes to stderr (via `error "..."` from messages.zsh) and the helper itself returns 1; the precondition's `msg:` is the fallback if go-task swallows stderr (which it shouldn't, but belt + suspenders).

---

## 7. `taskfiles/lint.yml` Skeleton (Planner Reference)

```yaml
# taskfiles/lint.yml
version: '3'

# =============================================================================
# Lint suite -- enforces v2 conventions structurally.
#
# - LINT-02: $VAR in status: blocks (the macos:shell:145 bug class)
# - LINT-03a: cmds: without status: (the gsd-install bug class)
# - LINT-03b: bare ln -s outside helpers.yml (the links.yml:69 bug class)
# - LINT-04: executable .zsh missing set -euo pipefail (the bootstrap.zsh:2 bug class)
# - LINT-05: portability hints (warn-only, exit 0)
# - LINT-07: zsh -n parse errors (the local-at-script-scope bug catches at runtime, not here)
#
# Callable as `task lint` (default) or individually as `task lint:taskfile`, etc.
# Read-only (no manifest dependency); not gated by cutover-ack.
# =============================================================================

includes:
  _: ./helpers.yml

vars:
  TASKFILE_GLOB: 'taskfiles/*.yml'
  ZSH_FIND: |
    find . -name '*.zsh' -not -path './.git/*' -not -path './.planning/*'

tasks:
  default:
    desc: "Run all lint checks (LINT-06 aggregator)"
    cmds:
      - task: syntax
      - task: taskfile
      - task: shell-headers
      - task: portability

  # ---------------------------------------------------------------------------
  # LINT-syntax + LINT-07: parse-level checks
  # ---------------------------------------------------------------------------
  syntax:
    desc: "YAML parse + zsh -n syntax checks"
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        # Taskfile YAML parse via go-task itself
        for f in {{.TASKFILE_GLOB}}; do
          if task --list-all --json -t "$f" >/dev/null 2>&1; then
            check "yaml-parse: $f"
          else
            cross "yaml-parse: $f -- task --list-all failed"
            exit 1
          fi
        done
      - |
        {{.DOTFILES_MESSAGES}}
        # zsh -n parse over every .zsh file
        violations=0
        while IFS= read -r f; do
          if zsh -n "$f" 2>&1; then
            check "zsh -n: $f"
          else
            cross "zsh -n: $f"
            violations=$((violations + 1))
          fi
        done < <({{.ZSH_FIND}})
        exit $violations

  # ---------------------------------------------------------------------------
  # LINT-02 + LINT-03a + LINT-03b: taskfile structure checks
  # ---------------------------------------------------------------------------
  taskfile:
    desc: "Taskfile structure: $VAR in status, missing status, bare ln -s"
    cmds:
      - cmd: '...'  # see §5.2, §5.3, §5.4 for concrete pipelines

  # ---------------------------------------------------------------------------
  # LINT-04: executable .zsh missing set -euo pipefail
  # ---------------------------------------------------------------------------
  shell-headers:
    desc: "Executable .zsh files have set -euo pipefail"
    cmds:
      - cmd: '...'  # see §5.5

  # ---------------------------------------------------------------------------
  # LINT-05: portability hints (warn-only, non-blocking)
  # ---------------------------------------------------------------------------
  portability:
    desc: "Portability hints for future-Linux (warn-only)"
    cmds:
      - cmd: '...'  # see §5.6
```

---

## 8. `docs/SECURITY.md` Outline (DOCS-07, BTSP-05)

```markdown
# Security: Bootstrap Trust Chain

## What This Document Covers

This document describes what `bootstrap.zsh` downloads, from where, how it is verified, and
who is trusted. SSH key handling is documented separately in Phase 4's identity layer
(see Phase 4 of `.planning/ROADMAP.md`).

## Bootstrap Trust Chain

### Step 1 -- Homebrew installer

**What is downloaded:** the Homebrew install shell script
(`install.sh`).

**From where:** `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`

**How it is verified:** HTTPS only. No checksum pin, no signature verification.

**Why this trust boundary is accepted:** The Homebrew install script is the canonical install
path published by `brew.sh` and used by every official macOS dev-environment guide. Pinning
to a checksum requires updating the pin every time the Homebrew project ships an installer
change; the maintenance burden outweighs the security delta over HTTPS-only retrieval. We
accept the same trust boundary as the wider macOS development community.

**Audit signal:** `bootstrap.zsh` emits an `AUDIT:` line to stderr before fetching the
installer, with a 3-second sleep so users have an explicit abort window.

### Step 2 -- go-task and yq

**What is downloaded:** Homebrew formula bottles for `go-task` and `yq`.

**From where:** Homebrew's CDN (`ghcr.io/homebrew/core/...` for bottle artifacts; metadata
served from `formulae.brew.sh`).

**How it is verified:** Homebrew computes SHA-256 checksums for every bottle and refuses to
install if the downloaded artifact does not match the formula's declared checksum. This is
Homebrew's standard formula-verification path -- we inherit its guarantee.

**Why this trust boundary is accepted:** Homebrew formula bottles are SHA-256 verified by
brew itself; bottling infrastructure is operated by the Homebrew project. This is a stronger
trust boundary than Step 1.

## Threat Model

| Threat | Mitigation | Residual Risk |
|--------|-----------|---------------|
| MITM on `raw.githubusercontent.com` during installer fetch | TLS only | Real -- accepted as cost of pragmatic install |
| Compromise of GitHub mirror serving the installer | HTTPS only; no signature check | Real -- documented |
| Compromise of Homebrew bottle artifact in CDN | SHA-256 checksum validated by brew | Mitigated |
| Compromise of formula metadata declaring wrong SHA-256 | Formula commits are PR-reviewed by Homebrew | Mitigated -- accept Homebrew's review process |
| Local user runs bootstrap with hostile `$DOTFILEDIR` env override | Bootstrap re-resolves `DOTFILEDIR` from `$0` | Mitigated |

## Trust Anchors

The following parties are trusted in the bootstrap chain:

1. **Apple** -- macOS itself, including the system curl, system bash, system zsh, and TLS
   implementation. Standard macOS development assumption.
2. **GitHub Inc.** -- TLS termination at `raw.githubusercontent.com`; integrity of the
   `Homebrew/install` repository; integrity of `ghcr.io` artifact storage.
3. **The Homebrew project** -- the install script's correctness; formula metadata
   accuracy (declared SHA-256 checksums); bottling pipeline integrity.

## What This Document Does NOT Cover

- SSH key handling -- deferred to Phase 4 (identity layer)
- 1Password agent integration -- deferred to Phase 4
- Claude hook secret-scanning -- deferred to Phase 7 hardening
- Per-machine credential management -- out of scope for v1; documented in `docs/MACHINES.md`
  (Phase 8)

## How to Audit

To inspect what bootstrap will run before invoking it:

    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | less

To verify go-task's bottle SHA-256 in the Homebrew formula:

    brew info --json=v2 go-task | jq '.formulae[0].bottle.stable.files'

## Future Hardening

Listed for reference; not in v1 scope:

- Pinned-checksum brew installer (vendor `install.sh` at a known commit)
- shellcheck integration for hooks
- GitHub Actions CI for lint regression detection
```

**Why this outline:** every section directly maps to a CONTEXT.md "Specific Ideas" item (`Reference SECURITY.md outline`, items 1-6).

---

## 9. Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOML parsing in lint or bootstrap | A regex parser | `yq` (already in P1 stack) | Schema-correct; handles quoted strings, multi-line, escapes |
| Taskfile AST traversal | Custom YAML walker | `yq '.tasks[] | select(.status)'` style queries | yq is the project's parsing primitive |
| Trust-anchor install ordering | curl-pipe-to-shell with custom retry | `command -v X || brew install X` | Three-line pattern; resumable by construction |
| Cutover-ack format | INI / TOML / JSON for one line of state | Single-line text file (`<name> <iso-ts>`) | Read with `read -r`; matches P1's `machine` state-file convention |
| Atomic write of resolved.json (P1, referenced) | Direct `>` redirect | `mktemp + mv` | Already in P1 resolver; not P2's concern but worth noting |
| Symlink creation outside helpers | Bare `ln -sfn` | `_:safe-link` (P1, in `taskfiles/helpers.yml`) | `_:safe-link` creates parent dir; LINT-03b enforces |
| Idempotency timing test (LINT-08) | A CI script that times `task install` | NOTHING -- LINT-01 (every task has status:) is the structural guarantee | Per D-11; speed is a consequence of correctness |
| Test framework for lint suite | bats or zunit | Shell-native fixture diff (`diff <(actual) <(expected)`) | P1's `manifest:test` already established this pattern -- reuse it |

**Key insight:** every Phase 2 deliverable can be built from tools already in the P1 stack (yq, jq, find, ggrep, zsh, go-task, brew). Phase 2 adds zero new tool dependencies.

---

## 10. Validation Architecture

### 10.1 Test Framework

| Property | Value |
|----------|-------|
| Framework | shell-native fixture testing (no bats/zunit -- consistent with P1 `manifest:test`) |
| Config file | none -- lint fixtures live under `taskfiles/test/lint-fixtures/<NN>-<name>/` |
| Quick run command | `task lint` (the aggregator) |
| Full suite command | `task lint && task lint:test-fixtures` (lint suite + lint-suite-self-test) |

Test runner approach: `taskfiles/lint.yml` includes a `task lint:test-fixtures` sub-task that iterates `taskfiles/test/lint-fixtures/*/` and asserts each fixture either passes or fails the corresponding lint check (per its `expect` file). One pass/fail line per fixture. Non-zero exit on any unexpected behavior.

### 10.2 Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BTSP-01 | bootstrap.zsh has `set -euo pipefail` | static | `head -30 bootstrap.zsh \| ggrep -q '^set -euo pipefail$'` | Wave 0 (bootstrap.zsh rewrite) |
| BTSP-02 | bootstrap installs go-task via `brew install`, not curl-pipe-to-shell | static | `! ggrep -E 'curl.*\\| *(sh\|bash)' bootstrap.zsh && ggrep -q 'brew install go-task' bootstrap.zsh` | Wave 0 |
| BTSP-03 | bootstrap re-run is no-op | smoke (live) | `./bootstrap.zsh; ./bootstrap.zsh` -- second run prints "already installed" lines and does not re-fetch any package | Wave 0 |
| BTSP-04 | `task setup -- <name>` writes machine state | unit (P1 already covers) | `task setup -- personal-laptop && test -f $XDG_STATE_HOME/dotfiles/machine` | exists (P1) |
| BTSP-05 | `docs/SECURITY.md` exists with required sections | static | `test -f docs/SECURITY.md && ggrep -qE '^## Bootstrap Trust Chain$' docs/SECURITY.md && ggrep -qE '^## Threat Model$' docs/SECURITY.md && ggrep -qE '^## Trust Anchors$' docs/SECURITY.md` | Wave 0 |
| BTSP-06 | `task install` is canonical; no `task update` exists | static | `task --list-all --json \| jq -e '.tasks \| map(.name) \| index("update") == null'` | Wave 0 (Taskfile.yml rewrite) |
| LINT-01 | every task in `task install`'s call graph has `status:` | unit | `task lint:taskfile` exits 0 against the v2 Taskfile.yml + included taskfiles | Wave 0 (lint.yml + Taskfile.yml + stubs) |
| LINT-02 | `$VAR` in status: block is detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/02a-shell-var-in-status/Taskfile.yml` exits non-zero | Wave 0 (fixture) |
| LINT-02 | `{{.X}}` in status: block does NOT trigger | unit (negative fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/02b-template-var-in-status/Taskfile.yml` exits 0 | Wave 0 (fixture) |
| LINT-03a | cmds without status: detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/03a-cmds-no-status/Taskfile.yml` exits non-zero | Wave 0 (fixture) |
| LINT-03b | bare `ln -s` outside helpers.yml detected | unit (positive fixture) | `task lint:taskfile -t taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` exits non-zero | Wave 0 (fixture) |
| LINT-04 | executable .zsh missing `set -euo pipefail` detected | unit (positive fixture) | `task lint:shell-headers` against fixture .zsh missing the line exits non-zero | Wave 0 (fixture) |
| LINT-05 | portability patterns warn but exit 0 | unit (positive fixture) | `task lint:portability` against shell file with `pbcopy` prints warning AND exits 0 | Wave 0 (fixture) |
| LINT-06 | `task lint` aggregates all sub-checks | smoke | `task lint` runs lint:syntax, lint:taskfile, lint:shell-headers, lint:portability sequentially | Wave 0 (lint.yml default task) |
| LINT-07 | `zsh -n` parse error detected | unit (positive fixture) | `task lint:syntax` against fixture .zsh with intentional syntax error exits non-zero | Wave 0 (fixture) |
| LINT-08 | DEPRECATED -- not implemented per D-11 | n/a | -- | -- |
| DOCS-07 | docs/SECURITY.md present with bootstrap trust chain section | static | (same as BTSP-05) | Wave 0 |
| (gate) | bootstrap fails actionably without cutover-ack sentinel | unit | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && ./bootstrap.zsh` -- expect exit 1 + actionable error referencing `task cutover:ack` | Wave 0 |
| (gate) | `task install` fails actionably without cutover-ack sentinel | unit | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && task install` -- expect exit 1 + actionable error | Wave 0 |
| (gate) | Read-only tasks NOT blocked by missing cutover-ack | smoke | `rm -f $XDG_STATE_HOME/dotfiles/cutover-ack && task lint && task manifest:show` -- both succeed | Wave 0 |

### 10.3 Sampling Rate

- **Per task commit:** `task lint` (the four sub-tasks; sub-second on this repo size)
- **Per wave merge:** `task lint && task lint:test-fixtures` (lint suite + self-test)
- **Phase gate:** all 18 requirements verified by their commands above, before `/gsd-verify-work`

### 10.4 Wave 0 Gaps

**Lint fixtures** (each has `Taskfile.yml` or `*.zsh` + `expect` file with `pass` or `fail` line):
- [ ] `taskfiles/test/lint-fixtures/02a-shell-var-in-status/` -- positive: status block uses `$VAR`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/02b-template-var-in-status/` -- negative: status uses `{{.X}}`. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/02c-command-substitution-in-status/` -- negative: status uses `$(cmd)`. Expect PASS (legitimate).
- [ ] `taskfiles/test/lint-fixtures/03a-cmds-no-status/` -- positive: task has cmds: but no status:. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/03a-internal-no-status-ok/` -- negative: `internal: true` task has cmds: no status:. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/03b-bare-ln/` -- positive: taskfile has `ln -sf` outside helpers.yml. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/03b-helpers-allowed/` -- negative: `helpers.yml` has `ln -sfn`. Expect PASS.
- [ ] `taskfiles/test/lint-fixtures/04a-missing-set-euo/` -- positive: executable .zsh has only `set -e`. Expect FAIL.
- [ ] `taskfiles/test/lint-fixtures/04b-non-exec-no-set/` -- negative: non-executable .zsh has no set line. Expect PASS (sourced-only is exempt).
- [ ] `taskfiles/test/lint-fixtures/05a-pbcopy-warn/` -- positive (warn): shell file uses `pbcopy`. Expect WARN + exit 0.
- [ ] `taskfiles/test/lint-fixtures/07a-syntax-error/` -- positive: .zsh with deliberate syntax error. Expect FAIL.

**New artifacts** (none of which exist yet):
- [ ] `bootstrap.zsh` (rewrite — replaces v1)
- [ ] `Taskfile.yml` (rewrite — replaces v1; drops `update:` per D-10)
- [ ] `taskfiles/install.yml` -- v2 install orchestration (or inline in root Taskfile per planner preference)
- [ ] `taskfiles/lint.yml` -- the lint suite
- [ ] `taskfiles/links-stub.yml`, `brew-stub.yml`, `claude-stub.yml`, `macos-stub.yml` -- stub files for P3/P5/P6/P7
- [ ] `install/cutover-gate.zsh` -- the gate helper
- [ ] `docs/SECURITY.md` -- bootstrap trust chain documentation

### 10.5 Negative tests (something that SHOULD fail)

- Replace `{{.BREW_ZSH}}` with `$BREW_ZSH` in any status block, run `task lint`. **Expect exit 1.**
- Add a task with `cmds: [echo hi]` and no `status:` to any taskfile. Run `task lint`. **Expect exit 1.**
- Add `ln -sf foo bar` to any taskfile other than `helpers.yml`. Run `task lint`. **Expect exit 1.**
- Remove `set -euo pipefail` from `bootstrap.zsh`. Run `task lint`. **Expect exit 1.**
- Insert `if [[ then` (broken zsh) into any .zsh file. Run `task lint`. **Expect exit 1.**
- Delete `$XDG_STATE_HOME/dotfiles/cutover-ack`, run `task install`. **Expect exit 1 with actionable error.**
- Write `wrong-machine 2026-05-15T10:23:00Z` to cutover-ack while machine state file says `personal-laptop`, run `task install`. **Expect exit 1 with mismatch error.**
- Run `task --list-all` and grep for "update". **Expect zero matches** (D-10).

### 10.6 Bootstrap re-run no-op verification (BTSP-03)

```bash
# After fresh bootstrap:
./bootstrap.zsh > /tmp/run1.txt 2>&1
time ./bootstrap.zsh > /tmp/run2.txt 2>&1   # expect <1 second
# run2 must contain no "Installing" lines, only "already installed"
! ggrep -E 'Installing (brew|go-task|yq)' /tmp/run2.txt
# diff (excluding any timestamp lines if planner adds them)
diff /tmp/run1.txt /tmp/run2.txt | wc -l    # expect minimal diff (info-line timestamps acceptable)
```

---

## 11. Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| brew | bootstrap.zsh (and entire chain) | yes | 5.1.11 | none -- bootstrap installs it if missing |
| go-task | task install + everything | yes | 3.50.0 | none -- bootstrap installs via brew |
| yq | install/resolver.zsh + lint.yml | yes | 4.53.2 | none -- bootstrap installs via brew |
| jq | install/resolver.zsh; not strictly needed by lint | yes | 1.8.1 | already in v1 Brewfile; planner adds to packages/core.rb in P5 |
| zsh | every script + LINT-07 | yes | 5.9 | macOS bundles 5.9 by default; Homebrew zsh upgraded later |
| ggrep | lint patterns (LINT-02, LINT-03, LINT-05) | yes | GNU grep 3.12 | macOS BSD grep is a fallback for most patterns; ggrep gives more reliable `-E` extended-regex behavior |
| ripgrep (rg) | not required; nice-to-have | yes | 14.1.1 | not used in P2 lint patterns |
| shellcheck | NOT used in P2 (deferred) | yes (1.0.x) | -- | deferred to future hardening |
| sleep | bootstrap audit pause | yes (POSIX) | -- | none |
| sed | trim whitespace in cutover-gate | yes | macOS BSD sed | none -- uses portable patterns only |

**Missing dependencies with no fallback:** none -- everything Phase 2 needs is either in the P1 Brewfile or installed by bootstrap itself.

**Missing dependencies with fallback:**
- `ggrep`: planner can fall back to BSD `grep -E` if user objects to GNU dependency. Cost: less consistent `-E` behavior, especially for `\b` word boundaries on macOS BSD grep. Recommendation: KEEP `ggrep` -- it's already in v1 Brewfile and Phase 5 will declare it.

**Bootstrap acquires its own dependencies, so this audit primarily protects the lint suite's developer experience** (a developer running `task lint` on a fresh machine before bootstrap completes). Recommendation: lint sub-tasks should `command -v ggrep yq jq zsh` at start and emit a clear error if missing.

---

## 12. Security Domain

> Required because security_enforcement is enabled in default config (config.json shows no `security_enforcement: false`).

### 12.1 Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no auth in P2 (machine identity is filesystem state, not credential) |
| V3 Session Management | no | no sessions |
| V4 Access Control | partial | cutover-ack gate is a coarse access-control mechanism (machine-name match) |
| V5 Input Validation | yes | cutover-ack file contents validated by `read -r`; machine name validated against P1's `MACHINE_NAME_RE` |
| V6 Cryptography | partial | rely on Homebrew's SHA-256 bottle verification (do not hand-roll) |
| V14 Configuration | yes | bootstrap installs trust anchors with documented audit |

### 12.2 Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Compromised brew install script (CDN MITM) | Spoofing / Tampering | HTTPS only; documented as known trust boundary in `docs/SECURITY.md`; `AUDIT:` line + 3s pause for user abort |
| Curl-pipe-to-shell from untrusted source | Tampering | BTSP-02: NEVER use curl-pipe for go-task/yq; only for Homebrew installer (canonical source) |
| Unbound variable in bootstrap leading to wrong directory operations | Tampering | `set -u` in `set -euo pipefail` (BTSP-01) |
| Pipe-failure swallowed by bash exit code | Tampering | `set -o pipefail` in `set -euo pipefail` (BTSP-01) |
| Cutover-ack sentinel forged for wrong machine | Tampering / Privilege Escalation | Gate validates the machine name in the sentinel matches `$XDG_STATE_HOME/dotfiles/machine` (D-08) |
| Cutover-ack sentinel created with malformed content | Tampering | `read -r` parses two whitespace-separated fields; missing/empty fields fail the gate |
| Lint suite missing a status block bug class (false negative) | Tampering | Self-tested via positive + negative fixtures (§10.4); planner verifies fixture suite catches every documented v1 bug |
| Hostile machine name written to state file | Tampering | P1's `MACHINE_NAME_RE` regex rejects path-traversal characters; P2 inherits |

### 12.3 Specific defenses to call out for the planner

- **`bootstrap.zsh` first DOTFILEDIR resolve must be defensive.** Without `set -u` (i.e., on v1) an empty `${BASH_SOURCE[0]:-$0}` results in `dirname "" = "."`, silently. With `set -u` and the `:-$0` fallback, it works. **Verify in lint fixture.**
- **Cutover gate emits errors to STDERR**, not stdout. Goes through `error()` from messages.zsh. Critical for tooling that pipes stdout (e.g., a wrapper script that captures install output for a log).
- **Sentinel file is read with `read -r`** -- prevents backslash-escape interpretation. Two-field split-on-whitespace; extra fields ignored.
- **No secrets in `cutover-ack`** -- it's a UX gate, not an authentication mechanism. The contents are intentionally inspectable (machine name + timestamp).

---

## 13. Common Pitfalls

### Pitfall 1: `head -3` is too restrictive for LINT-04
**What goes wrong:** A scan of `head -3` flags `install/resolver.zsh` (false positive) because its `set -euo pipefail` is at line 30 (after a long header comment).
**Why it happens:** v1 conventions allow file-level header blocks of arbitrary length.
**How to avoid:** Use `head -30` for the LINT-04 grep window. Verified clean against existing repo.
**Warning signs:** lint fails on a script that visibly has `set -euo pipefail`.

### Pitfall 2: `yq '.tasks[].status'` returns a list of strings, not parsed shell
**What goes wrong:** Treating yq's output as parsed shell (e.g., trying to expand `$VAR`) misses what we actually want -- the literal text of the status block.
**Why it happens:** confused between yq's "give me the value" mode (`-r`) and its YAML-rendered output.
**How to avoid:** use yq without `-r` so the output is YAML quoted; then grep for `\$VAR` patterns in the literal text. Verified pattern in §5.2.
**Warning signs:** lint silently passes when a known-bad fixture should fail.

### Pitfall 3: `internal: true` tasks shouldn't be required to have `status:`
**What goes wrong:** Lint flags every internal helper as missing `status:`.
**Why it happens:** internal helpers are called by parent tasks whose `status:` covers them; requiring duplicate `status:` blocks is annoying and adds no correctness.
**How to avoid:** exempt `internal: true` tasks from LINT-03a. Verified in §5.4.
**Warning signs:** lint output is dominated by helper-task warnings.

### Pitfall 4: `command -v` is the right precheck, NOT `brew install`
**What goes wrong:** `brew install go-task` when go-task is already installed takes 1.3s and hits the formula-API endpoint. A naive bootstrap that runs `brew install` unconditionally re-fetches metadata on every run.
**Why it happens:** `brew install` is itself idempotent in the install sense, but not in the "do nothing when nothing needs doing" sense.
**How to avoid:** wrap every `brew install` in `command -v <bin> >/dev/null || brew install <pkg>`. Verified in §3.3.
**Warning signs:** bootstrap re-run takes >2s on a converged machine.

### Pitfall 5: The cutover-ack gate must check BEFORE `task install`'s deps run
**What goes wrong:** putting `cutover_gate_check` in `cmds:` means it runs AFTER `deps: [manifest:resolve]`. The user sees manifest:resolve output before the gate error, which is confusing.
**Why it happens:** go-task runs deps before cmds; preconditions run before deps.
**How to avoid:** put the gate in `preconditions:` block. Verified in §6.3.
**Warning signs:** test users report seeing manifest output before getting the cutover error.

### Pitfall 6: `task --list-all --json` returns 0 even when there are no tasks
**What goes wrong:** A taskfile with valid YAML but no `tasks:` block parses successfully -- the JSON output is `{"tasks": []}` and exit code 0.
**Why it happens:** go-task treats "no tasks" as a valid state.
**How to avoid:** for taskfiles that MUST have tasks (i.e., not stubs), add a separate check that `jq -e '.tasks | length > 0'` succeeds.
**Warning signs:** lint silently passes a taskfile that's actually broken.

### Pitfall 7: shellcheck would catch `local`-at-script-scope; `zsh -n` does not
**What goes wrong:** the v1 `claude/hooks/agent-transparency.zsh:11` bug (using `local` outside a function) parses cleanly via `zsh -n` but is a runtime hazard.
**Why it happens:** zsh accepts `local` at script scope as a no-op; shellcheck flags it as an error.
**How to avoid:** plan for shellcheck integration in a future hardening phase; for v2 P2, accept that LINT-07 (`zsh -n`) only catches parse errors. Document the gap explicitly in `taskfiles/lint.yml` comments.
**Warning signs:** runtime errors in a hook that lint says is clean.

### Pitfall 8: `find . -name '*.zsh'` traverses .planning/ which contains hundreds of irrelevant files
**What goes wrong:** lint slows down or finds irrelevant `.zsh` examples in research notes.
**How to avoid:** ALWAYS exclude `-not -path './.planning/*' -not -path './.git/*'`. Verified in §5.7 and §5.5.
**Warning signs:** lint runtime grows linearly with `.planning/` size; lint flags `.zsh` snippets in markdown.

---

## 14. Code Examples

### Example 1: Bootstrap step-3 (yq install with version check)

```zsh
# Source: §3.3 of this document, verified in this session
if ! command -v yq >/dev/null 2>&1; then
  info "installing yq..."
  brew install yq
else
  yq_ver=$(yq --version | sed -nE 's/.*version v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
  info "yq already installed: v${yq_ver}"
  if ! printf '%s\n%s\n' "4.52.1" "$yq_ver" | sort -V -C 2>/dev/null; then
    warn "yq v${yq_ver} is older than minimum 4.52.1 -- upgrade with: brew upgrade yq"
  fi
fi
```

### Example 2: LINT-02 detection pipeline

```bash
# Source: §5.2 of this document, verified against v1 taskfiles in this session
violations=0
for f in taskfiles/*.yml; do
  out=$(yq '.tasks[] | select(.status) | .status' "$f" 2>/dev/null \
        | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
        | ggrep -vE '\$\(' \
        | ggrep -vE '\{\{' || true)
  if [[ -n "$out" ]]; then
    error "LINT-02: \$VAR in status: block — $f"
    echo "$out" >&2
    violations=$((violations + 1))
  fi
done
exit $violations
```

### Example 3: Cutover-ack gate helper (canonical form)

```zsh
# Source: §6.2 of this document
cutover_gate_check() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  local machine_file="${state_dir}/machine"
  local ack_file="${state_dir}/cutover-ack"
  local active_machine ack_machine ack_ts

  [[ -f "$machine_file" ]] || { error "no machine selected (run: task setup -- <machine-name>)"; return 1; }
  active_machine=$(head -n1 "$machine_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  [[ -f "$ack_file" ]] || { _cutover_gate_emit_error "$active_machine" "missing"; return 1; }

  read -r ack_machine ack_ts < "$ack_file"
  [[ -n "$ack_machine" && -n "$ack_ts" ]] || { _cutover_gate_emit_error "$active_machine" "malformed"; return 1; }

  [[ "$ack_machine" == "$active_machine" ]] || { _cutover_gate_emit_error "$active_machine" "mismatch (sentinel claims '$ack_machine')"; return 1; }

  return 0
}
```

### Example 4: `task install` with cutover gate

```yaml
# Source: §4.1 of this document
install:
  desc: "Install dotfiles for active machine (canonical entry)"
  preconditions:
    - sh: |
        source "{{.DOTFILEDIR}}/install/cutover-gate.zsh"
        cutover_gate_check
      msg: "cutover-ack gate failed -- see actionable error above"
  deps: [manifest:resolve]
  cmds:
    - task: links:all
    - task: brew:install
    - task: claude:install
    - task: macos:defaults
    - task: macos:shell
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"
```

---

## 15. State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `bootstrap.zsh` `set -e` only | `set -euo pipefail` | v2 P2 (BTSP-01) | Catches unbound vars + pipe failures |
| go-task installed via `curl ... \| sh` | `brew install go-task` | v2 P2 (BTSP-02) | Removes third-party CDN trust boundary |
| Separate `task install` and `task update` | `task install` only (D-10) | v2 P2 (BTSP-06) | Eliminates drift class entirely |
| Hostname-based machine detection | Manifest + state file (P1, carries forward) | P1 | Removes the v1 `.zprofile:55-56` hostname bug class |
| `$VAR` in status: blocks (silent re-run bug) | `{{.X}}` template vars + LINT-02 enforcement | v2 P2 | Structural guarantee against the v1 `macos:shell:145` bug class |
| Bare `ln -s` scattered through taskfiles | `_:safe-link` helper + LINT-03b enforcement | P1 helper, P2 enforcement | Single sanctioned symlink path |
| Hand-rolled file-existence checks | `_:check-link`, `_:check-file`, `_:check-command` (P1) | P1 | Reusable patterns; P2 uses these in lint output |

**Deprecated/outdated:**
- v1's `taskfile.dev/install.sh` curl-pipe in bootstrap -- replaced by Homebrew install path
- v1's hostname-based 1Password gate (`.zprofile:55-56`) -- replaced by manifest feature flag `one-password-ssh` (consumed in P4)

---

## 16. Open Questions

1. **Should `task install` body be in `Taskfile.yml` root or in `taskfiles/install.yml`?**
   - What we know: P1 establishes the pattern of including modular taskfiles. P2 introduces 4-5 new sub-task includes (links, brew, claude, macos, lint).
   - What's unclear: whether `task install` is short enough to live in the root or warrants its own file.
   - Recommendation: keep in root `Taskfile.yml` for v1 of v2; the install body is ~10 lines including the cutover gate precondition. Split out only if it grows past 30 lines.

2. **Does the LINT-03a exemption for `internal: true` need to extend to tasks marked with `summary:` containing "VALIDATE" or "PRINT" keywords?**
   - What we know: tasks like `validate`, `status`, `manifest:show` legitimately have no install state to gate; they always re-run.
   - What's unclear: how the lint distinguishes "always-runs by intent" from "missing status by oversight."
   - Recommendation: require `status: [true]` (an explicit always-run marker) for these tasks. Keeps the lint binary: every task with cmds: has status:, period. Slight verbosity cost; significant clarity gain.

3. **Should the cutover-ack sentinel contain any other fields (commit SHA, dotfiles version, user)?**
   - What we know: D-08 specifies single-line `<name> <iso-ts>` only.
   - What's unclear: whether future audit needs (e.g., "which machines were cut over before commit X?") would benefit from richer sentinel.
   - Recommendation: keep the v1 contract minimal per D-08. If audit needs emerge, add a second log file (`$XDG_STATE_HOME/dotfiles/cutover-history.log`) -- separate concern from the gate.

4. **Should `task lint` itself be gated by cutover-ack?**
   - What we know: D-09 explicitly says lint is NOT blocked. This protects the dev iteration loop on the v2 branch (a developer can't lint without cutover -- bad UX).
   - What's unclear: nothing -- this is settled by D-09.

5. **`[ASSUMED]` Does `task --list-all --json -t <file>` validate the includes:` graph or only the single file?**
   - Risk: if it only validates the single file, our LINT-syntax check misses cross-file include errors.
   - Recommendation: planner verifies during implementation; if it only validates the single file, add a `task --list -t Taskfile.yml` invocation as the integration check (parses the entire include graph).

---

## 17. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Homebrew install script's URL `raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` will remain canonical for v2's lifetime | §3.2 | LOW -- if URL changes, bootstrap fails actionably (`curl: (22) HTTP 404`); planner updates URL |
| A2 | LINT-05 portability list (pbcopy, osascript, defaults, ...) is comprehensive enough for v1 | §5.6 | LOW -- it's WARN-only by D-13; missing patterns surface as "Linux v2 found a portability gap not flagged in v1" -- annoying, not breaking |
| A3 | `task --list-all --json` parses the entire includes: graph in addition to the root file | §5.8, §16 Q5 | LOW -- if it only parses the root, LINT-syntax adds `task --list` as a second check |
| A4 | `head -30` is enough lines to capture every legitimate `set -euo pipefail` line in v2 scripts | §5.5 | LOW -- if a future script has a 50-line header, false-positive lint failure surfaces immediately; planner bumps the head count |
| A5 | The 3-second `sleep` after the brew installer audit line is enough abort window without being annoying | §3.2 | LOW -- planner can tune (1s? 5s?) based on user feedback during cutover |
| A6 | `internal: true` taskfile attribute is the right LINT-03a exemption boundary | §5.4 | LOW -- if it produces false positives (an internal task that legitimately needs explicit status), planner adds `status: [true]` to that task |
| A7 | `read -r ack_machine ack_ts < "$ack_file"` correctly handles the documented sentinel format on macOS bash and zsh | §6.2 | LOW -- planner verifies during impl; fallback is `awk '{print $1, $2}'` |
| A8 | `task --status` (built-in flag) is NOT useful for our LINT-01 enforcement (it tests a single task, not the absence of `status:` blocks) | §5.4 | LOW -- different problem; we use yq AST inspection instead |

**This table has 8 entries.** All are LOW-risk operational details, not architectural decisions. Planner can proceed without user confirmation but should surface A3 and A4 during implementation in case fallback logic is needed.

---

## 18. Sources

### Primary (HIGH confidence — verified by running locally in this session, 2026-05-13)

- yq 4.53.2 query `'.tasks[] | select(.status) | .status'` against v1 taskfiles -- correctly extracts every status block content. `[VERIFIED 2026-05-13]`
- Detection pipeline `yq ... | ggrep -nE '\$[A-Z_]+' | ggrep -v '$('| ggrep -v '{{'` correctly identifies the `$BREW_ZSH` v1 bug at `taskfiles/macos.yml:145`. `[VERIFIED 2026-05-13]`
- `ggrep -rn -E '\bln\s+-s' taskfiles/ | ggrep -v helpers.yml` correctly identifies `taskfiles/links.yml:69` and `taskfiles/profile-tasks.yml:57` v1 bugs. `[VERIFIED 2026-05-13]`
- `yq` query for `cmds:`-without-`status:` correctly identifies `taskfiles/claude.yml:install`, `update`, `validate`, `status`, `gsd-install` as candidates; after `internal: true` exemption, the real positives match CONTEXT.md's expected v1 bug list. `[VERIFIED 2026-05-13]`
- `head -10 ... | ggrep -qE '^set -euo pipefail$'` flags `bootstrap.zsh` (BTSP-01 target) and `ssh/cloudflared.zsh` (legitimate gap). After bumping to `head -30` only `bootstrap.zsh` remains as an intended fix target. `[VERIFIED 2026-05-13]`
- `zsh -n` parses `bootstrap.zsh`, `install/messages.zsh`, `install/resolver.zsh`, all hooks cleanly. `[VERIFIED 2026-05-13]`
- `task --list-all --json -t taskfiles/macos.yml` returns valid JSON and exits 0 on parseable taskfile. `[VERIFIED 2026-05-13]`
- `brew install go-task` when already installed takes ~1.3s; `command -v brew && command -v task && command -v yq` takes 0.001s. The precheck-vs-no-precheck timing delta justifies §3.3's pattern. `[VERIFIED 2026-05-13]`
- `brew --version` = Homebrew 5.1.11; `task --version` = 3.50.0; `yq --version` = 4.53.2; `zsh --version` = 5.9; `ggrep --version` = GNU 3.12; `jq --version` = 1.8.1; `rg --version` = 14.1.1. `[VERIFIED 2026-05-13]`

### Primary (HIGH confidence — official docs)

- [Homebrew Installation docs](https://docs.brew.sh/Installation) — canonical install URL `raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`; HTTPS only; no checksum mention. `[CITED via WebFetch this session]`
- [go-task CLI reference — exit codes](https://github.com/go-task/task/blob/main/website/src/docs/reference/cli.md) — `--exit-code` flag passes through command exit code. `[CITED via Context7 /go-task/task this session]`
- [go-task templating reference — fromJson](https://taskfile.dev/reference/templating/) — `fromJson` for parsing JSON into map vars. `[CITED — used by P1 and inherited by P2]`
- [Phase 1 RESEARCH §6.4 preconditions pattern](/Users/josh/Git/personal/dotfiles/.planning/phases/01-manifest-engine-repository-skeleton/01-RESEARCH.md) — `preconditions:` `msg:` interpolation verified. P2 reuses this pattern for the cutover-ack gate. `[CITED]`
- [Phase 1 PATTERNS §`install/resolver.zsh`](/Users/josh/Git/personal/dotfiles/.planning/phases/01-manifest-engine-repository-skeleton/01-PATTERNS.md) — `set -euo pipefail` + double-source guard pattern; ported to bootstrap and cutover-gate. `[CITED]`

### Secondary (MEDIUM confidence — research notes carrying forward from P1)

- `.planning/research/STACK.md` — yq vs dasel, antidote/Starship picks. `[CITED]`
- `.planning/research/PITFALLS.md` — pitfalls 1-3 (drift, schema sprawl, merge ambiguity). `[CITED]`
- `.planning/codebase/CONCERNS.md` — every v1 bug enumerated above (`taskfiles/macos.yml:145`, `bootstrap.zsh:2`, `bootstrap.zsh:33`, `taskfiles/links.yml:66-70`, `taskfiles/claude.yml:211-219`, `claude/hooks/agent-transparency.zsh:11`). `[CITED + verified in this session]`
- [Brew Hijack: Serving Malware Over Homebrew’s Core Tap (Koi Security, 2025)](https://www.koi.ai/blog/brew-hijack-serving-malware) — context for the trust boundary documented in SECURITY.md (Step 1 risk acknowledgement). `[CITED via WebSearch this session]`

### Tertiary (LOW confidence — flagged for verification during implementation)

- A3 (does `task --list-all --json` parse includes? §16 Q5)
- A7 (`read -r` behavior on the cutover-ack file — verify during impl)

---

## Metadata

**Confidence breakdown:**
- Bootstrap design: HIGH — every step verified by reading existing v1 bootstrap and timing brew commands live
- Idempotency contract / install body: HIGH — D-10 (drop update) makes SC#2 trivial; LINT-01 makes timing test redundant
- Lint engine patterns: HIGH — every detection pipeline run live against existing v1 violations and confirmed
- Cutover-ack gate: MEDIUM — design is sound; planner verifies sentinel parsing against the eventual `task cutover:ack` writer in Phase 8
- SECURITY.md outline: HIGH — content directly reflects D-01..D-05 and verified Homebrew docs
- Validation architecture: HIGH — fixtures are self-testing; phase requirement coverage is complete

**Research date:** 2026-05-13
**Valid until:** 2026-06-12 (30 days; refresh if go-task or yq ships behavior-changing minor in window)
