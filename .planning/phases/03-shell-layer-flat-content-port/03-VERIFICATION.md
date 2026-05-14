---
phase: 03-shell-layer-flat-content-port
verified: 2026-05-14T23:23:41Z
status: gaps_found
score: 4/6 must-haves verified
overrides_applied: 0
gaps:
  - truth: "v1 `zsh/theme.zsh` is ported as-is to `shell/theme.zsh`; antidote loads the static bundle file with no Antigen references anywhere in the repo"
    status: partial
    reason: "shell/theme.zsh is byte-identical to v1 (good) and shell/.zshrc swaps antigen->antidote (good), BUT antigen references survive in taskfiles/common.yml (taskfiles/common.yml:59-66, :105) and the runtime jgrid source-time gate is broken because aliases load before functions (CR-01). Net: the antidote replacement is incomplete and the gating contract that depends on antidote-loaded plugins running after function definitions is partially broken at runtime."
    artifacts:
      - path: "taskfiles/common.yml"
        issue: "Lines 59-66 still define an antigen-update task; line 105 references $HOMEBREW_PREFIX/share/antigen/antigen.zsh. The 'no Antigen references anywhere in the repo' clause of the goal is not met."
      - path: "shell/.zshrc"
        issue: "Source order is aliases-then-functions (lines 110, 118), so shell/aliases/jgrid.zsh:17 invokes `_dotfiles_feature` before the function is defined. Observed behavior: `command not found: _dotfiles_feature`; `alias steel` is NOT defined even when features.jgrid-net=true (verified via smoke test). CR-01."
    missing:
      - "Reverse source order in shell/.zshrc so shell/functions/*.zsh is sourced BEFORE shell/aliases/*.zsh (D-08 source-time gate requires the helper function to exist at source time)."
      - "Delete or rewrite the antigen-update task and antigen symlink validation in taskfiles/common.yml; no antigen reference should remain in repo files that ship with v2."
      - "Add a regression smoke test that asserts `alias steel` is defined when `features.jgrid-net=true`."

  - truth: "Every top-level directory has a `README.md` — pattern established by the `shell/` README"
    status: failed
    reason: "shell/README.md is the DOCS-02 anchor (52 lines, all required sections present), and manifests/, configs/, packages/, docs/, os/ each have a README.md. BUT three top-level directories that exist in the repo have NO README.md at all: install/, taskfiles/, claude/. git/ and ssh/ also lack READMEs (they exist as v1 directories; whether they count as 'top-level' in v2 is ambiguous since Phase 4 will own them). The DOCS-02 contract reads 'each top-level directory has a README.md'."
    artifacts:
      - path: "install/"
        issue: "No README.md. install/ is a top-level directory shipping the resolver and message library."
      - path: "taskfiles/"
        issue: "No README.md. taskfiles/ is a top-level directory shipping every taskfile included by Taskfile.yml."
      - path: "claude/"
        issue: "No README.md. claude/ is a top-level directory shipping hooks/agents/commands/skills."
    missing:
      - "install/README.md (purpose, key files: resolver.zsh + messages.zsh, how-to-add a script)"
      - "taskfiles/README.md (purpose, file-per-concern convention, how-to-add a new taskfile and include it from Taskfile.yml)"
      - "claude/README.md (or accept deferral to Phase 7 if claude/ ownership is later — note in REQUIREMENTS.md)"

deferred:
  - truth: "Phase 7 will move v1 zsh/configs/{motd_sysinfo.jsonc,motd_tron.txt} into configs/<tool>/ and update shell/functions/motd.zsh paths (CR-03)"
    addressed_in: "Phase 7"
    evidence: "Phase 3 CONTEXT.md `<deferred>` section names the move as out-of-scope for Phase 3; motd.zsh comment block lines 16-17 also flag this. zsh/configs/ still exists on disk so the runtime path resolves successfully today."
  - truth: "git/ and ssh/ top-level READMEs (Phase 4 IDNT-* requirements own these directories)"
    addressed_in: "Phase 4"
    evidence: "Plan 3-5 CONTEXT.md says P4 adds git/ssh wiring; the DOCS-02 contract for those subtrees is naturally owned by Phase 4."

