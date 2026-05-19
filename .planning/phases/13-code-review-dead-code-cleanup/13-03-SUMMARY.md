---
phase: 13-code-review-dead-code-cleanup
plan: 03
subsystem: code-review
tags: [code-review, dead-code, cleanup, manifest, taskfile, shell-startup]

requires:
  - phase: 13-code-review-dead-code-cleanup
    plan: 02
    provides: "13-REVIEW.md with 2 HIGH rows closed and 3 MEDIUM dead-code rows still open (rows 30/31/32)"
provides:
  - "Three MEDIUM dead-code rows (30, 31, 32) in 13-REVIEW.md annotated with closing short-SHAs"
  - "motd feature flag removed from manifests/defaults.toml and three machine TOMLs (had zero consumers)"
  - "Dead commit-task1.yml LINT-03a exemption removed from taskfiles/lint.yml"
  - "Unreachable Linux else-branch removed from shell/.zprofile (v1 is darwin-only)"
affects: [13-04-PLAN, 13-05-PLAN, 13-06-PLAN]

tech-stack:
  added: []
  patterns:
    - "Class B strict-removal per D-08: zero `git grep` callsites -> remove, with inline grep evidence in commit body"
    - "Class A allowlist preservation per D-08: shell/functions/motd.zsh kept (user-callable) while the flag-that-never-gated-it was removed"
    - "Per-removal verification gate: task lint && task test && task install --dry exit 0 after every commit"

key-files:
  created:
    - ".planning/phases/13-code-review-dead-code-cleanup/13-03-SUMMARY.md"
  modified:
    - "shell/.zprofile"
    - "taskfiles/lint.yml"
    - "manifests/defaults.toml"
    - "manifests/machines/personal-laptop.toml"
    - "manifests/machines/work-laptop.toml"
    - "manifests/machines/atium.toml"
    - ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md"

key-decisions:
  - "Three dead-code rows / six source files / one REVIEW.md edit -- well below the plan's implicit anti-scope-creep bound. No 13-03a/13-03b split needed."
  - "Class B removals batched one row per commit, then a single docs commit annotates REVIEW.md with all three closing SHAs. Per-row batching keeps each removal individually revertible (matches Phase 11/12 per-logical-unit commit discipline)."
  - "motd removal: README files (configs/README.md:19,46-48; configs/motd/README.md:29-30,37) and docs/MANIFEST.md:33,67,137,152,491 still reference the removed flag as if live. Out-of-scope for this plan (REVIEW.md row 16 for configs/README.md is MEDIUM/clarity already assigned to Plan 13-06; docs/MANIFEST.md schema-doc updates route to Plan 13-06 or Phase 14 TRIM-04 per D-11(a)). Documenting in this SUMMARY so Plan 13-06 (or 14) sees the trailer."
  - "Fixture manifests/test/fixtures/01-map-over-map/{defaults.toml,expected.json} contains motd=true as deep-merge test data. The fixture is self-contained (does NOT reference real manifests/defaults.toml) and tests live resolver deep-merge correctness; per D-10 the fixture is NOT orphan (the resolver code path it tests is alive). KEEP unchanged -- the data values are arbitrary; updating the key name would add noise without test-coverage benefit."
  - "shell/functions/motd.zsh PRESERVED under D-08 Class A (path matches shell/functions/*.zsh) -- the function is user-callable from interactive shells; the dead flag never gated it. shell/.zlogin:17 already invokes via `(( $+functions[motd] ))` which is the actual presence-gate."

requirements-completed: [REVW-03, REVW-06]

duration: ~15min
completed: 2026-05-18
---

# Phase 13 Plan 03: Dead-Code Removal Summary

