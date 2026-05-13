---
phase: 01-manifest-engine-repository-skeleton
reviewed: 2026-05-13T00:00:00Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - CLAUDE.md
  - configs/README.md
  - docs/MANIFEST.md
  - docs/README.md
  - identity/README.md
  - install/resolver.zsh
  - manifests/README.md
  - manifests/defaults.toml
  - manifests/machines/README.md
  - manifests/machines/personal-laptop.toml
  - manifests/machines/server-1.toml
  - manifests/machines/server-2.toml
  - manifests/machines/work-laptop.toml
  - manifests/test/README.md
  - manifests/test/fixtures/01-map-over-map/defaults.toml
  - manifests/test/fixtures/01-map-over-map/expected.json
  - manifests/test/fixtures/01-map-over-map/machine.toml
  - manifests/test/fixtures/02-list-replace/defaults.toml
  - manifests/test/fixtures/02-list-replace/expected.json
  - manifests/test/fixtures/02-list-replace/machine.toml
  - manifests/test/fixtures/03-scalar-override/defaults.toml
  - manifests/test/fixtures/03-scalar-override/expected.json
  - manifests/test/fixtures/03-scalar-override/machine.toml
  - manifests/test/fixtures/04-nested-table/defaults.toml
  - manifests/test/fixtures/04-nested-table/expected.json
  - manifests/test/fixtures/04-nested-table/machine.toml
  - manifests/test/fixtures/05-missing-keys/defaults.toml
  - manifests/test/fixtures/05-missing-keys/expected.json
  - manifests/test/fixtures/05-missing-keys/machine.toml
  - manifests/test/fixtures/06-extra-packages-concat/defaults.toml
  - manifests/test/fixtures/06-extra-packages-concat/expected.json
  - manifests/test/fixtures/06-extra-packages-concat/machine.toml
  - manifests/test/fixtures/_invalid-bad-os/machine.toml
  - manifests/test/fixtures/_invalid-missing-desc/machine.toml
  - os/README.md
  - packages/README.md
  - shell/README.md
  - taskfiles/manifest.yml
findings:
  blocker: 3
  warning: 8
  info: 6
  total: 17
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-13
**Depth:** standard
**Files Reviewed:** 38
**Status:** issues_found

## Summary

Phase 01 delivers a working manifest engine: TOML-driven deep-merge with golden
fixtures, a hand-rolled validator, atomic JSON cache writes, and a self-contained
go-task module. The core resolver in `install/resolver.zsh` is well-structured —
explicit modes, mtime-based idempotency, careful path-traversal guards on
`--machine`. Documentation in `docs/MANIFEST.md` is thorough and consistent
with the implementation.

The primary concerns are concentrated in `taskfiles/manifest.yml`:

1. The negative-fixture test driver (`manifest:test`) and the smoke-test driver
   (`manifest:test:add-machine`) both pollute `manifests/machines/` and
   `$XDG_STATE_HOME/dotfiles/` with throwaway files, with cleanup paths that
   leak state on partial failure.
2. CLI-arg passthrough (`{{.CLI_ARGS}}`) is wrapped in single quotes inside
   shell `printf` calls; any single quote in user input breaks shell parsing
   (template-substitution-into-quoted-string anti-pattern).
3. A handful of secondary correctness issues in the resolver: regex
   metacharacters in unknown-key warnings, no signal trap around `mktemp +
   mv`, no `schema_version` validation, and a foot-gun in `MANIFEST_JSON` that
   silently swallows resolver failure as `{}`.

No injection, secret-leak, or path-traversal vulnerabilities were found in the
resolver itself — the `MACHINE_NAME_RE` guard plus the canonical-path equality
check at `install/resolver.zsh:316` are sound.

## Critical Issues

### CR-01: Negative-fixture test pollutes `manifests/machines/` with no failure-path cleanup

