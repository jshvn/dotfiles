---
phase: 14-comment-doc-trim
plan: 03
status: complete
completed: 2026-05-19
requirements_addressed: [TRIM-03, TRIM-04, TRIM-05]
---

# Plan 14-03 -- Doc-Tier Trim + SC#5 Grep Gate

Closing wave of Phase 14. Fixed docs/MANIFEST.md drift, rewrote docs/README.md
to a 3-doc index, polished docs/SECURITY.md to past tense, deduplicated
README.md against CLAUDE.md (humans-only shape), ported Zsh startup order and
private-keys safety bullet to root CLAUDE.md, deleted `.claude/CLAUDE.md`,
and stripped 26 files of remaining `D-[0-9]+` planning-tag references to
satisfy the SC#5 closing assertion.

## Commits

| Hash      | Subject                                                                                |
|-----------|----------------------------------------------------------------------------------------|
| `5206494` | docs(14-03): purge motd drift + Phase-1 note + CLI form from docs/MANIFEST.md          |
| `efc4186` | docs(14-03): rewrite docs/README.md to 3-doc index + SECURITY.md past-tense polish     |
| `2818516` | docs(14-03): rewrite README.md to humans-only shape (D-06 dedup)                       |
| `5a37672` | docs(14-03): port Zsh startup order + private-keys safety from .claude/CLAUDE.md       |
| `9c6572e` | docs(14-03): delete .claude/CLAUDE.md (D-06; D-07 PASS; no fallback)                   |
| `ff8a6e6` | refactor(14-03): strip remaining SC#5 grep-gate matches across READMEs + configs       |

6 commits across 5 tasks (Task 4 split into 2 commits: port + delete; Task 5
SC#5 strip across 26 files folded into a single commit).

## Per-task evidence

### Task 1 -- docs/MANIFEST.md

- 5 `motd` sites removed (lines 33, 67, 137, 152, 491)
- Phase-1 note admonition removed (lines 461-464)
- CLI examples rewritten to public Phase 12 surface:
  `task setup -- <name>`, `task show:manifest`, `task audit:manifest`,
  `task test:manifest`
- `(Phase 5)` parenthetical stripped from a `packages/<name>.rb` reference
- `D-06 preserved` and `(D-06)` references removed from verify-model + MAS
  Required-fields table

### Task 2 -- docs/README.md + docs/SECURITY.md polish

- docs/README.md: 7 lines -> 5 lines (3-doc index; MIGRATION.md + CUTOVER.md
  references gone)
- docs/SECURITY.md: 4 future-tense Phase-N references rewritten to past tense
  / current-locations references (identity layer, claude/hooks/, docs/MACHINES.md)

### Task 3 -- README.md humans-only

- Before: 79 lines. After: 43 lines (-36).
- Removed: manifest-model deep-dive, "Where to Add Things" table, AI-agent
  prose, `.claude/CLAUDE.md` reference
- Added: 5-command surface, docs/ section, `[CLAUDE.md](CLAUDE.md)`
  contributing pointer
- Header-overlap: **0 shared `##` headers** between README.md and CLAUDE.md
  (target was <= 2)

### Task 4 -- .claude/CLAUDE.md deletion + content port

- Ported to root CLAUDE.md:
  - New `### Zsh startup order` subsection under §Rules (compact 4-line block
    naming the .zshenv -> .zprofile -> .zshrc -> .zlogin -> .zlogout chain)
  - New §Don't Do bullet: "Don't commit private keys. `identity/ssh/keys/`
    contains public keys only."
- Trimmed 2 lines from kebab-case examples to stay under 220-line ceiling
- Final `wc -l CLAUDE.md` = **220** (at the ceiling)
- `.claude/CLAUDE.md` deleted via `git rm` (125 lines removed)
- Cross-reference scan: `git grep .claude/CLAUDE.md -- ':!.planning/'` returns
  only the global `claude/CLAUDE.md` generic Claude-Code documentation line
  ("Project-level `.claude/CLAUDE.md` overrides these defaults.") -- that file
  is the symlink source for `~/.config/claude/CLAUDE.md` and documents Claude
  Code's project-override mechanism generically, not a hardcoded path
  consumer. Left in place.

### Task 5 -- SC#5 grep gate + full-suite gate

The initial SC#5 gate surfaced 49 matches across 25 files (the Plan 14-02
strip manifest did not include subdirectory READMEs, identity files,
manifests, `packages/*.rb`, `os/defaults/_apply_verify.zsh`, or the
LINT-08 fixture taskfiles). Per the plan's RED-case spec, each match was
rewritten to preserve the WHY and drop the `D-[0-9]+` / `Gap [0-9]+` /
`v1 bug` planning tag. Single commit (`ff8a6e6`) covers all 26 files.

