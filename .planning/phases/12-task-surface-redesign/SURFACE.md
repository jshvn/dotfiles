# Phase 12: Task Surface Classification (SURF-01)

**Captured:** 2026-05-18
**Snapshot source:** `task --list` output, 47 public entries (post-Phase-11 surface)
**Purpose:** SURF-01 deliverable -- the six-column classification table that lists every public task on today's `task --list` surface with verdict, proposed new name, `internal: true?` flag, rationale (citing D-NN), and pre-populated callsites column. House style mirrors Phase 9's `AUDIT.md` per D-14. Plans 02-08 iterate this file row-by-row to apply renames + visibility changes; Phase 13 reviewers read it as the post-phase audit trail of "what was renamed, what went internal, and why".

## Summary

| Metric | Count |
|--------|-------|
| Tasks classified | 55 |
| keep-as-is | 6 |
| rename | 13 |
| mark-internal | 19 |
| rename + mark-internal | 14 |
| create | 1 |
| create + mark-internal | 2 |
| remove | 0 |

Row totals: 47 public tasks from snapshot + 5 `defaults:<concern>` (visible via include alias as `macos:defaults:<concern>`, but the literal task names live in `taskfiles/macos.yml`) + 3 NEW (`macos:install`, `lint:banner-parity`, `audit:manifest`) = 55.

### Renames at a glance

- `links:all` -> `links:install`
- `links:zsh` -> `links:install-zsh`
- `links:claude` -> `links:install-claude`
- `links:configs` -> `links:install-configs`
- `links:reconcile` -> `audit:links`
- `identity:git` -> `identity:install-git`
- `identity:ssh` -> `identity:install-ssh`
- `identity:one-password-agent` -> `identity:install-one-password-agent`
- `claude:status` -> `show:claude`
- `claude:update` -> `refresh:claude`
- `manifest:show` -> `show:manifest`
- `manifest:test` -> `test:manifest`
- `manifest:test:add-machine` -> `test:add-machine`
- `packages:audit` -> `audit:packages`
- `macos:defaults` -> `macos:apply-defaults`
- `macos:shell` -> `macos:install-shell`
- `defaults:dock` -> `apply-defaults:dock`
- `defaults:finder` -> `apply-defaults:finder`
- `defaults:input` -> `apply-defaults:input`
- `defaults:screenshots` -> `apply-defaults:screenshots`
- `defaults:security` -> `apply-defaults:security`
- `perf:shell` -> `shell:startup-time`
- `shell:shell` -> `shell:startup-time`
- `perf:validate` -> `shell:validate` (dual-alias collapse; D-05)

Twenty-four rename entries above; verdict-column "rename" + "rename + mark-internal" totals = 13 + 14 = 27. The delta is the three `(NEW)` rows (`macos:install`, `lint:banner-parity`, `audit:manifest`) which use `create*` verdicts, not `rename`, and the `perf:shell` / `perf:validate` / `shell:shell` rows which each contribute a rename verdict but collapse to two distinct destination names (`shell:startup-time`, `shell:validate`). Count discrepancies are an artifact of the dual-alias `perf:` include retirement (D-05).

## Top-Level Commands

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `default` | rename | (rewrite cmds to D-12 two-tier banner; keep task key) | no | D-12 two-tier curated menu; bare-task is the operator landing page | Taskfile.yml:120-127 |
| `install` | keep-as-is | | no | D-01 top-level operator command; canonical entry per PROJECT.md | Taskfile.yml:227-265; README.md:27,34; docs/MANIFEST.md:418; .claude/CLAUDE.md:15 |
| `setup` | keep-as-is | | no | D-01 top-level operator command; delegates to `manifest:setup` per Claude's-Discretion | Taskfile.yml:137-141; README.md:26,33; .claude/CLAUDE.md:18; CLAUDE.md:116 |
| `test` | keep-as-is | | no | D-01 + D-04 top-level operator command; aggregates `manifest:test` + `test:hooks` | Taskfile.yml:144-148 |
| `validate` | keep-as-is | | no | D-01 top-level operator command; aggregator iteration loop at Taskfile.yml:206,213 | Taskfile.yml:150-225; .claude/CLAUDE.md:16 |

