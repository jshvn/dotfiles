---
phase: 08-validation-cutover-readiness
reviewed: 2026-05-16T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - README.md
  - Taskfile.yml
  - docs/CUTOVER.md
  - docs/MACHINES.md
  - docs/MIGRATION.md
  - taskfiles/claude.yml
  - taskfiles/links.yml
findings:
  critical: 4
  warning: 4
  info: 3
  total: 11
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-05-16
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 8 ships the validation aggregator (`task validate`), the cutover sentinel
writer (`task cutover:ack`), the orphan-symlink reconciler
(`task links:reconcile`), and four narrative docs (README, CUTOVER, MACHINES,
MIGRATION) that operationalize the v1->v2 cutover.

The aggregator pattern in `Taskfile.yml validate:` is solid: per-entry
`ignore_error: true`, run-all semantics, and a feature-disabled sentinel that
short-circuits to an `n/a` row. The Phase 8 `cutover:ack` task correctly
mirrors the `manifest:setup` security pattern (env-var pass-through, regex
validation, active-machine match).

Four BLOCKER findings reject the phase as currently submitted:

1. The fresh-machine procedure documented in CUTOVER.md and README.md
   contradicts the actual bootstrap behavior -- `bootstrap.zsh` calls
   `cutover_gate_check` which hard-fails (return 1) when
   `$XDG_STATE_HOME/dotfiles/machine` is absent. CUTOVER.md step 2 claims it
   "exits cleanly". The canonical 5-step install procedure cannot succeed as
   written.
2. `taskfiles/claude.yml marketplace:` status block tests `select(.name == "ecc@ecc")`
   while its install body and `validate:` test `select(.id == $i)`. The two
   selectors target different jq fields. One of them is wrong; whichever it
   is, you get either always-re-run (status fails forever) or always-reinstall
   (install body sees the plugin as missing) -- both regressions of the v1
   `macos:shell:145` idempotency bug class the phase explicitly closes.
3. `taskfiles/claude.yml validate:` prints `cross "claude CLI missing"` then
   exits 0. The Taskfile.yml aggregator captures rc=0 and renders the row as
   `check` -- a missing CLI is reported as a passing validation.
4. `taskfiles/links.yml configs:` has a status block that omits the ghostty
   link, so on a ghostty=true machine where only the ghostty link is broken
   (but the always-on configs are healthy), `task configs` short-circuits on
   status and never invokes `configs:ghostty`. This is the exact
   "partial-state regression class CR-02" the file's own header comment
   warns against.

Four warnings cover mixed-form `manifest:resolve` deps in claude.yml, a docs
claim that other validates emit the feature-disabled sentinel when only
`claude:validate` does, the `mode=detect` default branch in
`links:reconcile`, and double-running per-component validates. Three info
items cover MACHINES.md cask-list omissions and minor doc polish.

## Critical Issues

### CR-01: bootstrap.zsh exits 1 on fresh machine; documented procedure cannot complete

**File:** `docs/CUTOVER.md:33-38`, also `README.md:24-36`, cross-ref `bootstrap.zsh:111-112`, `install/cutover-gate.zsh:35-38`

**Issue:** CUTOVER.md "Fresh-machine verification" step 2 documents the canonical
fresh-install flow as:

> "On a first-time install the cutover-gate is invoked at the end of bootstrap
> for completeness but exits cleanly because no machine has been selected
> yet -- the machine file does not exist, so the gate skips the missing
> sentinel check and the script prints the next-step hint pointing at step 3."

This is incorrect. `install/cutover-gate.zsh:35-38` is the FIRST check in
`cutover_gate_check`:

```zsh
if [[ ! -f "$machine_file" ]]; then
  error "no machine selected (run: task setup -- <machine-name>)"
  return 1
fi
```

`bootstrap.zsh:111-112` calls `cutover_gate_check || exit 1`. On a fresh
machine the machine_file is absent, so the gate emits the "no machine
selected" error and returns 1, and `bootstrap.zsh` exits 1 BEFORE printing
the next-step hint at lines 117-124. The documented 5-step procedure
(`clone` -> `./bootstrap.zsh` -> `task setup` -> `task cutover:ack` ->
`task install`) cannot complete: step 2 (`./bootstrap.zsh`) errors out.

