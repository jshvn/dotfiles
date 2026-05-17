# Phase 9: v1-Drop Audit - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Read-only investigation. Every v1 leftover file (8 taskfiles, 4 Brewfiles, the entire `zsh/` tree, and v1-only doc fragments) is read in full and every defined task / aliased command / function / theme behavior is enumerated in a single `AUDIT.md` keep-list / drop-list / already-ported report. Zero code changes in this phase. The report is the source-of-truth that Phase 10 will work through and Phase 11 will gate on before deleting v1 files.

</domain>

<decisions>
## Implementation Decisions

### AUDIT.md Shape

- **D-01:** AUDIT.md is sectioned by leftover category at the top level: `## Taskfiles`, `## Install Assets`, `## zsh/ Tree`, `## Docs`. Each section carries its own six-column table. Maps 1:1 to AUDIT-01..05 and lets Phase 10 work through it section-by-section.
- **D-02:** Row granularity inside the Taskfiles section is **one row per task**, not one row per taskfile. Matches AUDIT-04's "every defined task is enumerated" and SC#5's grep cross-reference test, where every task name returned by the regex must appear in AUDIT.md.
- **D-03:** Each table carries exactly the six SC#1-required columns: `file:line`, `purpose` (one sentence), `v2 status` (ported / partially-ported / dropped), `keep/drop` classification, `rationale`, `v2 owner`. No additional columns (no Phase 10 priority column, no evidence column). Phase 10 derives implementation order from the keep-list bullets at the top of the doc, not from a sort column.
- **D-04:** Top of AUDIT.md carries a `## Summary` section with: (a) a counts table (X tasks audited / Y keep / Z drop / W already-ported) and (b) an explicit bullet list of every keep item with its v2 owner file. The bullet list IS Phase 10's implementation queue — Phase 10 plans should iterate it directly.

### zsh/ vs shell/ Comparison Method

