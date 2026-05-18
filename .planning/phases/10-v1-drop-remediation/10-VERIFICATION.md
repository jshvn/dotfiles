---
status: passed
phase: 10
verified: 2026-05-17
must_haves_score: 9/9
requirement_ids: [PORT-01, PORT-02, PORT-03]
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 10: v1-Drop Remediation -- Verification Report

**Phase Goal:** Every "keep" item from Phase 9's AUDIT.md is implemented in v2 in the file the audit named as the v2 owner; fresh-machine install produces a fully-functional first shell (prompt, theme, aliases, functions, MOTD, `_dotfiles_feature`) without manual remediation.

**Verified:** 2026-05-17
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `task install` writes `/etc/zshenv` with `export ZDOTDIR="$HOME/.config/zsh"` on a fresh machine via `taskfiles/links.yml:zdotdir`; the `zdotdir` task uses a `{{.ZDOTDIR}}` template-var status block (LINT-02 compliant) | VERIFIED | `taskfiles/links.yml:177-196` defines internal `zdotdir` task; the status block at line 196 is `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null`. Three-branch cmds heredoc at lines 184-194 mirrors v1 `taskfiles/common.yml:42-53` (file-absent -> sudo tee; line-absent -> sudo tee -a; else info no-op). Dispatched from `links:zsh` via `- task: zdotdir` at line 150. /etc/zshenv on the developer machine confirmed to carry `export ZDOTDIR="/Users/josh/.config/zsh"` (rendered template). |
| 2 | Re-running `task install` on a converged machine does NOT prompt for sudo (idempotent status block) | VERIFIED | Operator-verified PASS in 10-SMOKE.md Run Log (2026-05-17): "second `task links:zsh` invocation was silent (no sudo prompt) -- the new `zdotdir` task's `grep -qF` status block short-circuited cleanly." Status block uses `{{.ZDOTDIR}}` (template-resolved at task-graph build time), not `$ZDOTDIR` -- not the v1 macos:shell:145 bug class. |
| 3 | `task lint:taskfile` exits 0 against the new code (zero `$VAR` references in any new status block); pre-existing failures are out of scope | VERIFIED | Ran `task lint:taskfile` -- exits 24 (matches documented baseline). The 24 failures break down: LINT-02 in `taskfiles/{common,claude,manifest,packages}.yml` (4 files, pre-existing v1 leftovers Phase 11 deletes); LINT-03a in `taskfiles/{brew,common,manifest,profile-tasks,profile}.yml` plus the long-standing `shell:shell` lint-allow comment placement issue; LINT-03b in `taskfiles/test/lint-fixtures/03b-bare-ln/Taskfile.yml` (deliberate negative fixture). NEW Phase 10 code in `taskfiles/links.yml` (zdotdir task) and `taskfiles/shell.yml` (validate task) is reported PASS by LINT-02. No new failures introduced. |
| 4 | `task shell:validate` exists, exits 0 on a healthy machine, and exits non-zero when `/etc/zshenv` is missing the ZDOTDIR line | VERIFIED | `taskfiles/shell.yml:96-163` defines new `validate` task; ran `task -t taskfiles/shell.yml validate` -- exits 0 with seven green check marks (XDG config/data/state/cache homes + ZDOTDIR dir + /etc/zshenv ZDOTDIR line + DOTFILES_MACHINE state file). Negative test (sudo mv /etc/zshenv aside) operator-verified PASS in 10-SMOKE.md Run Log (2026-05-17): "task shell:validate printed cross ZDOTDIR not configured in /etc/zshenv and exited 1." failures-counter + `exit "$failures"` pattern at line 163 (NOT broken-exit-code `_:check-dir`). |
| 5 | `task validate` summary table contains a `shell` row | VERIFIED | Ran `task validate` -- summary table prints `manifest, identity, links, macos, packages, claude, shell` (all seven green check marks). Both aggregator for-loops at `Taskfile.yml:216` and `:223` end with `manifest identity links macos packages claude shell; do` (count = 2, Landmine 5 protection satisfied). |
| 6 | `task perf:shell` still works (SHEL-12 cold-start CI gate preserved via dual-alias include of taskfiles/shell.yml) | VERIFIED | `Taskfile.yml:92-93` declares both `perf: ./taskfiles/shell.yml` (legacy) and `shell: ./taskfiles/shell.yml` (primary). `task --list-all` reports BOTH `perf:shell` (Measure cold interactive zsh startup time) and `shell:validate` (Validate shell layer ...). Dual-alias side effect (`perf:validate` + `shell:shell`) is documented and accepted per D-06. |
| 7 | AUDIT.md row `install/Brewfile-personal.rb:72` reclassified `keep` -> `drop`; counts read Keep 2 / Drop 100; keep-list bullet removed | VERIFIED | `.planning/phases/09-v1-drop-audit/AUDIT.md:12-13` reads `\| Keep \| 2 \|` and `\| Drop \| 100 \|`. `.planning/phases/09-v1-drop-audit/AUDIT.md:18-22` contains exactly two keep-list bullets (both `taskfiles/common.yml` rows); the Things3 bullet is removed. `.planning/phases/09-v1-drop-audit/AUDIT.md:78` shows `\| install/Brewfile-personal.rb:72 \| ... \| ported \| drop \|` with new rationale text matching RESEARCH.md verbatim. |
| 8 | `manifests/machines/personal-laptop.toml:67` remains unchanged: `{ id = 904280696, name = "Things3" }` | VERIFIED | `manifests/machines/personal-laptop.toml:67` reads `  { id = 904280696, name = "Things3" },`. `git log --follow --oneline -- manifests/machines/personal-laptop.toml` shows the most recent commit is `1844e2f fix(packages): declare claude-code cask for laptops` (pre-Phase-10); no commits modify this file during Phase 10. D-07 honored. |
| 9 | `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` exists, documents the fresh-shell smoke procedure (seven assertions: $ZDOTDIR, $DOTFILES_MACHINE, prompt, _dotfiles_feature, alias listing, motd, no command-not-found), AND contains a Run Log table with operator's PASS entry | VERIFIED | File exists; H1 `# Phase 10: First-Shell Smoke Procedure`; sections `## What this is`, `## Procedure`, `### Pre-step setup`, `### First-shell assertions`, `### Pass criteria`, `## Run Log`. Seven `- [ ]` checkbox assertions verbatim. Run Log table header `\| Date \| Machine \| Result \| Notes \|`; populated row dated 2026-05-17 on personal-laptop with PASS plus notes documenting the two prereq revert commits. ROADMAP P10 SC#3 names this exact path. |

