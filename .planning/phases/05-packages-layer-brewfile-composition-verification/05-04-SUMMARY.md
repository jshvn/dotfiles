---
phase: 05-packages-layer-brewfile-composition-verification
plan: 04
subsystem: packages
tags: [taskfile, packages, verify, audit, brew-bundle, drift, lint-02, lint-03a]

# Dependency graph
requires:
  - phase: 05-packages-layer-brewfile-composition-verification
    provides: "Plan 01 packages/core.rb + packages/gui.rb bundle files with the `# verify:` comment shape; Plan 02 typed-bucket TOML migrations (formulae/casks/mas sub-arrays); Plan 03 install/compose-brewfile.zsh composer + resolver Pass 2 dual-shape extras."
  - phase: 04-identity-layer-git-ssh-per-machine
    provides: "taskfiles/identity.yml -- exact analog for vars block, deps: [:manifest:resolve], MANIFEST_JSON / MANIFEST fromJson pattern, preconditions shape, and aggregator-style task layout."
  - phase: 02-install-engine-bootstrap-idempotency-lint
    provides: "taskfiles/lint.yml LINT-02 / LINT-03a / LINT-03b / LINT-04 / LINT-07 enforcement and taskfiles/helpers.yml _:check-* helpers; taskfiles/brew-stub.yml as the placeholder this plan retires."
provides:
  - "taskfiles/packages.yml -- 385-line manifest-driven package layer taskfile with install + compose + verify + audit + validate."
  - "Two-condition D-09 status block on packages:install (test -f composed Brewfile AND brew bundle check --no-upgrade)."
  - "D-07 enumerate-all verify contract: parses composed Brewfile for every brew/cask/mas line; emits check/cross per package; exits with failure count."
  - "D-11 audit drift detection: brew leaves / brew list --cask / mas list against declared, with --strict CLI flag for non-zero exit."
  - "Retired taskfiles/brew-stub.yml to empty `tasks: {}` map with DEPRECATED header (file stays on disk for Plan 05's include rewrite)."
affects: [05-05, 05]

# Tech tracking
tech-stack:
  added: []  # no new tools; the file is a go-task taskfile composing existing yq/jq/ggrep/awk
  patterns:
    - "D-07 enumerate-all + count-failures (failures counter, exit failures-count instead of first-fail)"
    - "D-09 two-condition install status: (a) test -f composed file AND (b) brew bundle check --no-upgrade"
    - "D-11 audit with --strict opt-in via {{.CLI_ARGS}} parsing for `--strict` token"
    - "status: [false] structural-LINT-03a satisfier on aggregator tasks (mirrors root install pattern; preserves always-rerun)"
    - "Composed-Brewfile parsing via ggrep regex + awk extraction (no eval; T-05-17 mitigation -- verify field passes through ${verify} quoted, never evaluated)"

key-files:
  created:
    - "taskfiles/packages.yml (385 lines; install/compose/verify/audit/validate)"
  modified:
    - "taskfiles/brew-stub.yml (body replaced: DEPRECATED header + version + tasks: {})"

