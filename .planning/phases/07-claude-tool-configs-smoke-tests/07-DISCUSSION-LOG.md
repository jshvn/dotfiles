# Phase 7: Claude + Tool Configs + Smoke Tests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 07-claude-tool-configs-smoke-tests
**Areas discussed:** Claude config deployment shape, Tool config layout under configs/, GSD + marketplace status design, Hook smoke-test shape + scope

---

## Claude config deployment shape

### How should the repo's claude/ tree be symlinked into ~/.config/claude/?

| Option | Description | Selected |
|--------|-------------|----------|
| Mixed top-level (6 links) | Two file symlinks (CLAUDE.md, settings.json) + four directory symlinks (hooks/, agents/, commands/, skills/). Runtime ~/.config/claude/.claude.json and any future Claude-managed state live as siblings. | check |
| Per-file all the way down | Every individual file (each hook, each agent .md, each skill's SKILL.md + sub-files) gets its own symlink. ~50-100+ symlinks. | |
| Hybrid: per-file for top, dir for trees | Functionally identical to Option 1. | |

**User's choice:** Mixed top-level (6 links) (Recommended)

### How should claude/hooks/ handle the GSD-installer-managed JS/sh hooks?

| Option | Description | Selected |
|--------|-------------|----------|
| Repo owns only the 7 zsh hooks | Repo's claude/hooks/ contains only hooks wired by hooks.json. GSD files live as runtime artifacts. | check |
| Repo owns everything (freeze GSD hooks) | All current files stay checked into repo. Couples repo to GSD internals. | |
| Per-file hook symlinks | Repo files symlinked individually; GSD files coexist as native. | |

**User's choice:** Repo owns only the 7 zsh hooks (Recommended)

### Is anything in P7 about deploying project-level .claude/CLAUDE.md?

| Option | Description | Selected |
|--------|-------------|----------|
| Global only -- project-level is in-place | P7 deploys global ~/.config/claude/* only. Project-level auto-loaded from repo working directory. | check |
| Both global and project-level template | Scope creep. | |

**User's choice:** Global only -- project-level is in-place (Recommended)

### Should the 7 zsh hooks live flat or split by lifecycle?

| Option | Description | Selected |
|--------|-------------|----------|
| Flat claude/hooks/ | All 7 hooks under claude/hooks/. Matches v1 + "flat directories in v1" convention. hooks.json is canonical wiring. | check |
| Split by lifecycle event | Subdirs mirror hooks.json events. Discoverable but redundant. | |

**User's choice:** Flat claude/hooks/ (Recommended)

### Follow-up: hooks dir-symlink + GSD coexistence resolution (also applies to agents/commands/skills)

| Option | Description | Selected |
|--------|-------------|----------|
| Per-file symlinks only for hooks/; agents/commands/skills stay dir | hooks/ per-file (7 zsh + lib.zsh). agents/commands/skills stay dir AND repo gsd-* content gets deleted -- GSD owns those at runtime. | check |
| Per-file symlinks everywhere | All four subtrees get leaf-level symlinks. ~50-100 symlinks. | |
| Drop repo ownership of all 4 subdirs; deploy only files | Repo's agents/commands/skills DELETED. Only hooks/ + CLAUDE.md + settings.json symlinked. | |

**User's choice:** Per-file symlinks only for hooks/; agents/commands/skills stay dir (Recommended)

**Notes:** Contradiction between "Mixed top-level (6 links)" and "Repo owns only 7 zsh hooks" surfaced and resolved. Final shape: 2 file + 3 dir + 8 per-file inside hooks/ = 13 total symlinks.

---

## Tool config layout under configs/

### How should the configs/ directory be shaped per-tool?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-tool subdirectory, always | Every tool gets configs/<tool>/ even when single-file. Predictable; matches README-per-directory convention. | check |
| Flat configs/<tool>.<ext> when single-file | Asymmetric layout. | |

**User's choice:** Per-tool subdirectory, always (Recommended)

### Should source filenames under configs/<tool>/ match the destination filename, or preserve the v1 source names?

| Option | Description | Selected |
|--------|-------------|----------|
| Match destination | configs/eza/theme.yaml, configs/tlrc/config.toml. Removes a translation step in your head and in links.yml. | check |
| Preserve v1 source names | Adds an indirection. | |
| Match destination AND drop tool-prefixed file names | Breaks discoverability on deployed system. | |

**User's choice:** Match destination (Recommended)

### How should tool configs be gated per machine?

| Option | Description | Selected |
|--------|-------------|----------|
| Only ghostty gated; rest always-on | ghostty config gated on existing `ghostty` flag. Six others always-on -- their CLIs ship via core.rb. motd gates at the function level. | check |
| Every tool gated, one flag per tool | 5 new flags for marginal value. | |
| Conditional on package presence (no flags) | Implicit; conflicts with LINT-02. | |

**User's choice:** Only ghostty gated; rest always-on (Recommended)

### How should motd be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| configs/motd/ with no symlink in links.yml | Source files at configs/motd/. Function reads via ${DOTFILEDIR}/configs/motd/. | check |
| Leave motd files in shell/ tree | Breaks "everything tool-related lives in configs/<tool>/" symmetry. | |
| Hybrid: configs/motd/ + symlink to sentinel destination | Scope creep. | |

**User's choice:** configs/motd/ with no symlink in links.yml (Recommended)

---

## GSD + marketplace status design (CLDE-03, CLDE-04)

### Where should the pinned GSD CLI version live?

| Option | Description | Selected |
|--------|-------------|----------|
| Taskfile vars block | CLAUDE_GSD_VERSION inline. | |
| Manifest TOML field | Per-machine override. | |
| .tool-versions file | New convention in TOML-based repo. | |

**User's choice:** Free-text -- "isnt GSD automatically updated as part of the install & update process? why pin the version? wouldnt we always want the latest?"

**Notes:** User rejected version-pinning premise entirely. CLDE-03's "version-pinned sentinel" framing reconceived as a presence sentinel. CLDE-03/ROADMAP wording amend lands as planner action item: "version-pinned" -> "presence."

### How should the status: block detect 'GSD is installed'?

| Option | Description | Selected |
|--------|-------------|----------|
| Sentinel file with version, compared in status | Write pinned version; status reads + compares. | |
| Artifact-presence sentinel (version-agnostic) | status: tests for known artifact. Cheaper but version-agnostic. | check |
| Runtime npx --check | Defeats CLDE-03 (no npx on every install). | |

**User's choice:** Artifact-presence sentinel (version-agnostic)

### What shape should claude:marketplace status check be?

| Option | Description | Selected |
|--------|-------------|----------|
| Two-condition status: marketplaces + plugins | Every marketplace in CLAUDE_MARKETPLACES present in `claude plugin marketplace list --json`; every plugin in CLAUDE_PLUGINS present in `claude plugin list --json`. Mirrors P5 packages:install two-condition status. | check |
| Per-plugin grep (no jq in status) | Simpler; brittle. | |
| Single status with jq returning full match | Tighter but harder to read. | |

**User's choice:** Two-condition status: marketplaces + plugins (Recommended)

### What should claude:install do when the `claude` CLI isn't installed yet?

| Option | Description | Selected |
|--------|-------------|----------|
| Status fails (task runs); claude:install hard-fails with helpful message | First cmd fails with "Run task packages:install first". | check |
| Status returns 0 (skip silently) when claude CLI missing | Confusing on direct invocation. | |
| Status returns 0 (skip with warning) when claude CLI missing | Hides configuration error. | |

**User's choice:** Status fails (task runs); claude:install hard-fails with helpful message (Recommended)

### Given no version pinning, how should the explicit 'update GSD' path be shaped?

| Option | Description | Selected |
|--------|-------------|----------|
| Separate task: `task claude:update` | claude:install idempotent. claude:update aggregates marketplace update + plugin update + sentinel-delete-then-gsd-reinstall. | check |
| Flag on install: UPDATE=1 task install | Muddies D-10. LINT-02 conflict. | |
| Sub-tasks (3 separate update tasks) | More knobs to remember. | |
| Just bump the sentinel manually | Crude; doesn't update plugins/marketplaces. | |

**User's choice:** Separate task: `task claude:update` (Recommended)

### What sentinel artifact path should signal 'GSD is installed'?

| Option | Description | Selected |
|--------|-------------|----------|
| $XDG_STATE_HOME/dotfiles/gsd-installed touchfile | Lives in dotfiles' own state dir. Matches manifest state-file pattern. Decoupled from GSD's internal layout. | check |
| Known GSD artifact path (e.g., gsd-progress/SKILL.md) | Couples to GSD's internal layout; brittle. | |
| Both: GSD artifact path AND our touchfile | Overkill. | |

**User's choice:** $XDG_STATE_HOME/dotfiles/gsd-installed touchfile (Recommended)

### Should `task claude:update` also update brew packages, or stay claude-scoped?

| Option | Description | Selected |
|--------|-------------|----------|
| Claude-scoped only | Updates marketplaces + plugins + GSD CLI. Does NOT touch brew. Single-responsibility. | check |
| Wraps brew upgrade for declared formulas/casks | Conflicts with D-10. Scope creep. | |

**User's choice:** Claude-scoped only (Recommended)

---

## Hook smoke-test shape + scope (TEST-01)

### What shape should the hook smoke-test runner take?

| Option | Description | Selected |
|--------|-------------|----------|
| Single zsh runner with inline fixtures | install/test-hooks.zsh holds runner + all fixtures as heredocs. One function per hook. | check |
| Per-hook fixture-files directory | tests/hooks/<hook>/<scenario>.json + .expected. More files; more discoverable. | |
| Inline in taskfiles/test.yml | YAML+heredoc+assertions is awkward. | |

**User's choice:** Single zsh runner with inline fixtures (Recommended)

### What coverage matrix per hook should be tested?

| Option | Description | Selected |
|--------|-------------|----------|
| One pass + one block scenario per hook | ~8 fixtures total. Smoke test, not full coverage. | check |
| Full matrix: pass, warn, block, edge-case per hook | ~20+ fixtures. Higher maintenance. | |
| One representative scenario per hook (block only) | Cheapest. Doesn't catch false-positives. | |

**User's choice:** One pass + one block scenario per hook (Recommended)

### Which hooks are in TEST-01 scope?

| Option | Description | Selected |
|--------|-------------|----------|
| The 4 named in CLDE-02 | secret-scan, no-emojis, no-ai-comments, agent-transparency. Matches the requirement text. | check |
| All 7 zsh hooks | Adds block-destructive, notify, post-compact. notify/post-compact are side-effecty. | |
| Only the 3 'gate' hooks | Drops agent-transparency. But CLDE-02 names it as the v1 bug-fix target. | |

**User's choice:** The 4 named in CLDE-02 (Recommended)

### Where should the runner live?

| Option | Description | Selected |
|--------|-------------|----------|
| install/test-hooks.zsh | Sibling of install/resolver.zsh, install/compose-brewfile.zsh, install/messages.zsh, install/cutover-gate.zsh. | check |
| tests/hooks.zsh (new top-level tests/ tree) | Adds top-level directory. | |
| claude/hooks/.tests/ (co-located with hooks) | Complicates symlink shape. | |

**User's choice:** install/test-hooks.zsh (Recommended)

---

## Claude's Discretion

Items deferred to the planner for final shape (see CONTEXT.md `<decisions>` Claude's Discretion section):

- TOOL-03 `_:safe-link` target-type guard semantics (pre-check + behavior on existing-non-symlink, backward compat with P3/P4/P5/P6 callers)
- TOOL-04 `_:check-link` strict-mode mechanism (optional SOURCE var; whether to retrofit P3/P4 callers)
- Whether to gate `claude:gsd` task on `claude-marketplace` feature flag (reuse vs new `claude-gsd` flag); recommendation: reuse `claude-marketplace`
- `agent-transparency.zsh` rewrite shape (function-wrapped vs drop-local-keyword); recommendation: function-wrapped
- `.gitignore` precision for GSD-managed paths (prefix-based exemption)
- Pre-Phase-7 cleanup commit (Plan 07-01) for deleting committed `gsd-*` artifacts
- `claude/hooks/lib.zsh` symlink behavior verification (sourcing through symlink)
- Per-hook fixture exit-code conventions (encoded inline in test-hooks.zsh)

## Deferred Ideas

See CONTEXT.md `<deferred>` section. Captured ideas span:

- Phase 8 ownership (task validate composition, task links:reconcile, docs work, v1 file deletion, proposed LINT-10)
- Future hardening out of v1 scope (per-platform CLAUDE.md overlay, settings.json schema validation, version-pin escape hatch, hook coverage expansion, per-tool feature flags, _:safe-link directory-merge mode, pre-commit hook for repo artifacts, session-trace export)
- Open questions for execution-time verification (GSD hand-authored skill preservation, `claude plugin update --all` semantics, npx flag set, lib.zsh in settings.json, hook test runner on servers)
