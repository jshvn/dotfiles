---
phase: 10-v1-drop-remediation
reviewed: 2026-05-18T03:27:01Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - taskfiles/links.yml
  - taskfiles/shell.yml
  - Taskfile.yml
  - shell/.zshrc
  - shell/functions/motd.zsh
  - packages/core.rb
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-18T03:27:01Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Six source files were reviewed against the project conventions in `./CLAUDE.md`
and `./.claude/CLAUDE.md`. The Phase 10 keystone work (PORT-01 sudo write,
PORT-02 shell:validate, dual-include alias, source-order reorder in `.zshrc`)
is structurally sound and passes the LINT-02 / LINT-03b / `index`-access /
no-hardcoded-homebrew-path checks. Cross-file dangling references to the
deleted `configs/antidote/zsh_plugins.txt` are clean in code (taskfile +
manifest layer); only stale prose remains in three `README.md` files (out of
scope for this review).

Two non-trivial defects were found:

1. The reverted v1 `motd.zsh` still contains three project-rule violations
   (emojis in source) that were present in v1 but conflict with the v2
   stricter convention. The "byte-identical port" rationale does not exempt
   v2 source files from project rules.
2. The same `motd.zsh` hard-codes v1 paths (`${DOTFILEDIR}/zsh/configs/...`)
   for two asset files (`motd_sysinfo.jsonc`, `motd_tron.txt`) even though
   the v2 authoritative copies already live at `configs/motd/`. The runtime
   gate (`[[ -f "$ff_config" ]]`) currently masks this because v1's
   `zsh/configs/` is still on disk pending Phase 11 deletion -- once Phase 11
   removes `zsh/`, `motd` silently degrades to the bare-fastfetch fallback
   and the Tron quotes disappear without an error message.

Additional warnings: a small information-leak risk in the `zdotdir:` sudo
write if `$HOME` ever contains a single-quote (extremely low probability but
mechanically possible); namespace pollution from the dual-include alias
(`perf:validate` exists as a side effect of `shell:validate`).

Note on `task lint:taskfile` baseline: 24 pre-existing failures live in
v1-leftover taskfiles (slated for Phase 11 deletion) and are explicitly
out-of-scope for this review per the reviewer prompt.

## Warnings

### WR-01: motd.zsh contains emojis (violates project no-emojis rule)

**File:** `/Users/josh/Git/personal/dotfiles/shell/functions/motd.zsh:52,64,80`
**Issue:** Three emoji glyphs are present in source code:

- Line 52: `echo "${cyan}${bold}⚡ SYSTEM INFORMATION${reset}"` (`⚡` U+26A1)
- Line 64: `echo "${cyan}${bold}📦 DOTFILES${reset}"` (`📦` U+1F4E6)
- Line 80: `echo "${cyan}${bold}💭 TRANSMISSION${reset}"` (`💭` U+1F4AD)

Both `/Users/josh/Git/personal/dotfiles/CLAUDE.md` and
`/Users/josh/Git/personal/dotfiles/.claude/CLAUDE.md` state explicitly: "No
emojis in any file -- markdown included. Project convention is stricter than
the global rule." The phase rationale in `10-01-SUMMARY.md` calls this a
"byte-identical port from v1" but a byte-identical port does not exempt v2
source from v2 conventions. v1's `zsh/functions/motd.zsh` predates the v2
no-emoji rule; the port should have stripped them. (The other Unicode glyphs
in the file -- box-drawing/block characters at lines 32-48,86-87 -- are
typographic art, not emojis, and are within the project's typical
acceptance.)
**Fix:** Replace the three emoji glyphs with ASCII or typographic
equivalents that match the file's existing box-drawing aesthetic:

```zsh
# Line 52
echo "${cyan}${bold}[*] SYSTEM INFORMATION${reset}"
# Line 64
echo "${cyan}${bold}[#] DOTFILES${reset}"
# Line 80
echo "${cyan}${bold}[~] TRANSMISSION${reset}"
```