---

# Phase 03: Shell Layer Flat Content Port — Verification Report

**Phase Goal:** A `shell/` tree with flat alias/function layout (macOS-only v1), v1 prompt ported as-is, antidote replacing antigen, and v1 shell content fully ported under a 200ms cold-start budget
**Verified:** 2026-05-14T23:23:41Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Fresh interactive zsh exports `$DOTFILES_MACHINE` from state file; no `$DOTFILES_PROFILE` anywhere in the environment | VERIFIED | `shell/.zshenv:77` reads `$XDG_STATE_HOME/dotfiles/machine` and exports `DOTFILES_MACHINE`; `grep -rn DOTFILES_PROFILE shell/` returns no matches; `shell/.zshrc` emits an interactive-only missing-machine warning. The remaining references to `DOTFILES_PROFILE` live in `.claude/CLAUDE.md` (stale doc — see anti-patterns) and in `.planning/` research notes (intentional historical context). |
| 2 | `task perf:shell` measures cold start under 200ms; CI fails if exceeded | VERIFIED | `taskfiles/shell.yml:73-79` runs `hyperfine --warmup 1 --runs 5 --export-json /dev/stdout 'zsh -lic exit'`, parses mean via `jq -r .results[0].mean`, converts to ms, exits non-zero when `ms > 200`. `task perf:shell` resolves and lists from the root taskfile. **Threshold gate is wired; the actual 200ms budget cannot be programmatically verified without a converged install — flagged for human verification.** |
| 3 | Every v1 alias and function is ported to flat `shell/{aliases,functions}/*.zsh`; `zsh -n` passes on every function file | VERIFIED | v1 had 24 functions in `zsh/functions/`; v2 has 24 in `shell/functions/` (18 byte-stable verbatim ports confirmed via `diff`; `update.zsh` deliberately replaced by `alias update='task install'` in `shell/aliases/dotfiles.zsh` per CF-06; net function count: 23 ports + 1 net-new `_dotfiles_feature.zsh` = 24). All 4 v1 alias source files ported into 7 flat topic files (general/hardware/networking/dotfiles/finder/ghostty/jgrid). `zsh -n` passes on every file in both directories. No subdirectories under `shell/aliases/` or `shell/functions/` (flat layout confirmed). |
| 4 | v1 `zsh/theme.zsh` ported as-is; antidote loads the static bundle with no Antigen references anywhere in the repo | FAILED | `diff zsh/theme.zsh shell/theme.zsh` is empty (verbatim port good). `shell/.zshrc:73-86` wires antidote bundle from `configs/antidote/zsh_plugins.txt` (good). BUT `taskfiles/common.yml:59-66, :105` still references `antigen-update` task and `$HOMEBREW_PREFIX/share/antigen/antigen.zsh` — antigen has NOT been purged from the repo. ALSO: source order in `shell/.zshrc` breaks the D-08 gating contract that depends on antidote-loaded plugins coexisting with function definitions — see CR-01 in anti-patterns table. |
| 5 | MOTD cached to disk with 24h TTL (no synchronous fastfetch on shell startup); compinit uses daily-rebuilt cache | VERIFIED | `shell/functions/motd.zsh:21-22` declares `cache="${XDG_CACHE_HOME}/dotfiles/motd.cache"` and `ttl=86400`; cache miss path tees `_motd_render` synchronously; cache hit path `cat`s and triggers async refresh via `&!` (line 41). `shell/.zshrc:42-57` implements SHEL-10 compinit daily-rebuild: 86400s age check, `compinit -d` on full rebuild, `compinit -C -d` on fast path. **Caveat:** `motd.zsh:91,115` still reads from `${DOTFILEDIR}/zsh/configs/...` (v1 path, deferred to Phase 7 per CR-03; acceptable per phase-3 deferred-items contract). |
| 6 | Every top-level directory has a `README.md` — pattern established by `shell/` README | FAILED | `shell/README.md` is well-formed (52 lines, all DOCS-02 sections: purpose, key files, adding a pattern, performance budget, references). However, **three top-level directories that ship in v2 lack README.md entirely**: `install/`, `taskfiles/`, `claude/`. The DOCS-02 contract reads "each top-level directory has a README.md". Existing READMEs found: `shell/`, `manifests/`, `configs/`, `packages/`, `docs/`, `os/`. v1 directories without READMEs (`git/`, `ssh/`) are owned by Phase 4 and deferred. |

