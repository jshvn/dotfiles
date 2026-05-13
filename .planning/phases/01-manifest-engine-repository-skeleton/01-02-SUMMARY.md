---
phase: 01-manifest-engine-repository-skeleton
plan: 02
subsystem: manifest-engine
tags: [resolver, manifest, yq, jq, deep-merge, zsh, schema, validation]

# Dependency graph
requires:
  - 01-01 fixtures (defaults.toml + machine.toml + expected.json under manifests/test/fixtures/)
provides:
  - install/resolver.zsh -- three-mode resolver (resolve | --validate-only | --stdout)
  - manifests/defaults.toml -- shared baseline TOML (D-05 hybrid pattern)
  - Four machine manifests (personal-laptop, work-laptop, server-1, server-2) that
    each pass --validate-only with zero errors
  - manifests/README.md and manifests/machines/README.md
affects:
  - 01-03-taskfile-manifest (Plan 03 will wire taskfiles/manifest.yml against this resolver)
  - 01-04-skeleton (Plan 04 may reference defaults.toml schema for docs/MANIFEST.md)
  - every downstream phase that reads $XDG_STATE_HOME/dotfiles/resolved.json

# Tech tracking
tech-stack:
  added: []  # yq + jq + zsh were already in Phase 1 stack
  patterns:
    - "Three-pass merge pipeline: yq deep-merge -> jq union+dedupe for extra_packages -> arch backfill via uname -m"
    - "Atomic write via mktemp + mv (T-MAN-03 mitigation)"
    - "Hand-rolled D-03 validator using yq has() + tag predicates (no JSON Schema dep)"
    - "Machine-name regex guard (^[a-z0-9_][a-z0-9_-]*$) against path traversal"
    - "Pre-initializing DOTFILES_MESSAGES_LOADED before sourcing messages.zsh so the v1 library safely loads under set -u"
    - "Loop variable named field_path (not path) -- avoids shadowing zsh's special tied $path array"

key-files:
  created:
    - install/resolver.zsh
    - manifests/defaults.toml
    - manifests/machines/personal-laptop.toml
    - manifests/machines/work-laptop.toml
    - manifests/machines/server-1.toml
    - manifests/machines/server-2.toml
    - manifests/README.md
    - manifests/machines/README.md
  modified: []

key-decisions:
  - "Allowed underscore as a leading char in the machine-name regex so test/negative fixtures (e.g. _invalid-bad-os) can be passed to --validate-only. Path-traversal characters (/, ., .., spaces) remain rejected."
  - "Adopted `jq -s 'add | unique'` for extra_packages union+dedupe -- emits sorted output, which matches Plan 01 fixture 06's expected.json (['docker-desktop','jq','yq']) exactly."
  - "Renamed the validator's loop variable from `path` to `field_path`. zsh ties `path` to `$PATH` as an array; declaring `local path` inside a function empties $PATH for the function scope, breaking all external command lookups."
  - "Pre-initialized DOTFILES_MESSAGES_LOADED with `: ${VAR:=}` before sourcing the v1 messages.zsh library. The v1 library uses bare `$DOTFILES_MESSAGES_LOADED` in its double-source guard, which aborts under `set -u`. Treated as Rule 3 (auto-fix blocking issue) -- did not modify the v1 file (parallel-rewrite invariant)."
  - "Resolver writes resolved.json atomically via `mktemp + mv` with explicit cleanup on failure. T-MAN-03 mitigation enables Plan 03's downstream tasks to read via `fromJson` without partial-file races."

patterns-established:
  - "Pattern: three-pass merge -- one yq deep-merge pass for maps+arrays, one jq union+dedupe pass for extra_packages, one fall-through pass to backfill platform.arch."
  - "Pattern: hand-rolled validator returns the error count via stdout; caller compares to 0. All errors written to stderr via the messages library's `error` function (writes to stderr)."
  - "Pattern: machine-name guard runs BEFORE any filesystem access (regex validate, then construct canonical path, then equality-check against the canonical form)."

