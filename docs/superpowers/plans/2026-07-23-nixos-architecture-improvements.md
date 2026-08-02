# NixOS Architecture Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the repo along the architecture learnings in
`docs/NIXOS-ARCHITECTURE-LEARNINGS.md`: one uniform test layout, pure
settings composition (no generated files in the source tree), a
materialized build directory that makes `task diff` a cheap corollary, and
feature-declared packages in the registry.

**Architecture:** Three phases, each independently shippable.
Phase 1 unifies the three test conventions into `<domain>/tests/`.
Phase 2 moves machine-generated addon fragments out of the repo tree into
`$XDG_STATE_HOME/dotfiles/settings.d/` and makes settings compose a
deterministic, tested merge of `repo fragments + state fragments`.
Phase 3 materializes the desired state into
`$XDG_STATE_HOME/dotfiles/build/` (Brewfile, settings.json, links.map) and
adds per-domain `diff` tasks plus a public `task diff`.

Generation snapshots / rollback machinery are deliberately OUT of scope
(see the non-goals note at the end) -- the build dir contains exactly what
`task diff` consumes, nothing more.

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
  `# lint-allow: cmds-without-status` annotation (LINT-03a; tasks whose
  cmds are all `task:` delegations are exempt).
- Symlinks only via `_:safe-link` (LINT-03b). No hardcoded
  `/opt/homebrew` / `/usr/local` (LINT-10). Kebab-case feature keys use the
  `index` template form (LINT-11). Multi-element TOML arrays span one
  element per line (LINT-13).
- Never hand-edit `claude/settings.json` (generated; LINT-09 enforces).
- Taskfile shell blocks run under go-task's embedded POSIX-ish interpreter
  (mvdan/sh), NOT zsh -- no zsh glob qualifiers or zsh-only idioms in
  `cmds:` blocks or in libraries sourced by them
  (`install/compose-settings.zsh`, `install/messages.zsh`).
- Branch per phase: `josh/nix-phase-<n>-<slug>`; PR to master; squash merge.
- After every task: `task lint` and `task test` both pass before commit.
- The public operator surface is curated: any new public top-level task must
  be added to the `default:` banner in `Taskfile.yml` (LINT-08) and to the
  CLAUDE.md operator table.

## Target layout (the end state)

Repo tree (changes only):

```
install/
  README.md                  (rewritten: stage taxonomy)
  messages.zsh               [lib]
  compose-settings.zsh       [lib]
  resolver.zsh               [evaluate]
  compose-brewfile.zsh       [compose]
  lint-rules.zsh             [operate]
  links-audit-scan.zsh       [operate]
  claude-addons.zsh          [operate]
  repo-sync.zsh              [operate]
  tests/
    hooks.zsh                (was install/test-hooks.zsh)
    links-audit.zsh          (was install/test-links-audit.zsh)
    repo-sync.zsh            (was install/test-repo-sync.zsh)
    shell-startup.zsh        (was install/test-shell-startup.zsh)
    settings-compose.zsh     (new, Phase 2)
manifests/
  tests/                     (was manifests/test/)
    fixtures/
    shared/
taskfiles/
  tests/                     (was taskfiles/test/)
    lint-fixtures/
claude/
  settings.d/
    00-base.json             (repo-owned only; 99-addon-* gone from tree)
    10-hooks.json
```

State tree (`$XDG_STATE_HOME/dotfiles/`):

```
machine                      (existing)
resolved.json                (existing)
settings.d/                  (new: machine-generated addon fragments)
  99-addon-<name>.json
build/                       (new: exactly what task diff consumes)
  Brewfile                   (moved here from $XDG_CACHE_HOME/dotfiles/)
  settings.json
  links.map
```

---

## Phase 1 -- Test layout unification (branch `josh/nix-phase-1-test-layout`)

### Task 1: Move install test scripts to install/tests/

