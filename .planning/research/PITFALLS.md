# Pitfalls Research

**Domain:** Manifest-driven dotfiles refactor (parallel rewrite)
**Researched:** 2026-05-13
**Confidence:** HIGH — grounded in `.planning/codebase/CONCERNS.md` (live bugs in this repo), `.planning/codebase/CONVENTIONS.md`, plus dotfiles-community discourse (GitHub does dotfiles, Home Manager manual, chezmoi migration write-ups, zsh-bench, platform-rewrite post-mortems).

This document captures pitfalls *specific to this rewrite*. The existing `CONCERNS.md` audit catalogues live bugs in v1; this file explains how the v2 architecture must structurally prevent them and what new traps the manifest model introduces. Generic software-engineering advice is intentionally omitted.

---

## Critical Pitfalls

### Pitfall 1: Manifest-vs-installed-state drift

**What goes wrong:**
The manifest declares `features = ["one-password-ssh", "macos-defaults", "fastfetch"]` but the installed state diverges — a feature was removed from the manifest months ago and the corresponding symlink/agent.toml/defaults override still exists on disk. Or the inverse: a feature is added but `task install` doesn't pick up the orphan removal step. Over time, machines accumulate cruft that the manifest claims doesn't exist.

**Why it happens:**
The natural way to write manifest-driven installers is forward-only — "for each declared feature, install it." Removal is rarely modeled because it requires a diff between *previous* manifest state and *current* manifest state. Most dotfiles tools (stow, chezmoi without `--remove`) suffer this. The team builds install paths; uninstall paths are an afterthought.

**How to avoid:**
- Define the manifest as a *closed world*: every install task records a state sentinel (e.g. `$XDG_STATE_HOME/dotfiles/installed-features.toml`) and `task install` reconciles installed-state against the manifest, removing what no longer appears.
- Pair every `feature-install` task with a `feature-remove` task. Make `task install` invoke remove for any feature that disappeared from the manifest since last run.
- For symlinks specifically: the v2 link installer should iterate the manifest's declared symlinks AND scan `~/.config`, `~/.local/share`, etc., for symlinks pointing into `$DOTFILEDIR` that are *not* in the manifest — those are orphans.
- `task validate` must flag both directions: missing-declared and present-but-undeclared.

**Warning signs:**
- A symlink in `~/.config/` points at a file that no longer exists in the repo (broken).
- `defaults read com.apple.dock` shows keys you don't recognize and the manifest no longer requests them.
- 1Password SSH agent socket env var is set on a machine whose manifest no longer declares the feature.

**Phase to address:**
Manifest-engine phase (the phase that builds the TOML loader and feature dispatcher). Reconciliation is not bolt-on — it must be designed into the dispatcher's contract from the start.

---

### Pitfall 2: Schema sprawl in the manifest

**What goes wrong:**
The TOML manifest starts clean (`identity`, `features`, `packages`) and within six months has grown twenty top-level tables, three different ways to declare a package (`packages.brew`, `packages.brew_taps`, `packages.brew_casks`, `packages.brew_extras`, plus per-feature `[features.x.packages]` overrides). New machines copy-paste from old machines because nobody remembers which fields are required. Adding a new field requires editing N machine manifests.

**Why it happens:**
TOML has no schema enforcement out of the box. Every new requirement gets a new key. Without a documented schema, ad-hoc growth feels harmless. Inheritance/override rules are added piecemeal as needs arise.

**How to avoid:**
- Define and commit a **JSON Schema for the TOML manifest** (TOML can be validated with JSON Schema; tools like taplo, tombi, vscode-even-better-toml all support this). Reject unknown keys.
- Document the schema in `docs/MANIFEST.md` with a worked example, *required* vs *optional* fields, and the exact merge/inheritance rules between `defaults.toml` and `machines/<name>.toml`.
- Pick *one* package-declaration style and enforce it. e.g. `packages = ["bundle-base", "bundle-dev", "bundle-darwin"]` referring to bundle files under `packages/bundles/`. No inline package lists in machine manifests.
- Run schema validation as the first step of `task install` and in `task validate` — fail loudly on unknown keys or missing required ones.

**Warning signs:**
- Adding a new machine requires more than ~15 lines of TOML.
- New manifest fields appear without a corresponding edit to `docs/MANIFEST.md`.
- Two machines declare the same intent in different ways.
- Manifest validation step doesn't exist or is bypassed in CI.

**Phase to address:**
Manifest-engine phase. The schema is a first-class artifact, not documentation produced after the fact.

---

### Pitfall 3: Inheritance/override surprises (defaults.toml deep-merge ambiguity)

**What goes wrong:**
A machine sets `[features.macos-defaults] dock_autohide = false` to override the default `true`. After a refactor of the defaults file, the override silently stops working because the inheritance logic does shallow merge on `[features]` (replacing the entire table) rather than deep merge. Or worse — the override *does* work but a new sibling key in defaults (`dock_position = "left"`) is lost on the override side.

**Why it happens:**
TOML merge semantics aren't standardized — every tool defines its own. Implementers tend to copy-paste a merge helper from Stack Overflow that handles their first test case and breaks on the second. Lists are especially gnarly: should `packages = ["a", "b"]` in machine and `packages = ["a", "c"]` in defaults produce `["a", "b"]`, `["a", "b", "c"]`, or `["c", "a", "b"]`?