**File:** `taskfiles/manifest.yml:281-310`
**Issue:** The negative-fixture sub-tests copy `_invalid-missing-desc/machine.toml`
and `_invalid-bad-os/machine.toml` into `manifests/machines/`, invoke the
resolver, then `rm -f` the copies. There is no `trap` registered, so any failure
between the `cp` and the `rm -f` (yq crash, SIGINT, validator coredump) leaves
`manifests/machines/_invalid-bad-os.toml` and/or `_invalid-missing-desc.toml`
sitting in a real source-tree directory. Worse, the copy is silenced
(`cp ... 2>/dev/null || true`), so a `cp` failure is not surfaced — the test
will then run against whatever was already at the destination (or against the
absent file, in which case the resolver reports "machine manifest not found"
which contains neither `meta.description` nor `darwin`, so the assertion silently
fails). The set is leaked into the per-machine directory that
`list_available_machines` and the `AVAILABLE_MACHINES` task var iterate, which
breaks `task setup` autocomplete suggestions and validator UX until the user
manually deletes them.
**Fix:** Use the resolver's existing ability to validate any file path, or
register an `EXIT`/`INT`/`TERM` trap that runs `rm -f` on the throwaway paths
before the test does any work. Drop the `2>/dev/null || true` on `cp` — let it
fail loudly. Example:
```yaml
- |
  {{.DOTFILES_MESSAGES}}
  failures=0
  fix_dir="{{.FIXTURES_DIR}}"
  neg_copies=()
  cleanup_neg() {
    local f
    for f in "${neg_copies[@]}"; do
      rm -f "$f"
    done
  }
  trap cleanup_neg EXIT INT TERM
  # ... then for each negative fixture:
  tmp_neg="{{.MACHINES_DIR}}/_invalid-missing-desc.toml"
  neg_copies+=("$tmp_neg")
  cp "$neg_dir/machine.toml" "$tmp_neg"   # let cp errors propagate
  # ... run resolver, assert
```
A cleaner alternative is to extend the resolver with a `--manifest-file <path>`
flag that bypasses `resolve_machine_path` entirely so negative fixtures never
touch the real `manifests/machines/` directory.

### CR-02: `manifest:test:add-machine` leaks state when no prior machine was selected

**File:** `taskfiles/manifest.yml:341-360`
**Issue:** The smoke test captures `prior_machine` and `prior_resolved`, then
in `do_cleanup` only restores them if non-empty:
```bash
if [[ -n "$prior_machine" ]]; then
  printf '%s' "$prior_machine" > "$state_file"
fi
if [[ -n "$prior_resolved" ]]; then
  printf '%s' "$prior_resolved" > "$resolved_file"
fi
```
On a fresh machine (or any machine where state had not yet been written), both
`prior_machine` and `prior_resolved` are empty. The smoke test then writes
`_addmachine-test` to the state file at line 385, generates a resolved.json at
line 387-388, deletes the throwaway TOML at line 351 (`rm -f "$throwaway"`),
and exits. The cleanup function leaves `$XDG_STATE_HOME/dotfiles/machine`
pointing at the now-deleted `_addmachine-test`, and leaves a stale
`resolved.json` whose `meta.description` references a manifest file that no
longer exists. Subsequent `task manifest:resolve` will fail with
"machine manifest not found".
**Fix:** Distinguish between "no prior state existed" and "prior state was X"
using file-existence rather than string-emptiness:
```bash
prior_machine_existed=0
if [[ -f "$state_file" ]]; then
  prior_machine_existed=1
  prior_machine=$(cat "$state_file" 2>/dev/null | tr -d '[:space:]')
fi
prior_resolved_existed=0
if [[ -f "$resolved_file" ]]; then
  prior_resolved_existed=1
  prior_resolved=$(cat "$resolved_file" 2>/dev/null)
fi

do_cleanup() {
  rm -f "$throwaway"
  if (( prior_machine_existed )); then
    printf '%s' "$prior_machine" > "$state_file"
  else
    rm -f "$state_file"
  fi
  if (( prior_resolved_existed )); then
    printf '%s' "$prior_resolved" > "$resolved_file"
  else
    rm -f "$resolved_file"
  fi
}
```

