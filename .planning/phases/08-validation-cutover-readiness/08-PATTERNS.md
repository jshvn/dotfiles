# Phase 8: Validation + Cutover Readiness - Pattern Map

**Mapped:** 2026-05-16
**Files analyzed:** 8 target files (2 new tasks, 4 modified task files, 3 new docs, 1 doc replacement)
**Analogs found:** 8 / 8 (all have analogs; docs have structural analog in existing docs/)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `taskfiles/links.yml` (EXPECTED_TARGETS refactor) | orchestrator task | CRUD (symlink lifecycle) | `taskfiles/claude.yml install:` (inline-ternary pattern) | exact |
| `taskfiles/links.yml` (`links:validate` fix) | orchestrator task | request-response (diagnostic) | `taskfiles/macos.yml validate:` (failures-counter shell block) | exact |
| `taskfiles/links.yml` (`links:reconcile` new task) | orchestrator task | event-driven (detect/remove) | `taskfiles/packages.yml verify:` (failures-counter + enumerate-all) | role-match |
| `Taskfile.yml` (root `validate:` aggregator) | orchestrator task | request-response (composed aggregate) | `taskfiles/identity.yml validate:` (multi-task delegation) | exact |
| `Taskfile.yml` (`task install` + `links:reconcile` hook) | orchestrator task | CRUD (pipeline step) | `Taskfile.yml install:` lines 154-169 (existing pipeline) | exact |
| `Taskfile.yml` (`cutover:ack` task) | orchestrator task | file-I/O (sentinel write) | `taskfiles/manifest.yml setup:` (state-file writer with preconditions) | exact |
| `docs/CUTOVER.md` | doc | n/a | `docs/MANIFEST.md` (doc structure + heading style) | role-match |
| `docs/MIGRATION.md` | doc | n/a | `docs/MANIFEST.md` (H2 sections + tables) | role-match |
| `docs/MACHINES.md` | doc | n/a | `docs/MANIFEST.md` (thin doc, defers to source of truth) | role-match |
| `README.md` (root replacement) | doc | n/a | `taskfiles/README.md`, `install/README.md`, `shell/README.md` (sub-dir READMEs) | role-match |

---

## Pattern Assignments

### `taskfiles/links.yml` -- EXPECTED_TARGETS refactor (P1)

**Context:** D-08 requires retiring the 5 cmds-spanning `{{if}}...{{end}}` spots and the 2 bare
`manifest:resolve` deps. The refactor introduces a single `EXPECTED_TARGETS` var and rewrites
`links:validate` as a shell-block with a failures counter.

**Analog A: inline-ternary status gate** -- `taskfiles/links.yml` lines 161-174 (already present)

This is the CORRECT pattern. The `status:` lines below demonstrate it -- feature-off condition
renders `true` (no-op), feature-on condition renders the real test:

```yaml
# taskfiles/links.yml lines 161-174 -- inline-ternary status: pattern
status:
  - '{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md"{{end}}'
  - '{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/claude/settings.json"{{end}}'
```

**Anti-pattern (currently in links.yml cmds: blocks)** -- lines 133/160, 186/189, 234/261:

```yaml
# WRONG -- causes template: :1: unexpected EOF when feature is off
cmds:
  - '{{if index .MANIFEST.features "claude-marketplace"}}'
  - task: _:safe-link
    vars: { SOURCE: "...", TARGET: "..." }
  - '{{end}}'
```

**Analog B: deps flip from bare to root-namespace form** -- `taskfiles/identity.yml` validate: line 258 (confirmed pattern):

```yaml
# CORRECT form -- cross-taskfile dep uses leading colon
deps: [":manifest:resolve"]
```

vs. the two buggy bare refs in links.yml lines 131 and 184:

```yaml
# WRONG -- bare form only works if taskfile is top-level, breaks under includes:
deps: [manifest:resolve]
```

**EXPECTED_TARGETS var shape** -- new pattern, no exact analog, but mirrors the `DOTFILES_MESSAGES` multiline var:

