# Phase 8: Validation + Cutover Readiness - Research

**Researched:** 2026-05-16
**Domain:** go-task aggregator composition, symlink reconciliation, cutover documentation
**Confidence:** HIGH (all claims verified directly from codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Engineering-only phase; cutover execution is post-phase. CUTV-04, CUTV-05, CUTV-06 stay Pending in REQUIREMENTS.md until manually marked done after each machine completes its 7-day soak.
- **D-02:** Pre-flight personal-laptop + server-1 manifest pair during verification. Temporary state-file swap (`task setup -- server-1` then restore) per the `manifest:test:add-machine` pattern.
- **D-03:** Read-only verify + real `task install` end-to-end on personal-laptop. Server-1 manifest stays validate-only.
- **D-04:** Run-all-and-aggregate; non-zero exit on any failure. Each component prints its own check/cross during run; aggregator prints final summary table after all finish.
- **D-05:** Pure go-task with `ignore_error: true` — no helper script. Aggregation lives in Taskfile.yml or a new taskfiles/validate.yml. Final shell cmd re-runs each component's status check to compute summary table and bubble exit code.
- **D-06:** Skip silently when feature off; show as 'n/a' in summary. Feature-off components print `"<component>: feature disabled -- skipped"` and return 0.
- **D-07:** `task validate` stays Tier-1 runtime-only; `task lint` and `task test` stay separate. No `task check` umbrella in v1.
- **D-08:** Single `EXPECTED_TARGETS` top-level var in `taskfiles/links.yml`. Refactor `links:validate` and new `links:reconcile` to iterate over that one list. Fixes the `template: :1: unexpected EOF` bug in transit. The 5 cmds-spanning `{{if}}...{{end}}` wrappers and 2 bare `manifest:resolve` deps retire with this refactor.
- **D-09:** Orphan detection walks EXPECTED_TARGETS' parent dirs only. `find <dir> -maxdepth 2 -type l` then `readlink -f` against `$DOTFILEDIR`. Bounded surface; fast; predictable.
- **D-10:** Interactive `--remove` uses plain `read -r REPLY` per orphan, TTY-gated (`[[ -t 0 ]]`). Default `N` on empty/Enter. Magic words: `y`/`yes` removes (idempotent `unlink`), anything else skips.
- **D-11:** Install-time orphan warning runs as the very last step of `task install`. After `packages:verify`. Non-fatal: `task install` exits 0 even when orphans found. Install-time call uses internal mode flag (`--warn-only`) that swallows non-zero exit.
- **D-12:** `docs/CUTOVER.md` is one doc with two halves: top = numbered fresh-machine checklist; bottom = per-machine state table (`machine | status | cutover-date | last-validate-pass | days-on-v2 | notes`). Status values: planning / ready / installing / soaking / cut-over / archived.
- **D-13:** `docs/MIGRATION.md` is per-concept narrative + per-section path-mapping tables. Concepts: Profile suffix -> Machine manifest; Antigen -> Antidote; Brewfile-<profile> -> packages/<purpose>.rb + extra_packages; zsh/ -> shell/ (flat); gsd-install -> sentinel-gated claude:gsd + explicit claude:update; hostname-based Match exec -> manifest-driven identity gates; macos:shell $BREW_ZSH -> {{.BREW_ZSH}}. Closes with rollback section.
- **D-14:** `docs/MACHINES.md` is thin; manifests are source of truth. One H2 per machine. Non-TOML prose only. Ends each section with "See `manifests/machines/<name>.toml` for declarative state."
- **D-15:** Top-level `README.md` replaces v1 README entirely. Tutorial walkthrough: framing (~2 paragraphs) + fresh-machine flow fenced block + where-to-add table. Closes with doc pointers. No emojis, no AI attribution.
- **D-16 (implicit):** `links.yml` refactor folds into reconcile plan via D-08 EXPECTED_TARGETS refactor. NOT a separate pre-Phase-8 cleanup plan.

### Claude's Discretion

- Per-component validate ordering inside composed `task validate` (alphabetical or topological by deps).
- Final summary table format (match existing messages.zsh check/cross style; rich box-drawn vs plain text).
- `links:reconcile` output format (one-line-per-orphan vs grouped-by-parent-dir).
- Exact ordering of the four cutover docs inside Phase 8 (engineering plans precede docs plans; four docs can be interleaved freely).
- Optional cleanup of dead `taskfiles/claude-stub.yml`.

### Deferred Ideas (OUT OF SCOPE)

- `DRY_RUN=1 task install` (PERF-02)
- Per-component drift detection beyond VRFY-03 + reconcile (PERF-01)
- `task cutover:soak-check` helper
- Auto-generated `docs/MACHINES.md`
- `task check` umbrella (lint + test + validate)
- Manual cleanup of `taskfiles/claude-stub.yml` and other Phase-2-era stubs (discretionary only)
- v2 work items (LINUX-V2-*, PERF-*, TOOL-V2-*) from REQUIREMENTS.md §"v2 Requirements"
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CUTV-01 | `task validate` composes all per-component validate tasks with check/cross output | All per-component validate tasks confirmed in codebase; compose pattern proven in TESTING.md |
| CUTV-02 | `task links:reconcile` (default) detects orphan symlinks, exits non-zero; CI-safe | D-08 EXPECTED_TARGETS refactor enables the canonical link set; orphan walk pattern designed in D-09 |
| CUTV-03 | `docs/CUTOVER.md` tracks per-machine cutover state with verification steps | D-12 shape; docs/ currently has only MANIFEST.md, README.md, SECURITY.md -- CUTOVER.md is new |
| CUTV-04 | All four machines installable from v2 with 100% `task validate` pass | Post-phase operational; not a Phase 8 code deliverable (D-01) |
| CUTV-05 | Each machine runs v2 for >= 7 days before declared cut over | Post-phase operational; tracked in CUTOVER.md table |
| CUTV-06 | Old repo archived (not deleted) after final per-machine cutover | Post-phase operational; documented procedure in CUTOVER.md |
| CUTV-07 | `task links:reconcile -- --remove` interactive cleanup; y/N per orphan, never silent | D-10 TTY-gate + read -r REPLY pattern; unlink on confirm |
| CUTV-08 | `task install` runs `links:reconcile` in detect-only warn-only mode at end | D-11 slots after packages:verify at Taskfile.yml line 165 |
| DOCS-01 | Top-level `README.md` explains manifest model, machine setup flow, where-to-add | D-15; replaces v1 README (emoji-heavy; must be replaced entirely) |
| DOCS-05 | `docs/MIGRATION.md` records v1-to-v2 mapping and cutover plan | D-13; no existing MIGRATION.md -- new file |
| DOCS-06 | `docs/MACHINES.md` documents each machine's purpose, identity, special config | D-14; no existing MACHINES.md -- new file |
| DOCS-08 | `docs/CUTOVER.md` includes per-machine fresh-install verification procedure | D-12 top half (numbered checklist); same file as CUTV-03 |
</phase_requirements>

---

## Summary

Phase 8 is a composed aggregation and documentation phase that closes the v2 refactor by wiring together the per-component validate tasks shipped in Phases 1-7 and adding the cutover-readiness tooling and docs that make per-machine v1-to-v2 migration safe and auditable.

The engineering work has two mutually reinforcing parts. First, a root `task validate` aggregator that calls every per-component validate task with `ignore_error: true`, allowing all components to run regardless of failures, then prints a final summary table and exits non-zero if any component failed (D-04, D-05). Second, a two-mode `task links:reconcile` that detects orphan symlinks from a canonical `EXPECTED_TARGETS` var in `taskfiles/links.yml` (D-08) and optionally removes them interactively (D-10). The D-08 refactor of `links.yml` to use a single EXPECTED_TARGETS var fixes the pre-existing `template: :1: unexpected EOF` bug documented in the Phase 7 verification report as a byproduct, making this a structural improvement rather than just feature addition.

The four doc deliverables (CUTOVER.md, MIGRATION.md, MACHINES.md, README.md) are all new content; the current docs/ directory contains only MANIFEST.md, README.md (stub), and SECURITY.md. The existing top-level README.md is the v1 README (emoji-heavy, profile-based terminology) and must be replaced entirely. The existing v1 architecture document in .planning/codebase/ARCHITECTURE.md (which still references the profile-based v1 model) provides the v1 side of the MIGRATION.md narrative; the v2 architecture the docs must describe is the manifest-driven layered model that has been implemented across Phases 1-7.

**Primary recommendation:** Sequence plans as: P1 (EXPECTED_TARGETS links.yml refactor + links:validate fix), P2 (task validate aggregator), P3 (links:reconcile two-mode + install-time warn), P4 (docs/CUTOVER.md + docs/MACHINES.md), P5 (docs/MIGRATION.md), P6 (README.md). Engineering before docs; links refactor before validate aggregator (validate calls links:validate, which must be fixed first).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Validate aggregation (`task validate`) | Task Orchestration (Taskfile.yml or taskfiles/validate.yml) | Per-component taskfiles | Aggregator is orchestration; each component owns its own validate logic |
| Orphan detection (`links:reconcile`) | Task Orchestration (taskfiles/links.yml) | helpers.yml (`_:check-link`) | Links reconcile belongs with link management; helpers provide check primitives |
| Install-time orphan warn | Task Orchestration (root Taskfile.yml) | taskfiles/links.yml | Root install: task calls links:reconcile in warn-only mode; implementation lives in links.yml |
| Cutover gate (`cutover:ack` writer) | Task Orchestration (taskfiles/ or Taskfile.yml) | install/cutover-gate.zsh | Gate reader exists in Phase 2; Phase 8 adds the writer task |
| Documentation (CUTOVER, MIGRATION, MACHINES, README) | Asset Layer (docs/, README.md) | None | Pure documentation; no runtime dependencies |
| `links.yml` EXPECTED_TARGETS refactor | Task Orchestration (taskfiles/links.yml) | None | Structural fix enabling reconcile; owned entirely by the links module |

---

## Domain Knowledge

### Validation Aggregator Patterns

[VERIFIED: taskfiles/claude.yml, taskfiles/identity.yml, taskfiles/macos.yml, taskfiles/packages.yml]

The go-task aggregator pattern used throughout this codebase is:

```yaml
# lint-allow: cmds-without-status
aggregate-task:
  desc: "Run all sub-validates"
  cmds:
    - task: component-a:validate
    - task: component-b:validate
    - task: component-c:validate
```

When `ignore_error: true` is applied to individual `task:` entries, failures do not abort the chain. This is the correct mechanism for D-04's run-all-aggregate behavior.

The summary table pattern (D-05) requires a final shell `cmds:` entry that independently re-evaluates each component's pass/fail status (not re-running full validation, just checking exit state) and prints a formatted summary. The cleanest approach is to capture exit codes from each component run using a `failures` counter pattern identical to the one used in `taskfiles/macos.yml validate:` and `taskfiles/manifest.yml test:`.

### Feature-Gate Skip Pattern

[VERIFIED: taskfiles/claude.yml install:, taskfiles/macos.yml defaults:dock, taskfiles/links.yml claude:]

Two proven patterns exist for feature-gating in this codebase:

**Pattern A (cmds-spanning `{{if}}...{{end}}` wrapper):** Present in the current `links.yml` `claude:` and `configs:` tasks (lines 133/160, 186/189, 234). This causes the `template: :1: unexpected EOF` bug when the feature is off because go-task renders each cmds entry as its own template -- a bare `{{if}}` line on its own becomes an incomplete template.

**Pattern B (inline-ternary status:):** Proven in `taskfiles/claude.yml install:`:
```yaml
status:
  - '{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}false{{end}}'
```
This is the correct pattern that D-08 mandates for EXPECTED_TARGETS entries.

For the `task validate` aggregator, D-06 requires feature-off components to print an informational line and return 0. The per-component validate tasks already handle this internally (e.g., `claude:validate` can check `claude-marketplace` before running its body). The aggregator's summary table needs to show `n/a` for feature-off components -- this requires the aggregator to distinguish exit code 0 from a feature-off skip vs. exit code 0 from a passing validate. The simplest approach: have each per-component validate emit a sentinel line (e.g., `[INFO] component: feature disabled -- skipped`) to stdout; the aggregator can `grep` for that sentinel when building the summary row.

### EXPECTED_TARGETS Refactor (D-08) -- Critical Path

[VERIFIED: taskfiles/links.yml full survey]

The current `taskfiles/links.yml` declares symlink targets inline in each sub-task's `cmds:` block and duplicates them again in the `status:` block and `validate:` task. The D-08 refactor introduces a single `EXPECTED_TARGETS` vars entry listing every declared symlink target path (newline-separated, optionally annotated with feature gate conditions).

The parent directories of the full EXPECTED_TARGETS set (verified from current links.yml):
- `{{.ZDOTDIR}}` (zsh startup files + antidote plugin manifest)
- `{{.XDG_CONFIG_HOME}}/claude/` (CLAUDE.md, settings.json, hooks/)
- `{{.XDG_CONFIG_HOME}}/claude/hooks/` (8 hook files)
- `{{.XDG_CONFIG_HOME}}/ghostty/` (gated: ghostty feature)
- `{{.XDG_CONFIG_HOME}}/glow/` (2 files)
- `{{.XDG_CONFIG_HOME}}/trippy/`
- `{{.XDG_CONFIG_HOME}}/tlrc/`
- `{{.XDG_CONFIG_HOME}}/conda/`
- `{{.XDG_CONFIG_HOME}}/eza/`
- `{{.GIT_CONFIG_DIR}}/` (identity-owned symlinks; links.yml calls `task: identity:install`)
- `{{.SSH_DIR}}/` (identity-owned symlinks; links.yml calls `task: identity:install`)

Note: identity symlinks are created by `taskfiles/identity.yml` via `task: identity:install` from `links:all`. The EXPECTED_TARGETS var in links.yml should include only the symlinks that links.yml itself creates directly (the zsh + claude + configs sets). Identity-layer symlinks live in `identity.yml` and are validated by `identity:validate`. Including them in EXPECTED_TARGETS would create a cross-module dependency; the cleaner boundary is to limit links.yml's EXPECTED_TARGETS to what links.yml owns.

The 5 bug-causing spots in current links.yml:
- `claude:` task cmds: line 133 (`{{if index ...}}`) + line 160 (`{{end}}`)
- `configs:` task cmds: line 186 (`{{if index ...}}`) + line 189 (`{{end}}`)
- `validate:` task cmds: line 234 (`{{if index ...}}`) + line 261 (`{{end}}`) + line 263-266 (ghostty gate)

The 2 bare `manifest:resolve` deps to flip to `:manifest:resolve` form:
- `claude:` task line 131 `deps: [manifest:resolve]`
- `configs:` task line 184 `deps: [manifest:resolve]`

### Orphan Detection Algorithm (D-09)

[VERIFIED: taskfiles/links.yml, manifests/machines/personal-laptop.toml, manifests/machines/server-1.toml]

The reconcile algorithm:
1. Expand EXPECTED_TARGETS to get the list of known symlink paths.
2. Derive the parent directory set from EXPECTED_TARGETS (deduplicated).
3. For each parent dir: `find <dir> -maxdepth 2 -type l`.
4. For each symlink found: `readlink -f` → check if it starts with `$DOTFILEDIR`.
5. If `readlink -f` result starts with `$DOTFILEDIR` but the symlink path is NOT in EXPECTED_TARGETS → orphan.

In shell (inside a go-task cmd block):
```zsh
# Pseudo-code for orphan detection
dotfiledir="{{.DOTFILEDIR}}"
# EXPECTED_TARGETS is a multiline var -- iterate line by line
expected=()
while IFS= read -r line; do
  [[ -n "$line" ]] && expected+=("$line")
done <<< "{{.EXPECTED_TARGETS}}"

orphans=()
# Derive parent dirs
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
    # Check if lnk is in expected set
    found=0
    for e in "${expected[@]}"; do
      [[ "$lnk" == "$e" ]] && { found=1; break; }
    done
    (( found == 0 )) && orphans+=("$lnk")
  done < <(find "$dir" -maxdepth 2 -type l 2>/dev/null)
done
```

The three invocation modes:
- **Default (detect-only):** Print orphans, exit non-zero if any found.
- **`--remove` (interactive):** TTY-gate (`[[ -t 0 ]]`), `read -r REPLY` per orphan, `unlink` on `y`/`yes`.
- **`--warn-only` (install-time):** Print orphans via `warn()`, always exit 0.

### cutover-gate.zsh -- Phase 8's Missing Piece

[VERIFIED: install/cutover-gate.zsh]

The cutover gate reader (`cutover_gate_check()`) already exists and is wired into `task install`'s preconditions block (Taskfile.yml lines 145-152). The gate reads:
- `$XDG_STATE_HOME/dotfiles/machine` (active machine name)
- `$XDG_STATE_HOME/dotfiles/cutover-ack` (single line: `<machine-name> <timestamp>`)

The `cutover-gate.zsh` comment at line 15 explicitly states: "The sentinel WRITER (`task cutover:ack -- <name>`) is owned by Phase 8 (CUTV-03). P2 only reads/enforces."

Phase 8 must therefore add a `cutover:ack` task that:
1. Takes the machine name as `CLI_ARGS`.
2. Validates it matches the active machine file.
3. Writes `<machine-name> <ISO-timestamp>` to `$XDG_STATE_HOME/dotfiles/cutover-ack`.
4. Prints a confirmation message and reminds the user to update CUTOVER.md.

This task does NOT need a `status:` block (it's a one-shot write that should always re-run when explicitly called). The `# lint-allow: cmds-without-status` marker applies.

### `install/messages.zsh` Output Functions

[VERIFIED: install/messages.zsh]

Available output functions and their visual form:
- `info "msg"` -- `[INFO] msg` (blue)
- `success "msg"` -- `[SUCCESS] msg` (green)
- `warn "msg"` -- `[WARN] msg` (yellow) -- used for install-time orphan warning
- `error "msg"` -- `[ERROR] msg` (red, to stderr)
- `check "msg"` -- `✓ msg` (green) -- used per-component pass line
- `cross "msg"` -- `✗ msg` (red) -- used per-component fail line
- `header "msg"` -- `── msg ──` (green bold)
- `step "msg"` -- `→ msg` (blue)
- `debug "msg"` -- only when `DOTFILES_DEBUG=true`

The composed `task validate` summary table should use `check` / `cross` per component row, matching the existing per-component validate output style.

---

## Existing Code Survey

### Per-Component Validate Tasks (confirmed present)

[VERIFIED: direct file reads of each taskfile]

| Component | Task Name | Taskfile | Output Style | Feature Gate |
|-----------|-----------|----------|--------------|--------------|
| Manifest | `manifest:validate` | taskfiles/manifest.yml | check/cross inline shell | none (always runs) |
| Identity | `identity:validate` | taskfiles/identity.yml | check/cross via _:check-link + inline | identity feature flags |
| Packages | `packages:validate` | taskfiles/packages.yml | delegates to `packages:verify` | none |
| macOS | `macos:validate` | taskfiles/macos.yml | check/cross inline shell, enumerate-all | macos-* feature flags |
| Claude | `claude:validate` | taskfiles/claude.yml | check/cross inline shell + for: loops | claude-marketplace |
| Links | `links:validate` | taskfiles/links.yml | check/cross via _:check-link | claude-marketplace, ghostty |

**Notes on links:validate:** Currently has the `template: :1: unexpected EOF` bug for the `{{if}}...{{end}}` cmds-spanning wrappers. The D-08 refactor fixes this.

**packages:validate** is a thin wrapper (`cmds: [task: verify]`) that delegates entirely to `packages:verify`. This is already correctly set up for composition.

**identity:validate** is itself a composed aggregator (`cmds: [task: validate:symlinks, task: validate:git, task: validate:ssh-add, task: validate:keys]`). No changes needed.

**There is no existing root `task validate` in Taskfile.yml.** The current root Taskfile.yml exposes only `default`, `test`, and `install` at the top level. Phase 8 adds `validate` and `lint` (lint already exists via the `lint:` include). The old TESTING.md references a profile-era `task validate` that does not exist in the v2 Taskfile.yml.

### `task install` Current Final Step

[VERIFIED: Taskfile.yml lines 154-169]

```yaml
install:
  cmds:
    - task: links:all
    - task: packages:install
    - task: claude:install
    - task: macos:defaults
    - task: macos:shell
    - task: packages:verify    # <-- current last task call
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"  # <-- current final shell line
```

D-11 slots `task: links:reconcile` (warn-only mode) between `packages:verify` and the `success "install complete"` shell line. The shell line itself moves to after reconcile, or reconcile's warn output appears before the success message.

### Existing `cutover-ack` Writer Gap

[VERIFIED: install/cutover-gate.zsh, Taskfile.yml]

`cutover_gate_check()` reads `$XDG_STATE_HOME/dotfiles/cutover-ack` but no task writes it. The comment in cutover-gate.zsh at line 15 explicitly delegates this to Phase 8. Without a `task cutover:ack` task, a user cannot run `task install` on a new machine setup -- they'd get "machine 'X' is not cut over to v2 (missing)" immediately. Phase 8 must ship this writer task.

### Existing Docs State

[VERIFIED: docs/ directory listing, README.md]

| File | Status | Phase 8 Action |
|------|--------|----------------|
| `docs/MANIFEST.md` | Exists (Phase 1) | No changes; cited from CUTOVER.md and README.md |
| `docs/SECURITY.md` | Exists (Phase 2) | No changes; cited from CUTOVER.md bootstrap step |
| `docs/README.md` | Stub (1 paragraph listing expected files) | No changes needed; Phase 8 adds the actual files |
| `docs/CUTOVER.md` | Does not exist | Phase 8 creates |
| `docs/MIGRATION.md` | Does not exist | Phase 8 creates |
| `docs/MACHINES.md` | Does not exist | Phase 8 creates |
| `README.md` (root) | Exists (v1, emoji-heavy, profile-based) | Phase 8 replaces entirely |

The existing root README.md uses emoji headers (`## 👨🏻‍💻`, `## `, `### 🛠`, `### 📦`, `## 📘`, `## ☁️`, `## 📚`) and references the profile-era install flow (`cd dotfiles && zsh bootstrap.zsh` only), with no mention of manifests, `task setup`, or machine names. It must be replaced in its entirety.

### Dead Code to Optionally Clean

[VERIFIED: taskfiles/ listing, 07-VERIFICATION.md]

- `taskfiles/claude-stub.yml` -- no longer referenced in Taskfile.yml (replaced by real claude.yml in Phase 7). Can delete.
- `taskfiles/macos.v1.yml.bak` -- parked v1 backup. Can delete on cutover.
- `taskfiles/links-stub.yml`, `taskfiles/brew-stub.yml` -- old stubs from pre-Phase-3/5 era. Can delete.
- `taskfiles/common.yml`, `taskfiles/profile.yml`, `taskfiles/profile-tasks.yml`, `taskfiles/brew.yml` -- v1 taskfiles NOT included by v2 root Taskfile.yml (per root file header comment). Can delete on cutover.

The `taskfiles/shell.yml` is the v2 perf: include (aliased as `perf:` in Taskfile.yml includes block) -- NOT the v1 `shell.yml`. Keep.

---

## Dependencies

### Phase 7 Outputs (confirmed shipped)

[VERIFIED: 07-VERIFICATION.md, direct taskfile reads]

- `taskfiles/claude.yml` with `claude:validate` -- confirmed present and correct.
- `taskfiles/links.yml` with `links:validate` -- present but has the template-EOF bug (D-08 fixes).
- `taskfiles/helpers.yml` with hardened `_:safe-link` (TOOL-03) and `_:check-link` (TOOL-04) -- confirmed present.
- `taskfiles/test.yml` with `test:hooks` -- confirmed present.
- Tool configs in `configs/<tool>/` -- confirmed present.

### Helper Library Dependencies

`links:reconcile` uses:
- `install/messages.zsh` for `warn()` (orphan output) and `check`/`cross` (detection reporting).
- `_:check-link` from helpers.yml for per-expected-link verification (already the pattern in `links:validate`).
- `unlink` (POSIX, no helper needed) for `--remove` mode deletion.

`task validate` (aggregator) uses:
- `install/messages.zsh` for the summary table printing.
- Each per-component validate task via `task: <component>:validate` with `ignore_error: true`.

### Doc Cross-References

- `docs/CUTOVER.md` cites `docs/SECURITY.md` (bootstrap step) and `docs/MANIFEST.md` (task setup step).
- `docs/MIGRATION.md` cites `docs/MANIFEST.md` (schema reference), `docs/CUTOVER.md` (rollback section), `.planning/codebase/ARCHITECTURE.md` (v1 architecture as the "before" picture).
- `docs/MACHINES.md` cites `manifests/machines/<name>.toml` for each machine.
- `README.md` (root) cites `docs/MANIFEST.md`, `docs/SECURITY.md`, `docs/CUTOVER.md`, `docs/MIGRATION.md`, `docs/MACHINES.md`, `.claude/CLAUDE.md`.

---

## Validation Architecture

Nyquist validation is enabled (`workflow.nyquist_validation: true` in .planning/config.json).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | go-task (task runner as test runner; no dedicated test framework) |
| Config file | Taskfile.yml (root) |
| Quick run command | `task lint` |
| Full suite command | `task lint && task test && task validate` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| CUTV-01 | `task validate` exits non-zero when any component fails | Smoke | `task validate` (mutate a symlink to break it, confirm non-zero) | Manual mutation test |
| CUTV-01 | `task validate` prints summary table after all components run | Smoke | `task validate` visual inspection | Part of verify step |
| CUTV-02 | `task links:reconcile` exits non-zero when orphan present | Unit-like | Create orphan link, run `task links:reconcile`; assert `$?` non-zero | Part of verify script |
| CUTV-02 | `task links:reconcile` prints orphan paths | Smoke | Visual inspection from verify step | |
| CUTV-07 | `links:reconcile -- --remove` TTY-gate: exits non-zero when piped | Unit-like | `echo '' | task links:reconcile -- --remove`; assert non-zero | Automated in verify |
| CUTV-08 | `task install` exits 0 when orphan present (warn-only) | Integration | Create orphan, run `task install`, assert exit 0 | Real install in D-03 |
| CUTV-08 | Orphan warning appears in install output | Smoke | Visual inspection of `task install` output | |
| DOCS-01 | README.md has no emojis | Static | `task lint:shell-headers` (won't catch); manual grep / hook catches at commit time | Hook blocks commit |
| DOCS-01 | README.md is valid Markdown | Static | Visual review | |
| CUTV-01 | lint:taskfile passes on new validate.yml or updated Taskfile.yml | Static | `task lint` | Automated |

### Sampling Rate

- **Per task commit:** `task lint`
- **Per wave merge:** `task lint && task test`
- **Phase gate:** `task lint && task test && task validate` (full pipeline) + real `task install` on personal-laptop

### Wave 0 Gaps

- [ ] No new test files needed -- Phase 8 validates itself through the existing `task lint` / `task test` / `task validate` pipeline and the D-03 real install run.

---

## Security Domain

Phase 8 has no new cryptographic operations, authentication flows, or secret handling. The existing `cutover-ack` sentinel write is a plain text file under `$XDG_STATE_HOME` (machine-local, not committed). No ASVS categories apply beyond the already-covered V5 (input validation on machine name in `cutover:ack` task -- validate matches `^[a-z0-9_][a-z0-9_-]*$` per the pattern established in `manifest.yml setup:`).

The `links:reconcile -- --remove` mode must never delete files outside the symlink itself (`unlink` on the symlink path only, never `rm -rf`). This is enforced by using `unlink` (which removes only the named path) rather than `rm`.

---

## Common Pitfalls

### Pitfall 1: Template EOF from cmds-spanning `{{if}}...{{end}}`

**What goes wrong:** A bare `{{if condition}}` as its own cmds: entry and a bare `{{end}}` as another cmds: entry. When the condition is false, go-task renders the `{{if}}` line as an empty string and the `{{end}}` line separately -- but a template containing only `{{end}}` is malformed, producing `template: :1: unexpected EOF`.

**Why it happens:** go-task renders each cmds: entry as its own independent template, not as a block. A closing `{{end}}` without an opening `{{if}}` in the same entry is an incomplete template.

**How to avoid:** Use the inline-ternary pattern proven in `taskfiles/claude.yml install:`:
```yaml
status:
  - '{{if not (index .MANIFEST.features "feature-name")}}true{{else}}false{{end}}'
```
For feature-gating a block of sub-tasks, the correct go-task pattern is to use the task-level `status:` to gate the entire task body, not to wrap cmds: entries in `{{if}}`.

**Warning signs:** Any `{{if}}` or `{{end}}` as a standalone cmds: entry. The D-08 refactor removes all 5 such spots.

### Pitfall 2: `$X` in status: blocks (the LINT-02 bug class)

**What goes wrong:** Using `$X` shell variable references inside `status:` blocks. Shell variables are not in scope during status evaluation; the reference expands to empty string, causing the condition to always fail and the task to always re-run.

**How to avoid:** `{{.X}}` template vars only in status: blocks. LINT-02 enforces this; `task lint` catches violations.

**Specific risk for Phase 8:** The `links:reconcile` task will have mode detection logic. If the mode is determined by a shell variable (`MODE=$1`) and that variable is referenced in a `status:` block, it will fail. Solution: `links:reconcile` should have `status: [false]` (always-rerun, diagnostic) or no status block with `# lint-allow: cmds-without-status`.

### Pitfall 3: Orphan detection scope creep

**What goes wrong:** Walking all of `$XDG_CONFIG_HOME` or `$HOME` recursively for orphan symlinks. This catches symlinks that were intentionally created outside the dotfiles repo (e.g., by other tools).

**How to avoid:** Per D-09, walk only the parent directories derived from EXPECTED_TARGETS, with `-maxdepth 2`. Only symlinks that (a) are in those bounded dirs and (b) point into `$DOTFILEDIR` are candidates for orphan status.

### Pitfall 4: `ignore_error: true` on the wrong level

**What goes wrong:** Applying `ignore_error: true` at the aggregator task level instead of on individual `task:` entries. At the aggregator level, it means a failure in any sub-task is silently swallowed and the aggregator always exits 0 -- defeating the purpose.

**How to avoid:** Apply `ignore_error: true` on each individual `task:` delegation entry inside the aggregator's `cmds:`, not on the aggregator task itself:
```yaml
validate:
  cmds:
    - task: manifest:validate
      ignore_error: true
    - task: identity:validate
      ignore_error: true
    - task: packages:validate
      ignore_error: true
    - |
      # final summary and exit code
```

### Pitfall 5: Summary table exit code not bubbled

**What goes wrong:** The aggregator runs all components with `ignore_error: true` (so none abort the chain) but then the final shell `cmds:` entry that prints the summary exits 0 unconditionally, making `task validate` always succeed.

**How to avoid:** The final shell entry must independently track failures. Since `ignore_error: true` swallows the per-component exit codes at the task level, the summary must re-evaluate state independently. Two approaches:
1. Each per-component validate writes a status file under `$XDG_CACHE_HOME/dotfiles/validate/` (sentinel per component) -- complex.
2. The final shell entry re-invokes each component validate task with a quick re-check (cheap because per-component validates use idempotent checks) and accumulates a failures counter.
3. Each per-component validate emits a distinct sentinel pattern to stdout that the summary block greps for (no extra state files needed).

**Recommended approach (D-05 compliant):** Re-run each component's validate in the final shell entry as a sub-invocation, capturing exit codes into a `failures` counter. Since per-component validates are all idempotent read-only checks (no writes, no network), the double-run cost is negligible (milliseconds per component).

### Pitfall 6: TTY detection for `--remove` mode

**What goes wrong:** Forgetting to gate `read -r REPLY` on `[[ -t 0 ]]`. If `task links:reconcile -- --remove` is called from a script or piped stdin, `read` blocks waiting for input that never comes (or gets garbage input from a pipe).

**How to avoid:** Per D-10:
```zsh
if [[ ! -t 0 ]]; then
  error "links:reconcile --remove requires an interactive TTY; stdin is not a tty"
  exit 1
fi
```
Checked at the top of the `--remove` mode body, before any orphan enumeration.

### Pitfall 7: `cutover:ack` task triggering `task install` gate

**What goes wrong:** The `cutover:ack` task needs to write the cutover-ack sentinel file -- but if it has `deps: [manifest:resolve]` and if the root Taskfile.yml includes `cutover:ack` in an include that triggers the install precondition, it creates a chicken-and-egg: you can't run `task install` without the ack, but you can't run `cutover:ack` without first running install.

**How to avoid:** `task cutover:ack` must NOT have the install-gate precondition. It should be a standalone task (potentially in a new `taskfiles/cutover.yml` or in the root Taskfile.yml directly) that reads the machine state file and writes the ack file, with no dependency on the full install pipeline. The precondition in `Taskfile.yml install:` reads the ack file; the writer task does not need the full install chain as a dep.

---

## Recommended Approach

### File-by-File: What to Add, What to Modify

**P1: EXPECTED_TARGETS refactor + links:validate fix (pre-requisite for P2)**

Modify `taskfiles/links.yml`:
- Add a `EXPECTED_TARGETS` multiline var in the vars: block listing all symlink targets owned by links.yml (zsh, antidote, claude config tree, tool configs).
- Rewrite `links:validate` to iterate over EXPECTED_TARGETS instead of hardcoded `_:check-link` task chains. Feature-gate individual EXPECTED_TARGETS entries using inline-ternary status pattern.
- Rewrite `links:claude` and `links:configs` to use inline-ternary status gates instead of cmds-spanning `{{if}}...{{end}}`.
- Flip bare `manifest:resolve` deps to `:manifest:resolve` form (2 spots).
- The template-EOF bug disappears as a natural consequence.

Note: The `zsh:` and `antidote:` tasks are not feature-gated, so they remain simple. The identity symlinks are NOT in EXPECTED_TARGETS (they belong to identity.yml).

**P2: Root `task validate` aggregator**

Option A: Add `validate:` task directly to `Taskfile.yml` (no new file, simpler include graph).
Option B: Create `taskfiles/validate.yml` and include it in root (cleaner separation).

Given that `Taskfile.yml` already directly includes all the taskfiles whose validate tasks compose into the aggregator, and given that D-05 says "planner decides", adding directly to `Taskfile.yml` is simpler. The file is already at ~170 lines; a validate task adds ~30-40 lines.

```yaml
# lint-allow: cmds-without-status
validate:
  desc: "Validate full installation state (all components; run-all-aggregate)"
  deps: [manifest:resolve]
  cmds:
    - task: manifest:validate
      ignore_error: true
    - task: identity:validate
      ignore_error: true
    - task: packages:validate
      ignore_error: true
    - task: macos:validate
      ignore_error: true
    - task: claude:validate
      ignore_error: true
    - task: links:validate
      ignore_error: true
    - |
      # Summary: re-run each component's validate and capture exit codes
      # to build the final summary table.
      {{.DOTFILES_MESSAGES}}
      # ... failures counter + per-component re-invocation + summary print
```

Ordering (alphabetical with manifest first as keystone): manifest, identity, links, macos, packages, claude.

**P3: `task links:reconcile` (two-mode + install-time warn)**

Add `reconcile:` task to `taskfiles/links.yml`:
```yaml
# lint-allow: cmds-without-status
reconcile:
  desc: "Detect orphan symlinks (default: exit non-zero); -- --remove for interactive cleanup"
  deps: [":manifest:resolve"]
  status: [false]
  cmds:
    - |
      {{.DOTFILES_MESSAGES}}
      # parse --remove / --warn-only from CLI_ARGS
      # enumerate EXPECTED_TARGETS
      # derive parent dirs
      # walk with find -maxdepth 2 -type l
      # detect orphans via readlink -f prefix check
      # act based on mode
```

Wire into `task install` in `Taskfile.yml`: insert `task: links:reconcile` with `vars: {CLI_ARGS: "--warn-only"}` between the `packages:verify` task call and the `success "install complete"` shell line.

Add `task cutover:ack` (in Taskfile.yml or a new taskfiles/cutover.yml):
- Reads the machine state file for the active machine name.
- Validates the CLI_ARGS machine name matches (or uses active machine if none given).
- Writes `<machine-name> <ISO-timestamp>` to `$XDG_STATE_HOME/dotfiles/cutover-ack`.
- Prints instructions to update CUTOVER.md.

**P4: `docs/CUTOVER.md` + `docs/MACHINES.md`**

Create `docs/CUTOVER.md` with D-12 shape:
- Top half: numbered fresh-machine verification procedure
  1. Clone repo
  2. `./bootstrap.zsh` (links to docs/SECURITY.md for trust chain)
  3. `task setup -- <machine-name>` (links to docs/MANIFEST.md for machine list)
  4. `task cutover:ack -- <machine-name>` (unlocks task install)
  5. `task install`
  6. `task validate` (must be 100% green)
  7. Begin 7-day soak period
  8. After 7 days: update CUTOVER.md table, archive v1 when last machine done
- Bottom half: per-machine state table

Create `docs/MACHINES.md` with D-14 shape:
- H2 per machine: personal-laptop, work-laptop, server-1, server-2
- Purpose, hardware (Apple Silicon / Intel), role narrative, hostname (if non-default)
- Single line deferring to manifest TOML for features/identity/packages

Machine data from manifests:
- personal-laptop: arm64, primary dev, `claude-marketplace=true`, `ghostty=true`, all macos features on
- server-1: no arch declared (darwin, headless), `claude-marketplace=false`, server-1 git/ssh identity, macos-security only
- work-laptop: need to read work-laptop.toml
- server-2: need to read server-2.toml

**P5: `docs/MIGRATION.md`**

Create with D-13 shape. Per-concept sections sourcing from the v1 ARCHITECTURE.md (which documents the profile-based model) and the v2 implementation:
- Profile suffix → Machine manifest
- Antigen → Antidote
- `Brewfile-<profile>.rb` → `packages/<purpose>.rb` + `extra_packages`
- `zsh/` → `shell/` (flat)
- `gsd-install` v1 pattern → sentinel-gated `claude:gsd` + explicit `claude:update`
- `hostname`-based `Match exec` → manifest-driven identity gates
- `macos:shell $BREW_ZSH` → `{{.BREW_ZSH}}`
- Rollback section (how to fall back to v1 during cutover window)

**P6: Root `README.md` (full replacement)**

Create with D-15 shape:
- Framing paragraph on manifest model
- Fresh-machine flow fenced block (4 commands)
- Where-to-add table (mirror CLAUDE.md table)
- Doc pointers

Note: The v1 README.md is in git. The Write tool overwrites it cleanly. No migration needed.

---

## Plan Decomposition Hints

| Plan | Scope | Key Files Changed | Req IDs Closed |
|------|-------|-------------------|----------------|
| P1 | EXPECTED_TARGETS refactor in links.yml; fix template-EOF bug; retrofit links:validate | taskfiles/links.yml | CUTV-02 foundation; fixes pre-existing links:validate bug |
| P2 | Root `task validate` aggregator with run-all + summary table + non-zero exit | Taskfile.yml | CUTV-01 |
| P3 | `links:reconcile` two-mode; install-time warn hook; `cutover:ack` writer task | taskfiles/links.yml, Taskfile.yml | CUTV-02, CUTV-07, CUTV-08 |
| P4 | `docs/CUTOVER.md` + `docs/MACHINES.md` | docs/CUTOVER.md (new), docs/MACHINES.md (new) | CUTV-03, DOCS-06, DOCS-08 |
| P5 | `docs/MIGRATION.md` | docs/MIGRATION.md (new) | DOCS-05 |
| P6 | Root `README.md` replacement | README.md | DOCS-01 |

**Suggested sequence:** P1 before P2 (links:validate must be fixed before the aggregator calls it), P2 before P3 (validate aggregator ships before reconcile for clean verification), P3 before P4 (cutover:ack task must exist for CUTOVER.md procedure to be accurate), P4 and P5 can be swapped, P6 last (README can cite all other docs once they exist).

**Carry-forward from P1 that blocks P2:** The EXPECTED_TARGETS refactor in P1 rewrites `links:validate` so it no longer has the EOF bug. P2's aggregator calls `links:validate`; if P1 hasn't landed, the aggregator will trigger the EOF warning.

---

## Risks and Unknowns

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| `ignore_error: true` on task: entries not supported in go-task 3.37 | LOW | HIGH (blocks D-05 pattern) | Verify `ignore_error` at task: entry level; fallback is shell-level invocation `task links:validate || true` |
| Summary table exit code: double-invocation of per-component validates is slow on real machines | LOW | MEDIUM (LINT-08 5s gate) | Per CONTEXT.md D-11 note: reconcile detect-only is ms-range; validate components are all read-only idempotent checks; should be well under 5s |
| work-laptop.toml and server-2.toml content unknown | LOW | MEDIUM (needed for MACHINES.md) | Read both files during P4 planning; they're in manifests/machines/ |
| `find -maxdepth 2` for orphan detection may miss nested symlinks | KNOWN | LOW | Documented intentional trade-off in D-09; acceptable scope limitation |
| LINT-03a: new validate aggregator task trips the lint check | LOW | LOW | Use `# lint-allow: cmds-without-status` marker (proven pattern) |
| `claude-stub.yml` and other v1 stubs confuse lint:taskfile | KNOWN | LOW | Pre-existing 19 violations; Phase 8 doesn't make them worse; optional cleanup folded into P6 |
| TTY detection difference between go-task shells and interactive terminal | LOW | LOW | `[[ -t 0 ]]` is standard zsh; go-task's mvdan/sh interprets this correctly |

### Open Questions

1. **Does go-task 3.37 support `ignore_error: true` on individual `task:` entries within a `cmds:` list?**
   - What we know: `ignore_error` exists in go-task (documented in ARCHITECTURE.md reference). It may apply at the task level, not the individual cmds entry level.
   - What's unclear: The exact YAML path for per-entry ignore_error.
   - Recommendation: Test with `task -t taskfiles/manifest.yml validate` during P2 implementation; fallback to shell-level `task manifest:validate || true` if per-entry ignore_error isn't available.

2. **Exact content of work-laptop.toml and server-2.toml for MACHINES.md**
   - What we know: Both files exist in manifests/machines/.
   - What's unclear: Hardware (arm64 vs x86), feature flags, identity profiles.
   - Recommendation: Read both files during P4 planning (trivial -- they're in the repo).

3. **Should `task cutover:ack` live in root Taskfile.yml or a new taskfiles/cutover.yml?**
   - What we know: The root Taskfile.yml currently has only 3 non-default tasks (test, install, and the new validate).
   - Recommendation: Add to root Taskfile.yml directly; a one-task module in taskfiles/cutover.yml would require adding it to the includes: block. Keep it in the root where the other lifecycle tasks (install) live.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| go-task | All task orchestration | yes | 3.37+ (confirmed from CLAUDE.md min requirement) | None (project-critical) |
| zsh | Shell scripts | yes | macOS default + Homebrew | None |
| `find` (BSD) | links:reconcile orphan walk | yes | macOS built-in | None needed |
| `readlink` (BSD) | links:reconcile target resolution | yes | macOS built-in (note: BSD readlink -f behavior differs from GNU; test on macOS) | Use `realpath` if readlink -f unavailable |
| `unlink` | links:reconcile --remove | yes | POSIX built-in | `rm` as fallback (less safe) |
| `jq`, `yq` | Per-component validates (already in use) | yes | Confirmed from Phase 5-7 usage | None |

**Note on `readlink -f` on macOS:** BSD `readlink` on older macOS does not support `-f` for resolving symlink chains. Go-task's mvdan/sh shell uses `readlink -f` in some contexts. Verify with `readlink --version` or use `realpath` (available via coreutils Homebrew formula) as a safer alternative. The existing `_:check-link` in helpers.yml already uses `readlink -f` (confirmed at line 59 of helpers.yml), so if it works for TOOL-04 it works for reconcile.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ignore_error: true` can be applied per `task:` entry in a cmds: list | Domain Knowledge / Pitfall 4 | If only task-level, need shell-level `|| true` invocations; summary exit code pattern changes |
| A2 | `readlink -f` is available on all four target machines (macOS) | Environment Availability | reconcile orphan detection breaks; switch to `realpath` |
| A3 | Per-component validate tasks exit non-zero on failure (not just print cross and exit 0) | Existing Code Survey | Summary table exit code cannot be bubbled via re-invocation; need alternate approach |

**Note on A3:** Confirmed partially from code reading: `identity:validate:git` exits 1 on mismatch; `identity:validate:keys` exits 1 on non-pub files; `macos:validate` exits `"$failed"`. However, `links:validate` currently does NOT exit non-zero on failure -- it calls `_:check-link` which prints cross but `_:check-link` itself always exits 0 (the cmds: block uses `&&` not `||`, so failure just goes to the cross branch; there's no `exit 1` there). This is a potential gap: if links:validate always exits 0, the aggregator's re-invocation can't use its exit code for the summary. This needs to be verified and possibly fixed in P1 alongside the EXPECTED_TARGETS refactor. Check `taskfiles/helpers.yml check-link:` carefully -- the cmds: block doesn't exit 1 on cross; it just runs the if/else and exits 0 either way.

[VERIFIED: helpers.yml lines 48-72] `_:check-link` does NOT exit 1 on failure -- it prints `cross "..."` and continues. This means `links:validate` always exits 0. Same for `_:check-dir`, `_:check-file`, `_:check-command`. This is consistent with the pre-v2 validation design (validate = diagnostic, not blocking). For Phase 8's aggregator to correctly detect failures in `links:validate`, either:
1. `links:validate` needs to accumulate a failures counter and exit non-zero (P1 fix), OR
2. The aggregator uses a different mechanism to detect links:validate failure (e.g., grep for `✗` in output, or count cross lines).

**Recommendation:** Fix `links:validate` in P1 to accumulate a failures counter and exit non-zero when any `_:check-link` fails. This requires either: (a) inlining the check logic with explicit exit code tracking (matching the macos:validate pattern), or (b) wrapping `_:check-link` invocations in a shell block that captures their output and sets a flag. The cleaner path: rewrite `links:validate` as part of the EXPECTED_TARGETS refactor to be a shell block (like `macos:validate`) rather than a chain of `_:check-link` task calls. This also eliminates the template-EOF bug more cleanly.

Similarly, `identity:validate` delegates to sub-tasks some of which DO exit 1 (validate:git, validate:keys) and some that may not (validate:symlinks uses _:check-link which exits 0). Verify all per-component validates exit non-zero on failure before wiring the aggregator's exit code logic.

---

## Sources

### Primary (HIGH confidence -- direct codebase reads)
- `Taskfile.yml` -- root orchestration, install pipeline, existing task inventory
- `taskfiles/links.yml` -- full EXPECTED_TARGETS survey, template-EOF bug locations
- `taskfiles/helpers.yml` -- `_:safe-link`, `_:check-link` implementation
- `taskfiles/claude.yml` -- inline-ternary status pattern, `claude:validate` implementation
- `taskfiles/identity.yml` lines 270-438 -- `identity:validate` pattern
- `taskfiles/macos.yml` -- `macos:validate` enumerate-all pattern
- `taskfiles/packages.yml` -- `packages:validate` thin wrapper pattern
- `taskfiles/manifest.yml` -- `manifest:validate`, `manifest:test:add-machine` (state-swap pattern)
- `taskfiles/lint.yml` -- `# lint-allow: cmds-without-status` marker, LINT-03a exemption logic
- `install/messages.zsh` -- full function inventory
- `install/cutover-gate.zsh` -- cutover-ack sentinel format, cutover:ack task ownership note
- `manifests/machines/personal-laptop.toml` -- feature flags for laptop (all features on)
- `manifests/machines/server-1.toml` -- feature flags for server (claude-marketplace=false)
- `docs/` directory listing -- confirmed CUTOVER.md, MIGRATION.md, MACHINES.md do not exist
- `README.md` (root) -- confirmed v1 emoji-heavy content requiring full replacement
- `.planning/phases/08-validation-cutover-readiness/08-CONTEXT.md` -- all locked decisions D-01..D-15
- `.planning/phases/07-claude-tool-configs-smoke-tests/07-VERIFICATION.md` lines 110-134 -- template-EOF bug documentation, carry-forward debt
- `.planning/config.json` -- `workflow.nyquist_validation: true` confirmed

### Secondary (MEDIUM confidence -- planning documents)
- `.planning/REQUIREMENTS.md` -- requirement IDs, tier model, traceability table
- `.planning/ROADMAP.md` Phase 8 section -- success criteria
- `.planning/codebase/TESTING.md` -- validation framework documentation (v1-era; some superseded by v2)
- `.planning/codebase/ARCHITECTURE.md` -- v1 architecture (useful as MIGRATION.md "before" source)

---

## Metadata

**Confidence breakdown:**
- Per-component validate inventory: HIGH -- direct file reads, all 6 validates confirmed
- EXPECTED_TARGETS refactor scope: HIGH -- all 5 bug spots identified with line numbers
- links:reconcile algorithm: HIGH -- D-09/D-10 decisions are fully specified; implementation is straightforward
- Summary table exit code: MEDIUM -- depends on per-component exit code behavior (A3 assumption flagged; _:check-link always-exits-0 confirmed as gap)
- Doc content: MEDIUM -- structure from D-12..D-15 is clear; prose content requires judgment at write time
- `ignore_error: true` per-entry behavior: LOW -- not directly verified in go-task docs

**Research date:** 2026-05-16
**Valid until:** 2026-06-16 (stable project; no external dependencies)