### CR-03: `{{.CLI_ARGS}}` interpolated into single-quoted shell strings — breaks on apostrophes

**File:** `taskfiles/manifest.yml:102, 110, 158, 186`
**Issue:** Multiple shell snippets interpolate `{{.CLI_ARGS}}` into single-
quoted shell strings:
```yaml
name="{{.CLI_ARGS}}"                         # line 102: precondition check
printf '%s' "{{.CLI_ARGS}}" > "{{.STATE_FILE}}"  # line 110: setup
cli_args=$(printf '%s' '{{.CLI_ARGS}}' | tr -d "'")  # lines 158, 186
```
Go-task substitutes the template variable into the rendered shell text *before*
the shell parses it. If `CLI_ARGS` contains a single quote (e.g.,
`task setup -- "joe's-laptop"`), the rendered shell becomes
`cli_args=$(printf '%s' 'joe's-laptop' | tr -d "'")` — three single quotes,
unterminated string, parse error. While the regex on line 102 will reject
machine names with apostrophes anyway (so the CR-01 path-traversal class is not
re-introduced), the failure mode is a confusing shell parse error rather than
the actionable "invalid machine name" the precondition is designed to emit.
The `tr -d "'"` strip on lines 158/186 is also a stale defense — it operates
on the post-parse value, not the pre-parse template text, so it cannot recover
from a quote injected into the template substitution.
**Fix:** Pass `CLI_ARGS` via the environment instead of templating it into
shell-quoted text:
```yaml
- cmd: |
    set -u
    name="${CLI_ARGS_ENV}"
    [[ "$name" =~ ^[a-z0-9_][a-z0-9_-]*$ ]] || { echo "invalid: $name" >&2; exit 1; }
  env:
    CLI_ARGS_ENV: '{{.CLI_ARGS}}'
```
or sanitize the value at the template layer using go-task's `shellQuote` /
`squote` if available, or constrain the precondition to operate on a known-safe
extracted substring. The current pattern is uniformly broken across all four
sites and should be fixed together.

## Warnings

### WR-01: `mktemp` + `mv` has no signal trap — leaks tmp file on Ctrl-C

**File:** `install/resolver.zsh:282-294`
**Issue:** `resolve_manifest` creates `tmp=$(mktemp "${out_path}.XXXXXX")`,
runs `resolve_pipeline > "$tmp"`, then `mv "$tmp" "$out_path"`. The
`{ ... } || { rm -f "$tmp"; ... }` block handles ordinary command failures.
It does not handle SIGINT (Ctrl-C), SIGTERM, or the script being killed mid-
pipeline. In any of those cases the `${out_path}.XXXXXX` tmp file is left in
`$XDG_STATE_HOME/dotfiles/`. On a long-lived dev machine, repeated Ctrl-Cs
during iteration accumulate `resolved.json.aBcDeF`-style siblings.
**Fix:** Register a trap on the relevant signals before mktemp, and clear it
after a successful mv:
```zsh
local tmp
tmp=$(mktemp "${out_path}.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM
resolve_pipeline "$defaults_path" "$machine_path" > "$tmp"
mv "$tmp" "$out_path"
trap - EXIT INT TERM
```

### WR-02: Unknown-key warning grep uses unescaped key as regex

