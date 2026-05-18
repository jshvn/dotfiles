# Phase 11: v1 Removal -- Pattern Map

**Mapped:** 2026-05-17
**Phase shape:** file-deletion + doc-rewrite (zero net-new code)
**Files analyzed:** ~26 (8 taskfile deletes, 1 tree delete, 4 Brewfile deletes, 1 helper delete, 2 doc deletes, ~10 edits, 1 verification artifact)
**Analogs found:** all primary patterns located in v2 surface or Phase 10 history

---

## File Classification

### Deletion targets (`git rm`)

| File / tree | Role | Data Flow | Closest analog (pattern source) |
|---|---|---|---|
| `taskfiles/common.yml` | delete (v1 taskfile) | n/a | Phase 10 callers-first ordering (commit `9c80e75` merge shape) |
| `taskfiles/profile.yml` | delete (v1 taskfile) | n/a | same |
| `taskfiles/brew.yml` | delete (v1 taskfile) | n/a | same |
| `taskfiles/profile-tasks.yml` | delete (v1 taskfile) | n/a | same |
| `taskfiles/claude-stub.yml` | delete (v1 stub) | n/a | same |
| `taskfiles/brew-stub.yml` | delete (v1 stub) | n/a | same |
| `taskfiles/links-stub.yml` | delete (v1 stub) | n/a | same |
| `taskfiles/macos.v1.yml.bak` | delete (parked v1) | n/a | same |
| `zsh/` (entire tree) | delete (v1 shell content) | n/a | Phase 10 PORT smoke proved no v2 caller |
| `install/Brewfile.rb` | delete (v1 brew) | n/a | composed-Brewfile pipeline owns this surface |
| `install/Brewfile-personal.rb` | delete (v1 brew) | n/a | same |
| `install/Brewfile-server.rb` | delete (v1 brew) | n/a | same |
| `install/Brewfile-work.rb` | delete (v1 brew) | n/a | same |
| `install/cutover-gate.zsh` | delete (cutover infra) | n/a | callers simplified first (Taskfile.yml + bootstrap.zsh) |
| `docs/CUTOVER.md` | delete (cutover doc) | n/a | no live caller after Taskfile.yml + README edits |
| `docs/MIGRATION.md` | delete (D-01) | n/a | no live caller; PROJECT.md owns milestone narrative |

### Edit targets (lines removed / paragraphs rewritten)

| File | Lines | Role | Analog (the surrounding code that stays) |
|---|---|---|---|
| `Taskfile.yml` | 22-26 (comment block) | edit (drop) | the include-table at lines 13-21 (the kept inverse of the deleted block) |
| `Taskfile.yml` | 237-311 (`cutover:ack` task) | edit (drop) | the `validate:` task at 161-234 and `install:` at 313-361 (the neighbour tasks defining v2 shape) |
| `Taskfile.yml` | 319-328 (`install:` precondition) | edit (drop) | `install:` task body lines 313-361 minus the precondition |
| `bootstrap.zsh` | 105-112 (Step 4 cutover block) | edit (drop) | the Step 1/2/3 tool-install blocks above (lines 53-103) define the surrounding shape |
| `README.md` | 26-37 (fresh-install procedure) | edit (rewrite) | the surrounding `## What This Is` (1-22) and `## Where to Add Things` (47-58) sections set the prose register |
| `README.md` | 64 (CUTOVER.md doc bullet) | edit (drop) | the surrounding 5 doc bullets at 62-67 |
| `docs/SECURITY.md` | 16 (cutover-ack mention) | edit (rewrite) | the paragraph at lines 11-18 defining scope |
| `taskfiles/lint.yml` | 24 (cutover comment) | edit (drop) | surrounding banner at 1-33 |
| `taskfiles/README.md` | 25-29 (Phase 3 leftover sentence) | edit (rewrite/drop) | the surrounding `## Key files` bullets at 11-36 |
| `os/defaults/dock.zsh` | 34 (LINT-05 citation) | edit (drop clause) | `install/compose-brewfile.zsh` (the canonical LINT-05 exemplar) |
| `os/defaults/finder.zsh` | 40 | edit (drop clause) | same |
| `os/defaults/input.zsh` | 39 | edit (drop clause) | same |
| `os/defaults/screenshots.zsh` | 43 | edit (drop clause) | same |
| `os/defaults/security.zsh` | 54 | edit (drop clause) | same |
| `os/shell-registration.zsh` | 54 | edit (drop clause) | same |

### Create target

