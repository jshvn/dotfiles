# taskfiles

Modular taskfile concerns wired into `../Taskfile.yml` via go-task
`includes:`. One taskfile per concern, named for it; the `includes:` block in
`../Taskfile.yml` is the authoritative list. Every install-style task is
idempotent (`status:` block) and
every symlink goes through `_:safe-link` in `helpers.yml`.

## Key files

- **Helpers and shared library.** `helpers.yml` -- reusable
  `_:safe-link` and `_:check-link`. Every other taskfile pulls it via
  `includes: _: ./helpers.yml`. Always go through `_:safe-link`; never
  bypass with a bare `ln -s` (LINT-03b catches it).
- **Manifest.** `manifest.yml` -- `task setup -- <machine>`,
  `manifest:resolve`, `manifest:show`, `manifest:validate`,
  `manifest:audit`. Reads TOMLs; writes `resolved.json`.
- **Lint.** `lint.yml` -- one `lint:<check>` task per LINT-NN rule, plus
  `lint:test-fixtures` (the rules checking themselves against fixtures) and
  the `lint:default` aggregate. Catalogue below.
- **Links.** `links.yml` -- shell symlinks via `_:safe-link` plus
  the zdotdir step (antidote is the plugin manager; plugin set in
  `shell/.zsh_plugins.txt`). `shell.yml` exposes `task shell:startup-time`
  (cold-start gate); `shell:validate` is internal-only (invoked by root
  `task validate`).
- **Smoke-test fixtures.** `tests/lint-fixtures/` -- fixture taskfiles
  consumed by `task lint:test-fixtures`. The production lint scans exclude
  this directory by name (`lint-fixtures`), since the fixtures deliberately
  violate the rules they exercise.

## Adding a pattern

- **A new taskfile.** Create `taskfiles/<concern>.yml` starting with
  `version: '3'` and a `# =====`-style file-header banner naming purpose,
  callers, and conventions. Add `includes: _: ./helpers.yml`. Every
  install-style task MUST have a `status:` block (LINT-03a) that uses
  `{{.X}}` template vars only -- never `$X` shell vars (LINT-02 catches
  this; the v1 `macos:shell:145` regression class). For diagnostic-only
  tasks (validate, perf, etc.) that re-run by design, add an inline
  `# lint-allow: cmds-without-status` comment ABOVE the task name so
  LINT-03a skips it.
- **Wiring the taskfile into the root `Taskfile.yml`.** Add a line to the
  `includes:` block in `../Taskfile.yml` (alphabetical by namespace
  alias). Update the includes comment table at the top of `Taskfile.yml`
  to add a `#   - <alias>   (P<n>, real)` line. The first invocation from
  the root namespace becomes `task <alias>:<task>` (for example,
  `task shell:startup-time`).
- **A new symlink.** Add a `_:safe-link` invocation to `links.yml` (or
  the appropriate links subtask) with `SOURCE` and `TARGET` vars resolved
  from the root `Taskfile.yml` vars block. Add a matching `test -L` line
  to the task's `status:` block. Add a `_:check-link` invocation to the
  `validate:` task for diagnostic output. NEVER use bare `ln -s` outside
  `helpers.yml` (LINT-03b).

## References

- `../Taskfile.yml` -- root taskfile, includes block, and the operator
  surface. `task install` is the canonical entry: installing and updating
  run the same pipeline.
- `helpers.yml` -- symlink helpers and command-availability checks.
- `../docs/MANIFEST.md` -- manifest schema; many tasks consume
  `resolved.json` via `fromJson`.
- `../CLAUDE.md` -- v2 gotchas (status-block templating, no bare
  `ln -s`, `set -euo pipefail` on every executable `.zsh`).

## Lint catalogue

In-code `# LINT-NN:` citations reference this catalogue. The rule body lives in
`taskfiles/lint.yml`; this table is the operator-facing summary.

| ID | Scope | What it checks |
|----|-------|----------------|
| LINT-02 | Taskfiles | `status:` uses `{{.X}}` template vars, not `$X` shell vars |
| LINT-03a | Taskfiles | Tasks with `cmds:` have `status:` (or exempt via `internal: true` / all-task-delegates) |
| LINT-03b | Repo-wide | No bare `ln -s` outside `taskfiles/helpers.yml` |
| LINT-04 | Executable .zsh | `set -euo pipefail` in first 30 lines |
| LINT-05 | shell/ + os/ (.zsh only) | Portability-sensitive commands surface as warnings (non-blocking) |
| LINT-07 | All .zsh | `zsh -n` parse-check (Tier-0 syntax) |
| LINT-08 | Root Taskfile.yml | `default:` banner lists every public top-level task |
| LINT-10 | .zsh + .yml repo-wide | No hardcoded `/opt/homebrew` or `/usr/local`; dispatch sites carry `# lint-allow: hardcoded-prefix` |
| LINT-11 | Taskfiles | Kebab-case feature keys use the `index` form, never template dot-access |
| LINT-12 | All .zsh | File-header banner (Purpose / Depends on / Side effects between `# ===` rules) |
| LINT-13 | `manifests/**/*.toml` | Multi-element arrays span one element per line (empty/single-element inline arrays exempt) |

LINT-01, LINT-06, and LINT-09 are intentionally absent; retired numbers are
never reused, so existing `# LINT-NN:` citations in code stay unambiguous.
LINT-01 ("every install task has a status: block") was generalized into
LINT-03a. LINT-09 checked a generated `settings.json` tracked in the repo;
the repo tree holds source only, and build-vs-live drift is runtime, covered
by `task claude:audit` under both `task audit` and `task validate`.