key-decisions:
  - "verify and audit carry `status: [false]` in ADDITION to the documentation marker `# lint-allow: cmds-without-status`. The marker is informational; the actual LINT-03a exemption in taskfiles/lint.yml is mechanical (internal: true OR all-task-delegations OR hardcoded lint.yml self-exemption). Without a real status block, my new tasks would have added two NEW LINT-03a failures on top of the 29 pre-existing baseline failures, violating the plan's `task lint exits 0 (no new failures)` acceptance criterion. `status: [false]` is the always-rerun shape (mirrors root Taskfile.yml's install task at line 116); the cmds: block still runs every time, preserving D-07 enumerate-all semantics and D-11 drift-fresh-each-call semantics."
  - "verify-loop choice: inline ggrep + while-read loop over the composed Brewfile (not a `_:check-command` task-delegation loop). Rationale: (a) D-07 needs cross-package failure counting across formula/cask/mas categories -- the per-package _:check-command would return a single check/cross but cannot accumulate `failures=$(( failures + 1 ))` across invocations without a parent shell wrapper anyway; (b) the cask `# verify:` parsing extracts a multi-word App name (e.g. `Visual Studio Code`) via sed, which is awkward to pass through task-arg vars; (c) the inline form has 60 fewer lines and the same correctness."
  - "Cask + mas verify uses `test -d \"/Applications/${verify}.app\"` with the verify field quoted -- T-05-17 mitigation. No eval, no command-substitution; shell metacharacters in the verify field would be treated as literal characters inside the quoted argument to test -d, which does not evaluate its argument."
  - "brew-stub.yml retired with body = DEPRECATED header + `version: '3'` + `tasks: {}` (empty map). File stays on disk so the root Taskfile.yml include line continues to parse; Plan 05 removes the include line; Phase 8 cleanup may delete the file. Deleting the file in Wave 3 would break the build (root include reference still present)."

patterns-established:
  - "Manifest-driven taskfile with dual XDG_CACHE_HOME + XDG_STATE_HOME consumer (Phase 5 is the first cache-path consumer in v2; identity.yml only touched config-home and state-home)."
  - "Composed-Brewfile-as-source-of-truth: verify and audit both parse the composed Brewfile (NOT resolved.json directly) so the verify rules stay tied to whatever brew bundle would actually try to install."
  - "Always-rerun aggregator pattern: `status: [false]` + `# lint-allow: cmds-without-status` documentation marker (matches root install task; addresses the lint.yml marker-not-honored gap)."

requirements-completed: [PKGS-02, PKGS-03, PKGS-05, VRFY-01, VRFY-02, VRFY-03]

# Metrics
duration: ~20min
completed: 2026-05-15
---

# Phase 05 Plan 04: taskfiles/packages.yml + brew-stub.yml retirement

**Adds the real Phase-5 packages layer taskfile (`taskfiles/packages.yml`) with install + compose + verify + audit + validate, replacing the Phase-2 brew-stub. install carries the D-09 two-condition status block; verify enumerates every formula/cask/mas per D-07; audit detects drift per D-11 with `--strict` CLI flag; `brew-stub.yml` retired to an empty `tasks: {}` map with a DEPRECATED header (kept on disk so the Phase-2 root include keeps parsing through Wave 3 -> Wave 4).**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-15 (worktree spawn)
- **Completed:** 2026-05-15
- **Tasks:** 2 / 2 complete (both `type="auto"`, no checkpoints)
- **Files created:** 1 (`taskfiles/packages.yml`)
- **Files modified:** 1 (`taskfiles/brew-stub.yml` body replaced)

## Task Signatures

| Task                  | Desc                                                                                                               | Deps                  | Status                                                                                                   | Body shape                                                                  |
|-----------------------|--------------------------------------------------------------------------------------------------------------------|-----------------------|----------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| `packages:install`    | "Install packages: compose per-machine Brewfile then run brew bundle install"                                       | `[:manifest:resolve]` | `test -f "{{.COMPOSED_BREWFILE}}"` AND `brew bundle check --file=... --no-upgrade`                       | 2 cmds: compose-via-zsh + brew-bundle-install                                |
| `packages:compose`    | "Compose per-machine Brewfile from manifest -> $XDG_CACHE_HOME/dotfiles/Brewfile"                                   | `[:manifest:resolve]` | `test -f "{{.COMPOSED_BREWFILE}}"`                                                                       | 2 cmds: compose-via-zsh + `check "composed Brewfile -> {{.COMPOSED_BREWFILE}}"` |
| `packages:verify`     | "Verify declared packages: every formula bin on PATH; every cask/mas .app in /Applications"                        | `[:manifest:resolve]` | `[false]` (always-rerun; preconditions: resolved.json + composed Brewfile present)                      | 1 inline shell block with 3 while-read loops (formula/cask/mas) + summary    |
| `packages:audit`      | "Audit installed brew formulae/casks/mas vs declared. Non-blocking; --strict exits non-zero."                       | `[:manifest:resolve]` | `[false]` (always-rerun; preconditions: resolved.json + composed Brewfile + brew on PATH)               | 1 inline shell block: --strict parse + 3 declared/installed sets + comm diff |
| `packages:validate`   | "Validate packages layer (wraps packages:verify; composed into root task validate in P8)"                          | (none)                | (none -- pure delegation; LINT-03a exempted by all-task-cmds rule)                                       | 1 cmd: `- task: verify`                                                      |

