---
plan: 02-05
status: complete
completed: 2026-05-13
phase: 02-install-engine-bootstrap-idempotency-lint
---

# Plan 02-05 Summary: Lint Fixtures + Self-Test Runner

## What was built

11 lint fixtures under `taskfiles/test/lint-fixtures/` covering positive
and negative cases for LINT-02 (shell-var in status), LINT-03a (cmds
without status), LINT-03b (bare ln outside helpers), LINT-04 (missing
strict-mode header), LINT-05 (portability warn), and LINT-07 (zsh -n
parse error).

Replaced the placeholder body of `task lint:test-fixtures` in
`taskfiles/lint.yml` (shipped as a stub in Plan 02-01) with the actual
runner. The runner iterates `taskfiles/test/lint-fixtures/[0-9]*-*/`,
reads each `expect` file (`pass`, `fail`, or `warn`), runs the
fixture-appropriate lint check against the fixture's source file, and
asserts actual outcome against expected. Exits with the count of
mismatches; exits 0 on full match.

## Key files created

- `taskfiles/test/lint-fixtures/02a-shell-var-in-status/` — LINT-02 positive (expect=fail)
- `taskfiles/test/lint-fixtures/02b-template-var-in-status/` — LINT-02 negative (expect=pass)
- `taskfiles/test/lint-fixtures/02c-command-substitution-in-status/` — LINT-02 negative (expect=pass)
- `taskfiles/test/lint-fixtures/03a-cmds-no-status/` — LINT-03a positive (expect=fail)
- `taskfiles/test/lint-fixtures/03a-internal-no-status-ok/` — LINT-03a internal-exempt (expect=pass)
- `taskfiles/test/lint-fixtures/03b-bare-ln/` — LINT-03b positive (expect=fail)
- `taskfiles/test/lint-fixtures/03b-helpers-allowed/` — LINT-03b helpers.yml allowlist (expect=pass)
- `taskfiles/test/lint-fixtures/04a-missing-set-euo/` — LINT-04 positive (expect=fail)
- `taskfiles/test/lint-fixtures/04b-non-exec-no-set/` — LINT-04 non-executable exempt (expect=pass)
- `taskfiles/test/lint-fixtures/05a-pbcopy-warn/` — LINT-05 portability (expect=warn)
- `taskfiles/test/lint-fixtures/07a-syntax-error/` — LINT-07 parse error (expect=fail)

## Key files modified

- `taskfiles/lint.yml` — replaced `test-fixtures` task body with the iterator + asserter described above. `test-fixtures` remains intentionally OUT of the `default` aggregator (per RESEARCH §10.1).

## Verification

`task -t taskfiles/lint.yml test-fixtures` exits 0 with all 11 fixtures
reporting `expect=<X> actual=<X>` matches. The runner correctly
distinguishes fail/pass/warn semantics across the six lint categories.

## Notable deviations

This plan was rescued inline by the orchestrator after the spawned
executor agent forked a worktree from the wrong base (a321531 instead
of the post-Wave-1 HEAD 8f7f59d) and produced fixtures-only output
without committing the runner or SUMMARY. The orchestrator copied the
22 fixture files from the worktree to the main checkout, wrote the
runner per the plan spec verbatim, ran the self-test (all 11 pass),
and committed the work. The worktree was force-removed after rescue.

## Self-Check: PASSED

All success criteria met. 11 fixtures committed. `task lint:test-fixtures` runs and reports all fixtures behaving as expected.
