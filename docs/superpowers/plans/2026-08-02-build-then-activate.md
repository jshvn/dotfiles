# Build-Then-Activate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Design:** `docs/superpowers/specs/2026-08-02-build-then-activate-design.md`
**Baseline:** v2.5.0 (`f7bdee5`)
**Goal:** Separate computing the desired state from applying it. One test
convention, a repo tree that holds source only, a materialized build
directory, and `task diff` as a corollary of the last.

**Architecture:** Three phases, each independently shippable.
Phase 1 unifies three test conventions into `<domain>/tests/`.
Phase 2 evicts both generated files from the repo tree: addon fragments to
`$XDG_STATE_HOME/dotfiles/settings.d/`, `settings.json` to
`$XDG_STATE_HOME/dotfiles/build/` with a real (non-symlink) live file.
Phase 3 materializes `build/{Brewfile,settings.json,links.map}` and adds
per-domain `diff` plus public `task diff`.

**Tech Stack:** zsh, go-task >= 3.37, jq >= 1.7, yq (mikefarah) >= 4.52.1,
Homebrew. No new dependencies.

## Global Constraints

- Commit format: `<type>(<scope>): <summary>` (<75 chars, imperative mood).
  No AI attribution anywhere (hooks block it).
- No emojis in any file, including markdown.
- Every executable `.zsh` starts with `set -euo pipefail` (LINT-04) and the
  Purpose / Depends on / Side effects banner between two `# ===` 77-char
  rules (LINT-12).
- `status:` blocks use `{{.X}}` template vars, never `$X` shell vars
  (LINT-02). Tasks with `cmds:` carry `status:` or a
  `# lint-allow: cmds-without-status` annotation (LINT-03a; tasks whose cmds
  are all `task:` delegations are exempt).
- Symlinks only via `_:safe-link` (LINT-03b). No hardcoded `/opt/homebrew` /
  `/usr/local` (LINT-10). Kebab-case feature keys use the `index` template
  form (LINT-11). Multi-element TOML arrays span one element per line
  (LINT-13).
- Taskfile shell blocks run under go-task's embedded interpreter (mvdan/sh),
  NOT zsh -- no zsh glob qualifiers or zsh-only idioms in `cmds:` blocks or
  in libraries sourced by them (`install/compose-settings.zsh`,
  `install/messages.zsh`).
- Branch per phase: `josh/bta-phase-<n>-<slug>`; PR to master; squash merge.
- After every task: `task lint` and `task test` both pass before commit.
- Any new public top-level task must be added to the `default:` banner in
  `Taskfile.yml` (LINT-08) and to the CLAUDE.md operator table.

---

## Phase 1 -- Test layout unification (branch `josh/bta-phase-1-test-layout`)

### Task 1: Move install test scripts to install/tests/

**Files:**
- Move: `install/test-hooks.zsh` -> `install/tests/hooks.zsh`
- Move: `install/test-links-audit.zsh` -> `install/tests/links-audit.zsh`
- Move: `install/test-repo-sync.zsh` -> `install/tests/repo-sync.zsh`
- Move: `install/test-shell-startup.zsh` -> `install/tests/shell-startup.zsh`
- Modify: `taskfiles/test.yml` (4 invocation paths, 4 `desc:` strings, header)

**Interfaces:**
- Consumes: nothing.
- Produces: the `install/tests/<name>.zsh` path convention that Task 5's new
  test follows. Task names (`test:hooks` etc.) are unchanged.

- [ ] **Step 1: git mv the four scripts (preserves execute bits)**

`test-hooks.zsh` and `test-repo-sync.zsh` are executable; the other two are
not. `git mv` preserves both modes -- do not chmod.

```bash
cd /Users/josh/Git/personal/dotfiles
mkdir -p install/tests
git mv install/test-hooks.zsh          install/tests/hooks.zsh
git mv install/test-links-audit.zsh    install/tests/links-audit.zsh
git mv install/test-repo-sync.zsh      install/tests/repo-sync.zsh
git mv install/test-shell-startup.zsh  install/tests/shell-startup.zsh
```

- [ ] **Step 2: Update each moved script's banner title line**

Each banner's first content line names the old path. Edit exactly those four
lines (`install/test-<x>.zsh` -> `install/tests/<x>.zsh`); nothing else in
the banners changes.

- [ ] **Step 3: Update taskfiles/test.yml paths and descs**

Four invocation lines (`zsh "${DOTFILEDIR}/install/test-<x>.zsh"` ->
`zsh "${DOTFILEDIR}/install/tests/<x>.zsh"`), the four matching `desc:`
strings, and the file-header `Purpose:` / `Depends on:` lines that name
`install/test-hooks.zsh` and `install/test-shell-startup.zsh`.

- [ ] **Step 4: Verify**

```bash
task test && task lint
```

Expected: every suite passes (hooks, repo-sync, links-audit, shell-startup,
manifest fixtures, lint fixtures); LINT-04/LINT-12 pick up the moved files at
their new paths.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(tests): move install test scripts to install/tests/"
```

### Task 2: Rename manifests/test/ to manifests/tests/

**Files:**
- Move: `manifests/test/` -> `manifests/tests/` (fixtures/, shared/, README.md)
- Modify: `Taskfile.yml:47` (`FIXTURES_DIR`)
- Modify: `taskfiles/test.yml` (`test_base` path, header `Depends on:`)
- Modify: `manifests/tests/README.md` (internal path references)

**Interfaces:**
- Consumes: nothing.
- Produces: `{{.FIXTURES_DIR}}` resolving to `manifests/tests/fixtures`.

- [ ] **Step 1: git mv the directory**

```bash
git mv manifests/test manifests/tests
```

- [ ] **Step 2: Update Taskfile.yml**

```yaml
  FIXTURES_DIR: '{{.ROOT_DIR}}/manifests/tests/fixtures'