The README.md step-list at lines 30-36 inherits the same defect.

**Fix:** Pick one of two paths and align all artifacts:

Option A (docs match code): Update CUTOVER.md step 2 and README.md to
acknowledge that bootstrap exits non-zero on a fresh machine after the
tool-installs complete, and instruct the user to ignore that exit code (or
re-run after `task setup` and `task cutover:ack`).

Option B (code matches docs, recommended): Make `cutover_gate_check`
skip the missing-machine case as the docs describe -- treat
`[[ ! -f "$machine_file" ]]` as "not yet selected, gate not applicable"
(return 0) and only fail when the machine file exists but the ack file is
missing or malformed:

```zsh
# install/cutover-gate.zsh
cutover_gate_check() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  local machine_file="${state_dir}/machine"
  local ack_file="${state_dir}/cutover-ack"
  local active_machine ack_machine ack_ts

  # No machine selected yet -- bootstrap path. The gate has no machine to
  # check against; defer enforcement to `task install` preconditions, which
  # run AFTER `task setup` writes the machine file.
  if [[ ! -f "$machine_file" ]]; then
    return 0
  fi
  active_machine=$(head -n1 "$machine_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # ... rest unchanged
}
```

Note: `task install`'s precondition (Taskfile.yml:285-293) ALREADY calls
`cutover_gate_check`. The bootstrap-time invocation in `bootstrap.zsh:112` is
documented as "for completeness". With Option B, the install-time check still
fires when a machine has been selected but not acked -- the defense-in-depth
property is preserved while the documented fresh-install flow actually works.

### CR-02: marketplace status block tests .name; install/validate test .id -- one is wrong, both classes of failure are idempotency regressions

**File:** `taskfiles/claude.yml:125-127` vs `:150` and `:277`

**Issue:** The `marketplace:` task has three jq selectors that should target
the same field for the same plugin object, but they disagree:

| Line | Context | Selector |
|------|---------|----------|
| 127 | `marketplace:` status block, plugin probe | `select(.name == "ecc@ecc")` |
| 150 | `marketplace:` cmds, plugin probe | `select(.id == $i)` |
| 277 | `validate:` cmds, plugin probe | `select(.id == $i)` |

`CLAUDE_PLUGINS` declares the entry as `ecc@ecc`. This is the plugin's
fully-qualified id (`<name>@<marketplace>`), not its bare name. Either:

- `.id == "ecc@ecc"` is correct and `.name == "ecc@ecc"` always fails -- the
  status block never returns success, the task always re-runs, and
  `claude plugin install ecc@ecc` re-fires on every `task install`. The
  install body itself protects against actual reinstall via the line-150
  `.id` check inside `MARKETPLACES_JSON`/`PLUGINS_JSON`, but the outer
  `marketplace:` task's status idempotency is lost. This is the
  `macos:shell:145` re-run-forever bug class.

- `.name == "ecc@ecc"` is correct (plugin objects have `.name` set to the
  qualified id), in which case the install body and validate both fail to
  find the installed plugin and try to re-install it on every run.

Either way, the two-condition idempotency claim in the file header
(lines 25-30: "claude:marketplace is a no-op when BOTH conditions hold...")
is structurally broken: the line-127 selector cannot return success if
the line-150 selector does, and vice versa.

**Fix:** Align all three selectors on the same field. The intended contract
from the file header is "plugin id" (D-12 / CLDE-04). Use `.id`
everywhere:

```yaml
# taskfiles/claude.yml:127 -- status: block, plugin probe
- jq -e '.[] | select(.id == "ecc@ecc")' <(claude plugin list --json 2>/dev/null || echo '[]') >/dev/null
```

After fixing, validate by running `claude plugin list --json` on a
real machine and confirming the actual object shape exposes `.id` (not
just `.name`). If the CLI only exposes `.name`, flip lines 150 and 277
to `.name` instead -- but the three MUST agree.

### CR-03: claude:validate prints cross then exits 0 on missing claude CLI -- root validate reports green