## claude:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `claude:install` | mark-internal | | yes | D-01 per-component install is internal; called by root `task install` pipeline | taskfiles/claude.yml; Taskfile.yml:237 |
| `claude:status` | rename | `show:claude` | no | D-02 diagnostic (state-printer) moves to `show:` namespace | taskfiles/claude.yml |
| `claude:update` | rename | `refresh:claude` | no | D-03 explicit refresh moves to `refresh:` namespace; not in `task install` | taskfiles/claude.yml:23 |
| `claude:validate` | mark-internal | | yes | D-01 per-component validate is internal; called by validate aggregator at Taskfile.yml:206 | taskfiles/claude.yml |

## identity:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `identity:install` | mark-internal | | yes | D-01 per-component install is internal; called by root install and `links:all` callee chain | taskfiles/identity.yml:110-117; taskfiles/links.yml:129 |
| `identity:git` | rename + mark-internal | `identity:install-git` | yes | D-10 verb-first sub-target; D-01 internal; sibling `task: git` call in identity:install must update | taskfiles/identity.yml:115,127-173; identity/git/config (none); identity/ssh/agent.toml:4 (doc) |
| `identity:ssh` | rename + mark-internal | `identity:install-ssh` | yes | D-10 verb-first sub-target; D-01 internal; sibling `task: ssh` call in identity:install must update | taskfiles/identity.yml:116,220-279; identity/ssh/config:6 (doc) |
| `identity:one-password-agent` | rename + mark-internal | `identity:install-one-password-agent` | yes | D-10 verb-first sub-target; D-11 longest name acceptable; sibling `task: one-password-agent` call must update | taskfiles/identity.yml:117,289-295; identity/ssh/agent.toml:4 (doc) |
| `identity:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213 | taskfiles/identity.yml:306-312 |

## links:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `links:all` | rename + mark-internal | `links:install` | yes | D-09 aggregator pattern (`<ns>:install`); D-01 per-component install is internal | Taskfile.yml:235; taskfiles/links.yml:7,120-131; taskfiles/identity.yml:39 (comment); taskfiles/README.md (no direct ref but adjacent context) |
| `links:zsh` | rename + mark-internal | `links:install-zsh` | yes | D-10 verb-first sub-target; D-01 internal; sibling `task: zsh` call in links:all must update | taskfiles/links.yml:123,137-157; taskfiles/links.yml:333-334,345 (comments) |
| `links:claude` | rename + mark-internal | `links:install-claude` | yes | D-10 verb-first sub-target; D-01 internal; sibling `task: claude` call in links:all must update | taskfiles/links.yml:130,260-281; taskfiles/links.yml:334,346 (comments) |
| `links:configs` | rename + mark-internal | `links:install-configs` | yes | D-10 verb-first sub-target; D-01 internal; sibling `task: configs` call in links:all must update | taskfiles/links.yml:131,260+; taskfiles/links.yml:334,346 (comments) |
| `links:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213 | taskfiles/links.yml; taskfiles/README.md:25 (Phase 3 note) |
| `links:reconcile` | rename + mark-internal | `audit:links` | yes | D-02 diagnostic (drift-checker) moves to `audit:`; per B-2 the implementation stays internal in links.yml; public `audit:links` is a thin delegate in a new `taskfiles/audit.yml` (or aliased via include); single committed path | Taskfile.yml:254; taskfiles/links.yml:411,458,578 (self-refs); taskfiles/links.yml:77 (comment) |

## lint:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `lint:default` (alias `lint`) | keep-as-is | | no | D-04 lint aggregator is public; the `lint` alias is the operator entry | taskfiles/lint.yml:76-87; docs/SECURITY.md:138 |
| `lint:portability` | mark-internal | | yes | D-04 lint sub-check is internal; called by `lint:default` at taskfiles/lint.yml:82 | taskfiles/lint.yml:82,237-265 |
| `lint:shell-headers` | mark-internal | | yes | D-04 lint sub-check is internal; called by `lint:default` at taskfiles/lint.yml:81 | taskfiles/lint.yml:81,208-235 |
| `lint:syntax` | mark-internal | | yes | D-04 lint sub-check is internal; called by `lint:default` at taskfiles/lint.yml:79 | taskfiles/lint.yml:79,89-127 |
| `lint:taskfile` | mark-internal | | yes | D-04 lint sub-check is internal; called by `lint:default` at taskfiles/lint.yml:80 | taskfiles/lint.yml:80,129-205 |
| `lint:test-fixtures` | mark-internal | | yes | D-04 lint sub-check is internal (self-test of fixtures) | taskfiles/lint.yml:266-351; taskfiles/README.md:28 |
| `(NEW) lint:banner-parity` | create + mark-internal | `lint:banner-parity` | yes | D-13 enforces banner-vs-public-task-list parity; created by Plan 08 | taskfiles/lint.yml (new task); taskfiles/test/lint-fixtures/13-banner-parity-*/ (new fixtures) |