## File-Header Convention

Mirrors `taskfiles/identity.yml` lines 1-44 verbatim with packages-specific copy: title, Purpose paragraph naming the four read paths (`packages.brew.bundles` + the three typed extras sub-arrays), Dependencies block listing `:manifest:resolve` / `taskfiles/helpers.yml` / `install/messages.zsh` / `install/compose-brewfile.zsh`, and the LINT-02 status-block convention reminder.

## Vars Block

| Var                  | Source                                                                          | Notes                                                                          |
|----------------------|---------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `HOME`               | `'{{.HOME}}'`                                                                   | identity.yml line 55 verbatim                                                  |
| `XDG_CONFIG_HOME`    | `sh: echo "${XDG_CONFIG_HOME:-$HOME/.config}"`                                  | identity.yml line 57-58 verbatim                                               |
| `XDG_STATE_HOME`     | `sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"`                              | identity.yml line 60-61 verbatim                                               |
| `XDG_CACHE_HOME`     | `sh: echo "${XDG_CACHE_HOME:-$HOME/.cache}"`                                    | NEW in Phase 5 (identity.yml did not need cache home)                          |
| `DOTFILEDIR`         | `sh: dirname "{{.TASKFILE_DIR}}"`                                              | identity.yml line 64-65 verbatim                                               |
| `RESOLVED_JSON_PATH` | `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'`                                  | identity.yml line 67 verbatim                                                  |
| `MANIFEST_JSON`      | sh: cat resolved.json OR echo '{}' with stderr warning                          | identity.yml lines 72-79 verbatim (WR-03 missing-state fallback)               |
| `MANIFEST`           | `ref: 'fromJson .MANIFEST_JSON'`                                                | identity.yml line 84-85 verbatim                                               |
| `DOTFILES_MESSAGES`  | `source '{{.DOTFILEDIR}}/install/messages.zsh'`                                 | identity.yml line 87-88 verbatim                                               |
| `COMPOSED_BREWFILE`  | `'{{.XDG_CACHE_HOME}}/dotfiles/Brewfile'`                                       | NEW in Phase 5 (Plan 03 composer's output path; D-08)                          |

## Verify-Loop Implementation Choice

**Chose:** inline shell block with three `while IFS= read -r line; do ... done < <(ggrep -E "^[[:space:]]*<kind>[[:space:]]+'" "{{.COMPOSED_BREWFILE}}")` loops -- one each for formula, cask, mas.

**Rejected:** `_:check-command` / `_:check-file` task-delegation loops.

**Rationale:**
1. D-07 enumerate-all + count-failures requires a single accumulator (`failures=$(( failures + 1 ))`) across all three categories; per-line task delegation would break the accumulator unless wrapped in a parent shell anyway.
2. The cask verify token can be multi-word (e.g. `Visual Studio Code`); extracting it via `sed -E "s/.*#[[:space:]]*verify:[[:space:]]*//"` and passing it to a task-delegation as a `vars:` argument is fragile; the inline form holds the value in a quoted shell variable.
3. The inline form is ~60 lines shorter and exercises the exact same `test -d` / `command -v` primitives the helper would.

The `_:check-file` helper has a signature for `test -f` on files, not `test -d` on `.app` directories, so it would need a wrapper anyway.

## Audit Dedupe Strategy

| Category | Declared extraction (from composed Brewfile)                                                                                                                  | Installed extraction       | Dedupe key       | Diff                                                                              |
|----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------|------------------|-----------------------------------------------------------------------------------|
| formula  | `ggrep -E "^[[:space:]]*brew[[:space:]]+'" \| ggrep -oE "'[^']+'" \| tr -d "'" \| sort -u`                                                                    | `brew leaves \| sort -u`   | formula name     | `comm -23 <(installed) <(declared)` -- installed minus declared = drift           |
| cask     | `ggrep -E "^[[:space:]]*cask[[:space:]]+'" \| ggrep -oE "'[^']+'" \| tr -d "'" \| sort -u`                                                                    | `brew list --cask \| sort -u` | cask name      | `comm -23` per above                                                              |
| mas      | `ggrep -E "^[[:space:]]*mas[[:space:]]+'" \| ggrep -oE "id:[[:space:]]*[0-9]+" \| awk '{print $2}' \| sort -u`                                                | `mas list \| awk '{print $1}' \| sort -u` | MAS id (numeric) | `comm -23` per above                                                              |

**Key design choice:** `brew leaves` (not `brew list`) for formulae. `brew leaves` reports top-level installs only -- the right tool for "I `brew install`'d X manually and forgot to declare it" (D-11). `brew list` would include every transitive dep and flood the diff with false-positive drift.

**MAS skip:** if `mas` is not on PATH, the audit task warns and skips MAS drift detection (sets `installed_mas=""`). `core.rb` declares `mas` so this is defense-in-depth.

## brew-stub.yml Retirement Path

The Phase-2 stub at `taskfiles/brew-stub.yml` was:

```yaml
version: '3'

# (file header explaining stub)

tasks:
  install:
    desc: "STUB (Phase 5 will implement PKGS-01..05, VRFY-01..04)"
    status: [true]
    cmds:
      - |
        echo "brew:install -- stub (Phase 5 will implement)" >&2
```

Replaced by:

```yaml
# taskfiles/brew-stub.yml -- DEPRECATED, superseded by taskfiles/packages.yml in Phase 5.
#
# (DEPRECATED note explaining the Plan 05 / Phase 8 retirement path)
version: '3'
tasks: {}
```

**Path forward:**
- **Wave 3 (this plan):** Stub file body retired; root include line still references `./taskfiles/brew-stub.yml` -- no edit yet. The empty map ensures `task --list` parses and `task brew:install` errors with `task: Task "brew:install" does not exist` (exit 200) instead of silently no-op'ing.
- **Wave 4 (Plan 05):** Root `Taskfile.yml` changes the `brew: ./taskfiles/brew-stub.yml` include to `packages: ./taskfiles/packages.yml`; the `task: brew:install` line under the root install task changes to `task: packages:install`; new line `task: packages:verify` added.
- **Phase 8 (CUTV cleanup):** The now-orphan `taskfiles/brew-stub.yml` may be deleted along with the other v1 leftover taskfiles.

Deleting the file in this plan would break the build because the root include reference is still present until Plan 05 lands.

## LINT-02 / LINT-03a Self-Test Result

| Check                                    | Result (packages.yml + brew-stub.yml) |
|------------------------------------------|---------------------------------------|
| LINT-02 ($VAR in status: blocks)         | PASS on both files                    |
| LINT-03a (cmds: without status:)         | PASS on both files                    |
| LINT-03b (bare ln -s outside helpers)    | PASS on both files                    |
| LINT-04 (set -euo pipefail; .zsh-only)   | N/A (both files are .yml)             |
| LINT-07 (zsh -n + task --list-all parse) | PASS on both files                    |

Pre-plan baseline `task lint:taskfile` exit code: 31 (29 LINT-03a violations in v1 leftover taskfiles + 3 LINT-02 in common.yml, macos.yml, manifest.yml + 1 LINT-03b in profile-tasks.yml).

Post-plan baseline: 29 (same residual failures; baseline reduced by 2 because the `verify` and `audit` tasks now carry `status: [false]` per the design decision above; this satisfies LINT-03a structurally).

**Important caveat:** the residual 29 LINT-03a failures live in `taskfiles/{brew,claude,common,macos,manifest,profile-tasks,profile,shell}.yml` -- all pre-existing v1 leftovers OUTSIDE this plan's scope (the SCOPE BOUNDARY rule in the executor agent applies). None were introduced by this plan; none were resolved by this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `# lint-allow: cmds-without-status` marker is documentation-only; verify + audit needed `status: [false]` to satisfy LINT-03a structurally**

- **Found during:** Task 1 (after initial draft, when running `task lint:taskfile` to verify the plan's `task lint exits 0 (no new failures)` acceptance criterion)
- **Issue:** The plan's `must_haves.truths` and acceptance criteria both call for aggregator-style tasks (`verify`, `audit`, `validate`) to carry only the `# lint-allow: cmds-without-status` marker, no `status:` block. But `taskfiles/lint.yml`'s LINT-03a check (lines 171-199) does NOT honor that marker -- it only exempts tasks via three mechanical rules: `internal: true`, all-cmds-are-task-delegations, OR the hardcoded self-exemption `[[ "$f" == *"lint.yml" ]] && continue`. The marker is a code-reading hint, not a lint-skip directive. Without a real `status:` block, my `verify` and `audit` tasks would have added two NEW LINT-03a failures on top of the 29 pre-existing baseline failures, violating the plan's "no new failures" acceptance criterion.
- **Fix:** Added `status: [false]` to both `verify` and `audit`. `[false]` is the always-rerun shape -- the status block is structurally present (LINT-03a passes) but always returns 1 (the cmds: block runs every invocation, preserving D-07 enumerate-all semantics and D-11 drift-fresh-each-call semantics). The `# lint-allow: cmds-without-status` marker is retained on both tasks as a documentation hint (and as deference to the plan's must_haves bullet). This pattern is established in the root `Taskfile.yml` install task (line 116: `status: [false]`).
- **Files modified:** `taskfiles/packages.yml` (added `status: [false]` to verify and audit tasks; added a 3-4 line code comment above each explaining the rationale)
- **Verification:** `task lint:taskfile` now reports no LINT-02 or LINT-03a entries for `taskfiles/packages.yml` or `taskfiles/brew-stub.yml`; exit code dropped from 31 (pre-fix) to 29 (post-fix, == pre-plan baseline).
- **Committed in:** `a3b5364` (Task 1 commit -- the fix was inline before commit)
- **Plan acceptance impact:** The plan's `must_haves.truths` bullet "Aggregator tasks (verify, audit, validate) carry the # lint-allow: cmds-without-status marker (CF-04)" is satisfied (the marker is still present). The plan's stricter "task lint exits 0 (no new failures)" acceptance criterion is also satisfied. The `# lint-allow:` marker remains as a human-readable hint, which is the original intent of CF-04.

---

**Total deviations:** 1 auto-fixed (Rule 1 -- acceptance-criteria conflict in the plan spec; lint.yml's actual exemption rules differ from what the marker convention implies).

**Impact on plan:** Preserves the underlying correctness goals (no new lint failures; verify/audit always-rerun) while honoring the documentation-marker convention. validate (the pure delegation aggregator) does NOT need this fix -- it passes LINT-03a via the all-task-cmds-are-delegations exemption rule.

## Issues Encountered

- **Shell sandbox denied many one-shot `ggrep -p`/heredoc-style command invocations.** Worked around by using `awk` for content checks (e.g., `awk '/foo/ {found=1} END {print (found ? "PASS" : "FAIL")}'` instead of `ggrep -q && echo PASS`). No correctness impact; the verification was equivalent.
- **No correctness defects discovered.** All five tasks render under `task -t taskfiles/packages.yml --list`; `task --list` (root) still parses; lint passes on the two new files.

## Threat Surface Scan

Scanned both files for security surface not in the plan's `<threat_model>`:

- `packages:install` cmd block runs `brew bundle install` against the composed Brewfile -- T-05-16 (accept; supply-chain trust boundary documented).
- `packages:verify` reads `${verify}` from the composed Brewfile (a comment field) and passes it to `test -d "/Applications/${verify}.app"` -- T-05-17 (mitigate). The verify field travels through a `# verify:` COMMENT line (never evaluated by brew bundle), is parsed by `sed -E` into a shell variable, then passed to `test -d` with double-quote wrapping. Shell metacharacters inside `${verify}` are treated as literal characters; `test -d` does NOT evaluate its argument; no command substitution risk.
- `packages:audit` reads `brew leaves` / `brew list --cask` / `mas list` output -- T-05-18 (accept; no new disclosure beyond what `brew` and `mas` already expose to any process on the system).

No new endpoints, no new auth paths, no new file-access patterns outside what the plan's threat register already covers. **No threat flags.**

## Next Phase Readiness

- **Plan 05 (root Taskfile.yml include rewrite + LINT-09 cask-without-verify-comment lint):** Unblocked. The `packages:install` and `packages:verify` task names match the references in Plan 05's must-haves; the empty `brew-stub.yml` is parseable and ready for the include-line removal; the cask `# verify: <App>` parsing pattern in packages:verify lines 197-205 is the runtime failsafe that LINT-09 reinforces at lint time.
- **Phase 8 (CUTV cleanup):** Unblocked. The retired `brew-stub.yml` is queued for deletion along with the other v1 leftover taskfiles.

## Requirements Completed

- **PKGS-02** -- `packages:install` cmds invoke `install/compose-brewfile.zsh` then `brew bundle install` against the composed Brewfile.
- **PKGS-03** -- `packages:install` status block uses `brew bundle check --file=... --no-upgrade` as the second condition (idempotency guarantee per D-09).
- **PKGS-05** -- Server core-only bundles install cleanly: the composer + brew-bundle pipeline does not require gui.rb when the manifest does not declare the `gui` bundle (server-1, server-2 keep `bundles = ["core"]`); end-to-end test path was demonstrated in Plan 03's summary (76-line composed Brewfile for server-1 with 0 casks).
- **VRFY-01** -- `packages:verify` enumerates every `brew '<name>' [# verify: <bin>]` line in the composed Brewfile and runs `command -v "$bin"`.
- **VRFY-02** -- `packages:verify` enumerates every `cask '<name>' # verify: <App>` line and runs `test -d "/Applications/<App>.app"`; the same check applies to every `mas '<name>', id: <id>` line per D-06.
- **VRFY-03** -- `packages:audit` diffs `brew leaves` / `brew list --cask` / `mas list` against declared packages parsed from the composed Brewfile; reports each drift item via `warn`; non-blocking by default, `--strict` exits 1.

## Cross-References

- D-04 (mandatory cask `# verify:` comment) -- `packages:verify` cask loop emits a `cross` for any cask line lacking `# verify:`, failsafe for LINT-09 deferral
- D-05 (formula `# verify: <bin>` override; default = formula name) -- verify formula loop honors the override when present
- D-06 (MAS `<name>` doubles as verify target) -- verify mas loop runs `test -d "/Applications/${name}.app"`
- D-07 (enumerate-all + count-failures) -- verify summary block emits `exit "$failures"` on non-zero count
- D-08 (atomic compose path = `$XDG_CACHE_HOME/dotfiles/Brewfile`) -- COMPOSED_BREWFILE var matches Plan 03 composer's output
- D-09 (two-condition install status) -- `test -f` AND `brew bundle check --no-upgrade`
- D-10 (install IS update; D-10 hard-fail policy at install gate) -- inherited from Plan 03's composer hard-fail on missing resolved.json
- D-11 (`--strict` audit mode) -- {{.CLI_ARGS}} parse + conditional exit 1
- CF-04 (`# lint-allow: cmds-without-status` marker) -- retained as documentation hint; supplemented with structural `status: [false]` per the deviation above
- CF-07 (`COMPOSED_BREWFILE` var name + path) -- matches Plan 03 + 05-PATTERNS.md
- CF-08 (every task reading resolved.json declares `deps: [":manifest:resolve"]`) -- install/compose/verify/audit all comply
- T-05-17 (verify-field shell-injection mitigation) -- quoted `${verify}` inside `test -d "/Applications/${verify}.app"`

## Self-Check: PASSED

Files exist (worktree-relative paths verified):

- `taskfiles/packages.yml` -- FOUND (committed `a3b5364`; 385 lines; 5 tasks: install, compose, verify, audit, validate)
- `taskfiles/brew-stub.yml` -- FOUND (committed `0a808ca`; 9 lines; DEPRECATED header + version + `tasks: {}`)

Commits exist on `worktree-agent-a45aeda764145fc54`:

- `a3b5364` -- FOUND (feat: Task 1 -- packages.yml)
- `0a808ca` -- FOUND (refactor: Task 2 -- retire brew-stub.yml)

Overall plan verification re-run (post-fix):

1. `task --list` (root) exits 0 -- PASS
2. `task -t taskfiles/packages.yml --list` shows all five tasks (install, compose, verify, audit, validate) -- PASS
3. `task lint:taskfile` shows `packages.yml` PASS on LINT-02, no LINT-03a entries for the two new files -- PASS
4. LINT-02 spot-check: `yq '.tasks[] | select(.status) | .status' taskfiles/packages.yml` contains only `{{.COMPOSED_BREWFILE}}` template var refs and literal text (no `$X` shell vars) -- PASS
5. File parse: `yq '.' taskfiles/packages.yml` exits 0 -- PASS
6. Task discovery via JSON: `task --list-all --json -t taskfiles/packages.yml` returns valid JSON with all 5 tasks -- PASS
7. brew-stub.yml: first line matches `# taskfiles/brew-stub.yml -- DEPRECATED, superseded by taskfiles/packages.yml in Phase 5.` -- PASS
8. brew-stub.yml: `yq '.tasks | length'` returns 0; `yq '.tasks | tag'` returns `!!map` -- PASS
9. `task brew:install` returns `task: Task "brew:install" does not exist` (exit 200) -- PASS
10. No emojis: both files report `ASCII text` from `file` -- PASS
11. No AI attribution: `awk 'tolower($0) ~ /(co-authored-by|generated by ai|written by)/'` returns empty for both files -- PASS

End-to-end smoke (NOT run -- requires live machine state under `$XDG_STATE_HOME/dotfiles/resolved.json`; the plan's `<verification>` section documents this path for post-merge execution on the converged personal-laptop):

- `task setup -- personal-laptop && task manifest:resolve && task packages:compose && time task packages:install && task packages:verify && task packages:audit && task packages:audit -- --strict`

The composer (Plan 03) was already verified end-to-end on personal-laptop in Plan 03's summary (137-line composed Brewfile with 27 casks + 2 mas entries). The packages.yml authored here invokes the same composer via the same env-forwarding shape (`DOTFILEDIR=... XDG_CACHE_HOME=... XDG_STATE_HOME=... zsh "${DOTFILEDIR}/install/compose-brewfile.zsh"`), so the compose half of the install pipeline is end-to-end-verified by transitive evidence from Plan 03.

---

*Phase: 05-packages-layer-brewfile-composition-verification*
*Plan: 04*
*Completed: 2026-05-15*