```

- [ ] **Step 3: Update taskfiles/test.yml**

`test_base="{{.ROOT_DIR}}/manifests/test/shared/base.toml"` ->
`.../manifests/tests/shared/base.toml`. Header `Depends on:` line naming
`manifests/test/fixtures/` -> `manifests/tests/fixtures/`. Also the inline
comment naming `manifests/test/shared/base.toml` in the typed-fixture block.

- [ ] **Step 4: Fix internal references in manifests/tests/README.md**

```bash
grep -n 'manifests/test/' manifests/tests/README.md
```

Replace every hit.

- [ ] **Step 5: Verify**

```bash
task test
```

Expected: every `typed-*` and `_invalid-*` fixture runs at the new path and
passes. LINT-13 already scans all of `manifests/**/*.toml` including
fixtures -- no exclusion to update.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(tests): rename manifests/test to manifests/tests"
```

### Task 3: Rename taskfiles/test/ to taskfiles/tests/ and narrow lint scopes

**Files:**
- Move: `taskfiles/test/` -> `taskfiles/tests/`
- Modify: `taskfiles/lint.yml` (5 references; 2 of them change key, not value)

**Interfaces:**
- Consumes: nothing.
- Produces: `taskfiles/tests/lint-fixtures/` consumed by `lint:test-fixtures`;
  `install/tests/*.zsh` newly in scope for LINT-10.

- [ ] **Step 1: git mv the directory**

```bash
git mv taskfiles/test taskfiles/tests
```

- [ ] **Step 2: Update the two path-anchored find exclusions**

Both are literal path prefixes and just follow the rename:

1. `ZSH_FIND` var (line ~23):
   `-not -path '{{.ROOT_DIR}}/taskfiles/test/*'` ->
   `-not -path '{{.ROOT_DIR}}/taskfiles/tests/*'`
2. `shell-headers` find (line ~179): same substitution.

- [ ] **Step 3: Re-key the two grep exclusions onto lint-fixtures**

`--exclude-dir` matches by basename, so `--exclude-dir='tests'` would
silently exclude `install/tests/` and `manifests/tests/` too -- dropping our
own test scripts out of the LINT-10 scan. Key on the fixture directory
instead:

1. LINT-03b scan (line ~133): `--exclude-dir='test'` ->
   `--exclude-dir='lint-fixtures'`. Update the comment block above it: the
   exclusion exists because fixtures deliberately contain bare `ln -s`.
2. LINT-10 `brew-prefix` scan (line ~283): `--exclude-dir='test'` ->
   `--exclude-dir='lint-fixtures'`.

- [ ] **Step 4: Update the fixtures_dir path**

`lint:test-fixtures` (line ~394):
`fixtures_dir="{{.ROOT_DIR}}/taskfiles/test/lint-fixtures"` ->
`.../taskfiles/tests/lint-fixtures`. Also the comment near line ~419 that
cites `--include='*.yml' --exclude-dir='test'`.

- [ ] **Step 5: Verify**

```bash
task lint && task test
```

Expected: all pass. Specifically no LINT-03b/LINT-04/LINT-10 failures leaking
from fixture files into the production scan, and `lint:test-fixtures` reports
every fixture behaving as expected. `install/tests/*.zsh` are now scanned by
LINT-10 -- if any hit appears, fix the script (it is a real violation that
the old basename exclusion was hiding).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(tests): rename taskfiles/test to taskfiles/tests"
```

### Task 4: install/README stage taxonomy + stale-reference sweep

**Files:**
- Modify: `install/README.md` (rewrite `## Key files`)
- Modify: any remaining live doc naming the old test paths

**Interfaces:**
- Consumes: the Phase 1 renames.
- Produces: the documented stage taxonomy (lib / evaluate / realize /
  operate / tests) new `install/` scripts must slot into.

- [ ] **Step 1: Rewrite the Key files section**

Replace the flat list with a staged one. Keep the existing per-file prose;
regroup, retitle, and add `shell-startup.zsh` (missing from the current
list).

```markdown
## Key files, by pipeline stage

Every script here belongs to exactly one stage. A new script must name its
stage in this list.

### lib (sourced, never executed)

- `messages.zsh` -- colored-output library (`info`, `check`, `cross`, ...)
  sourced by task `cmds:` blocks via `{{.DOTFILES_MESSAGES}}`.
- `compose-settings.zsh` -- settings-compose algorithm shared by
  `claude:settings-compose` and `claude:audit`.

### evaluate (manifests -> resolved.json)

- `resolver.zsh` -- validates a machine manifest against the feature registry
  and base tier, then compiles it to
  `$XDG_STATE_HOME/dotfiles/resolved.json`.

### realize (resolved.json + repo source -> build artifacts)

- `compose-brewfile.zsh` -- emits the per-machine Brewfile from
  resolved.json's typed buckets.

### operate (drift detection, addon lifecycle, repo hygiene)

- `claude-addons.zsh` -- install / upgrade / remove / list / validate the
  third-party Claude addons.
- `links-audit-scan.zsh` -- orphan-symlink detection for `task links:audit`.
- `lint-rules.zsh` -- shared lint detectors backing both the production scan
  and the fixture self-test.
- `repo-sync.zsh` -- fast-forward pull run before install.

### tests (`install/tests/`)

- `hooks.zsh` -- smoke tests for the named Claude hooks (`test:hooks`).
- `links-audit.zsh` -- smoke tests for `links-audit-scan.zsh`
  (`test:links-audit`).
- `repo-sync.zsh` -- smoke tests for `repo-sync.zsh` (`test:repo-sync`).
- `shell-startup.zsh` -- zsh startup smoke tests (`test:shell-startup`).
```