```yaml
# taskfiles/links.yml vars: block -- add after existing vars
EXPECTED_TARGETS: |
  {{.ZDOTDIR}}/.zshenv
  {{.ZDOTDIR}}/.zprofile
  {{.ZDOTDIR}}/.zshrc
  {{.ZDOTDIR}}/.zlogin
  {{.ZDOTDIR}}/.zlogout
  {{.ZDOTDIR}}/.zsh_plugins.txt
  {{if index .MANIFEST.features "claude-marketplace"}}{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md{{end}}
  {{if index .MANIFEST.features "claude-marketplace"}}{{.XDG_CONFIG_HOME}}/claude/settings.json{{end}}
  ... (one line per owned symlink target)
```

Note: identity symlinks (`{{.GIT_CONFIG_DIR}}/config`, `{{.SSH_DIR}}/config`, etc.) are NOT in
EXPECTED_TARGETS -- they are owned by `taskfiles/identity.yml` and validated by `identity:validate`.
Including them here would create a cross-module boundary violation.

---

### `taskfiles/links.yml` -- `links:validate` rewrite (P1, part of EXPECTED_TARGETS refactor)

**Problem:** `_:check-link` always exits 0 (confirmed: `taskfiles/helpers.yml` lines 48-73 -- prints
`cross` but no `exit 1`). Current `links:validate` therefore always exits 0, so the root `task validate`
aggregator cannot detect links failures via exit code.

**Fix pattern:** Rewrite `links:validate` as a single shell block (like `macos:validate`) with an
inline failures counter. Stop delegating to `_:check-link` tasks; inline the check logic with
`exit "$failures"` at the end.

**Analog:** `taskfiles/macos.yml validate:` lines 254-305 -- the enumerate-all pattern with failures counter:

```yaml
# taskfiles/macos.yml lines 254-305
# lint-allow: cmds-without-status
validate:
  desc: "Validate macOS defaults match in-script expected values"
  platforms: [darwin]
  deps: [":manifest:resolve"]
  status: [false]
  cmds:
    - |
      DOTFILEDIR={{.DOTFILEDIR}} BREW_ZSH={{.HOMEBREW_PREFIX}}/bin/zsh zsh -c '
        set -euo pipefail
        : "${DOTFILES_MESSAGES_LOADED:=}"
        if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
          source "${DOTFILEDIR}/install/messages.zsh"
        fi

        failed=0

        # enumerate-all: no short-circuit; OR into failed flag
        source "${DOTFILEDIR}/os/defaults/dock.zsh"
        verify_dock || failed=1

        exit "$failed"
      '
```

**Adapt for links:validate:** Same shell-block structure; inline the symlink check logic per target
from EXPECTED_TARGETS; use `|| failed=$(( failed + 1 ))` per check; close with `exit "$failed"`.
The `status: [false]` + `# lint-allow: cmds-without-status` marker pair is required (diagnostic
always-rerun -- same as macos:validate).

**Alternate analog for the check logic:** `taskfiles/packages.yml verify:` lines 203-220 -- `failures` counter with `check`/`cross` output:

```yaml
# taskfiles/packages.yml lines 203-220 -- failures counter pattern
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    failures=0

    if brew bundle check --no-upgrade --file="{{.COMPOSED_BREWFILE}}" >/dev/null 2>&1; then
      check "Layer 1: all declared packages installed per brew bundle"
    else
      cross "Layer 1: brew bundle check FAILED"
      failures=$(( failures + 1 ))
    fi

    # ... more checks ...

    exit "$failures"
```

---

### `taskfiles/links.yml` -- `links:reconcile` new task (P3)

**Analog:** `taskfiles/packages.yml verify:` (enumerate-all shell block with failures exit) +
`taskfiles/claude.yml validate:` (feature-gate in shell, not as cmds-spanning template).

**Core shape to replicate:**