Files touched in the SC#5 strip-pass (alphabetical):

```
.gitignore
claude/README.md
configs/README.md
configs/eza/README.md
configs/motd/README.md
configs/tlrc/README.md
docs/MANIFEST.md
identity/README.md
identity/git/config
identity/git/identities/atium
identity/git/identities/personal
identity/git/identities/work
identity/ssh/identities/personal
identity/ssh/identities/work
manifests/defaults.toml
manifests/machines/atium.toml
os/README.md
os/defaults/_apply_verify.zsh
packages/README.md
packages/core.rb
packages/gui.rb
shell/README.md
taskfiles/README.md
taskfiles/lint.yml
taskfiles/test/lint-fixtures/08a-banner-parity-fail/Taskfile.yml
taskfiles/test/lint-fixtures/08b-banner-parity-ok/Taskfile.yml
```

## Closing assertions (Phase 14 SC#1-5 + auxiliary gates)

| Gate                           | Command                                                                                         | Result    |
|--------------------------------|-------------------------------------------------------------------------------------------------|-----------|
| SC#5 grep gate                 | `git grep -E 'v1 (bug\|finding\|leftover)\|Gap [0-9]+\|D-[0-9]+\|UAT [Gg]ap' -- ':!.planning/'` | **PASS**  |
| Header-overlap (TRIM-04 SC#4)  | `comm -12 <(grep '^##' README.md \| sort -u) <(grep '^##' CLAUDE.md \| sort -u) \| wc -l`       | **0**     |
| .claude/CLAUDE.md deletion     | `test ! -f .claude/CLAUDE.md`                                                                   | **PASS**  |
| CLAUDE.md size                 | `wc -l CLAUDE.md`                                                                               | **220**   |
| `task lint`                    | run-all                                                                                         | **exit 0**|
| `task test`                    | run-all (11 fixtures + 8 hook smokes)                                                           | **exit 0**|
| `task install`                 | full pipeline (links + packages verify + claude + macos + reconcile)                            | **exit 0**|
| `task validate`                | full validation suite                                                                           | **exit 0**|

## Phase 14 ROADMAP SC#1-5

| SC | Description                                                  | Status |
|----|--------------------------------------------------------------|--------|
| 1  | 14-METRICS.md aggregate % reduction > 0 (Plan 14-02)         | **PASS** (52% reduction across 42 files) |
| 2  | Banner shape consistent across all stripped files (14-02)    | **PASS** |
| 3  | docs/ reviewed; obsolete content removed (14-03 Tasks 1-2)   | **PASS** |
| 4  | README/CLAUDE.md/.claude dedup (14-03 Tasks 3-4)             | **PASS** (header overlap = 0; .claude/CLAUDE.md deleted) |
| 5  | SC#5 grep gate returns PASS (14-03 Task 5)                   | **PASS** |

## Notes

- Plan 14-02's strip manifest scoped to taskfiles + `.zsh` files; the
  README.md / config / TOML / `.rb` files surfaced under the SC#5 grep gate
  in this plan and were swept up in commit `ff8a6e6`. The Plan 14-02
  manifest could have included these from the start; recording the gap so
  future per-file-strip plans honor the SC#5 grep scope (`:!.planning/`
  exclusion is repo-wide, not file-list-scoped).
- The IDE diagnostics on `taskfiles/test/lint-fixtures/08*/Taskfile.yml`
  (`status: [false]` is "Incorrect type. Expected string") are pre-existing
  LSP-only schema strictness; go-task accepts the form at runtime and
  `task test` passes (all 11 fixtures green). Not a regression from this
  plan's comment edits.

## Phase 14 close

Phase 14 is complete. All three plans landed; SC#1-5 all green; full suite
exits 0 on every commit and at plan close. Ready for `/gsd-verify-work`.
v2.1 milestone is closeable from here.