Also fix the intro paragraph's "Tier-3 hook smoke-test runner" reference and
any `test-hooks.zsh` mention further down.

- [ ] **Step 2: Sweep for stale path references**

```bash
grep -rn 'install/test-\|manifests/test/\|taskfiles/test/' \
  --include='*.md' --include='*.yml' --include='*.zsh' --include='*.toml' . \
  | grep -v '\.git/' | grep -v 'docs/superpowers/'
```

Fix every hit in live docs. Leave `docs/superpowers/**` untouched -- dated
design documents are historical records.

- [ ] **Step 3: Verify**

Re-run the Step 2 grep: zero hits outside `docs/superpowers/`.

```bash
task lint && task test
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs(install): stage taxonomy in README; fix stale test paths"
```

---

## Phase 2 -- Repo tree becomes source only (branch `josh/bta-phase-2-purity`)

### Task 5: Two-directory settings compose (test-first)

**Files:**
- Create: `install/tests/settings-compose.zsh`
- Modify: `install/compose-settings.zsh` (`settings_compose_fragments`)
- Modify: `taskfiles/test.yml` + root `Taskfile.yml` (wire the new test)

**Interfaces:**
- Consumes: the `install/tests/` convention from Task 1.
- Produces:
  `settings_compose_fragments <repo_d> <state_d> <preserved_json> [jq_flag]`
  -- state dir may be missing or empty. Consumed by Tasks 6 and 7.

- [ ] **Step 1: Write the failing test**

Create `install/tests/settings-compose.zsh`, `chmod +x`:

```zsh
#!/usr/bin/env zsh

# =============================================================================
# install/tests/settings-compose.zsh -- smoke tests for compose-settings.zsh
#
# Purpose:      Exercise settings_compose_fragments + settings_preserved_keys
#               against throwaway fragment dirs: repo-fragment merge order,
#               state-dir fragments layering over repo fragments, missing and
#               empty state dirs, and preserved CLI-managed keys winning over
#               fragment values.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/compose-settings.zsh; install/messages.zsh; jq.
# Side effects: creates throwaway dirs under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:settings-compose)}"

source "${DOTFILEDIR}/install/messages.zsh"
source "${DOTFILEDIR}/install/compose-settings.zsh"

typeset -i failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

repo_d="${work}/settings.d"
state_d="${work}/state-settings.d"
mkdir -p "$repo_d" "$state_d"

echo '{"a": 1, "nested": {"x": 1}}' > "${repo_d}/00-base.json"
echo '{"b": 2, "nested": {"y": 2}}' > "${repo_d}/10-hooks.json"
echo '{"a": 9, "addon": true}'      > "${state_d}/99-addon-test.json"

# Scenario 1: repo fragments deep-merge in filename order; a missing state
# dir is tolerated.
out=$(settings_compose_fragments "$repo_d" "${work}/no-such-dir" '{}')
if [[ "$(echo "$out" | jq -c '{a, b, nested}')" == '{"a":1,"b":2,"nested":{"x":1,"y":2}}' ]]; then
  check "repo fragments deep-merge in filename order"
else
  cross "repo fragment merge wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 2: state-dir fragments layer after (over) repo fragments.
out=$(settings_compose_fragments "$repo_d" "$state_d" '{}')
if [[ "$(echo "$out" | jq -c '{a, addon}')" == '{"a":9,"addon":true}' ]]; then
  check "state-dir addon fragment overrides repo fragment"
else
  cross "state-dir layering wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 3: an existing-but-empty state dir composes like repo-only.
rm -f "${state_d}"/*.json
out=$(settings_compose_fragments "$repo_d" "$state_d" '{}')
if [[ "$(echo "$out" | jq -r '.a')" == "1" ]]; then
  check "empty state dir composes repo fragments only"
else
  cross "empty state dir handling wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 4: preserved keys layer over every fragment.
preserved='{"enabledPlugins": {"p": true}, "a": 42}'
out=$(settings_compose_fragments "$repo_d" "$state_d" "$preserved")
if [[ "$(echo "$out" | jq -c '{a, enabledPlugins}')" == '{"a":42,"enabledPlugins":{"p":true}}' ]]; then
  check "preserved keys layer over fragments"
else
  cross "preserved-key layering wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 5: settings_preserved_keys extracts only CLI-managed keys, and
# carries tui only when the live file has it.
live="${work}/settings.json"
echo '{"enabledPlugins": {"q": true}, "permissions": {}, "model": "opus", "tui": "fullscreen"}' > "$live"
out=$(settings_preserved_keys "$live")
if [[ "$(echo "$out" | jq -c 'keys | sort')" == '["enabledPlugins","extraKnownMarketplaces","model","tui"]' ]]; then
  check "settings_preserved_keys extracts CLI-managed keys only"
else
  cross "settings_preserved_keys wrong: $out"
  failures=$(( failures + 1 ))
fi

if (( failures == 0 )); then
  success "settings-compose: all scenarios passed"
else
  error "settings-compose: ${failures} scenario(s) failed"
fi
exit "$failures"
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
DOTFILEDIR="$PWD" zsh install/tests/settings-compose.zsh
```