## macos:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `macos:defaults` | rename + mark-internal | `macos:apply-defaults` | yes | D-10 macOS uses `apply-` for non-install actions; D-01 per-component is internal; caller at Taskfile.yml:238 must update | Taskfile.yml:238; taskfiles/macos.yml:120-140; docs/MACHINES.md:67; manifests/defaults.toml:30,32-34 (comments) |
| `macos:shell` | rename + mark-internal | `macos:install-shell` | yes | D-10 verb-first sub-target (zsh login-shell registration IS an install action); caller at Taskfile.yml:239 must update | Taskfile.yml:239; taskfiles/macos.yml:222-255; os/shell-registration.zsh:12,37,55,62 (doc comments) |
| `macos:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213 | taskfiles/macos.yml:257-300 |
| `(NEW) macos:install` | create + mark-internal | `macos:install` | yes | D-09 NEW aggregator (`<ns>:install`); created by Plan 05; replaces lines 238-239 of Taskfile.yml install pipeline | taskfiles/macos.yml (new task); Taskfile.yml:238-239 (caller swap) |
| `defaults:dock` (surfaces as `macos:defaults:dock`) | rename | `apply-defaults:dock` (surfaces as `macos:apply-defaults:dock`) | (already internal) | D-10 lockstep rename with parent (`macos:defaults` -> `macos:apply-defaults`); B-9 empirical confirmation -- literal task name in macos.yml | taskfiles/macos.yml:130,142-154; manifests/defaults.toml:30 (comment); os/defaults/dock.zsh:9 (doc) |
| `defaults:finder` (surfaces as `macos:defaults:finder`) | rename | `apply-defaults:finder` (surfaces as `macos:apply-defaults:finder`) | (already internal) | D-10 lockstep rename with parent; B-9 empirical confirmation | taskfiles/macos.yml:131,156-168; os/defaults/finder.zsh:9 (doc) |
| `defaults:input` (surfaces as `macos:defaults:input`) | rename | `apply-defaults:input` (surfaces as `macos:apply-defaults:input`) | (already internal) | D-10 lockstep rename with parent; B-9 empirical confirmation | taskfiles/macos.yml:132,170-182; manifests/defaults.toml:32 (comment); os/defaults/input.zsh:14 (doc) |
| `defaults:screenshots` (surfaces as `macos:defaults:screenshots`) | rename | `apply-defaults:screenshots` (surfaces as `macos:apply-defaults:screenshots`) | (already internal) | D-10 lockstep rename with parent; B-9 empirical confirmation | taskfiles/macos.yml:133,184-196; manifests/defaults.toml:33 (comment); os/defaults/screenshots.zsh:12 (doc) |
| `defaults:security` (surfaces as `macos:defaults:security`) | rename | `apply-defaults:security` (surfaces as `macos:apply-defaults:security`) | (already internal) | D-10 lockstep rename with parent; B-9 empirical confirmation | taskfiles/macos.yml:134,198-220; manifests/defaults.toml:34 (comment); os/defaults/security.zsh:13 (doc) |

## manifest:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `manifest:resolve` | mark-internal | | yes | D-01 + Claude's-Discretion: operator can still invoke directly; `audit:manifest` covers diagnostic use case | taskfiles/manifest.yml; Taskfile.yml (`deps: [manifest:resolve]` lines 153,232 unaffected); .claude/CLAUDE.md:19 (doc: drop or rewrite) |
| `manifest:setup` | mark-internal | | yes | D-01 + Claude's-Discretion keeps `setup` top-level alias delegating to internal `manifest:setup` body | Taskfile.yml:140; taskfiles/manifest.yml |
| `manifest:show` | rename | `show:manifest` | no | D-02 diagnostic (state-printer) moves to `show:` namespace | taskfiles/manifest.yml:205 (self-ref comment); install/resolver.zsh:6,23,577 (comments); .claude/CLAUDE.md:20; docs/MANIFEST.md:470 |
| `manifest:test` | rename + mark-internal | `test:manifest` | yes | D-04 sub-task internal + Claude's-Discretion moves to `test:` namespace; caller at Taskfile.yml:147 must update | Taskfile.yml:147; taskfiles/manifest.yml; taskfiles/test.yml:9,15 (comments); docs/MANIFEST.md:472 |
| `manifest:test:add-machine` | rename + mark-internal | `test:add-machine` | yes | D-04 sub-task internal + Claude's-Discretion moves to `test:` namespace; move definition into taskfiles/test.yml | taskfiles/manifest.yml:571; taskfiles/test.yml (new home) |
| `manifest:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213; D-03 dual-shape via NEW public `audit:manifest` | taskfiles/manifest.yml; Taskfile.yml:206,213 |

