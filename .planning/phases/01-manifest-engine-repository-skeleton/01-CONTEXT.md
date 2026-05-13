# Phase 1: Manifest Engine + Repository Skeleton - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the keystone manifest layer plus the full repository skeleton.

**In scope:**
- TOML schema for `manifests/defaults.toml` and `manifests/machines/<name>.toml`
- `install/resolver.zsh` that compiles defaults + machine manifest into `$XDG_STATE_HOME/dotfiles/resolved.json`
- `task setup -- <machine-name>` persists explicit machine selection to `$XDG_STATE_HOME/dotfiles/machine`
- `task manifest:resolve` / `manifest:show` / `manifest:validate` / `manifest:test`
- Deep-merge test fixtures (map-over-map, list-replace, scalar-override, nested table, missing-key, `extra_packages` concatenation)
- Top-level directory skeleton with stub READMEs (every directory exists in P1)
- `docs/MANIFEST.md` documenting schema, merge semantics, worked examples
- Project-level `CLAUDE.md` with v2 conventions

**Out of scope (deferred to later phases):**
- Bootstrap hardening + lint suite (Phase 2)
- Any actual content under `shell/`, `identity/`, `packages/`, `configs/`, `os/`, `claude/` (their respective phases)
- Drift detection / reconciliation (Phase 8)
- Package verification (Phase 5)

**Requirements addressed:** MFST-01, MFST-02, MFST-03, MFST-04, MFST-05, MFST-06, MFST-07, MFST-08, MFST-09, DOCS-03, DOCS-04

</domain>

<decisions>
## Implementation Decisions

### TOML Schema Shape

- **D-01: `[platform]` block is required**, `os` must equal `"darwin"` in v1. Validator rejects any other value. When Linux v2 arrives, the rule opens up to accept `"linux"` — no schema migration needed.
- **D-02: `arch` is optional.** Resolver detects via `uname -m` and writes the value into `resolved.json` so downstream tasks read it from one place.
- **D-03: Standard required-field set for machine manifests** — `manifest:validate` fails if any of these is missing from `manifests/machines/<name>.toml`:
  - `meta.description` (free-text)
  - `platform.os` (must be `"darwin"` in v1)
  - `features` (table, may be empty `{}`)
  - `packages.brew.bundles` (array, must list at least `"core"`)
  - `identity.git` (string, one of `"personal" | "work" | "none"`)
  - `identity.ssh` (string, one of `"personal" | "work" | "none"`)