**Files:**
- Move: `install/test-hooks.zsh` -> `install/tests/hooks.zsh`
- Move: `install/test-links-audit.zsh` -> `install/tests/links-audit.zsh`
- Move: `install/test-repo-sync.zsh` -> `install/tests/repo-sync.zsh`
- Move: `install/test-shell-startup.zsh` -> `install/tests/shell-startup.zsh`
- Modify: `taskfiles/test.yml` (4 invocation paths, 4 desc strings, header)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the `install/tests/<name>.zsh` path convention every later task
  (Task 5's new test) follows. Task names (`test:hooks` etc.) are unchanged.

- [ ] **Step 1: git mv the four scripts (preserves execute bits)**

```bash
cd /Users/josh/Git/personal/dotfiles
mkdir -p install/tests
git mv install/test-hooks.zsh          install/tests/hooks.zsh
git mv install/test-links-audit.zsh    install/tests/links-audit.zsh
git mv install/test-repo-sync.zsh      install/tests/repo-sync.zsh
git mv install/test-shell-startup.zsh  install/tests/shell-startup.zsh
```

- [ ] **Step 2: Update each moved script's banner title line**

In each moved file, the banner's first content line names the old path.
Edit exactly these four lines (nothing else in the banners changes):

- `install/tests/hooks.zsh`:
  `# install/test-hooks.zsh -- smoke tests for the four named Claude hooks`
  -> `# install/tests/hooks.zsh -- smoke tests for the four named Claude hooks`
- `install/tests/links-audit.zsh`:
  `# install/test-links-audit.zsh -- smoke tests for install/links-audit-scan.zsh`
  -> `# install/tests/links-audit.zsh -- smoke tests for install/links-audit-scan.zsh`
- `install/tests/repo-sync.zsh`:
  `# install/test-repo-sync.zsh -- smoke tests for install/repo-sync.zsh`
  -> `# install/tests/repo-sync.zsh -- smoke tests for install/repo-sync.zsh`
- `install/tests/shell-startup.zsh`:
  `# install/test-shell-startup.zsh -- smoke tests for zsh startup files`
  -> `# install/tests/shell-startup.zsh -- smoke tests for zsh startup files`

- [ ] **Step 3: Update taskfiles/test.yml paths and descs**

Replace the four invocation lines:

```
zsh "${DOTFILEDIR}/install/test-hooks.zsh"          -> zsh "${DOTFILEDIR}/install/tests/hooks.zsh"
zsh "${DOTFILEDIR}/install/test-repo-sync.zsh"      -> zsh "${DOTFILEDIR}/install/tests/repo-sync.zsh"
zsh "${DOTFILEDIR}/install/test-links-audit.zsh"    -> zsh "${DOTFILEDIR}/install/tests/links-audit.zsh"
zsh "${DOTFILEDIR}/install/test-shell-startup.zsh"  -> zsh "${DOTFILEDIR}/install/tests/shell-startup.zsh"
```

Update the four `desc:` strings to name the new paths, e.g.
`desc: "Run Claude hook smoke tests via install/tests/hooks.zsh"`.
Update the file-header `Purpose:`/`Depends on:` lines that name
`install/test-hooks.zsh` etc. to the new paths.

- [ ] **Step 4: Verify**

Run: `task test`
Expected: all suites pass (hook, repo-sync, links-audit, shell-startup,
manifest fixtures, lint fixtures).

Run: `task lint`
Expected: all checks pass (LINT-04/LINT-12 pick up the moved files at their
new paths; git mv preserved the execute bits).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(tests): move install test scripts to install/tests/"
```

### Task 2: Rename manifests/test/ to manifests/tests/

**Files:**
- Move: `manifests/test/` -> `manifests/tests/` (fixtures/, shared/, README.md)
- Modify: `Taskfile.yml:47` (FIXTURES_DIR var)
- Modify: `taskfiles/test.yml` (shared-dir path, header comment)
- Modify: `manifests/tests/README.md` (internal path references)

**Interfaces:**
- Consumes: nothing.
- Produces: `{{.FIXTURES_DIR}}` now resolves to
  `manifests/tests/fixtures`.

- [ ] **Step 1: git mv the directory**

```bash
git mv manifests/test manifests/tests
```

- [ ] **Step 2: Update the FIXTURES_DIR var in Taskfile.yml**

```yaml
  FIXTURES_DIR: '{{.ROOT_DIR}}/manifests/tests/fixtures'
```

- [ ] **Step 3: Update taskfiles/test.yml references**

Line `test_shared_dir="{{.ROOT_DIR}}/manifests/test/shared"` ->
`test_shared_dir="{{.ROOT_DIR}}/manifests/tests/shared"`.
Header `Depends on:` line naming `manifests/test/fixtures/` ->
`manifests/tests/fixtures/`.

- [ ] **Step 4: Fix internal references in manifests/tests/README.md**

```bash
grep -n 'manifests/test/' manifests/tests/README.md
```

Replace every hit's `manifests/test/` with `manifests/tests/`.

- [ ] **Step 5: Verify**

Run: `task test`
Expected: the manifest fixture suite finds and runs every typed-* and
_invalid-* fixture at the new path; all pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(tests): rename manifests/test to manifests/tests"
```

### Task 3: Rename taskfiles/test/ to taskfiles/tests/ and update lint scopes

**Files:**
- Move: `taskfiles/test/` -> `taskfiles/tests/`
- Modify: `taskfiles/lint.yml` (five path/scope references)

**Interfaces:**
- Consumes: nothing.
- Produces: lint-fixture path `taskfiles/tests/lint-fixtures/` consumed by
  `lint:test-fixtures`.

- [ ] **Step 1: git mv the directory**

```bash
git mv taskfiles/test taskfiles/tests
```

- [ ] **Step 2: Update taskfiles/lint.yml scopes**

Five edits (fixture files intentionally violate lint rules, so every
exclusion must follow the rename or the production scan turns red):

1. `ZSH_FIND` var: `-not -path '{{.ROOT_DIR}}/taskfiles/test/*'` ->
   `-not -path '{{.ROOT_DIR}}/taskfiles/tests/*'`
2. `shell-headers` find: `-not -path '{{.ROOT_DIR}}/taskfiles/test/*'` ->
   `-not -path '{{.ROOT_DIR}}/taskfiles/tests/*'`
3. LINT-03b scan: `--exclude-dir='test'` -> `--exclude-dir='tests'`; also
   update the comment line above it that cites `--exclude-dir='test'`.
4. `brew-prefix` scan: `--exclude-dir='test'` -> `--exclude-dir='tests'`
5. `test-fixtures` task:
   `fixtures_dir="{{.ROOT_DIR}}/taskfiles/test/lint-fixtures"` ->
   `fixtures_dir="{{.ROOT_DIR}}/taskfiles/tests/lint-fixtures"`

- [ ] **Step 3: Verify**

Run: `task lint`
Expected: all pass -- in particular no LINT-03b/LINT-04/LINT-10 failures
from fixture files leaking into the production scan.

Run: `task test`
Expected: `lint:test-fixtures` reports all fixtures behaving as expected.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(tests): rename taskfiles/test to taskfiles/tests"
```

### Task 4: install/README stage taxonomy + stale-reference sweep

**Files:**
- Modify: `install/README.md` (rewrite the Key files section)
- Modify: any remaining live doc naming the old test paths

**Interfaces:**
- Consumes: the Phase 1 renames.
- Produces: the documented stage taxonomy (lib / evaluate / compose /
  operate / tests) that new `install/` scripts must slot into.

- [ ] **Step 1: Rewrite the Key files section of install/README.md**

Replace the current flat `## Key files` list with a staged one (keep the
existing per-file descriptions; only regroup and retitle):