- **D-05:** When a function file exists in both trees (same name in `zsh/functions/<name>.zsh` and `shell/functions/<name>.zsh`): run `diff` and classify behaviorally — `identical`, `ported-with-documented-delta`, or `partial port (v2 missing behavior X)`. Filename-presence alone is NOT enough; the inside-the-file silent drift class is exactly what triggered this milestone.
- **D-06:** For aliases (v1 has `zsh/aliases/common/` + `zsh/aliases/personal/`; v2 has flat `shell/aliases/`): build the v1 effective-set per machine by concatenating `common/*.zsh` + the `personal/*.zsh` that would load under the personal profile, then diff that flattened set against `shell/aliases/*.zsh`. Captures both per-profile losses AND content drift inside same-named alias files. Alias-name-only comparison is rejected because it misses behavioral diffs (same alias name, different command).
- **D-07:** For `zsh/configs/` (ghostty, glow.yml, tlrc.toml, trippy.toml, condarc, motd_* data files) and `zsh/styles/` (eza_style.yaml, glow_style.json): diff each v1 file against its v2 sibling at the body level. Presence-only check rejected — operator hand-edits to v1 configs are exactly the drift class that needs catching.
- **D-08:** Six startup files (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`, `theme.zsh`): one AUDIT row per file. The `rationale` column lists each v1 block and its v2 disposition (e.g., "block ZDOTDIR write to /etc/zshenv = DROPPED in v2 — the milestone driver; MOTD synchronous fastfetch = replaced by cached lazy-load motd function; antigen apply = replaced by antidote bundle"). Surfaces every block-level decision without inflating to per-line rows.

### Already-Ported Threshold

- **D-09:** "Ported" means behavior-equivalent under the v2 manifest model on the same machine — same operator-visible outcome, even if the implementation changed (manifest gate replaces hostname check, `_dotfiles_feature` replaces `personal/` subdir, `{{.BREW_ZSH}}` replaces `$BREW_ZSH`, etc.). The bar is "on personal-laptop today, does it still work the same way?" — NOT "is the v1 code byte-equivalent to v2?". Strict code-equivalence is rejected because it would flag every intentional v2 improvement.
- **D-10:** When v2 explicitly fixes a v1 bug (`macos:shell:145` `$BREW_ZSH` bug, `.zprofile` hardcoded `"server"` hostname check, `agent-transparency.zsh` `local` at script scope), the row is classified `v2 status = ported, classification = drop` (drop the v1 source) and the `rationale` column names the bug and points to the v2 fix. The three-value v2-status enum stays intact.
- **D-11:** Stub taskfiles (`taskfiles/claude-stub.yml`, `taskfiles/brew-stub.yml`, `taskfiles/links-stub.yml`) are classified `v2 status = ported, classification = drop`. Rationale points to the v2 real file that superseded each (`taskfiles/claude.yml`, `taskfiles/packages.yml`, `taskfiles/links.yml`). They have no behavior of their own — they were scaffolds, and v2 replaced them with real files.
- **D-12:** v1 Brewfiles (`install/Brewfile.rb`, `install/Brewfile-personal.rb`, `install/Brewfile-work.rb`, `install/Brewfile-server.rb`) are audited at the package level: build the v1 effective package set per machine (`Brewfile.rb` + the matching `Brewfile-<profile>.rb`), build the v2 effective set per machine from `resolved.json` (`packages.brew.bundles` + `extra_packages`), then set-diff at the formula/cask/mas name. Any v1 package absent from v2's effective set on the same machine becomes a row (`v2 status = dropped`, `classification = keep|drop with rationale`). Skip-the-audit option is rejected — any silently-dropped package would slip past Phase 5's verification because PKGS verification only checks declared packages.

### Claude's Discretion
- Plan breakdown (one audit plan vs split by leftover category) was not selected for discussion. Planner has flexibility — recommendation is to split by section to map plan boundaries to AUDIT.md section boundaries, but a single-plan walk is also viable for a read-only phase.
- Scope of v1 doc review (AUDIT-05) was not deepened. Planner should cover `install/README.md`, anything in git history under the prior top-level `README.md`, and any doc fragments in `docs/` not part of the v2 set; deeper archeology in git history beyond the last shipping v1 commit is optional.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specs (locked decisions that bound the phase)
- `.planning/ROADMAP.md` §"Phase 9: v1-Drop Audit" — phase goal, depends-on, success criteria #1–#5, requirements list
- `.planning/REQUIREMENTS.md` §"Audit (v1-drop investigation)" — AUDIT-01 through AUDIT-05 with the exact taskfile / asset list
- `.planning/PROJECT.md` §"Current Milestone: v2.1 Cleanup" — milestone driver, the live `/etc/zshenv` ZDOTDIR finding, audit-first ordering rationale
- `.planning/STATE.md` — current position; v2.1 phase numbering carries on from v1.0

### Codebase maps (v1 era — they ARE the audit input)
- `.planning/codebase/STRUCTURE.md` — v1 directory layout including the exact `zsh/aliases/{common,personal}/` and `zsh/functions/` and `zsh/configs/`+`zsh/styles/` listings; v1 Brewfile-per-profile layout
- `.planning/codebase/CONCERNS.md` — known v1 bugs (the `macos:shell:145` `$BREW_ZSH` class, the `.zprofile` hardcoded "server" check, the `gsd-install` no-status-guard, agent-transparency `local`-at-script-scope). Every concern in this doc should map to an AUDIT.md row.
- `.planning/codebase/ARCHITECTURE.md` — five-layer model that informs the "v2 owner" column
- `.planning/codebase/CONVENTIONS.md` — v1 conventions; useful when classifying intentional improvements

### v1 leftover surface (the audit primary sources)
- `taskfiles/common.yml` — XDG dirs, ZDOTDIR `/etc/zshenv` write (lines 36–57, the milestone driver), zdotdir-validate (lines 80–95), antigen update
- `taskfiles/profile.yml` — profile selection, ensure, set, validate
- `taskfiles/profile-tasks.yml` — parameterized per-profile install/links/brew/validate
- `taskfiles/brew.yml` — v1 Homebrew install/update/bundle
- `taskfiles/claude-stub.yml` — Phase 7 scaffold (superseded by `taskfiles/claude.yml`)
- `taskfiles/brew-stub.yml` — Phase 5 scaffold (superseded by `taskfiles/packages.yml`)
- `taskfiles/links-stub.yml` — Phase 3 scaffold (superseded by `taskfiles/links.yml`)
- `taskfiles/macos.v1.yml.bak` — pre-v2 macOS defaults backup (contains the `$BREW_ZSH` bug line that Phase 6 D-11 documents)
- `install/Brewfile.rb` — v1 common packages
- `install/Brewfile-personal.rb` — v1 personal-profile packages
- `install/Brewfile-work.rb` — v1 work-profile packages
- `install/Brewfile-server.rb` — v1 server-profile packages
- `zsh/` — entire v1 shell tree: 6 startup files, 24 function files, aliases split common/+personal/, configs/, styles/, theme.zsh

### v2 surface (for comparison)
- `taskfiles/shell.yml`, `taskfiles/identity.yml`, `taskfiles/packages.yml`, `taskfiles/macos.yml`, `taskfiles/claude.yml`, `taskfiles/manifest.yml`, `taskfiles/lint.yml`, `taskfiles/links.yml`, `taskfiles/helpers.yml`, `taskfiles/test.yml`
- `install/messages.zsh`, `install/resolver.zsh`, `install/compose-brewfile.zsh`, `install/cutover-gate.zsh`, `install/test-hooks.zsh`
- `shell/` (flat aliases/, flat functions/, the 5 startup files + theme.zsh, configs/, styles/)
- `packages/core.rb`, `packages/gui.rb` (current v2 bundles)
- `manifests/defaults.toml`, `manifests/machines/<name>.toml` (× 4)
- `docs/` — `MANIFEST.md`, `SECURITY.md`, `CUTOVER.md`, `MIGRATION.md`, `MACHINES.md`, `README.md`

### Conventions docs (project-level rules)
- `CLAUDE.md` (project root) — the v2 manifest model, kebab-case feature-key `index` rule, `set -euo pipefail` rule, `status:` template-var rule, XDG paths
- `.claude/CLAUDE.md` — project structure and conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bash`/`diff`/`grep` pipelines — the audit is read-only investigation; no new tooling needed. SC#5's grep cross-reference command is the proof-of-coverage primitive.
- `.planning/codebase/CONCERNS.md` — pre-existing inventory of v1 issues; every entry here should map to an AUDIT.md row. Treat it as the seed list, not the whole list.
- `manifests/machines/*.toml` × 4 — the v1-vs-v2 effective-set comparison for aliases and Brewfiles is driven per-machine; the manifests define the four machines (personal-laptop, work-laptop, server-1, server-2) the audit must walk for the comparison.
- `install/resolver.zsh` — produces `resolved.json` per machine; running it for each machine name yields the v2 effective package set + feature gates the comparison needs.

### Established Patterns
- One-file-per-concept (taskfiles per concern, one function per file, one alias topic per file): the AUDIT.md section split mirrors this, with one row per discrete v1 unit.
- The six-column "what is it / what's its status / what should we do / why / who owns it" rationale shape is consistent with how prior PHASE-* / SUMMARY-* docs in this project structure findings. The AUDIT.md table follows that house style.
- "Behavior-equivalent on the same machine" matches how the v2 refactor described itself in PROJECT.md ("feature parity confirmed via `task validate` per machine"). The threshold for "ported" reuses that bar.

### Integration Points
- AUDIT.md keep-list at the top is the direct input to Phase 10's planning. Phase 10 plans should reference `AUDIT.md` keep-list bullets by exact text.
- AUDIT.md drop-list with rationale is Phase 11's deletion manifest. Phase 11 SC#1 names the eight taskfiles and `zsh/` tree to delete; AUDIT must confirm there is no live dependency BEFORE Phase 11 runs.
- AUDIT.md's "v2 owner" column feeds the file-modification map Phase 10's planner uses for its files_modified lists.

</code_context>

<specifics>
## Specific Ideas

- The `/etc/zshenv` ZDOTDIR write at `taskfiles/common.yml:36-57` is the milestone driver and the headline keep item. AUDIT.md should call it out explicitly in the summary keep-list with its v2 owner named (current expected owner per ROADMAP Phase 10 SC#1: `taskfiles/shell.yml` or equivalent — Phase 10 plan settles which).
- The v1 macos defaults backup file (`taskfiles/macos.v1.yml.bak`) contains the `$BREW_ZSH` shell-vs-template-var bug. The audit row for that file should explicitly cross-reference Phase 6's D-11 / D-03 fix-up so the rationale is auditable.
- Phase 7's TOOL-02 work ported `zsh/configs/{ghostty,glow,tlrc,trippy,condarc,motd_*}` to `configs/<tool>/`. The audit confirms these are byte-equivalent or names the delta; it does not re-validate symlinks (Phase 7's TOOL-04 strict mode already does that).
- The four machine manifests (`manifests/machines/personal-laptop.toml`, `work-laptop.toml`, `server-1.toml`, `server-2.toml`) drive the per-machine effective-set comparisons. Run `install/resolver.zsh` against each to produce a comparable `resolved.json` for the alias and Brewfile diffs.

</specifics>

<deferred>
## Deferred Ideas

- Adding a Phase 10 priority column or an evidence column to AUDIT.md was rejected for v2.1; if Phase 10 finds it hard to prioritize from the keep-list alone, a later milestone could add a priority annotation.
- A `zsh -x` trace-level comparison for the 6 startup files was rejected as overkill for read-only audit; if Phase 10 implementation surfaces unexpected order-of-operations bugs, that comparison can be done then.
- Plan breakdown gray area (one big plan vs split-by-category) was not selected for discussion — planner picks.
- Scope of v1 doc review (AUDIT-05) was not deepened — planner picks; baseline coverage is `install/README.md` + obvious doc fragments not present in v2 `docs/`.

</deferred>

---

*Phase: 9-v1-drop-audit*
*Context gathered: 2026-05-17*