- **D-04: Unknown keys produce a warning, not a failure.** `manifest:validate` prints `unknown key: features.macos-dok at manifests/machines/personal-laptop.toml:14` to stderr and exits 0. Trade-off: friendlier for staged renames; one stale-key class of bug stays possible. Revisit if it bites.
- **D-05: `defaults.toml` is hybrid** — it supplies safe values for every required field (so resolver always produces a complete `resolved.json` even if a machine field is missing), BUT `manifest:validate` still requires the machine file to explicitly declare every required field from D-03. Inheriting a sensitive field silently is the failure mode being guarded against (Pitfall #1 — drift).

### Deep-Merge Semantics

- **D-06: Merge rules** (already locked pre-discussion in PROJECT.md / STATE.md):
  - Maps (tables): deep-merge, machine wins on conflict, sibling keys preserved
  - Scalars (string/number/bool): machine replaces defaults
  - Arrays: replaced wholesale (no concatenation) — except `extra_packages`
  - `extra_packages`: explicitly concatenated (defaults + machine, deduplicated) — additive escape hatch
- **D-07: Merge expression** — Use `yq eval-all '. as $i ireduce ({}; . * $i)'` (or equivalent recursive merge), NOT `jq -s '.[0] * .[1]'` (that's shallow and drops nested table keys). Researcher to confirm exact yq syntax / version requirements.
- **D-08: Test fixtures are golden-output tests** under `manifests/test/fixtures/` — each fixture has a `defaults.toml`, `machine.toml`, and expected `resolved.json`. `task manifest:test` diffs actual vs expected. Required fixture cases per MFST-05: map-over-map, list-replace, scalar-override, nested table, missing-in-defaults, missing-in-machine, `extra_packages` concatenation.

### Repository Skeleton

- **D-09: Full skeleton in Phase 1.** Every top-level directory exists in P1 regardless of when its phase populates it:
  - `manifests/` (P1 — populated)
  - `taskfiles/` (P1 — populated)
  - `install/` (P1 — populated)
  - `docs/` (P1 — populated)
  - `shell/` (P3 — stub README only)
  - `identity/` (P4 — stub README only)
  - `packages/` (P5 — stub README only)
  - `configs/` (P7 — stub README only)
  - `os/` (P6 — stub README only)
  - `claude/` (P7 — stub README only)
- **D-10: Flat structure for v1**, since v1 is macOS-only:
  - `packages/` is flat (no `packages/brew/` subdirectory). Brewfiles will live as `packages/core.rb`, `packages/gui.rb`, etc., directly under `packages/`.
  - `os/` is flat: `os/defaults/<concern>.zsh`, `os/shell-registration.zsh` — no `os/darwin/` nesting.
  - `shell/aliases/<topic>.zsh` flat (no `common/darwin/` split).
  - `shell/functions/<name>.zsh` flat.
  - `identity/git/identities/<name>` flat, `identity/ssh/identities/<name>` flat.
  - Known v2 migration cost: when Linux returns, flattened dirs must be reshaped. Accepted trade-off — keeps v1 simple, defers nesting decisions until a real Linux machine exists.
- **D-11: Stub READMEs for placeholder directories** — each unpopulated top-level dir gets a README under ~10 lines: one-line purpose, "Populated by Phase X", optional pointer to the requirement IDs that will land here. Phase that populates the dir replaces the stub with the real README.
- **D-12: `docs/MANIFEST.md` is a P1 deliverable** with: schema reference (required fields, types, allowed values), merge-semantics worked examples (one per fixture case), and a "Adding a new machine" walkthrough.
- **D-13: Project-level `CLAUDE.md` (at repo root) is a P1 deliverable** capturing v2 conventions for AI-assisted maintenance: manifest model, one-concept-per-file rule, flat-dir-in-v1 rule, where to add aliases/functions/packages/features.

### `resolved.json` Cache Lifecycle

- **D-14: Auto-rebuild via task precondition.** Every downstream task that reads `resolved.json` declares `deps: [manifest:resolve]`. `manifest:resolve` has a `status:` check that skips rebuild when `resolved.json` exists and its mtime is newer than every `manifests/*.toml` and `manifests/machines/<active>.toml`. Overhead is the mtime check (~50ms); never stale, never manual.
- **D-15: Cache location:** `$XDG_STATE_HOME/dotfiles/resolved.json` (machine-local, not in repo, not checked in).
- **D-16: Missing-state behavior — hard fail with actionable error.** If `$XDG_STATE_HOME/dotfiles/machine` doesn't exist when `task install` (or any other task) runs, the resolver exits non-zero with:
  ```
  error: no machine selected
    run: task setup -- <machine-name>
    available: personal-laptop, work-laptop, server-1, server-2
  ```
  Lists available machines by scanning `manifests/machines/*.toml`. No interactive prompts (breaks CI / non-TTY contexts). No silent fallback to hostname inference.
- **D-17: Inspection — `task manifest:show` accepts `-- --machine <name>`.** Default prints active machine's resolved JSON. `task manifest:show -- --machine work-laptop` resolves and prints any machine's manifest without switching the state file. Enables side-by-side comparison and AI-agent inspection.

### Claude's Discretion

- **Schema validation mechanism** — hand-rolled zsh checks in `resolver.zsh` is the simplest path (no new deps); a `manifests/schema.json` + taplo/yq+ajv pipeline would be richer but adds tooling. Pick the simpler one for v1 unless researcher finds a strong reason. JSON Schema can be added later for editor integration (deferred to v2 — `TOOL-V2-01`).
- **Machine naming convention** — `kebab-case` is implied by convention (project-level CLAUDE.md says so). No explicit rename flow in v1; renaming = edit state file by hand + rename TOML.
- **Test runner mechanics** — `task manifest:test` likely a zsh script that loops fixtures and diffs; exact diff tool (`diff`, `jd`, `dyff`) is implementation detail.
- **`docs/MANIFEST.md` structure** — outline above is a suggestion; planner can refine.
- **Header comment in `resolved.json`** — a debug header noting source mtime / `task manifest:resolve` invocation timestamp would be nice but is not required.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions, scope
- `.planning/REQUIREMENTS.md` — Full v1 requirements list (MFST-01..09, DOCS-03..04 in scope)
- `.planning/ROADMAP.md` Phase 1 section — Goal, success criteria, requirement mapping
- `.planning/STATE.md` — Pre-Phase-1 decisions (yq throughout, merge semantics, antidote/Starship Phase 3) and blockers (deep-merge shallow-merge bug, `go-task ref:` syntax verify)

### Domain Research (already on disk)
- `.planning/research/SUMMARY.md` — Synthesized research findings
- `.planning/research/STACK.md` — yq v4.53+, go-task v3.50+, antidote, Starship rationale
- `.planning/research/ARCHITECTURE.md` — Standard architecture, manifest schema sketch, resolver pipeline
- `.planning/research/FEATURES.md` — Feature catalogue from research
- `.planning/research/PITFALLS.md` Pitfalls 1-3 — Drift, schema sprawl, merge-rule ambiguity (most relevant to P1)

### Existing Codebase (v1 patterns to inform, not blindly copy)
- `.planning/codebase/ARCHITECTURE.md` — v1 architecture (5 layers: entry, orchestration, helpers, messages, assets) — patterns to preserve
- `.planning/codebase/STRUCTURE.md` — v1 directory layout (what we're replacing)
- `.planning/codebase/CONCERNS.md` — Live v1 bugs (informs Phase 2 lint, but P1 should not reintroduce these patterns)
- `.planning/codebase/CONVENTIONS.md` — v1 naming/scripting conventions (zsh `set -euo pipefail`, kebab-case files, no AI attribution)
- `.planning/codebase/STACK.md` — v1 tech stack

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — Project conventions for AI-assisted maintenance
- `.claude/CLAUDE.md` — Project-level Claude instructions
- `~/.config/claude/CLAUDE.md` — Global conventions (Code section, Language Tooling section, Dotfiles section)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (from v1, port pattern not literal code)
- **`install/messages.zsh`** — colored output library (info/success/warn/error/check/cross). Re-usable as-is; messaging library is orthogonal to the manifest refactor. Keep its `DOTFILES_MESSAGES_LOADED` guard pattern.
- **`taskfiles/helpers.yml`** — `_:safe-link`, `_:check-link`, `_:check-dir`, `_:check-file`, `_:check-command` helpers. The pattern (internal `_:` namespace, parameterized via vars) survives the rewrite; the actual helpers get rebuilt/hardened in later phases (Phase 7 hardens `_:check-link`).
- **Root `Taskfile.yml`** vars block — pattern for global vars (`XDG_*`, `DOTFILEDIR`, `HOMEBREW_PREFIX`, `DOTFILES_MESSAGES`). v2 equivalent reads from `resolved.json` via `fromJson` instead of profile literal.
- **`bootstrap.zsh`** — entry-point pattern (DOTFILEDIR symlink-traversal resolution, install go-task if missing, delegate to `task install`). v2 rewrites with `set -euo pipefail`, no `curl|sh`. Phase 2 owns the rewrite; P1 can leave `bootstrap.zsh` untouched (parallel-rewrite — v1 still works).

### Established Patterns (from v1, to preserve in v2)
- **One concept per file** — every alias topic, every function, every taskfile gets its own file. P1's `manifests/machines/<name>.toml` extends this rule.
- **Idempotency via `status:`** — go-task pattern. P1's `manifest:resolve` uses mtime-based `status:` to satisfy LINT-01 from Phase 2.
- **Symlink-based deployment via `_:safe-link`** — pattern survives the rewrite. P1 doesn't deploy any symlinks itself but the helpers are referenced by D-11 stub READMEs.
- **`set -euo pipefail` on every executable `.zsh`** — `install/resolver.zsh` must follow this.
- **No hardcoded `/opt/homebrew` or `/usr/local`** — detect via `uname -m` and `$HOMEBREW_PREFIX`. Applies to anywhere the resolver shells out.

### Integration Points
- **`$XDG_STATE_HOME/dotfiles/machine`** — single-line text file written by `task setup`, read by `resolver.zsh` and `zsh/.zshenv` (later phase). v1's `$XDG_CONFIG_HOME/dotfiles/profile` is its analog; v2 moves it to STATE_HOME because it's machine-derived state, not user-configured.
- **`$XDG_STATE_HOME/dotfiles/resolved.json`** — written by `manifest:resolve`, read by every downstream task via go-task `fromJson` (Pattern B from research/ARCHITECTURE.md). Researcher to confirm exact `fromJson` / `ref:` syntax in go-task v3.50.
- **`Taskfile.yml` root `vars:`** — pulls `MACHINE` from state file, `MANIFEST` from resolved.json. P1 establishes this pattern; every later phase reads from the same vars.

</code_context>

<specifics>
## Specific Ideas

- **Reference machine list:** `personal-laptop`, `work-laptop`, `server-1`, `server-2` — all macOS, mixed roles (laptops + Mac servers).
- **Reference yq deep-merge expression** (subject to researcher verification): `yq eval-all '. as $i ireduce ({}; . * $i)' defaults.toml machine.toml -o json`. Alternative: a recursive jq function. Researcher to pick the one that is correct, readable, and supported in the pinned yq version.
- **Reference manifest sketch** (from `research/ARCHITECTURE.md`):
  ```toml
  schema_version = 1

  [meta]
  description = "Josh's personal MacBook"

  [platform]
  os = "darwin"
  arch = "arm64"    # optional; detected by resolver if absent

  [features]
  one-password-ssh = true
  macos-dock = true

  [packages.brew]
  bundles = ["core", "gui", "dev", "personal"]
  extra_packages = ["docker-desktop"]

  [identity]
  git = "personal"
  ssh = "personal"
  ```
- **`task setup -- <name>` behavior:** validates `<name>` exists as `manifests/machines/<name>.toml`, writes name to state file, runs `manifest:validate` then `manifest:resolve` to populate cache.

</specifics>

<deferred>
## Deferred Ideas

- **JSON Schema for editor validation** (taplo, vscode-even-better-toml) — already in v2 backlog as `TOOL-V2-01`. P1 ships hand-rolled validation; JSON Schema added later.
- **Manifest rename flow** (`task setup -- --rename <old> <new>`) — not needed in v1; rename = edit state file + git mv.
- **Drift detection / orphan reconciliation** — owned by Phase 8 (`links:reconcile`, `packages:audit`). P1 lays no groundwork; the closed-world pattern is reintroduced via state sentinels in P8.
- **Header comment in `resolved.json`** with debug timestamp + source mtime — nice-to-have, not required.
- **`task manifest:diff <m1> <m2>`** for side-by-side machine comparison — deferred; can be added when the pain is real.
- **Interactive `task setup` prompt** — explicitly rejected in v1 (breaks CI). Deferred indefinitely; no use case.

</deferred>

---

*Phase: 01-manifest-engine-repository-skeleton*
*Context gathered: 2026-05-13*