Expected: FAIL -- `settings_compose_fragments` still takes
`<settings_d> <preserved> [flag]`, so scenarios 1-4 misparse their arguments.
Scenario 5 should already pass.

- [ ] **Step 3: Implement the two-dir compose**

In `install/compose-settings.zsh`, replace `settings_compose_fragments`
(leave `settings_preserved_keys` untouched):

```zsh
# settings_compose_fragments <repo_settings_d> <state_settings_d> <preserved_json> [jq_flag]
# Deep-merge every *.json fragment: repo dir first (numeric filename prefix
# = merge priority), then the state dir (machine-generated addon fragments,
# 99-addon-* by convention), then layer the preserved keys on top. The state
# dir may be missing or empty. Pass `-S` as the optional 4th arg to sort keys
# (drift comparisons use this to normalize key order). Output to stdout.
# find (not a glob) enumerates fragments: portable across zsh and go-task's
# embedded shell, and immune to zsh's nomatch abort on an empty dir.
settings_compose_fragments() {
  local repo_d="$1" state_d="$2" preserved="$3" flag="${4:-}"
  {
    find "$repo_d" -maxdepth 1 -name '*.json' 2>/dev/null | sort
    if [ -d "$state_d" ]; then
      find "$state_d" -maxdepth 1 -name '*.json' 2>/dev/null | sort
    fi
  } | while IFS= read -r f; do
    cat "$f"
  done | jq -s $flag --argjson preserved "$preserved" \
    'reduce .[] as $f ({}; . * $f) | . * $preserved'
}
```

Update the file-header `Purpose:` line to name both fragment sources.

- [ ] **Step 4: Confirm the test passes**

```bash
DOTFILEDIR="$PWD" zsh install/tests/settings-compose.zsh
```

Expected: `settings-compose: all scenarios passed`, exit 0.

- [ ] **Step 5: Update the two existing call sites to the new arity**

`taskfiles/claude.yml` `settings-compose` and `audit` both call
`settings_compose_fragments "$settings_d" "$preserved" [-S]`. Add a
`state_d` argument in position 2. Until Task 6 lands, pass the state path
that Task 6 will create -- it simply will not exist yet, which the function
tolerates:

```yaml
  SETTINGS_STATE_D: '{{.STATE_DIR}}/settings.d'
```

```
        settings_compose_fragments "$settings_d" "$state_d" "$preserved" > "$tmp"
        settings_compose_fragments "$settings_d" "$state_d" "$preserved" -S > "$expected"
```

- [ ] **Step 6: Wire the new test into the suite**

`taskfiles/test.yml`:

```yaml
  # lint-allow: cmds-without-status
  settings-compose:
    desc: "Run settings-compose smoke tests via install/tests/settings-compose.zsh"
    internal: true
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        info "running settings-compose smoke tests"
        export DOTFILEDIR="{{.ROOT_DIR}}"
        zsh "${DOTFILEDIR}/install/tests/settings-compose.zsh"
    status:
      - false
```

Root `Taskfile.yml`: add `- task: test:settings-compose` to the `test:`
aggregator and widen its `desc:` string.

- [ ] **Step 7: Verify**

```bash
task test && task lint
```