**Score:** 4/6 truths verified

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | motd.zsh path migration from `zsh/configs/` to `configs/<tool>/` | Phase 7 | Phase 3 CONTEXT.md explicitly defers; motd.zsh comment block flags it; v1 `zsh/configs/` still exists so runtime path resolves. |
| 2 | git/ and ssh/ top-level READMEs | Phase 4 | Plan 3-5 says P4 adds git/ssh wiring; DOCS-02 for those subtrees follows Phase 4 ownership. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `manifests/defaults.toml` | macos-finder, ghostty, jgrid-net flags declared false | VERIFIED | All three present with inline comments. |
| `manifests/machines/personal-laptop.toml` | ghostty=true, jgrid-net=true | VERIFIED | Both present. |
| `manifests/machines/work-laptop.toml` | ghostty=true (jgrid-net default false) | VERIFIED | ghostty=true present; jgrid-net intentionally absent. |
| `configs/antidote/zsh_plugins.txt` | 7 plugin lines, exact D-01 order | VERIFIED | Exactly 7 lines, order matches v1 antigen invocations; non-executable; no shebang. |
| `shell/.zshenv` | XDG exports + DOTFILES_MACHINE from state file | VERIFIED | 79 lines; all required XDG/locale/HISTFILE/CLAUDE_CONFIG_DIR exports; DOTFILES_MACHINE read guarded by `[[ -r ... ]]`. WR-02: capture preserves trailing newline (cosmetic warning). |
| `shell/.zprofile` | uname-m brew shellenv; SSH_AUTH_SOCK gated on features.one-password-ssh via inline jq | VERIFIED | 68 lines; arm64/x86_64 Homebrew prefix branching present; jq-based feature read replaces v1 hostname check; SSH_AUTH_SOCK gated on `features.one-password-ssh`. |
| `shell/.zshrc` | antidote replaces antigen; flat globs replace profile loops; SHEL-10 compinit; CF-05 warning | PARTIAL | All four items present, BUT source order is aliases-before-functions which breaks D-08 source-time gate in jgrid.zsh (CR-01 BLOCKER). |
| `shell/.zlogin` | motd dispatch when function exists | VERIFIED | 19 lines; `$+functions[motd]` dispatch preserved verbatim. |
| `shell/.zlogout` | history flush via `fc -W` | VERIFIED | 56 lines; verbatim port; `fc -W 2>/dev/null \|\| true` preserved. |
| `shell/theme.zsh` | byte-stable verbatim port of v1 | VERIFIED | `diff zsh/theme.zsh shell/theme.zsh` is empty. 99 lines. |
| `shell/aliases/*.zsh` (7 files) | flat layout; gated files use D-07/D-08 | PARTIAL | 7 files present; finder/ghostty use D-07 wrappers (correct at call time); jgrid uses D-08 source-time gate but is broken by CR-01 load order. |
| `shell/functions/*.zsh` (24 files) | flat layout; helper + 23 ports | VERIFIED | 24 files present; 18 verbatim ports byte-identical to v1; `_dotfiles_feature.zsh` net-new; `motd.zsh` rewritten for SHEL-11; `aliaslist/functionlist/sshlist.zsh` rewritten to drop DOTFILES_PROFILE. update.zsh deliberately absent (CF-06). |
| `taskfiles/links.yml` | replaces links-stub; zsh + antidote subtasks via _:safe-link | PARTIAL | File present and structurally correct, BUT the `all:` aggregator status block only checks 2 of 6 symlinks (CR-02 BLOCKER) — partial state goes uncorrected by `task install`. |
| `taskfiles/shell.yml` | task perf:shell with hyperfine + 200ms gate | VERIFIED | hyperfine existence check, warmup/runs args, JSON parse, threshold gate, SHEL-12 reference all present; `# lint-allow: cmds-without-status` marker present. |
| `Taskfile.yml` | links: -> links.yml; perf: -> shell.yml | VERIFIED | Both includes wired; `links-stub.yml` no longer referenced. |
| `shell/README.md` | DOCS-02 anchor with purpose/key files/adding/budget | VERIFIED | 52 lines; all required sections present; references `_dotfiles_feature`, 200ms, `task perf:shell`, SHEL-12, D-07, D-08; no emojis. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `shell/.zshenv` | `$XDG_STATE_HOME/dotfiles/machine` | guarded `$(<file)` read | WIRED | `[[ -r ... ]]` guard; export only when readable; graceful degrade on missing state. |
| `shell/.zprofile` | `$XDG_STATE_HOME/dotfiles/resolved.json` | inline `jq -r '.features."one-password-ssh"'` | WIRED | jq invocation present; SSH_AUTH_SOCK assigned only when result is literal `"true"`. |
| `shell/.zshrc` | `configs/antidote/zsh_plugins.txt` | antidote bundle <-> cache mtime check | WIRED | DOTFILEDIR set before antidote block; bundle source path correct; mtime-based regenerate logic present. |
| `shell/.zshrc` | `shell/aliases/*.zsh` and `shell/functions/*.zsh` | flat glob with `(.N)` nullglob | NOT_WIRED CORRECTLY | Both globs present (lines 110, 118), but order is WRONG: aliases first, functions second. Breaks D-08 source-time gate in jgrid.zsh — see CR-01. |
| `shell/.zshrc` | `shell/theme.zsh` | direct `source` after antidote, before functions | WIRED | Line 115. |
| `shell/aliases/jgrid.zsh` | `_dotfiles_feature` helper | source-time `[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] \|\| return 0` | NOT_WIRED | Helper not yet defined at source time. Smoke test confirms `command not found: _dotfiles_feature`. |
| `taskfiles/links.yml` | `_:safe-link` from helpers.yml | `task: _:safe-link` invocations | WIRED | 6 invocations (5 in zsh: + 1 in antidote:). |
| `Taskfile.yml` includes: `links:` | `./taskfiles/links.yml` | go-task includes block | WIRED | Real file, no -stub suffix. |
| `Taskfile.yml` includes: `perf:` | `./taskfiles/shell.yml` | go-task includes block | WIRED | `task perf:shell` resolves from root. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `shell/.zshenv` DOTFILES_MACHINE | DOTFILES_MACHINE | `$XDG_STATE_HOME/dotfiles/machine` file | Yes when file exists (Phase 1 D-15); UNSET when missing (CF-05 graceful degrade) | FLOWING |
| `shell/.zprofile` SSH_AUTH_SOCK | SSH_AUTH_SOCK | jq read of features.one-password-ssh from resolved.json | Yes when manifest declares feature true | FLOWING |
| `shell/functions/_dotfiles_feature.zsh` _DOTFILES_FEATURES | _DOTFILES_FEATURES (typeset -gA) | jq parse of features object from resolved.json | Yes on first invocation; cached thereafter; defaults to false on missing/unreadable | FLOWING |
| `shell/aliases/jgrid.zsh` aliases (steel, iron, ...) | 22 metal aliases | source-time gate decides whether to execute the alias loop | **NO** — helper unavailable at source time means gate evaluates to false-via-error even when feature is true | DISCONNECTED |
| `shell/functions/motd.zsh` cached output | cache file `$XDG_CACHE_HOME/dotfiles/motd.cache` | `_motd_render` (verbatim v1 logic) | Renders only if `${DOTFILEDIR}/zsh/configs/motd_*.jsonc/txt` exist — TODAY they do (v1 leftovers); after Phase 7 cleanup they will not (deferred bug per CR-03 note) | STATIC (acceptable in Phase 3; deferred to Phase 7) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `zsh -n` parses every shell startup file | `for f in shell/.zshenv shell/.zprofile shell/.zshrc shell/.zlogin shell/.zlogout shell/theme.zsh; do zsh -n "$f"; done` | All exit 0 | PASS |
| `zsh -n` parses every function file | `for f in shell/functions/*.zsh; do zsh -n "$f"; done` | All exit 0 | PASS |
| `zsh -n` parses every alias file | `for f in shell/aliases/*.zsh; do zsh -n "$f"; done` | All exit 0 | PASS |
| `_dotfiles_feature` returns false on unknown flag | `zsh -c '. shell/functions/_dotfiles_feature.zsh && echo $(_dotfiles_feature foo)'` | `false` | PASS |
| `_dotfiles_feature` graceful degrade with missing resolved.json | `XDG_STATE_HOME=/nonexistent zsh -c '. shell/functions/_dotfiles_feature.zsh && echo $(_dotfiles_feature any)'` | `false`, no crash | PASS |
| 18 v1 functions byte-identical to v2 | `for f in ...; do diff zsh/functions/$f.zsh shell/functions/$f.zsh; done` | All empty | PASS |
| `shell/theme.zsh` byte-identical to v1 | `diff zsh/theme.zsh shell/theme.zsh` | Empty | PASS |
| `task --list` shows links:* and perf:shell | `task --list \| grep -E 'links\|perf'` | All 5 tasks listed (links:all, links:zsh, links:antidote, links:validate, perf:shell) | PASS |
| Source order behavioral test: alias `steel` defined when feature enabled? | Simulate `.zshrc` source order with `features.jgrid-net=true` | `command not found: _dotfiles_feature` then `alias steel` is NOT defined | **FAIL — CR-01 confirmed** |
| `task perf:shell` actually measures cold start under 200ms | Requires converged install with symlinks present | Cannot run programmatically | SKIP — human verification |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| (none) | - | No `scripts/*/tests/probe-*.sh` defined in repo or phase plans | N/A |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SHEL-01 | 03-02 | `shell/.zshenv` exports XDG + DOTFILES_MACHINE; no DOTFILES_PROFILE | SATISFIED | All exports present; DOTFILES_PROFILE absent from shell/ tree. |
| SHEL-02 | 03-02 | `shell/.zprofile` shellenv guarded; SSH_AUTH_SOCK manifest-gated | SATISFIED | `[[ -x "$DIRECTORY" ]]` guard present; jq-based feature read replaces hostname check. |
| SHEL-03 | 03-02 | `.zshrc` glob-loads shell/aliases and shell/functions (flat) | PARTIAL — source order bug | Globs present and flat, but order breaks D-08 contract (CR-01). |
| SHEL-04 | 03-01, 03-02 | Antidote replaces Antigen | PARTIAL — antigen survives in taskfiles/common.yml | Antidote correctly wired in `.zshrc`; antigen NOT fully purged (taskfiles/common.yml:59-66, :105). |
| SHEL-05 | 03-02 | theme.zsh ported as-is | SATISFIED | Byte-identical port. |
| SHEL-06 | 03-04 | One alias topic per file in shell/aliases/<topic>.zsh | SATISFIED | 7 topic files; flat; one purpose per file. |
| SHEL-07 | 03-03 | One function per file in shell/functions/<name>.zsh | SATISFIED | 24 function files; flat; filename = function name (with `_` prefix for helper). |
| SHEL-08 | 03-04 | All v1 aliases ported to flat shell/aliases | SATISFIED | All v1 alias content accounted for; Finder/Ghostty extracted to gated files; new update alias hosts in dotfiles.zsh. |
| SHEL-09 | 03-03 | All v1 functions ported; each passes `zsh -n` | SATISFIED | 24 files; zsh -n passes on all. |
| SHEL-10 | 03-02 | compinit daily-rebuilt cache | SATISFIED | 86400s age check; `compinit -d` vs `-C -d` paths present. |
| SHEL-11 | 03-03 | MOTD 24h-TTL cached with async refresh | SATISFIED | 86400 TTL; atomic `.tmp` write; `&!` disown for async. |
| SHEL-12 | 03-05 | Cold shell start under 200ms via `task perf:shell` | PARTIAL — gate wired, runtime budget needs human verification | hyperfine command + 200ms threshold + non-zero exit on miss all present. Actual 200ms budget on real hardware NEEDS HUMAN. |
| DOCS-02 | 03-05 | Each top-level directory has a README.md | BLOCKED | shell/, manifests/, configs/, packages/, docs/, os/ have READMEs. install/, taskfiles/, claude/ have NO README.md. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `shell/.zshrc` | 110, 118 | Aliases sourced BEFORE functions | BLOCKER (CR-01) | Breaks D-08 source-time gate in jgrid.zsh: `_dotfiles_feature` not yet defined when jgrid.zsh:17 invokes it. Smoke-test confirmed `command not found: _dotfiles_feature`; `alias steel` is NOT defined even when features.jgrid-net=true. Goal clause "v1 shell content fully ported" is NOT met on jgrid-net machines. |
| `taskfiles/links.yml` | 73-76 | `all:` aggregator `status:` only checks 2 of 6 symlinks | BLOCKER (CR-02) | Partial-link state goes silently uncorrected: if any of .zprofile/.zshrc/.zlogin/.zlogout is missing while .zshenv and .zsh_plugins.txt exist, `task install -> links:all` short-circuits and never restores the missing files. Exact v1 `macos:shell:145` bug class. |
| `shell/functions/motd.zsh` | 91, 115 | References `${DOTFILEDIR}/zsh/configs/motd_*.{jsonc,txt}` | WARNING (CR-03) — deferred | Still works today because v1 `zsh/configs/` exists on disk; will silently degrade after Phase 7 cleanup unless paths are updated. Phase 3 plan accepts this; deferred to Phase 7. |
| `shell/functions/fs.zsh` | 16 | `find . -type f \| du -ah -d1` (du ignores stdin) | WARNING (CR-04) | Dead branch (`uname != Darwin`) on macOS-only v1. Will produce drift when Linux support lands. The branch is a v1-verbatim port — `diff zsh/functions/fs.zsh shell/functions/fs.zsh` is empty. Pre-existing v1 bug carried forward. |
| `shell/functions/docker.zsh` | 14 | `docker ps` inside wrapper (recurses instead of `command docker ps`) | WARNING (WR-04 from review) | Pre-existing v1 bug; v2 port is byte-identical. Triggers only in the "no container specified" error path of the bash/sh branch. |
| `shell/aliases/jgrid.zsh` | 17 | No defensive `(( $+functions[_dotfiles_feature] ))` guard | WARNING (WR-01) | Compounds CR-01: file fails silently rather than emitting a load-order error. |
| `shell/.zshenv` | 77 | `$(<file)` retains trailing newline | WARNING (WR-02) | String equality checks like `[[ "$DOTFILES_MACHINE" == "personal-laptop" ]]` will fail if state file has trailing `\n` (typically does when written by `echo`). |
| `shell/.zshrc` | 101-103 | `source "$(code --locate-shell-integration-path zsh)"` lacks existence check | WARNING (WR-03) | On a machine without `code` in PATH, command substitution yields empty string and `source ""` errors out. |
| `shell/theme.zsh` | 19-23 | `local user='...'` at top scope | WARNING (WR-11) | `local` valid only in functions; under some option sets prints "local: can only be used in a function". Cosmetic but breaks lint runs with WARN_CREATE_GLOBAL. |
| Multiple function files | — | Lack file-level comment block per CLAUDE.md | INFO (IN-01) | 26 files cited in CR-01..09 review. Cosmetic; CLAUDE.md convention. |
| `.claude/CLAUDE.md` | 7, 56 | Still references `$DOTFILES_PROFILE` | INFO | Project-level doc is stale relative to v2 reality. Not in `shell/` so doesn't break SHEL-01, but contradicts the goal narrative. |
| `taskfiles/common.yml` | 59-66, 105 | Antigen task + symlink validation survives | BLOCKER (contributes to truth 4) | Goal clause "no Antigen references anywhere in the repo" is NOT met. |