Alternatively, if the no-emojis rule has an explicit "byte-identical v1
revert" exemption (none is documented), record the carve-out in
`./.claude/CLAUDE.md` so future reviewers do not re-flag it.

### WR-02: motd.zsh hard-codes v1 asset paths -- will silently degrade after Phase 11 deletes zsh/

**File:** `/Users/josh/Git/personal/dotfiles/shell/functions/motd.zsh:53,77`
**Issue:** The reverted v1 `motd.zsh` references two asset files via v1's
`zsh/configs/` prefix:

- Line 53: `local ff_config="${DOTFILEDIR}/zsh/configs/motd_sysinfo.jsonc"`
- Line 77: `local quotes_file="${DOTFILEDIR}/zsh/configs/motd_tron.txt"`

The v2 authoritative copies live at `configs/motd/motd_sysinfo.jsonc` and
`configs/motd/motd_tron.txt` (verified via `ls configs/motd/`). Currently
both v1 and v2 copies exist on disk, so the runtime gates
(`[[ -f "$ff_config" ]]` and `[[ -f "$quotes_file" ]]`) hit the v1 copies
and `motd` renders correctly. After Phase 11 deletes `zsh/`, both gates
flip to false and:

- `fastfetch` is called with no config (still works, but the curated
  motd_sysinfo layout is lost)
- The Tron quote block is silently elided (`[[ -f ... ]]` simply skips)

There is no error message; the operator only notices that the motd looks
"different" or "smaller" after a future install. The smoke procedure in
`10-SMOKE.md` line 37 (`motd output appears`) would still pass post-Phase-11
because partial degradation is still output. This is exactly the kind of
silent regression that landed v2 in the Phase-9 audit cycle.
**Fix:** Update the two paths to point at v2's authoritative location:

```zsh
# Line 53
local ff_config="${DOTFILEDIR}/configs/motd/motd_sysinfo.jsonc"
# Line 77
local quotes_file="${DOTFILEDIR}/configs/motd/motd_tron.txt"
```

This is a one-line surgery per reference; the "byte-identical" port
rationale does not extend to embedded paths that point at directories the
v2 layout deliberately moved. The byte-identical concern (cache
width-sensitivity) is in the `tput cols` render path, not in the asset path
strings.

### WR-03: zdotdir sudo write is theoretically vulnerable to single-quote injection via $HOME

**File:** `/Users/josh/Git/personal/dotfiles/taskfiles/links.yml:183`
**Issue:** The sudo write builds its payload via template-var expansion:

```yaml
ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
```

`{{.ZDOTDIR}}` is `{{.XDG_CONFIG_HOME}}/zsh` (root Taskfile.yml line 40),
which expands to `{{.HOME}}/.config/zsh`. `$HOME` comes from the user's
environment. The string is wrapped in single quotes, so shell parameter
expansion is suppressed at parse time -- BUT if `$HOME` ever contained a
literal single quote, that would terminate the single-quoted string and
let the remainder leak into the rendered shell. The resulting `sudo tee`
could then write arbitrary content to `/etc/zshenv`.

In practice this is exceedingly unlikely (most operating systems reject
`'` in usernames; even when allowed, this is a privilege-escalation vector
from one's own user account to root via `/etc/zshenv` -- already a
weakened threat model since the user can edit `/etc/zshenv` directly with
sudo anyway). However, the same single-quote pattern is the documented
injection vector in `manifest.yml setup:` (lines 118-119) which uses the
"pass via env (CLI_ARGS_ENV)" idiom for exactly this reason.
**Fix:** Two options, in increasing safety:

Option A (defense in depth, mirrors Pattern 6 from cutover:ack):

```yaml
zdotdir:
  desc: "Configure ZDOTDIR in /etc/zshenv (sudo write, idempotent)"
  internal: true
  env:
    ZDOTDIR_ENV: '{{.ZDOTDIR}}'
  cmds:
    - |
      {{.DOTFILES_MESSAGES}}
      ZDOTDIR_EXPORT="export ZDOTDIR=\"${ZDOTDIR_ENV}\""
      # ... rest unchanged
```