Expected: all pass. LINT-09 still passes -- composed output is unchanged
because the state dir does not exist yet.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(claude): settings compose merges repo and state fragments"
```

### Task 6: Addon fragments live in machine state

**Files:**
- Modify: `install/claude-addons.zsh` (`SETTINGS_D` -> state dir; banner)
- Modify: `taskfiles/claude-addons.yml` (header + `remove` summary)
- Modify: `taskfiles/claude.yml` (`fragment_count` counts both dirs)
- Delete: `claude/settings.d/99-addon-ecc.json`
- Modify: `CLAUDE.md`, `docs/CLAUDE-ADDONS.md`, `claude/README.md`

**Interfaces:**
- Consumes: two-dir compose (Task 5).
- Produces: `$XDG_STATE_HOME/dotfiles/settings.d/99-addon-<name>.json` as the
  addon fragment location.

- [ ] **Step 1: Point the addon lifecycle at the state dir**

`install/claude-addons.zsh:22`:

```zsh
typeset -r SETTINGS_D="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/settings.d"
```

Update the banner `Side effects:` line (line ~12) and the `cmd_remove`
Phase-4 comment (line ~207) to name the new location. `cmd_install` already
does `mkdir -p "$SETTINGS_D"` before the `cp` -- no other change.

- [ ] **Step 2: Update the fragment count**

`taskfiles/claude.yml` `settings-compose`, the `fragment_count` line:

```
        fragment_count=$( { ls "$settings_d"/*.json 2>/dev/null; ls "$state_d"/*.json 2>/dev/null; } | wc -l | tr -d ' ')
```

Also update `taskfiles/claude-addons.yml`'s header `Side effects:` comment
and the `remove` task `summary:` (both name `claude/settings.d/99-addon-*`).

- [ ] **Step 3: Remove the tracked build artifact and regenerate**

```bash
git rm claude/settings.d/99-addon-ecc.json
DOTFILEDIR="$PWD" zsh install/claude-addons.zsh install
ls ~/.local/state/dotfiles/settings.d/
```

Expected: the ecc addon reports installed/upgraded and
`99-addon-ecc.json` exists in the state dir.

- [ ] **Step 4: Confirm the composed output is unchanged**

```bash
task claude:audit
```

Expected: no drift. The fragment moved directories but its content and merge
position (`99-` sorts last in both the old single-dir order and the new
repo-then-state order) are identical.

- [ ] **Step 5: Update docs**

```bash
grep -rn 'settings\.d' CLAUDE.md docs/CLAUDE-ADDONS.md claude/README.md
```

Every hit describing addon fragments (`99-addon-<name>.json`) now names
`$XDG_STATE_HOME/dotfiles/settings.d/`. Repo-owned fragments (`00-base`,
`10-hooks`) stay in `claude/settings.d/` and keep their wording. In CLAUDE.md
this touches the generated-artifact section, the addons section, the "Where
to Add Things" hook row, and the "Don't Do" bullets.

- [ ] **Step 6: Verify**

```bash
task test && task lint && git status --short
```

Expected: all pass; `git status` shows only the intended deletions and doc
edits -- no reappearing `99-addon-ecc.json`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(claude): addon fragments live in machine state, not the repo"
```

### Task 7: settings.json moves to the build dir

**Files:**
- Modify: `taskfiles/claude.yml` (vars, `settings-compose`, new `activate`,
  `install`, `audit`, header)
- Modify: `taskfiles/links.yml` (`CLAUDE_LINKS`: drop `settings.json`)
- Modify: `taskfiles/lint.yml` (delete `settings-drift`; drop from aggregator)
- Delete: `claude/settings.json`
- Modify: `CLAUDE.md` (LINT table, generated-artifact section, Don't Do),
  `claude/README.md`, `install/README.md`

**Interfaces:**
- Consumes: two-dir compose (Task 5), state fragments (Task 6).
- Produces: `{{.SETTINGS_BUILD}}` (`$XDG_STATE_HOME/dotfiles/build/settings.json`)
  as the composed artifact and `{{.SETTINGS_PATH}}`
  (`~/.config/claude/settings.json`) as the live real file. Task 9's
  `claude:diff` consumes both.

- [ ] **Step 1: Capture the pre-migration baseline**

```bash
jq -S . claude/settings.json > /tmp/settings-baseline.json
wc -c /tmp/settings-baseline.json
```

This is the correctness gate for Step 6.

- [ ] **Step 2: Repoint the vars**

`taskfiles/claude.yml`:

```yaml
vars:
  # Live file the Claude CLI reads and writes. A real file, not a symlink --
  # activation mv's the built artifact over it. Compose reads the CLI-managed
  # keys back out of it (the CLI writes them here; that cannot be prevented).
  SETTINGS_PATH:    '{{.XDG_CONFIG_HOME}}/claude/settings.json'
  # Composed artifact: pure function of the two fragment dirs + preserved keys.
  SETTINGS_BUILD:   '{{.STATE_DIR}}/build/settings.json'
  SETTINGS_D:       '{{.ROOT_DIR}}/claude/settings.d'
  SETTINGS_STATE_D: '{{.STATE_DIR}}/settings.d'
```

Update the file header `Side effects:` line to name both paths.

- [ ] **Step 3: settings-compose writes the build artifact**

In `settings-compose`, change `target='{{.SETTINGS_PATH}}'` to keep reading
preserved keys from the live file but write to the build path:

```
        live='{{.SETTINGS_PATH}}'
        built='{{.SETTINGS_BUILD}}'
        settings_d='{{.SETTINGS_D}}'
        state_d='{{.SETTINGS_STATE_D}}'
        mkdir -p "$(dirname "$built")"
        preserved=$(settings_preserved_keys "$live")
```

and `mv "$tmp" "$built"`. Keep the `.permissions and .hooks` sanity check
(it guards against composing an empty object) and the glob guard on
`$settings_d`. Update the `summary:` to name the realize stage and the final
`check` line to `build/settings.json composed from N fragment(s)`.

- [ ] **Step 4: Add claude:activate**

```yaml
  # lint-allow: cmds-without-status
  activate:
    desc: "Install the built settings.json over the live file"
    internal: true
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        set -euo pipefail
        built='{{.SETTINGS_BUILD}}'
        live='{{.SETTINGS_PATH}}'
        if [[ ! -f "$built" ]]; then
          cross "claude:activate: $built missing -- run claude:settings-compose"
          exit 1
        fi
        mkdir -p "$(dirname "$live")"
        # mktemp + mv, never cp onto $live: before the first activation $live
        # is still a symlink into the repo, and cp would follow it and write
        # into tracked source. mv replaces the directory entry instead.
        tmp=$(mktemp "$(dirname "$live")/.settings.XXXXXX")
        trap 'rm -f "$tmp"' EXIT
        cat "$built" > "$tmp"
        chmod 644 "$tmp"
        mv "$tmp" "$live"
        trap - EXIT
        check "claude/settings.json activated"
```

Add `- task: activate` to `claude:install` after `settings-compose`.

- [ ] **Step 5: Repoint audit at build-vs-live**

`claude:audit` no longer composes inline; it deps the compose step and
compares:

```yaml
  # lint-allow: cmds-without-status
  audit:
    desc: "Check the live settings.json for drift vs the composed artifact"
    deps: [settings-compose]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        set -euo pipefail
        built='{{.SETTINGS_BUILD}}'
        live='{{.SETTINGS_PATH}}'
        if [[ ! -f "$live" ]]; then
          cross "claude:audit: $live does not exist -- run 'task install'"
          exit 1
        fi
        if diff -q <(jq -S . "$built") <(jq -S . "$live") >/dev/null; then
          check "settings.json matches the composed artifact (no drift)"
        else
          cross "settings.json DRIFT detected vs composed fragments"
          echo "--- diff: < live | > composed ---" >&2
          diff <(jq -S . "$live") <(jq -S . "$built") >&2 || true
          echo "--- run 'task install' to fix ---" >&2
          exit 1
        fi
```

`settings-compose` writes only into the state tree, never the live system, so
depending on it keeps `audit` read-only with respect to the machine.

- [ ] **Step 6: Migrate and verify byte-equality**

```bash
task claude:install
ls -l ~/.config/claude/settings.json
jq -S . ~/.config/claude/settings.json | diff /tmp/settings-baseline.json - && echo IDENTICAL
```

Expected: the live path is a regular file (no `->` in `ls -l`), and its
normalized content is identical to the pre-migration baseline -- including
`enabledPlugins`, `extraKnownMarketplaces`, and `tui`.

- [ ] **Step 7: Drop settings.json from the link set and the repo**

`taskfiles/links.yml`: remove the `settings.json` line from `CLAUDE_LINKS`.
It is no longer a symlink, so `links:validate` must stop expecting one and
the orphan scanner must stop counting it.

```bash
git rm claude/settings.json
task links:validate
```

Expected: `links:validate` passes with `settings.json` absent from its
output; every other claude link still checks out.

- [ ] **Step 8: Delete LINT-09**

`taskfiles/lint.yml`: remove the `settings-drift` task (lines ~238-262) and
its `- task: settings-drift` / `ignore_error: true` pair from the `default:`
aggregator (lines ~46-47). In `CLAUDE.md`, drop the LINT-09 row from the
catalogue table and extend the gap note: LINT-01, LINT-06, and LINT-09 are
intentionally absent so existing `# LINT-NN:` citations stay unambiguous.
Record why: build-vs-live drift is runtime, and `claude:audit` already covers
it under both `task audit` and `task validate`.

- [ ] **Step 9: Update docs**

- `CLAUDE.md`: the "`claude/settings.json` is a generated build artifact"
  section becomes "the repo tree holds source only" -- fragments in
  `claude/settings.d/`, composed artifact in
  `$XDG_STATE_HOME/dotfiles/build/settings.json`, live file at
  `~/.config/claude/settings.json`. Fix the two "Don't Do" bullets naming
  `claude/settings.json` and LINT-09.
- `claude/README.md`: `settings.json` leaves the file table and the symlink
  list; state that everything in `claude/` is now repo-owned source.
- `install/README.md`: `compose-settings.zsh` writes the build artifact.

- [ ] **Step 10: Verify the whole surface**

```bash
task test && task lint && task validate && task audit
git status --short
```

Expected: all green, and `git status` is clean -- the property that does not
hold today. Toggle the TUI mode or run `/model` in Claude and re-check
`git status`: still clean.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "refactor(claude): compose settings.json into build, activate over live"
```

---

## Phase 3 -- Build dir and task diff (branch `josh/bta-phase-3-diff`)

### Task 8: Materialize the build directory

**Files:**
- Modify: `install/compose-brewfile.zsh` (output path)
- Modify: `taskfiles/packages.yml` (`COMPOSED_BREWFILE`, compose cmd, header)
- Modify: `taskfiles/links.yml` (factor `resolve_source`; new `emit-map`)
- Modify: `Taskfile.yml` (internal `build` task)
- Modify: `install/README.md` (Brewfile path)

**Interfaces:**
- Consumes: `{{.STATE_DIR}}`; `claude:settings-compose` from Task 7.
- Produces: `$XDG_STATE_HOME/dotfiles/build/` containing `Brewfile`,
  `settings.json`, and `links.map` (lines `target<TAB>source`); the internal
  root task `build`; the internal task `links:emit-map`.

- [ ] **Step 1: Repoint the Brewfile composer**

`install/compose-brewfile.zsh:52-53`:

```zsh
typeset -r BUILD_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/build"
typeset -r COMPOSED_OUT="${BUILD_DIR}/Brewfile"
```

Update the `mkdir -p "$CACHE_DIR"` at line ~162 to `"$BUILD_DIR"`, and the
three banner / `Output structure` comments naming
`$XDG_CACHE_HOME/dotfiles/Brewfile`.

`taskfiles/packages.yml`:

```yaml
  COMPOSED_BREWFILE: '{{.STATE_DIR}}/build/Brewfile'
```

Drop the now-unused `XDG_CACHE_HOME="{{.XDG_CACHE_HOME}}"` env prefix from
the `packages:compose` cmd (line ~79) and fix the header comment plus the
`compose` task `desc:` naming the old path. Update the `install/README.md`
line describing the composer's output.

- [ ] **Step 2: Factor resolve_source into a shared var**

`taskfiles/links.yml`: move the `resolve_source()` block currently inlined in
`validate` (lines ~208-228) verbatim into a taskfile var so the validator and
the map emitter cannot drift:

```yaml
  # LINKS_RESOLVE_SOURCE -- shell function mapping an expected TARGET path to
  # its repo SOURCE. Single copy shared by links:validate and links:emit-map;
  # editing a mapping requires editing this case statement AND the
  # corresponding install cmds: entry.
  LINKS_RESOLVE_SOURCE: |
    resolve_source() {
      local target="$1"
      local zdotdir="{{.ZDOTDIR}}"
      local xdg="{{.XDG_CONFIG_HOME}}"
      local dotfiledir="{{.ROOT_DIR}}"
      case "$target" in
        "$zdotdir/.zshenv")            printf '%s\n' "$dotfiledir/shell/.zshenv" ;;
        "$zdotdir/.zprofile")          printf '%s\n' "$dotfiledir/shell/.zprofile" ;;
        "$zdotdir/.zshrc")             printf '%s\n' "$dotfiledir/shell/.zshrc" ;;
        "$zdotdir/.zlogin")            printf '%s\n' "$dotfiledir/shell/.zlogin" ;;
        "$zdotdir/.zlogout")           printf '%s\n' "$dotfiledir/shell/.zlogout" ;;
        "$xdg/claude/"*)               printf '%s\n' "$dotfiledir/claude/${target#$xdg/claude/}" ;;
        "$xdg/ghostty/config")         printf '%s\n' "$dotfiledir/configs/ghostty/config" ;;
        "$xdg/tlrc/"*)                 printf '%s\n' "$dotfiledir/configs/tlrc/${target##*/tlrc/}" ;;
        "$xdg/conda/"*)                printf '%s\n' "$dotfiledir/configs/conda/${target##*/conda/}" ;;
        "$xdg/eza/"*)                  printf '%s\n' "$dotfiledir/configs/eza/${target##*/eza/}" ;;
        *)                             printf '%s\n' "" ;;
      esac
    }