```yaml
# lint-allow: cmds-without-status
reconcile:
  desc: "Detect orphan symlinks (default: exit non-zero); -- --remove for interactive cleanup"
  deps: [":manifest:resolve"]
  status: [false]
  cmds:
    - |
      {{.DOTFILES_MESSAGES}}
      # Parse mode from CLI_ARGS
      # Default: detect-only (exit non-zero on orphans)
      # --remove: interactive TTY-gated (read -r REPLY per orphan)
      # --warn-only: swallow exit, emit via warn() [install-time call]
```

**TTY-gate pattern** (D-10) -- no existing analog in taskfiles; borrow from zsh convention:

```zsh
# D-10 TTY gate -- must appear at top of --remove mode body
if [[ ! -t 0 ]]; then
  error "links:reconcile --remove requires an interactive TTY; stdin is not a tty"
  exit 1
fi
```

**Mode-detection pattern** (CLI_ARGS parsing) -- analog: `taskfiles/manifest.yml show:` which
reads CLI_ARGS. The exact form in go-task:

```yaml
# Pass mode via CLI_ARGS: `task links:reconcile -- --remove`
# Inside the shell block, CLI_ARGS is available as {{.CLI_ARGS}}
# Use it early to set a mode variable before any other logic.
```

**Orphan detection loop** (D-09 algorithm from RESEARCH.md lines 178-208):

```zsh
# Shell block for orphan detection -- walks only EXPECTED_TARGETS parent dirs
dotfiledir="{{.DOTFILEDIR}}"
expected=()
while IFS= read -r line; do
  [[ -n "$line" ]] && expected+=("$line")
done <<< "{{.EXPECTED_TARGETS}}"

orphans=()
parent_dirs=()
for t in "${expected[@]}"; do
  parent_dirs+=("$(dirname "$t")")
done
parent_dirs=($(printf '%s\n' "${parent_dirs[@]}" | sort -u))

for dir in "${parent_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r lnk; do
    target="$(readlink -f "$lnk" 2>/dev/null || true)"
    [[ "$target" == "$dotfiledir"* ]] || continue
    found=0
    for e in "${expected[@]}"; do
      [[ "$lnk" == "$e" ]] && { found=1; break; }
    done
    (( found == 0 )) && orphans+=("$lnk")
  done < <(find "$dir" -maxdepth 2 -type l 2>/dev/null)
done
```

**Anti-pattern:** Do NOT put mode detection logic in a `status:` block referencing `$X` shell
variables. The `status: [false]` pattern (always-rerun) avoids this entirely. The task is
diagnostic; idempotency does not apply.

---

### `Taskfile.yml` -- root `validate:` aggregator (P2)

**Analog:** `taskfiles/identity.yml validate:` lines 278-285 (multi-task delegation aggregator):

```yaml
# taskfiles/identity.yml lines 278-285 -- aggregator pattern
# lint-allow: cmds-without-status
validate:
  desc: "Validate identity layer: symlinks, git config, ssh-add, keys/ contents"
  cmds:
    - task: validate:symlinks
    - task: validate:git
    - task: validate:ssh-add
    - task: validate:keys
```

**Key difference for root validate:** Must use `ignore_error: true` on each `task:` delegation
(D-04 run-all-aggregate), then add a final shell block for the summary table and exit code bubble.

**Pattern to implement:**

```yaml
# Taskfile.yml -- new root validate: task
# lint-allow: cmds-without-status
validate:
  desc: "Validate full installation state (all components; run-all-aggregate)"
  deps: [manifest:resolve]
  cmds:
    - task: manifest:validate
      ignore_error: true
    - task: identity:validate
      ignore_error: true
    - task: links:validate
      ignore_error: true
    - task: macos:validate
      ignore_error: true
    - task: packages:validate
      ignore_error: true
    - task: claude:validate
      ignore_error: true
    - |
      {{.DOTFILES_MESSAGES}}
      # Summary: re-run each component validate and accumulate failures counter.
      # Per-component validates are idempotent read-only checks; double-run cost is
      # negligible. This is D-05's "final shell cmd re-runs each component" approach.
      failures=0
      header "Validation Summary"
      task manifest:validate >/dev/null 2>&1 && check "manifest" || { cross "manifest"; failures=$(( failures + 1 )); }
      task identity:validate >/dev/null 2>&1 && check "identity" || { cross "identity"; failures=$(( failures + 1 )); }
      task links:validate    >/dev/null 2>&1 && check "links"    || { cross "links";    failures=$(( failures + 1 )); }
      task macos:validate    >/dev/null 2>&1 && check "macos"    || { cross "macos";    failures=$(( failures + 1 )); }
      task packages:validate >/dev/null 2>&1 && check "packages" || { cross "packages"; failures=$(( failures + 1 )); }
      task claude:validate   >/dev/null 2>&1 && check "claude"   || { cross "claude";   failures=$(( failures + 1 )); }
      exit "$failures"
```

