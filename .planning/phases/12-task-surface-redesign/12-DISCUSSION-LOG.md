# Phase 12: Task Surface Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** 12-task-surface-redesign
**Areas discussed:** Curation criteria, perf:/shell: dual alias, Naming convention, Bare `task` output

---

## Curation criteria

### Q1: Per-component install/validate visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Public -- operator can re-run any layer | Keep per-component installs/validates public for targeted re-runs | |
| Internal -- only `task install` and `task validate` are public | Hide per-component tasks; force everything through aggregators | check |
| Split -- install public, validate internal | Per-component installs surface; validates internal | |

**User's choice:** Internal -- only `task install` and `task validate` are public
**Notes:** Strict curation rule applied uniformly.

### Q2: Diagnostic tool visibility (manifest:show, claude:status, packages:audit, links:reconcile)

| Option | Description | Selected |
|--------|-------------|----------|
| Public -- they're how you debug | Keep diagnostics as-is | |
| Public, but renamed under a clearer namespace | Move under `show:`/`audit:`/etc. for discoverability | check |
| Internal -- only top-level commands are public | Apply strict rule to diagnostics too | |

**User's choice:** Public, but renamed under a clearer namespace

### Q3: Diagnostic namespace choice

| Option | Description | Selected |
|--------|-------------|----------|
| Two namespaces: `show:` (state) + `audit:` (drift) | Surfaces intent; operator learns one verb | check |
| One namespace: `info:` (state + drift) | Single discovery prefix; smaller learning curve | |
| Keep per-component namespace, just unhide them | No rename move; cleaner descs, same names | |

**User's choice:** Two namespaces: `show:` (state) + `audit:` (drift)

### Q4: Dual-purpose tasks (manifest:validate, claude:update)

| Option | Description | Selected |
|--------|-------------|----------|
| Dual-shape: internal pipeline name + public audit/refresh name | manifest:validate stays internal; audit:manifest public; claude:update -> refresh:claude | check |
| Internal-only for both | Hide both; operator uses `task install` for refresh | |
| Public-only for both | Surface both directly | |

**User's choice:** Dual-shape both -- internal pipeline + public audit/refresh name

---

## perf: vs shell: dual alias

### Q1: Drop `perf:` namespace?

| Option | Description | Selected |
|--------|-------------|----------|
| Drop `perf:`. Rename `perf:shell` and update SHEL-12 reference | Single `shell:` namespace; rename the cold-start task | check |
| Keep dual-alias -- muscle memory matters | Accept the awkward `shell:shell` line | |
| Drop `shell:`, keep `perf:` | Reverse direction; rename `shell:validate` to `perf:validate` | |

**User's choice:** Drop `perf:` and rename the cold-start task under `shell:`

### Q2: New name for the cold-start gate

| Option | Description | Selected |
|--------|-------------|----------|
| `shell:perf` | Symmetric with `shell:validate` | |
| `shell:startup-time` | Describes what it measures; more discoverable | check |
| `shell:bench` | Short generic framing | |
| Keep `shell:shell` | Don't rename inside the file | |

**User's choice:** `shell:startup-time`
**Notes:** Confirmed via `git grep` -- no `.github/workflows/` exists, so SHEL-12 references are entirely in-repo (Taskfile.yml, taskfiles/README.md, taskfiles/shell.yml header, shell/README.md).

---

## Naming convention

### Q1: Internal task name churn scope

| Option | Description | Selected |
|--------|-------------|----------|
| Normalize internal names too -- audit pass is the right moment | Fix internal naming inconsistencies during the rename pass | check |
| Freeze internal names -- only rename what's surfaced publicly | Minimum-churn rule | |
| Normalize only the outliers | Fix worst offenders only | |

**User's choice:** Normalize internal names too -- audit pass is the right moment

### Q2: Aggregator naming pattern

| Option | Description | Selected |
|--------|-------------|----------|
| `<ns>:install` everywhere | Universal verb-pattern for install aggregators | check |
| `<ns>:all` everywhere | Generalize the descriptive `:all` form | |
| Action-named per namespace | Pick what each aggregator actually does | |

**User's choice:** `<ns>:install` everywhere
**Notes:** Rename `links:all` -> `links:install`; add new `macos:install` aggregator.

### Q3: Per-target sub-install task naming style

