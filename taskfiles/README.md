# taskfiles

Modular taskfile concerns wired into `../Taskfile.yml` via go-task
`includes:`. One taskfile per concern, named for it; the `includes:` block in
`../Taskfile.yml` is the authoritative list. Every install-style task is
idempotent (`status:` block) and
every symlink goes through `_:safe-link` in `helpers.yml`.

## Key files

- **Helpers and shared library.** `helpers.yml` -- reusable
  `_:safe-link` and `_:check-link`. A taskfile that calls a helper pulls it
  via `includes: _: ./helpers.yml`. Always go through `_:safe-link`; never
  bypass with a bare `ln -s` (LINT-03b catches it).
- **Manifest.** `manifest.yml` -- `manifest:set` (behind the root
  `task setup -- <machine>`), `manifest:resolve`, `manifest:show`,
  `manifest:validate`, `manifest:audit`. Reads TOMLs; writes `resolved.json`.
- **Lint.** `lint.yml` -- `lint:<check>` tasks covering the LINT-NN rules,
  plus `lint:test-fixtures` (the rules checking themselves against fixtures)
  and the `lint:default` aggregate. Catalogue below.
- **Links.** `links.yml` -- shell and tool-config symlinks via `_:safe-link`,
  the zdotdir step, and `links:diff` / `links:audit`. `shell.yml` exposes
  `task shell:startup-time` (cold-start gate) and the antidote bundle update
  (antidote is the plugin manager; plugin set in `shell/.zsh_plugins.txt`);
  `shell:validate` is internal-only (invoked by root `task validate`).
- **Smoke-test fixtures.** `tests/lint-fixtures/` -- fixture taskfiles
  consumed by `lint:test-fixtures` (run by `task test`). The production lint
  scans exclude this directory by name (`lint-fixtures`), since the fixtures
  deliberately violate the rules they exercise.

## Adding a pattern

- **A new taskfile.** Create `taskfiles/<concern>.yml` starting with
  `version: '3'` and a `# =====`-style file-header banner (Purpose /
  Depends on / Side effects). Add `includes: _: ./helpers.yml` if it calls
  a helper. Every install-style task MUST have a `status:` block that uses
  `{{.X}}` template vars only -- never `$X` shell vars (LINT-02 catches
  this). LINT-03a requires every public task with `cmds:` to declare a
  `status:` or be `internal: true`; diagnostic tasks that re-run by design
  (validate, perf, etc.) declare `status: [false]`.
- **Wiring the taskfile into the root `Taskfile.yml`.** Add a line to the
  `includes:` block in `../Taskfile.yml`, and add the file to the root
  `Taskfile.yml` header's `Depends on:` list. The first invocation from
  the root namespace becomes `task <alias>:<task>` (for example,
  `task shell:startup-time`).
- **A new symlink.** Add a `_:safe-link` invocation to `links.yml` (or
  the appropriate links subtask) with `SOURCE` and `TARGET` vars resolved
  from the root `Taskfile.yml` vars block. Add a matching `test -L` line
  to the task's `status:` block. Add the target to `EXPECTED_TARGETS` and
  its source mapping to `LINKS_RESOLVE_SOURCE` so `links:validate` and
  `links:diff` cover it. NEVER use bare `ln -s` outside `helpers.yml`
  (LINT-03b).

## References

- `../Taskfile.yml` -- root taskfile, includes block, and the operator
  surface. `task install` is the canonical entry: installing and updating
  run the same pipeline.
- `helpers.yml` -- symlink helpers (`_:safe-link`, `_:check-link`).
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
| LINT-03b | `taskfiles/**/*.yml` | No bare `ln -s` outside `taskfiles/helpers.yml` |
| LINT-04 | Executable .zsh | `set -euo pipefail` in first 30 lines |
| LINT-05 | shell/ + os/ (.zsh only) | Portability-sensitive commands surface as warnings (non-blocking) |
| LINT-07 | All .zsh + `taskfiles/*.yml` | `zsh -n` parse-check and YAML parse (Tier-0 syntax) |
| LINT-08 | Root Taskfile.yml | `default:` banner lists every public top-level task |
| LINT-10 | .zsh + .yml repo-wide | No hardcoded `/opt/homebrew` or `/usr/local`; dispatch sites carry `# lint-allow: hardcoded-prefix` |
| LINT-11 | Taskfiles | Kebab-case feature keys use the `index` form, never template dot-access |
| LINT-12 | All .zsh | File-header banner (Purpose / Depends on / Side effects between `# ===` rules) |
| LINT-13 | `manifests/**/*.toml` | Multi-element arrays span one element per line (empty/single-element inline arrays exempt) |

LINT-01, LINT-06, and LINT-09 are intentionally absent; retired numbers are
never reused, so existing `# LINT-NN:` citations in code stay unambiguous.