**File:** `taskfiles/claude.yml:240-245`

**Issue:** When `claude` is missing from PATH:

```yaml
if command -v claude >/dev/null 2>&1; then
  check "claude CLI installed"
else
  cross "claude CLI missing -- run 'task packages:install' first"
  exit 0          # <-- exits 0 on a hard failure!
fi
```

The Taskfile.yml aggregator captures rc=0 (line 192) and the elif branch
matches: `check "${component}"`. The validation summary table shows the
`claude` row as passing (green check) even though the CLI is missing and
the per-component output already printed the cross.

This silently passes a known-broken state. A red-team operator running
`task validate` after a partial install would see "claude: check" and
conclude the install is complete; the actual `cross` message is buried in
the verbose output above the summary.

Cross-reference: this defeats the entire purpose of the validation
aggregator. CUTOVER.md step 6 explicitly says "All six rows must show
check on a freshly installed machine".

**Fix:** Exit non-zero on missing CLI:

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  {{if not (index .MANIFEST.features "claude-marketplace")}}
  info "claude: feature disabled -- skipped"
  exit 0
  {{end}}
  rc=0
  if command -v claude >/dev/null 2>&1; then
    check "claude CLI installed"
  else
    cross "claude CLI missing -- run 'task packages:install' first"
    rc=1
  fi
  if command -v jq >/dev/null 2>&1; then
    check "jq installed"
  else
    cross "jq missing -- run 'task packages:install' first"
    rc=1
  fi
  exit "$rc"
```

Same pattern applies to the `jq` check at lines 246-250 -- it currently
prints cross but doesn't set a non-zero exit either. After the missing-CLI
check the script falls through to the marketplace/plugin/GSD checks anyway,
which will all fail loudly when `claude` or `jq` is absent. The aggregate
exit code from the final block (lines 282-290) is the only signal the root
validator reads.

### CR-04: configs: status block omits ghostty -- partial-state regression class the comment warns against

**File:** `taskfiles/links.yml:224-247` (status block 241-247) vs `:258-266`

**Issue:** The `configs:` task creates 7 symlinks (6 always-on + 1
ghostty-gated). The `cmds:` block invokes `task: configs:ghostty` as its
first entry and then 6 `_:safe-link` calls for the always-on configs. But
the `status:` block (lines 241-247) only checks the 6 always-on links and
omits the ghostty link.

go-task semantics: a task with a status: block that returns success will
SKIP its cmds entirely -- including any `task: <other>` sub-task calls
inside the cmds. So on a ghostty=true machine where the ghostty link is
missing or broken but all 6 always-on configs are healthy:

1. `task configs:` status evaluation runs the 6 `test -L` checks.
2. All 6 succeed; status returns 0.
3. go-task skips the entire cmds block.
4. `task: configs:ghostty` is never invoked.
5. The broken ghostty link is never repaired.

The file's own header comment at links.yml:25-30 explicitly warns:

> "A status: block on the aggregator that only checks a subset of the
> sub-tasks' symlinks would short-circuit on partial state -- the exact
> macos:shell:145 regression class CR-02 closes."

The `configs:` task does exactly that. The comment block at lines 250-255
on `configs:ghostty` justifies its isolation as "the gate works
independently of the always-on tool configs" -- but that isolation is moot
when the parent task's own status short-circuits before `configs:ghostty`
gets called.

**Fix:** Either (a) lift the ghostty link into the `configs:` status block
as a gated entry, mirroring the `claude:` status pattern at lines 204-216:

```yaml
configs:
  desc: "Link tool config files (ghostty, glow, trippy, tlrc, conda, eza)"
  deps: [":manifest:resolve"]
  cmds:
    - task: configs:ghostty
    - task: _:safe-link
      vars: { ... glow ... }
    # ... rest
  status:
    - '{{if not (index .MANIFEST.features "ghostty")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/ghostty/config"{{end}}'
    - test -L "{{.XDG_CONFIG_HOME}}/glow/glow.yml"
    # ... rest of always-on entries