requirements-completed: [MFST-01, MFST-02, MFST-04]

# Metrics
duration: ~30 min
completed: 2026-05-13
---

# Phase 01 Plan 02: Manifest Resolver Summary

**The keystone manifest layer is live: `install/resolver.zsh` compiles `manifests/defaults.toml` plus the active machine's TOML into `$XDG_STATE_HOME/dotfiles/resolved.json` via a verified three-pass yq+jq pipeline, enforces the D-03 required-field schema, and writes atomically — and the four real machine manifests every downstream phase will consume now exist on disk and validate clean.**

## Performance

- **Duration:** approx 30 min
- **Tasks:** 2
- **Files created:** 8 (1 zsh executable + 5 TOMLs + 2 READMEs)

## Accomplishments

- **`install/resolver.zsh`** implements the full contract from the plan's `<interfaces>` block:
  - Resolve mode (default invocation): reads `$XDG_STATE_HOME/dotfiles/machine`, performs the three-pass merge, atomically writes `resolved.json`.
  - `--validate-only --machine <name>`: runs the D-03 required-field validator + D-01 os enum check + D-04 unknown-key warnings; exits 1 on hard errors, exits 0 with stderr warnings on unknown keys.
  - `--machine <name> --stdout`: ad-hoc resolve to stdout (used by the future `manifest:show` task).
- Verified yq deep-merge expression `yq eval-all '. as $i ireduce ({}; . * $i)'` ports cleanly from RESEARCH section 4.2 — runs against the four real manifests and produces the expected `resolved.json` shape end-to-end.
- Verified `jq -s 'add | unique'` for the extra_packages union matches Plan 01 fixture 06's expected output exactly (`["docker-desktop","jq","yq"]` — alphabetical).
- `uname -m` arch backfill works: `work-laptop.toml` omits `platform.arch`, and the resolver fills it with `arm64` from the running host.
- Hand-rolled validator catches both negative fixtures (`_invalid-missing-desc` reports `missing required field: meta.description`; `_invalid-bad-os` reports `platform.os must equal "darwin" in v1; got: linux`).
- Path-traversal guard rejects `--machine '../etc/passwd'` and `--machine 'foo/bar'` with `invalid machine name` error and exit 1.
- D-16 missing-state behavior: when `$XDG_STATE_HOME/dotfiles/machine` is absent, the resolver prints the actionable `no machine selected` + `run: task setup -- <name>` + `available: <list>` to stderr and exits 1.
- Four machine manifests authored to the schema in RESEARCH section 3.2; each validates clean against its own resolver (`--validate-only --machine <name>` returns 0).
- Two READMEs authored within the plan's line budgets (manifests/ = 18 lines; manifests/machines/ = 6 lines).

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement `install/resolver.zsh`** — `fb21779` (feat)
2. **Task 2: Author defaults.toml, four machine manifests, two READMEs** — `9824f89` (feat)

## Files Created

- `install/resolver.zsh` — 434 lines; `set -euo pipefail` strict mode; `zsh -n` clean; executable bit set.
- `manifests/defaults.toml` — schema_version + meta + platform + features + packages.brew + identity; safe baseline values for every D-03 required field.
- `manifests/machines/personal-laptop.toml` — identity=personal, arch=arm64, full feature set, bundles=`["core","gui","dev","personal"]`, extras=`["docker-desktop"]`.
- `manifests/machines/work-laptop.toml` — identity=work, no arch (resolver backfills), GUI + dev (no personal), bundles=`["core","gui","dev"]`.
- `manifests/machines/server-1.toml` — identity=none, core bundle only, no GUI flags, `claude-marketplace=false`.
- `manifests/machines/server-2.toml` — identical schema to server-1 (different `meta.description` only).
- `manifests/README.md` — 18-line overview pointing to `defaults.toml`, `machines/`, `test/`, and `docs/MANIFEST.md`.
- `manifests/machines/README.md` — 6-line stub with see-also link and add-a-machine one-liner.

## Verification