**File:** `install/resolver.zsh:230`
**Issue:** The line-number lookup for unknown-key warnings uses:
```zsh
line_no=$("$grep_cmd" -n "^${leaf}[[:space:]]*=" "$machine_file" ...)
```
`leaf` is the trailing dot-segment of a yq-emitted path. TOML key syntax
permits quoted keys that can contain regex metacharacters
(`"foo.bar" = 1`, `"a*b" = 1`). When such a key flows into the grep pattern,
metacharacters are interpreted literally as regex. Worst case a key like
`."" =` could short-circuit the match and produce a misleading line number,
but no crash. This is a polish issue, not a correctness or security issue.
**Fix:** Use `grep -F` (fixed-string) when matching the leaf name:
```zsh
line_no=$("$grep_cmd" -nF "${leaf}" "$machine_file" 2>/dev/null \
  | grep -E "^[[:space:]]*${leaf//[^A-Za-z0-9_-]/.}[[:space:]]*=" \
  | head -1 | cut -d: -f1 || true)
```
or skip the line-number heuristic entirely for keys that fail a strict
identifier-character check (which the docs already warn may be imprecise:
`docs/MANIFEST.md:413`).

### WR-03: `MANIFEST_JSON` silently masks resolver failure as `{}`

**File:** `taskfiles/manifest.yml:70-71`
**Issue:** `MANIFEST_JSON: sh: cat '{{.RESOLVED_JSON_PATH}}' 2>/dev/null ||
echo '{}'` returns `{}` on any failure (file missing, file empty, file
unreadable, file contains malformed JSON). `MANIFEST: ref: 'fromJson
.MANIFEST_JSON'` then succeeds with an empty map, and downstream tasks that
use `{{.MANIFEST.identity.git}}` evaluate to the zero value (`<no value>` in
Go templates) without any indication that the manifest was never resolved.
This is a foot-gun for Phase 2+ when the root Taskfile starts wiring
manifest-driven tasks. Symptoms will be silent skips of features the user
expected to be enabled.
**Fix:** Either drop the fallback so go-task fails loudly (preferred — Phase 1
docs already say "task setup must be run first"), or emit a stderr warning:
```yaml
MANIFEST_JSON:
  sh: |
    if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
      cat '{{.RESOLVED_JSON_PATH}}'
    else
      echo "warning: {{.RESOLVED_JSON_PATH}} missing -- run 'task setup'" >&2
      echo '{}'
    fi
```
The resolver task itself does have a `preconditions:` check on `STATE_FILE`,
so the silent fallback is mostly defensive — but it actively hides bugs once
manifest-driven tasks land in Phase 2.

### WR-04: `schema_version` is documented as required but not enforced

**File:** `install/resolver.zsh:103-109` (and `docs/MANIFEST.md` schema table)
**Issue:** Every manifest in the repo declares `schema_version = 1`, the docs
treat it as part of the schema (`docs/MANIFEST.md:18, 51`), and the entire
v2 forward-compat story depends on it. The validator's `required_strings`
array does not include `schema_version`, and there is no separate check on
its presence or value. A manifest with `schema_version = 99` (or absent
entirely) validates cleanly. Once v2 introduces a different schema, a v1
resolver running against a v2 manifest will silently produce wrong output.
**Fix:** Add `schema_version` to the required-fields validator with an
explicit value check:
```zsh
local schema_value
schema_value=$(yq -r '.schema_version // ""' "$machine_file" 2>/dev/null)
if [[ -z "$schema_value" ]]; then
  error "missing required field: schema_version (must equal 1)"
  errors=$(( errors + 1 ))
elif [[ "$schema_value" != "1" ]]; then
  error "schema_version must equal 1; got: ${schema_value}"
  errors=$(( errors + 1 ))
fi
```

### WR-05: Hardcoded fixture count drifts when fixtures are added

**File:** `taskfiles/manifest.yml:231, 315`
**Issue:** The positive-fixture loop uses `for fix in "${fix_dir}"/0[1-6]-*`
and the summary uses `total=8`. Adding a 7th positive fixture requires editing
both the glob (`0[1-7]-*` or `0[0-9]-*`) and the constant. Easy to forget,
silent failure mode (the new fixture is never run), and the misleading
"6 passed of 8 total" output remains correct only by accident.
**Fix:** Compute the totals dynamically:
```bash
positive_count=0
for fix in "${fix_dir}"/[0-9][0-9]-*; do
  positive_count=$(( positive_count + 1 ))
  # ... existing test logic
done
negative_count=2  # or count "${fix_dir}"/_invalid-*/ similarly
total=$(( positive_count + negative_count ))
```