```

Or (b) remove the `status:` block from `configs:` entirely (it becomes a
cmds-only aggregator) and rely on each sub-task / `_:safe-link` invocation
to be idempotent. The `_:safe-link` helper already uses `ln -sfn` which
is idempotent; the only reason `configs:` has status currently is to
skip the work cost when everything is converged. The cmds-only form
costs a few `ln -sfn` no-op invocations but cannot regress on partial
state.

The CR-02 mention in the comment is recursive (it refers to a CR-02 in a
PRIOR review of links.yml that closed the equivalent shell-startup-files
regression). This CR-04 re-opens it for the configs: subtree.

## Warnings

### WR-01: claude.yml uses bare `manifest:resolve` in deps for install/marketplace/update; uses leading-colon form only in validate

**File:** `taskfiles/claude.yml:88, 116, 188` (bare) vs `:227` (leading colon)

**Issue:** Inconsistent dep reference form across the same file:

| Line | Task | Deps |
|------|------|------|
| 88 | `install` | `deps: [manifest:resolve]` |
| 116 | `marketplace` | `deps: [ensure-cli, manifest:resolve]` |
| 188 | `update` | `deps: [ensure-cli, manifest:resolve]` |
| 227 | `validate` | `deps: [":manifest:resolve"]` |

The same root taskfile is included as `claude: ./taskfiles/claude.yml`. Within
claude.yml's namespace, the bare reference `manifest:resolve` does not name a
local task (claude.yml has no `manifest:resolve`); go-task currently falls
through to the root-included `manifest:resolve` for the bare form, which is
why this works today. The explicit `:manifest:resolve` (leading colon)
unambiguously addresses the root namespace and is the form `links.yml` uses
consistently (5 occurrences, all with leading colon).

This is a portability hazard: future go-task versions tightening namespace
resolution semantics could break the bare form. The mixed-form pattern also
implies different intent at each call site when there is none.

**Fix:** Convert all three bare references to the leading-colon form for
consistency with `validate:` (line 227) and `links.yml`:

```yaml
# taskfiles/claude.yml:88
install:
  ...
  deps: [":manifest:resolve"]

# taskfiles/claude.yml:116
marketplace:
  ...
  deps: ["ensure-cli", ":manifest:resolve"]

# taskfiles/claude.yml:188
update:
  ...
  deps: ["ensure-cli", ":manifest:resolve"]
```

Same pattern in `Taskfile.yml:141, 294` -- the root taskfile uses bare
`manifest:resolve` for `validate:` and `install:` deps. Since these are AT
the root (not in an included taskfile), the bare form is unambiguous there;
no change required. The inconsistency is only between the same file's
internal references.

### WR-02: CUTOVER.md claims `claude` n/a is the example, implying other components emit the same sentinel -- only claude:validate does

**File:** `docs/CUTOVER.md:70-72`, cross-ref `taskfiles/claude.yml:237`, all
other `*:validate` tasks

**Issue:** CUTOVER.md step 6 says:

> "feature-off components (e.g., `claude` on server-1 where `claude-marketplace`
> is false) show `n/a` and are considered passing."

The "e.g., `claude`" framing implies other components show n/a when their
features are off. But a grep across the taskfiles shows only `claude.yml:237`
emits the contract substring `feature disabled -- skipped`:

```
$ grep -rn "feature disabled" taskfiles/
taskfiles/claude.yml:234: # Sentinel substring `feature disabled -- skipped` is contract-bound across
taskfiles/claude.yml:237:     info "claude: feature disabled -- skipped"
```

No other `*:validate` task (identity, links, macos, packages, manifest)
emits this sentinel. So on server-1:

- `claude:validate` -> emits sentinel -> aggregator renders `n/a   claude`
- `identity:validate`, `links:validate`, etc. -> run full validate paths

This isn't necessarily wrong (other validates may correctly pass even when
their features are off because feature-gated entries no-op internally), but
the documentation framing leads operators to expect symmetric "feature off
-> n/a" behavior across all rows. On server-1 specifically, the docs claim
several feature flags are absent / off (macos-dock, macos-finder, etc.). If
`macos:validate` doesn't emit the sentinel and instead returns rc=0 because
the gated work was no-oped, the aggregator renders `check macos` -- not
`n/a macos`. This is fine for "passing" semantics but contradicts the
"feature-off rows show n/a" expectation.

**Fix:** Tighten the CUTOVER.md wording to reflect reality:

```markdown
6. Run `task validate`. The composed validator runs every per-component
   validate (manifest, identity, links, macos, packages, claude) to
   completion regardless of any single failure and prints a check/cross/n/a
   summary table at the end. All six rows must show `check` or `n/a` on a
   freshly installed machine. Currently only `claude:validate` emits the
   feature-disabled sentinel that the aggregator renders as `n/a`; the
   other components return `check` even when their feature flags are off
   because the underlying validates internally no-op feature-gated work
   rather than emitting a separate skip marker.