**Three MEDIUM dead-code rows in 13-REVIEW.md closed with grep-verified zero-hit removals: motd feature flag dropped from 4 manifest TOMLs (no `_dotfiles_feature motd` consumer existed), the dead commit-task1.yml LINT-03a exemption removed from taskfiles/lint.yml (no such file ever existed), and the unreachable Linux else-branch removed from shell/.zprofile (v1 targets darwin only). Class A shell/functions/motd.zsh preserved; no orphan fixtures found; green tree after every commit.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-18 (worktree spawn, post wave-2)
- **Completed:** 2026-05-18 (Self-Check completion)
- **Tasks:** 2 (Task 1 inventory + grep verification; Task 2 batch removals + REVIEW.md annotation)
- **Files modified:** 7 source + planning files
- **Commits:** 4

## Removal Manifest (Task 1 output)

| REVIEW.md row | Symbol/branch | Class | Grep hits | Action |
|---------------|---------------|-------|-----------|--------|
| 30 | `motd = true` feature flag (defaults.toml + 3 machine TOMLs) | B | 0 live consumers (`_dotfiles_feature motd` 0 hits; `features.motd` 0 hits) | REMOVE |
| 31 | `[[ "$f" == *"commit-task"* ]] && continue` exemption (lint.yml) | B | 0 hits (`commit-task` outside this line; no file by that name exists) | REMOVE |
| 32 | `else / # Linux / DIRECTORY="/home/linuxbrew/.linuxbrew/bin/brew"` arm (.zprofile) | B | 0 hits (`linuxbrew` outside this single arm) | REMOVE |

