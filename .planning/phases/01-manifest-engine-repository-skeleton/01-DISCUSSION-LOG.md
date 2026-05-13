# Phase 1: Manifest Engine + Repository Skeleton - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 01-manifest-engine-repository-skeleton
**Areas discussed:** TOML schema shape & required fields, Repository skeleton scope, resolved.json cache lifecycle

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| TOML schema shape & required fields | What MUST a machine manifest declare vs. what's optional? Drives what manifest:validate enforces. | yes |
| Schema validation mechanism | Hand-rolled zsh vs. JSON Schema + taplo/ajv. | (skipped — Claude's discretion) |
| Repository skeleton scope (which dirs in P1?) | Create ALL dirs vs. only P1-populated. READMEs as stubs vs. fleshed out. | yes |
| resolved.json cache lifecycle | When does the cache rebuild? What if state file is missing? | yes |

---

## TOML Schema Shape & Required Fields

### Sub-question 1: Should the v1 machine manifest include a `[platform]` block?

| Option | Description | Selected |
|--------|-------------|----------|
| Omit `[platform]` entirely in v1 | Resolver assumes darwin everywhere. Cleaner schema; risk: migration cost when Linux returns. | |
| Keep `[platform]` required, lock os=darwin | Validator rejects anything but os=darwin in v1. When Linux arrives, validator rule changes — no schema migration. | yes |
| Keep `[platform]` optional, default darwin | Resolver fills os=darwin if absent. Risk: two ways to do the same thing. | |

**User's choice:** Keep `[platform]` required, lock os=darwin.
**Notes:** Trades a small redundancy in v1 manifests for zero schema migration when Linux v2 lands.

### Sub-question 2: Required minimum shape for a machine manifest?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: description, platform.os, identity.git | Smallest viable manifest; features/packages inherit defaults. Risk: silent inheritance of sensitive fields. | |
| Standard: description, platform.os, features, packages.brew.bundles, identity.git, identity.ssh | Every machine must make explicit choices about features and packages. No hidden inheritance surprises. | yes |
| Recommend a third option | — | |

**User's choice:** Standard required-field set.
**Notes:** Pitfall #1 from research (drift) is the dominant risk — explicit declarations beat hidden defaults.

### Sub-question 3: Policy on unknown keys in manifests?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail | manifest:validate rejects unknown keys. Catches typos immediately. Costs: allowlist maintenance. | |
| Warn, don't block | Print warning, exit 0. Friendlier; typos can silently drop a feature. | yes |
| Hard fail with --allow-unknown escape hatch | Default hard fail; flag downgrades to warn. Lets you stage new fields across commits. | |

**User's choice:** Warn, don't block.
**Notes:** Trade-off accepted: lighter validator, one stale-key class of bug stays possible. Revisit if it bites.

### Sub-question 4: How does `defaults.toml` interact with required fields?

| Option | Description | Selected |
|--------|-------------|----------|
| Skeleton-only — defaults documents shape, fills few values | Every machine declares everything. Defaults is shape + global truths. | |
| Filled defaults — sensible values for everything | Machine overrides few keys. Risk: forgotten field silently inherits possibly-wrong default. | |
| Hybrid — defaults provides safe values; required fields still must be declared per machine | Resolver always produces complete resolved.json, but validator requires machine file to declare all required fields. | yes |

**User's choice:** Hybrid.
**Notes:** Best of both — silent inheritance of sensitive fields is the failure mode being guarded against.

---

## Repository Skeleton Scope

### Sub-question 1: Which top-level directories in Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Create ALL directories now (full skeleton) | All top-level dirs created in P1 with placeholder READMEs. | yes |
| Create only what P1 populates | manifests/, taskfiles/, install/, docs/ only. Other phases create their own dirs later. | |
| Full skeleton, but no READMEs (.gitkeep only) | All dirs exist; READMEs land when each phase populates the dir. | |

**User's choice:** Create ALL directories now.
**Notes:** Locks the repo shape on day 1; AI agents see the full layout immediately.

### Sub-question 2: v1 nesting for `packages/` and `os/`?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep nesting (packages/brew/, os/darwin/) — future-proof | Verbose now, zero migration cost when Linux returns. | |
| Flatten for v1 (packages/, os/defaults/) — simpler now | Matches macOS-only spirit of v1; v2 migration cost when Linux arrives. | yes |
| Mixed: packages/brew/ nested, os/ flat | Nest packages because Linux package managers are the most likely v2 sibling; flat os/ because macOS is the only branch ever envisioned. | |

**User's choice:** Flatten for v1.
**Notes:** Extends the macOS-only-v1 principle into the directory structure. v2 migration accepted as a known cost.

### Sub-question 3: README depth for placeholder directories?

| Option | Description | Selected |
|--------|-------------|----------|
| Stub READMEs: "Populated by Phase X" + one-line purpose | ~10 lines per stub. Phase that populates the dir replaces the stub. | yes |
| Full READMEs now (purpose, structure, how-to-add) | Locks structure in advance; risk that populating phase invalidates pattern claims. | |
| Stub READMEs + planned-final-shape comment | Stub plus code-block sketch of final layout. Lets you eyeball without prescriptive how-to-add text. | |

**User's choice:** Stub READMEs.
**Notes:** Minimum lock-in now; full READMEs land with content.

---

## resolved.json Cache Lifecycle

### Sub-question 1: When is `resolved.json` rebuilt?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto: precondition of every downstream task | mtime-based status: check. Never stale, never manual. ~50ms overhead per task. | yes |
| Manual: user runs `task manifest:resolve` | Explicit, no hidden work. Risk: "why isn't my change taking effect?" footgun. | |
| Hybrid: auto-rebuild via mtime + `--force` flag | Same as auto, plus a manual override for when mtime lies. | |

**User's choice:** Auto: precondition of every downstream task.
**Notes:** AI agents can't forget to invoke resolve. The exact cost of mtime check is negligible against the cost of a single stale-cache bug.

### Sub-question 2: What if `task install` runs but no `task setup` has been run yet?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail with actionable error | Exit non-zero with command to fix + list of available machines. No fallback. | yes |
| Interactive prompt: "Which machine?" | Friendly but breaks CI / non-TTY contexts. | |
| Hard fail + `task install -- --machine <name>` shortcut | Same as hard fail plus a one-shot setup+install flag. | |

**User's choice:** Hard fail with actionable error.
**Notes:** Aligns with the "no hostname guessing" project value. CI-safe by default.

### Sub-question 3: Inspection support for `task manifest:show`?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: print active machine's resolved.json | Single command, covers MFST-07. | |
| Standard: `--machine <name>` flag | Resolve any machine without switching state file. Enables side-by-side comparison. | yes |
| Standard + `task manifest:diff <m1> <m2>` | Adds structural diff command between two machines. | |

**User's choice:** Standard with `--machine` flag.
**Notes:** Diff command deferred until pain is real.

---

## Wrap-Up

| Option | Description | Selected |
|--------|-------------|----------|
| Ready — write CONTEXT.md | Three areas discussed; researcher resolves remaining open items. | yes |
| One more area — schema validation mechanism | Lock JSON Schema vs. hand-rolled zsh validator explicitly. | |
| One more area — machine naming convention | Lock allowed characters, max length, rename flow. | |
| Other — something missed | — | |

**User's choice:** Ready.

---

## Claude's Discretion

- **Schema validation mechanism** — User deferred. Default: hand-rolled zsh checks in `resolver.zsh` for v1. JSON Schema deferred to v2 backlog (`TOOL-V2-01`).
- **Machine naming convention** — User deferred. Default: kebab-case (project CLAUDE.md convention). No explicit rename flow in v1.
- **Test runner mechanics** — `task manifest:test` implementation detail (loop + diff). Diff tool choice (`diff`, `jd`, `dyff`) left to planner.
- **`docs/MANIFEST.md` structure** — Outline suggested in decisions; planner refines.
- **Header comment in `resolved.json`** — Optional debug aid; nice-to-have, not required.

## Deferred Ideas

- JSON Schema for editor validation (taplo, vscode-even-better-toml) — already in v2 backlog as `TOOL-V2-01`.
- Manifest rename flow (`task setup -- --rename <old> <new>`).
- Drift detection / orphan reconciliation — Phase 8 (`links:reconcile`, `packages:audit`).
- `task manifest:diff <m1> <m2>` for side-by-side comparison.
- Interactive `task setup` prompt — explicitly rejected (breaks CI).
- Header comment in `resolved.json` with debug timestamp.