```

Replace the inlined definition in `validate` with `{{.LINKS_RESOLVE_SOURCE}}`
and leave the surrounding logic untouched.

- [ ] **Step 3: Add links:emit-map**

```yaml
  # lint-allow: cmds-without-status
  emit-map:
    desc: "Write the expected-symlink map to the build dir (target TAB source)"
    internal: true
    deps: [":manifest:resolve"]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        {{.LINKS_RESOLVE_SOURCE}}
        mkdir -p '{{.STATE_DIR}}/build'
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        while IFS= read -r target; do
          [[ -z "$target" ]] && continue
          src="$(resolve_source "$target")"
          if [[ -z "$src" ]]; then
            cross "links:emit-map: no known source for $target"
            exit 1
          fi
          printf '%s\t%s\n' "$target" "$src" >> "$tmp"
        done <<< "{{.EXPECTED_TARGETS}}"
        mv "$tmp" '{{.STATE_DIR}}/build/links.map'
        trap - EXIT
        check "build/links.map written ($(wc -l < '{{.STATE_DIR}}/build/links.map' | tr -d ' ') links)"
```

- [ ] **Step 4: Add the root build task**

`Taskfile.yml` (all cmds are `task:` delegations, so LINT-03a's
all-delegates exemption applies):

```yaml
  build:
    desc: "Materialize the desired state into $XDG_STATE_HOME/dotfiles/build/"
    internal: true
    # ponytail: links activation still derives targets from its own vars
    # rather than reading build/links.map -- the map serves task diff only.
    # (packages and claude already consume their built artifacts.) Upgrade
    # path: point links:install at links.map.
    deps: [manifest:resolve]
    cmds:
      - task: packages:compose
      - task: claude:settings-compose
      - task: links:emit-map