```markdown
## Key files, by pipeline stage

Every script here belongs to exactly one stage. A new script must name its
stage in this list.

### lib (sourced, never executed)

- `messages.zsh` -- colored-output library (`info`, `check`, `cross`, ...)
  sourced by task `cmds:` blocks via `{{.DOTFILES_MESSAGES}}`.
- `compose-settings.zsh` -- settings-compose algorithm shared by
  `claude:settings-compose` and `claude:audit`.

### evaluate (manifest -> resolved.json)

- `resolver.zsh` -- validates a machine manifest against the feature
  registry and base tier, then compiles it to
  `$XDG_STATE_HOME/dotfiles/resolved.json`.

### compose (resolved.json -> concrete artifacts)

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

Also update the older prose references in that README (`test-hooks.zsh`
mentions in the intro and References sections) to the new paths.

- [ ] **Step 2: Sweep for stale path references**

```bash
grep -rn 'install/test-\|manifests/test/\|taskfiles/test/' \
  --include='*.md' --include='*.yml' --include='*.zsh' --include='*.toml' . \
  | grep -v '.git/' | grep -v 'docs/superpowers/specs/'
```

Fix every hit in live docs (`docs/NIXOS-ARCHITECTURE-LEARNINGS.md`,
`taskfiles/README.md`, `claude/README.md`, `docs/*.md` as found) by
substituting the new path. Leave `docs/superpowers/specs/*` untouched --
dated design documents are historical records.

- [ ] **Step 3: Verify**

Re-run the grep from Step 2.
Expected: zero hits outside `docs/superpowers/specs/`.

Run: `task lint && task test`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs(install): stage taxonomy in README; fix stale test paths"
```

---

## Phase 2 -- Claude settings purity (branch `josh/nix-phase-2-settings-purity`)

### Task 5: Move addon fragments out of the repo tree (test-first)

**Files:**
- Create: `install/tests/settings-compose.zsh`
- Modify: `install/compose-settings.zsh` (two-dir compose)
- Modify: `install/claude-addons.zsh` (SETTINGS_D -> state dir)
- Modify: `taskfiles/claude.yml` (compose + audit call sites, new var)
- Modify: `taskfiles/claude-addons.yml` (header comment)
- Modify: `taskfiles/test.yml` + root `Taskfile.yml` (wire the new test)
- Delete: `claude/settings.d/99-addon-ecc.json` (tracked build artifact)
- Modify: `CLAUDE.md`, `docs/CLAUDE-ADDONS.md`, `claude/README.md` (docs)

**Interfaces:**
- Consumes: `install/tests/` convention from Task 1.
- Produces: `settings_compose_fragments <repo_d> <state_d> <preserved_json>
  [jq_flag]` (new signature -- state dir may be missing/empty) and the
  machine-fragment location `$XDG_STATE_HOME/dotfiles/settings.d/`
  (taskfile var `SETTINGS_STATE_D`), both consumed by Task 6.

- [ ] **Step 1: Write the failing test**

Create `install/tests/settings-compose.zsh` (executable: `chmod +x`):

```zsh
#!/usr/bin/env zsh

# =============================================================================
# install/tests/settings-compose.zsh -- smoke tests for compose-settings.zsh
#
# Purpose:      Exercise settings_compose_fragments + settings_preserved_keys
#               against throwaway fragment dirs: repo-fragment merge order,
#               state-dir addon fragments layering over repo fragments,
#               missing/empty state dir, and preserved CLI-managed keys
#               winning over fragment values.
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

# Scenario 5: settings_preserved_keys extracts only CLI-managed keys.
live="${work}/settings.json"
echo '{"enabledPlugins": {"q": true}, "permissions": {}, "model": "opus"}' > "$live"
out=$(settings_preserved_keys "$live")
if [[ "$(echo "$out" | jq -c 'keys | sort')" == '["enabledPlugins","extraKnownMarketplaces","model"]' ]]; then
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

- [ ] **Step 2: Run it to verify it fails**

```bash
DOTFILEDIR="$PWD" zsh install/tests/settings-compose.zsh
```

Expected: FAIL -- `settings_compose_fragments` still has the old
2-arg-plus-flag signature, so scenarios 1-4 misparse arguments and cross.

- [ ] **Step 3: Implement the two-dir compose**

In `install/compose-settings.zsh`, replace `settings_compose_fragments`
(keep `settings_preserved_keys` untouched):

```zsh
# settings_compose_fragments <repo_settings_d> <state_settings_d> <preserved_json> [jq_flag]
# Deep-merge every *.json fragment: repo dir first (numeric filename prefix
# = merge priority), then the state dir (machine-generated addon fragments,
# 99-addon-* by convention), then layer the preserved keys on top. The state
# dir may be missing or empty. Pass `-S` as the optional 4th arg to sort
# keys (claude:audit uses this to normalize key order for its diff; the
# compose path passes nothing so the written settings.json byte-matches the
# historical output). Output to stdout. find (not glob) enumerates
# fragments: portable across zsh and go-task's embedded shell, and immune
# to zsh's nomatch abort on an empty dir.
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

Update the file's header banner `Purpose:` line to mention the two fragment
sources (repo `claude/settings.d/` + machine
`$XDG_STATE_HOME/dotfiles/settings.d/`).

- [ ] **Step 4: Run the test to verify it passes**

```bash
DOTFILEDIR="$PWD" zsh install/tests/settings-compose.zsh
```

Expected: PASS -- `settings-compose: all scenarios passed`, exit 0.

- [ ] **Step 5: Wire the new test into the suite**

In `taskfiles/test.yml` add (alongside the other runners):

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

In root `Taskfile.yml`, extend the `test:` aggregator:

```yaml
      - task: test:settings-compose
```

and widen its `desc:` string to include `settings-compose`.

- [ ] **Step 6: Point the addon lifecycle at the state dir**

In `install/claude-addons.zsh`:

```zsh
typeset -r SETTINGS_D="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/settings.d"
```

(replacing `typeset -r SETTINGS_D="${DOTFILEDIR}/claude/settings.d"`).
Update the banner `Side effects:` line and the `cmd_remove` Phase-4 comment
to name the new location. `cmd_install` already does `mkdir -p "$SETTINGS_D"`
before the `cp` -- no other change needed.

In `taskfiles/claude-addons.yml`, update the header `Side effects:` comment
(`claude/settings.d/99-addon-<name>.json` ->
`$XDG_STATE_HOME/dotfiles/settings.d/99-addon-<name>.json`) and the
`remove` task's `summary:` text likewise.

- [ ] **Step 7: Update the compose/audit call sites**

In `taskfiles/claude.yml`:

Add to `vars:`:

```yaml
  SETTINGS_STATE_D: '{{.STATE_DIR}}/settings.d'
```

In `settings-compose` cmds, add after `settings_d='{{.SETTINGS_D}}'`:

```
        state_d='{{.SETTINGS_STATE_D}}'
```

change the compose invocation to:

```
        if ! settings_compose_fragments "$settings_d" "$state_d" "$preserved" > "$tmp"; then
```

and the fragment count line to:

```
        fragment_count=$( { ls "$settings_d"/*.json 2>/dev/null; ls "$state_d"/*.json 2>/dev/null; } | wc -l | tr -d ' ')
```

In `audit` cmds, add `state_d='{{.SETTINGS_STATE_D}}'` likewise and change:

```
        settings_compose_fragments "$settings_d" "$state_d" "$preserved" -S > "$expected"
```

Update the `settings-compose` task's `summary:` text (step 2 of the
algorithm) to name both fragment sources.

- [ ] **Step 8: Remove the tracked build artifact and regenerate**

```bash
git rm claude/settings.d/99-addon-ecc.json
DOTFILEDIR="$PWD" zsh install/claude-addons.zsh install
```

Expected: the ecc addon reports installed/upgraded and
`~/.local/state/dotfiles/settings.d/99-addon-ecc.json` exists.

- [ ] **Step 9: Update docs**

```bash
grep -rn 'settings\.d' CLAUDE.md docs/CLAUDE-ADDONS.md claude/README.md
```

For every hit describing addon fragments (`99-addon-<name>.json`): the
location is now `$XDG_STATE_HOME/dotfiles/settings.d/` (machine state, not
the repo tree). Repo-owned fragments (`00-base`, `10-hooks`) stay in
`claude/settings.d/` -- hits about those keep their wording. In CLAUDE.md
this touches the "claude/settings.json is a generated build artifact"
section, the addons section, the "Where to Add Things" hook row, and the
"Don't Do" bullets.

- [ ] **Step 10: Verify the whole surface**

```bash
task test
task lint
```

Expected: all pass -- LINT-09 (settings drift) passes because the composed
output (repo fragments + state fragment + preserved keys) still matches the
live `claude/settings.json`.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "refactor(claude): addon settings fragments live in machine state, not the repo tree"
```

---

## Phase 3 -- Diff preview via a build dir (branch `josh/nix-phase-3-diff`)

### Task 6: Materialize the build directory

**Files:**
- Modify: `install/compose-brewfile.zsh` (output path -> build dir)
- Modify: `taskfiles/packages.yml` (COMPOSED_BREWFILE var, header)
- Modify: `taskfiles/claude.yml` (new internal `settings-build` task)
- Modify: `taskfiles/links.yml` (factor resolve_source; new `emit-map` task)
- Modify: `Taskfile.yml` (new internal `build` task)
- Modify: `install/README.md` (Brewfile path reference)

**Interfaces:**
- Consumes: two-dir `settings_compose_fragments` +
  `SETTINGS_STATE_D` (Task 5), `{{.STATE_DIR}}` root var.
- Produces: `$XDG_STATE_HOME/dotfiles/build/` containing `Brewfile`,
  `settings.json`, and `links.map` (lines `target<TAB>source`); the
  internal root task `build`; the internal tasks `claude:settings-build`
  and `links:emit-map`. Task 7 consumes all of these.

- [ ] **Step 1: Repoint the Brewfile composer at the build dir**

In `install/compose-brewfile.zsh` replace:

```zsh
typeset -r CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
typeset -r COMPOSED_OUT="${CACHE_DIR}/Brewfile"
```

with:

```zsh
typeset -r BUILD_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/build"
typeset -r COMPOSED_OUT="${BUILD_DIR}/Brewfile"
```

Update every other `CACHE_DIR` reference in the script (the `mkdir -p`
before the atomic write) to `BUILD_DIR`, and the banner/`Output structure`
comments naming `$XDG_CACHE_HOME/dotfiles/Brewfile` to
`$XDG_STATE_HOME/dotfiles/build/Brewfile`.

In `taskfiles/packages.yml`:

```yaml
  COMPOSED_BREWFILE: '{{.STATE_DIR}}/build/Brewfile'
```

Drop the now-unused `XDG_CACHE_HOME=...` env prefix from the
`packages:compose` cmd line and update the file header comment naming the
old path. Update the `install/README.md` line describing
`compose-brewfile.zsh`'s output path.

- [ ] **Step 2: Add claude:settings-build**

In `taskfiles/claude.yml` add:

```yaml
  # lint-allow: cmds-without-status
  settings-build:
    desc: "Compose settings.json into the build dir (no live-file write)"
    internal: true
    deps: [":manifest:resolve"]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        {{if not (index .MANIFEST.features "claude-marketplace")}}
        info "claude: feature disabled -- skipped"
        exit 0
        {{end}}
        source '{{.ROOT_DIR}}/install/compose-settings.zsh'
        set -euo pipefail
        mkdir -p '{{.STATE_DIR}}/build'
        preserved=$(settings_preserved_keys '{{.SETTINGS_PATH}}')
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        if ! settings_compose_fragments '{{.SETTINGS_D}}' '{{.SETTINGS_STATE_D}}' "$preserved" > "$tmp"; then
          cross "claude:settings-build: compose failed"
          exit 1
        fi
        mv "$tmp" '{{.STATE_DIR}}/build/settings.json'
        trap - EXIT
        check "build/settings.json composed"
```

- [ ] **Step 3: Factor resolve_source and add links:emit-map**

In `taskfiles/links.yml`, move the `resolve_source()` function body (the
whole `resolve_source() { ... }` block currently inlined in `validate`'s
cmd) into a taskfile var so two tasks share one copy:

```yaml
vars:
  # ... existing CLAUDE_LINKS and EXPECTED_TARGETS ...

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

In `validate`'s cmd, replace the inlined function definition with
`{{.LINKS_RESOLVE_SOURCE}}` (keep the surrounding logic untouched).

Add the new task:

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

In `Taskfile.yml` add (all cmds are `task:` delegations, so LINT-03a's
all-delegates exemption applies -- no status needed):

```yaml
  build:
    desc: "Materialize the desired state into $XDG_STATE_HOME/dotfiles/build/"
    internal: true
    # ponytail: activation (links:install, claude:settings-compose) still
    # derives state from its own vars rather than reading build/ -- the
    # build dir is authoritative for task diff only (the Brewfile is the
    # exception: packages:install consumes the built one). Upgrade path:
    # point links:install at links.map and claude:install at
    # build/settings.json.
    deps: [manifest:resolve]
    cmds:
      - task: packages:compose
      - task: claude:settings-build
      - task: links:emit-map
```

The install pipeline is intentionally untouched: `packages:install`
already deps `packages:compose` (which now writes into the build dir), and
`task diff` deps `build` directly, regenerating on demand.

- [ ] **Step 5: Verify**

`build` is internal; exercise it via the pipeline:

```bash
task install
ls ~/.local/state/dotfiles/build/
```

Expected: `task install` completes normally and the build dir contains at
least `Brewfile` (settings.json and links.map appear after the first
`task diff` in Task 7 -- or run any task that deps `:build` once it
exists).

```bash
task lint && task test
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(build): materialize desired state into state build dir"
```

### Task 7: Per-domain diff tasks + public task diff

**Files:**
- Modify: `taskfiles/packages.yml` (packages:diff)
- Modify: `taskfiles/links.yml` (links:diff)
- Modify: `taskfiles/claude.yml` (claude:diff)
- Modify: `Taskfile.yml` (public `diff` aggregator + banner)
- Modify: `CLAUDE.md` (operator command table + diagnostics grammar)

**Interfaces:**
- Consumes: `build/` contents from Task 6 (`Brewfile`, `links.map`,
  `settings.json`); root `build` task via `deps: [":build"]`.
- Produces: `task diff` (public), `task <domain>:diff` for packages, links,
  claude.

- [ ] **Step 1: packages:diff**

Add to `taskfiles/packages.yml`:

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
        # Declared entries with newer upstream versions. brew outdated
        # covers formulae and casks in one call; intersect with the declared
        # set so undeclared strays never appear in the preview.
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

(Verify the literal `brew bundle check --verbose` phrasing on the installed
brew version at execution time and adjust the ggrep pattern if the wording
differs -- the assertion target is "one line per missing entry".)

- [ ] **Step 2: links:diff**

Add to `taskfiles/links.yml`:

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

Add to `taskfiles/claude.yml`:

```yaml
  # lint-allow: cmds-without-status
  diff:
    desc: "Preview settings.json changes: built settings vs live file"
    deps: [":build"]
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        {{if not (index .MANIFEST.features "claude-marketplace")}}
        info "claude: feature disabled -- skipped"
        exit 0
        {{end}}
        built='{{.STATE_DIR}}/build/settings.json'
        live='{{.SETTINGS_PATH}}'
        if [[ ! -f "$live" ]]; then
          info "claude: settings.json would be created"
          exit 0
        fi
        if diff <(jq -S . "$built") <(jq -S . "$live") >/dev/null 2>&1; then
          check "claude: settings.json current"
        else
          info "claude: settings.json would change (< live | > built):"
          diff <(jq -S . "$live") <(jq -S . "$built") || true
        fi
```

- [ ] **Step 4: Public aggregator + banner + docs**

In `Taskfile.yml` add:

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

Add to the `default:` banner's lifecycle block (LINT-08 requires it):

```
        info "  diff        Preview what task install would change"
```

In `CLAUDE.md`: add the `task diff` row to the Common Tasks table and add
`diff` to the domain-verb grammar line
(`task <domain>:diff -- packages | links | claude`).

- [ ] **Step 5: Verify**

```bash
task diff
```

Expected on a converged machine: three `no changes` / `current` lines.
Then break something and confirm detection:

```bash
rm ~/.config/eza/theme.yaml && task diff
```

Expected: `create: .../eza/theme.yaml -> .../configs/eza/theme.yaml`.
Repair: `task install`. Then `task lint && task test` -- all pass
(banner-parity LINT-08 now sees `diff` listed).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(diff): task diff previews install changes per domain"
```

---

## Non-goals (documented to prevent re-litigation)

- **Generation snapshots / rollback machinery.** Considered and cut by
  operator decision (2026-07-24): Homebrew is rolling-release and refuses
  version pinning, so binaries never roll back regardless -- and the
  remaining value (a version-record flight recorder for "it worked last
  week" bisection) addresses a problem that has not occurred in years of
  operation. Config rollback is already git checkout + `task install`.
  Everything cut with it: `taskfiles/generations.yml`, `build/meta.json`,
  `build/resolved.json` copy, the CLI-state snapshot file, and the
  `task: build` step in the install pipeline. Revisit only if a real
  "which version did I have?" incident actually happens.
- **Activation reading from build/.** links:install and claude:install keep
  their own state derivation; the build dir serves `task diff` only
  (the Brewfile excepted -- packages:install consumes the built one).
  Ponytail'd on the `build` task with the upgrade path.
- **`packages:prune`, diff-vs-history comparisons.** NIXOS-IDEAS items;
  out of scope here.

## Self-review checklist (run after writing, before executing)

- Spec coverage against the learnings doc: A build-dir/diff (Tasks 6-7),
  B purity (Task 5), C feature packages (delivered separately by
  docs/superpowers/plans/2026-08-02-manifest-tier-restructure.md), D install taxonomy
  (Task 4), E test layout (Tasks 1-3). Generations deliberately excluded
  (see Non-goals).
- Every path in this plan was verified against the live tree at plan time;
  re-verify any `Modify:` line against current file contents before
  editing (files may have drifted).
- Known judgment calls, resolved: settings-build reads CLI keys from the
  live file via settings_preserved_keys (same as compose/audit -- the CLI
  writes those keys into the live file, so reading them there is the
  honest interface, not an impurity to engineer around); the install
  pipeline is untouched by Phase 3.