| File | Role | Analog |
|---|---|---|
| `.planning/phases/11-v1-removal/11-VERIFICATION.md` | create | `.planning/phases/10-v1-drop-remediation/10-VERIFICATION.md` |

### CONTEXT.md miscalls (planner-visible)

| Claim in CONTEXT.md `<canonical_refs>` | Actual on-disk state |
|---|---|
| D-07 lists `identity/ssh/identities/server-{1,2}` and `identity/ssh/keys/server-{1,2}.pub` as needing rewrites | These four files **do not exist**. `identity/ssh/identities/` contains `personal, work, atium, none`; `identity/ssh/keys/` contains `personal.pub, atium.pub, .gitignore`. None of them contain the string "cutover". D-07 scope is **empty**; planner should record this and skip the SSH-rewrite step. |

---

## Pattern Assignments

### Deletion-target pattern (the 8 v1 taskfiles, `zsh/`, 4 Brewfiles, `install/cutover-gate.zsh`, `docs/CUTOVER.md`, `docs/MIGRATION.md`)

**Analog:** Phase 10 merge / commit shape (`git log --oneline .planning/phases/10-v1-drop-remediation/` -- summary commits hold context, each commit leaves a green tree).

**Pattern shape per CONTEXT.md D-04 ordering:**

1. Callers simplified first (Taskfile.yml + bootstrap.zsh edits BEFORE `install/cutover-gate.zsh` delete).
2. Each delete is a separate `git rm <path>` commit (or a small batch where files are independent of each other -- the 8 v1 taskfiles are not included by root Taskfile.yml so they delete as one batch safely).
3. Commit subject: `chore(11): remove <thing>` (matches the project commit format `<type>(<scope>): <summary>` < 75 chars per global CLAUDE.md).
4. After every commit: `task lint:taskfile` exits at the same documented baseline (24 failures -- pre-existing) AND `task --list` succeeds.

**What to mirror:** callers-first ordering and green-tree-per-commit discipline.
**What's different:** there is no PORT-N "implement first" half -- Phase 10 was port-then-keep, Phase 11 is simplify-then-delete.

---

### `Taskfile.yml:237-311` (the `cutover:ack` task body)

**Analog:** the neighbour `validate:` task at lines 161-234 and `install:` task at lines 313-361. These define the v2 task shape that must remain consistent post-edit (`# lint-allow: cmds-without-status` marker above each top-level task, `status: [false]` for aggregators, `desc:` line one-liner).

**Excerpt of v2 shape that stays (Taskfile.yml:313-361, kept around `cutover:ack` removal):**

```yaml
  # lint-allow: cmds-without-status
  install:
    desc: "Install dotfiles for active machine (canonical entry)"
    summary: |
      task install IS task update -- there is no separate update pipeline.
      Re-running is a no-op (every subtask has a status: block per LINT-01).
    status: [false]
    preconditions:
      - sh: |
          export DOTFILEDIR="{{.TASKFILE_DIR}}"
          source "${DOTFILEDIR}/install/cutover-gate.zsh"   # <-- 4 lines removed
          cutover_gate_check                                #
        msg: "cutover-ack gate failed -- see error above"  #
    deps: [manifest:resolve]
    cmds:
      - task: links:all
      - task: packages:install
      ...
```

**What to mirror:** the surrounding `install:` task body must remain idiomatic v2 (deps + cmds list + final `success` message); `deps: [manifest:resolve]` stays.
**What's different:** the whole `preconditions:` key disappears (no other v2 task body retains the `cutover_gate_check` source-and-call shape).

---

### `Taskfile.yml:22-26` (the "v1 leftover taskfiles" comment block)

**Analog:** the include-table comment immediately above at lines 13-21 -- this is the kept inverse. Post-edit the file should read like the v2-only include manifest (one alias per real taskfile, no v1 mention).

**Excerpt of kept comment (Taskfile.yml:13-21):**

```yaml
# Includes:
#   - manifest (P1, real)
#   - lint     (P2, real)
#   - links    (P3, real)
#   - perf     (P3, real)
#   - identity (P4, real)
#   - packages (P5, real)
#   - claude   (stub; P7 wires real bodies)
#   - macos    (P6, real)
```

**What to mirror:** the table-style banner format (no surrounding `# ===` rule needed -- the file already uses `# =====` outer banners).
**What's different:** the deleted block has no replacement -- it just disappears. The `claude` line at 20 may also be updated from "(stub; P7 wires real bodies)" to "(P7, real)" for accuracy since Phase 7 has shipped; planner discretion.

---

### `bootstrap.zsh:105-112` (Step 4 cutover-ack gate)

