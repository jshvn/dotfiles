---
status: diagnosed
trigger: "task identity:git prints 'warning: /resolved.json missing or empty -- run task setup -- <machine> first' (bare-slash path) even when resolved.json exists; task identity:ssh does not. Two-part bug: (a) bare-slash path interpolation, (b) spurious-fire on success. Discovered in Phase 04 verify-work UAT 2026-05-14."
created: 2026-05-14T00:00:00Z
updated: 2026-05-14T00:30:00Z
---

## Current Focus

hypothesis: CONFIRMED. The bare-slash warning is emitted from `taskfiles/manifest.yml`'s `MANIFEST_JSON` `sh:` block. Its `RESOLVED_JSON_PATH` substitutes to the literal string `/resolved.json` because, when `manifest.yml` is loaded as an INCLUDE from the root `Taskfile.yml`, its template variable `STATE_DIR` (`'{{.XDG_STATE_HOME}}/dotfiles'`) is not in the substitution scope used to render `MANIFEST_JSON`'s sh: text. The chain `RESOLVED_JSON_PATH = '{{.STATE_DIR}}/resolved.json'` collapses with `STATE_DIR=""` to the literal `'/resolved.json'`. The MANIFEST_JSON sh: then runs with that bare path, finds no file, and emits the warning to stderr. The "spurious-fire on success" symptom is because there are TWO different MANIFEST_JSON `sh:` evaluations in the same task graph: the broken one from manifest.yml (always emits the warning), and a working one from identity.yml (which uses the FLAT template `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'` and substitutes correctly). Identity.yml's working evaluation populates the actual MANIFEST ref used by the cmds, so the cmds see the real data — both the broken warning AND the correct substitution coexist. The "asymmetry between identity:git and identity:ssh" symptom is illusory: with `--force` BOTH tasks fire the warning. The user only saw it on git because, at that moment, ssh's `status:` block was satisfied (already linked) and skipped its `cmds:` execution, while git's was about to run.

test: completed (see Evidence)
expecting: completed
next_action: return ROOT CAUSE FOUND structured result; do NOT fix (diagnose-only mode)

## Symptoms

expected: |
  When resolved.json exists at `$XDG_STATE_HOME/dotfiles/resolved.json`, no warning is emitted by `task identity:git` or `task identity:ssh`. The fallback warning, when it does fire on a fresh machine, must show the real interpolated path (e.g. `/Users/josh/.local/state/dotfiles/resolved.json`), not a bare slash.
actual: |
  (a) Warning fires even when resolved.json exists and parses correctly:
        warning: /resolved.json missing or empty -- run 'task setup -- <machine>' first
  (b) Path is literally `/resolved.json` -- leading slash with the basename only. Both `XDG_STATE_HOME` AND `dotfiles/` are missing from the path.
  (c) Asymmetry observed: `task identity:git` fires warning, `task identity:ssh` does not (initially attributed to a per-task code path; actually a status-block cache effect -- both fire when `--force`d).
  (d) Real MANIFEST loader path WORKS: cmds receive correct `{{.MANIFEST.identity.git}}`, symlinks materialize correctly, exit code 0.
errors: |
  No errors -- exit 0. Just spurious stderr noise.
reproduction: |
  Test 1 (gap 2) in `.planning/phases/04-identity-layer-git-ssh-per-machine/04-UAT.md`.
  1. On a machine with valid resolved.json: `task identity:git --force` (or `task identity:git` when symlinks have not yet been created).
  2. Observe warning text on stderr: `warning: /resolved.json missing or empty -- run 'task setup -- <machine>' first`.
  3. Compare with `task identity:ssh --force` from the same machine -- same warning fires.
  4. Run `task identity:git -v --force` to see the underlying sh: text: two MANIFEST_JSON sh: evaluations occur, one with bare path `/resolved.json` (broken), one with full path (working).
started: Discovered during Phase 04 verify-work UAT on 2026-05-14.

## Eliminated