**Score:** 9/9 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `taskfiles/links.yml` | Internal `zdotdir` task + `task: zdotdir` cmds entry + status-block extension on `zsh` task | VERIFIED | `zdotdir:` defined at line 177; `internal: true` at line 179; cmds heredoc at 184-194 (sudo tee branches); status at line 196 (template-var grep). `links:zsh` cmds includes `- task: zdotdir` at line 150; `links:zsh` status appended with `grep -qF 'export ZDOTDIR="{{.ZDOTDIR}}"' /etc/zshenv 2>/dev/null` at line 157. |
| `taskfiles/shell.yml` | New `validate` task asserting XDG dirs + ZDOTDIR dir + /etc/zshenv ZDOTDIR line + DOTFILES_MACHINE state | VERIFIED | `validate:` defined at line 96; `status: [false]` at line 98; cmds heredoc 100-163 with five `[[ -d {{.X}} ]]` checks, the `/etc/zshenv` grep using `'export ZDOTDIR="{{.ZDOTDIR}}"'` literal, the DOTFILES_MACHINE check, and `exit "$failures"` at line 163. Existing `shell:` perf task at line 61 untouched. |
| `Taskfile.yml` | Dual-alias include (`perf:` + `shell:`) for taskfiles/shell.yml; `shell` token appended to both validate-aggregator loops | VERIFIED | Lines 92-93 carry both `perf:` and `shell:` includes pointing at `./taskfiles/shell.yml`. Both aggregator loops at lines 216 and 223 end with `claude shell; do`. `grep -c "manifest identity links macos packages claude shell" Taskfile.yml` returns 2 (Landmine 5 protection satisfied). |
| `.planning/phases/09-v1-drop-audit/AUDIT.md` | Row 3 reclassified keep -> drop; counts updated; keep-list bullet removed | VERIFIED | Counts table at lines 12-13: Keep 2 / Drop 100. Keep-list section at lines 18-22 contains 2 bullets (both `taskfiles/common.yml` rows). Row at line 78 in the Install Assets table shows `ported / drop` with the canonical-mas-list-name rationale verbatim. |
| `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` | Documented smoke procedure with 7 assertions + Run Log table | VERIFIED | File exists; H1, sections, 7 checkbox assertions, Run Log table with operator PASS entry (2026-05-17). Zero emojis. Zero AI-attribution strings. |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `taskfiles/links.yml:zsh` task | `taskfiles/links.yml:zdotdir` task | `- task: zdotdir` in cmds + matching `grep -qF` line in outer status | WIRED -- `taskfiles/links.yml:150` has `- task: zdotdir`; line 157 has the `grep -qF` status sentinel; D-04 / Landmine 7 honored. |
| `Taskfile.yml:validate` aggregator | `taskfiles/shell.yml:validate` task | `shell` token in both for-loops (216 + 223), resolved via `shell:` include alias (line 93) | WIRED -- end-to-end exercise: `task validate` runs successfully; output above shows the `shell` row in the summary section. |
| `Taskfile.yml:includes` block | `taskfiles/shell.yml` | dual-alias: `perf:` AND `shell:` (lines 92-93) | WIRED -- `task --list-all` reports `perf:shell`, `perf:validate`, `shell:shell`, `shell:validate`. Both aliases load the same file (D-06 dual-alias). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `task lint:taskfile` against new code reports zero NEW failures | `task lint:taskfile` | exits 24 (matches documented baseline); zero NEW failures in `taskfiles/links.yml` or `taskfiles/shell.yml:validate` | PASS |
| `task -t taskfiles/shell.yml validate` exits 0 on a healthy machine | `task -t /Users/josh/Git/personal/dotfiles/taskfiles/shell.yml validate` | exits 0 with seven green check marks (4 XDG dirs + ZDOTDIR dir + /etc/zshenv ZDOTDIR line + DOTFILES_MACHINE state) | PASS |
| `task validate` summary table contains `shell` row | `task validate` | summary shows 7 green rows ending with `shell` | PASS |
| `task --list-all` lists both legacy and new shell aliases | `task --list-all \| grep -E '(shell:validate\|perf:shell)'` | both `perf:shell` and `shell:validate` present | PASS |
| Both aggregator loops contain the `shell` token | `grep -c 'manifest identity links macos packages claude shell' Taskfile.yml` | returns 2 (Landmine 5 protection) | PASS |
| /etc/zshenv contains the resolved ZDOTDIR export line | `cat /etc/zshenv` | shows `export ZDOTDIR="/Users/josh/.config/zsh"` (rendered from `{{.ZDOTDIR}}` template) | PASS |
| manifests/machines/personal-laptop.toml Things3 row unchanged | `grep -F 'name = "Things3"' manifests/machines/personal-laptop.toml` | line 67 unchanged; `git log --follow` confirms no Phase-10 commits touched it | PASS |
| antidote config NOT present (revert applied) | `ls configs/antidote/` | no such directory; `configs/` lists conda/eza/ghostty/glow/motd/tlrc/trippy + README.md | PASS |
| `shell/.zshrc` sources antigen with `antigen use ohmyzsh/ohmyzsh` | `grep -n 'antigen use\|antigen apply\|antigen bundle' shell/.zshrc` | line 85 `antigen use ohmyzsh/ohmyzsh`; lines 88-94 list 7 antigen bundles; line 96 `antigen apply` | PASS |
| `packages/core.rb` declares `brew 'antigen'` (not antidote) | `grep -n "brew 'antigen'\|brew 'antidote'" packages/core.rb` | line 63 `brew 'antigen'`; no `brew 'antidote'` | PASS |
| `shell/functions/motd.zsh` is byte-identical to v1 `zsh/functions/motd.zsh` | `diff shell/functions/motd.zsh zsh/functions/motd.zsh` | empty output; exit 0 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PORT-01 | 10-01-PLAN | v2 task writes /etc/zshenv with the ZDOTDIR export line during `task install` | SATISFIED | `taskfiles/links.yml:zdotdir` is the new task; dispatched from `links:zsh`. Operator-verified fresh-write + idempotency PASS in 10-SMOKE.md Run Log. |
| PORT-02 | 10-01-PLAN | Every keep item in AUDIT.md is implemented in the v2 owner file | SATISFIED | Keep row #1 (ZDOTDIR write) -> implemented in `taskfiles/links.yml` (D-02 amends AUDIT's `taskfiles/shell.yml` owner). Keep row #2 (validate XDG dirs + ZDOTDIR line) -> implemented in `taskfiles/shell.yml:validate`. Keep row #3 (Brewfile-personal Things) -> reclassified to drop (D-07). Zero keep rows remain unimplemented. |
| PORT-03 | 10-01-PLAN | Fresh-machine smoke procedure confirms first-shell readiness | SATISFIED | `.planning/phases/10-v1-drop-remediation/10-SMOKE.md` carries the documented procedure; operator recorded PASS in Run Log on 2026-05-17 for personal-laptop. All seven assertions ticked. |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| (none in scope) | n/a | n/a | SKIPPED -- Phase 10 is not a migration/tooling phase with `scripts/*/tests/probe-*.sh` infrastructure; success criteria are exercised via the task graph and the operator-run SMOKE procedure, not via probe scripts. |