### WR-06: `manifest:show` / `manifest:validate` only accept `--machine NAME`, not bare names

**File:** `taskfiles/manifest.yml:159, 187`
**Issue:** Both tasks document `[-- --machine NAME]` and parse it via:
```bash
machine_name=$(printf '%s' "$cli_args" | sed -n 's/.*--machine[[:space:]]\{1,\}\([a-z0-9_][a-z0-9_-]*\).*/\1/p')
```
A user invoking `task manifest:show -- personal-laptop` (the natural form,
matching `task setup -- <name>` exactly) gets an unhelpful "no machine
selected" error because the regex requires the literal `--machine` token.
This is a UX inconsistency with the `setup` task, which accepts bare names.
**Fix:** Either accept both forms (try `--machine NAME` extraction first,
then fall back to using a bare-string CLI_ARGS as the machine name), or
update the docs to be explicit that `--machine` is the only accepted form
for these two tasks. The first option is friendlier:
```bash
machine_name=$(printf '%s' "$cli_args" | sed -n 's/.*--machine[[:space:]]\{1,\}\([a-z0-9_][a-z0-9_-]*\).*/\1/p')
if [[ -z "$machine_name" ]]; then
  candidate=$(printf '%s' "$cli_args" | tr -d '[:space:]')
  if [[ "$candidate" =~ ^[a-z0-9_][a-z0-9_-]*$ ]]; then
    machine_name="$candidate"
  fi
fi
```

### WR-07: `validate_manifest` reports errors on stdout — fragile to subprocess noise

**File:** `install/resolver.zsh:85-189`
**Issue:** The function communicates its error count via `echo "$errors"` on
the last line, and the caller does `errcount=$(validate_manifest ...)`. Every
yq invocation in the function is silenced with `2>/dev/null || echo false`,
which is correct, but if any future addition writes anything to stdout
(`echo`, an unwrapped command), the captured `errcount` becomes a
non-numeric string and the subsequent `(( errcount > 0 ))` test fires `set -e`
or evaluates strangely. The pattern is brittle for a function this large.
**Fix:** Use a global variable or a return code instead:
```zsh
validate_manifest() {
  VALIDATE_ERRORS=0
  # ... use (( VALIDATE_ERRORS++ )) instead of echo
  return $(( VALIDATE_ERRORS > 0 ? 1 : 0 ))
}
```
or split the count into a side-channel via a temp file that the caller
reads. The current pattern works today only because every internal stdout
producer is explicitly suppressed.

### WR-08: `machine_name="${machine_name//[[:space:]]/}"` silently rewrites embedded whitespace

**File:** `install/resolver.zsh:407`
**Issue:** After reading the state file, the script strips ALL whitespace,
not just leading/trailing. A state file containing `bad name\n` becomes
`badname`, which then either matches a real but unintended machine or fails
the regex check. The intent (per surrounding comments and the fact that the
state file is single-line) is to trim leading/trailing whitespace only.
**Fix:** Use parameter expansion to strip only edges:
```zsh
machine_name="${machine_name##[[:space:]]##}"
machine_name="${machine_name%%[[:space:]]##}"
```
or use a `read` builtin which trims naturally:
```zsh
read -r machine_name < "$STATE_FILE"
```
The same issue exists at `taskfiles/manifest.yml:63` (`tr -d '[:space:]'`)
and `taskfiles/manifest.yml:162, 190, 342, 346` — fix all sites together.

## Info

### IN-01: `vars: HOME: '{{.HOME}}'` is redundant