- `zsh -n install/resolver.zsh` parses cleanly (Tier-0 syntax compliance).
- Plan's full automated verify command (`test -x ... && head -2 ... && grep -q 'set -euo pipefail' ... && zsh -n ... && grep -q 'yq eval-all' ... && grep -q 'ireduce' ... && grep -q 'mktemp' ... && grep -v '^#' ... | grep -q 'mv ' && grep -q 'uname -m' ... && grep -q 'validate_manifest' ... && grep -q 'has("description")' ... && ! grep -qiE 'co-authored-by|generated by' ... && echo OK`) returns `OK`.
- All four real machine manifests pass `DOTFILEDIR=$(pwd) zsh install/resolver.zsh --validate-only --machine <name>` with exit 0 and no error output.
- End-to-end resolve of personal-laptop produces a `resolved.json` that satisfies `jq -e '.identity.git == "personal" and .platform.arch == "arm64" and (.features."one-password-ssh" == true)'`.
- Negative fixtures `_invalid-missing-desc` and `_invalid-bad-os` (temporarily copied into `manifests/machines/`) reject with exit 1 and the appropriate specific error message on stderr; restored after testing.

## Decisions Made

- **Loop variable shadowing fix** — the validator's loop iterates a list of required field paths. The natural variable name `path` collides with zsh's special tied `$path` array (which mirrors `$PATH`); a `local path` declaration empties the function's PATH and breaks every external command lookup. Renamed to `field_path` and documented the gotcha inline.
- **DOTFILES_MESSAGES_LOADED pre-initialization** — the v1 `install/messages.zsh` library guards against double-sourcing with bare `[[ -n "$DOTFILES_MESSAGES_LOADED" ]]`, which aborts under `set -u`. Since the parallel-rewrite invariant forbids editing v1 files, the resolver pre-initializes the variable with `: "${DOTFILES_MESSAGES_LOADED:=}"` before sourcing the library. Captured as a Rule 3 auto-fix (blocking issue) rather than a deviation, since the alternative was editing v1.
- **Underscore prefix in machine-name regex** — initial guard was `^[a-z0-9][a-z0-9-]*$`, which rejected the negative fixture names (`_invalid-missing-desc`, `_invalid-bad-os`). Relaxed to `^[a-z0-9_][a-z0-9_-]*$` so the fixtures can be exercised via `--validate-only` in Plan 03's test driver. Path-traversal characters (`/`, `.`, `..`, spaces) remain rejected.
- **`jq -s 'add | unique'` for extra_packages** — Plan 01 fixture 06's expected output is alphabetically sorted (`["docker-desktop","jq","yq"]`), and `jq -s 'add | unique'` produces sorted output by construction. No need for a custom union-preserving-order pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-initialize DOTFILES_MESSAGES_LOADED before sourcing messages.zsh**
- **Found during:** Task 1 smoke-testing the missing-state code path.
- **Issue:** `messages.zsh:20` references bare `$DOTFILES_MESSAGES_LOADED` in its double-source guard. The resolver enables `set -euo pipefail` before sourcing the library, so under `set -u` the bare reference aborts with `DOTFILES_MESSAGES_LOADED: parameter not set`.
- **Fix:** Added `: "${DOTFILES_MESSAGES_LOADED:=}"` before the source line in the resolver. Parallel-rewrite invariant precludes editing v1 files; the resolver owns the safe-load contract.
- **Files modified:** `install/resolver.zsh`
- **Commit:** `fb21779`

**2. [Rule 1 - Bug] Loop variable renamed from `path` to `field_path`**
- **Found during:** Task 1 smoke-testing the validator against the `_invalid-bad-os` fixture (the fixture had every required field present, yet the validator reported all fields missing).
- **Issue:** `local path parent key present value` in the validator function shadowed zsh's special tied `$path` array (the array view of `$PATH`). With `path` declared local-and-empty, every yq invocation inside the function failed with `command not found: yq`. The `|| echo false` fallback then captured "false" and the validator reported every field missing.
- **Fix:** Renamed the loop variable to `field_path` everywhere in the validator. Added an inline comment documenting the zsh gotcha.
- **Files modified:** `install/resolver.zsh`
- **Commit:** included in `fb21779`