**Note on `ignore_error: true` per entry:** RESEARCH.md flags this as assumption A1 (go-task 3.37
support not directly verified). If per-`task:` entry `ignore_error: true` is not supported, fall back
to shell-level: replace `task: manifest:validate` + `ignore_error: true` with a single shell
`cmd: task manifest:validate || true`. The final shell block already handles exit code tracking
independently either way.

**Ordering (Claude's discretion):** manifest first (keystone), then alphabetical: identity, links,
macos, packages, claude. D-06 feature-off components (e.g., claude when `claude-marketplace=false`)
are handled by each per-component validate internally -- the aggregator calls all six unconditionally.

**`# lint-allow: cmds-without-status` marker:** Required on the line immediately preceding the task
key. LINT-03a exempts aggregators whose cmds: are entirely `task:` delegations plus one shell block.
Analog: `taskfiles/identity.yml` line 278, `taskfiles/links.yml` line 76.

---

### `Taskfile.yml` -- install pipeline + `links:reconcile` warn-only hook (P3, D-11)

**Analog:** `Taskfile.yml install:` lines 154-169 (existing pipeline):

```yaml
# Taskfile.yml lines 154-169 -- current install pipeline
install:
  cmds:
    - task: links:all
    - task: packages:install
    - task: claude:install
    - task: macos:defaults
    - task: macos:shell
    - task: packages:verify    # <-- current last task call (line 165)
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"
```

**D-11 modification:** Insert `links:reconcile` (warn-only mode) between `packages:verify` and the
`success` shell line. The `--warn-only` flag is passed via `vars:` or `CLI_ARGS`:

```yaml
# Modified install: cmds block -- D-11 insertion point
    - task: packages:verify
    - task: links:reconcile    # CUTV-08: warn-only, always exits 0
      vars: { CLI_ARGS: "--warn-only" }
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"
```

**Note:** The `links:reconcile` task in `--warn-only` mode must swallow its non-zero exit internally
(the install pipeline does not use `ignore_error: true` on the overall `task install`). The mode flag
causes the task shell block to redirect non-zero into `warn()` output and `exit 0`.

---

### `Taskfile.yml` -- `cutover:ack` task (P3)

**Analog:** `taskfiles/manifest.yml setup:` lines 105-143 -- state-file writer with machine name
validation, `requires: vars:`, `env:` for CLI_ARGS safety, `preconditions:` for validation.

```yaml
# taskfiles/manifest.yml lines 105-143 -- state-file writer pattern
setup:
  desc: "Persist active machine selection: task setup -- <machine-name>"
  requires:
    vars: [CLI_ARGS]
  env:
    CLI_ARGS_ENV: '{{.CLI_ARGS}}'
  preconditions:
    - sh: |
        name="${CLI_ARGS_ENV}"
        [[ "$name" =~ ^[a-z0-9_][a-z0-9_-]*$ ]] || exit 1
        test -f "{{.MACHINES_DIR}}/${name}.toml"
      msg: |
        invalid or unknown machine: "{{.CLI_ARGS}}"
          available: {{.AVAILABLE_MACHINES}}
  cmds:
    - mkdir -p "{{.STATE_DIR}}"
    - printf '%s' "${CLI_ARGS_ENV}" > "{{.STATE_FILE}}"
    - |
      {{.DOTFILES_MESSAGES}}
      success "Machine set to: ${CLI_ARGS_ENV}"
```

**Adapt for `cutover:ack`:** Same `env:` + `requires:` shape. Precondition validates that the
CLI_ARGS machine name matches the active machine in `$XDG_STATE_HOME/dotfiles/machine` (using the
logic from `install/cutover-gate.zsh` lines 35-39 as a reference). The write target is
`$XDG_STATE_HOME/dotfiles/cutover-ack` with content `<machine-name> <ISO-timestamp>`.

**Critical idiom (Pitfall 7 from RESEARCH.md):** `cutover:ack` must NOT have the install-gate
precondition that `task install` has. It must be standalone -- the gate reader in `cutover-gate.zsh`
reads the file that `cutover:ack` writes; these must not form a circular dependency.

**Timestamp format:**

```zsh
# ISO-8601 timestamp without external tools
printf '%s' "${CLI_ARGS_ENV} $(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "{{.XDG_STATE_HOME}}/dotfiles/cutover-ack"
```

**No `status:` block:** `cutover:ack` is a one-shot writer that should always re-run when explicitly
called. Use `status: [false]` + `# lint-allow: cmds-without-status`. Analog: `packages:verify` at
`taskfiles/packages.yml` line 201 uses the same always-rerun shape.

**Placement:** In root `Taskfile.yml` directly (not a new `taskfiles/cutover.yml`). Per RESEARCH.md
recommendation: a one-task module is needless overhead; keep it with the other lifecycle tasks.
This requires no new `includes:` entry. The task name `cutover:ack` uses the colon-namespace
convention matching existing tasks (`manifest:resolve`, `manifest:show`, etc.).

---

### `docs/CUTOVER.md` (new, P4)

**Analog:** `docs/MANIFEST.md` lines 1-11 -- H1 title + "What This Is" H2 + prose paragraphs:

```markdown
# Manifest Reference

## What This Is

Manifests are the source of truth for what each machine installs. Two TOML files...
```

**Structure to replicate (D-12):**

- H1: `# Cutover Reference`
- H2 "What This Is" -- one paragraph framing
- H2 "Fresh-Machine Verification Procedure" -- numbered checklist (steps 1-8)
- H2 "Per-Machine Cutover State" -- markdown table with columns:
  `machine | status | cutover-date | last-validate-pass | days-on-v2 | notes`
- Status values: `planning` / `ready` / `installing` / `soaking` / `cut-over` / `archived`

**Cross-references:** Step 2 (bootstrap) links to `docs/SECURITY.md`. Step 3 (`task setup`) links to
`docs/MANIFEST.md`. Step 4 references `task cutover:ack`. No emojis. No AI attribution.

**Heading style:** Match `docs/MANIFEST.md` -- H1 for doc title, H2 for top-level sections,
H3 for sub-sections if needed. Use `---` horizontal rule only if present in analog (it is not;
avoid). Use inline code for commands (`\`task install\``).

---

### `docs/MIGRATION.md` (new, P5)

**Analog:** `docs/MANIFEST.md` -- H2 per concept, code blocks, inline tables.

**Structure to replicate (D-13):**

- H1: `# Migration Guide: v1 to v2`
- H2 per concept (7 concepts from D-13):
  1. Profile suffix -> Machine manifest
  2. Antigen -> Antidote
  3. `Brewfile-<profile>.rb` -> `packages/<purpose>.rb` + `extra_packages`
  4. `zsh/` -> `shell/` (flat layout)
  5. `gsd-install` -> sentinel-gated `claude:gsd` + explicit `claude:update`
  6. Hostname-based `Match exec` -> manifest-driven identity gates
  7. `macos:shell $BREW_ZSH` -> `{{.BREW_ZSH}}`
- Each H2 ends with an old-path -> new-path mapping table (2-column markdown table)
- Final H2: "Rollback" -- how to fall back to v1 during cutover window

**v1 "before" narrative source:** `.planning/codebase/ARCHITECTURE.md` (v1 architecture).
**v2 "after" narrative source:** project `CLAUDE.md` and `.claude/CLAUDE.md`.

No emojis. No AI attribution. No duplication of content from `docs/MANIFEST.md` -- cite it instead.

---

### `docs/MACHINES.md` (new, P4)

**Analog:** `docs/MANIFEST.md` -- thin doc, defers to source of truth for declarative state.

**Structure to replicate (D-14):**

- H1: `# Machine Reference`
- H2 per machine (4 machines): `personal-laptop`, `work-laptop`, `server-1`, `server-2`
- Each H2 contains:
  - Purpose (prose, one sentence)
  - Hardware (Apple Silicon arm64 vs Intel x86_64)
  - Role narrative (what it's used for day-to-day)
  - Hostname if non-default
  - Special handling (external display, Tailscale, etc.)
  - Single deference line: `See \`manifests/machines/<name>.toml\` for declarative state.`
- No feature flag tables, no identity/package duplication -- those live in the TOML

**Machine data to read:** `manifests/machines/personal-laptop.toml`, `manifests/machines/server-1.toml`,
`manifests/machines/work-laptop.toml`, `manifests/machines/server-2.toml` (planner reads these during
P4 implementation; the implementer needs the `[meta].description` and `[platform].arch` fields).

---

### `README.md` (root replacement, P6)

**Analog:** `taskfiles/README.md`, `install/README.md`, `shell/README.md`, `claude/README.md` -- the
project's sub-directory READMEs share a consistent style: H1 title, short prose intro, section
headers, inline code for commands, no emojis.

**Structure to replicate (D-15):**

- H1: `# dotfiles`
- H2 "What This Is" (~2 paragraphs): manifest model framing (what + why); reference `docs/MANIFEST.md`
- H2 "Fresh Machine Setup": fenced code block with 4 commands:
  ```
  git clone <url>
  ./bootstrap.zsh
  task setup -- <machine-name>
  task install
  ```
- H2 "Where to Add Things": table mirroring `CLAUDE.md` "Adding" table (Adding | Where | Naming)
- H2 "Documentation": bullet list of doc pointers to `docs/MANIFEST.md`, `docs/SECURITY.md`,
  `docs/CUTOVER.md`, `docs/MIGRATION.md`, `docs/MACHINES.md`, `.claude/CLAUDE.md`

**Replacement:** The current `README.md` is the v1 emoji-heavy version (confirmed lines 1-30).
It is replaced in its entirety. No content from v1 README survives; the v1 install flow
(`cd dotfiles && zsh bootstrap.zsh` only, no `task setup`) is retired.


**No emojis (project convention):** Strictly enforced -- no emoji in README.md. The hooks
enforce this at commit time. The v1 README uses emoji in every section header
(confirmed: `README.md` lines 1-30); that is the exact pattern NOT to replicate.

---
## Shared Patterns

### `# lint-allow: cmds-without-status` marker

**Source:** `taskfiles/links.yml` line 76, `taskfiles/identity.yml` line 278, `Taskfile.yml` line 123
**Apply to:** All new aggregator tasks (`validate:`, `links:reconcile:`, `cutover:ack:`)

```yaml
# Pattern: marker on line immediately above the task key
# lint-allow: cmds-without-status
validate:
  desc: "..."
```

### `status: [false]` always-rerun shape

**Source:** `taskfiles/packages.yml verify:` line 201, `taskfiles/claude.yml validate:` line 232,
`taskfiles/macos.yml validate:` line 259

```yaml
# For diagnostic tasks that should always re-run (validate, reconcile, verify)
status: [false]
```

Note: `status: [false]` is the structural always-rerun declaration that satisfies LINT-03a.
The `# lint-allow: cmds-without-status` marker is documentation; `status: [false]` is the
operative form. Use BOTH together on diagnostic tasks.

### `{{.DOTFILES_MESSAGES}}` sourcing pattern

**Source:** `Taskfile.yml` line 167, `taskfiles/macos.yml validate:` line 267

```yaml
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    check "something passed"
    cross "something failed"
    failures=$(( failures + 1 ))
```

This must appear as the FIRST line of any shell block that uses `check`/`cross`/`info`/`warn`/
`success`/`error`/`header`/`step` from `install/messages.zsh`.

### deps: root-namespace form for cross-taskfile deps

**Source:** `taskfiles/macos.yml validate:` line 258, `taskfiles/packages.yml verify:` line 187

```yaml
# CORRECT -- leading colon = root namespace, works across all included taskfiles
deps: [":manifest:resolve"]

# WRONG -- bare form breaks when called from root Taskfile.yml context
deps: [manifest:resolve]
```

### failures counter + non-zero exit pattern

**Source:** `taskfiles/packages.yml verify:` lines 205-219, `taskfiles/manifest.yml test:` lines 282-348

```yaml
cmds:
  - |
    {{.DOTFILES_MESSAGES}}
    failures=0

    if <check>; then
      check "<description>"
    else
      cross "<description>"
      failures=$(( failures + 1 ))
    fi

    exit "$failures"
```

### `env:` for CLI_ARGS safety (shell injection prevention)

**Source:** `taskfiles/manifest.yml setup:` lines 118-119

```yaml
env:
  CLI_ARGS_ENV: '{{.CLI_ARGS}}'
```

Used by `cutover:ack` to prevent apostrophe/metacharacter injection when the machine name is
templated into shell code. Always use `$CLI_ARGS_ENV` (env var) inside shell blocks, never
`{{.CLI_ARGS}}` directly.

### Machine name validation regex

**Source:** `taskfiles/manifest.yml setup:` lines 127-130

```zsh
[[ "$name" =~ ^[a-z0-9_][a-z0-9_-]*$ ]] || exit 1
```

`cutover:ack` reuses the same regex. The regex allows underscore prefix (for `_addmachine-test`
fixture names) and kebab-case (for real machine names like `personal-laptop`).

---

## No Analog Found

No Phase 8 files are entirely without analog. All engineering deliverables map to existing
patterns in the codebase. The algorithm pseudocode in RESEARCH.md lines 178-208 (orphan
detection loop) is the closest thing to novel logic; it combines the `find -maxdepth 2 -type l`
pattern (standard POSIX) with the `readlink -f` prefix check (already used in `helpers.yml`
line 59).

---

## Anti-Patterns to Avoid

| Anti-Pattern | Bug Class | Source Reference | Fix |
|-------------|-----------|------------------|-----|
| `{{if index ...}}` as standalone cmds: entry | `template: :1: unexpected EOF` | `links.yml` lines 133/160/186/189/234/261 | Use inline-ternary in `status:` or shell-block gate |
| `$X` in `status:` blocks | LINT-02 / v1 macos:shell:145 bug | `links.yml` line 24 (doc) | `{{.X}}` template vars only |
| `deps: [manifest:resolve]` bare form | broken cross-taskfile dep | `links.yml` lines 131, 184 | `deps: [":manifest:resolve"]` with leading colon |
| `_:check-link` relied upon for non-zero exit | aggregator always-succeeds | `helpers.yml` lines 48-73 | Inline check logic with explicit `failures=$(( failures + 1 ))` |
| `ignore_error: true` at aggregator task level | silently swallows all failures | RESEARCH.md Pitfall 4 | Apply per-`task:` entry, not on the aggregator itself |
| `task links:reconcile -- --remove` without TTY gate | hangs on piped stdin | RESEARCH.md Pitfall 6 | `[[ -t 0 ]] || { error "..."; exit 1; }` at start of --remove body |
| `cutover:ack` with install-gate precondition | chicken-and-egg | RESEARCH.md Pitfall 7 | `cutover:ack` must be standalone; no `cutover_gate_check` dep |
| Emojis in any file (including README.md) | project convention violation | `CLAUDE.md` (project root) | No emojis anywhere; hooks enforce at commit time |

---

## Metadata

**Analog search scope:** `taskfiles/`, `Taskfile.yml`, `install/`, `docs/`, root `README.md`
**Files scanned:** 12 source files read directly
**Pattern extraction date:** 2026-05-16