**File:** `taskfiles/manifest.yml:36`
**Issue:** Go-task already exposes `$HOME` as `.HOME` natively. The explicit
`HOME: '{{.HOME}}'` declaration adds no value and risks confusing readers
into thinking it serves a purpose (e.g., overriding HOME for tests).
**Fix:** Remove the line. If the intent is to ensure `XDG_STATE_HOME`'s
`sh:` block (line 39) sees a HOME var, that is handled by the parent
environment automatically.

### IN-02: `cat | tr` UUOC

**File:** `taskfiles/manifest.yml:63, 162, 190, 342, 346`
**Issue:** `cat '{{.STATE_FILE}}' 2>/dev/null | tr -d '[:space:]'` is a
useless use of cat. Stylistic but worth standardizing.
**Fix:** `tr -d '[:space:]' < '{{.STATE_FILE}}' 2>/dev/null` (and accept
`read -r` as a cleaner alternative, see WR-08).

### IN-03: `error` writes color codes even when stderr is not a TTY

**File:** `install/messages.zsh:46-47` (referenced by all reviewed files)
**Issue:** `error()` unconditionally emits `\033[0;31m` ... `\033[0m`. When
stderr is captured by `manifest:test` (e.g., line 286: `neg_stderr=$(... 2>&1
>/dev/null)`), the captured string contains ANSI escape sequences. The
subsequent `grep -q 'meta.description'` still works because the substring is
intact, but any future grep that anchors with `^` or `$` will silently fail
on the embedded escape codes.
**Fix:** Detect TTY and disable colors when not interactive:
```zsh
if [[ -t 2 ]]; then
  echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2
else
  echo "[ERROR] $*" >&2
fi
```
Out of strict Phase 1 scope (file is not in this phase's diff), but worth
flagging as the test driver depends on capturing this stream.

### IN-04: `ls | xargs basename | sed | tr` chain is fragile

**File:** `taskfiles/manifest.yml:81`
**Issue:** Parsing `ls` output is a known anti-pattern (filenames with
newlines, spaces, or shell metacharacters break it). Filenames in
`manifests/machines/` are constrained by the kebab-case regex so this won't
fail in practice, but the pattern is unidiomatic for zsh.
**Fix:** Use a zsh glob with a parameter expansion:
```yaml
AVAILABLE_MACHINES:
  sh: |
    setopt nullglob
    files=({{.MACHINES_DIR}}/*.toml)
    out=""
    for f in "${files[@]}"; do
      out+="${f:t:r} "
    done
    echo "${out% }"
```

### IN-05: `_invalid-bad-os/machine.toml` fixture has TOML quirk that may mislead

**File:** `manifests/test/fixtures/_invalid-bad-os/machine.toml:11`
**Issue:** The line `[features]` followed by a blank line and `[packages.brew]`
declares an empty inline `features` table. yq accepts this; some TOML parsers
reject empty section headers without subsequent keys (or treat them
ambiguously). Not a bug today, but if the resolver is ever ported off yq,
this fixture may parse differently.
**Fix:** Use the explicit empty-table form: `features = {}` instead of
`[features]\n\n`. Same change applies to `_invalid-missing-desc/machine.toml`.

### IN-06: Phase 1 docs reference Phase 2 wiring inconsistently

**File:** `docs/MANIFEST.md:341, 369`, `manifests/test/README.md:14`,
`manifests/README.md:18`
**Issue:** The `task setup -- <name>` examples in `docs/MANIFEST.md:351`
and `manifests/README.md:18` assume Phase 2 wiring (no `-t taskfiles/manifest.yml`
flag), while the explanatory note immediately above says "Phase 1 invocation:
use the `-t` flag". Readers who copy/paste the example commands will hit a
"task: No tasks with description available" error until Phase 2 lands.
**Fix:** Make the inconsistency explicit. Either prefix every example with
`-t taskfiles/manifest.yml` and add a "post-Phase-2" note, or split the
walkthrough into two code blocks (current / post-Phase-2). The current
mixed presentation is confusing.

---

_Reviewed: 2026-05-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
