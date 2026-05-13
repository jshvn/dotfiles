---
phase: 01-manifest-engine-repository-skeleton
fixed_at: 2026-05-13T00:00:00Z
review_path: .planning/phases/01-manifest-engine-repository-skeleton/01-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 11
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-05-13
**Source review:** .planning/phases/01-manifest-engine-repository-skeleton/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (3 blocker + 8 warning; 6 info findings deferred)
- Fixed: 11
- Skipped: 0

All blocker and warning findings were resolved. Each fix was verified by
re-running `task -t taskfiles/manifest.yml manifest:test` (8 fixtures passing)
and, where the change exercised additional code paths, by also running
`manifest:resolve`, `manifest:validate`, `manifest:show` (default + bare-name
+ `--machine` forms), and `manifest:test:add-machine`. The resolver passes
`zsh -n install/resolver.zsh` after every commit.

## Fixed Issues

### CR-01: Negative-fixture test pollutes `manifests/machines/` with no failure-path cleanup

**Files modified:** `taskfiles/manifest.yml`
**Commit:** 987f340
**Applied fix:** Registered an `EXIT` trap that removes any negative-fixture
copies from `manifests/machines/` even on yq crash, validator coredump, or
Ctrl-C. Drop the silenced `cp ... 2>/dev/null || true` so a failed copy fails
loudly instead of silently running the test against stale state. Note: only
`EXIT` is registered (not `INT TERM` as the review suggested) because
go-task's mvdan/sh interpreter rejects `INT`/`TERM` by name; go-task forwards
received signals to its child shell, which then runs the `EXIT` trap on its
way out, so `EXIT` alone covers Ctrl-C correctly.

### CR-02: `manifest:test:add-machine` leaks state when no prior machine was selected

**Files modified:** `taskfiles/manifest.yml`
**Commit:** dde3c76
**Applied fix:** Track `prior_machine_existed` and `prior_resolved_existed`
via file existence rather than string emptiness. On a fresh machine the
prior state files are absent, not just empty -- the previous logic skipped
the restore branch and left `_addmachine-test` as the active machine plus a
stale `resolved.json` pointing at a deleted manifest. Cleanup now deletes
the state files when no prior state existed and restores them when it did.
Verified manually by removing real state, running the smoke test, and
confirming the state directory was empty afterwards.

### CR-03: `{{.CLI_ARGS}}` interpolated into single-quoted shell strings — breaks on apostrophes

**Files modified:** `taskfiles/manifest.yml`
**Commit:** 0a1ee80
**Applied fix:** Pass `CLI_ARGS` via `env: { CLI_ARGS_ENV: '{{.CLI_ARGS}}' }`
in `setup`, `manifest:show`, and `manifest:validate`. The value now flows
through the environment intact (post-go-task-template, pre-shell-parse), so
an apostrophe in user input cannot unterminate the surrounding shell quote.
Verified that `task setup -- "joe's-laptop"` now emits the actionable
"invalid or unknown machine" precondition message instead of a confusing
shell parse error. The stale `tr -d "'"` defenses on the old lines 158/186
were removed -- they only operated on the post-parse value and could not
recover from a quote injected into the template substitution.

### WR-01: `mktemp` + `mv` has no signal trap — leaks tmp file on Ctrl-C