**Analog:** the Step 1/2/3 tool-install blocks above (lines 53-103) define the surrounding zsh-script shape -- `# --- Step N: <name>` header comment, no `set -e` re-statement (already set at line 27), inline messages-library calls.

**Excerpt of v2 shape that stays (bootstrap.zsh:114-124):**

```zsh
# --- Step 5: next-step hint (D-03)         <-- renumber to Step 4 per D
# Bootstrap is tools-only: no task setup, no task install invocation.
# The user completes setup by running the two commands below.
echo
success "Bootstrap complete. Next steps:"
echo "  task setup -- <machine-name>     # write machine state"
echo "  task install                     # install dotfiles"
```

**What to mirror:** the Step-numbering scheme, the `success` + `info` message style, the trailing `Available machines:` enumeration.
**What's different:** the inserted block at 105-112 sources an external library (`install/cutover-gate.zsh`) -- no other step in `bootstrap.zsh` does this. Removing it returns the script to a pure-tools-acquisition shape consistent with the file's own header banner (lines 3-25 "Tools-only: does NOT take a machine name; does NOT invoke task setup").

---

### `README.md:26-37` (fresh-install procedure with `task cutover:ack`)

**Analog:** the kept `## What This Is` section (lines 1-22) and `## Where to Add Things` table (47-58) -- these define the prose register (plain, declarative, no marketing voice; backticks for code/paths; "see <file>" cross-references in the closing paragraph).

**Excerpt of kept prose register (README.md:1-22):**

```markdown
# dotfiles

## What This Is

macOS dotfiles managed with go-task, manifest-driven per-machine
configuration via TOML, and an XDG base directory layout throughout.
[...]
The complete schema for both TOML files (sections, types, deep-merge
rules, worked examples) lives in `docs/MANIFEST.md`.
```

**What to mirror:** declarative voice, line-wrap at ~70 chars, file/path backticks, closing "see X" cross-references.
**What's different:** the post-edit `## Fresh Machine Setup` block drops one line from the fenced shell example AND removes the entire preceding paragraph explaining why `task cutover:ack` is required (lines 26-31). The replacement paragraph should be 1-2 sentences naming `task setup` then `task install` with no acknowledgment step.

---

### LINT-05 pattern-citation edits (6 files)

**Analog:** `install/compose-brewfile.zsh` (the recommended exemplar per D-06).

**The current citation (identical across all 6 files, e.g. `os/defaults/security.zsh:50-54`):**

```zsh
# messages.zsh references a bare $DOTFILES_MESSAGES_LOADED in its double-source
# guard; under set -u that would abort. Pre-initialize the guard variable and
# the caller-supplied DOTFILEDIR var so this script is safe to source from a
# `set -euo pipefail` taskfile heredoc (matches install/resolver.zsh +
# install/compose-brewfile.zsh + install/cutover-gate.zsh pattern).
```

**The minimal D-06 edit (drop the trailing clause):**

```zsh
# ... safe to source from a `set -euo pipefail` taskfile heredoc
# (matches install/resolver.zsh + install/compose-brewfile.zsh pattern).
```

**Structural fingerprint of `install/compose-brewfile.zsh` (the surviving exemplar) -- verifies it really is the right replacement:**

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/compose-brewfile.zsh -- compose per-machine Brewfile from manifest
# Sourced from: taskfiles/packages.yml (packages:compose, packages:install ...)
# Reads:  $XDG_STATE_HOME/dotfiles/resolved.json   (compiled manifest)
# Writes: $XDG_CACHE_HOME/dotfiles/Brewfile        (atomic mktemp+mv)
# -----------------------------------------------------------------------------

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task packages:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi
```

Fingerprint match against the LINT-05 shape being taught (file-header banner + `set -euo pipefail` + `:?` parameter assertion on `DOTFILEDIR` + double-source guard + `error`/`success` calls into messages.zsh): **all five fingerprint elements present**. `install/compose-brewfile.zsh` is the structurally correct replacement exemplar.

**What to mirror:** the rest of the comment paragraph stays byte-identical.
**What's different:** only the ` + install/cutover-gate.zsh` clause is removed (single in-line edit per file, no surrounding context shift).

---

### `docs/SECURITY.md:16` (cutover-ack-gate mention)

**Analog:** the immediately surrounding paragraph at lines 11-18 (scope statement). Rewrite that lops the cutover-ack sentence and lets the paragraph end at the prior cross-reference.

**Excerpt of current text (lines 11-18):**

```markdown
Scope is intentionally narrow: only the three tools the bootstrap
script acquires (Homebrew, go-task, yq) and the audit signals the
script emits before doing so. SSH key handling is deferred to Phase 4
(identity layer); Claude hook secret-scanning is deferred to Phase 7
hardening; per-machine credential management is documented in
`docs/MACHINES.md` (Phase 8). The cutover-ack gate (`task cutover:ack`)
referenced by the gate library is owned by Phase 8 CUTV-03 and is
described in `docs/CUTOVER.md` (also Phase 8).
```

**What to mirror:** the declarative scope-statement voice (Phase-N attributions on deferred subjects).
**What's different:** the last sentence ("The cutover-ack gate ...") is removed entirely. Optional planner choice per CONTEXT D-08: append a one-sentence replacement naming the manifest model as the post-cutover security boundary (CONTEXT explicit: "the security boundary is now bootstrap.zsh's HTTPS-only trust chain + the manifest model itself").

---

### `taskfiles/lint.yml:24` (cutover-ack comment in file-header banner)

**Analog:** the kept surrounding banner at lines 1-33. The banner format is `# ===`-style outer rules + indented enforcement-rule bullets; the read-only / no-gate note at lines 23-24 currently reads:

