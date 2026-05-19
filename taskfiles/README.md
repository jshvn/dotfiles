# taskfiles

Modular taskfile concerns wired into `../Taskfile.yml` via go-task
`includes:`. One taskfile per concern: manifest, lint, links, shell,
identity, packages, macos, claude, test, helpers. Every install-style
task is idempotent (`status:` block) and every symlink goes through
`_:safe-link` in `helpers.yml`.

## Key files

- **Helpers and shared library.** `helpers.yml` -- reusable
  `_:safe-link`, `_:check-link`, `_:check-dir`, `_:check-file`,
  `_:check-command`. Every other taskfile pulls it via
  `includes: _: ./helpers.yml`. Always go through `_:safe-link`; never
  bypass with a bare `ln -s` (LINT-03b catches it).
- **Phase 1 (real).** `manifest.yml` -- `task setup -- <machine>`,
  `manifest:resolve`, `manifest:validate`, `manifest:show`,
  `manifest:test`, `manifest:test:add-machine`. Reads TOMLs; writes
  `resolved.json`.
- **Phase 2 (real).** `lint.yml` -- `lint:taskfile`, `lint:shell-headers`,
  `lint:portability`, `lint:syntax`, `lint:test-fixtures`. Enforces
  LINT-01..LINT-07.
- **Phase 3 (real).** `links.yml` -- shell symlinks via `_:safe-link` plus
  the zdotdir step (antigen is the live plugin manager; antidote was
  evaluated and reverted -- see `shell/.zshrc:75` comment
  for rationale). `shell.yml` exposes `task shell:startup-time` (SHEL-12
  cold-start gate); `shell:validate` is internal-only (invoked by root
  `task validate`).
- **Smoke-test fixtures.** `test/` -- lint-fixture taskfiles consumed by
  `task lint:test-fixtures`.

## Adding a pattern

- **A new taskfile.** Create `taskfiles/<concern>.yml` starting with
  `version: '3'` and a `# =====`-style file-header banner naming purpose,
  callers, and conventions. Add `includes: _: ./helpers.yml`. Every
  install-style task MUST have a `status:` block (LINT-01) that uses
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

- `../Taskfile.yml` -- root taskfile, includes block, install/update
  unification (`task install` is the canonical entry; `task update` is
  retired).
- `helpers.yml` -- symlink helpers and command-availability checks.
- `../docs/MANIFEST.md` -- manifest schema; many tasks consume
  `resolved.json` via `fromJson`.
- `../CLAUDE.md` -- v2 conventions (status-block templating, no bare
  `ln -s`, `set -euo pipefail` on every executable `.zsh`).
- `../.planning/REQUIREMENTS.md` -- LINT-01..LINT-07, DOCS-02
  traceability.

Satisfies DOCS-02 for taskfiles/.