**3. [Rule 2 - Critical correctness] Machine-name regex accepts underscore prefix**
- **Found during:** Task 1 smoke-testing the validator on the negative fixtures.
- **Issue:** The plan's stated regex `^[a-z0-9][a-z0-9-]*$` rejected `_invalid-missing-desc` and `_invalid-bad-os`, which Plan 01 deliberately authored with an underscore prefix. The plan's own acceptance criteria require these names to be accepted by `--validate-only` so the fixtures can be exercised.
- **Fix:** Widened to `^[a-z0-9_][a-z0-9_-]*$`. Path-traversal characters (`/`, `.`, `..`, spaces, control chars) remain rejected by the regex. Verified that `--machine '../etc/passwd'` and `--machine 'foo/bar'` still both fail-closed.
- **Files modified:** `install/resolver.zsh`
- **Commit:** included in `fb21779`

### Verification methodology deviation (not behavioral)

- **The plan's `<verify>` lines invoke `yq '.' <file>` without `-p toml`.** yq v4.53.2 defaults the input parser based on file extension AND emits a warning when it falls back to YAML for `.toml` inputs. Both invocations (with and without `-p toml`) parse all five TOML files cleanly, so the deviation is verification methodology only — no behavioral change to the manifests or resolver.

## Issues Encountered

- **First-pass yq invocations all returned the fallback value `false`** — root cause was the `local path` shadowing described above. Solved by inline tracing with `zsh -x`, which surfaced `command not found: yq` from inside the function scope. Fix took the form of a one-word rename.
- **Negative-fixture path-traversal acceptance criterion** required widening the machine-name regex by one character (`_`). Did not weaken the security guard (path-traversal characters remain rejected).
- **Initially used `2>/dev/null` on yq inside `$(...)` capture** which suppressed the diagnostic stderr that would have surfaced the PATH issue immediately. Kept the redirection in the final code (the validator legitimately wants to silence yq's `null`-handling messages), but the debug detour added a few minutes to Task 1.

## User Setup Required

None — the resolver runs entirely from existing project paths and writes to `$XDG_STATE_HOME/dotfiles/`. Plan 03 will wire the taskfile module; until then, the resolver is invokable directly via `DOTFILEDIR=$(pwd) zsh install/resolver.zsh [flags]`.

## Next Phase Readiness

- **Plan 03 (Wave 2 — `taskfiles/manifest.yml`) has a working resolver to wire against.** The CLI surface (`resolve`, `--validate-only --machine`, `--machine --stdout`) matches the contract in this plan's `<interfaces>` block exactly; no late-bound surprises for the task module.
- **Plan 01's fixtures and Plan 02's resolver are now testable end-to-end.** Plan 03 can build the `manifest:test` task that diffs `actual.json` (from this resolver run on each fixture's defaults.toml + machine.toml) against `expected.json`.
- **Downstream phases (3+) can rely on `resolved.json`'s shape** as demonstrated by the personal-laptop smoke output: deep-merged features (defaults + machine), wholesale-replaced bundles, union-deduped extra_packages, backfilled platform.arch.
- **Threat model coverage:** T-MAN-01 (manifest tampering) mitigated by hand-rolled validator + D-03 + D-01 + identity enum; T-MAN-02 (CLI-arg path traversal) mitigated by kebab-case regex + canonical-path equality check; T-MAN-03 (partial-write race) mitigated by mktemp + mv atomic-write contract.

## Self-Check: PASSED

All 8 plan output files verified present on disk; both task commits (`fb21779`, `9824f89`) verified in `git log`. All plan-spec automated verifications return OK (resolver static checks, four-machine validation, end-to-end personal-laptop resolve, negative-fixture rejection, path-traversal guard).

---
*Phase: 01-manifest-engine-repository-skeleton*
*Completed: 2026-05-13*