## packages:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `packages:audit` | rename | `audit:packages` | no | D-02 diagnostic (drift-checker) moves to `audit:` namespace | taskfiles/packages.yml:454 (self-ref comment); taskfiles/packages.yml |
| `packages:compose` | mark-internal | | yes | D-01 per-component step is internal; called by `packages:install` | taskfiles/packages.yml |
| `packages:install` | mark-internal | | yes | D-01 per-component install is internal; called by root `task install` pipeline | Taskfile.yml:236; taskfiles/packages.yml |
| `packages:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213; wraps `packages:verify` | taskfiles/packages.yml |
| `packages:verify` | mark-internal | | yes | D-01 per-component step is internal; called by root install at Taskfile.yml:245 and by `packages:validate` (taskfiles/packages.yml:539) | Taskfile.yml:245; taskfiles/packages.yml:539; docs/MANIFEST.md:351,352,360,379 |

## perf:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `perf:shell` | rename | `shell:startup-time` | no | D-05 drops the `perf:` include alias (Taskfile.yml:82); D-06 cold-start gate renames; `perf:shell` and `shell:shell` collapse to the single new name | Taskfile.yml:82 (drop alias); taskfiles/shell.yml:12,61 (header + task); taskfiles/README.md:24,46; shell/README.md:43 |
| `perf:validate` | rename | `shell:validate` | yes | D-05 drops the `perf:` include alias; `perf:validate` and `shell:validate` collapse to the single `shell:validate`; D-01 marks it internal | Taskfile.yml:82 (drop alias); taskfiles/shell.yml:96; taskfiles/README.md:25 |

## shell:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `shell:shell` | rename | `shell:startup-time` | no | D-06 discoverable rename; D-05 perf-alias retirement collapses the dual surface to a single name | taskfiles/shell.yml:61; taskfiles/shell.yml:12 (header); shell/README.md:43 |
| `shell:validate` | mark-internal | | yes | D-01 per-component validate is internal; iterated by Taskfile.yml:206,213 | taskfiles/shell.yml:96; taskfiles/shell.yml:154 (comment); taskfiles/README.md:25,46 |

## test:

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `test:default` | mark-internal | | yes | D-04 test sub-task internal; aggregator-only public surface | taskfiles/test.yml |
| `test:hooks` | mark-internal | | yes | D-04 test sub-task internal; called by root `test` at Taskfile.yml:148 and by `test:default` at taskfiles/test.yml:48 | Taskfile.yml:148; taskfiles/test.yml:48 |

## Diagnostics (show: / audit: / refresh:)

_New public namespaces created by this phase. Tasks listed here are also referenced under their owning namespace section above; this section is the consolidated diagnostic view._

| task name (current) | verdict | new name (if renamed) | internal: true? | rationale | callsites to update |
|---------------------|---------|-----------------------|------------------|-----------|---------------------|
| `claude:status` | rename | `show:claude` | no | D-02 state-printer in `show:` namespace | (see `## claude:` row) |
| `manifest:show` | rename | `show:manifest` | no | D-02 state-printer in `show:` namespace | (see `## manifest:` row) |
| `packages:audit` | rename | `audit:packages` | no | D-02 drift-checker in `audit:` namespace | (see `## packages:` row) |
| `links:reconcile` | rename + mark-internal | `audit:links` | yes | D-02 drift-checker in `audit:` namespace; B-2 single committed path: impl internal, delegate public | (see `## links:` row) |
| `(NEW) audit:manifest` | create | `audit:manifest` | no | D-03 NEW public delegate of internal `manifest:validate`; one-cmd wrapper; created by Plan 07 | taskfiles/manifest.yml (or taskfiles/audit.yml); docs/MANIFEST.md:471 (update) |
| `claude:update` | rename | `refresh:claude` | no | D-03 explicit refresh in `refresh:` namespace (only `refresh:` member today) | (see `## claude:` row) |