### Anti-Patterns Found

Scanned files: `taskfiles/links.yml`, `taskfiles/shell.yml`, `Taskfile.yml`, `.planning/phases/09-v1-drop-audit/AUDIT.md`, `.planning/phases/10-v1-drop-remediation/10-SMOKE.md`.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | -- | No debt markers (TBD/FIXME/XXX), no stub returns, no console.log-only handlers, no hardcoded empty data, no emojis in the new artifacts. | -- | -- |

The 10-REVIEW.md (advisory) reported 0 critical / 4 warnings / 4 info items against Phase 10 code. Two info items (IN-02, IN-04) were addressed by commit `a1293f7 fix(phase-10): apply IN-02 + IN-04 code review hygiene fixes`. The remaining WR-01..04 + IN-01, IN-03 are advisory and out of scope for Phase 10 goal achievement (see Deferred Items below).

### Human Verification Required

None. Operator-run verification was completed in this session and recorded in 10-SMOKE.md Run Log on 2026-05-17 (personal-laptop, PASS for all three operator tests: PORT-01 fresh-write + idempotency, PORT-02 negative test, PORT-03 fresh-shell smoke). The verifier confirms the Run Log entry exists with date, machine, result, and notes documenting the two prereq revert commits.

### Acknowledgment: Prerequisite Revert Commits