### Human Verification Required

1. **`task perf:shell` reports cold-start under 200ms on a converged personal-laptop**
   - Test: On a personal-laptop with `task setup -- personal-laptop && task install` complete (Plans 01-05 all merged), run `task perf:shell`.
   - Expected: Output reads `cold shell start: NNms (target: <= 200ms)` with NN ≤ 200; exit code 0.
   - Why human: Requires a real hardware run; CI gate is wired but the measured budget is hardware/load-sensitive.

2. **Fresh interactive login sources the v2 stack cleanly**
   - Test: After `task install` symlinks all six files, open a new Ghostty (or other) terminal session.
   - Expected: No "command not found", no stderr warnings except possibly the CF-05 missing-machine warning (only if state file is absent); the MOTD renders (cached or fresh); prompt segments display correctly (user@host, pwd, git, return code, time).
   - Why human: Real terminal needed to see the prompt, MOTD, and any startup stderr.

3. **`finder`, `findershow`, `finderhide`, `g`, and the 22 metal aliases work on personal-laptop**
   - Test: Run `finder`, `findershow`, `finderhide`, and one of the metal aliases (e.g. `steel`).
   - Expected: `finder` opens Finder; show/hide toggles work; `g` launches Ghostty; `steel` opens SSH session to steel-ssh.jgrid.net. **Note: CR-01 BLOCKER means the metal aliases will NOT be defined under the current source order — this test will fail with `command not found: steel` until CR-01 is fixed.**
   - Why human: GUI invocation and network behavior cannot be verified in a sandbox.