**Files modified:** `install/resolver.zsh`
**Commit:** 8745697
**Applied fix:** Registered `trap 'rm -f "$tmp"' EXIT INT TERM` before the
`resolve_pipeline` call and cleared the trap with `trap - EXIT INT TERM`
after a successful `mv` (so the renamed final path is not subsequently
rm'd). The resolver runs under zsh, which fully supports `INT`/`TERM` by
name, so the original review suggestion applies as-written here (unlike
the taskfile context).

### WR-02: Unknown-key warning grep uses unescaped key as regex

**Files modified:** `install/resolver.zsh`
**Commit:** b102d11
**Applied fix:** Gated the line-number grep behind a strict identifier
check `[[ "$leaf" =~ ^[A-Za-z0-9_-]+$ ]]`. When the leaf contains TOML
quoted-key metacharacters, the warning still fires but the line: hint is
omitted (printed as `?`) instead of substituting metacharacters into the
regex and producing a misleading line number. Lower friction than the
review's `${leaf//[^A-Za-z0-9_-]/.}` substitution suggestion, with the
same correctness outcome.

### WR-03: `MANIFEST_JSON` silently masks resolver failure as `{}`

**Files modified:** `taskfiles/manifest.yml`
**Commit:** e8b9261
**Applied fix:** Replaced `cat ... 2>/dev/null || echo '{}'` with an
explicit guard that checks `[[ -s "$path" ]]` and writes a stderr warning
(`"warning: ... missing or empty -- run 'task setup -- <machine>' first"`)
when the file is absent or empty. The `{}` fallback is preserved so the
`fromJson` ref does not abort go-task initialization, but the warning
surfaces the misconfiguration so Phase 2+ tasks that rely on
`{{.MANIFEST.identity.git}}` no longer silently skip features.

### WR-04: `schema_version` is documented as required but not enforced

**Files modified:** `install/resolver.zsh`
**Commit:** 63d7aae
**Applied fix:** Added explicit presence + equality check in
`validate_manifest`. Distinct error messages for absent
(`"missing required field: schema_version (must equal 1)"`) and non-1
(`"schema_version must equal 1 in v1 resolver; got: ..."`) cases.
Verified manually with two synthetic manifests (one missing
`schema_version`, one with `schema_version = 99`) -- both rejected with
exit 1 and the correct stderr message. All existing fixtures declare
`schema_version = 1`, so `manifest:test` continues to pass.

### WR-05: Hardcoded fixture count drifts when fixtures are added

**Files modified:** `taskfiles/manifest.yml`
**Commit:** 987f340 (folded into CR-01 — same task, contiguous edit)
**Applied fix:** Changed the positive-fixture loop glob from `0[1-6]-*`
to `[0-9][0-9]-*` and derive `total = positive_count + negative_count`
where `positive_count` is recounted from the same glob in a separate
loop after the main run. Adding a 7th positive fixture now requires no
hand-edit of any constant.

### WR-06: `manifest:show` / `manifest:validate` only accept `--machine NAME`, not bare names

**Files modified:** `taskfiles/manifest.yml`
**Commit:** 0a1ee80 (folded into CR-03 — same parse blocks, coupled edit)
**Applied fix:** After the `--machine NAME` sed extraction, fall back to
treating a whitespace-trimmed `cli_args` as a bare machine name if it
matches the kebab-case regex. Verified that
`task manifest:show -- personal-laptop` now works and produces the same
output as `task manifest:show -- "--machine personal-laptop"`. Updated
both task `desc:` strings to read `[--machine] NAME` to document the
relaxed accepted form.

### WR-07: `validate_manifest` reports errors on stdout — fragile to subprocess noise

**Files modified:** `install/resolver.zsh`
**Commit:** 38dc3eb
**Applied fix:** Refactored the function to return its error count via a
`typeset -gi VALIDATE_ERRORS` global plus a 0/1 exit status, instead of
echoing the count on stdout. Caller in `main` now reads `VALIDATE_ERRORS`
after `validate_manifest "$machine_file" || true` (the `|| true` keeps
`set -e` from aborting on a non-zero return so the caller can read the
count and emit a summary). Removed the corresponding `echo "$errors"`
and `echo 1` from the function body. Verified with both valid manifests
(exit 0, no error message) and invalid manifests (exit 1, correct
stderr message and count).

### WR-08: `machine_name="${machine_name//[[:space:]]/}"` silently rewrites embedded whitespace

**Files modified:** `install/resolver.zsh`, `taskfiles/manifest.yml`
**Commit:** 2130ac0
**Applied fix:** Resolver: replaced the `${//[[:space:]]/}` strip with
`read -r machine_name < "$STATE_FILE"` which trims naturally and stops
at the first newline. Taskfile sites (the `MACHINE` var on line 63, the
state-file reads in `manifest:show` / `manifest:validate`, and the
`prior_machine` capture in `manifest:test:add-machine`): replaced
`tr -d '[:space:]' < file` with
`head -n1 file | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`.
This reads only the first line (single-line state-file contract) and
trims edges only, so a malformed `bad name\n` is no longer silently
rewritten to `badname`. The `candidate=$(printf '%s' "$cli_args" | tr -d
'[:space:]')` sites in `show`/`validate` were intentionally left alone
-- the intent there is "test whether the entire CLI_ARGS payload
condenses to a single bare name token", which is materially different
from the state-file reading intent.

## Deferred (Info-only — out of scope for `critical_warning` fix run)

The following six findings were classified as Info severity in the review
and are intentionally not addressed in this iteration:

- **IN-01** -- `vars: HOME: '{{.HOME}}'` is redundant
- **IN-02** -- `cat | tr` UUOC (partially addressed as a side effect of WR-08
  at the four state-file-reading sites; the remaining `cat | tr` patterns
  are at non-state-file sites)
- **IN-03** -- `error()` writes color codes even when stderr is not a TTY
  (file is in `install/messages.zsh`, outside Phase 1's diff)
- **IN-04** -- `ls | xargs basename | sed | tr` chain is fragile
- **IN-05** -- `_invalid-bad-os/machine.toml` empty `[features]` TOML quirk
- **IN-06** -- Phase 1 docs reference Phase 2 wiring inconsistently

These remain visible in `01-REVIEW.md` for a future polish iteration.

---

_Fixed: 2026-05-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