```

The install pipeline is intentionally untouched: `packages:install` already
deps `packages:compose`, `claude:install` already deps `settings-compose`,
and `task diff` deps `build` directly.

- [ ] **Step 5: Verify**

```bash
task install
ls -l ~/.local/state/dotfiles/build/
```

Expected: install completes normally; the build dir holds `Brewfile` and
`settings.json` (`links.map` appears once anything deps `:build` -- Task 9).
Confirm the stale cache copy is gone from the pipeline:

```bash
grep -rn 'XDG_CACHE_HOME' taskfiles/ install/
```

Expected: no hits tied to the Brewfile. Optionally
`rm -f ~/.cache/dotfiles/Brewfile` to clear the orphan.

```bash
task lint && task test
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(build): materialize desired state into the state build dir"
```

### Task 9: Per-domain diff tasks and public task diff

**Files:**
- Modify: `taskfiles/packages.yml`, `taskfiles/links.yml`,
  `taskfiles/claude.yml` (one `diff` task each)
- Modify: `Taskfile.yml` (public `diff` aggregator + banner)
- Modify: `CLAUDE.md` (operator table + diagnostics grammar)

**Interfaces:**
- Consumes: `build/` contents from Task 8 via `deps: [":build"]`.
- Produces: public `task diff` and `task <domain>:diff` for packages, links,
  claude.

- [ ] **Step 1: packages:diff**

```yaml
  # lint-allow: cmds-without-status
  diff:
    desc: "Preview package changes: what brew bundle install would add or upgrade"
    deps: [":build"]
    preconditions:
      - sh: command -v brew >/dev/null 2>&1
        msg: "brew not on PATH -- run bootstrap.zsh first"
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        brewfile='{{.COMPOSED_BREWFILE}}'
        changes=0
        # Missing entries: `brew bundle check --verbose` prints one line per
        # absent dependency.
        missing=$(brew bundle check --no-upgrade --verbose --file="$brewfile" 2>/dev/null \
          | ggrep -iE 'needs to be installed' || true)
        if [[ -n "$missing" ]]; then
          info "packages to install:"
          printf '%s\n' "$missing" | sed 's/^/  /'
          changes=$(( changes + $(printf '%s\n' "$missing" | wc -l) ))
        fi
        # Declared entries with newer upstream versions. brew outdated covers
        # formulae and casks in one call; intersect with the declared set so
        # undeclared strays never appear in the preview.
        declared=$( { ggrep -E "^[[:space:]]*(brew|cask)[[:space:]]+'" "$brewfile" || true; } \
          | ggrep -oE "'[^']+'" | tr -d "'" | sort -u)
        outdated=$(brew outdated --quiet 2>/dev/null | sort -u || true)
        upgrades=$(comm -12 <(printf '%s\n' "$declared") <(printf '%s\n' "$outdated") || true)
        if [[ -n "$upgrades" ]]; then
          info "packages to upgrade:"
          printf '%s\n' "$upgrades" | sed 's/^/  /'
          changes=$(( changes + $(printf '%s\n' "$upgrades" | wc -l) ))
        fi
        if (( changes == 0 )); then
          check "packages: no changes"
        else
          info "packages: ${changes} change(s) pending -- run 'task install'"
        fi
