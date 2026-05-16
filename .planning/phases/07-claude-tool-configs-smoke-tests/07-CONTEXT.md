# Phase 7: Claude + Tool Configs + Smoke Tests - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the Claude Code config tree into the v2 install pipeline, deploy the seven
non-shell tool configs (ghostty, glow, trippy, tlrc, conda, eza, motd) under
`configs/<tool>/` via hardened symlink helpers, replace the v1
`npx`-on-every-install GSD task with an artifact-presence sentinel + a separate
explicit `task claude:update`, formalize the marketplace install as a
`status:`-gated no-op, smoke-test the four named hooks (with the v1
`agent-transparency.zsh` `local`-at-script-scope bug fixed), and aggregate
manifest + hook tests under root `task test`. Replaces `taskfiles/claude-stub.yml`
with the real `taskfiles/claude.yml`; extends `taskfiles/links.yml` with the
P7 entries; harden `taskfiles/helpers.yml` (`_:safe-link` target-type guard
+ `_:check-link` strict mode); add `taskfiles/test.yml` (new); add
`install/test-hooks.zsh` (new).

**Key architectural decision (sets the tone):** Mixed top-level claude/
symlinks (2 file + 3 dir + 1 per-file subtree), per-tool subdirectory under
configs/ always (source filename = destination filename), no GSD version pin
(touchfile-sentinel idempotency + separate explicit `task claude:update`), and
runner-with-inline-fixtures hook smoke tests scoped to the four named hooks.
The CLDE-03 wording in REQUIREMENTS ("GSD install task uses a version-pinned
sentinel file") softens here -- the user's intent is "latest-when-explicitly-
updated, never on every `task install`," which the touchfile sentinel
satisfies. CLDE-03's REQUIREMENT text gets a one-word amend (planner action
item) from "version-pinned sentinel" to "presence sentinel."

**In scope:**

- **`taskfiles/claude.yml`** -- replaces `taskfiles/claude-stub.yml` in the
  root Taskfile.yml `includes.claude:` slot. Tasks:
  - `claude:install` -- aggregator. Sequences: marketplace ensure (CLDE-04
    status-gated), GSD install (CLDE-03 sentinel-gated), then exits clean.
    No `cmds:` body of its own beyond `task:` delegations + a final success
    message. Carries `# lint-allow: cmds-without-status` marker (LINT-01/03a
    aggregator exemption).
  - `claude:marketplace` -- registers `CLAUDE_MARKETPLACES` and installs
    `CLAUDE_PLUGINS` (vars carried over from v1 `taskfiles/claude.yml`).
    `status:` block: two conditions parsed via `jq` against
    `claude plugin marketplace list --json` (every declared marketplace
    registered) AND `claude plugin list --json` (every declared plugin
    installed). Template-vars-only (LINT-02 compliant). `cmds:` only fires
    on a fresh box or when the lists drift. Gated on
    `index .MANIFEST.features "claude-marketplace"` (kebab-case index form,
    CLAUDE.md rule) -- servers with `claude-marketplace = false` skip the
    task entirely at the feature-gate level (server-1.toml, server-2.toml).
  - `claude:gsd` -- installs `get-shit-done-cc` via
    `npx -y get-shit-done-cc@latest --claude --global`. `status:` block:
    `test -f {{.GSD_SENTINEL}}` where
    `GSD_SENTINEL: '{{.XDG_STATE_HOME}}/dotfiles/gsd-installed'`. After
    successful npx, `touch` the sentinel. No version comparison; no
    artifact-path coupling to GSD's internal layout. Always-on (no feature
    flag) on machines that pass the upstream `claude-marketplace` gate --
    actually GSD is independent of ECC marketplace; the planner may want a
    separate `claude-gsd` feature flag OR just always-on for every machine
    that has `claude` CLI installed. Recommend always-on; server-1 and
    server-2 are also v2-managed and benefit from `task progress` for state.
  - `claude:update` -- explicit refresh. Three sub-cmds:
    (1) `claude plugin marketplace update`,
    (2) `claude plugin update --all` (or per-plugin loop -- matches v1's
        `plugins-update` shape for the `CLAUDE_PLUGINS` list),
    (3) `rm -f {{.GSD_SENTINEL}} && task claude:gsd`.
    NOT in `task install`'s call graph. NOT in `task install`'s
    re-trigger semantics. Run explicitly when you want fresh artifacts.
    Preserves v2 D-10 ("install IS update") for the root pipeline while
    giving claude-scoped knobs their own update path. Marketplace + plugin
    portions are also gated on `claude-marketplace`; the GSD portion runs
    unconditionally on machines that have the CLI.
  - `claude:status` -- carries over from v1 (`claude plugin marketplace
    list` + `claude plugin list`). No `status:` block; always re-runs;
    diagnostic-only. `# lint-allow: cmds-without-status` marker.
  - `claude:validate` -- ports v1 logic verbatim (claude-CLI-present,
    jq-present, per-marketplace check/cross, per-plugin check/cross) plus
    a new GSD sentinel check (`test -f {{.GSD_SENTINEL}}` -> check; absent
    -> cross "run task claude:install"). Composed into root `task validate`
    in P8 (CUTV-01). No `status:` block (validate is diagnostic);
    `# lint-allow: cmds-without-status` marker.
  - `claude:ensure-cli` -- internal. Hard-fail with a helpful message when
    `command -v claude` returns non-zero: "Run `task packages:install` first
    (claude CLI from core.rb) before `task claude:install`." Same shape as
    v1's `ensure-cli`. `claude:marketplace` and `claude:gsd` depend on it
    via `deps: [ensure-cli]`. `task install`'s call graph already runs
    `packages:install` before `claude:install`, so this is the safety net
    for direct invocation (`task claude:install` on a fresh box).