| Option | Description | Selected |
|--------|-------------|----------|
| Keep noun-style | `links:zsh` reads as 'links: the zsh layer' | |
| Verb-first: `<ns>:install-<target>` | `links:install-zsh`, `identity:install-ssh`, etc. | check |
| Drop the prefix; deeper namespace | `links:zsh:install` -- max explicit, may collide | |

**User's choice:** Verb-first: `<ns>:install-<target>`
**Notes:** `macos:defaults` -> `macos:apply-defaults` (non-install action); `macos:shell` -> `macos:install-shell` (login-shell registration is still install).

### Q4: lint:* and test:* sub-task visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Aggregator-only public; sub-checks internal | Only `task lint` and `task test` are public | check |
| Sub-checks public -- debugging tools | Surface every individual lint check / test group | |
| Aggregator public, sub-checks runnable but undocumented | internal: true but invocable by name | |

**User's choice:** Aggregator-only public; sub-checks internal

---

## Bare `task` output

### Q1: What bare `task` prints

| Option | Description | Selected |
|--------|-------------|----------|
| Plain `task --list` of all public tasks | Single source of truth via `internal: true` | |
| Hand-curated tiered menu | Structured 'common tasks' menu | |
| Two-tier: top-level commands prominent, namespaces under fold | Middle ground -- commands first, namespaces grouped | check |

**User's choice:** Two-tier: top-level commands prominent, namespaces under fold

### Q2: Two-tier menu shape

| Option | Description | Selected |
|--------|-------------|----------|
| Commands top, one-line per namespace below | Compact; namespace summary lines | check |
| Commands top, sub-namespaces listed individually below | Max visibility; longer output | |
| Commands top, prose 'getting started' line below | Friendliest tone; mixed prose | |

**User's choice:** Commands top, one-line per namespace below

### Q3: Implementation of the curated banner

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-rendered echo block in `default:` cmd | Simplest; maintainer updates banner | check |
| Generated from a YAML manifest | Drift-resistant; more machinery | |
| Use `task --list` output filtered/grouped via awk/grep | No hand-maintained list; depends on go-task output stability | |

**User's choice:** Hand-rendered echo block in `default:` cmd

### Q4: Drift mitigation for the banner

| Option | Description | Selected |
|--------|-------------|----------|
| Add a lint check: every public top-level task must appear in `default:`'s banner | Extend taskfiles/lint.yml; catches drift | check |
| Accept the drift risk -- it's a small surface | Trust the operator to notice | |
| Auto-regenerate the banner from `task --list -j` (JSON) | No banner to maintain; depends on go-task JSON format | |

**User's choice:** Add a lint check enforcing banner parity

---

## Claude's Discretion

(See CONTEXT.md `<decisions>` -> "Claude's Discretion" section for the full list. Highlights:)

- Whether `task install` invokes the new `macos:install` aggregator or keeps calling `macos:apply-defaults` + `macos:install-shell` as separate steps (D-09).
- Exact wording of every renamed task's `desc:` string; whether to strip phase markers (P5/P7/SHEL-12/etc.) during this touch or leave for Phase 14 TRIM-01.
- Plan breakdown (one big plan vs split by namespace boundary).
- Whether to update `.claude/CLAUDE.md` "Quick Reference" section as part of this phase or defer to Phase 14 TRIM-04.
- Internal-vs-public verdict on `manifest:resolve` (recommendation: internal -- `show:manifest` and `audit:manifest` cover the diagnostic use case).
- Whether `manifest:test` / `manifest:test:add-machine` move under `test:` namespace.

## Deferred Ideas

- Renaming `manifest:resolve` (e.g., to `manifest:compile` or `setup:resolve`) -- planner's discretion if undertaken.
- Adding a `task help` or `task doctor` top-level command (out of scope -- net-new functionality).
- Renaming top-level commands (rejected -- operator muscle memory binds).
- `task uninstall` / rollback command (v2.x).
- A `task surface:audit` programmatic public-set check (rejected -- D-13 banner-parity check covers the common drift class).
- Phase 14 TRIM-04 README/CLAUDE.md dedup (explicitly deferred to Phase 14).
- `desc:` string trimming (Phase 14 TRIM-01, with Phase-12-touch flexibility).
- Zsh shell-completion tuned to the curated surface (out of scope; would read from `task --list -j`).

---

*Discussion log generated 2026-05-18.*
