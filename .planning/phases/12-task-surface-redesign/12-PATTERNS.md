# Phase 12: Task Surface Redesign -- Pattern Map

**Mapped:** 2026-05-18
**Phase shape:** rename + visibility refactor across every taskfile (zero net-new behavior; one new lint check; one new doc artifact)
**Files analyzed:** 14 taskfiles + 1 root Taskfile.yml + 7 doc targets + 1 messages library
**Analogs found:** all primary patterns located in current v2 surface (no analog miss)

---

## File Classification

### Creation targets

| File | Role | Data Flow | Closest analog |
|---|---|---|---|
| `.planning/phases/12-task-surface-redesign/SURFACE.md` | classification table | document | `.planning/phases/09-v1-drop-audit/09-01-PLAN.md` (six-column AUDIT.md table) + `AUDIT.md` itself |
| `taskfiles/test/lint-fixtures/13-banner-parity-fail/Taskfile.yml` (positive) | lint fixture | static input | `taskfiles/test/lint-fixtures/03a-cmds-no-status/Taskfile.yml` |
| `taskfiles/test/lint-fixtures/13-banner-parity-fail/expect` | fixture expectation | static | `taskfiles/test/lint-fixtures/02a-shell-var-in-status/expect` |
| `taskfiles/test/lint-fixtures/13-banner-parity-ok/Taskfile.yml` (negative) | lint fixture | static input | `taskfiles/test/lint-fixtures/03a-internal-no-status-ok/Taskfile.yml` |
| `taskfiles/test/lint-fixtures/13-banner-parity-ok/expect` | fixture expectation | static | same |

Note: fixture directory names follow the `<LINT-NN><variant>-<slug>/` convention already in use (e.g., `02a-shell-var-in-status`, `02b-template-var-in-status`); planner may use `13a-` / `13b-` or a different banner-rule number per the existing LINT-NN scheme.

### Edit targets -- rename pass (one row per task being renamed)

| File | Role | Current task name | Renamed to | Verb | D-ref |
|---|---|---|---|---|---|
| `taskfiles/links.yml` | aggregator | `links:all` | `links:install` | rename + `internal: true` | D-09, D-01 |
| `taskfiles/links.yml` | sub-target | `links:zsh` | `links:install-zsh` | rename + `internal: true` | D-10, D-01 |
| `taskfiles/links.yml` | sub-target | `links:claude` | `links:install-claude` | rename + `internal: true` | D-10, D-01 |
| `taskfiles/links.yml` | sub-target | `links:configs` | `links:install-configs` | rename + `internal: true` | D-10, D-01 |
| `taskfiles/links.yml` | validate | `links:validate` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/links.yml` | diagnostic | `links:reconcile` | `audit:links` | rename (move to audit:) | D-02 |
| `taskfiles/identity.yml` | aggregator | `identity:install` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/identity.yml` | sub-target | `identity:git` | `identity:install-git` | rename + `internal: true` | D-10 |
| `taskfiles/identity.yml` | sub-target | `identity:ssh` | `identity:install-ssh` | rename + `internal: true` | D-10 |
| `taskfiles/identity.yml` | sub-target | `identity:one-password-agent` | `identity:install-one-password-agent` | rename + `internal: true` | D-10, D-11 |
| `taskfiles/identity.yml` | validate | `identity:validate` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/macos.yml` | sub-target | `macos:defaults` | `macos:apply-defaults` | rename + `internal: true` | D-10 |
| `taskfiles/macos.yml` | sub-target | `macos:shell` | `macos:install-shell` | rename + `internal: true` | D-10 |
| `taskfiles/macos.yml` | aggregator | (none) | `macos:install` (NEW) + `internal: true` | create | D-09 |
| `taskfiles/macos.yml` | validate | `macos:validate` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/packages.yml` | aggregator | `packages:install` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/packages.yml` | diagnostic | `packages:audit` | `audit:packages` | rename (move to audit:) | D-02 |
| `taskfiles/packages.yml` | compose | `packages:compose` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/packages.yml` | verify | `packages:verify` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/packages.yml` | validate | `packages:validate` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/claude.yml` | aggregator | `claude:install` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/claude.yml` | diagnostic | `claude:status` | `show:claude` | rename (move to show:) | D-02 |
| `taskfiles/claude.yml` | refresh | `claude:update` | `refresh:claude` | rename (move to refresh:) | D-03 |
| `taskfiles/claude.yml` | validate | `claude:validate` | (keep name) + `internal: true` | mark-internal | D-01 |
| `taskfiles/manifest.yml` | diagnostic | `manifest:show` | `show:manifest` | rename (move to show:) | D-02 |
| `taskfiles/manifest.yml` | validate | `manifest:validate` | (keep) + `internal: true` + NEW public `audit:manifest` | mark-internal + dual-shape | D-01, D-03 |
| `taskfiles/manifest.yml` | resolve | `manifest:resolve` | (keep) + `internal: true` | mark-internal | D-01, Claude's-Discretion |
| `taskfiles/manifest.yml` | setup | `manifest:setup` | (keep) + `internal: true` | mark-internal | D-01 |
| `taskfiles/manifest.yml` | test | `manifest:test` | `test:manifest` | rename (move to test:) + `internal: true` | D-04 + Claude's-Discretion |
| `taskfiles/manifest.yml` | test | `manifest:test:add-machine` | `test:add-machine` | rename + `internal: true` | D-04 + Claude's-Discretion |
| `taskfiles/shell.yml` | gate | `shell:shell` (and the `perf:shell` alias) | `shell:startup-time` | rename | D-06 |
| `taskfiles/shell.yml` | validate | `shell:validate` | (keep) + `internal: true` | mark-internal | D-01 |
| `taskfiles/lint.yml` | aggregator | `lint:default` (alias `lint`) | (keep) | keep-as-is | D-04 |
| `taskfiles/lint.yml` | sub-check | `lint:syntax` | (keep name) + `internal: true` | mark-internal | D-04 |
| `taskfiles/lint.yml` | sub-check | `lint:taskfile` | (keep name) + `internal: true` | mark-internal | D-04 |
| `taskfiles/lint.yml` | sub-check | `lint:shell-headers` | (keep name) + `internal: true` | mark-internal | D-04 |
| `taskfiles/lint.yml` | sub-check | `lint:portability` | (keep name) + `internal: true` | mark-internal | D-04 |
| `taskfiles/lint.yml` | sub-check | `lint:test-fixtures` | (keep name) + `internal: true` | mark-internal | D-04 |
| `taskfiles/lint.yml` | sub-check (NEW) | (none) | `lint:banner-parity` + `internal: true` | create | D-13 |
| `taskfiles/test.yml` | aggregator | `test:default` | (keep) + `internal: true` | mark-internal | D-04 |
| `taskfiles/test.yml` | sub-check | `test:hooks` | (keep) + `internal: true` | mark-internal | D-04 |
| `taskfiles/helpers.yml` | helpers | all already `internal: true` | (no change) | n/a | -- |
| `Taskfile.yml` | includes block | `perf:` alias line:82 | DROP | drop alias | D-05 |
| `Taskfile.yml` | top-level | `default:` (lines 120-127) | rewrite cmds block to D-12 two-tier banner | edit | D-12 |
| `Taskfile.yml` | install pipeline | `task: macos:defaults` + `task: macos:shell` (235-239) | optionally collapse to `task: macos:install` | edit | D-09 (recommendation) |
| `Taskfile.yml` | install pipeline | every `task: <ns>:install` callee | update names in lockstep with the rename of the callee | edit | D-04 callers-first |
| `Taskfile.yml` | validate aggregator | iteration list at 206, 213 (manifest identity links macos packages claude shell) | unchanged | keep-as-is | D-01 |

### Edit targets -- doc-reference updates (SURF-02 callsite map)

See `## Doc-Reference Map (SURF-02 / D-15)` section below for the per-file `path:line` references the planner must update in lockstep with the task renames.