- **`claude/` tree -- repo ownership rules (CLDE-01):**
  - **Files (repo-owned):** `claude/CLAUDE.md`, `claude/settings.json`.
    Both committed; symlinked as files.
  - **`claude/hooks/` (mixed):** Repo owns the seven zsh hooks wired by
    `settings.json`
    (`post-compact.zsh`, `agent-transparency.zsh`, `secret-scan.zsh`,
    `block-destructive.zsh`, `no-ai-comments.zsh`, `no-emojis.zsh`,
    `notify.zsh`) + `lib.zsh` (shared helpers). Repo does NOT own
    `gsd-*.js` / `gsd-*.sh` files -- those are written by
    `npx get-shit-done-cc` into `~/.config/claude/hooks/` at install time.
    **Pre-Phase-7 cleanup (P7 deliverable):** remove the committed
    `gsd-*.js` / `gsd-*.sh` files from `claude/hooks/` and `.gitignore`
    them so GSD-installer outputs don't accidentally get committed by
    future `git add .` from `~/.config/claude/hooks/`.
  - **`claude/agents/` (deletion + dir symlink):** Currently committed with
    ~33 `gsd-*` agents. GSD installer owns this directory at runtime.
    **Pre-Phase-7 cleanup:** delete the committed `gsd-*` agents from
    `claude/agents/`. Leave the directory with just a README explaining
    the deployment shape. The dir symlink (`claude/agents/` ->
    `~/.config/claude/agents/`) re-targets the (now-near-empty) repo dir;
    GSD installer fills it at runtime. **Critical:** since the directory
    IS a symlink at install time, GSD's writes land in the symlink target
    (i.e., in the repo's `claude/agents/`), which is committed. That
    means GSD-installer output WOULD show up in git status. The
    cleanest fix is `.gitignore`'ing `claude/agents/gsd-*.md`.
  - **`claude/commands/`:** Currently has only a README. Same dir-symlink
    pattern as `agents/`.
  - **`claude/skills/`:** Currently has ~64 `gsd-*` skill subdirs.
    Same surgery as `agents/`: delete `gsd-*` subdirs, `.gitignore`
    `claude/skills/gsd-*/`.
  - **Symlinks emitted by `taskfiles/links.yml`** (new entries):
    - 1 file symlink: `claude/CLAUDE.md` -> `~/.config/claude/CLAUDE.md`
    - 1 file symlink: `claude/settings.json` -> `~/.config/claude/settings.json`
    - 8 file symlinks (one per zsh hook + lib.zsh):
      `claude/hooks/<name>.zsh` -> `~/.config/claude/hooks/<name>.zsh`
    - 3 dir symlinks: `claude/{agents,commands,skills}` ->
      `~/.config/claude/{agents,commands,skills}`
    - Total: 13 entries. Aggregated under a `claude:` sub-task in
      `links.yml` (`task: claude` in the `all:` aggregator).
  - **`.gitignore` additions:** `claude/agents/gsd-*.md`,
    `claude/commands/gsd-*`, `claude/skills/gsd-*/`, `claude/hooks/gsd-*`.
    Prevents GSD-installer runtime artifacts from being committed by
    accident.

- **`configs/<tool>/` -- per-tool subdirectory, always (TOOL-01, TOOL-02):**
  Source filenames match destination. New entries:
  - `configs/ghostty/config` -> `~/.config/ghostty/config` (file symlink).
    v1 source: `zsh/configs/ghostty/` (directory containing one `config`
    file). v2 source is just the `config` file. Gated on
    `index .MANIFEST.features "ghostty"` (existing flag).
  - `configs/glow/glow.yml` -> `~/.config/glow/glow.yml`.
    `configs/glow/glow_style.json` -> `~/.config/glow/glow_style.json`.
    v1 sources: `zsh/configs/glow.yml` + `zsh/styles/glow_style.json`.
    Always-on (glow ships via `core.rb`).
  - `configs/trippy/trippy.toml` -> `~/.config/trippy/trippy.toml`.
    v1 source: `zsh/configs/trippy.toml`. Always-on.
  - `configs/tlrc/config.toml` -> `~/.config/tlrc/config.toml`.
    v1 source: `zsh/configs/tlrc.toml` (rename to `config.toml` in transit
    -- match-destination-filename rule).
  - `configs/conda/condarc` -> `~/.config/conda/condarc`.
    v1 source: `zsh/configs/condarc`. Always-on.
  - `configs/eza/theme.yaml` -> `~/.config/eza/theme.yaml`.
    v1 source: `zsh/styles/eza_style.yaml` (rename to `theme.yaml` in
    transit). Always-on.
  - `configs/motd/motd_tron.txt` + `configs/motd/motd_sysinfo.jsonc` --
    NO symlinks. Read directly by `shell/functions/motd.zsh` at runtime
    from `${DOTFILEDIR}/configs/motd/`. Function-side: motd.zsh already
    gates on the `motd` feature flag (P3 D-10 pattern); no separate
    symlink-side gating needed. v1 sources: `zsh/configs/motd_tron.txt`,
    `zsh/configs/motd_sysinfo.jsonc`.
  - Total new entries in `taskfiles/links.yml`: ~7 (one symlink-batch task
    per tool, conditional on `ghostty` for the ghostty entry).
  - All seven `configs/<tool>/` directories get a one-paragraph
    `configs/<tool>/README.md` (purpose + symlink destination). The
    aggregate `configs/README.md` (currently a P3 stub) gets a real body
    -- one-line table of tools + destinations + feature gates.

- **Hook smoke tests (TEST-01):**
  - **Runner:** `install/test-hooks.zsh` -- single file, inline fixtures.
    One function per hook (`test_secret_scan`, `test_no_emojis`,
    `test_no_ai_comments`, `test_agent_transparency`). Each function
    pipes a synthetic JSON payload (Claude Code's hook stdin schema --
    `tool_name`, `tool_input`, `cwd`, etc.) via heredoc to the hook and
    asserts exit code + stderr regex match.
  - **Coverage matrix:** Two scenarios per hook (~8 fixtures total):
    - **Pass:** clean input -> hook exits 0 with no stderr output (or
      info-level stderr only).
    - **Block/Warn:** flagged input -> hook exits 2 (block) for
      `secret-scan` and `block-destructive`-class; exits 0 with stderr
      warning regex for `no-emojis`, `no-ai-comments`, `agent-transparency`.
      The four named hooks have asymmetric exit-code semantics; the
      runner encodes the expected code per hook.
  - **Scope:** the four named in CLDE-02 -- `secret-scan`, `no-emojis`,
    `no-ai-comments`, `agent-transparency`. The other three repo-owned
    zsh hooks (`block-destructive`, `notify`, `post-compact`) are out of
    smoke-test scope -- `notify` and `post-compact` are side-effecty
    (desktop notification; git context dump) and hard to assert on
    without mocking; `block-destructive` is gate-shaped like `secret-scan`
    and could be folded in if planner wants symmetry, but it's not named
    in CLDE-02 or TEST-01, so stays out by default. JS hooks (`gsd-*.js`)
    are entirely out of scope (not repo-owned per D-01).
  - **Idempotency contract:** the runner runs synthesized JSON payloads
    only; no host-side state mutation; safe to run on any machine including
    CI.

- **Root `task test` aggregator (TEST-02):**
  - New `taskfiles/test.yml` with two tasks:
    - `test:hooks` -- invokes `install/test-hooks.zsh`. Per-hook
      check/cross output via `messages.zsh`. Exits non-zero if any
      fixture fails.
    - `test` (the root-callable name) -- aggregator. Two `cmds:`:
      `task: manifest:test` (P1 deliverable -- deep-merge fixtures) and
      `task: test:hooks`. Aggregator (`# lint-allow: cmds-without-status`).
  - Root `Taskfile.yml` `includes:` gets `test: ./taskfiles/test.yml`.
  - CI hook (out of scope for v1; documentation note in DOCS-08 in P8):
    `task test` runs alongside `task lint` as the Tier-0 gate.

- **`taskfiles/helpers.yml` hardening (TOOL-03, TOOL-04) -- Claude's Discretion:**
  - **`_:safe-link` (TOOL-03):** Add a pre-check before `ln -sfn`: if
    `[[ -e "{{.TARGET}}" && ! -L "{{.TARGET}}" ]]`, fail with
    "_:safe-link: target exists and is not a symlink: {{.TARGET}}". This
    refuses to clobber regular files / directories. Behavior:
    existing-symlink -> `ln -sfn` re-points (matches current);
    no-target -> create (matches current);
    existing-non-symlink -> hard fail (NEW). Backward compatible with
    P3/P4/P5/P6 callers (all of those create symlinks where no real file
    pre-existed in v2's parallel-rewrite invariant; the guard would only
    trip on a cutover from v1 if v1 left a real file where the v2 symlink
    expects to go -- desired safety behavior).
  - **`_:check-link` (TOOL-04):** Extend with optional `SOURCE` var. When
    `SOURCE` is provided, add a third check: `[[ "$(readlink -f "{{.TARGET}}")"
    == "{{.SOURCE}}" ]]` -- the symlink resolves to the expected source
    path. When `SOURCE` is absent, fall back to current two-check
    behavior (exists + non-broken). Opt-in strict mode; existing P3+P4
    callers don't break. P7's new `_:check-link` callers in
    `taskfiles/claude.yml` validate and `taskfiles/links.yml`'s
    `validate:` task pass `SOURCE` for the new claude/configs/ entries.
    Retrofit of P3/P4 existing entries is a Claude's Discretion call
    (recommend yes -- safety win is uniform).

- **`agent-transparency.zsh` rewrite (CLDE-02):** v1 file has `local` at
  script scope (lines 11, 39). Rewrite using a function wrapper -- wrap
  the script body in `main()` and call `main "$@"` at the bottom; or
  drop `local` and use plain assignments at script scope. shellcheck-clean
  before P7 ships. Smoke test confirms the rewrite doesn't break logging
  behavior.

- **Required ROADMAP / REQUIREMENTS edits (planner action items):**
  - `REQUIREMENTS.md` **CLDE-03**: text says "GSD install task uses a
    version-pinned sentinel file as its `status:` check". Soften to:
    "GSD install task uses a presence sentinel file as its `status:` check
    -- `npx` runs only when the sentinel is absent. An explicit
    `task claude:update` deletes the sentinel and re-runs `npx`."
  - `ROADMAP.md` Phase 7 **success criterion #2**: text says "uses a
    version-pinned sentinel file". Same soften.
  - `PROJECT.md` Active section "Claude marketplace and plugin install
    with a working `status:` guard" -- already matches D-CLDE-04; no edit.

- **Install-pipeline participation -- `task install` call graph (Phase 7
  position):**
  ```
  manifest:resolve
   -> links:all              (P3 + P4 + P7: claude + configs subtasks added)
   -> packages:install       (P5)
   -> claude:install         (P7: marketplace + gsd, gated on features.claude-marketplace)
   -> macos:defaults         (P6)
   -> macos:shell            (P6)
   -> packages:verify        (P5 final-step gate)
  ```
  No re-ordering of existing P5/P6 tasks. P7 fills the `claude:install`
  slot that currently no-ops via the stub.

**Out of scope (deferred to later phases or future versions):**

- `task validate` root composition -- Phase 8 (CUTV-01). P7 ships
  `task claude:validate` ready to compose.
- `task links:reconcile` two-mode (detect + cleanup) -- Phase 8 (CUTV-02,
  CUTV-07, CUTV-08). The orphan-detector for `claude/agents/gsd-*` etc.
  is critical -- without it, GSD-installer-written files outside the
  `.gitignore` set look like orphans. Phase 8 must understand the
  "repo-owned vs runtime-managed" split.
- v1 file deletion (`taskfiles/claude.yml` already exists -- it's v2-shaped
  by P2's overhaul; the v2 P7 changes overwrite it. v1 `zsh/configs/*`,
  `zsh/styles/*` source files stay byte-stable on disk until P8 cutover.
- Docs work: `docs/MIGRATION.md` v1->v2 mapping (Phase 8 DOCS-05),
  `docs/MACHINES.md` per-machine purpose (Phase 8 DOCS-06),
  `docs/CUTOVER.md` per-machine fresh-install procedure (Phase 8 DOCS-08).
  P7 ships only the per-directory READMEs (`configs/README.md`,
  per-tool README, `claude/README.md` if absent).
- Hook smoke tests for `block-destructive`, `notify`, `post-compact`
  (out of CLDE-02 named scope).
- JS hook smoke tests (`gsd-*.js`) -- not repo-owned.
- Per-tool feature flags (beyond `ghostty`/`motd`/`claude-marketplace`) --
  no use case; the CLIs land via core.rb on every machine.
- `_:safe-link` directory-merge mode (TOOL-03 only refuses to clobber;
  no "merge into existing directory" semantics).
- Hook coverage matrix beyond pass+block per hook.
- A `task claude:bump-gsd` task that pins a specific version -- the user
  explicitly rejected version pinning. If a specific version is ever
  needed (security pin, breaking-change avoidance), it gets added then.

**Requirements addressed:** CLDE-01, CLDE-02, CLDE-03, CLDE-04, TOOL-01,
TOOL-02, TOOL-03, TOOL-04, TEST-01, TEST-02

</domain>

<decisions>
## Implementation Decisions

### Claude Config Deployment (CLDE-01)

- **D-01: Mixed top-level symlinks for claude/.** 13 entries total in
  `taskfiles/links.yml`: 2 file symlinks at the top (`CLAUDE.md`,
  `settings.json`), 3 directory symlinks for the GSD-managed trees
  (`agents/`, `commands/`, `skills/`), and 8 file symlinks inside
  `hooks/` (the 7 repo-owned zsh hooks + `lib.zsh`). The hooks subtree
  is per-file so GSD-installer-written `gsd-*.js`/`gsd-*.sh` runtime
  files can coexist as native files in `~/.config/claude/hooks/`.
  agents/commands/skills are dir symlinks because GSD owns those
  directories at runtime -- the repo's (near-empty post-cleanup) source
  directories ARE the target of write operations from
  `npx get-shit-done-cc`. **Rationale (user-led):** "Mixed top-level
  (6 links) (Recommended)" + "Repo owns only the 7 zsh hooks
  (Recommended)" + "Per-file symlinks only for hooks/; agents/commands/
  skills stay dir (Recommended)." The two answers, taken together,
  produce the 13-entry split.

- **D-02: Repo owns only hand-authored Claude assets.** Drop the
  committed `gsd-*` files from `claude/agents/` (~33 files),
  `claude/skills/` (~64 dirs), and `claude/hooks/` (8 JS/sh files).
  `.gitignore` `claude/agents/gsd-*.md`, `claude/skills/gsd-*/`,
  `claude/commands/gsd-*`, `claude/hooks/gsd-*` so GSD-installer-written
  artifacts don't get accidentally re-committed.
  **Rationale (user-led):** GSD is its own deploy system; freezing its
  artifacts in the dotfiles repo couples our release cadence to theirs
  unnecessarily and produces phantom diffs every time GSD updates.

- **D-03: Global scope only.** P7 deploys the global
  `~/.config/claude/*` tree only. The project-level `.claude/CLAUDE.md`
  stays in-place at the repo root and is auto-loaded by Claude when
  working in this repo. No symlink, no template scaffolding for other
  projects. **Rationale (user-led):** "Global only -- project-level is
  in-place (Recommended)."

- **D-04: Flat `claude/hooks/` layout.** All 7 repo-owned zsh hooks live
  directly under `claude/hooks/` (no per-lifecycle subdirectories). The
  hooks.json file is the canonical wiring -- it names which hook runs on
  which event. Filesystem layout matches v1 + CLAUDE.md's "flat directories
  in v1" convention. **Rationale (user-led):** "Flat claude/hooks/
  (Recommended)."

### Tool Config Layout (TOOL-01, TOOL-02)

- **D-05: Per-tool subdirectory under configs/, always.** Even single-file
  tools get their own directory: `configs/tlrc/config.toml`,
  `configs/conda/condarc`, `configs/eza/theme.yaml`, `configs/ghostty/config`,
  `configs/glow/{glow.yml,glow_style.json}`, `configs/trippy/trippy.toml`,
  `configs/motd/{motd_tron.txt,motd_sysinfo.jsonc}`. Each subdir gets a
  `README.md`. **Rationale (user-led):** "Per-tool subdirectory, always
  (Recommended)." Predictable shape, matches the README-per-directory
  pattern from P3 SC#6.

- **D-06: Source filename equals destination filename.** No rename
  indirection in links.yml. v1 `zsh/styles/eza_style.yaml` -> v2
  `configs/eza/theme.yaml` (renamed in transit during P7 port). v1
  `zsh/configs/tlrc.toml` -> v2 `configs/tlrc/config.toml`. The
  `_:safe-link` call reads
  `{ SOURCE: "{{.DOTFILEDIR}}/configs/eza/theme.yaml", TARGET: "{{.XDG_CONFIG_HOME}}/eza/theme.yaml" }`
  with matching basenames. **Rationale (user-led):** "Match destination
  (Recommended)." Removes a translation step in your head and in
  links.yml.

- **D-07: Only ghostty gated; rest always-on.** ghostty config is
  feature-gated on the existing `ghostty` flag in `defaults.toml`
  (already enabled on personal-laptop + work-laptop; absent -> false
  on servers). The other six configs (glow, trippy, tlrc, conda, eza,
  motd) are always-on -- their CLIs land via `core.rb` on every machine.
  motd's source files are read by `shell/functions/motd.zsh` which
  already gates on the existing `motd` feature flag; no separate
  symlink-side gating needed. **Rationale (user-led):** "Only ghostty
  gated; rest always-on (Recommended)." No new feature flags introduced.

- **D-08: motd lives at configs/motd/ with no symlink.** Source files
  `motd_tron.txt` and `motd_sysinfo.jsonc` live at `configs/motd/` for
  symmetry with sibling tool configs. `shell/functions/motd.zsh` reads
  them at runtime from `${DOTFILEDIR}/configs/motd/`. `links.yml` has
  no motd entry. **Rationale (user-led):** "configs/motd/ with no
  symlink in links.yml (Recommended)." Treats motd consistently with
  siblings even though it isn't symlinked.

### GSD + Marketplace Status Design (CLDE-03, CLDE-04)

- **D-09: No GSD version pin; touchfile sentinel only.** The pinned-version
  framing in CLDE-03 / ROADMAP P7 success #2 is rejected -- GSD is meant
  to track latest. **`taskfiles/claude.yml`** has no `CLAUDE_GSD_VERSION`
  var. `claude:gsd` status:
  `test -f {{.GSD_SENTINEL}}` (where
  `GSD_SENTINEL: '{{.XDG_STATE_HOME}}/dotfiles/gsd-installed'`).
  `cmds:` runs `npx -y get-shit-done-cc@latest --claude --global` then
  `touch {{.GSD_SENTINEL}}`. The sentinel is empty -- timestamp-only;
  presence IS the contract. **Required REQUIREMENTS/ROADMAP edit:**
  soften "version-pinned" -> "presence" in both docs (planner action item).
  **Rationale (user-led):** "isnt GSD automatically updated as part of
  the install & update process? why pin the version? wouldnt we always
  want the latest?" -- correct; pinning a version artificially freezes
  what's meant to be a rolling target.

- **D-10: `task claude:update` is the explicit refresh path.** Separate
  task (NOT in `task install`'s call graph). Three cmds in order:
  (1) `claude plugin marketplace update`,
  (2) per-plugin loop matching v1's `plugins-update` against
      `CLAUDE_PLUGINS`,
  (3) `rm -f {{.GSD_SENTINEL}} && task: claude:gsd`.
  Preserves v2 D-10 root-pipeline "install IS update" while letting
  per-tool refresh paths exist where they're useful. The naming
  asymmetry with D-10 ("`task install` IS `task update`" at the root,
  but `claude:install` and `claude:update` are distinct in this
  namespace) is fine -- the root D-10 rule prevents the root drift class
  (`task update` adds a package, fresh-install path forgets); the
  per-tool update is an explicit user action, not an automatic
  background refresh. **Rationale (user-led):** "Separate task:
  `task claude:update` (Recommended)."

- **D-11: GSD sentinel is our own touchfile, not a GSD-internal artifact.**
  Path: `{{.XDG_STATE_HOME}}/dotfiles/gsd-installed`. Lives in dotfiles'
  own state directory (we control it; GSD updates can't accidentally
  invalidate it by reshuffling their own files). Matches the existing
  state-file pattern (P1: `$XDG_STATE_HOME/dotfiles/{machine,resolved.json}`).
  **Rationale (user-led):** "$XDG_STATE_HOME/dotfiles/gsd-installed
  touchfile (Recommended)." Decoupled from GSD's internal layout.

- **D-12: Marketplace status is two-condition.** `claude:marketplace`
  status: block:
  (1) `claude plugin marketplace list --json | jq` parses every entry
      in `{{.CLAUDE_MARKETPLACES}}` and asserts present;
  (2) `claude plugin list --json | jq` parses every entry in
      `{{.CLAUDE_PLUGINS}}` and asserts present.
  Both must return 0 for the task to no-op. Template-vars-only
  (LINT-02). Mirrors P5 packages:install two-condition status pattern.
  jq and claude CLI are both required (`claude:ensure-cli` is a `deps:`).
  **Rationale (user-led):** "Two-condition status: marketplaces +
  plugins (Recommended)."

- **D-13: claude:install hard-fails when CLI missing.** `claude:ensure-cli`
  is the gate. If `command -v claude` returns non-zero, fail with
  "Run `task packages:install` first (claude CLI from core.rb) before
  `task claude:install`." `task install`'s call graph runs
  `packages:install` before `claude:install` so the case only arises
  on direct invocation. **Rationale (user-led):** "Status fails (task
  runs); claude:install hard-fails with helpful message (Recommended)."
  No silent skip; no warning-then-continue. Same shape as v1's
  `ensure-cli`.

- **D-14: `task claude:update` is claude-scoped only.** Does NOT touch
  brew packages. brew updates go through `brew upgrade` directly (or a
  future `task packages:update` if one materializes -- out of P7 scope).
  Single-responsibility task. **Rationale (user-led):** "Claude-scoped
  only (Recommended)."

### Hook Smoke Tests (TEST-01)

- **D-15: Single zsh runner with inline fixtures.** `install/test-hooks.zsh`
  is the runner. One function per hook (`test_secret_scan`,
  `test_no_emojis`, `test_no_ai_comments`, `test_agent_transparency`).
  Each function defines its pass + block fixtures as heredocs inline,
  pipes them to the hook via stdin, captures exit code + stderr, and
  asserts both via `messages.zsh`'s `check`/`cross`. One file, fixtures
  next to assertions. **Rationale (user-led):** "Single zsh runner with
  inline fixtures (Recommended)."

- **D-16: Coverage = one pass + one block scenario per hook.** Two
  fixtures per hook x 4 hooks = ~8 fixtures. Smoke test, not full
  coverage. Catches regressions in the gate without becoming a
  maintenance burden. **Rationale (user-led):** "One pass + one block
  scenario per hook (Recommended)." Per-hook expected exit code is
  asymmetric (secret-scan blocks with exit 2; no-emojis warns with exit
  0 + stderr); the runner encodes per-hook expectations.

- **D-17: Scope = the 4 named in CLDE-02.** secret-scan, no-emojis,
  no-ai-comments, agent-transparency. Out of scope: block-destructive,
  notify, post-compact (side-effecty or unnamed), and all gsd-*.js hooks
  (not repo-owned per D-02). **Rationale (user-led):** "The 4 named in
  CLDE-02 (Recommended)." Matches the requirement text literally.

- **D-18: Runner lives at install/test-hooks.zsh.** Sibling of
  `install/resolver.zsh`, `install/compose-brewfile.zsh`,
  `install/messages.zsh`, `install/cutover-gate.zsh`. Pattern: a .zsh
  script in `install/` that does one thing. `taskfiles/test.yml` (new)
  hosts the `test:hooks` task that invokes it + the `test` aggregator
  (TEST-02). **Rationale (user-led):** "install/test-hooks.zsh
  (Recommended)."

### Claude's Discretion (planner concerns)

- **TOOL-03 _:safe-link target-type guard.** Recommended approach:
  pre-check `[[ -e "{{.TARGET}}" && ! -L "{{.TARGET}}" ]]` -> fail with
  helpful error. Existing-symlink path: unchanged (`ln -sfn` re-points).
  Backward-compatible with P3/P4/P5/P6 existing callers in
  `taskfiles/links.yml` (none of those touch v2 paths where real files
  pre-exist). The guard catches the v1->v2 cutover case where a user
  has a real file at a v2 symlink destination -- desired safety behavior
  (force the user to remove the file rather than silently clobbering).

- **TOOL-04 _:check-link strict-mode mechanism.** Recommended:
  extend `_:check-link` with an optional `SOURCE` var. When present,
  third condition: `[[ "$(readlink -f "{{.TARGET}}")" == "{{.SOURCE}}" ]]`
  -- the symlink resolves to the manifest-expected source path. When
  absent, fall back to existing two-check behavior (exists + non-broken).
  Opt-in strict mode; existing P3+P4+P6 callers don't break. P7's new
  callers pass `SOURCE`. Retrofit decision (apply strict mode to
  existing P3/P4 callers?) -- planner's call; recommend yes (uniform
  safety win, cost is just adding the `SOURCE` arg to existing
  `_:check-link` invocations in `links.yml validate:`).

- **Whether to gate the `claude:gsd` task on a feature flag.** Not gated
  in the recommended design -- every machine runs GSD CLI (it's the
  workflow surface). But the planner may want a `gsd-cli` feature flag
  for symmetry with `claude-marketplace`. v1 didn't gate it; v2's
  servers (server-1, server-2) currently have `claude-marketplace = false`
  -- the `claude:marketplace` task skips on servers via that gate. Does
  GSD CLI also skip on servers? Recommend: also gate on
  `claude-marketplace` (servers without the marketplace feature also
  don't need GSD CLI). Or: introduce a new `claude-gsd` feature flag
  defaulting to true. Recommend reusing `claude-marketplace` (one fewer
  feature flag).

- **`agent-transparency.zsh` rewrite shape.** Two options:
  (a) wrap script body in `main()` function; call `main "$@"` at end.
  (b) Drop the `local` keyword and use plain variable declarations at
  script scope.
  Recommend (a) -- functions-with-locals is the pattern v2 conventions
  push for; matches the `os/defaults/<concern>.zsh` shape from P6.
  Smoke test (D-15) catches regressions in the rewrite.

- **`.gitignore` entries for GSD-managed paths.** Need to be
  precise to avoid hiding hand-authored files that happen to share the
  prefix:
  ```
  claude/agents/gsd-*.md
  claude/commands/gsd-*
  claude/skills/gsd-*/
  claude/hooks/gsd-*
  ```
  Hand-authored agents/commands/skills/hooks that DON'T have the `gsd-`
  prefix stay tracked. If GSD ever ships a non-`gsd-` prefixed asset,
  the .gitignore needs an update.

- **Backfill v1 cleanup deletes.** Pre-Phase-7 git commit:
  delete `claude/agents/gsd-*.md` (~33 files), `claude/skills/gsd-*/`
  (~64 dirs), `claude/hooks/gsd-*.{js,sh}` (~10 files), and the empty
  `claude/commands/`. Single commit: `chore(07): drop committed
  GSD-managed claude artifacts (now runtime-managed)`. Plan this as
  Plan 07-01 before any taskfile edits.

- **`claude/hooks/lib.zsh` symlink behavior.** lib.zsh is sourced by the
  other hooks via `source "${0:h}/lib.zsh"` or similar. Verify the
  sourcing pattern works through the symlink (the hooks resolve their
  own `${0:h}` to `~/.config/claude/hooks/`, which contains the
  lib.zsh symlink -- sourcing follows the symlink to the repo's
  lib.zsh). Likely already correct; the smoke test runner (D-15) hits
  every hook, which sources lib.zsh -- if the resolution is broken, the
  smoke test surfaces it.

- **Hook fixture exit codes.** Per Claude Code's hook contract (from
  the existing hooks.json + the hook bodies):
  - `secret-scan.zsh`: pass=exit 0; block=exit 2 (PreToolUse:Write|Edit)
  - `block-destructive.zsh` (out of scope but referenced): same shape
  - `no-emojis.zsh`: warn-only -- exit 0 either way; flagged input
    writes to stderr with "warn: emojis detected" pattern
  - `no-ai-comments.zsh`: warn-only -- exit 0 either way; flagged input
    writes to stderr with "warn: AI attribution detected" pattern
  - `agent-transparency.zsh`: log-only -- exit 0 either way; logs to
    stderr with "Agent delegated -> ..." pattern
  The runner must encode per-hook expected behavior (exit code +
  stderr regex). Inline in `install/test-hooks.zsh`'s functions.

### Carried Forward (not re-decided in this discussion)

- **CF-01:** Manifest is the source of truth -- `taskfiles/claude.yml` and
  `taskfiles/links.yml` read `resolved.json` via `ref: fromJson` (P1
  D-15, P2/P4/P5/P6 confirmed pattern). No hostname inference.
- **CF-02:** Kebab-case feature keys use `index` form in go-template
  (`{{if index .MANIFEST.features "claude-marketplace"}}`,
  `{{if index .MANIFEST.features "ghostty"}}`). Snake_case keys use dot
  access (CLAUDE.md, every prior CONTEXT).
- **CF-03:** `status:` blocks use `{{.X}}` template vars ONLY -- never
  `$X` shell vars (LINT-02; the v1 `macos:shell:145` bug class). Every
  P7 task `status:` conforms.
- **CF-04:** Every install task has a `status:` block; aggregator tasks
  omit `status:` with `# lint-allow: cmds-without-status` marker
  (LINT-01/03a). `claude:install` is an aggregator (D-09 sub-tasks
  carry their own status); `test` is an aggregator; `links.yml`'s `all`
  aggregator gains the `claude:` and `configs:` sub-task references but
  stays aggregator-shaped.
- **CF-05:** No bare `ln -s` outside `taskfiles/helpers.yml` (LINT-03b).
  P7's new symlinks all go through `_:safe-link`. helpers.yml is the
  one file that's allowed to call `ln` -- the TOOL-03 hardening lives
  there.
- **CF-06:** `set -euo pipefail` on every executable `.zsh` (LINT-04).
  `install/test-hooks.zsh` and the rewritten `claude/hooks/*.zsh` files
  conform.
- **CF-07:** XDG everywhere -- `GSD_SENTINEL` at `$XDG_STATE_HOME/dotfiles/`;
  symlink destinations resolve `$XDG_CONFIG_HOME` (matches existing
  P3+P4+P5+P6 patterns).
- **CF-08:** `deps: [manifest:resolve]` on every `claude:*` and
  `configs:*` task that reads `resolved.json` -- P1 D-14 pattern reused
  by P4 `identity.yml`, P5 `packages.yml`, P6 `macos.yml`.
- **CF-09:** `install/messages.zsh` sourced via `{{.DOTFILES_MESSAGES}}`
  for check/cross output (P1 deliverable, used by P2/P3/P4/P5/P6).
  `install/test-hooks.zsh` uses it for per-hook check/cross output.
- **CF-10:** Detect Homebrew prefix via `uname -m`; use `$HOMEBREW_PREFIX`
  (shell) / `{{.HOMEBREW_PREFIX}}` (task) -- never hardcode
  `/opt/homebrew` (CLAUDE.md). claude CLI install path is `brew install
  claude` (in core.rb -- planner verifies); no `/opt/homebrew` references
  in claude.yml.
- **CF-11:** Parallel rewrite -- v1 `zsh/configs/*` and `zsh/styles/*`
  files stay byte-stable on disk; P8 owns their deletion. v1
  `taskfiles/claude.yml` was already overhauled by P2 -- P7 builds on
  the existing shape, not on the pre-v2 monolith.
- **CF-12:** No AI attribution in commits or source; no emojis (project
  convention, hook-enforced via the very `no-ai-comments.zsh` and
  `no-emojis.zsh` hooks that P7 smoke-tests).
- **CF-13:** Sibling-README pattern (P3 SC#6 origin) -- `configs/README.md`
  (currently P3 stub) gets a real body in P7; each `configs/<tool>/`
  subdir gets its own README. `claude/README.md` (already exists) is
  updated if needed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` -- Core value, constraints, Out of Scope. Active
  section: "Claude Code integration -- Global CLAUDE.md, settings.json,
  hooks, agents, commands, and skills installed via go-task" + "Hooks
  ported: secret-scan, no-emojis, no-ai-comments, agent-transparency
  (with shellcheck-clean rewrite)" + "Claude marketplace and plugin
  install with a working status: guard (current gsd-install re-runs
  every time)". All three lines drive P7. No edit needed; the
  "version-pinned" framing is in REQUIREMENTS/ROADMAP, not PROJECT.
- `.planning/REQUIREMENTS.md` CLDE-01..04, TOOL-01..04, TEST-01..02 --
  Full requirements. CLDE-03 wording needs an amend per D-09 ("version-
  pinned" -> "presence") -- planner action item.
- `.planning/ROADMAP.md` Phase 7 section -- Goal, seven success criteria,
  requirement mapping; success criterion #2 needs the same "version-
  pinned" -> "presence" amend per D-09.
- `.planning/STATE.md` -- Pre-Phase-7 state (Phases 1-6 complete;
  manifest + install + shell + identity + packages + os-defaults layers
  shipped).

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md`
  -- Phase 1 decisions binding on P7:
  - **D-14:** Auto-rebuild via task precondition -- `claude.yml` and
    `links.yml`'s claude sub-task declare `deps: [manifest:resolve]`.
  - **D-15:** `resolved.json` at `$XDG_STATE_HOME/dotfiles/resolved.json`
    -- machine-local; one-active-machine-at-a-time invariant. P7's
    `GSD_SENTINEL` lives in the same directory.
- `.planning/phases/02-install-engine-bootstrap-idempotency-lint/02-CONTEXT.md`
  -- Phase 2 decisions binding on P7:
  - **D-12:** All lint logic inlined in `taskfiles/lint.yml`;
    `taskfiles/claude.yml` and `taskfiles/test.yml` must pass LINT-01..04
    + LINT-07. No new lint rules proposed in P7 (the LINT-10 candidate
    from P6 is the only outstanding lint-suite proposal).
  - **D-13:** Lint severity model -- LINT-02 (`$VAR` in `status:`) and
    LINT-03a (`cmds:` without `status:`) are blocking; every P7 task
    `status:` conforms.
- `.planning/phases/03-shell-layer-flat-content-port/03-CONTEXT.md`
  -- Phase 3 decisions binding on P7:
  - **D-10 / `motd` feature flag:** the `motd` feature flag in
    `defaults.toml` gates `shell/functions/motd.zsh`'s body. P7's
    `configs/motd/{motd_tron.txt,motd_sysinfo.jsonc}` source files are
    read by motd.zsh; no separate symlink-side gating needed.
  - **D-07 / `ghostty` feature flag:** the `ghostty` feature flag gates
    `shell/aliases/ghostty.zsh`. P7 reuses the same flag for
    `configs/ghostty/config` symlink (same-flag-multiple-consumers
    pattern, mirroring P6 D-01 for `macos-finder`).
- `.planning/phases/04-identity-layer-git-ssh-per-machine/04-CONTEXT.md`
  -- Phase 4 decisions binding on P7:
  - **CF-06:** `set -euo pipefail` on every executable `.zsh`; sourced-
    only files exempt -- `install/test-hooks.zsh` is executable
    (invoked via the test task); claude hooks are executable too.
- `.planning/phases/05-packages-layer-brewfile-composition-verification/05-CONTEXT.md`
  -- Phase 5 decisions binding on P7:
  - **D-07:** Verify enumerates every item, no fast-fail. P7's
    `claude:validate` mirrors: enumerate every marketplace + plugin +
    GSD-sentinel check, full check/cross table, exit non-zero if any
    failed.
  - **D-10:** Hard-fail at the install gate. P7's `claude:install`
    contributes to the install pipeline; if `claude:install` fails
    (e.g., marketplace registration fails), `task install` aborts
    before `macos:defaults` runs -- same hard-fail discipline.
- `.planning/phases/06-os-defaults-macos-configuration/06-CONTEXT.md`
  -- Phase 6 decisions binding on P7:
  - **D-01 / same-flag-multiple-consumers:** P6 reused `macos-finder`
    for both alias-gate and defaults-gate. P7 reuses `ghostty` for both
    alias-gate (existing P3) and config-symlink-gate (new P7). Same
    pattern.
  - **Aggregator pattern:** P6 `macos:defaults` is an aggregator with
    `# lint-allow: cmds-without-status`. P7 `claude:install` and
    `test` follow the same pattern.

### Existing v1 Codebase (sources for the port)
- `taskfiles/claude.yml` -- already v2-shaped from a P2 overhaul (not v1
  monolith). P7 builds on this: same install/update/validate/status tasks
  but adds `status:` blocks (CLDE-04), the GSD sentinel logic (CLDE-03),
  the new `claude:update` shape (D-10), and the `claude:ensure-cli`
  hard-fail message (D-13). The `marketplaces-add`, `marketplaces-update`,
  `plugins-install`, `plugins-update`, `gsd-install` internal tasks port
  forward with minor edits.
- `taskfiles/claude-stub.yml` -- Phase 2 stub for the `claude:` include
  slot in root `Taskfile.yml`. P7 replaces it (root `Taskfile.yml`
  `includes.claude:` flips from `claude-stub.yml` to `claude.yml`).
- `taskfiles/links.yml` -- Phase 3 real implementation. P7 extends with
  a `claude:` sub-task (13 entries per D-01) and a `configs:` sub-task
  (~7 entries per D-05). The `all:` aggregator gains
  `task: claude` and `task: configs` `cmds:` entries.
- `taskfiles/helpers.yml` -- P7 hardens `_:safe-link` (TOOL-03) and
  `_:check-link` (TOOL-04). Backward-compatible extensions per Claude's
  Discretion above.
- `claude/CLAUDE.md` -- existing global instructions; symlinked as-is.
- `claude/settings.json` -- existing hooks wiring; symlinked as-is.
- `claude/hooks/*.zsh` -- 7 zsh hooks (post-compact, agent-transparency,
  secret-scan, block-destructive, no-ai-comments, no-emojis, notify) +
  lib.zsh. `agent-transparency.zsh` has the v1 `local`-at-script-scope
  bug (lines 11, 39) -- P7 rewrites per CLDE-02.
- `claude/agents/` -- currently ~33 committed `gsd-*` agents. P7 deletes
  these per D-02; remaining content is README.md + any future hand-authored
  agents.
- `claude/commands/` -- empty except README.md.
- `claude/skills/` -- currently ~64 committed `gsd-*` skill dirs. P7
  deletes these per D-02; remaining content is README.md.
- `zsh/configs/{ghostty,glow.yml,trippy.toml,tlrc.toml,condarc,
  motd_tron.txt,motd_sysinfo.jsonc}` -- v1 tool config sources. P7
  copies content (with rename per D-06) into `configs/<tool>/` and leaves
  v1 files byte-stable until P8 cutover (CF-11).
- `zsh/styles/{eza_style.yaml,glow_style.json}` -- v1 style sources.
  Same parallel-rewrite invariant: copy into `configs/eza/theme.yaml`
  and `configs/glow/glow_style.json`; v1 files stay until P8.
- `install/messages.zsh` -- reused by `taskfiles/claude.yml`,
  `taskfiles/test.yml`, and `install/test-hooks.zsh` for check/cross
  output.
- `install/resolver.zsh`, `install/compose-brewfile.zsh`,
  `install/cutover-gate.zsh` -- pattern templates for
  `install/test-hooks.zsh` (set -euo pipefail header, messages.zsh
  source, single-purpose script).
- `.planning/codebase/CONCERNS.md` -- Tech debt P7 fixes:
  - `gsd-install` task runs `npx` on every `task install` with no
    `status:` guard. D-09 + D-11 fix this structurally.
  - `agent-transparency.zsh` uses `local` at script scope (shellcheck
    error). D-15 + CLDE-02 rewrite fixes this; smoke test catches
    regressions.

### Manifest Layer (P7 reads + writes)
- `manifests/defaults.toml` -- P7 reads `features.claude-marketplace`,
  `features.ghostty`, `features.motd`. No new feature flags added in
  P7 (per D-07 + Claude's Discretion `claude-gsd` recommendation:
  reuse `claude-marketplace`).
- `manifests/machines/personal-laptop.toml` -- already has
  `claude-marketplace = true`, `ghostty = true`, `motd = true`. No edit
  needed.
- `manifests/machines/work-laptop.toml` -- same as personal. No edit.
- `manifests/machines/server-1.toml`, `server-2.toml` -- already have
  `claude-marketplace = false`, `motd = true` (and `ghostty` absent ->
  inherited false). No edit needed. Servers skip the marketplace task at
  the feature-gate level; per Claude's Discretion, they also skip the
  GSD CLI install (same gate).
- `docs/MANIFEST.md` -- no schema changes in P7 (no new feature flags).
  References to `features.ghostty` and `features.claude-marketplace`
  unchanged.

### Hook Schema (External Reference)
- Claude Code hook stdin schema -- Anthropic docs / Claude Code CLI
  reference. Each hook receives a JSON payload with `tool_name`,
  `tool_input`, `cwd`, etc. The smoke-test fixtures (D-15) construct
  synthetic JSON matching this shape. The runner pipes via stdin
  (matching the real-runtime invocation).
- Claude Code hook exit-code semantics -- exit 0 = pass/warn, exit 2 =
  block (the hook's stderr message surfaces to the user). D-16 fixtures
  encode the per-hook expected exit code.

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) -- v2 conventions: flat directories in v1, one
  concept per file (one tool per `configs/<tool>/`, one hook per file in
  `claude/hooks/`), `status:` blocks use template vars only, no
  hardcoded `/opt/homebrew`, kebab-case feature keys need `index`
  access. P7 conforms.
- `.claude/CLAUDE.md` -- Project-level Claude instructions; reaffirms
  flat layout + manifest-as-truth + LINT contract. Stays in-place per
  D-03.
- `~/.config/claude/CLAUDE.md` -- the symlink P7 creates. Source is
  `${DOTFILEDIR}/claude/CLAUDE.md`. Global conventions; loaded for
  every Claude Code session.

### Claude Code Tooling Documentation
- Claude Code plugin marketplace docs -- `claude plugin marketplace add`,
  `list --json`, `update`; `claude plugin install`, `list --json`,
  `update --all` (and per-plugin update). v1 `taskfiles/claude.yml`
  already uses the `--json` flag; P7 preserves the parsing pattern.
- `npx -y get-shit-done-cc@latest --claude --global` -- the installer
  command. `--global` lays artifacts down into `~/.config/claude/`;
  `--claude` is the variant flag. P7 keeps the command verbatim,
  changes only the surrounding idempotency contract (D-09 + D-10).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (port from v1 or v2-already-shaped)
- **`taskfiles/claude.yml`** -- v2-shaped from P2; tasks port forward
  with status: blocks added (CLDE-03 + CLDE-04 enforcement) and the
  `claude:update` shape change (D-10). The `marketplaces-add`,
  `marketplaces-update`, `plugins-install`, `plugins-update`,
  `gsd-install` internal task bodies migrate with minor edits.
- **`taskfiles/claude-stub.yml`** -- Phase 2 stub; replaced when
  `Taskfile.yml`'s `includes.claude:` flips from `claude-stub.yml` to
  `claude.yml`.
- **`claude/CLAUDE.md`** and **`claude/settings.json`** -- ship verbatim
  via file symlink. No content edits needed; deployment is the
  P7 work.
- **`claude/hooks/lib.zsh`** -- shared helpers sourced by the seven
  hooks. Ships verbatim (per-file symlink) per D-01.
- **`claude/hooks/agent-transparency.zsh`** -- rewrite needed (CLDE-02 +
  Claude's Discretion). Wrap body in `main()` function. Shellcheck-clean
  after rewrite.
- **`claude/hooks/{secret-scan,no-emojis,no-ai-comments,
  block-destructive,notify,post-compact}.zsh`** -- ship verbatim
  (shellcheck-clean already per existing convention; planner verifies).
- **`taskfiles/helpers.yml`** -- `_:safe-link` and `_:check-link`
  patterns are the pre-existing helpers; P7 extends them (TOOL-03 +
  TOOL-04) without breaking existing callers.
- **`install/messages.zsh`** -- reused by `taskfiles/claude.yml`,
  `taskfiles/test.yml`, and `install/test-hooks.zsh` for check/cross
  output.
- **`install/resolver.zsh`, `install/compose-brewfile.zsh`,
  `install/cutover-gate.zsh`** -- shape templates for
  `install/test-hooks.zsh`.
- **`zsh/configs/*.{toml,yml,jsonc,txt}` + `zsh/styles/*.{yaml,json}`** --
  v1 tool config sources; content copies into `configs/<tool>/` with
  destination-name renames per D-06.

### Established Patterns (binding on P7)
- **`status:` blocks use `{{.X}}` template vars only** -- LINT-02. Every
  P7 task `status:` conforms. The GSD sentinel and marketplace status
  use `{{.GSD_SENTINEL}}` and `{{.CLAUDE_MARKETPLACES}}` /
  `{{.CLAUDE_PLUGINS}}` (vars block) -- no `$VAR` shell-var usage.
- **Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status`
  marker** -- `claude:install` aggregator, `links.yml all:` aggregator
  (already has the marker; P7 extends `cmds:`), `taskfiles/test.yml`
  `test:` aggregator.
- **`set -euo pipefail` on every executable `.zsh`** -- applies to
  `install/test-hooks.zsh` and the rewritten `claude/hooks/*.zsh`
  files (sourced-only `lib.zsh` is exempt per convention but carries
  the flag anyway -- P4 CF-06 v2 convention).
- **Manifest as runtime source of truth** -- `claude.yml` reads
  `resolved.json` via `ref: fromJson`. `features.claude-marketplace`
  uses `index` form (kebab-case). `features.ghostty` uses `index` form.
  `features.motd` uses `index` form.
- **`deps: [manifest:resolve]`** -- every `claude:*` task that reads
  `resolved.json` declares this.
- **Per-hook check/cross output via `messages.zsh`** -- mirror P5
  `packages:verify` and P6 `macos:validate` patterns. `task test:hooks`
  prints `check "secret-scan.pass"` / `cross "no-emojis.block (expected
  exit 0 + stderr warn, got exit X)"` etc.
- **Sibling-README pattern (P3 SC#6 origin)** -- `configs/README.md`
  (already P3 stub) gets a real body in P7; each `configs/<tool>/` subdir
  ships its own README.md.

### Integration Points
- **`claude/` -> `manifests/`** -- `claude:install` reads
  `features.claude-marketplace` (gates the entire `claude:install`
  aggregator -- servers with the flag false skip). `claude:gsd`
  reuses the same gate (per Claude's Discretion).
- **`claude/` -> root `Taskfile.yml`** -- `includes.claude:` flips from
  `./taskfiles/claude-stub.yml` to `./taskfiles/claude.yml`. Root
  `install` task's `cmds:` already invokes `task: claude:install`
  (Taskfile.yml line 142) -- no edit needed there. The `claude:install`
  position in the pipeline is between `packages:install` (P5) and
  `macos:defaults` (P6); no re-ordering.
- **`configs/` -> `manifests/`** -- only ghostty consults a feature
  flag (`features.ghostty`). The other six tool configs are
  unconditional.
- **`configs/` -> P3 shell layer** -- `configs/motd/*` files are read by
  `shell/functions/motd.zsh` at runtime via
  `${DOTFILEDIR}/configs/motd/<file>`. The motd function already gates
  on `features.motd`; no symlink involved.
- **`configs/ghostty/config`** -- consumed by the Ghostty terminal app
  via its config-file convention (`~/.config/ghostty/config`).
- **`taskfiles/test.yml` -> `taskfiles/manifest.yml`** -- the `test`
  aggregator calls `task: manifest:test` (P1 deliverable) and
  `task: test:hooks`. P1's manifest:test task already exists.
- **`taskfiles/test.yml` -> root `Taskfile.yml`** -- root `includes:`
  gets a new `test: ./taskfiles/test.yml` entry. No root `cmds:`
  change required (the test task is called explicitly, like
  `task lint`, not part of `task install`).
- **`taskfiles/helpers.yml` -> every taskfile** -- the TOOL-03 + TOOL-04
  hardenings affect every existing `_:safe-link` and `_:check-link`
  caller in `links.yml`, `identity.yml`, and the new `claude` /
  `configs` sub-tasks. Backward-compatible by design (per Claude's
  Discretion).

</code_context>

<specifics>
## Specific Ideas

- **`taskfiles/claude.yml` skeleton (the key task shapes):**
  ```yaml
  version: '3'

  includes:
    _: ./helpers.yml

  vars:
    CLAUDE_MARKETPLACES: |
      ecc https://github.com/affaan-m/everything-claude-code.git
    CLAUDE_PLUGINS: |
      ecc@ecc
    GSD_SENTINEL: '{{.XDG_STATE_HOME}}/dotfiles/gsd-installed'
    MARKETPLACES_JSON:
      sh: claude plugin marketplace list --json 2>/dev/null || echo '[]'
    PLUGINS_JSON:
      sh: claude plugin list --json 2>/dev/null || echo '[]'

  tasks:
    # lint-allow: cmds-without-status
    install:
      desc: "Install Claude Code marketplaces, plugins, and get-shit-done-cc"
      deps: [manifest:resolve]
      cmds:
        - '{{if index .MANIFEST.features "claude-marketplace"}}'  # feature gate (servers skip)
        - task: ensure-cli
        - task: marketplace
        - task: gsd
        - |
          {{.DOTFILES_MESSAGES}}
          success "Claude plugins installed"
        - '{{end}}'

    marketplace:
      desc: "Register marketplaces + install plugins"
      internal: true
      deps: [ensure-cli, manifest:resolve]
      cmds:
        # marketplaces-add loop (port from v1)
        # plugins-install loop (port from v1)
      status:
        # Two-condition (D-12): every marketplace registered AND every plugin installed
        - |
          for entry in {{range (splitList "\n" .CLAUDE_MARKETPLACES)}} ... ; do
            echo '{{.MARKETPLACES_JSON}}' | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null || exit 1
          done
        - |
          for id in {{range (splitList "\n" .CLAUDE_PLUGINS)}} ... ; do
            echo '{{.PLUGINS_JSON}}' | jq -e --arg i "$id" '.[] | select(.id == $i)' >/dev/null || exit 1
          done

    gsd:
      desc: "Install get-shit-done-cc (presence-sentinel idempotent)"
      internal: true
      deps: [ensure-cli]
      cmds:
        - |
          {{.DOTFILES_MESSAGES}}
          info "installing get-shit-done-cc (global)"
          npx -y get-shit-done-cc@latest --claude --global
          mkdir -p "$(dirname {{.GSD_SENTINEL}})"
          touch {{.GSD_SENTINEL}}
          success "GSD installed; sentinel touched at {{.GSD_SENTINEL}}"
      status:
        - test -f {{.GSD_SENTINEL}}

    # lint-allow: cmds-without-status
    update:
      desc: "Refresh marketplaces + plugins + GSD (explicit; not in task install)"
      deps: [ensure-cli, manifest:resolve]
      cmds:
        - claude plugin marketplace update
        - for: { var: CLAUDE_PLUGINS, split: "\n", as: ID }
          cmd: |
            [[ -z "{{.ID}}" ]] && exit 0
            claude plugin update "{{.ID}}"
        - rm -f {{.GSD_SENTINEL}}
        - task: gsd

    ensure-cli:
      desc: "Hard-fail if claude or jq missing"
      internal: true
      cmds:
        - |
          {{.DOTFILES_MESSAGES}}
          missing=0
          if ! command -v claude >/dev/null 2>&1; then
            cross "claude CLI not found -- run 'task packages:install' first"
            missing=1
          fi
          if ! command -v jq >/dev/null 2>&1; then
            cross "jq not found -- run 'task packages:install' first"
            missing=1
          fi
          [[ $missing -eq 0 ]]

    # lint-allow: cmds-without-status
    validate:
      desc: "Validate Claude install state (composed into root task validate in P8)"
      deps: [manifest:resolve]
      cmds:
        # claude-CLI-present, jq-present, per-marketplace check/cross,
        # per-plugin check/cross, GSD sentinel check (ported from v1
        # validate task with the sentinel addition).

    # lint-allow: cmds-without-status
    status:
      desc: "Show installed marketplaces + plugins (diagnostic)"
      cmds:
        - claude plugin marketplace list
        - echo
        - claude plugin list
  ```

- **`taskfiles/links.yml` claude sub-task skeleton:**
  ```yaml
  tasks:
    # The `all:` aggregator (existing) gains:
    #   - task: claude
    #   - task: configs

    claude:
      desc: "Link Claude Code config tree"
      cmds:
        # 2 file symlinks (CLAUDE.md, settings.json)
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/CLAUDE.md", TARGET: "{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/settings.json", TARGET: "{{.XDG_CONFIG_HOME}}/claude/settings.json" }
        # 3 dir symlinks (agents, commands, skills)
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/agents", TARGET: "{{.XDG_CONFIG_HOME}}/claude/agents" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/commands", TARGET: "{{.XDG_CONFIG_HOME}}/claude/commands" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/skills", TARGET: "{{.XDG_CONFIG_HOME}}/claude/skills" }
        # 8 file symlinks inside hooks/ (7 zsh hooks + lib.zsh)
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/post-compact.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/post-compact.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/agent-transparency.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/agent-transparency.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/secret-scan.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/secret-scan.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/block-destructive.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/block-destructive.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/no-ai-comments.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/no-ai-comments.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/no-emojis.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/no-emojis.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/notify.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/notify.zsh" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/claude/hooks/lib.zsh", TARGET: "{{.XDG_CONFIG_HOME}}/claude/hooks/lib.zsh" }
      status:
        - test -L "{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md"
        - test -L "{{.XDG_CONFIG_HOME}}/claude/settings.json"
        - test -L "{{.XDG_CONFIG_HOME}}/claude/agents"
        - test -L "{{.XDG_CONFIG_HOME}}/claude/commands"
        - test -L "{{.XDG_CONFIG_HOME}}/claude/skills"
        - test -L "{{.XDG_CONFIG_HOME}}/claude/hooks/post-compact.zsh"
        # ... (one per hook)
  ```

- **`taskfiles/links.yml` configs sub-task skeleton:**
  ```yaml
  tasks:
    configs:
      desc: "Link tool configs (ghostty/glow/trippy/tlrc/conda/eza)"
      cmds:
        # ghostty (gated)
        - '{{if index .MANIFEST.features "ghostty"}}'
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/ghostty/config", TARGET: "{{.XDG_CONFIG_HOME}}/ghostty/config" }
        - '{{end}}'
        # glow (2 files)
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/glow/glow.yml", TARGET: "{{.XDG_CONFIG_HOME}}/glow/glow.yml" }
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/glow/glow_style.json", TARGET: "{{.XDG_CONFIG_HOME}}/glow/glow_style.json" }
        # trippy
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/trippy/trippy.toml", TARGET: "{{.XDG_CONFIG_HOME}}/trippy/trippy.toml" }
        # tlrc
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/tlrc/config.toml", TARGET: "{{.XDG_CONFIG_HOME}}/tlrc/config.toml" }
        # conda
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/conda/condarc", TARGET: "{{.XDG_CONFIG_HOME}}/conda/condarc" }
        # eza
        - task: _:safe-link
          vars: { SOURCE: "{{.DOTFILEDIR}}/configs/eza/theme.yaml", TARGET: "{{.XDG_CONFIG_HOME}}/eza/theme.yaml" }
      status:
        # Conditional status entries for ghostty (only if flag on)
        - '{{if not (index .MANIFEST.features "ghostty")}}true{{else}}test -L "{{.XDG_CONFIG_HOME}}/ghostty/config"{{end}}'
        - test -L "{{.XDG_CONFIG_HOME}}/glow/glow.yml"
        - test -L "{{.XDG_CONFIG_HOME}}/glow/glow_style.json"
        - test -L "{{.XDG_CONFIG_HOME}}/trippy/trippy.toml"
        - test -L "{{.XDG_CONFIG_HOME}}/tlrc/config.toml"
        - test -L "{{.XDG_CONFIG_HOME}}/conda/condarc"
        - test -L "{{.XDG_CONFIG_HOME}}/eza/theme.yaml"
  ```

- **`install/test-hooks.zsh` skeleton:**
  ```zsh
  #!/usr/bin/env zsh
  # install/test-hooks.zsh -- Tier-3 smoke tests for the four named Claude hooks.
  # Invoked by `task test:hooks`. Pipes synthetic JSON payloads to each hook and
  # asserts exit code + stderr regex.

  set -euo pipefail
  source "${DOTFILEDIR}/install/messages.zsh"

  HOOK_DIR="${DOTFILEDIR}/claude/hooks"
  failed=0

  test_secret_scan() {
    # Pass scenario: write of a non-secret file
    local pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"hello world"}}'
    if echo "$pass_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1; then
      check "secret-scan.pass"
    else
      cross "secret-scan.pass: expected exit 0, got $?"
      failed=1
    fi
    # Block scenario: write containing an API key pattern
    local block_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"export API_KEY=sk-abc123def456ghi789jkl012mno345"}}'
    local exit_code
    echo "$block_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1 || exit_code=$?
    if [[ ${exit_code:-0} -eq 2 ]]; then
      check "secret-scan.block"
    else
      cross "secret-scan.block: expected exit 2, got ${exit_code:-0}"
      failed=1
    fi
  }

  test_no_emojis() { ... }       # warn-only -- exit 0 either way, check stderr for warn pattern
  test_no_ai_comments() { ... }  # warn-only -- exit 0, check stderr for AI-attribution pattern
  test_agent_transparency() { ... }  # log-only -- exit 0, check stderr for "Agent delegated"

  test_secret_scan
  test_no_emojis
  test_no_ai_comments
  test_agent_transparency

  exit $failed
  ```

- **`taskfiles/test.yml` skeleton:**
  ```yaml
  version: '3'

  vars:
    DOTFILEDIR:
      sh: dirname "{{.TASKFILE_DIR}}"
    DOTFILES_MESSAGES: |
      source '{{.DOTFILEDIR}}/install/messages.zsh'

  tasks:
    # lint-allow: cmds-without-status
    default:
      desc: "Run all smoke tests"
      cmds:
        - task: hooks
        # Note: manifest:test is invoked from root `task test` via the aggregator
        # below; not duplicated here.

    hooks:
      desc: "Run Claude hook smoke tests"
      cmds:
        - |
          {{.DOTFILES_MESSAGES}}
          export DOTFILEDIR="{{.DOTFILEDIR}}"
          zsh "${DOTFILEDIR}/install/test-hooks.zsh"
      status:
        - false   # tests are diagnostic; always run
  ```

  And in root `Taskfile.yml`:
  ```yaml
  includes:
    test: ./taskfiles/test.yml
    # ... existing includes ...

  tasks:
    # lint-allow: cmds-without-status
    test:
      desc: "Run all smoke tests (manifest fixtures + hook fixtures)"
      cmds:
        - task: manifest:test    # P1 deep-merge fixtures
        - task: test:hooks       # P7 hook smoke tests
  ```

- **`agent-transparency.zsh` rewrite (function-wrapped):**
  ```zsh
  #!/usr/bin/env zsh
  # claude/hooks/agent-transparency.zsh -- Log subagent delegations.
  # Listens on PreToolUse:Agent. Reads JSON from stdin; writes one log line per
  # invocation to stderr.

  set -euo pipefail

  main() {
    local agent_type description cwd agent_md
    local input
    input=$(cat)
    agent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty')
    description=$(echo "$input" | jq -r '.tool_input.description // empty')
    # ... rest of the body ...
    local output="Agent delegated -> type: ${agent_type}, task: ${description}"
    echo "$output" >&2
  }

  main "$@"
  ```

- **Pre-Phase-7 cleanup commit (Plan 07-01 first deliverable):**
  ```
  chore(07): drop committed GSD-managed claude artifacts (now runtime-managed)

  - Delete claude/agents/gsd-*.md (~33 files)
  - Delete claude/skills/gsd-*/ (~64 dirs)
  - Delete claude/hooks/gsd-*.{js,sh} (~10 files)
  - Add .gitignore patterns for claude/{agents,commands,skills,hooks}/gsd-*

  Per Phase 7 D-02: GSD installer owns these directories at runtime.
  Freezing them in the dotfiles repo couples our release cadence to GSD's
  unnecessarily and produces phantom diffs every time GSD updates.
  ```

</specifics>

<deferred>
## Deferred Ideas

### Owned by later phases (do not pull into P7 scope)
- **Root `task validate` composition** -- Phase 8 (CUTV-01). P7 ships
  `task claude:validate`, `task links:validate` (extended with claude +
  configs entries), and `task test:hooks` ready to compose.
- **`task links:reconcile` two-mode + orphan-vs-GSD-runtime distinction**
  -- Phase 8 (CUTV-02, CUTV-07, CUTV-08). The "repo-owned vs
  GSD-runtime-managed" split in P7 D-02 affects what counts as an
  orphan: files in `~/.config/claude/agents/gsd-*.md` are GSD-managed,
  not orphans. Phase 8 must understand the prefix-based exemption.
- **`docs/MIGRATION.md` v1->v2 mapping** -- Phase 8 (DOCS-05). The
  v1-`zsh/configs/*` -> v2-`configs/<tool>/` mapping table lives there.
- **`docs/MACHINES.md`, `docs/CUTOVER.md`** -- Phase 8 (DOCS-06,
  DOCS-08).
- **v1 file deletion (`zsh/configs/*`, `zsh/styles/*`)** -- Phase 8.
  v1 files stay byte-stable until cutover completes (parallel-rewrite
  invariant per every prior phase's CF-11).
- **Proposed LINT-10 (defaults-write-without-status-read)** -- Carried
  forward from Phase 6 deferred. Not P7's concern; would land in
  `taskfiles/lint.yml` (per P2 D-12 "all lint logic inlined") as a
  follow-up against P2's lint suite.
- **Additional hook smoke tests for `block-destructive`, `notify`,
  `post-compact`** -- out of CLDE-02 / TEST-01 named scope. If
  block-destructive starts misfiring, it lands as a P7+1 follow-up plan
  to extend `install/test-hooks.zsh`.
- **JS hook smoke tests (`gsd-*.js`)** -- not repo-owned per D-02;
  GSD's repo owns that test surface.

### Future hardening (out of v1 scope)
- **`claude/CLAUDE.md` per-platform overlay** -- only one CLAUDE.md
  today; v2 might want a Linux-specific overlay when LINUX-V2 work
  starts. Out of v1.
- **Settings.json schema validation** -- `claude/settings.json` carries
  a `$schema` field; a future lint rule could validate against the
  schema at `task lint` time. Not P7.
- **`task claude:bump-gsd` with explicit version pin** -- user
  rejected version pinning in P7 D-09. If a security pin or
  breaking-change avoidance ever requires it, the manifest grows a
  `claude.gsd_version` field at that point.
- **Hook coverage matrix beyond pass+block per hook** -- P7 D-16 ships
  the minimum. If smoke tests start missing real regressions (e.g.,
  false-positives in the warn-only hooks aren't caught), expand to a
  warn-tier scenario per hook.
- **Per-tool feature flag explosion** (`tool-glow`, `tool-trippy`, etc.)
  -- P7 D-07 rejects this. Servers don't need fine-grained config
  gating; the CLIs aren't running on servers anyway (core.rb ships them
  but no one invokes them).
- **`_:safe-link` directory-merge mode** -- P7 TOOL-03 only adds
  refuse-clobber. A merge mode ("if target is a directory, symlink each
  child individually") would be needed if a tool's config path becomes
  a directory with mixed repo-owned + runtime-managed files. Out of v1.
- **Pre-commit hook for repo-side artifacts** -- a hook that fails if
  someone tries to `git add claude/agents/gsd-*.md` (in case the
  `.gitignore` is bypassed via `git add -f`). Defensive; out of v1.
- **Claude Code session-trace export to dotfiles repo** -- future
  feature, not relevant to P7.

### Open questions for later (not blocking P7)
- **Does GSD's installer leave hand-authored skills alone if you
  re-run it?** P7 assumes yes (you can hand-author a skill at
  `~/.config/claude/skills/my-skill/` and GSD's update doesn't clobber
  it). Verify during execution; if GSD clobbers, the answer is to
  symlink hand-authored skills individually from the repo
  (similar to the hooks per-file shape).
- **Does `claude plugin update --all` work, or do we need a per-plugin
  loop?** P7 D-10 calls `claude plugin update --all` in `claude:update`'s
  second cmd. v1 used a per-plugin loop. Use whichever the CLI
  supports; per-plugin loop is the safe fallback.
- **What's the right `npx` invocation flag set?** v1 uses
  `-y get-shit-done-cc@latest --claude --global`. The `-y` flag
  auto-accepts npx prompts; `--claude --global` are GSD's variant
  flags. Verify during execution that the flags haven't shifted in
  GSD between repo-commit time and P7 execution time.
- **Does `lib.zsh` need to be in `settings.json`'s hooks section?**
  No -- it's sourced internally by the other hooks via `source ...`.
  Settings.json names the entry-point hooks (the ones Claude Code
  invokes); `lib.zsh` is library code, not an entry point.
- **Hook smoke test runner on a server (server-1, server-2)?**
  Servers have `claude-marketplace = false` -- they skip
  `claude:install`. But `task test` is callable independently; the
  smoke test runner should work on any machine that has the hook
  files symlinked (which servers don't, since the symlinks are
  feature-gated). The `claude:` symlink batch in `links.yml` could
  also be gated on `claude-marketplace` (matching `claude:install`).
  Recommend yes; servers don't need the claude hook tree at all.

</deferred>

---

*Phase: 07-claude-tool-configs-smoke-tests*
*Context gathered: 2026-05-16*