Two prerequisite `fix:` commits landed on main during this session because the PORT-03 fresh-shell smoke surfaced regressions from earlier-phase decisions. Both are reverts of earlier-phase work that turned out to break the fresh-shell goal; neither is in plan-10-01's scope, but both are necessary preconditions for PORT-03 to evaluate the shell honestly.

| Commit | Title | What it reverts | Requirement it drops |
|--------|-------|-----------------|---------------------|
| `ef3d236` | fix(shell): revert antigen->antidote port, restore OMZ lib loading | Phase 3 D-01 / CF-03 silently dropped `antigen use ohmyzsh/ohmyzsh`, removing `setopt prompt_subst`, `git_prompt_info`, `git_prompt_status`, and the `l` alias. Antidote has no `use` equivalent; the port captured the 7 bundle lines but not OMZ's `lib/*.zsh` loading. | SHEL-04 (cold-shell budget guaranteed by antidote static-bundle) -- the cold-start budget vs SHEL-12 must be re-measured. |
| `54b0e38` | fix(shell): revert motd 24h-TTL cache, restore v1 always-fresh render | Phase 3 SHEL-11 wrapped motd in a 24h-TTL cache that wrote width-sensitive output; later shells at different widths displayed stale output (overflow or short). v1's `motd()` always recomputed `tput cols` and rendered fresh. | SHEL-11 (24h-TTL motd cache). |

Verified in codebase:
- `shell/.zshrc:80-96` sources antigen and calls `antigen use ohmyzsh/ohmyzsh` (line 85), enumerates the 7 antigen bundles (lines 88-94), and calls `antigen apply` (line 96).
- `packages/core.rb:63` declares `brew 'antigen'`; no `brew 'antidote'` anywhere.
- `configs/antidote/` directory does NOT exist; `configs/` lists conda, eza, ghostty, glow, motd, tlrc, trippy, README.md.
- `shell/functions/motd.zsh` is byte-identical to `zsh/functions/motd.zsh` (`diff` returns empty).

These reverts are validated decisions that turned out to be incorrect once exercised end-to-end; the revert restored v1 behavior. The drops of SHEL-04 and SHEL-11 should be reflected in REQUIREMENTS.md status tracking by a follow-up.

### Deferred Items

Items NOT in Phase 10 scope. These do not block goal achievement; they are tracked for follow-up phases.