## Decisions Cross-Reference

- **D-01** (strict pipeline-vs-operator split): justifies every per-component install/validate mark-internal -- 19 rows: `claude:install`, `claude:validate`, `identity:install`, `identity:install-git`, `identity:install-ssh`, `identity:install-one-password-agent`, `identity:validate`, `links:install`, `links:install-zsh`, `links:install-claude`, `links:install-configs`, `links:validate`, `macos:apply-defaults`, `macos:install-shell`, `macos:validate`, `macos:install`, `manifest:resolve`, `manifest:setup`, `manifest:validate`, `packages:compose`, `packages:install`, `packages:validate`, `packages:verify`, `shell:validate`. (Overlaps with rename verdicts where applicable.)
- **D-02** (diagnostics public under show: + audit:): justifies the diagnostic renames -- 4 rows: `claude:status` -> `show:claude`, `manifest:show` -> `show:manifest`, `packages:audit` -> `audit:packages`, `links:reconcile` -> `audit:links`.
- **D-03** (dual-shape pipeline/operator straddler): justifies 2 rows: NEW `audit:manifest` public delegate + `claude:update` -> `refresh:claude` rename.
- **D-04** (lint + test aggregator-only): justifies 9 rows -- `lint:portability`, `lint:shell-headers`, `lint:syntax`, `lint:taskfile`, `lint:test-fixtures`, NEW `lint:banner-parity`, `test:default`, `test:hooks`, plus the move-to-`test:` for `manifest:test` -> `test:manifest` and `manifest:test:add-machine` -> `test:add-machine`.
- **D-05** (drop `perf:` include alias): justifies the `perf:*` namespace retirement; affects 2 rows (`perf:shell`, `perf:validate`) and the includes block edit at Taskfile.yml:82.
- **D-06** (cold-start gate becomes `shell:startup-time`): justifies the rename of `shell:shell` -> `shell:startup-time` (and `perf:shell` collapse via D-05).
- **D-07** (in-repo SHEL-12 reference migration): the callsite map for `perf:shell` / `shell:shell` rename; touches `Taskfile.yml:82`, `taskfiles/README.md:24,46`, `taskfiles/shell.yml:12`, `shell/README.md:43`.
- **D-08** (normalize internal names too): umbrella decision for the cross-the-board normalization; every renamed row implicitly cites D-08 alongside its primary D.
- **D-09** (aggregator pattern `<ns>:install`): justifies `links:all` -> `links:install` + NEW `macos:install` aggregator + the `task install` pipeline edit at Taskfile.yml:238-239.
- **D-10** (sub-target verb-first `<ns>:install-<target>` / `apply-<target>`): justifies 8 rows -- `links:install-zsh`, `links:install-claude`, `links:install-configs`, `identity:install-git`, `identity:install-ssh`, `identity:install-one-password-agent`, `macos:apply-defaults`, `macos:install-shell`. Lockstep cascade to the 5 `defaults:<concern>` -> `apply-defaults:<concern>` rows (per B-9 empirical confirmation).
- **D-11** (`identity:install-one-password-agent` 32-char length tolerated): justifies the single longest-name row; no abbreviation.
- **D-12** (`default:` two-tier curated menu): justifies the `default` cmds-block rewrite at Taskfile.yml:120-127.
- **D-13** (lint-check enforces banner parity): justifies the NEW `lint:banner-parity` row.
- **D-14** (SURFACE.md 6-column shape): governs every column header in this document; verdict-enum lock is also D-14.
- **D-15** (callsites column is the planner's modification map): governs every "callsites to update" cell; pre-populated via `git grep -nE 'task [a-z][a-z0-9:-]+' README.md CLAUDE.md .claude/CLAUDE.md docs/ shell/README.md taskfiles/`.