**How to avoid:**
- Pick and **document** the merge rule explicitly. Recommendation: deep-merge for tables (keys from machine override keys from defaults, sibling keys preserved), **replace** for lists (machine's list wins entirely; no concatenation), with a one-shot `+` prefix or dedicated `additions = [...]` field when concatenation is wanted.
- Write the merge function once, with a test fixture per merge case (table-over-table, list-replace, scalar-override, deeply-nested-table, missing-in-defaults, missing-in-machine, type-mismatch). Pin behavior with golden output tests.
- Surface the *resolved* manifest in a debug command: `task manifest:show -- <machine>` prints the post-merge TOML so the user can verify their override actually took effect.
- In docs, give a worked example of every merge case.

**Warning signs:**
- "Why isn't my override working?" said twice.
- Adding a sibling key to a defaults table accidentally drops machine-level keys.
- The merge function lives in one file but has no tests.

**Phase to address:**
Manifest-engine phase. Merge semantics must be the second deliverable (after schema), with tests.

---

### Pitfall 4: Premature cutover from v1 to v2

**What goes wrong:**
v2 reaches "feature parity" on the primary laptop, the maintainer flips the symlink target on their main machine, and three days later discovers that `task update` on the work laptop subtly breaks because a single function was ported incorrectly. Now they're in the worst position: half the muscle memory works on v2, half doesn't, and v1 has drifted further while attention was on v2.

**Why it happens:**
"Feature parity" is asserted, not measured. The maintainer is the only validator. Each machine has its own latent surprises that only surface in real use (e.g. server-only paths, work-only SSH hosts, machine-specific aliases). Parallel-rewrite literature consistently warns: feature parity blind spots are *guaranteed* to exist, the question is whether you find them before or after cutover.

**How to avoid:**
- Define cutover as a per-machine event with explicit gates: (1) `task validate` passes 100% on the v2 repo for that machine, (2) interactive smoke-test checklist passes (open a new shell, source MOTD, run a sample of N functions, push to a git repo, ssh to a representative host), (3) machine runs in v2 for >7 days with no fallback to v1 before declaring done.
- **Keep v1 fully working in parallel.** No "frozen, do not touch" v1 — bugs in v1 still get fixed during the rewrite. The rewrite cannot be the excuse to let v1 rot.
- Use a per-machine cutover register: `docs/CUTOVER.md` lists each of the four machine categories with status (v1 / shadowing / v2). Cutover is *individual*, not big-bang.
- Build a feature-parity diff tool: enumerate every alias, function, hook, brew package, macOS default, and symlink in v1; assert all are present (or explicitly omitted) in v2. Generate this as a checklist artifact.
- Cutover order: personal-laptop (highest validation surface, used daily) first, then work-laptop, then servers. Servers last because they're hardest to remediate remotely if a problem surfaces.

**Warning signs:**
- Cutover discussion uses the word "should" ("it should be at parity").
- v1 hasn't been touched in weeks, suggesting it's already informally abandoned.
- No checklist exists for "what does parity mean for this machine."
- Tempted to flip the symlink during the same session as a fresh feature was added.

**Phase to address:**
Cutover phase, but the *parity checklist* must be produced early (during the audit/inventory phase) and grow as features are ported.

---

### Pitfall 5: Identity bleed across machines (wrong git email / SSH key)

**What goes wrong:**
The work machine's git config silently uses the personal email on a new repo because the manifest's `[identity]` table was copy-pasted from the personal machine and the email key was overlooked. Or: the server uses the personal SSH key because the SSH identity stanza wasn't gated on a manifest feature. Commits with the wrong identity get pushed before anyone notices. Worst case: a sensitive work commit ends up signed by a personal key.

**Why it happens:**
- Hostname-based identity selection is fragile (already burned this repo, per `CONCERNS.md` re `.zprofile:55`).
- `git config --global user.email = ...` is global to the user, not per-repo, so a missed `includeIf` directive defaults to whatever was last written.
- Machine manifests start as copies of existing ones; identity fields are easy to miss-update during the copy.
- SSH agent forwarding can quietly use a key from a different machine if the agent socket is shared (1Password universal access).

**How to avoid:**
- Make `[identity]` a **required, top-level, no-defaults table** in the manifest schema. Validation fails if missing, ambiguous, or matching a known-other-machine's email.
- `git/identities/` directory holds one file per identity (already planned). Driven by manifest, never by hostname. `includeIf "hasconfig:remote.*.url:git@github.com:work-org/**"` rules selected by manifest, not by file presence alone.
- `task validate` runs `git config --get user.email` inside one representative repo per identity and confirms it matches the manifest. Same for `ssh-add -L` confirming the *expected* key set.
- For 1Password SSH agent: gate the socket export on `feature = "one-password-ssh"` in the manifest, never on hostname (this is already in PROJECT.md but worth repeating — the existing `.zprofile:55` bug is the canonical instance of this pitfall).
- Add a pre-commit (or pre-push) check that the configured email matches an allowed set for the current repo origin.

**Warning signs:**
- `git log --author=<wrong-email>` returns commits.
- `ssh -G <work-host> | grep IdentityFile` shows a personal key path.
- Manifest validation doesn't fail when `[identity]` is missing.
- `hostname` appears in any code path that influences identity.

**Phase to address:**
Manifest-engine phase (schema enforcement) + identity-config phase (git/ssh wiring). This pitfall is the existing `.zprofile:55` bug generalized — solve it structurally, not by patching one hostname check.

---

### Pitfall 6: Shell startup performance regression goes unnoticed

**What goes wrong:**
Cold interactive shell start was ~500ms with antigen (v1, per `CONCERNS.md`). v2 targets <200ms. Three months in, it's drifted back to 400ms because someone added a synchronous `kubectl completion zsh`, a synchronous gcloud SDK source, and a `git status` in the prompt. Nobody noticed because the regression was gradual — each addition felt small.

**Why it happens:**
Shell startup is invisible by default — you don't see it unless you measure it. Each new plugin/tool/source feels like "just one more thing." Plugin managers like antigen run `apply` on every shell start regardless of cache validity (per zinit/antidote benchmarks). MOTD and prompt code runs synchronously by default. There's no CI for shell startup latency.

**How to avoid:**
- Pin a startup budget in the manifest or convention docs (e.g. <200ms cold, <50ms warm). Document it in `docs/PERFORMANCE.md`.
- Add `task perf:shell` that runs `zsh-bench` (`romkatv/zsh-bench`) or a homegrown `for i in {1..10}; do time zsh -i -c exit; done` and reports against budget. Run it in CI.
- Switch plugin manager: antigen's `apply` is the dominant cost (community-documented 200–500ms; one user got 81% reduction migrating to zinit). Candidates: `zinit` (turbo mode, deferred load), `antidote` (antigen-compatible API, much faster), `zsh4humans` for an opinionated stack. Pick during the shell-config phase.
- MOTD must be async or cached with TTL. The existing v1 MOTD runs `git log`, `git status`, and `fastfetch` synchronously on every login (per `CONCERNS.md`). v2 design: cache `fastfetch` output to a file with a 24h TTL; run `git status` only if cwd is a git repo and the index has changed since last cached.
- Lazy-load heavy completions: `kubectl`, `gcloud`, `terraform`, etc. via zinit's `wait` modifier or a one-shot stub that loads on first invocation.

**Warning signs:**
- New shell takes "long enough that you notice."
- No automated perf measurement.
- `zprof` shows any single line >50ms.
- Adding completions doesn't go through a performance review.

**Phase to address:**
Shell-config phase (plugin manager choice) + observability/validation phase (the perf task). Don't defer perf to "later" — once a heavyweight plugin is in, removing it is hard.

---

### Pitfall 7: Cross-platform leakage (macOS-isms in shared code, BSD/GNU command divergence)

**What goes wrong:**
Aliases and functions in `common/` use `pbcopy`, `system_profiler`, `defaults write`, `mDNSResponder`, `open -a Finder`. They appear to work on the maintainer's laptop and silently break on the server (per `CONCERNS.md` — there are 4+ live instances of this already: `hardware.zsh`, `general.zsh:27-31`, `networking.zsh:4`, `pubkey.zsh:11`). Or: a shared function uses `sed -i ''` (BSD form) and breaks on Linux because GNU `sed -i` takes no argument. Or: `shuf` (GNU-only) is called with a `sort -R` fallback that *also* doesn't exist on BSD `sort`.

**Why it happens:**
The shared/common directory is the easiest place to add things — and it's also where divergence is most damaging. The maintainer's primary machine is macOS, so macOS-only code looks correct until a server install. BSD/GNU command differences are subtle (`sed -i`, `find -printf`, `stat`, `date -r`, `readlink -f`, `tr -d '[:space:]'`).

**How to avoid:**
- Directory layout encodes platform: `aliases/common/` is **truly common** (verified portable), `aliases/darwin/` and `aliases/linux/` for platform-specific. Loading code picks the right directory by `$(uname)` at shell startup. This is already in PROJECT.md — *enforce it with a lint*.
- Write a `task lint:platform` that greps every file in `common/` for known macOS-only commands (`pbcopy`, `pbpaste`, `open -a`, `system_profiler`, `defaults`, `osascript`, `diskutil`, `sysctl machdep`, `mdfind`, `mDNSResponder`, `dscacheutil`, `launchctl`, `networksetup`, `airport`, `pmset`) and Linux-only commands (`xclip`, `xsel`, `xdotool`, `notify-send`, `systemctl`, `dconf`). Fail CI if any are found.
- Pick one of two GNU-vs-BSD strategies and document it:
  - **Option A:** Install GNU coreutils on macOS without `g` prefix (via `$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin` on PATH) so scripts can write GNU-flavored commands and they work on both platforms. *This is the simpler choice for an AI-friendly codebase.*
  - **Option B:** Write portable POSIX-only code in `common/`. Banned: `sed -i`, `readlink -f`, `find -printf`, `date -d`. Allowed: nothing fancy.
- For GNU grep specifically: the existing `hook::require_ggrep` pattern (`ggrep` on macOS, `grep` on Linux) is already correct — generalize it to a `coreutil` helper that resolves the right binary by platform.

**Warning signs:**
- A function works on the laptop but fails on the server.
- `task lint:platform` doesn't exist or doesn't run in CI.
- New aliases land in `common/` without a platform check.
- `(uname)` appears in alias files but not in a centralized helper.

**Phase to address:**
Shell-content phase (porting aliases/functions) + observability phase (the lint task). The v1 audit has already identified the specific files that break — the v2 directory layout must structurally prevent re-occurrence.

---

### Pitfall 8: Symlink hygiene — broken, orphaned, partial-unlink

**What goes wrong:**
After a refactor, three symlinks in `~/.config/` point at paths that no longer exist in the repo (renamed files, removed configs). Or: the manifest used to declare `claude/skills/foo` but no longer does — the symlink remains. Or: a `mkdir -p` inline in a task races with `ln -s` and creates the directory instead of the symlink, then subsequent runs see "it exists" and skip the link creation.

**Why it happens:**
- Forward-only install logic (see Pitfall 1).
- `ln -sf` doesn't replace a directory with a symlink — it puts the symlink *inside* the directory. Without `-n`, this is the classic dotfiles trap. The dotfiles community has documented this extensively (per stow/coder issues, broken symlinks in `.config/` are the #1 dotfiles bug).
- `mkdir -p ~/.config/foo` followed by `ln -s ~/dotfiles/foo ~/.config/foo` creates `~/.config/foo/foo` because the directory now exists.
- Validation checks "is this a symlink?" but not "does it point at the *expected* target?"

**How to avoid:**
- All symlink creation goes through `_:safe-link` (existing helper, keep it). Internally: `ln -sfn` (the `-n` is critical when target exists as a directory), preceded by `mkdir -p "$(dirname "$TARGET")"` (parent dir only, never the target itself).
- `task validate` for symlinks must check three properties: (1) exists, (2) is a symlink, (3) `readlink` matches the expected source path. The existing `_:check-link` helper checks (1) and (2); add (3).
- Pair every install with an explicit cleanup: `task links:reconcile` scans `$XDG_CONFIG_HOME` and other managed dirs for symlinks pointing into `$DOTFILEDIR`, cross-references the manifest, removes orphans. Runs as part of `task install`.
- Never create the *target* directory of a symlink. If the manifest declares a symlink target, the install logic refuses to proceed if the target exists as a non-symlink directory; the user must `rm -rf` it manually (loud failure beats silent wrong link).

**Warning signs:**
- `find ~ -xtype l -lname '*dotfiles*'` returns results (broken symlinks pointing into the repo).
- A symlink in `~/.config/` is actually a directory containing one symlinked file (classic `ln -s` into existing dir bug).
- `task validate` passes but `cat ~/.config/foo` shows stale content.

**Phase to address:**
Install-engine phase. The `_:safe-link` helper exists; harden it with target-type checks and `-n` flag. Add the reconciliation pass as a separate task.

---

### Pitfall 9: Idempotency bugs in `status:` checks

**What goes wrong:**
The maintainer adds a new `task install` step, writes a `status:` check that looks right, and ships it. The check uses a shell variable that's unset in the task's evaluation context (the live bug in `macos:shell` at `taskfiles/macos.yml:145` uses `$BREW_ZSH` instead of `{{.BREW_ZSH}}` — the task re-runs on every install). Or: the check tests for a sentinel file that gets touched at the wrong time. Or: the check depends on network state (e.g. `npx -y` against the registry, per `gsd-install`).

**Why it happens:**
- go-task evaluates `status:` in a fresh shell that doesn't inherit the caller's environment. Template variables (`{{.X}}`) interpolate at parse time; shell variables (`$X`) interpolate at runtime in a different scope. Easy to confuse.
- Sentinel-file patterns require choosing *when* to write the sentinel — too early and a failed install gets marked done.
- Network-dependent checks (curl, npx, git ls-remote) defeat the purpose of `status:` — they make re-runs slow and dependent on connectivity.

**How to avoid:**
- Lint `status:` checks for the `$VAR` vs `{{.VAR}}` mistake. A simple grep: any `\$[A-Z_]+` in a `status:` line that isn't `$HOME` or a documented shell builtin should be flagged. Add this to `task lint:taskfile`.
- For each install task, the `status:` check must test a **deterministic local condition** that the task itself creates:
  - For symlinks: `test -L "$TARGET" && [[ "$(readlink "$TARGET")" == "$SOURCE" ]]`
  - For installed packages: a sentinel file in `$XDG_STATE_HOME/dotfiles/` written *after* successful completion. Or query the package manager (`brew list --formula | grep -q ^foo$`).
  - For tools fetched via npx: cache the install to a local path with a version sentinel, check `test -f "$XDG_DATA_HOME/dotfiles/gsd-version" && grep -qF "$EXPECTED_VERSION" "$XDG_DATA_HOME/dotfiles/gsd-version"`.
- Run `task install` twice in CI; the second run must complete in <5s (per PROJECT.md constraint). Any task that re-executes on the second run has a broken `status:`.
- Document the rule in `CONVENTIONS.md`: "Every `cmds:` block must have a `status:` block. `status:` must not depend on network or on variables outside the task's resolved scope."

**Warning signs:**
- `time task install` on a converged machine takes >5s.
- `task install` triggers network calls (npx, curl, git fetch) when nothing has changed.
- `status:` uses `$VARNAME` where `VARNAME` isn't a posix env var.
- Adding a task without a `status:` block doesn't fail review.

**Phase to address:**
Install-engine phase + observability phase (the lint task + the two-run timing test). The existing `macos:shell` and `gsd-install` bugs are canonical instances — fix them in v2 by *structurally* requiring `status:` validation, not by patching one line.

---

### Pitfall 10: Bootstrap supply-chain risk and partial-failure recovery

**What goes wrong:**
Fresh-install bootstrap pipes `curl | sh` to fetch go-task (live bug per `CONCERNS.md` and `bootstrap.zsh:33`). A compromised CDN or MITM injects malicious code that runs with the maintainer's permissions on a new machine. Less dramatically: bootstrap fails halfway (network drops during `brew install`) and the machine is in an inconsistent state — some symlinks made, some not, no clear recovery path.

**Why it happens:**
- `curl | sh` is the well-known anti-pattern; it's used because it's simpler than verifying checksums.
- Bootstrap scripts often use `set -e` rather than `set -euo pipefail`, hiding unbound-variable bugs (live in `bootstrap.zsh:2`).
- Bootstrap isn't designed for resumability — it assumes happy-path linear execution.

**How to avoid:**
- Replace `curl | sh` for go-task with one of:
  - **Best:** Bootstrap installs Homebrew first (Homebrew's own install script is *also* curl-piped — accept this once and only once, with documented justification), then `brew install go-task`. Single point of trust.
  - **Acceptable:** Download the go-task install script, verify SHA256 against a hash committed in the repo, then execute.
  - **Not acceptable:** Current state of piping directly.
- `set -euo pipefail` mandatory in bootstrap and every executable zsh script in the repo (already in conventions, enforce with a hook or lint).
- Make bootstrap idempotent at every step (every step has the same `status:`-style guard as install tasks). Resume = re-run.
- Pin tool versions in the manifest where possible (`tools.brew_min_version`, `tools.go_task_min_version`). Bootstrap checks versions and refuses to proceed on mismatch rather than silently using whatever's installed.
- Document the bootstrap trust chain in `docs/SECURITY.md`: what's downloaded, from where, how it's verified, who you're trusting.

**Warning signs:**
- Bootstrap script contains `curl` and `sh` on the same line.
- A bootstrap failure halfway through requires manual cleanup before re-running.
- No documented "what to trust" for fresh installs.

**Phase to address:**
Bootstrap phase. Solve this once, properly, before the rewrite ships to any new machine.

---

### Pitfall 11: Documentation drift (conventions vs code)

**What goes wrong:**
`CLAUDE.md` says "all hooks use `set -euo pipefail`" but `agent-transparency.zsh` uses `local` at script scope, which shellcheck flags as an error (live bug per `CONCERNS.md`). `CONVENTIONS.md` documents `_:safe-link` as mandatory but `links:ssh` uses raw `ln -sf` for the 1Password agent config. AI agents follow the docs; humans follow the code; over time they diverge silently.

**Why it happens:**
- Docs are written once and not regenerated. Code evolves. Drift is the default state.
- Hooks enforce some rules (no AI attribution, no emojis) but not others (mandatory `_:safe-link`, mandatory `set -euo pipefail`, mandatory `status:` blocks). Undocumented rules can't be enforced; un-enforced rules drift.
- AI agents read docs and produce code that follows docs even when codebase reality has moved on. Humans read code and produce code that follows existing patterns even when docs forbid them.

**How to avoid:**
- Treat conventions as **executable** wherever possible. Each documented rule maps to a lint or hook:
  - "All scripts must `set -euo pipefail`" → `task lint:shell-headers` greps for `set -euo pipefail` in every `.zsh` executable.
  - "All install tasks must have `status:`" → `task lint:taskfile` parses YAML and checks every task with `cmds` also has `status`.
  - "All symlinks created via `_:safe-link`" → `task lint:taskfile` greps for bare `ln -s` outside helpers.yml.
  - "No macOS-only commands in `common/`" → `task lint:platform` (see Pitfall 7).
- A single `task lint` aggregates all of them. CI runs it.
- `docs/CONVENTIONS.md` is the canonical doc; `CLAUDE.md` *delegates* to it ("See CONVENTIONS.md for full rules"). Single source of truth.
- For rules that can't be linted (architectural choices, philosophy), add explicit examples to docs and review periodically — flag in a "convention audit" milestone every 6 months.

**Warning signs:**
- Convention docs are dated more than a month ago.
- AI agents produce code that violates conventions (the agent isn't lying — the docs really are out of date, or the codebase already drifted and the agent is matching reality).
- Pre-commit/CI passes on code that violates documented conventions.

**Phase to address:**
Observability/lint phase. The lint suite is the structural prevention; without it, every other convention is a suggestion.

---

### Pitfall 12: Testing floor — what's the minimum that actually catches things?

**What goes wrong:**
Dotfiles testing is famously hard. The maintainer skips it entirely (current state per `TESTING.md`: zero unit tests). A typo in `.zshrc` breaks all interactive shells until manually fixed. A refactored function silently returns wrong output. Six months later, a regression that would have been caught by a one-line test costs an hour of debugging.

**Why it happens:**
- Shell code is hard to test in isolation (depends on env vars, PATH, sourced state).
- Test frameworks (`bats`, `zunit`) have setup cost.
- Manual testing (open a new shell, run things) feels sufficient until it isn't.
- "Real" CI requires a macOS runner which adds cost/complexity.

**How to avoid:**
Pragmatic floor — pick a tier and *do that one*, don't aspire to a higher tier and ship none.

- **Tier 0 (baseline, do unconditionally):** Syntax check every `.zsh` file with `zsh -n` (parse-only, no execution). Fast, no framework, catches typos. Run in pre-commit and CI.
- **Tier 1 (high value):** Lint suite (see Pitfall 11). Add `shellcheck` for bash-compatible shell scripts; zsh isn't fully shellcheck-compatible but most logic is.
- **Tier 2 (function tests):** `bats` for pure-function unit tests on the small set of functions that have logic (parsing, string manipulation, path resolution). Most aliases don't need this; most one-liner functions don't either. Target: ~10 high-value tests, not 100.
- **Tier 3 (integration):** `task validate` on a converged real machine remains the integration test of record. Add `task install` idempotency timing (Pitfall 9) and `task perf:shell` startup measurement (Pitfall 6).
- **Tier 4 (full CI on macOS runner):** Optional. Costs money/time. Defer until a real bug slips through that this would have caught.

The trap to avoid: aiming for Tier 4 and shipping nothing. Tier 0 + Tier 1 + a small slice of Tier 2 is the realistic stopping point for a one-maintainer repo.

**Warning signs:**
- Refactoring a function breaks a different function and you find out by using the shell.
- "I'll add tests later" said more than once.
- A bug ships that `zsh -n` would have caught.

**Phase to address:**
Observability/test phase. Tier 0 + Tier 1 are not optional; treat them as part of the foundation.

---

### Pitfall 13: Bus-factor and undocumented machine-specific knowledge

**What goes wrong:**
The repo has four machines: personal-laptop, work-laptop, server-1, server-2. Each has implicit configuration that lives only in the maintainer's head: "server-1 needs the timezone set to UTC; server-2 needs eastern; the work laptop has a corporate proxy at `proxy.corp:8080`; the personal laptop has Music.app sync disabled in `defaults`." Six months later the maintainer themselves has forgotten which machine needs what. AI agents can't help because the knowledge isn't anywhere they can read.

**Why it happens:**
- One-maintainer repos accumulate tribal knowledge by default.
- "Obvious" decisions don't get documented because they were obvious at the time.
- The manifest captures *what* is installed but not *why* a particular machine needs it.

**How to avoid:**
- The machine manifest gets a top-level `description = """..."""` field. Required by schema. Documents purpose, distinguishing features, and rationale for any non-default settings. ~5-10 lines per machine.
- `docs/MACHINES.md` aggregates: one section per machine, hand-written narrative (when to use it, what runs on it, what's special). Updated when a new feature is added.
- For server-specific operational knowledge (cron jobs, services, backups, network), `docs/RUNBOOKS/<machine>.md` per machine. Or a section in `MACHINES.md`. Either way: written down, not in the maintainer's head.
- During phase transitions, ask: "If I lost this machine tomorrow, can I rebuild it from this repo + my password manager?" If the answer involves any remembered detail, add it to the docs *now*.

**Warning signs:**
- Fresh-install a machine and discover something you "always do" that isn't scripted.
- Manifest has no `description` field.
- The only person who can fix the server is the maintainer, even with full repo access for someone else.

**Phase to address:**
Documentation phase, ongoing. Cutover gate: every machine has a complete description before it cuts over.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hostname-based identity/feature selection (`if [[ $(hostname) == 'foo' ]]`) | Skip writing a manifest field | Silent breakage when hostname changes or pattern matches unexpectedly (live: `.zprofile:55`) | Never — explicit manifest selection is the whole point of v2 |
| Skipping `status:` on a "fast" install task | One less line per task | Re-run of `task install` becomes slow; install side-effects fire repeatedly (live: `gsd-install`, `brew:bundle`) | Never for install tasks; OK for explicitly-imperative tasks like `task update` |
| Inline `ln -sf` instead of `_:safe-link` | Slightly shorter task | Inconsistent symlink behavior, `mkdir -p` race traps, no centralized hardening (live: `links:ssh` 1Password block) | Never in this repo |
| Macros/aliases in `common/` that "happen to work" on the primary platform | Faster authoring | Server install ships broken aliases; failures are silent (live: 4 instances per `CONCERNS.md`) | Never — directory split is the structural answer |
| Manifest field added without schema update | Faster prototyping | Schema sprawl, manifest becomes write-once-read-never (Pitfall 2) | Only during pre-schema prototyping; once schema lands, never |
| Skipping the `description` field on a new machine manifest | One less line | Bus-factor accumulates; six months later you don't remember what this machine is for | Never if the machine survives more than a week |
| Pipe `curl` to `sh` for any installer | One less step | Supply-chain risk on every fresh install (live: `bootstrap.zsh:33`) | Only for Homebrew itself, with documented acceptance |
| Synchronous heavy operations in `.zshrc` or MOTD | Easier to implement | Shell startup regression; gradual death by 10ms (live: antigen apply, fastfetch in MOTD) | Never in interactive-shell path |
| Manifest list with implicit ordering ("things are in dependency order") | No explicit dependency declaration | Reordering breaks installs; new contributor adds an entry wrongly placed | Avoid — use explicit `depends_on` if order matters; otherwise sort alphabetically |
| "I'll port that function later" during the parallel rewrite | Faster phase completion | Half-migrations; cutover blocked when item finally needed; v1 keeps growing | Acceptable *only* if explicitly listed in the parity tracker as deferred-with-reason |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Homebrew (macOS) | Hardcoding `/opt/homebrew` or `/usr/local`; assuming Intel vs Apple Silicon | Detect by `uname -m`; use `$(brew --prefix)` once at startup and cache (current `Taskfile.yml:32-39` already does this — keep) |
| Homebrew (Linux) | Assuming Linuxbrew is at `/home/linuxbrew/.linuxbrew` for all users | Use `$(brew --prefix)` post-shellenv; gate Linuxbrew use behind a manifest feature, prefer apt/dnf for Linux servers |
| apt/dnf (Linux servers) | Treating Linux as a stripped-down macOS Brewfile | First-class Linux package manifest with its own bundles; not "macOS minus the GUI apps" |
| 1Password SSH agent | Hostname-based detection (live bug); assuming socket path is stable across 1Password versions | Manifest feature `one-password-ssh`; read socket path from 1Password's own env or config, don't hardcode |
| GitHub authentication (gh, git push) | Mixing personal/work tokens via `gh auth status` confusion | Per-identity `includeIf` in git config; `gh` uses `GH_HOST` and per-host config; never share a token across identities |
| Claude Code marketplaces/plugins | `npx -y` on every install (live: `gsd-install`); no version pinning | Pin marketplace/plugin versions in manifest; `status:` check verifies installed version matches pinned |
| Antigen / plugin manager | Calling `antigen apply` on every shell start; running update checks synchronously | Switch to zinit/antidote with deferred load; turn off auto-update in interactive path |
| `chsh` (default shell change) | Re-running on every install (live: `macos:shell` due to `$BREW_ZSH` vs `{{.BREW_ZSH}}`) | `status:` check tests `dscl . -read /Users/$USER UserShell` (macOS) or `getent passwd $USER` (Linux) against expected path |
| `defaults write` (macOS) | Re-running on every install regardless of current value | `status:` checks `defaults read <domain> <key>` and compares; only writes on mismatch |
| `cheat.sh` and similar external lookups | Plain HTTP (live: `cheat.zsh`); no TLS verification | HTTPS always; consider a local fallback if the function is critical |
| 1Password agent.toml | Tracked in repo (current state); contains paths that document local setup | Acceptable for now; flagged in `CONCERNS.md`; re-evaluate if 1Password adds tokens to this format |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous `antigen apply` on every shell | 200-500ms cold start (live) | Switch to deferred-load plugin manager; cache plugin compile output | Every interactive shell |
| Synchronous MOTD with `git log`/`git status`/`fastfetch` | Multi-second login on slow disk/network mounts | Async with timeout; cache to file with 24h TTL | Every login shell |
| `command -v` resolution at alias load time over many aliases | Slower `.zshrc` source | Acceptable if <50 aliases; cache resolutions if more | ~100+ aliases referencing Homebrew tools |
| Network calls in `status:` checks (`npx`, `git ls-remote`) | `task install` takes seconds even when nothing changed | `status:` must be local-only; cache external state to a sentinel file | Every `task install` |
| `brew bundle` with no `status:` | 30-90s per `task install` (live) | Sentinel file written on success; `status:` checks sentinel + Brewfile mtime | Every `task install` |
| Loading 70+ Claude skills on every Claude Code session start | Context bloat, slower agent response | Skills are externally sourced; keep flat structure; defer concern until >200 skills | At very large skill counts |
| `mdfind` / `locate` in interactive paths | Stalls until indexer responds | Use `find`/`fd` with explicit roots | Cold cache or large home dir |
| Heavy prompt with sync git status | Per-keystroke lag on large repos | Async git status (powerlevel10k pattern, starship's async mode) | Repos >10k files or slow filesystems |
| Synchronous tool completions (`kubectl`, `gcloud`, `terraform`) sourced in `.zshrc` | Cold start grows with each tool added | Lazy-load on first invocation via zinit `wait` or stub functions | Every interactive shell |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `curl <url> | sh` in bootstrap (live: `bootstrap.zsh:33`) | Compromised CDN or MITM executes arbitrary code with user privileges on every fresh install | Install Homebrew first, then `brew install go-task`; or checksum-verify the install script |
| Plain HTTP for external script lookups (live: `cheat.zsh`) | MITM returns malicious command suggestions presented as helpful output | HTTPS only; pin to known-good hosts |
| Identity bleed across machines (Pitfall 5) | Wrong git email signs commits; wrong SSH key authenticates | Manifest-driven `includeIf`; validate at install time; pre-commit email check |
| Committing private SSH keys | Repo-wide key compromise; instant credential leak | `.gitignore` private key patterns; pre-commit secret scan (existing `secret-scan.zsh` hook covers this — keep) |
| `sudo` in install paths without explicit justification | Unprivileged tasks request privileges, encouraging blanket-accept | Each `sudo` call documents *why* in a comment; minimize surface |
| 1Password socket env var leaking to subshells on wrong machine | SSH attempts use wrong agent / wrong identity | Gate `SSH_AUTH_SOCK` export on manifest feature, not on `hostname` (Pitfall 5) |
| `eval "$(brew shellenv)"` on every shell with no existence check (live: `.zprofile:36-47`) | If brew is missing, every shell prints an error and `.zshrc` fails to load | Wrap in `[[ -x "$DIRECTORY" ]] && eval ...` |
| Reading profile/identity from a file with `Match exec "cat ..."` in SSH config | Shell injection if the file is ever writable from another source (currently mitigated by `task profile:set` validation) | Use ssh config's `Include` directives keyed off file presence, not `exec`; manifest declares which identity files to install |
| Hooks that exit 0 on missing dependency (`hook::require_ggrep warn`) | Security hooks silently disabled when `ggrep` not installed | Security/blocking hooks must `fail closed` (exit 2 if `ggrep` missing); only advisory hooks fail open (current pattern is correct — preserve it) |
| Re-using a single Brewfile across machines with secrets in cask names or tap URLs | Inadvertently installs personal tooling on work machine, or vice versa | Per-machine bundle composition via manifest; bundle files only reference public packages |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but commonly miss a critical piece during this kind of rewrite.

- [ ] **Manifest engine:** Schema validation in place — verify by trying to install a manifest with an unknown key; must fail loudly.
- [ ] **Manifest engine:** `task manifest:show -- <machine>` prints fully-resolved post-merge TOML — verify against hand-computed expected output for at least one machine with overrides.
- [ ] **Per-feature install:** Pair install-task with remove-task — verify by removing a feature from the manifest and running `task install`; the side effects (symlinks, agent sockets, defaults) must disappear.
- [ ] **Symlinks:** All created via `_:safe-link` — verify with `grep -r 'ln -s' taskfiles/` returns only the helper definition.
- [ ] **Symlinks:** Validation checks readlink target, not just existence — verify by manually pointing a symlink elsewhere; `task validate` must flag it.
- [ ] **`status:` checks:** All install tasks have one — verify `task install` twice in a row on a converged machine completes in <5s and triggers no install commands on the second run.
- [ ] **`status:` checks:** No `$VAR` confusion — `grep -rE 'status:.*\$[A-Z_]+' taskfiles/` should be empty (except `$HOME` and documented exceptions).
- [ ] **Identity:** `task validate` reads actual git email and asserts it matches manifest — verify by temporarily setting wrong email; must flag.
- [ ] **Identity:** No hostname-based logic anywhere — `grep -rn 'hostname' zsh/ taskfiles/` finds no decision-influencing matches.
- [ ] **Shell startup:** `task perf:shell` exists and is in CI with a budget — verify by adding a `sleep 0.5` to `.zshrc` and ensuring CI fails.
- [ ] **Cross-platform:** `task lint:platform` flags macOS-only commands in `common/` — verify by adding `alias t=defaults` to `aliases/common/` and ensuring lint fails.
- [ ] **Cross-platform:** Server install in a clean VM (or container) succeeds end-to-end without manual intervention.
- [ ] **Bootstrap:** No `curl | sh` — `grep -E 'curl.*\|.*sh' bootstrap.zsh` returns empty (Homebrew install is its own audited step).
- [ ] **Bootstrap:** Resumable — kill bootstrap halfway through, re-run, must succeed.
- [ ] **Cutover:** Per-machine checklist exists and is filled in — `docs/CUTOVER.md` shows all 4 machine categories with verification steps and status.
- [ ] **Cutover:** v1 still works during the transition — verify by installing v1 from scratch on a test VM.
- [ ] **Docs:** `task lint:docs` (or equivalent) checks that every convention documented in `CONVENTIONS.md` has a corresponding lint/test — gaps flagged.
- [ ] **Machines:** Every machine manifest has a `description` field — schema enforces.
- [ ] **Testing:** Tier 0 (`zsh -n`) in pre-commit — verify by introducing a syntax error in a `.zsh` file; commit must fail.
- [ ] **Reconciliation:** `task links:reconcile` exists and removes orphaned symlinks — verify by manually creating a symlink into `$DOTFILEDIR` with no manifest entry; reconcile must remove it.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Manifest drift (Pitfall 1) | LOW | `task links:reconcile` + `task install` to converge state; identify the drift source (un-paired install/remove) and add the missing remove step |
| Schema sprawl (Pitfall 2) | MEDIUM | Schedule a "schema audit" milestone; consolidate redundant keys; migrate all machines in one commit; document deprecations |
| Merge ambiguity (Pitfall 3) | LOW-MEDIUM | Add the failing case to merge-function tests; fix the merge function; re-run `task manifest:show` on every machine to spot any other affected configs |
| Premature cutover (Pitfall 4) | HIGH | Roll back the affected machine to v1 (because v1 was kept working — this is why); identify gap; add to parity checklist; re-cut over when parity confirmed |
| Identity bleed (Pitfall 5) | MEDIUM-HIGH | `git filter-repo` or `git rebase -i` to rewrite affected commits; rotate any leaked-in-credentials; fix the manifest gating; add validation that would have caught it |
| Shell perf regression (Pitfall 6) | LOW | Run `zprof` or `zsh-bench`; identify the regression-causing change; revert or refactor to async/lazy; set up the CI budget if not present |
| Cross-platform leakage (Pitfall 7) | LOW | Move the offending file from `common/` to `darwin/` or `linux/`; add to `task lint:platform` if it slipped past |
| Symlink hygiene break (Pitfall 8) | LOW | `find ~ -xtype l -lname '*dotfiles*'` to enumerate broken; `task links:reconcile` to clean up; harden `_:safe-link` if pattern reoccurs |
| `status:` bug (Pitfall 9) | LOW | Fix the specific check; add the `$VAR` vs `{{.VAR}}` pattern to `task lint:taskfile` if it caught you |
| Bootstrap compromise (Pitfall 10) | CATASTROPHIC | Treat machine as compromised: rotate all credentials reachable from it, audit, reinstall OS in worst case |
| Doc drift (Pitfall 11) | LOW-MEDIUM | Update docs to match code or fix code to match docs (depending on which is right); add a lint to enforce the now-correct rule |
| Missing test catches a real bug | LOW | Write the test that would have caught it before fixing the bug; commit the test first |
| Bus-factor / undocumented config (Pitfall 13) | MEDIUM | When you discover something undocumented, write the doc *immediately*, before continuing work; treat this as non-negotiable |

---

## Pitfall-to-Phase Mapping

How roadmap phases should structurally address each pitfall. Phase names are descriptive — the actual roadmap may use different names but the dependency structure should match.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Manifest-vs-installed drift | Manifest engine | Install → remove feature from manifest → re-install → side effects gone |
| 2. Schema sprawl | Manifest engine | Schema JSON committed; invalid manifest rejected; new field requires schema PR |
| 3. Inheritance/override surprises | Manifest engine | Merge-function test fixtures cover every case; `task manifest:show` matches hand-computed expected |
| 4. Premature cutover | Cutover (gated by all earlier phases) | Per-machine cutover checklist; v1 verifiably installs from scratch during transition |
| 5. Identity bleed | Manifest engine + identity-config phase | No `hostname` references in decision paths; `task validate` reads actual git/ssh state and asserts manifest match |
| 6. Shell perf regression | Shell-config phase + observability phase | `task perf:shell` in CI with <200ms budget; regression fails CI |
| 7. Cross-platform leakage | Shell-content phase (porting) + observability phase | `task lint:platform` in CI; server install in clean VM succeeds end-to-end |
| 8. Symlink hygiene | Install-engine phase | `_:safe-link` is the only path; `task links:reconcile` removes orphans; validation checks readlink target |
| 9. `status:` idempotency bugs | Install-engine phase + observability phase | `task install` twice <5s on second run; `task lint:taskfile` flags `$VAR` in status blocks |
| 10. Bootstrap supply-chain | Bootstrap phase (first of the roadmap) | No `curl | sh` for go-task; trust chain documented; bootstrap resumable |
| 11. Doc drift | Observability/lint phase, ongoing | Each rule in `CONVENTIONS.md` has a lint; `task lint` aggregates; CI fails on violation |
| 12. Testing floor | Observability/test phase | `zsh -n` in pre-commit; lint suite in CI; small bats slice for high-value functions |
| 13. Bus-factor / machine docs | Documentation phase + cutover gate | Schema requires `description` on every machine; `docs/MACHINES.md` reviewed at each cutover |

---

## How the v2 Architecture Structurally Prevents Existing `CONCERNS.md` Issues

Cross-referencing the live-bug audit — the v2 design must not just fix these, but make them re-occurrence-resistant.

| Live `CONCERNS.md` issue | v2 structural prevention |
|--------------------------|--------------------------|
| `test` profile declared but unimplemented | Out of scope per PROJECT.md — drop entirely. Schema declares the closed set of valid identities; no "test" value exists. |
| `macos:shell` `$BREW_ZSH` vs `{{.BREW_ZSH}}` | `task lint:taskfile` flags `$VAR` in `status:` lines; CI fails the PR before it lands (Pitfall 9). |
| `.zprofile` hostname literal for 1Password | Manifest `features = ["one-password-ssh"]` drives the export; no `hostname` reference in shell startup code; `grep -rn hostname zsh/` is empty post-rewrite (Pitfall 5). |
| `gsd-install` re-runs `npx` every time | All install tasks require `status:` (lint enforces); GSD version pinned in manifest, sentinel file written on install (Pitfall 9). |
| `bootstrap.zsh` `set -e` only | Lint rule: every executable `.zsh` script must contain `set -euo pipefail`; hook or CI check enforces (Pitfall 10, Pitfall 11). |
| `bootstrap.zsh` `curl | sh` | Bootstrap installs Homebrew first (single documented trust event), then `brew install go-task` (Pitfall 10). |
| Antigen + sync MOTD = ~500ms startup | Plugin manager swap (zinit/antidote); MOTD async-with-TTL; `task perf:shell` enforces <200ms budget in CI (Pitfall 6). |
| macOS-only aliases in `common/` | Directory split (`common/` / `darwin/` / `linux/`) loaded by `uname`; `task lint:platform` flags macOS-only commands in `common/` (Pitfall 7). |
| `agent-transparency.zsh` `local` at script scope | Shellcheck (where applicable) + lint suite; rewrite to use a function-scoped main (Pitfall 11). |
| `pubkey.zsh` stale docstring | Documentation drift — same root cause as Pitfall 11. The fix is structural (lint + review at convention audit milestones), not just patching this one example. |
| No work aliases/functions dir | Manifest declares what dirs are loaded; absent dirs are explicitly absent, not silently skipped. Or: pre-create empty dirs via install task with a `.gitkeep` and a placeholder. |
| No syntax checking of zsh files | Tier 0 testing (`zsh -n`) is non-negotiable (Pitfall 12). |
| Hardware/general/networking aliases break on Linux | Same as macOS-only-in-`common/` — directory split + lint (Pitfall 7). |

---

## Sources

- `.planning/codebase/CONCERNS.md` (2026-05-13, this repo) — primary source for live bugs; pitfalls 5, 6, 7, 8, 9, 10, 11 all map to documented instances.
- `.planning/codebase/CONVENTIONS.md` (this repo) — existing convention catalogue; basis for the "every rule should be a lint" position in Pitfall 11.
- `.planning/codebase/TESTING.md` (this repo) — current state of validation; basis for the testing tier framework in Pitfall 12.
- `.planning/PROJECT.md` (this repo) — locks in scope; "explicit machine selection" and "no hostname guessing" decisions inform Pitfalls 5 and 13.
- [GitHub does dotfiles](https://dotfiles.github.io/) — community discourse on symlink hygiene and idempotent install scripts (`ln -sfn` pattern).
- [Missing Semester — Dotfiles](https://missing.csail.mit.edu/2019/dotfiles/) — canonical primer on dotfiles structure and the "test on a fresh machine" discipline (informs Pitfall 4 cutover checklist).
- [Home Manager Manual](https://nix-community.github.io/home-manager/) — per-machine config patterns; informs Pitfall 5 (identity gating) and Pitfall 1 (declarative reconciliation).
- [Migrating from Nix to Chezmoi](https://htdocs.dev/posts/migrating-from-nix-and-home-manager-to-homebrew-and-chezmoi/) — concrete migration write-up; informs Pitfall 4 (parallel-rewrite pace).
- [Platform rewrites: lessons learned](https://blog.thesharmas.org/2019/10/11/platform-rewrites-lessons-learned/) — "don't aim for feature parity, aim for solving the user need" — tempered against the local constraint that this rewrite explicitly *does* require parity per PROJECT.md.
- [zsh-bench (romkatv)](https://github.com/romkatv/zsh-bench) — benchmark methodology for Pitfall 6; the canonical reference for "deferred-init may not be useful in practice."
- [Speeding up Zsh Startup by 81%](https://wicksipedia.com/blog/speeding-up-zsh-startup/) — concrete antigen-to-zinit migration; informs the plugin-manager swap recommendation in Pitfall 6.
- [zsh-plugin-manager-benchmark (rossmacarthur)](https://github.com/rossmacarthur/zsh-plugin-manager-benchmark) — comparative benchmarks across antigen/antidote/zim/zinit.
- [coreutils Homebrew formula and gnubin guide](https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da) — informs Pitfall 7's Option A (drop `g` prefix via `gnubin` PATH addition).
- [Taskfile official guide](https://taskfile.dev/docs/guide) — `status:` semantics; informs Pitfall 9.
- [JSON Schema for TOML validation](https://json-schema-everywhere.github.io/toml) — informs Pitfall 2's schema enforcement recommendation.
- [coder/coder dotfiles symlink issue](https://github.com/coder/coder/issues/21108) — concrete instance of the "symlink over existing directory" trap; informs Pitfall 8.
- Direct experience captured in `CONCERNS.md`: the `.zprofile:55` hostname bug, the `macos:shell` template-var bug, and the antigen perf cost are all *this repo's own history* — the most reliable source for what re-occurs in dotfiles refactors.

---

*Pitfalls research for: manifest-driven dotfiles refactor*
*Researched: 2026-05-13*