```

If symmetric behavior is intended (per the prose), the other validates
must adopt the same sentinel pattern -- but that's a code change, not a
docs change.

### WR-03: links:reconcile case statement has no default branch -- silent no-op on unknown mode

**File:** `taskfiles/links.yml:487-534`

**Issue:** The `case "$mode" in` block dispatches on three modes (detect, warn,
remove). The initialization at line 408 sets `mode="detect"` and the only
mutators are the two `case " $cli " in *" --remove "*` / `*" --warn-only "*`
blocks. So `$mode` is always one of the three. Still, the case statement has
no `*) ... ;;` catch-all. If a future refactor introduces a fourth mode or a
flag-parsing bug sets `$mode` to an unexpected value, the case statement
falls through silently -- exit 0 with no orphan action taken.

This is defensive-coding hygiene, not a present-day bug.

**Fix:** Add an explicit catch-all so unknown modes surface as a hard error:

```yaml
case "$mode" in
  detect)
    # ...
    ;;
  warn)
    # ...
    ;;
  remove)
    # ...
    ;;
  *)
    error "links:reconcile: internal bug -- unknown mode '$mode'"
    exit 1
    ;;
esac
```

### WR-04: validate: aggregator runs each per-component validate twice; documented but wasteful

**File:** `Taskfile.yml:150-199`

**Issue:** The `validate:` aggregator has two phases:

1. Lines 151-162: six `task: <component>:validate` calls with
   `ignore_error: true`. These print per-component output to the user's
   terminal.
2. Lines 187-198: a for-loop that re-invokes the same six validates via
   `task "${component}:validate"` inside a $(...) substitution, capturing
   exit code + output to decide row state.

The comment block on lines 164-169 acknowledges this:

> "double-run cost is negligible, milliseconds per component"

True for read-only validates, but two concerns remain:

1. Any per-component validate that has accidental side effects (e.g.,
   touches a sentinel file, writes a state cache) will run twice. The phase
   relies on "idempotent read-only" semantics across all six validates;
   that's an architectural assumption with no enforcing test.
2. The per-component output prints to terminal twice when the second run
   captures via `$(...)`. Actually only once -- the $(...) capture
   suppresses the second print -- but the user-facing UX is "see each
   validate's output, then see the summary table". A single-pass design
   would be cleaner: capture exit code and tee output for the user in one
   pass.

**Fix:** Single-pass design using a tempfile or process substitution:

```yaml
- |
  source '{{.TASKFILE_DIR}}/install/messages.zsh'
  set +e +o pipefail
  failures=0
  declare -A rc_by_component output_by_component
  for component in manifest identity links macos packages claude; do
    tmpfile=$(mktemp)
    task "${component}:validate" 2>&1 | tee "$tmpfile"
    rc=${PIPESTATUS[0]}
    rc_by_component[$component]=$rc
    output_by_component[$component]=$(<"$tmpfile")
    rm -f "$tmpfile"
  done
  header "Validation Summary"
  for component in manifest identity links macos packages claude; do
    rc=${rc_by_component[$component]}
    output=${output_by_component[$component]}
    if echo "$output" | grep -q "feature disabled -- skipped"; then
      info "n/a   ${component}"
    elif [ "$rc" -eq 0 ]; then
      check "${component}"
    else
      cross "${component}"
      failures=$(( failures + 1 ))
    fi
  done
  exit "$failures"