| # | Item | Tracked Under | Status |
|---|------|---------------|--------|
| 1 | WR-01: `shell/functions/motd.zsh` contains emojis (`⚡` U+26A1) violating project no-emojis rule | 10-REVIEW.md WR-01 (warning, advisory) | DEFERRED -- motd was restored byte-identical to v1 by the `54b0e38` revert; v1 itself carried the glyph. Future hygiene pass can replace with `[*]` or similar plain-ASCII marker. |
| 2 | WR-02: `shell/functions/motd.zsh` hard-codes v1 asset paths (`$DOTFILEDIR/zsh/configs/motd_sysinfo.jsonc`, `$DOTFILEDIR/zsh/configs/motd_tron.txt`) that Phase 11 will delete when `zsh/` tree is removed | 10-REVIEW.md WR-02 (warning, advisory) | DEFERRED -- Phase 11 RMV-01 must migrate these path references to `configs/motd/` before deleting `zsh/`. Tracked in ROADMAP Phase 11 success criteria #2 ("v1 `zsh/` directory is deleted"). |
| 3 | WR-03: zdotdir sudo write theoretical single-quote injection via `$HOME` | 10-REVIEW.md WR-03 (warning, advisory) | DEFERRED -- threat model T-10-01 already documents that `{{.ZDOTDIR}}` resolves to `{{.XDG_CONFIG_HOME}}/zsh` (root-Taskfile-controlled, not user-supplied); mitigation is in place. No active exploit path on a single-user macOS workstation. |
| 4 | WR-04: shell.yml's vars block does not declare XDG_* template vars it references | 10-REVIEW.md WR-04 (warning, advisory) | DEFERRED -- works correctly because go-task vars-merge forwards root XDG_* vars on include; the vars block is intentionally minimal (the precedent at links.yml:50-64 is the same shape). Phase 13 REVW-* cleanup may revisit. |
| 5 | IN-01: Dual-include alias creates namespace-pollution side effect (`perf:validate` + `shell:shell`) | 10-REVIEW.md IN-01 (info, advisory) | DEFERRED -- documented per D-06 ("Option B trade-off"); accepted. Future namespace collapse when this file is split into `perf.yml` + `shell.yml`. |
| 6 | IN-03: Stale documentation references to antidote in three README files (`packages/README.md`, `shell/README.md`, `taskfiles/README.md`) | 10-REVIEW.md IN-03 (info, advisory) | DEFERRED -- Phase 14 TRIM-03 is the right place to sweep stale documentation; the README references were valid before the `ef3d236` revert and need to be reconciled with the actual `antigen` reality. |
| 7 | Pre-existing `task lint:taskfile` failure baseline (24 failures across `taskfiles/{common,claude,manifest,packages,brew,profile-tasks,profile,test/lint-fixtures}.yml`) | Phase 11 RMV-01 (deletes v1 leftovers) + Phase 13 REVW-* (linter regex hygiene) | DEFERRED -- not introduced by Phase 10; pre-existing baseline. New Phase 10 code adds zero lint failures. |
| 8 | LINT-03a false-positive on `taskfiles/shell.yml:shell` task: `# lint-allow: cmds-without-status` marker is on a comment line above the task; the LINT-03a yq scan does not consult adjacent comments | Phase 13 REVW-* (linter regex hygiene) | DEFERRED -- known limitation; remediation is either to teach the regex about adjacent comments or to move the marker into a yq-readable annotation. |

### Gaps Summary

No gaps. All 9 must-have truths verified against the codebase. The phase goal is achieved: every keep item from Phase 9's AUDIT.md is implemented in v2 (rows #1 and #2 via PORT-01 and PORT-02; row #3 reclassified to drop per D-07), and fresh-machine install produces a fully-functional first shell (PORT-03 PASS recorded in 10-SMOKE.md Run Log).

The two prerequisite revert commits (`ef3d236`, `54b0e38`) restored v1 plugin-manager and motd behavior that earlier-phase decisions had broken; without these reverts the PORT-03 prompt-renders and motd-fits-width assertions would not have passed. The reverts drop SHEL-04 (antidote-based cold-shell budget) and SHEL-11 (24h-TTL motd cache); these requirement status changes should be reflected in REQUIREMENTS.md by a follow-up.

---

_Verified: 2026-05-17_
_Verifier: Claude (gsd-verifier)_