```yaml
# Read-only: no manifest dependency, no resolved.json dependency, no
# cutover-ack gate (per D-09). Runs without task setup -- <machine>.
```

**What to mirror:** the banner's bullet voice (declarative, named-decision references).
**What's different:** drop the `, no cutover-ack gate (per D-09)` clause; the rest of the line is true and stays.

---

### `taskfiles/README.md:25-29` (v1 leftover description sentence)

**Analog:** the surrounding `## Key files` Phase-N bullets at lines 11-36. The Phase 3 bullet currently reads:

```markdown
- **Phase 3 (real).** `common.yml` -- XDG + ZDOTDIR install.
  `links.yml` -- shell + antidote symlinks via `_:safe-link`.
  `shell.yml` -- `task perf:shell` (SHEL-12 cold-start gate via
  hyperfine). `profile.yml`, `profile-tasks.yml` -- v1 leftovers retained
  for the cutover window; Phase 8 retires them.
```

**What to mirror:** the per-Phase bullet shape with one-line file descriptions.
**What's different:** drop the `profile.yml`, `profile-tasks.yml` sentence entirely; also drop the entire Phase 4-7 stubs bullet at lines 30-34 (those files are deleted by RMV-01). Replace with a clean Phase 3 bullet naming only the real v2 files (`common.yml` mention also goes -- that file is deleted by RMV-01). Planner may also need to revise the opening sentence at line 4-5 ("common, profile, helpers") to drop the v1 names.

---

### `11-VERIFICATION.md` (the create target)