```

The associative-array form requires bash; mvdan/sh supports it. Alternative:
collect to a here-string and parse, or use parallel arrays. The current
"document the double-run" approach is acceptable if the architectural
assumption ("validates are pure") is genuinely enforced; if it's just
documented intent, this becomes a latent footgun.

## Info

### IN-01: MACHINES.md cask lists are incomplete vs the TOMLs

**File:** `docs/MACHINES.md:24-25` (personal-laptop), `:43-45` (work-laptop), cross-ref `manifests/machines/personal-laptop.toml:34-67`, `manifests/machines/work-laptop.toml:32-56`

**Issue:** MACHINES.md describes itself as "brief by design" with the TOML as
source of truth. The personal-laptop cask narrative omits `whatsapp`,
`appcleaner`, `alcove`, `dropbox`, `cryptomator`, `standard-notes`,
`fantastical`, `cardhop`, `zoom`, `firefox`, `nvidia-geforce-now`, and the
MAS apps `Magnet` / `Things3`. The work-laptop narrative omits `spotify`,
`appcleaner`, `alcove`, `standard-notes`, `fantastical`, `cardhop`, plus MAS
`Magnet` / `Things`.

Since the file explicitly defers to TOML for declarative state, this is
forgivable. But the prose currently reads like an exhaustive list of installed
apps, which it isn't. A reader cross-referencing MACHINES.md against the
actual installed-app set will find numerous mismatches.

**Fix:** Either (a) replace the prose enumeration with a one-line "see TOML
for the full cask list" and drop the inline cask names, or (b) make the
prose accurate by listing all casks. Option (a) matches the file's stated
purpose better:

```markdown
- Role narrative: full GUI + dev + personal feature set. Day-to-day use is
  personal-project development, dotfiles iteration, and Claude Code
  experimentation. The personal git/ssh identity is wired through this
  machine. See `manifests/machines/personal-laptop.toml` for the full cask
  and MAS list.
```

### IN-02: Server-2 narrative is largely a copy-paste of server-1 with limited differentiation

**File:** `docs/MACHINES.md:75-93`

**Issue:** The server-2 section mirrors server-1 verbatim except for the
"second" qualifier and the blast-radius rationale at lines 88-91. The
"Hardware" line uses the identical "Apple Silicon or Intel -- arch detected
by the resolver via uname -m because [platform].arch is absent in the
server-2 TOML" wording.

The TOML files for server-1 and server-2 are nearly identical aside from
the identity name. The MACHINES.md value-add is the prose rationale; on
server-2 most of the prose is "same shape as server-1". This is acceptable
but could be tightened.

**Fix:** Either consolidate server-1 and server-2 under a single "Mac
servers" section with a brief per-host call-out, or leave as-is and accept
the duplication. No blocking issue.

### IN-03: README.md and CUTOVER.md both describe the 5-step procedure; the two should explicitly cross-link

**File:** `README.md:24-36`, `docs/CUTOVER.md:14-86`

**Issue:** Both docs present the canonical fresh-install procedure. README.md
gives a 5-line block; CUTOVER.md gives an 8-step enumeration with prose. They
diverge in two ways:

- README.md compresses bootstrap + setup + cutover:ack + install into 4 commands
  (clone is step 0); CUTOVER.md splits them across steps 1-5 with prose.
- CUTOVER.md adds steps 6 (`task validate`), 7 (begin soak), 8 (after 7
  days). README.md doesn't mention these post-install steps.

The README.md last paragraph ("For the full per-machine procedure...") does
cross-link to CUTOVER.md, which is good. But the two sources presenting
overlapping-but-different versions of the same procedure invites drift. CR-01
above already demonstrates one drift (the bootstrap-exits-cleanly claim only
exists in CUTOVER.md, not README.md).

**Fix:** No code change required. As a docs hygiene practice, treat CUTOVER.md
as the canonical procedure source and have README.md include only the
minimum 4-command block + cross-link. Reduces the surface area where the
two can diverge.

---

_Reviewed: 2026-05-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