---

## Pattern Assignments

### 1. SURFACE.md classification table (D-14)

**Analog:** `.planning/phases/09-v1-drop-audit/09-01-PLAN.md:108-160` -- the Plan 09-01 skeleton task that locks AUDIT.md's six-column shape. SURFACE.md adopts the same shape; only the column NAMES change (per D-14).

**Column-header pattern (the row planner writes verbatim into SURFACE.md):**

```markdown
| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
```

**Verdict-enum lock (D-14):** verdict column values are exactly one of: `keep-as-is`, `rename`, `mark-internal`, `remove`. Combined verdicts (e.g., `rename + mark-internal`) write both verbs separated by ` + `.

**Sample row (using `links:all` -> `links:install` rename as worked example):**

```markdown
| `links:all` | rename + mark-internal | `links:install` | yes | D-09 aggregator pattern; D-01 per-component install is internal | Taskfile.yml:235; taskfiles/identity.yml (via :links:reconcile callers? none); taskfiles/README.md:23 |
```

**House-style cross-reference (mirror AUDIT.md):**

- Top of SURFACE.md carries a `## Summary` section with (a) counts table (Tasks audited / keep-as-is / rename / mark-internal / remove) and (b) a Keep-As-Is / Rename / Mark-Internal bullet list (the planner's iteration queue) -- see `.planning/phases/09-v1-drop-audit/AUDIT.md`'s `## Summary` shape that 09-01-PLAN.md:117-131 establishes.
- One row per public task in today's `task --list` output (44 visible entries; planner may also list internals already in helpers.yml for completeness per D-14).
- House-style markdown: no emojis; backticks around code/task names; one decision ref per row in the rationale column (`D-NN` format).
- Section headers use `## <Category>` (e.g., `## Top-Level Commands`, `## links:`, `## identity:`, ... `## Diagnostics (show:/audit:/refresh:)`); planner chooses sectioning per D-14's "house style mirrors Phase 9's AUDIT.md".

**What to mirror:** six-column shape; Summary counts table; one-row-per-discrete-unit granularity; explicit `D-NN` citations in rationale.
**What's different:** column NAMES differ (Phase 9 had `file:line | purpose | v2 status | keep/drop | rationale | v2 owner`; Phase 12 has `task name (current) | verdict | new name | internal: true? | rationale | callsites to update`). The verdict column carries four values vs Phase 9's two.

---

### 2. `internal: true` task definition

**Analogs (already in v2):**

- `taskfiles/helpers.yml:30-42` -- `safe-link` (the entire file is internal-by-convention).
- `taskfiles/links.yml:177-196` -- `zdotdir` (the cleanest single-task example; was renamed to internal in Phase 10 PORT-01).
- `taskfiles/macos.yml:142-154` -- `defaults:dock` (representative of the 5-concern set).
- `taskfiles/claude.yml:125-173` -- `marketplace` (a non-trivial internal task with status + cmds).
- `taskfiles/identity.yml:183-211` -- `server-include` (template-gated internal generator).

**Excerpt (the canonical `internal: true` task shape; `taskfiles/links.yml:177-196`):**

```yaml
  zdotdir:
    desc: "Configure ZDOTDIR in /etc/zshenv (sudo write, idempotent)"
    internal: true
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
        if [[ ! -f /etc/zshenv ]]; then
          info "Creating /etc/zshenv with ZDOTDIR export..."
          echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null
          success "ZDOTDIR configured in /etc/zshenv"
        elif ! grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
          # ...
        fi
    status:
      - grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null
```

**Placement rule (verified across all 5 analogs):** `internal: true` lives on the line immediately after `desc:` (or immediately after the task key when no `desc:` is present). No analog puts it later -- the canonical position is line 2 of the task block. The planner's mark-internal edit follows this placement.

**Status:** none of the renames in D-09/D-10 alter the existing `status:` block of the renamed task -- LINT-01 stays green. The mark-internal pass is purely the addition of one line per task.

---

### 3. Aggregator pattern (`<ns>:install`)

**Analogs (three current aggregators):**

- `Taskfile.yml:227-265` -- root `install:` (the canonical pipeline; D-12 banner check references its top-level desc).
- `taskfiles/identity.yml:111-117` -- `identity:install` (smallest aggregator; identity:git + identity:ssh + identity:one-password-agent).
- `taskfiles/links.yml:120-131` -- `links:all` (-> will become `links:install` per D-09).

**Excerpt (the cleanest current aggregator -- `taskfiles/identity.yml:110-117`):**

```yaml
  # lint-allow: cmds-without-status
  install:
    desc: "Install identity layer (git + ssh)"
    deps: [":manifest:resolve"]
    cmds:
      - task: git
      - task: ssh
      - task: one-password-agent
```

**Aggregator-pattern fingerprint (LINT-03a-aware):**

1. `# lint-allow: cmds-without-status` marker on the line immediately above the task key (lint exemption: aggregators with only `task:` delegations are auto-exempt per `taskfiles/lint.yml:186-194`, but the marker is documentation).
2. `desc:` one-liner.
3. `deps: [":manifest:resolve"]` when the aggregator's sub-tasks read `resolved.json` (leading-colon absolute form -- bare `manifest:resolve` does NOT work when this taskfile is loaded as a namespaced include; see comment at `taskfiles/links.yml:124-128`).
4. `cmds:` list of `- task: <sub-target>` entries.
5. NO `status:` block (aggregator idempotency lives in sub-tasks per the convention documented at `taskfiles/links.yml:25-30`).

**For the new `macos:install` aggregator (D-09):**

```yaml
  # lint-allow: cmds-without-status
  install:
    desc: "Apply macOS defaults + register Homebrew zsh as login shell"
    internal: true
    platforms: [darwin]
    deps: [":manifest:resolve"]
    cmds:
      - task: apply-defaults
      - task: install-shell
```

Three structural notes for the planner: (a) `internal: true` per D-01 because the aggregator is per-component; (b) `platforms: [darwin]` mirrors the existing `macos:defaults` and `macos:shell` (`taskfiles/macos.yml:122, 224`); (c) sub-task names are the post-D-10 renames (`apply-defaults`, `install-shell`).

**What to mirror:** the five-element fingerprint above.
**What's different:** the new `macos:install` is the FIRST aggregator inside `taskfiles/macos.yml`; all five existing tasks (`defaults`, `defaults:dock` + 4 concerns, `shell`, `validate`) are sub-targets.

---

### 4. Sub-target with `status:` block (D-10 verb-first renames)

**Analog (the cleanest sub-target shape):** `taskfiles/links.yml:137-157` -- `links:zsh` (renamed to `links:install-zsh`).

**Current shape (before rename, `taskfiles/links.yml:137-157`):**

```yaml
  zsh:
    desc: "Link zsh configuration files and configure /etc/zshenv ZDOTDIR"
    cmds:
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zprofile", TARGET: "{{.ZDOTDIR}}/.zprofile" }
      # ... 3 more _:safe-link calls ...
      - task: zdotdir
    status:
      - test -L "{{.ZDOTDIR}}/.zshenv"
      - test -L "{{.ZDOTDIR}}/.zprofile"
      - test -L "{{.ZDOTDIR}}/.zshrc"
      - test -L "{{.ZDOTDIR}}/.zlogin"
      - test -L "{{.ZDOTDIR}}/.zlogout"
      - grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null
```

**Post-rename shape (D-10 verb-first + D-01 internal):**

```yaml
  install-zsh:
    desc: "Link zsh configuration files and configure /etc/zshenv ZDOTDIR"
    internal: true
    cmds:
      - task: _:safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
      # ... unchanged ...
      - task: zdotdir
    status:
      # ... unchanged ...
```

**Critical edits in the rename pass (verified against `links:zsh` shape):**

1. Task key changes from `zsh:` to `install-zsh:` (one line).
2. Add `internal: true` immediately after `desc:` (one line).
3. The `status:` block does NOT change -- the existing status: assertions are mechanical (test -L / grep -qF) and reference paths, not task names.
4. The `cmds:` block does NOT change unless it dispatches via `task: zdotdir` (internal sibling) -- in which case the inner `task:` ref stays unchanged (siblings inside the same taskfile resolve by short name, no namespace prefix).
5. The internal `zdotdir` task at lines 177-196 stays put -- its name is already discoverable as `links:zdotdir` but is already `internal: true`, so the rename pass leaves it alone.

**Worked rename examples (planner reference for the per-rename touch shape):**

| Before | After | Touch |
|---|---|---|
| `links:zsh` | `links:install-zsh` | key + `internal: true` |
| `links:claude` | `links:install-claude` | key + `internal: true` |
| `links:configs` | `links:install-configs` | key + `internal: true` |
| `identity:git` | `identity:install-git` | key + `internal: true` (NB: also called as `git` from siblings -- update sibling cmd refs) |
| `identity:ssh` | `identity:install-ssh` | same |
| `identity:one-password-agent` | `identity:install-one-password-agent` | same; LONGEST renamed name at 32 chars (D-11 acceptable cost) |
| `macos:defaults` | `macos:apply-defaults` | key + `internal: true` (NB: callers in `Taskfile.yml:238` and `macos:defaults` aggregator's `task: defaults:dock` style -- the sub-targets `defaults:dock` etc. ARE under a `defaults:` sub-namespace, NOT renamed) |
| `macos:shell` | `macos:install-shell` | key + `internal: true` (caller: `Taskfile.yml:239`) |
| `manifest:show` | `show:manifest` (D-02 namespace move) | key changes namespace -- this is NOT a sibling rename; planner moves the entire task definition OR aliases via go-task includes |

**Special case -- `manifest:test:add-machine` -> `test:add-machine`:** the go-task colon-in-task-name syntax already nests `manifest:test:add-machine` under the `manifest:` include's `test:` sub-prefix. Move requires either (a) defining the task in `taskfiles/test.yml` instead, or (b) renaming within `taskfiles/manifest.yml` and adjusting the include in root Taskfile.yml. Planner picks; recommendation is (a) since the task is logically test-suite content.

---

### 5. `default:` banner cmd-block (D-12)

**Current shape (`Taskfile.yml:119-127`):**

```yaml
  # lint-allow: cmds-without-status
  default:
    desc: "List available tasks"
    # status: [false] forces the cmd to run every invocation. With status:
    # [true] the task is considered up-to-date and skipped, so `task` alone
    # would print nothing instead of listing tasks.
    status: [false]
    cmds:
      - task --list
```

**Post-D-12 shape (the planner writes the actual echo block; this is the structural fingerprint):**

```yaml
  # lint-allow: cmds-without-status
  default:
    desc: "Print curated task surface"
    status: [false]
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        header "Dotfiles -- common tasks"
        echo
        info "  install     Install dotfiles for the active machine"
        info "  setup       Set the active machine: task setup -- <machine-name>"
        info "  validate    Validate full installation state"
        info "  test        Run all smoke tests"
        info "  lint        Run all lint checks"
        echo
        header "Diagnostics"
        info "  task show:*      Inspect current state (manifest, claude)"
        info "  task audit:*     Detect drift (manifest, packages, links)"
        info "  task refresh:*   Manually refresh a layer (claude)"
        echo
        echo "Run 'task --list' for the full task graph."
```

**messages.zsh helper cross-reference (from `install/messages.zsh` + existing call sites):**

- `header "Section Name"` -- prints styled `── Section Name ──` header (`install/messages.zsh:55-58`).
- `info "..."` -- prints `[INFO] ...` in blue (`install/messages.zsh:34-36`).
- `success "..."` -- prints `[SUCCESS] ...` in green (`install/messages.zsh:38-40`).
- `check "..."` -- prints `✓ ...` in green (`install/messages.zsh:64-66`).

**Existing call-site for visual-consistency reference (`Taskfile.yml:212-223`, the `validate:` summary block):**

```bash
header "Validation Summary"
for component in manifest identity links macos packages claude shell; do
  eval "rc=\$rc_${component}"
  if grep -q "feature disabled -- skipped" "${cache_dir}/${component}"; then
    info "n/a   ${component}"
  elif [ "$rc" -eq 0 ]; then
    check "${component}"
  else
    cross "${component}"
    failures=$(( failures + 1 ))
  fi
done
```

**Critical rule (matches `Taskfile.yml:193, 264`):** the banner cmd-block must source messages.zsh via `source '{{.TASKFILE_DIR}}/install/messages.zsh'` directly (NOT `{{.DOTFILES_MESSAGES}}`), per the documented "DOTFILEDIR pollution" workaround comment at `Taskfile.yml:186-192`. Planner may also use `{{.DOTFILES_MESSAGES}}` -- both currently work in the root file's task scope; the `TASKFILE_DIR` form is more defensive against the include-merge pollution called out in that comment block.

**What to mirror:** `header`/`info`/`echo` interleaving for the two-tier visual hierarchy; the `validate:` summary pattern's `header "<Title>"` shape.
**What's different:** the cmd-block grows from 1 line (`task --list`) to a multi-line heredoc; `status: [false]` stays (the banner must re-render every invocation).

---

### 6. Lint-fixture pattern (D-13 banner-parity check)

**Analog rule (LINT-02 is the cleanest example):** `taskfiles/lint.yml:128-201` -- the `taskfile:` task body.

**LINT-02 rule excerpt (`taskfiles/lint.yml:140-155`):**

```yaml
        # --- LINT-02: $VAR-style shell variables inside status: blocks ---
        # The macos:shell:145 bug class: $BREW_ZSH is unset in status eval context
        # so the check always fails and the task always re-runs.
        while IFS= read -r f; do
          out=$(yq '.tasks[] | select(.status) | .status' "$f" 2>/dev/null \
                | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
                | ggrep -vE '\$\(' \
                | ggrep -vE '\{\{' || true)
          if [[ -n "$out" ]]; then
            cross "LINT-02: \$VAR in status: block -- $f"
            echo "$out" >&2
            failures=$(( failures + 1 ))
          else
            check "LINT-02: $f"
          fi
        done < <(find {{.DOTFILEDIR}}/taskfiles -maxdepth 1 -name '*.yml' | sort)
```

**Rule-shape fingerprint (mirror for D-13 `lint:banner-parity`):**

1. `while IFS= read -r f; do ... done < <(find ...)` iteration when the check operates on every taskfile (D-13 only needs `Taskfile.yml`, so the iteration may be a single-file check).
2. `yq` extracts the structure to check; `ggrep` filters; failure case: `cross "LINT-NN: <message>"` + `failures=$(( failures + 1 ))`.
3. Success case: `check "LINT-NN: <name>"`.
4. Final line: `exit "$failures"`.

**D-13 banner-parity check sketch (one possible shape; planner picks the exact grep pipeline):**

```bash
        # --- LINT-NN: banner parity check ---
        # The `default:` task's cmd block must list every non-internal
        # top-level task (no `:` in the name). Drift detection:
        # diff yq-extracted task list against the banner cmd text.
        public_top_tasks=$(yq '.tasks | to_entries | .[] | select(.value.internal // false | not) | .key | select(test("^[^:]+$"))' "$ROOT_TASKFILE")
        banner_body=$(yq '.tasks.default.cmds[0]' "$ROOT_TASKFILE")
        for task_name in $public_top_tasks; do
          if ! echo "$banner_body" | grep -qF "$task_name"; then
            cross "LINT-NN: 'task $task_name' is public but missing from default:'s banner -- update Taskfile.yml"
            failures=$(( failures + 1 ))
          else
            check "LINT-NN: $task_name in banner"
          fi
        done
```

**Failure-message style (matches `taskfiles/lint.yml:149, 164, 196` shape):** `<RULE>: <action-hint> -- <location>`. The CONTEXT.md `<specifics>` line 180 names the exact form: `"lint: 'task <name>' is public but missing from default:'s banner -- update the banner in Taskfile.yml"`.

**Fixture pair (positive + negative; mirrors LINT-02's 02a/02b pair):**

Positive (lint-fixture detects banner drift -- expect: `fail`):
```
taskfiles/test/lint-fixtures/13-banner-parity-fail/
├── Taskfile.yml    # defines a top-level public task NOT mentioned in default:'s cmd block
└── expect          # contains: fail
```

Negative (banner is in parity -- expect: `pass`):
```
taskfiles/test/lint-fixtures/13-banner-parity-ok/
├── Taskfile.yml    # every public top-level task is named in default:'s cmd block
└── expect          # contains: pass
```

**Fixture-file analog -- `taskfiles/test/lint-fixtures/02a-shell-var-in-status/Taskfile.yml`:**

```yaml
version: '3'

# =============================================================================
# taskfiles/test/lint-fixtures/<NN>-<slug>/Taskfile.yml
#
# Positive fixture for LINT-<NN>: <one-line description of the failure case>.
#
# Expected outcome: LINT-<NN> fires (expect: fail)
# =============================================================================

tasks:
  fixture-task:
    desc: "fixture: <one-line>"
    status:
      - test -f "$XDG_CONFIG_HOME/dotfiles/marker"
    cmds:
      - echo run
```

**Fixture file naming (verified against `taskfiles/test/lint-fixtures/` listing):** directory name is `<NN><variant>-<slug>` (e.g., `02a-shell-var-in-status`, `02b-template-var-in-status`, `02c-command-substitution-in-status`, `03a-cmds-no-status`, `03a-internal-no-status-ok`, `03b-bare-ln`, `03b-helpers-allowed`). The new banner-parity fixtures pick an unused LINT-NN number (planner picks; LINT-08 is deprecated per `taskfiles/lint.yml:15-17`, so LINT-08 or LINT-09 is available).

**Self-test runner extension:** the `test-fixtures:` task at `taskfiles/lint.yml:266-351` has a `case "$name" in` switch with one branch per LINT rule. The planner adds a new branch matching the chosen fixture-directory glob (e.g., `08*) ... ;;` if banner-parity is named LINT-08).

**What to mirror:** rule-body fingerprint (4 elements above) + paired positive/negative fixture shape + case-switch extension in `test-fixtures:`.
**What's different:** the new check reads `Taskfile.yml` only (not every taskfile in the glob) because `default:` only lives at the root.

---

### 7. `task install` pipeline body (D-09 / D-04 callers-first)

**Current shape (`Taskfile.yml:227-265`):**

```yaml
  # lint-allow: cmds-without-status
  install:
    desc: "Install dotfiles for active machine (canonical entry)"
    summary: |
      task install IS task update -- there is no separate update pipeline.
      Re-running is a no-op (every subtask has a status: block per LINT-01).
    status: [false]
    deps: [manifest:resolve]
    cmds:
      - task: links:all
      - task: packages:install
      - task: claude:install
      - task: macos:defaults
      - task: macos:shell
      - task: packages:verify
      - task: links:reconcile
        vars: { CLI_ARGS: "--warn-only" }
      - |
        # ... messages.zsh source + success line ...
```

**Post-D-09 (recommended; collapses macos:defaults + macos:shell into macos:install):**

```yaml
    cmds:
      - task: links:install         # was: links:all (D-09)
      - task: packages:install      # unchanged (already canonical)
      - task: claude:install        # unchanged (already canonical)
      - task: macos:install         # NEW aggregator (D-09); replaces lines 238-239
      - task: packages:verify       # unchanged
      - task: audit:links           # was: links:reconcile (D-02 rename)
        vars: { CLI_ARGS: "--warn-only" }
```

**Post-D-09 (alternative; keep two macos calls, planner's discretion):**

```yaml
    cmds:
      - task: links:install         # was: links:all
      - task: packages:install
      - task: claude:install
      - task: macos:apply-defaults  # was: macos:defaults (D-10)
      - task: macos:install-shell   # was: macos:shell (D-10)
      - task: packages:verify
      - task: audit:links           # was: links:reconcile
        vars: { CLI_ARGS: "--warn-only" }
```

**D-04 callers-first ordering:** every `task: <ns>:<name>` line in this cmd block MUST be updated BEFORE OR IN THE SAME COMMIT AS the rename of the callee. Per Phase 11 D-04 precedent: callers simplified first so that intermediate commits still leave the tree green (`task lint` passes, `task --list` succeeds).

**`status: [false]` and `deps: [manifest:resolve]` stay unchanged** -- they reference `manifest:resolve` which D-01 marks internal, but per CONTEXT.md `<code_context>` the `internal:` flag only affects `task --list` visibility, not invocability. The `deps:` continues to work.

---

### 8. Validate-aggregator iteration loop (Taskfile.yml:206, 213)

**Excerpt (`Taskfile.yml:206-213`):**

```bash
        for component in manifest identity links macos packages claude shell; do
          task "${component}:validate" 2>&1 | tee "${cache_dir}/${component}"
          eval "rc_${component}=\${PIPESTATUS[0]}"
        done
        header "Validation Summary"
        for component in manifest identity links macos packages claude shell; do
          eval "rc=\$rc_${component}"
          if grep -q "feature disabled -- skipped" "${cache_dir}/${component}"; then
```

**D-01 cross-verification:** after `<ns>:validate` tasks are marked `internal: true`, the loop continues to work because:

1. go-task's `internal: true` only hides the task from `task --list` (verified at `taskfiles/lint.yml:95` comment: "Exit-1 with empty task list (all internal: true) is NOT a parse error").
2. The loop invokes `task <ns>:validate` programmatically; internal tasks remain callable by name.
3. No edit to this loop is required as part of Phase 12. The aggregator's iteration list (`manifest identity links macos packages claude shell`) remains unchanged.

**What to mirror:** nothing -- this loop is the documented integration point that proves the D-01 internal-mark is safe.

---

### 9. Doc-reference targets (SURF-02 / D-15 callsite map)

The `callsites to update` column in SURFACE.md (D-15) is pre-populated from the grep output below. Per the CONTEXT.md `<canonical_refs>` "Doc references" subsection plus a fresh `grep -nE 'task [a-z][a-z0-9:-]+'` over operator docs:

| File | Line(s) | Reference | Action |
|---|---|---|---|
| `README.md` | 26-27, 33 | `task setup`, `task install` | Stay correct (top-level commands unchanged) |
| `README.md` | 46, 49 | table rows with `task setup` | Stay correct |
| `CLAUDE.md` | 116, 119 | table rows with `task setup` | Stay correct |
| `.claude/CLAUDE.md` | 15-16 | `task install`, `task validate` | Stay correct |
| `.claude/CLAUDE.md` | 18 | `task setup -- <machine-name>` | Stay correct |
| `.claude/CLAUDE.md` | 19 | `task manifest:resolve` | Update or drop -- D-01/Claude's-Discretion marks `manifest:resolve` internal; either drop the bullet or rewrite to `task <new-public-name>` if planner adds a public delegate |
| `.claude/CLAUDE.md` | 20 | `task manifest:show` | Update to `task show:manifest` (D-02) |
| `docs/MANIFEST.md` | 351-352, 360, 379 | `task packages:verify`, `task packages:install` | Stay correct if these go internal (mark-internal only hides from --list); planner may rewrite to reference `task install` instead since `packages:verify` runs inside the install pipeline |
| `docs/MANIFEST.md` | 418 | `task install` | Stay correct |
| `docs/MANIFEST.md` | 468-472 | manifest task surface table | Update per row: `task setup --` stays; `task manifest:resolve` -> drop or rewrite (internal); `task manifest:show` -> `task show:manifest`; `task manifest:validate` -> `task audit:manifest` (D-03 public delegate) OR drop (internal); `task manifest:test` -> `task test:manifest` (Claude's-Discretion to move to test:) |
| `docs/SECURITY.md` | 138 | `task lint` | Stay correct |
| `docs/MACHINES.md` | 67 | `task macos:defaults` | Update to `task macos:apply-defaults` (D-10) OR drop the reference if surfacing the internal name is undesirable -- CONTEXT explicitly notes planner picks |
| `shell/README.md` | 43 | `task perf:shell` | Update to `task shell:startup-time` (D-06/D-07) |
| `taskfiles/README.md` | 23-26, 46 | `task perf:shell`, `task shell:validate` | Rewrite the entire `## Key files` Phase-3 bullet: `task perf:shell` -> `task shell:startup-time`; `task shell:validate` -> mention-as-internal or drop (D-01) |

**Grep primitive (D-15 callsite-finder per CONTEXT.md `<code_context>`):**

```bash
git grep -nE '\btask [a-z][a-z0-9:-]+' README.md CLAUDE.md .claude/CLAUDE.md docs/ shell/README.md taskfiles/README.md
```

The grep output is the input to D-15 -- planner runs it per renamed task and pastes the resulting `path:line` list into the SURFACE.md `callsites to update` column.

**SHEL-12 reference migration (D-07):** the only in-repo SHEL-12 references are: `Taskfile.yml:82` (drop the `perf:` alias line), `taskfiles/README.md:24, 46` (rewrite to `task shell:startup-time`), `taskfiles/shell.yml:12` (header comment), `shell/README.md:43` (hyperfine invocation note). Confirmed: no `.github/workflows/` exists in this repo.

---

### 10. Identity overlay (Phase 11 cross-check)

**CONTEXT.md `<canonical_refs>` line 94 claim:** "`taskfiles/identity.yml` -- contains `identity:install`, `identity:git`, `identity:ssh`, `identity:one-password-agent`, `identity:validate`."

**Verified against on-disk taskfiles/identity.yml:**

- `identity:install` -- lines 110-117 (aggregator).
- `identity:git` -- lines 127-173 (sub-target with status block).
- `identity:server-include` -- lines 183-211 (internal, generator; ALREADY `internal: true`).
- `identity:ssh` -- lines 220-279 (sub-target with status block).
- `identity:one-password-agent` -- lines 289-295 (sub-target with status block; NOT currently internal).
- `identity:validate` -- lines 306-312 (aggregator; cmds: are all task: delegations to four internal validators).
- `identity:validate:symlinks`, `:one-password-agent`, `:git`, `:ssh-add`, `:keys` -- lines 316-471 (already `internal: true`).

**Status-block excerpt from `identity:git` (lines 164-173) -- the structural shape that survives the rename to `identity:install-git`:**

```yaml
    status:
      - test -L "{{.GIT_CONFIG_DIR}}/config"
      - test -L "{{.GIT_CONFIG_DIR}}/ignore"
      # Per-identity symlink presence is checked by iterating the source dir;
      # a missing target for any overlay file triggers a re-run.
      - |
        for f in "{{.DOTFILEDIR}}/identity/git/identities/"*; do
          [[ -e "$f" ]] || continue
          test -L "{{.GIT_CONFIG_DIR}}/identities/$(basename "$f")" || exit 1
        done
```

**Internal-set after Phase 12 rename pass (identity.yml):** all five aggregator/sub-target tasks (`install`, `install-git`, `install-ssh`, `install-one-password-agent`, `validate`) gain `internal: true`. The five `validate:<sub>` internals already are internal -- no change. `server-include` already internal -- no change. Net result: `task --list` shows ZERO `identity:*` rows after the phase lands.

---

## Shared Patterns

### A. Status-block template-var rule (LINT-02 hardening)

**Source:** `CLAUDE.md` (project root) §"Rules" -- LINT-02; `taskfiles/lint.yml:140-155`.
**Apply to:** every renamed task -- the rename pass MUST NOT introduce new `$VAR` references inside `status:` blocks. The existing status blocks on every renamed task already use `{{.X}}` template vars (LINT-02 enforces this at every commit). The rename only changes the task key + adds `internal: true`; status: bodies are unchanged.

### B. Aggregator vs sub-task LINT-03a marker

**Source:** `taskfiles/lint.yml:171-194` rule + the in-tree convention documented at `taskfiles/links.yml:25-30`.
**Apply to:** every aggregator (`<ns>:install`, root `install:`, `default:`, `validate:`, `test:`, `lint:default`). Either (a) carry `# lint-allow: cmds-without-status` on the line immediately above the task key, OR (b) have all `cmds:` be `task:` delegations (LINT-03a auto-exempt). The new `macos:install` aggregator gets the marker.

### C. File-header banner (every taskfile)

**Source:** consistent across all v2 taskfiles (e.g., `taskfiles/links.yml:1-39`, `taskfiles/identity.yml:1-44`, `taskfiles/macos.yml:1-48`).
**Apply to:** any taskfile that loses or gains tasks during Phase 12 -- update the banner's role / surface listing. Specifically:

- `taskfiles/macos.yml:1-48` -- add the new `macos:install` aggregator to the "Tasks" comment block.
- `taskfiles/shell.yml:1-28` -- rewrite the "Tasks" listing (line 10-13) post `perf:shell` -> `shell:startup-time` rename and post-`shell:validate` mark-internal.
- `taskfiles/links.yml:7-15` -- the "currently included" block mentioning `links:all` aggregator extension; update for `links:install` and the `links:reconcile` -> `audit:links` move.
- `taskfiles/lint.yml:25-32` -- the Callable-as listing; update with the new `lint:banner-parity` row and the mark-internal flag on every sub-check.
- `taskfiles/test.yml:12-15` -- "Callable as" block; mark `test:default` / `test:hooks` internal-only; reflect any test:manifest / test:add-machine additions.

### D. Leading-colon absolute-task ref

**Source:** documented at `taskfiles/links.yml:124-128` + `taskfiles/identity.yml:36-40` + `taskfiles/macos.yml` deps.
**Apply to:** every cross-namespace `task:` call. Bare `task: <ns>:<name>` resolves relative to the current namespace when invoked through an include -- it tries `links:<ns>:<name>`. The leading-colon form `task: :<ns>:<name>` (or `deps: [":<ns>:<name>"]`) resolves absolute. Renames that change a target's namespace (e.g., `links:reconcile` -> `audit:links`) require the caller to update both the colon-prefix AND the new namespace.

### E. Green-tree-per-commit gate (Phase 10/11 inherited)

**Source:** Phase 11 PATTERNS.md `### Green-tree-per-commit gate` section -- `task lint:taskfile` is the pre-commit gate; `task --list` must continue to succeed.
**Apply to:** every commit in Phase 12. Per CONTEXT.md `<code_context>` line 144 "Phase 11 D-04's callers-first ordering: rename callers before renaming the callee (otherwise the rename breaks the call). Same pattern applies here." The lint suite (D-13 banner-parity included) runs on every commit; any drift fails immediately.

### F. Commit-message format (project + global CLAUDE.md)

**Source:** global CLAUDE.md `## Git` section + Phase 11 PATTERNS.md.
**Apply to:** every Phase 12 commit. Form: `<type>(<scope>): <summary>` < 75 chars, imperative mood. Types: `refactor` for renames, `feat` for new lint check + new `macos:install` aggregator, `docs` for SURFACE.md + README/CLAUDE.md updates, `chore` for the `perf:` include drop. Examples:

- `refactor(12): rename links:all -> links:install + mark internal`
- `refactor(12): rename identity sub-tasks to install-<target>`
- `refactor(12): rename macos:defaults -> macos:apply-defaults + macos:shell -> macos:install-shell`
- `feat(12): add macos:install aggregator`
- `refactor(12): move claude:status -> show:claude, claude:update -> refresh:claude`
- `feat(12): add lint:banner-parity check + fixtures`
- `docs(12): rewrite default: banner to two-tier curated surface`
- `docs(12): refresh task-name references in CLAUDE.md / docs / READMEs`

No AI-attribution trailers (project + global CLAUDE.md both forbid; hooks enforce at commit time).

---

## No Analog Found / Notable Absences

| Item | Reason | Disposition |
|------|--------|-------------|
| Existing `<ns>:install` aggregator inside `taskfiles/macos.yml` | macos.yml has no aggregator today -- only `defaults`, `defaults:<concern>` x5, `shell`, `validate` | D-09 creates `macos:install` from scratch using the identity.yml shape (Pattern 3) |
| Existing `audit:` namespace in the repo | None of `taskfiles/*.yml` declares an `audit:` namespace; `packages:audit` is the only `audit`-named task and lives inside `packages:` | Phase 12 creates `audit:` as a NEW logical namespace by renaming existing diagnostic tasks. No new taskfile is needed -- tasks stay in their owning files (e.g., `audit:packages` lives in `taskfiles/packages.yml`, `audit:links` in `taskfiles/links.yml`); they share the `audit:` prefix via the rename alone. Same for `show:` and `refresh:`. |
| Existing two-tier banner cmd-block | None -- the current `default:` is one line (`task --list`) | D-12 builds it from scratch using the `Taskfile.yml:212-223` validate-summary block as the closest visual analog |
| `lint:banner-parity` check | New per D-13 | Built using the LINT-02 fingerprint (Pattern 6) |

---

## Metadata

**Analog search scope:** `Taskfile.yml`, `taskfiles/*.yml`, `taskfiles/test/lint-fixtures/`, `install/messages.zsh`, `.planning/phases/09-v1-drop-audit/AUDIT.md` + `09-01-PLAN.md`, `.planning/phases/11-v1-removal/11-PATTERNS.md`, every doc named in CONTEXT.md `<canonical_refs>`.
**Files scanned:** 18 (14 read in full, 4 grepped for specific line citations).
**Pattern extraction date:** 2026-05-18.