**Analog:** `.planning/phases/10-v1-drop-remediation/10-VERIFICATION.md` (Phase 10's verification artifact -- the established gating-doc shape).

**Structural fingerprint to mirror (from 10-VERIFICATION.md):**

```markdown
---
status: passed
phase: 11
verified: <date>
must_haves_score: <N>/<N>
requirement_ids: [RMV-01, RMV-02, RMV-03, RMV-04, RMV-05, RMV-06, RMV-07]
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 11: v1 Removal -- Verification Report

**Phase Goal:** [paste from ROADMAP P11]
**Verified:** <date>
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ... | VERIFIED | ... |

**Score:** N/N truths verified.

### Required Artifacts
### Key Link Verification
### Behavioral Spot-Checks
### Requirements Coverage
### Probe Execution
### Anti-Patterns Found
### Human Verification Required
### Deferred Items
### Gaps Summary
```

**Plus the two D-05 mandatory sections from CONTEXT.md:**

1. **Steady-state `task install` no-op on personal-laptop** -- terminal output capture (or summarized one-line-per-subtask render per Claude's Discretion) showing the simplified `install:` graph runs through `links:all -> packages:install -> claude:install -> macos:defaults -> macos:shell -> packages:verify -> links:reconcile --warn-only`, every subtask hits its status block, exit 0, no `cutover:ack` step ever invoked. Format mirrors 10-SMOKE.md `## Run Log` table (Date | Machine | Result | Notes columns).
2. **SC#5 grep gate report** -- `git grep -E '\bv1\b|profile_suffix|DOTFILES_PROFILE|cutover'` excluding `.planning/` and `.claude/` returns ONLY references the operator has deliberately kept. Run BEFORE the verification commit so the report itself does not show. Each retained ref is listed with rationale.

**What to mirror:** YAML frontmatter shape (`status`, `phase`, `verified`, `must_haves_score`, `requirement_ids`, `re_verification` keys), the H1 + `## Goal Achievement` + `### Observable Truths` table-of-evidence skeleton, the sub-section list (Required Artifacts, Key Link Verification, Behavioral Spot-Checks, Requirements Coverage, Probe Execution, Anti-Patterns Found, Human Verification Required, Deferred Items, Gaps Summary), and the closing `_Verified: <date>_ / _Verifier: Claude (gsd-verifier)_` italic footer.

**What's different:** Phase 11 verification has no PORT-* requirement coverage (RMV-01..07 only). The "Acknowledgment: Prerequisite Revert Commits" section from 10-VERIFICATION.md does NOT apply to Phase 11 (no reverts expected). The D-05 steady-state install capture is new content not in 10-VERIFICATION.md -- it goes under `### Behavioral Spot-Checks` (or as a dedicated `### Steady-State Install Capture` subsection -- planner discretion). The SC#5 grep gate report is also new content; goes under either `### Anti-Patterns Found` or a dedicated `### Grep Gate Report` subsection.

---

## Shared Patterns

### Commit-message format

**Source:** global CLAUDE.md `## Git` section + recent project history (`git log --oneline`).
**Apply to:** every Phase 11 commit.

```
<type>(<scope>): <summary>
```

Where `<type>` is `chore` for deletes and `docs` for the verification artifact + doc-rewrite commits, `<scope>` is `11` (or the more specific subsystem, e.g. `taskfiles`, `bootstrap`, `readme`, `docs`), and `<summary>` is imperative-mood < 75 chars. Examples that fit:

- `chore(11): remove cutover-gate library`
- `chore(11): drop v1 leftover taskfiles`
- `chore(11): delete zsh/ tree`
- `chore(11): remove v1 install Brewfiles`
- `docs(11): rewrite fresh-install README, drop cutover-ack`
- `docs(11): retire cutover/migration docs`
- `docs(11): record verification`

No AI-attribution trailers anywhere (hooks enforce; global + project CLAUDE.md both forbid).

### File-header banner (every executable `.zsh`)

**Source:** `install/compose-brewfile.zsh:1-20` and `os/defaults/security.zsh:1-46`.
**Apply to:** kept .zsh files only -- Phase 11 does NOT create new .zsh files. The pattern is informational: any edit to an .zsh file must preserve the existing banner. The 6 LINT-05 citation edits all preserve their file headers.

### Green-tree-per-commit gate

**Source:** Phase 10 commit sequence (per 10-VERIFICATION.md Observable Truth #3).
**Apply to:** every Phase 11 commit.

The gate command is `task lint:taskfile`. Pre-Phase-11 baseline: **24 failures** (4 LINT-02 in v1 leftover taskfiles + 5 LINT-03a in v1 leftovers + the long-standing `shell:shell` lint-allow placement + 1 deliberate negative fixture). After each Phase 11 commit:
- Deleting v1 taskfiles must REDUCE the failure count (the file no longer exists to scan).
- The final post-Phase-11 baseline should approach the irreducible minimum: the deliberate negative fixture + the `shell:shell` lint-allow placement issue + whatever remains in `taskfiles/manifest.yml` / `taskfiles/packages.yml` / `taskfiles/claude.yml` (those v2 files are not Phase 11 scope per ROADMAP and stay until Phase 13).

The aggregate `task install` smoke (verified at the verification commit) is the secondary gate -- it should remain invokable end-to-end at every commit, even though it's only formally re-run at verification time.

---

## No Analog Found / Skip Items

| Item | Reason |
|------|--------|
| D-07 SSH-identity rewrites (`identity/ssh/identities/server-{1,2}`, `identity/ssh/keys/server-{1,2}.pub`) | These four files do not exist on disk. `identity/ssh/identities/` contains only `personal, work, atium, none`; `identity/ssh/keys/` contains only `personal.pub, atium.pub, .gitignore`. None of the kept files contain the string "cutover". D-07 is a no-op for Phase 11 implementation; planner should record the absent-file finding in the plan and skip the rewrite step. The SC#5 grep gate will confirm no "cutover" residue exists in `identity/`. |

---

## Metadata

**Analog search scope:** `Taskfile.yml`, `taskfiles/`, `install/`, `os/`, `bootstrap.zsh`, `README.md`, `docs/`, `identity/`, `.planning/phases/10-*/`.
**Files scanned:** ~30 (15 read in full, 15 grepped for citation lines).
**Pattern extraction date:** 2026-05-17.