**Class A rows:** None in this plan (no dead-code rows pointed at shell/functions/*.zsh or shell/aliases/*.zsh).

**Fixture audit:**
- `taskfiles/test/lint-fixtures/` -- 13 fixtures, every one maps to a live LINT-NN rule (LINT-02a/b/c, LINT-03a/b, LINT-04a/b, LINT-05a, LINT-07a, LINT-08a/b). **No orphan fixtures.**
- `manifests/test/fixtures/` -- 11 fixtures (6 positive deep-merge + 5 negative validator); every one exercises live resolver code. **No orphan fixtures.**
- `manifests/test/fixtures/01-map-over-map/` uses `motd = true` as test data; self-contained (does not reference real defaults.toml); tests live deep-merge mechanic; **KEEP** per D-10.

## Per-Commit Summary

| Commit | Type | Subject | REVIEW.md rows closed | Files touched |
|--------|------|---------|------------------------|----------------|
| `ebccf47` | refactor(13-03) | drop unreachable Linux branch from .zprofile -- closes REVIEW.md row 32 | row 32 | `shell/.zprofile` |
| `cdbab32` | refactor(13-03) | drop dead commit-task1.yml exemption from lint.yml -- closes REVIEW.md row 31 | row 31 | `taskfiles/lint.yml` |
| `edbbabd` | refactor(13-03) | drop dead motd feature flag from manifests -- closes REVIEW.md row 30 | row 30 | `manifests/defaults.toml`, `manifests/machines/personal-laptop.toml`, `manifests/machines/work-laptop.toml`, `manifests/machines/atium.toml` |
| `4d7ae25` | docs(13-03) | annotate REVIEW.md rows 30, 31, 32 closed by edbbabd, cdbab32, ebccf47 | rows 30 + 31 + 32 (annotation) | `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` |

## Grep Evidence (per the plan's must_haves)

### Row 32 (.zprofile Linux branch)
```
git grep -nE 'linuxbrew' -- '*.zsh' '*.yml' '*.toml' '*.rb' 'Brewfile*' '*.md' ':!.planning/'
(no output -- verified: 0 hits)
```

### Row 31 (lint.yml commit-task exemption)
```
git grep -nE 'commit-task' -- '*.zsh' '*.yml' '*.toml' '*.rb' 'Brewfile*' '*.md' ':!.planning/'
(no output -- verified: 0 hits)
find . -name 'commit-task*' -not -path './.git/*' -not -path './.planning/*'
(no output -- file never existed)
```

### Row 30 (motd feature flag)
```
# The flag itself (no live consumer)
git grep -nE '_dotfiles_feature[[:space:]]+motd' -- '*.zsh' '*.yml'
(no output -- verified: 0 hits)
git grep -nE 'features.*motd' -- '*.zsh' '*.yml'
(no output -- verified: 0 hits)
```

Remaining `motd` token references after Row 30 removal (all preserved per D-08):
- `shell/functions/motd.zsh` (Class A function, user-invokable -- PRESERVED)
- `configs/motd/motd_tron.txt`, `configs/motd/motd_sysinfo.jsonc` (runtime templates read by the function -- PRESERVED)
- `configs/README.md`, `configs/motd/README.md`, `docs/MANIFEST.md`: stale documentation references to the removed flag -- deferred to Plan 13-06 (REVIEW.md row 16 is already MEDIUM/clarity scoped to 13-06; docs/MANIFEST.md schema doc refresh routes to 13-06 or Phase 14 TRIM-04 per D-11(a))
- `manifests/test/fixtures/01-map-over-map/{defaults.toml,expected.json}`: self-contained fixture testing deep-merge mechanic -- KEEP per D-10
- `.claude/CLAUDE.md:43`: tool-list mention (refers to `configs/motd/` subdir, not the flag)

## Verification (green-tree gate after every commit)

| Commit | task lint | task test | task install --dry |
|--------|-----------|-----------|--------------------|
| `ebccf47` | exit 0 | exit 0 (11/11 fixtures + 9/9 hook smokes) | exit 0 |
| `cdbab32` | exit 0 (LINT-03a still enforces over real taskfiles) | exit 0 | exit 0 |
| `edbbabd` | exit 0 | exit 0 (manifest fixtures incl. 01-map-over-map self-contained pass) | exit 0 |
| `4d7ae25` | exit 0 | exit 0 | n/a (docs-only) |

Final resolved.json (`task show:manifest`) features block no longer contains `motd`. No regression in `task show:manifest`, `task validate`, or any test fixture.

## Accomplishments

- **Three dead-code rows closed**: Rows 30, 31, 32 each annotated with a closing short-SHA per the plan's REVW-03 / REVW-06 closure gate.
- **REVIEW.md closure check passes**: `grep -cE '^\|.*\| dead-code \|.*\|[[:space:]]*\|[[:space:]]*$' 13-REVIEW.md` returns 0.
- **Class A allowlist honored**: `shell/functions/motd.zsh` PRESERVED -- the actual `motd` function (user-callable from interactive shell) is untouched. Only the dead feature flag that never gated it was removed.
- **No orphan fixtures**: Both fixture directories (`taskfiles/test/lint-fixtures/` 13 fixtures; `manifests/test/fixtures/` 11 fixtures) audited; every fixture exercises a live code path. No fixture renames needed since Phase 12's renames did not touch any symbol referenced by the existing fixtures.
- **Green-tree gate held after every commit**: task lint, task test, and task install --dry all exit 0 after each of the four commits.

## Out-of-Scope Doc Cleanup (deferred trailers)

The motd flag removal (edbbabd) leaves the following documentation files stale; deferring per D-11(a):

| File | Stale claim | Defer target |
|------|-------------|--------------|
| `configs/README.md:19,46-48` | Lists `motd` row in the configs table; describes "motd runtime-read exception" tied to `features.motd` | Plan 13-06 (REVIEW.md row 16 already MEDIUM/clarity assigned there) |
| `configs/motd/README.md:29-30,37` | Claims motd function is "gated on this flag via `_dotfiles_feature motd`" (false) | Plan 13-06 (sibling of row 16) |
| `docs/MANIFEST.md:33,67,137,152,491` | Schema-doc examples + feature-flag table list `motd = true` | Plan 13-06 or Phase 14 TRIM-04 per D-11(a) |

These are documentation-only stalenesses (no runtime impact). The motd flag is gone from real manifests as of edbbabd; the runtime is correct. Doc text follows in 13-06.

## Deviations from Plan

### Auto-fixed Issues

None -- no Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations triggered. The three removals matched the plan's exact prescription (D-08 Class B with grep-verified zero hits); fixture audit returned the expected "no orphans" result.

### Adaptations (not deviations, documented above)

- Doc-text staleness in `configs/README.md`, `configs/motd/README.md`, `docs/MANIFEST.md` deliberately NOT updated by this plan; that scope belongs to Plan 13-06 / Phase 14 TRIM-04 per D-11(a). Plan 13-03's mandate is REVW-03 (dead-code removal with grep evidence) + REVW-06 (no orphan fixtures); README-narrative refresh is REVW-04 / MEDIUM/clarity / Phase 14 territory.
- Fixture `manifests/test/fixtures/01-map-over-map/` left unchanged despite containing `motd = true` as test data, because the fixture is self-contained (not referencing real manifests) and exercises live deep-merge resolver mechanics; updating the key name would add noise without test-coverage benefit (per D-10 conservative interpretation).

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** All three Class B dead-code rows removed exactly as the plan prescribed; REVIEW.md annotated; green tree at every step.

## Issues Encountered

None. Both `task lint && task test && task install --dry` exited 0 after every commit. The pre-existing LINT-05 portability hints (`dscl`, `defaults read/write`, `pbcopy`) in `os/`, `os/defaults/*`, and `shell/functions/{pubkey,sethostname}.zsh` continue to warn but are LINT-05-by-design-`exit 0` and pre-date this plan.

## User Setup Required

None. The motd flag removal is non-disruptive: no machine ever had a `_dotfiles_feature motd` gate consuming the flag, so removing it changes no runtime behavior. The `motd` function itself remains intact and continues to display at login via the unconditional `shell/.zlogin:17` presence-gate.

## Next Phase Readiness

- **Plan 13-04 (duplication consolidation) ready to start**: dead code is gone; the duplication patterns in REVIEW.md rows 20-27 (rule-of-three+ cases) operate on the now-leaner surface. None of Plan 13-03's edits touch the duplication candidate files (`install/*.zsh`, `os/defaults/*.zsh`, `taskfiles/manifest.yml`, `taskfiles/test.yml`, `Taskfile.yml`, `shell/aliases/{finder,ghostty}.zsh`).
- **Plan 13-05 (links target-match fix) ready to start**: REVIEW.md row 14 still carries `defer: Plan 13-05 (REVW-05)`; no row-30/31/32 edit touched `taskfiles/links.yml`.
- **Plan 13-06 (MEDIUM/LOW triage) inherits two doc-staleness trailers from this plan**: (a) update `configs/README.md` motd row + section; (b) update `configs/motd/README.md` to drop the `_dotfiles_feature motd` gate claim. Both stem from removing the motd flag here.

## Known Stubs

None. All edits replace dead code with absence; no placeholder data or empty-state stubs introduced.

## Threat Flags

None. The three removals only DROP code (no new network endpoint, auth path, file-access pattern, or schema change). The motd flag removal is a schema simplification (one fewer optional key); resolver semantics unchanged.

## Self-Check: PASSED

Verified before writing this section:

- `shell/.zprofile` no longer contains the `linuxbrew` else-branch (verified: 0 hits via grep).
- `taskfiles/lint.yml` no longer contains the `commit-task` exemption (verified: 0 hits via grep).
- `manifests/defaults.toml` no longer contains `motd = true` (verified: 0 hits via grep `^motd[[:space:]]*=` in real manifest files).
- `manifests/machines/{personal-laptop,work-laptop,atium}.toml` no longer contain `motd = true`.
- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` rows 30, 31, 32 each carry the expected short-SHA (`edbbabd`, `cdbab32`, `ebccf47` respectively).
- All four commits (`ebccf47`, `cdbab32`, `edbbabd`, `4d7ae25`) exist in `git log --oneline f90c124..HEAD` -- chronological order matches the plan's iteration order.
- `task lint && task test && task install --dry` exit 0 after each of the four commits.
- No modifications to STATE.md or ROADMAP.md (orchestrator owns those -- verified by `git diff --name-only` against the wave-3 base showing only the seven expected files).

---

*Phase: 13-code-review-dead-code-cleanup*
*Completed: 2026-05-18*