- hypothesis: "Bare-slash path comes from `taskfiles/identity.yml`'s `MANIFEST_JSON` sh: block (line 72-79) with `XDG_STATE_HOME` empty."
  evidence: |
    identity.yml line 67 declares `RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'`. With XDG_STATE_HOME="" this would substitute to `/dotfiles/resolved.json` (still has `dotfiles/`). The observed bare-slash form `/resolved.json` does NOT contain `dotfiles/`. Only manifest.yml's chain `RESOLVED_JSON_PATH = '{{.STATE_DIR}}/resolved.json'` with `STATE_DIR=""` produces the exact observed string. Verbose output additionally shows the identity.yml MANIFEST_JSON evaluating with the FULL correct path -- ruling it out as the source of the bare-slash form.
  timestamp: 2026-05-14T00:25:00Z

- hypothesis: "Asymmetry is a real per-task bug (only `identity:git` calls the broken warn-helper; `identity:ssh` doesn't)."
  evidence: |
    `task identity:ssh --force` reproduces the EXACT same `warning: /resolved.json` line. Both tasks pull in the same included taskfiles. The asymmetry the user observed in normal (non-forced) mode is purely an artifact of go-task's `status:` block caching: when a task's `status:` evaluates true (everything is up-to-date), the task's `cmds:` (and thus the eager-eval of `MANIFEST_JSON` references) are skipped. `identity:git` was about to actually run on that machine (state mismatch); `identity:ssh` was status-true and short-circuited.
  timestamp: 2026-05-14T00:27:00Z

- hypothesis: "Bare-slash warning is from root `Taskfile.yml`'s `MANIFEST_JSON` sh: block (line 63-70)."
  evidence: |
    Root Taskfile.yml's MANIFEST_JSON sh: text uses `-f` (not `-s`) and writes `"warn: resolved.json not found (run 'task setup -- <machine>')"` (different prefix `warn:` and different wording). Verbose output's broken sh: uses `-s` and writes `"warning: /resolved.json missing or empty -- run 'task setup -- <machine>' first"`. The text shape matches manifest.yml/identity.yml verbatim, NOT root.
  timestamp: 2026-05-14T00:28:00Z

## Evidence

- timestamp: 2026-05-14T00:10:00Z
  checked: |
    File on disk vs. observed warning. `test -s /Users/josh/.local/state/dotfiles/resolved.json && echo NONEMPTY` returns NONEMPTY; `printenv XDG_STATE_HOME` returns `/Users/josh/.local/state`.
  found: |
    The file exists, is non-empty, parses as valid JSON. The shell environment has XDG_STATE_HOME set correctly. The bug is NOT a missing-file or missing-env issue.
  implication: |
    The warning's IF-branch (`[[ -s '/resolved.json' ]]`) is testing a wrong path constructed by go-task template substitution -- not by environment misconfiguration.

- timestamp: 2026-05-14T00:12:00Z
  checked: |
    All `taskfiles/*.yml` and `Taskfile.yml` for the literal warning string `"missing or empty"` to identify candidate sources.
  found: |
    Only TWO sources produce the exact warning text observed:
      - `taskfiles/manifest.yml:85`: `echo "warning: {{.RESOLVED_JSON_PATH}} missing or empty -- run 'task setup -- <machine>' first" >&2`
      - `taskfiles/identity.yml:77`: identical text.
    Root `Taskfile.yml:68` uses different wording: `"warn: resolved.json not found (run 'task setup -- <machine>')"`.
  implication: |
    The warning must come from manifest.yml or identity.yml. Distinguishing the two requires looking at the path-construction chain in each.

