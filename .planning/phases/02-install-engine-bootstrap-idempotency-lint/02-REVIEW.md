---
phase: 02-install-engine-bootstrap-idempotency-lint
status: needs_attention
generated: 2026-05-13
depth: standard
files_reviewed: 9
findings:
  critical: 1
  warning: 3
  info: 6
---

# Phase 02 Code Review

Scope: 9 production source files shipped by Phase 2 (bootstrap.zsh,
install/cutover-gate.zsh, Taskfile.yml, taskfiles/lint.yml, four stub
taskfiles, docs/SECURITY.md). Lint fixtures excluded — they are
intentionally broken probes for the lint suite's self-test runner.

## Critical

### C-01 — `read -r` under bootstrap's `set -e` may exit before emitting malformed-ack error

**File:** `install/cutover-gate.zsh:46`

`cutover_gate_check()` does:
```zsh
read -r ack_machine ack_ts < "$ack_file"
if [[ -z "$ack_machine" || -z "$ack_ts" ]]; then
  _cutover_gate_emit_error "$active_machine" "malformed"
  return 1
fi
```

When called from `bootstrap.zsh` (which has `set -euo pipefail`), the
sourced function inherits the caller's shell options. If `ack_file`
exists but is empty (touch'd with no content), `read` returns non-zero
on EOF, and `set -e` may abort the function before the `[[ -z ]]` check
runs. The user sees a silent exit instead of the actionable
"machine '...' is not cut over to v2 (malformed)..." block.

**Impact:** D-09 contract states the gate "produces" an actionable
error for malformed sentinels. The bootstrap path silently exits on
empty ack file. The go-task `preconditions:` path is unaffected (no
`set -e` in that context).

**Suggested fix:** make the read tolerant — `read -r ack_machine ack_ts < "$ack_file" || true` — then the existing `[[ -z ... ]]` check fires
correctly.

## Warning

### W-01 — `MANIFEST_JSON: sh:` runs unconditionally on every `task lint` invocation

**File:** `Taskfile.yml:61-68`

The root `vars:` block defines `MANIFEST_JSON` with an `sh:` body that
emits `warn: resolved.json not found...` to stderr when the file is
absent. go-task evaluates root vars on every task invocation, including
read-only tasks like `task lint`.

**Impact:** CONTEXT explicitly states (D-09 commentary): "Lint reads
from disk only — no manifest dependency, no `resolved.json` dependency."
Currently, a fresh-checkout `task lint` always spews the warning even
though lint never reads MANIFEST. Contract violation.

**Suggested fix:** lazily reference MANIFEST_JSON only where consumed
(no consumer in P2 yet — the var ships for P3+ consumers). Either gate
the warning behind a `task: install`-only trigger, or accept the noise
until P3 wires real consumers.

### W-02 — LINT-02 doesn't scan `preconditions:` blocks

**File:** `taskfiles/lint.yml:140-152`

LINT-02 extracts `$VAR` patterns from
`.tasks[] | select(.status) | .status` — only top-level task `status:`
blocks. But the same `$VAR`-in-shell-eval bug class applies to
`preconditions:` `sh:` blocks. The root `Taskfile.yml:106-114` install
task uses a `preconditions: sh:` that exports `DOTFILEDIR` and
references shell variables; a future regression that introduces `$VAR`
without `:-` defaults would not be caught.

**Impact:** Coverage gap.

**Suggested fix:** extend `lint:taskfile` to also scan
`.tasks[] | .preconditions[]? | .sh` for the same `$VAR` pattern, or
document the gap as accepted for v1.

### W-03 — `${BASH_SOURCE[0]:-$0}` is a fragile zsh idiom under env injection

**File:** `bootstrap.zsh:34`

The bootstrap re-resolves `DOTFILEDIR` from `${BASH_SOURCE[0]:-$0}`.
In zsh, `BASH_SOURCE` is not a native array; the bracket-index expansion
behavior on an env-set `BASH_SOURCE` (scalar) is option-dependent and
not portable. SECURITY.md claims this defends against hostile
`$DOTFILEDIR` env override — the defense is real but the mechanism is
subtler than the doc suggests.

**Impact:** Low-likelihood security mismatch between doc claim and code
behavior. Not exploitable in practice on macOS zsh defaults.

**Suggested fix:** prefer the zsh-native pattern from `.claude/CLAUDE.md`
(`SOURCE="${(%):-%N}"`), or document the actual mechanism more
precisely in SECURITY.md.

## Info

### I-01 — `head -30` magic number in LINT-04 may miss `set -euo pipefail` past line 30

**File:** `taskfiles/lint.yml:206, 209`

`head -30 "$f" | ggrep -qE '^set -euo pipefail$'` assumes the
strict-mode header lands in the first 30 lines. The current bootstrap
(with a 27-line header banner) is fine, but a file with a longer comment
block would register a false LINT-04 violation.

**Suggested fix:** raise to `head -50` or allow leading whitespace.

### I-02 — yq version parser depends on "version v" substring

**File:** `bootstrap.zsh:98`

`sed -nE 's/.*version v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'` assumes
`yq --version` output contains "version v". Other yq implementations
(Python `kislyuk/yq`) and very old versions of `mikefarah/yq` use
different formats. Empty `yq_ver` flows into the version compare and
triggers a warn with a cosmetically broken message ("yq v is older
than minimum").

**Suggested fix:** if empty `yq_ver`, print a clearer message and skip
the version compare.

### I-03 — Empty `machine_file` produces "machine '' is not cut over" error

**File:** `install/cutover-gate.zsh:39`

If `$XDG_STATE_HOME/dotfiles/machine` is a zero-byte file, the trimmed
`active_machine` is empty and the downstream error prints
`machine '' is not cut over to v2`. Cosmetic.

**Suggested fix:** after the trim, if empty, emit the same
"no machine selected" error as the missing-file branch.

### I-04 — Duplicate `find ... -maxdepth 1 -name '*.yml'` invocations

**File:** `taskfiles/lint.yml:105, 152, 189`

Three separate `find {{.DOTFILEDIR}}/taskfiles -maxdepth 1 -name '*.yml'`
calls. The file already declares `TASKFILE_GLOB: 'taskfiles/*.yml'` at
line 43, but the find invocations don't use it.

**Suggested fix:** consolidate to a single shared loop or reuse
`TASKFILE_GLOB`.

### I-05 — `find -perm +111` is macOS-only

**File:** `taskfiles/lint.yml:212`

The `-perm +111` syntax is BSD-find (macOS); GNU `find` requires
`-perm /111`. v1 targets macOS, but a Linux port will need this fixed.

**Suggested fix:** add a comment marking the call site as
macOS-only, or use a portable alternative when Linux scope is added.

### I-06 — `Taskfile.yml` `set: [errexit, pipefail]` is missing `nounset`

**File:** `Taskfile.yml:28`

CLAUDE.md says the project standard is `set -euo pipefail`. The root
Taskfile uses `set: [errexit, pipefail]` — no `nounset`. Probably
intentional but no comment explains the choice.

**Suggested fix:** add an inline comment explaining the omission, or
include `nounset` and convert vulnerable expansions to `${VAR:-}`.

## Notes

- `docs/SECURITY.md` is well-structured; the Threat Model table covers
  the bootstrap surface adequately.
- The lint suite's self-test runner (Plan 02-05) correctly handles all
  11 fixture cases; the case-statement dispatching is sound.
- The stub taskfiles (links/brew/claude/macos) are minimal and pass
  Plan 02-01's lint suite; they grep-find correctly for the
  `STUB (Phase X)` marker as the planner intended.
- The cutover-gate's double-source guard and emit_error helper are
  textbook-correct.

## Carry-forward

The C-01 fix is a one-line change in `install/cutover-gate.zsh`. Worth
landing as a follow-up before Phase 4. The W-01 manifest-noise issue
is cosmetic for P2 but should be addressed before P3 wires real
MANIFEST consumers.