```

Verify the literal `brew bundle check --verbose` wording against the
installed brew at execution time and adjust the ggrep pattern if it differs;
the assertion target is "one line per missing entry".

- [ ] **Step 2: links:diff**

```yaml
  # lint-allow: cmds-without-status
  diff:
    desc: "Preview symlink changes: links install would create or retarget"
    deps: [":build"]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        map='{{.STATE_DIR}}/build/links.map'
        changes=0
        while IFS=$'\t' read -r target source; do
          [[ -z "$target" ]] && continue
          if [[ ! -L "$target" ]]; then
            info "create:   $target -> $source"
            changes=$(( changes + 1 ))
          else
            actual=$(readlink -f "$target" 2>/dev/null || true)
            if [[ "$actual" != "$source" ]]; then
              info "retarget: $target -> $source (currently ${actual:-broken})"
              changes=$(( changes + 1 ))
            fi
          fi
        done < "$map"
        if (( changes == 0 )); then
          check "links: no changes"
        else
          info "links: ${changes} change(s) pending -- run 'task install'"
        fi
```

- [ ] **Step 3: claude:diff**

```yaml
  # lint-allow: cmds-without-status
  diff:
    desc: "Preview settings.json changes: built artifact vs live file"
    deps: [":build"]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        {{if not (index .MANIFEST.features "claude-marketplace")}}
        info "claude: feature disabled -- skipped"
        exit 0
        {{end}}
        built='{{.SETTINGS_BUILD}}'
        live='{{.SETTINGS_PATH}}'
        if [[ ! -f "$live" ]]; then
          info "claude: settings.json would be created"
          exit 0
        fi
        if diff -q <(jq -S . "$built") <(jq -S . "$live") >/dev/null 2>&1; then
          check "claude: settings.json current"
        else
          info "claude: settings.json would change (< live | > built):"
          diff <(jq -S . "$live") <(jq -S . "$built") || true
        fi
```

Same comparison as `claude:audit`; the difference is the exit contract --
`diff` always exits 0, `audit` exits non-zero on drift.

- [ ] **Step 4: Public aggregator, banner, docs**

`Taskfile.yml`:

```yaml
  # lint-allow: cmds-without-status
  diff:
    desc: "Preview what task install would change (read-only)"
    status: [false]
    deps: [build]
    cmds:
      - task: packages:diff
        ignore_error: true
      - task: links:diff
        ignore_error: true
      - task: claude:diff
        ignore_error: true
```

Add to the `default:` banner lifecycle block (LINT-08 requires every public
top-level task to appear):

```
        info "  diff        Preview what task install would change"
```

and to the diagnostics block:

```
        info "  task <domain>:diff                   packages | links | claude"
```

`CLAUDE.md`: add the `task diff` row to the Common Tasks table and `diff` to
the domain-verb grammar list.

- [ ] **Step 5: Verify**

```bash
task diff
```

Expected on a converged machine: three `no changes` / `current` lines. Then
prove detection and repair:

```bash
rm ~/.config/eza/theme.yaml
task diff        # expect: create: .../eza/theme.yaml -> .../configs/eza/theme.yaml
task install
task diff        # expect: silent again
```

```bash
task lint && task test
```

Expected: all pass, including LINT-08 banner parity now that `diff` is
listed.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(diff): task diff previews install changes per domain"
```

### Task 10: Retire the superseded plan

- [ ] **Step 1: Delete the 07-23 plan**

Every phase of it is either delivered here or delivered by the manifest tier
restructure in v2.5.0.

```bash
git rm docs/superpowers/plans/2026-07-23-nixos-architecture-improvements.md
```

- [ ] **Step 2: Update the learnings doc priority list**

`docs/NIXOS-ARCHITECTURE-LEARNINGS.md` ends with a five-item priority order.
Mark A (build dir), B (purity), D (install taxonomy), and E (test layout) as
done with a pointer to
`docs/superpowers/specs/2026-08-02-build-then-activate-design.md`, matching
how item C already records the tier restructure. Do not rewrite the analysis
sections -- only the status markers.

- [ ] **Step 3: Verify and commit**

```bash
task lint && task test
git add -A
git commit -m "docs(plans): retire the superseded nixos architecture plan"
```

---

## Self-review checklist (run after writing, before executing)

- Every `Modify:` path and line number was checked against the tree at
  v2.5.0 (`f7bdee5`); re-verify before editing, since line numbers move as
  earlier tasks land.
- Phase ordering is load-bearing twice: Task 5's new test file must land at
  `install/tests/` (Phase 1 first), and `claude:diff` needs the built
  artifact and the live file to be two distinct paths (Phase 2 before
  Phase 3).
- The two irreversible-looking steps are both git-recoverable: Task 7 Step 7
  (`git rm claude/settings.json`) is preceded by a byte-equality gate in
  Step 6, and Task 10 deletes a document whose content is fully absorbed
  here.
- Known judgment calls, resolved in the design doc: preserved CLI keys are
  still read from the live file; links activation still does not read
  `links.map`; LINT-09 is deleted rather than repointed.