- timestamp: 2026-05-14T00:14:00Z
  checked: |
    Path-construction chains in each candidate:
      manifest.yml line 51-53:
          STATE_DIR: '{{.XDG_STATE_HOME}}/dotfiles'
          RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'
      identity.yml line 67:
          RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'
      root Taskfile.yml line 59:
          RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'
  found: |
    Substitution outcome by which variable is empty:
      | source | XDG empty | STATE_DIR empty | both empty |
      |--------|-----------|-----------------|------------|
      | manifest.yml | /dotfiles/resolved.json | /resolved.json | /resolved.json |
      | identity.yml | /dotfiles/resolved.json | n/a (uses XDG directly) | /dotfiles/resolved.json |
      | root  | /dotfiles/resolved.json | n/a | /dotfiles/resolved.json |

    Only manifest.yml's chain produces the OBSERVED bare-slash form `/resolved.json` -- and only when its TEMPLATE var STATE_DIR is empty during substitution.
  implication: |
    The bug source is manifest.yml. Specifically: `STATE_DIR` evaluates to `""` at the moment manifest.yml's MANIFEST_JSON sh: text is rendered for evaluation.

- timestamp: 2026-05-14T00:18:00Z
  checked: |
    `task identity:git --force -v` to capture all dynamic-variable evaluations.
  found: |
    Verbose output reveals TWO distinct MANIFEST_JSON sh: evaluations during this single invocation:

      (#5 in eval order, BROKEN) -- identical text shape to manifest.yml:80-87 and identity.yml:72-79:
        if [[ -s '/resolved.json' ]]; then
          cat '/resolved.json'
        else
          echo "warning: /resolved.json missing or empty -- run 'task setup -- <machine>' first" >&2
          echo '{}'
        fi
      result: "{}"

      (#8 in eval order, WORKING):
        if [[ -s '/Users/josh/.local/state/dotfiles/resolved.json' ]]; then
          cat '/Users/josh/.local/state/dotfiles/resolved.json'
        ...
      result: full resolved.json content

    `XDG_STATE_HOME` was already evaluated to `/Users/josh/.local/state` at position #2, BEFORE the broken MANIFEST_JSON ran. So `XDG_STATE_HOME` was set in the var table by the time the broken MANIFEST_JSON's sh: text was rendered. But the path string in the rendered text is `/resolved.json` (no `dotfiles/`), which can ONLY happen if `STATE_DIR` is missing/empty in the substitution context for manifest.yml's `MANIFEST_JSON`.
  implication: |
    Confirms the broken evaluation is manifest.yml's MANIFEST_JSON, with its dependency-chain template var STATE_DIR resolving to empty during substitution. The working evaluation is identity.yml's MANIFEST_JSON (uses XDG_STATE_HOME directly without an intermediate template var).

- timestamp: 2026-05-14T00:20:00Z
  checked: |
    Standalone manifest.yml invocation: `task -t taskfiles/manifest.yml manifest:resolve --force -v`.
  found: |
    Single MANIFEST_JSON evaluation, with FULL correct path `/Users/josh/.local/state/dotfiles/resolved.json`. No bare-slash form. No double evaluation.
  implication: |
    When manifest.yml is loaded standalone (NOT via the root Taskfile.yml include), its `STATE_DIR` template var DOES resolve correctly. The bug only manifests when manifest.yml is loaded as an include with the root's `vars: { XDG_STATE_HOME: ... }` override block. This narrows the failure to the include-with-vars-override interaction.

- timestamp: 2026-05-14T00:22:00Z
  checked: |
    Asymmetry hypothesis: `task identity:git --force` vs `task identity:ssh --force`.
  found: |
    Both fire the SAME bare-slash warning. The user-observed asymmetry was a status-block effect: when a task's `status:` block evaluates true, its cmds skip and the broken eval is ALSO skipped (or its output is suppressed because the task is "up to date"). Without --force, identity:ssh's `status:` block was satisfied (all symlinks present); identity:git's was not (some link missing or out of sync). The bug is symmetric across both tasks; the symptom presentation is asymmetric only because of cache.
  implication: |
    The investigation hint about server-include or per-task code-path was a red herring. Both tasks pull in the same included taskfiles and trigger the same broken eval; the difference was purely whether the task ran cmds at all. (Note: the broken sh: eval at task-graph build time is suppressed by go-task's verbose-mode output filtering when no task actually executes; this is why running `task identity:ssh` alone showed no warning.)

- timestamp: 2026-05-14T00:24:00Z
  checked: |
    External research: go-task GitHub issues on included-taskfile var evaluation.
  found: |
    Issue #1295 "Included taskfiles don't use provided vars while evaluating their vars": vars passed to an included taskfile via the include's `vars:` block are NOT available during the included file's own `sh:` (and template var) evaluation phase.
    Issue #2108 "Variables from included Taskfiles cannot be overwritten": parent's `vars:` overrides on the include don't reliably override the included file's local vars in all contexts.
    Issue #535 "Vars are not interpolated before deps in a task" + general behaviour: go-task evaluates dynamic (sh:) vars EAGERLY at startup for ALL included taskfiles -- even those whose tasks aren't being invoked.
  implication: |
    These issues collectively explain the broken eval. When root Taskfile.yml includes manifest.yml with `vars: { XDG_STATE_HOME: ... }`, go-task evaluates manifest.yml's vars block at startup. During that evaluation, the parent's forwarded `XDG_STATE_HOME` IS available (it's the only var the parent forwards), but the chain `STATE_DIR -> RESOLVED_JSON_PATH -> MANIFEST_JSON` interacts with the parent override in a way that makes `STATE_DIR` evaluate to empty at substitution time. The exact mechanism is the documented include-vars-evaluation-order issue: when manifest.yml renders the sh: text for `MANIFEST_JSON`, the substitution context includes the parent-forwarded `XDG_STATE_HOME` but does NOT include the locally-derived `STATE_DIR` (because local template vars aren't yet present in the scope used to render MANIFEST_JSON's sh: text). Standalone, this race doesn't happen because there is no parent-vars override block to interleave with the local var resolution.

- timestamp: 2026-05-14T00:26:00Z
  checked: |
    Behaviour of broken eval w.r.t. real data: does the cmds: actually receive `{}` or the real resolved.json content?
  found: |
    cmds: receive the REAL resolved.json content. Verified by:
      - Symlinks materialize at the correct paths.
      - `task identity:git --force` exits 0 with green check marks.
      - The MANIFEST ref used during cmds: substitution is from identity.yml's WORKING evaluation (which has the real JSON), not manifest.yml's BROKEN evaluation (which has `{}`).
  implication: |
    The broken evaluation in manifest.yml is benign in terms of correctness: nothing in the cmds: actually consumes its `{}` output. It only produces stderr noise. The reason: each included taskfile has its OWN `MANIFEST` ref bound to its OWN `MANIFEST_JSON` sh: var (per the existing `ref: 'fromJson .MANIFEST_JSON'` line in each file). When identity:git's cmds: reference `{{.MANIFEST.identity.git}}`, they resolve through identity.yml's MANIFEST ref, not manifest.yml's. So the broken eval is isolated -- it just runs and emits the warning, then its `{}` output is discarded because nothing consumes it. This explains symptom (b) "spurious-fire on success" perfectly.

## Resolution

root_cause: |
  TWO closely related issues combine to produce the symptoms:

  1. PRIMARY (path-construction): `taskfiles/manifest.yml` defines `RESOLVED_JSON_PATH` via a TWO-HOP template chain:
        STATE_DIR: '{{.XDG_STATE_HOME}}/dotfiles'           # line 51
        RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'  # line 53
        MANIFEST_JSON: sh: ... [[ -s '{{.RESOLVED_JSON_PATH}}' ]] ...  # line 80
     When manifest.yml is loaded as an INCLUDE from root `Taskfile.yml` (which forwards only `XDG_STATE_HOME`, `DOTFILEDIR`, `DOTFILES_MESSAGES` via the include's `vars:` block), go-task's variable substitution renders the `MANIFEST_JSON` sh: text against a scope where `XDG_STATE_HOME` is set BUT the locally-derived intermediate template var `STATE_DIR` is NOT in scope. The substitution chain therefore collapses:
        '{{.STATE_DIR}}/resolved.json' -> '/resolved.json'   (STATE_DIR empty)
     Resulting sh: text:
        if [[ -s '/resolved.json' ]]; then ... else echo "warning: /resolved.json missing or empty ..." >&2; echo '{}' fi
     The `[[ -s '/resolved.json' ]]` test always fails (no such file at filesystem root), so the warning fires unconditionally, and the fallback `{}` is returned.

     This is the documented go-task behaviour described in issues #1295 and #2108: vars passed to an included taskfile via the include's `vars:` block are not available (and the included file's own template vars don't fully resolve) during the included file's own sh: var evaluation phase. The same chain works correctly when manifest.yml is invoked STANDALONE (`task -t taskfiles/manifest.yml ...`) because there is no parent-forwarded override block to interleave with local var resolution.

  2. SECONDARY (eager eval + status-block masking): go-task evaluates `sh:` vars EAGERLY at startup for ALL included taskfiles, even those whose tasks aren't being invoked. So invoking `task identity:git` triggers manifest.yml's broken `MANIFEST_JSON` sh: evaluation (issue #535 + documented changelog behaviour). The "warning fires even when resolved.json exists" symptom is explained by this eager eval: it runs whether or not the file exists at the right path, because it's always testing the wrong path.

     The "asymmetry between identity:git and identity:ssh" symptom is an artefact of go-task's `status:` block caching: when a task's `status:` evaluates true (work already done), the task's `cmds:` are skipped AND the verbose/normal-mode trace of the eager-eval warning is suppressed (the task is reported as "up to date"). On the user's clean machine, ssh was status-true and skipped silently; git was status-false and ran (with the warning visible). With `--force`, both tasks reproduce the warning identically.

     The "real MANIFEST loader works" symptom is because each included taskfile has its OWN `MANIFEST` ref bound to its OWN `MANIFEST_JSON` sh: block. identity.yml's `MANIFEST_JSON` uses the FLAT one-hop template `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'`, which substitutes correctly even in the include-with-vars-override context (XDG_STATE_HOME is the parent-forwarded var, no intermediate hop needed). So identity.yml's MANIFEST ref resolves to the real JSON content, while manifest.yml's MANIFEST ref resolves to `{}` -- and only the former is consumed by identity:git/identity:ssh cmds:.

  NET: The bug is the two-hop template chain in `taskfiles/manifest.yml` (`STATE_DIR` -> `RESOLVED_JSON_PATH` -> `MANIFEST_JSON`) interacting with go-task's well-known include-vars-evaluation-order quirk. The symptom is purely cosmetic stderr noise; correctness is unaffected because identity.yml's parallel one-hop chain produces the actual MANIFEST data consumed by the cmds.

fix: |
  (Not applied -- diagnose-only mode.) Suggested fix direction:

  Option A (minimal, preferred): Replace manifest.yml's two-hop chain with a one-hop chain that mirrors identity.yml's working pattern. Specifically, change line 53 from
        RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'
  to
        RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'
  This eliminates the broken intermediate substitution. `STATE_DIR` is still defined and used elsewhere in manifest.yml (e.g., `mkdir -p "{{.STATE_DIR}}"` in cmds: blocks, where it substitutes correctly because cmd substitution happens later in the lifecycle than vars-block sh: eval).

  Option B: Forward `STATE_DIR` AND `RESOLVED_JSON_PATH` (and `DOTFILES_MESSAGES`) explicitly in the root Taskfile.yml include's `vars:` block. This works around the bug but couples root to manifest.yml internals.

  Option C: Set `RESOLVED_JSON_PATH` as an `sh:` var (`sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/resolved.json"`). Avoids the template-chain interaction entirely, at the cost of replacing a static template substitution with a shell sub-process.

  Option A is the cleanest and aligns manifest.yml with identity.yml's working pattern.
verification: (n/a -- diagnose-only)
files_changed: []