Option B (explicit assertion at line 182, simplest):

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  case "{{.ZDOTDIR}}" in
    *\'*) error "ZDOTDIR contains a single quote; refusing to write /etc/zshenv"; exit 1 ;;
  esac
  ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
  # ... rest unchanged
```

If the project's threat model explicitly excludes user-controlled `$HOME`
(reasonable for personal-machine dotfiles), record the carve-out in a code
comment so future reviewers do not re-flag.

### WR-04: shell.yml's vars: block does not declare XDG_* template vars it references

**File:** `/Users/josh/Git/personal/dotfiles/taskfiles/shell.yml:39-48,106,113,120,127,135,146,157`
**Issue:** The new `validate:` task references five template vars
(`{{.XDG_CONFIG_HOME}}`, `{{.XDG_DATA_HOME}}`, `{{.XDG_STATE_HOME}}`,
`{{.XDG_CACHE_HOME}}`, `{{.ZDOTDIR}}`) that are NOT declared in the local
`vars:` block (lines 39-48). When the file is included by the root
`Taskfile.yml` these vars merge in from root (vars: block lines 36-40),
but the file header (lines 33-36) advertises that direct invocation works:

```yaml
# Vars block -- self-contained so direct invocation
#   task -t taskfiles/shell.yml shell
# works without the root Taskfile.yml being loaded.
```

I verified empirically that with `XDG_*` env vars unset, the template vars
render as empty strings:

```
$ unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME ZDOTDIR
$ task -t taskfiles/shell.yml validate
...
if [[ -d "" ]]; then  # <-- five empty checks
```

Behavior in the unset case: every check fails, `failures=7`, task exits 7.
That is technically "fail loud" but the failure message ("XDG config home
missing") is misleading -- the actual cause is "validate task missing its
own vars declaration". The links.yml parallel doesn't have this issue
because `links:validate` works through `EXPECTED_TARGETS` which derives
from `{{.ZDOTDIR}}` that IS declared in links.yml's local vars (line 56).
**Fix:** Add the five XDG/ZDOTDIR vars to shell.yml's local vars block to
match links.yml's self-containment contract:

```yaml
vars:
  HOME: '{{.HOME}}'

  XDG_CONFIG_HOME:
    sh: echo "${XDG_CONFIG_HOME:-$HOME/.config}"
  XDG_DATA_HOME:
    sh: echo "${XDG_DATA_HOME:-$HOME/.local/share}"
  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"
  XDG_CACHE_HOME:
    sh: echo "${XDG_CACHE_HOME:-$HOME/.cache}"

  ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'

  DOTFILEDIR:
    sh: dirname "{{.TASKFILE_DIR}}"

  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'