### Gaps Summary

Two truths fail goal-backward verification:

**Truth 4 ("antidote replaces antigen with no antigen references anywhere in the repo")** is FAILED on two grounds:
- `taskfiles/common.yml` lines 59-66 and 105 still reference antigen (an `antigen-update` task and a `_:check-link` for `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`). The plan focused only on `shell/.zshrc` and missed the broader repo-wide antigen sweep.
- The runtime gating contract is partially broken by CR-01: the source order in `shell/.zshrc` causes `shell/aliases/jgrid.zsh:17` to invoke `_dotfiles_feature` before the function is defined. The behavioral spot check confirms `alias steel` is NOT defined when `features.jgrid-net = true` — directly contradicting the goal clause "v1 shell content fully ported".

**Truth 6 ("Every top-level directory has a README.md")** is FAILED because three top-level v2 directories — `install/`, `taskfiles/`, `claude/` — have no README.md. The DOCS-02 contract is explicit: "Each top-level directory has a README.md". `shell/README.md` is a valid anchor (the pattern is established), but the pattern was not propagated.

Two more items qualify as warnings but should be flagged for next-phase awareness:
- **CR-02 (links.yml under-checks)**: `all:` status block tests only 2 of 6 symlinks. The bug class is exactly the v1 `macos:shell:145` regression the lint rules were written to prevent. Recommended fix: remove the aggregator `status:` block entirely (sub-tasks are already idempotent via their own status checks).
- **WR-02, WR-04 etc. from CR-01..09**: cosmetic/pre-existing bugs in verbatim ports. The fs.zsh `du` Linux-fallback and docker.zsh recursion are byte-identical v1 carryovers and could be tracked as platform-port debt.

Phase 3 has strong structural foundations — the manifest layer, the shell tree, the 24-function port, the SHEL-11 motd cache, and the SHEL-12 perf gate are all in place. But two BLOCKERs (CR-01 source order, antigen survival in taskfiles/common.yml) prevent the phase goal from being met, and one BLOCKER (CR-02 status-block bug) is the exact regression class lint was built to catch. Status: **gaps_found**.

---

*Verified: 2026-05-14T23:23:41Z*
*Verifier: Claude (gsd-verifier)*