```

Or alternatively, amend the file-header comment to say "direct invocation
is supported only for the `shell` perf task; `validate` requires invocation
via the root taskfile" so the contract matches the implementation.

## Info

### IN-01: Dual-include alias creates namespace-pollution side effect (perf:validate)

**File:** `/Users/josh/Git/personal/dotfiles/Taskfile.yml:92-93`
**Issue:** The dual-include pattern works but creates four task entries
where only two are intended:

```
$ task --list | grep -E '^\* (shell|perf):'
* perf:shell:      Measure cold interactive zsh startup time ...
* perf:validate:   Validate shell layer (XDG dirs, ZDOTDIR dir, ...
* shell:shell:     Measure cold interactive zsh startup time ...
* shell:validate:  Validate shell layer (XDG dirs, ZDOTDIR dir, ...
```

Intended surface area:

- `task perf:shell` (legacy alias, called by CI / runbooks)
- `task shell:validate` (new PORT-02)

Side-effect surface area:

- `task perf:validate` (unused; confusing alias)
- `task shell:shell` (awkward; would be invoked by no one)

This is acceptable transitional shape (the file header comment in
shell.yml already calls out the legacy `perf:` alias) and `task validate`
correctly delegates to `shell:validate`, not `perf:validate`. Long-term
the dual-include should collapse to a single namespace once the cold-start
gate caller(s) update to `task shell:shell` or once shell.yml is split
into `perf.yml` + `shell.yml` per Plan D-06 option (c).
**Fix:** Document the transitional state explicitly in the file header
of `taskfiles/shell.yml`:

```yaml
# Naming:
#   Included twice by root Taskfile.yml (lines 92-93) under both `perf:`
#   (legacy, for SHEL-12 cold-start gate callers) and `shell:` (new, for
#   PORT-02 shell:validate). Side effect: `task perf:validate` and
#   `task shell:shell` also resolve; ignore both. Slated for collapse to
#   a single namespace when this file is split into perf.yml + shell.yml.
```

No code change needed in this phase; just record the intent.

### IN-02: shell:validate has both `status: [false]` and the `lint-allow: cmds-without-status` marker

**File:** `/Users/josh/Git/personal/dotfiles/taskfiles/shell.yml:96-99`
**Issue:** The new task carries two redundant-and-slightly-contradictory
signals:

```yaml
# lint-allow: cmds-without-status     # <-- claims "no status block"
validate:
  desc: ...
  status: [false]                     # <-- has a status block (always-run sentinel)
```

`status: [false]` IS a status block (the literal-false sentinel meaning
"always run") so the `lint-allow: cmds-without-status` marker is
inaccurate. Other tasks in the same file (`shell:` at line 60) use the
marker without a `status:` block, which is the documented LINT-03a
pattern. This is purely a hygiene concern -- the task runs correctly --
but the lint marker should match reality.
**Fix:** Choose one:

Option A (drop the marker, keep status: [false]):

```yaml
validate:
  desc: ...
  status: [false]
  cmds: ...
```

Option B (drop status: [false], add marker; matches `shell:` task above):

```yaml
# lint-allow: cmds-without-status
validate:
  desc: ...
  cmds: ...
```

Both behave identically (always-run). Option A is more explicit; option B
matches the existing `shell:` task pattern in the same file.

### IN-03: Stale documentation references to antidote in three README files

**File:** Out-of-scope for this review (none of these are in the edited
file list); recording for awareness.

- `/Users/josh/Git/personal/dotfiles/taskfiles/README.md:26`:
  "`links.yml` -- shell + antidote symlinks via `_:safe-link`."
- `/Users/josh/Git/personal/dotfiles/shell/README.md:16`:
  "antidote loads `omz-git` (the v1 prompt is small, fast, ..."
- `/Users/josh/Git/personal/dotfiles/packages/README.md:17`:
  "Roughly 30 formulas: shell tooling (zsh, antidote, go-task), ..."

The antidote → antigen revert (prerequisite fix `ef3d236`) flipped the
implementation but did not propagate to docs. Not a defect in the
phase-10 edited files; flagging so it doesn't get lost during Phase 11
cleanup.
**Fix:** Update the three README files in a docs-only follow-up commit
to reflect the antigen reality. Same wording-level surgery as the
comment edit in `packages/core.rb:24-26`.

### IN-04: .zshrc retains stale antidote example in header comment

**File:** `/Users/josh/Git/personal/dotfiles/shell/.zshrc:26-28`
**Issue:** The .zshrc file header still contains v1-era antidote example
code:

```zsh
#   - Plugin managers and interactive hooks (antidote, zinit, oh-my-zsh):
#       source $HOMEBREW_PREFIX/share/antidote/antidote.zsh
#       antidote bundle < $ZDOTDIR/.zsh_plugins.txt > $cache
```

The file's actual body (lines 73-97) uses antigen, not antidote. The
explanatory comment at line 73 ("antigen plugin manager (reverted from
antidote...)") makes the revert clear, but the header example block was
not updated to match. This is documentation-only -- the file runs
correctly -- but the example block now contradicts the implementation
two screenfuls below it.
**Fix:** Update the header example block (lines 26-28) to mention antigen
instead of antidote, or remove the example block entirely (it's
explanatory boilerplate that the active body already supersedes):

```zsh
#   - Plugin managers and interactive hooks (antigen, zinit, oh-my-zsh):
#       source $HOMEBREW_PREFIX/share/antigen/antigen.zsh
#       antigen use ohmyzsh/ohmyzsh
#       antigen bundle <plugin>
#       antigen apply
```

---

## Items Verified (no findings)

The following project rules were checked and PASS:

- **LINT-02 (status blocks use `{{.X}}` template vars, never `$X`):**
  `zdotdir:` status block (links.yml:195-196) uses `{{.ZDOTDIR}}`.
  `shell:validate` status (`[false]`) is a literal sentinel with no
  variable reference. Outer `zsh:` task status (links.yml:151-157) extends
  the v1 pattern with `{{.ZDOTDIR}}` template var. The grep pattern at
  shell.yml:147 lives inside `cmds:` (legal shell context), not `status:`.
- **LINT-03b (no bare `ln -s` outside helpers.yml):** new `zdotdir:` task
  does not create symlinks. Outer `zsh:` task delegates every symlink
  through `_:safe-link`. Confirmed via `grep -n 'ln -s' taskfiles/`.
- **No hardcoded `/opt/homebrew` or `/usr/local`:** `shell/.zshrc:78`
  guards on `$HOMEBREW_PREFIX` and sources
  `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`. No literal paths in any
  edited file.
- **No AI attribution in source/commits:** none found across the six
  edited files.
- **`set -euo pipefail` on executable .zsh:** the edited `.zsh` files
  (`shell/.zshrc`, `shell/functions/motd.zsh`) are sourced-only (zsh
  startup file + function-loop file). Sourced files are exempt per
  project rules. Their executable bit is incidental (the original v1
  files had it too).
- **kebab-case feature keys use `index .MANIFEST.features "key"`:** the
  two new tasks (`zdotdir:` and `shell:validate`) do not read any feature
  flag, so the rule is vacuously satisfied. The surrounding unchanged
  blocks already use the `index` form correctly.
- **Idempotency of `zdotdir:`:**
  - First run (no `/etc/zshenv`): hits the `[[ ! -f ]]` branch, creates
    the file via `sudo tee`, sudo prompts once.
  - Second run (file exists with ZDOTDIR export): `grep -qF` in status
    block returns 0; entire task is skipped; no sudo prompt.
  - Modified-file run (file exists but ZDOTDIR line removed): status block
    returns non-zero (re-run), cmds: hits the `elif ! grep -qF ...` branch,
    appends via `sudo tee -a`. Sudo prompts.
  - All three transitions behave correctly. Per the SMOKE.md run log
    (line 51) this was verified empirically.
- **Cross-file consistency (no dangling antidote refs in code):** verified
  via `grep -rn antidote taskfiles/ Taskfile.yml shell/ packages/`. The
  only matches are: (a) packages/core.rb's revert rationale comment, (b)
  shell/.zshrc's stale header example (IN-04), (c) three README files
  (IN-03). No taskfile cmds: bodies, status: blocks, vars: blocks, or
  cmds: chains reference antidote.
- **Source order in `.zshrc`:** new order `theme.zsh → functions →
  aliases` correctly places `alias highlight=...` (theme.zsh:49) in
  scope before `aliaslist.zsh` and `functionlist.zsh` are parsed (both
  use `highlight` in pipe form in their function bodies). The D-08
  source-time gate in `jgrid.zsh:17` still works because
  `_dotfiles_feature.zsh` is loaded in the functions glob (step 2) before
  the aliases glob (step 3).
- **`configs/antidote/zsh_plugins.txt` deletion is clean:** the directory
  no longer exists (`ls configs/antidote/` -> "No such file or
  directory") and no code references the path (`grep -rn 'configs/antidote\|zsh_plugins'`
  matches only the .zshrc header example comment from IN-04).
- **Both validate-aggregator for-loops include `shell`:** Taskfile.yml
  line 216 and line 223 both contain `manifest identity links macos
  packages claude shell`.
- **Pre-existing lint baseline:** `task lint:taskfile` has 24 pre-existing
  failures in v1-leftover taskfiles slated for Phase 11 deletion;
  out-of-scope for this review per the prompt.

---

_Reviewed: 2026-05-18T03:27:01Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
