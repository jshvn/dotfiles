# Claude 5 Context Engineering Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure this repo's Claude Code surface around the Claude 5 context engineering
paradigm ([blog post, 2026-07-24](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)):
cut always-loaded generic rules, make CLAUDE.md gotchas-first, move detail behind progressive
disclosure, and retire manual memory machinery in favor of native auto-memory.

**Architecture:** All changes flow through surfaces this repo already owns: the ECC addon TOML
(`manifests/claude-addons/ecc.toml`), settings fragments (`claude/settings.d/`), the two
CLAUDE.md files, and repo-owned skills (`claude/skills/`). No new mechanisms; `task install`
remains the single convergence pipeline and LINT-09 keeps `settings.json` honest.

**Tech Stack:** go-task, zsh, TOML addon manifests, Claude Code skills/agents/hooks.

## Global Constraints

- No emojis anywhere, markdown included. No AI attribution in commits or files.
- Commit format `<type>(<scope>): <summary>`, imperative, under 75 chars.
- `claude/settings.json` is generated; only `claude/settings.d/*.json` fragments are edited, then `task install` recomposes.
- `manifests/claude-addons/ecc.toml` command arrays: one command string per line (LINT-13 applies to multi-element arrays).
- Machine-local working-tree links stay in `.git/info/exclude`, never `.gitignore`.
- Comments describe the current system only -- no migration history, no references to what was removed. When a task deletes a file, flag, or section, grep the tree for its name and update every referencing doc in the same commit.
- Every task ends in its own commit; rollback is `git revert <commit>` followed by `task install` to reconverge the machine.
- `[upgrade]` re-runs `install.sh`, which re-copies the selected payload. Every prune added to `[install].commands` MUST also appear in `[upgrade].commands` or the next `task install` resurrects what it pruned. In-array prunes are only for payload a kept component re-copies; a path a dropped component leaves behind gets a one-time rm.

---

## Why: the paradigm shift, measured against this repo

The article's core claim: Claude 5 generation models (Opus 5, Fable 5) were being
overconstrained -- Anthropic removed over 80% of Claude Code's own system prompt for these
models with no measurable coding-eval loss. Its six shifts, mapped to this repo:

| # | Shift | Applied by |
|---|-------|-----------|
| 1 | Rules -> judgment (drop absolutist generic rules) | Tasks 1, 7, 8 |
| 2 | Examples -> interface design | No action: hook messages and the task surface are already terse interfaces (see Deferred) |
| 3 | Upfront loading -> progressive disclosure | Tasks 2, 3, 5, 6, 7 |
| 4 | Repetition -> single authoritative location | Tasks 1, 3, 4, 8 |
| 5 | Manual memory -> native auto-memory | Task 4 |
| 6 | Simple specs -> rich references (code-as-spec, verification skills, rubrics) | Tasks 5, 6; the resolver + `resolved.json` are already code-as-spec |

### Baseline: measured per-session context tax (this machine, 2026-07-25)

Estimates: `bytes / 4` for prose files; roster/list entries estimated from description word
counts. Directional, not exact. The rules-tree row is direct observation, not inference: the
full text of `~/.claude/rules/ecc/` README + common/ appears in this repo's live session
context (Claude Code reads `~/.claude/rules/` natively, independent of CLAUDE_CONFIG_DIR).
Re-confirm with `/context` or the `context-dump` skill before executing Task 1.

| Always-loaded source | On disk | Est. tokens | After plan |
|---|---|---|---|
| `~/.claude/rules/ecc/` (README + common/, auto-loaded every session) | 23,041 B | ~5,800 | 0 |
| Project `CLAUDE.md` | 19,287 B | ~4,800 | ~1,300 |
| Global `claude/CLAUDE.md` | 3,459 B | ~900 | ~850 |
| ECC agent roster (67 descriptions in every session) | 432 KB bodies | ~2,500 | ~500 (11 agents) |
| ECC skill-list entries (43 linked skills) | -- | ~1,500 | ~300 (8 skills) |
| ECC prior-session summary injection (SessionStart hook) | <=4,000 B | ~1,000 | 0 |
| Superpowers SessionStart injection (skill text plus the hook's wrapper) | 3,063 B | ~1,000 | ~1,000 (kept, see Decisions) |
| Superpowers skill-list entries (~14 skills) | -- | ~400 | ~400 (kept) |
| **Total user-config overhead** | | **~17,900** | **~4,350 (about 75% reclaimed)** |

Beyond tokens, the ECC rules actively conflict with the global CLAUDE.md -- the exact
"conflicting guidance forces deliberation" failure the article opens with:

- ECC `git-workflow.md` mandates `<type>: <description>`; global CLAUDE.md mandates `<type>(<scope>): <summary>`.
- ECC `testing.md` mandates TDD with 80% coverage and three test types for all work; global CLAUDE.md mandates lazy-YAGNI with ONE runnable check.
- ECC `patterns.md` prescribes Repository Pattern and API response envelopes; global CLAUDE.md forbids unrequested abstractions and boilerplate.
- ECC `performance.md` describes a pre-Claude-5 model lineup ("Sonnet: best coding model") -- stale facts injected into every session.

---

> **Read first:** Tasks 1-4 assume the ECC addon stays installed. The "Trimmed addon or
> vendored files" decision (after Task 9) presents a simpler alternative that replaces
> Tasks 1-4 entirely; pick a path before executing.

### Task 1: Stop loading ECC always-on rules

**Files:**
- Modify: `manifests/claude-addons/ecc.toml` (`[install].commands`, `[upgrade].commands`, header comment)
- Modify: `docs/CLAUDE-ADDONS.md` (worked-example installer bullet, same commit as the flag change)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `~/.claude/rules/ecc` and `~/.claude/AGENTS.md` absent after any `task install`; their `[footprint] extra_paths` entries stay (still valid for `claude-addons:remove`).

The installer's component selector excludes the rules tree at copy time:
`manifests/install-components.json` in the marketplace clone declares `baseline:rules`, and
`--without` is the same mechanism already dropping `baseline:commands` (proven live:
`~/.claude/commands` does not exist). Each `--without` flag takes one component id and
repeats. The installer does not garbage-collect prior copies, so already-converged machines
need a one-time rm. Nothing replaces the rules: their generic content (immutability, DRY,
error handling, review checklists) is baseline Claude 5 judgment, their workflow content
duplicates installed skills (superpowers TDD, code-review commands, security-reviewer agent),
and their Josh-specific content is already in the global CLAUDE.md. `~/.claude/AGENTS.md`
carries the identical conflicting guidance (mandatory TDD, 80% coverage) but ships with the
kept `agents-core` module and is re-copied on every run, so it gets an in-array prune. It is
not session-loaded on this setup (CLAUDE_CONFIG_DIR points at `~/.config/claude/`), but any
AGENTS.md-reading tool aimed at `~/.claude` would ingest it.

- [ ] **Step 1: Exclude the rules component in both command arrays**

In `[install].commands` and `[upgrade].commands`, change both installer invocations:

```
--profile minimal --without baseline:commands --with baseline:hooks
```

to:

```
--profile minimal --without baseline:commands --without baseline:rules --with baseline:hooks
```

- [ ] **Step 2: Add the AGENTS.md prune to both command arrays**

In `[install].commands`, insert directly after the `install.sh` line:

```toml
  "rm -f \"$HOME/.claude/AGENTS.md\"",
```

Insert the identical line after the `install.sh` line in `[upgrade].commands`.

- [ ] **Step 3: Update the header comment**

In the ecc.toml header, change:

```
#     upstream target): ~21 workflow skills, 67 agents, rules, hook scripts.
#     `--without baseline:commands` drops the 93 legacy slash-command shims
#     (skills cover the same workflows); `--with baseline:hooks` installs the
#     hook *scripts* without registering any hooks.
```

to:

```
#     upstream target): workflow skills, agents, hook scripts.
#     `--without baseline:commands` drops the 93 legacy slash-command shims
#     (skills cover the same workflows); `--without baseline:rules` drops the
#     always-on rules tree (generic guidance Claude 5 does not need);
#     `--with baseline:hooks` installs the hook *scripts* without registering
#     any hooks.
```

- [ ] **Step 4: Update the addon doc's installer bullet in the same commit**

In `docs/CLAUDE-ADDONS.md` (the ECC worked example):

```
- runs `install.sh --target claude --profile minimal --without
  baseline:commands --with baseline:hooks` to copy a trimmed payload into
```

to:

```
- runs `install.sh --target claude --profile minimal --without
  baseline:commands --without baseline:rules --with baseline:hooks` to copy
  a trimmed payload into
```

- [ ] **Step 5: One-time removal of the legacy tree, then converge and verify**

```bash
rm -rf "$HOME/.claude/rules/ecc"
task install
```

Then: `test ! -d "$HOME/.claude/rules/ecc" && test ! -f "$HOME/.claude/AGENTS.md" && echo PRUNED`
Expected: `PRUNED`, and still `PRUNED` after a second `task install` (the excluded component
is never re-copied). A fresh Claude session no longer shows `rules/ecc` content in context.

- [ ] **Step 6: Commit**

```bash
git add manifests/claude-addons/ecc.toml docs/CLAUDE-ADDONS.md
git commit -m "refactor(claude): stop loading ecc always-on rules"
```

---

### Task 2: Prune the ECC agent roster from 67 to 11

**Files:**
- Modify: `manifests/claude-addons/ecc.toml` (`[install].commands`, `[upgrade].commands`)

**Interfaces:**
- Consumes: Task 1's `rm -f .../AGENTS.md` line (used as this task's insertion anchor).
- Produces: `~/.claude/agents/` holds exactly these 11 files after any `task install`: `architect.md`, `build-error-resolver.md`, `code-explorer.md`, `code-reviewer.md`, `code-simplifier.md`, `doc-updater.md`, `planner.md`, `python-reviewer.md`, `refactor-cleaner.md`, `security-reviewer.md`, `typescript-reviewer.md`.

Every agent description loads into every session's roster whether or not the agent is ever
spawned. The dropped 56 (flutter, django, harmonyos, pytorch, marketing, seo, healthcare,
gan-*, network-*, opensource-*, ...) do not match this machine's stacks (zsh/go-task dotfiles;
Python, TypeScript, shell per global CLAUDE.md). The keep-list preserves the global CLAUDE.md
delegation rule (language-specific reviewers for Python/TypeScript) plus the core
plan/review/explore/build set. Restoring an agent later = add its filename to the keep-list
below and re-run `task install` (upgrade re-copies all 67, then prunes).

- [ ] **Step 1: Add the prune to both command arrays**

Insert after the `rm -f .../AGENTS.md` line (from Task 1) in BOTH `[install].commands` and
`[upgrade].commands`, as one line:

```toml
  "find \"$HOME/.claude/agents\" -maxdepth 1 -name '*.md' ! -name 'architect.md' ! -name 'build-error-resolver.md' ! -name 'code-explorer.md' ! -name 'code-reviewer.md' ! -name 'code-simplifier.md' ! -name 'doc-updater.md' ! -name 'planner.md' ! -name 'python-reviewer.md' ! -name 'refactor-cleaner.md' ! -name 'security-reviewer.md' ! -name 'typescript-reviewer.md' -delete",
```

- [ ] **Step 2: Converge and verify**

Run: `task install`
Then: `ls "$HOME/.claude/agents"/*.md | wc -l`
Expected: `11`

- [ ] **Step 3: Commit**

```bash
git add manifests/claude-addons/ecc.toml
git commit -m "refactor(claude): prune ecc agent roster to dotfiles-relevant set"
```

---

### Task 3: Curate ECC skill links from 43 to 8

**Files:**
- Modify: `manifests/claude-addons/ecc.toml` (`[install].commands`, `[upgrade].commands`, the "Skills MUST be linked flat" comment paragraph)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: exactly these 8 ECC skills linked into `$XDG_CONFIG_HOME/claude/skills/`: `agent-sort`, `architecture-decision-records`, `code-tour`, `codebase-onboarding`, `config-gc`, `context-budget`, `council`, `skill-scout`. The full payload stays at `~/.claude/skills/ecc/` (relink = add a name to the list, `task install`).

Kept: config/meta hygiene tools with no native or superpowers equivalent. Dropped links (still
on disk, one line to restore): `tdd-workflow` and `git-workflow` (superpowers and global
CLAUDE.md own these), `continuous-learning` (deprecated by its own description),
`continuous-learning-v2` and `ck` (native auto-memory, Task 4), `strategic-compact` (native
compaction), `verification-loop`/`delivery-gate`/`eval-harness`/`santa-method` (superpowers
verification-before-completion covers the need), plus the non-daily rest
(windows-desktop-e2e, repo-scan, production-audit, plankton-code-quality, ...).

- [ ] **Step 1: Replace the link-all loop in `[install].commands`**

Replace this line:

```toml
  "find \"$HOME/.claude/skills/ecc\" -mindepth 1 -maxdepth 1 -type d | while read -r d; do ln -sfn \"$d\" \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/$(basename \"$d\")\"; done",
```

with these two lines (unlink pass first so machines converge down from 43; the case pattern
matches only ECC-payload targets, so repo-owned real dirs -- `context-dump`, `goalsmith`,
and Task 6's `verifying-dotfiles-changes` -- are untouched):

```toml
  "find \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/\" -maxdepth 1 -type l | while read -r l; do case \"$(readlink \"$l\")\" in \"$HOME/.claude/skills/ecc/\"*) rm -f \"$l\";; esac; done",
  "for s in agent-sort architecture-decision-records code-tour codebase-onboarding config-gc context-budget council skill-scout; do ln -sfn \"$HOME/.claude/skills/ecc/$s\" \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/$s\"; done",
```

- [ ] **Step 2: Same replacement in `[upgrade].commands`**

The `[upgrade]` array contains the identical link-all loop line; replace it with the same two
lines. The existing git-exclude append loops in both arrays stay unchanged -- they iterate
whatever links exist, which is now the curated set. Exclude lines for dropped links go stale
in `.git/info/exclude` -- inert by definition, the same convention the `[remove]` section
already documents.

- [ ] **Step 3: Update the comment paragraph**

In the `[install]` comment block, change:

```
# re-link semantics. LINT-03b scopes to taskfiles/*.yml and does not apply
# here. Skills MUST be linked flat (one link per skill dir): user-scope skill
```

to:

```
# re-link semantics. LINT-03b scopes to taskfiles/*.yml and does not apply
# here. Skills are linked flat from a curated keep-list (one link per kept
# skill; the rest of the payload stays unlinked on disk): user-scope skill
```

- [ ] **Step 4: Converge and verify**

Run: `task install`
Then: `find "${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/" -maxdepth 1 -type l -exec readlink {} ';' | grep -c "^$HOME/.claude/skills/ecc/"`
Expected: `8`

- [ ] **Step 5: Commit**

```bash
git add manifests/claude-addons/ecc.toml
git commit -m "refactor(claude): curate ecc skill links to daily set"
```

---

### Task 4: Drop ECC session hooks; rely on native auto-memory

**Files:**
- Delete: `manifests/claude-addons/ecc.fragment.json`
- Delete: `claude/settings.d/99-addon-ecc.json`
- Modify: `manifests/claude-addons/ecc.toml` (installer flags, hook-runtime prune, `[footprint]`, header comment)
- Modify: `docs/CLAUDE-ADDONS.md`, `manifests/claude-addons/README.md` (fragment references)
- Modify: `manifests/machines/personal-laptop.toml` (node formula comment)

**Interfaces:**
- Consumes: Task 1's installer-flag and comment edits (this task's quoted old text builds on them).
- Produces: `claude/settings.json` (recomposed) with no `Stop`/`PreCompact` hooks, no `session-start-bootstrap.js` SessionStart entry, no `ECC_SESSION_START_MAX_CHARS` env. Repo-owned hooks from `10-hooks.json` are untouched. Nothing under `docs/` or `manifests/` references `ecc.fragment.json` anymore.

The article's shift 5: Claude now captures relevant memories automatically -- and the native
memory directory is already active for this project (`MEMORY.md` index + per-fact files). The
ECC pipeline injects up to 4,000 chars of prior-session summary wrapped in its own
"STALE-BY-DEFAULT -- MUST NOT re-execute" warning (context that mostly warns against itself)
and spawns node on every session start, stop, and compaction.

- [ ] **Step 1: Delete the fragment pair**

```bash
rm manifests/claude-addons/ecc.fragment.json claude/settings.d/99-addon-ecc.json
```

(The addon schema treats the settings fragment as optional; `[verify]` does not reference it.)

- [ ] **Step 2: Drop the hook-scripts component from both installer invocations**

In `[install].commands` and `[upgrade].commands`, change both occurrences of:

```
--profile minimal --without baseline:commands --without baseline:rules --with baseline:hooks
```

to:

```
--profile minimal --without baseline:commands --without baseline:rules
```

- [ ] **Step 3: One-time removal of the hook runtime**

```bash
rm -rf "$HOME/.claude/scripts/hooks" "$HOME/.claude/scripts/lib" "$HOME/.claude/hooks"
```

All three paths belong to the `hooks-runtime` module (per the marketplace's
`manifests/install-modules.json`), which Step 2 stops installing -- nothing re-copies them,
so the one-time rm is durable. The platform-configs module's payload
(`scripts/auto-update.js`, `scripts/setup-package-manager.js`) stays: inert files with zero
session cost.

- [ ] **Step 4: Update the ecc.toml comments**

Replace the fragment paragraph in the header:

```
#   - The paired ecc.fragment.json registers ONLY the three session-persistence
#     hooks (session-start, pre-compact, session-end) and caps the session
#     summary at 4000 chars. No GateGuard, no observers, no format/notify/cost
#     Stop hooks, no per-tool-call node spawns.
```

with:

```
#   - No settings fragment: the addon registers zero hooks. Session
#     continuity is native auto-memory; no node spawns on start/stop/compact.
```

And drop the hook-scripts wording from the payload/flags comment (Task 1's version,
accurate until this task):

```
#     upstream target): workflow skills, agents, hook scripts.
#     `--without baseline:commands` drops the 93 legacy slash-command shims
#     (skills cover the same workflows); `--without baseline:rules` drops the
#     always-on rules tree (generic guidance Claude 5 does not need);
#     `--with baseline:hooks` installs the hook *scripts* without registering
#     any hooks.
```

to:

```
#     upstream target): workflow skills and agents.
#     `--without baseline:commands` drops the 93 legacy slash-command shims
#     (skills cover the same workflows); `--without baseline:rules` drops the
#     always-on rules tree (generic guidance Claude 5 does not need).
```

- [ ] **Step 5: Track the learned-instincts dir in the footprint and clean it up**

In `[footprint].extra_paths`, after the `"$HOME/.claude/skills/ecc",` line add:

```toml
  "$HOME/.claude/skills/learned",
```

Then one-time on this machine (empty orphan of the now-unlinked continuous-learning-v2):

```bash
rmdir "$HOME/.claude/skills/learned" 2>/dev/null || true
```

- [ ] **Step 6: Purge stale fragment references from the addon docs**

In `docs/CLAUDE-ADDONS.md`, four edits. The section heading:

```
### Installer-script addon with cherry-picked hooks (the ECC pattern)
```

to:

```
### Installer-script addon with post-copy prunes (the ECC pattern)
```

The installer invocation bullet (Task 1's version, which already added the rules exclusion):

```
- runs `install.sh --target claude --profile minimal --without
  baseline:commands --without baseline:rules --with baseline:hooks` to copy
  a trimmed payload into
```

to:

```
- runs `install.sh --target claude --profile minimal --without
  baseline:commands --without baseline:rules` to copy a trimmed payload into
```

The fragment bullet:

```
- registers ONLY the three session-persistence hooks via the paired
  [`ecc.fragment.json`](../manifests/claude-addons/ecc.fragment.json) --
  per-hook cherry-picking the plugin path cannot do.
```

to:

```
- registers no hooks and ships no settings fragment -- session continuity is
  native auto-memory, and post-copy prunes in `[install]`/`[upgrade]` keep
  the payload to the curated keep-lists.
```

The array-replace caveat (keep the caveat, drop the dead example):

```
**Array-replace caveat:** compose deep-merges with jq `*`, which merges maps
but REPLACES arrays. A fragment that defines `hooks.<Event>` replaces that
event's whole array from earlier fragments. `ecc.fragment.json` defines
`hooks.SessionStart`, so it restates the repo's post-compact entry from
`10-hooks.json`; editing the SessionStart wiring in `10-hooks.json` requires
mirroring the change there. Events a fragment doesn't mention are unaffected.
```

to:

```
**Array-replace caveat:** compose deep-merges with jq `*`, which merges maps
but REPLACES arrays. A fragment that defines `hooks.<Event>` replaces that
event's whole array from earlier fragments, so it must restate any entries
from `10-hooks.json` it wants to keep (a fragment defining
`hooks.SessionStart` restates the repo's post-compact entry). Events a
fragment doesn't mention are unaffected.
```

In `manifests/claude-addons/README.md`, replace the ecc reference-case bullet:

```
- [`ecc.toml`](ecc.toml) -- installer-script addon with cherry-picked hooks.
  NOT the ecc@ecc plugin (untrimmable ~228-skill context tax): the ecc
  marketplace stays registered as the upgrade fetch, `install.sh` copies the
  minimal profile into `~/.claude/`, flat per-skill symlinks + an `agents/ecc`
  dir link expose it under `$XDG_CONFIG_HOME/claude/`, and the paired
  [`ecc.fragment.json`](ecc.fragment.json)
  registers only the three session-persistence hooks (see the array-replace
  caveat in `docs/CLAUDE-ADDONS.md`). **Enabled on `personal-laptop` only.**
```

with:

```
- [`ecc.toml`](ecc.toml) -- installer-script addon with post-copy prunes.
  NOT the ecc@ecc plugin (untrimmable ~228-skill context tax): the ecc
  marketplace stays registered as the upgrade fetch, `install.sh` copies the
  minimal profile into `~/.claude/`, in-array prunes trim it to the curated
  keep-lists, and flat per-skill symlinks + an `agents/ecc` dir link expose
  it under `$XDG_CONFIG_HOME/claude/`. No paired fragment -- the addon
  registers no hooks. **Enabled on `personal-laptop` only.**
```

- [ ] **Step 7: Correct the node formula comment**

In `manifests/machines/personal-laptop.toml`:

```
# node: the ecc Claude addon's hooks invoke the `node` binary directly.
```

to:

```
# node: the ecc Claude addon's installer runtime (install.sh delegates to Node).
```

- [ ] **Step 8: Recompose and verify**

Run: `task install`
Then: `jq -r '.hooks | keys | sort | join(",")' claude/settings.json`
Expected: `Notification,PostToolUse,PreToolUse,SessionStart` (SessionStart retains only the repo post-compact hook)
Then: `jq '.env' claude/settings.json`
Expected: `null`
Then: `grep -rn 'ecc\.fragment' docs/ manifests/ README.md`
Expected: no matches.
Then: `test ! -d "$HOME/.claude/scripts/hooks" && test ! -d "$HOME/.claude/scripts/lib" && test ! -d "$HOME/.claude/hooks" && echo HOOKLESS`
Expected: `HOOKLESS`
Then: `task lint`
Expected: zero failure crosses in the output, LINT-09 included (the lint aggregate always
exits 0 by design).

- [ ] **Step 9: Commit**

```bash
git add -A manifests/ claude/settings.d/ claude/settings.json docs/CLAUDE-ADDONS.md
git commit -m "refactor(claude): drop ecc session hooks in favor of native auto-memory"
```

---

### Task 5: Move decisions, scope, and constraints to docs/DECISIONS.md

**Files:**
- Create: `docs/DECISIONS.md`
- Modify: `docs/README.md` (index entry)
- Reference: `CLAUDE.md` (source of the copied sections; its deletion edit happens in Task 7)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `docs/DECISIONS.md` containing, verbatim from today's CLAUDE.md, the sections "Key Decisions" (full table), "Out of Scope" (all bullets with reasoning), "Performance and Security Constraints" (all three bullets), and "Tooling Versions" (full table). Task 7's CLAUDE.md draft links here.

This is reference material consulted when re-litigating direction -- exactly what progressive
disclosure moves out of the every-session file.

- [ ] **Step 1: Create the file**

Create `docs/DECISIONS.md` with this frame, pasting each listed CLAUDE.md section's body
verbatim under the matching heading:

```markdown
# Decisions, Scope, and Constraints

Locked decisions with rationale. The point is to prevent re-litigation; revisit only with
new evidence. Referenced from CLAUDE.md.

## Key Decisions

[paste the "Key Decisions" table from CLAUDE.md, unchanged]

## Out of Scope

[paste the "Out of Scope" bullets from CLAUDE.md, unchanged]

## Performance and Security Constraints

[paste the "Performance and Security Constraints" bullets from CLAUDE.md, unchanged]

## Tooling Versions

[paste the "Tooling Versions" table from CLAUDE.md, unchanged]
```

- [ ] **Step 2: Index it**

Add to the file list in `docs/README.md`, matching the surrounding entry format:

```markdown
- `DECISIONS.md` -- locked decisions, scope boundaries, performance/security constraints
```

- [ ] **Step 3: Verify**

Run: `grep -c '^## ' docs/DECISIONS.md`
Expected: `4`

- [ ] **Step 4: Commit**

```bash
git add docs/DECISIONS.md docs/README.md
git commit -m "docs(decisions): move decisions and constraints out of CLAUDE.md"
```

---

### Task 6: Create the verification skill

**Files:**
- Create: `claude/skills/verifying-dotfiles-changes/SKILL.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: skill name `verifying-dotfiles-changes`, auto-discovered via the existing `$XDG_CONFIG_HOME/claude/skills` symlink into `claude/skills/` (repo-owned real directory beside the machine-local ECC links; the ECC unlink pass in Task 3 only touches symlinks, so this survives). Task 7's CLAUDE.md draft references it by this exact name.

The article's own worked example: "if you have several unique instructions on how to verify
your work, create a verification skill and reference it from your CLAUDE.md." The five-tier
model and per-change-type commands currently live inline in CLAUDE.md; they load only when
verifying once they live here.

- [ ] **Step 1: Write the skill**

Create `claude/skills/verifying-dotfiles-changes/SKILL.md`:

```markdown
---
name: verifying-dotfiles-changes
description: Use after changing anything in this dotfiles repo - maps each change type to the task commands that prove convergence; five-tier testing model; one-check rule.
---

# Verifying Dotfiles Changes

Run the narrowest check that can fail, then the relevant aggregate.

| You changed | Run | Proves |
|---|---|---|
| Any taskfile | `task lint` | LINT-02..13 pass, banner drift caught |
| Machine/base/feature TOML | `task setup -- "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/machine")" && task manifest:audit` | resolver validates, resolved.json fresh |
| Package declarations | `task install && task packages:audit` | Brewfile converges, no drift |
| Symlink entries (links.yml) | `task install && task links:audit` | links exist, point into the repo |
| Shell files (.zsh) | `task lint && task test && exec zsh` | parse-check, smoke tests, live shell loads |
| claude/settings.d fragments | `task install && task claude:audit` | settings.json recomposed, LINT-09 clean |
| Claude addon TOMLs | `task install && task claude-addons:audit` | addon verify probes pass |
| os/defaults | `task install`, then log out/in for domains that need it | defaults applied |

Aggregates: `task validate` (installation state), `task test` (all smoke tests),
`task audit` (all-domain drift, read-only).

## The five-tier model

1. Static lint (`task lint`) -- syntax and repo rules, no side effects
2. Validate (`task validate`) -- is the machine in its declared state
3. Reconcile (`task install`) -- converge; a second run must be a fast no-op, so a re-run
   that does work is itself a failed check
4. Smoke (`task test`) -- behavior probes
5. System (`task audit`) -- cross-domain drift detection

Each tier catches a different drift class; "looks installed but isn't" and
"symlink-soup-after-refactor" are the two this repo has been burned by.

## The one-check rule

Non-trivial logic ships with one runnable check that fails if the logic breaks -- an
assert-based self-check or a smoke test wired into `task test`. No frameworks, no fixtures.
A change without its check is unfinished.
```

- [ ] **Step 2: Verify discovery**

Run: `test -f "${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/verifying-dotfiles-changes/SKILL.md" && echo DISCOVERABLE`
Expected: `DISCOVERABLE` (a fresh session lists the skill).

- [ ] **Step 3: Commit**

```bash
git add claude/skills/verifying-dotfiles-changes/
git commit -m "feat(claude): add verification skill for change-type checks"
```

---

### Task 7: Rewrite project CLAUDE.md gotchas-first

**Files:**
- Modify: `CLAUDE.md` (full replacement below)
- Modify: `taskfiles/README.md` (receives the lint catalogue table)
- Modify: `README.md`, `taskfiles/lint.yml`, `docs/LINT-FIXES.md`, `docs/CLAUDE-ADDONS.md`, `claude/README.md` (references to moved or renamed sections)

**Interfaces:**
- Consumes: `docs/DECISIONS.md` (Task 5), skill name `verifying-dotfiles-changes` (Task 6).
- Produces: CLAUDE.md under 8,000 bytes; every removed section reachable one hop away.

Per the article: briefly say what the repo is, spend the tokens on gotchas, avoid stating what
the file system already shows. Dropped content and where it went: "Where to Add Things" table
-> per-directory READMEs (all nine exist); Key Decisions / Out of Scope / constraints /
tooling versions -> `docs/DECISIONS.md`; five-tier testing and per-change verification ->
`verifying-dotfiles-changes` skill; lint catalogue table -> `taskfiles/README.md` (rule
bodies already live in `taskfiles/lint.yml`); schema detail -> `docs/MANIFEST.md` and
`docs/CLAUDE-ADDONS.md`. The XDG defaults table is dropped without relocation: the values
live in `shell/.zshenv`, and the draft keeps a one-line XDG gotcha.

- [ ] **Step 1: Replace CLAUDE.md wholesale with:**

```markdown
# Dotfiles v2 -- Project Instructions for AI Agents

## What This Is

Manifest-model dotfiles for macOS (Apple Silicon and Intel). Each machine is described by one
self-contained TOML at `manifests/machines/<name>.toml`, validated against the feature-flag
registry `manifests/features.toml`, and compiled by `install/resolver.zsh` into a JSON cache
that every go-task task reads. No profile suffixes, no hostname inference, no hidden branching.

| Concept | Location |
|---------|----------|
| Feature-flag registry | `manifests/features.toml` |
| Per-machine declaration | `manifests/machines/<name>.toml` |
| Unconditional package tier | `manifests/base.toml` |
| Compiled output (machine-local) | `$XDG_STATE_HOME/dotfiles/resolved.json` |
| Active machine name (machine-local) | `$XDG_STATE_HOME/dotfiles/machine` |

## Finding Things

- Manifest schema: `docs/MANIFEST.md`. Claude addon schema: `docs/CLAUDE-ADDONS.md`.
- Locked decisions, scope boundaries, performance/security constraints: `docs/DECISIONS.md`.
  Revisit only with new evidence.
- Every top-level concept directory has a README saying what belongs there and how to name it.
- Operator surface: six lifecycle commands (`install`, `setup`, `validate`, `test`, `lint`,
  `audit`) plus `<domain>:<verb>` diagnostics (`show`, `audit`). Bare `task` prints the
  banner; `task --list` the full graph. Per-component install/validate tasks are internal
  pipeline steps, not operator commands.
- Verifying a change: use the `verifying-dotfiles-changes` skill (change type to exact
  commands, five-tier model, one-check rule).

## Gotchas

What the file system will not tell you:

- Taskfiles read `resolved.json` (preloaded as `{{.MANIFEST}}`), never TOML. TOML parsing
  lives only in `install/resolver.zsh`.
- Kebab-case feature keys need the `index` form -- `{{if index .MANIFEST.features
  "one-password-ssh"}}` -- because `-` breaks Go-template dot-access at parse time.
- `status:` blocks evaluate before shell context exists: `{{.X}}` template vars only, never
  `$X` (empty there; the task re-runs forever). Every install task has a `status:` block
  returning 0 when converged.
- `claude/settings.json` is generated: edit `claude/settings.d/*.json` fragments, re-run
  `task install`. The composer preserves the CLI-managed keys `enabledPlugins`,
  `extraKnownMarketplaces`, `model`, `tui`. LINT-09 fails on drift; never hand-edit, and
  never register a hook there directly.
- A machine's `[features]` must account for every registry flag applicable to its `os` in
  either `enabled` or `disabled`; an unaccounted flag is a hard `task setup` error.
  Cross-field rules (e.g. identity overlays carrying `# capability:` sentinels require the
  matching feature) live in `validate_manifest` in `install/resolver.zsh`.
- Symlinks only via `_:safe-link` (`taskfiles/helpers.yml`); bare `ln -s` fails LINT-03b.
  Machine-local links that land in the working tree go in `.git/info/exclude`, not
  `.gitignore`.
- No hardcoded `/opt/homebrew` or `/usr/local`: `$HOMEBREW_PREFIX` (shell) or
  `{{.HOMEBREW_PREFIX}}` (task), resolved in the root Taskfile (LINT-10).
- Repo root is the go-task built-in `{{.ROOT_DIR}}`; scripts receive it as the `DOTFILEDIR`
  env var at invocation. No custom repo-root variable.
- Machine identity is explicit (`task setup -- <name>`); never infer from hostname or any
  environment heuristic.
- Executable `.zsh`: `set -euo pipefail` (LINT-04), the three-label header banner
  (Purpose / Depends on / Side effects between `# ===` 77-char rules, LINT-12), errors to
  stderr via `install/messages.zsh`. XDG paths come from `shell/.zshenv` and `{{.XDG_*}}`.
- Zsh startup order: `.zshenv` -> `.zprofile` (brew shellenv, 1Password socket) -> `.zshrc`
  (antidote plugins, theme, functions, aliases) -> `.zlogin` (MOTD) -> `.zlogout`.
- Lint rules LINT-02..13: catalogue table in `taskfiles/README.md`, rule bodies in
  `taskfiles/lint.yml`; `# LINT-NN:` comments cite them. LINT-01 and LINT-06 are
  intentionally retired numbers -- do not reuse.
- Third-party Claude addons are declarative: `manifests/claude-addons/<name>.toml` plus the
  machine's `[claude].addons` list; they install inside `task install`.
- One concept per file, flat directories: one alias topic / function / taskfile / machine
  manifest / defaults concern per file; no subdirectories under `shell/aliases/` or
  `manifests/base.toml`.
- Packages every machine needs belong in `manifests/base.toml` (never named by
  machine); a machine's own `[packages]` table is one-off extras with the identical shape,
  so promotion is a copy.
- No AI attribution and no emojis anywhere, markdown included (hooks enforce both). No
  private keys in the repo; `identity/ssh/keys/` holds public keys only.
```

- [ ] **Step 2: Relocate the lint catalogue and retarget every reference to the moved sections**

Append to `taskfiles/README.md` a `## Lint catalogue` section containing, verbatim from
today's CLAUDE.md, the LINT-02..13 table plus the retired-numbers paragraph (everything
under the current "### Lint rule catalogue (LINT-02..12)" heading, intro sentence included).

Then four reference fixes. In `README.md`:

```
See [CLAUDE.md](CLAUDE.md) for conventions, rules, where-to-add tables, and
the lint catalogue.
```

to:

```
See [CLAUDE.md](CLAUDE.md) for the gotchas and conventions; each top-level
directory's README says what belongs there; the lint catalogue lives in
[taskfiles/README.md](taskfiles/README.md).
```

In the `taskfiles/lint.yml` header banner:

```
#               recurring bug classes (01 and 06 intentionally absent). See
#               CLAUDE.md §Lint rule catalogue for the rule definitions.
```

to:

```
#               recurring bug classes (01 and 06 intentionally absent). See
#               taskfiles/README.md §Lint catalogue for the rule summaries.
```

In `taskfiles/README.md` (the Key files lint bullet):

```
  Enforces LINT-02..LINT-12
  (see the catalogue in `../CLAUDE.md`).
```

to:

```
  Enforces LINT-02..LINT-12
  (catalogue below).
```

and its References bullet:

```
- `../CLAUDE.md` -- v2 conventions (status-block templating, no bare
  `ln -s`, `set -euo pipefail` on every executable `.zsh`, the lint
  catalogue LINT-02..LINT-12).
```

to:

```
- `../CLAUDE.md` -- v2 gotchas (status-block templating, no bare
  `ln -s`, `set -euo pipefail` on every executable `.zsh`).
```

In `docs/LINT-FIXES.md`:

```
The LINT-02..12 rule
catalogue lives in `../CLAUDE.md`; the rule bodies live in `taskfiles/lint.yml`.
```

to:

```
The LINT-02..12 rule
catalogue lives in `../taskfiles/README.md`; the rule bodies live in `taskfiles/lint.yml`.
```

In `docs/CLAUDE-ADDONS.md` (Cross-references section; the "Rules" heading no longer exists
after this task):

```
- [`CLAUDE.md`](../CLAUDE.md) -- project rules; "Rules" section names this
  doc as the canonical reference for settings composition and addons.
```

to:

```
- [`CLAUDE.md`](../CLAUDE.md) -- project instructions; the Gotchas section
  covers settings composition and addons at a glance, with this doc as the
  deep reference.
```

And the same file's intro line:

```
For project rules see [`CLAUDE.md`](../CLAUDE.md).
```

to:

```
For project gotchas and conventions see [`CLAUDE.md`](../CLAUDE.md).
```

In `claude/README.md` (Canonical references; the quoted subheadings become Gotchas bullets):

```
- [`../CLAUDE.md`](../CLAUDE.md) -- project rules (see "settings.json is a
  generated build artifact" + "Third-party Claude addons are declarative").
```

to:

```
- [`../CLAUDE.md`](../CLAUDE.md) -- project instructions (see the Gotchas
  bullets on generated `settings.json` and declarative addons).
```

- [ ] **Step 3: Verify size and link integrity**

Run: `wc -c CLAUDE.md`
Expected: under 8000.
Run: `test -f docs/DECISIONS.md && test -f docs/MANIFEST.md && test -f docs/CLAUDE-ADDONS.md && test -f claude/skills/verifying-dotfiles-changes/SKILL.md && echo LINKS-OK`
Expected: `LINKS-OK`
Run: `grep -n 'Lint rule catalogue' README.md taskfiles/lint.yml docs/LINT-FIXES.md`
Expected: no matches (the phrase survives only in this plan and git history).
Run: `task lint`
Expected: zero failure crosses in the output (the aggregate always exits 0 by design).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md taskfiles/lint.yml taskfiles/README.md docs/LINT-FIXES.md docs/CLAUDE-ADDONS.md claude/README.md
git commit -m "docs(claude): rewrite CLAUDE.md gotchas-first with progressive disclosure"
```

---

### Task 8: Dedupe the global CLAUDE.md

**Files:**
- Modify: `claude/CLAUDE.md` (the file symlinked to `~/.config/claude/CLAUDE.md`)

**Interfaces:**
- Consumes: nothing.
- Produces: one authoritative statement per policy across the CLAUDE.md chain.

The file is already what the article endorses -- opinion-encoding particular to Josh -- so it
stays essentially intact. Only true repetition goes: the no-AI-attribution policy is currently
stated twice here, again in project CLAUDE.md, and enforced by a hook; the hook-behavior
description duplicates what the hooks report at runtime. The "Hooks block: secrets in code"
sentence goes with it deliberately: hook behavior is observable at runtime and documented in
`claude/README.md`'s hooks table. The replacement's "No emojis outside markdown." line
codifies the previously implicit global scope (project CLAUDE.md already cites it as the
global no-emojis-in-non-markdown rule).

- [ ] **Step 1: Collapse the Dotfiles section duplication**

In `claude/CLAUDE.md`, replace:

```markdown
Hooks block: secrets in code. Hooks warn: no emojis, no AI attribution.
No AI attribution anywhere -- no Co-Authored-By trailers, no "generated by" comments, not in source code or commit messages.
```

with:

```markdown
No AI attribution anywhere -- no Co-Authored-By trailers, no "generated by" comments, not in
source code or commit messages. No emojis outside markdown.
```

- [ ] **Step 2: Verify and commit**

Run: `grep -c 'AI attribution' claude/CLAUDE.md`
Expected: `1`

```bash
git add claude/CLAUDE.md
git commit -m "docs(claude): dedupe global instructions"
```

---

### Task 9: Converge, measure, and doctor

**Files:**
- None created; convergence and measurement only.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: measured before/after context numbers; a clean lint/test/audit run.

- [ ] **Step 1: Full converge on this machine**

Run: `task install`
Expected: converges with no unexpected work. The addon path re-runs its `[upgrade]` commands
on every invocation by design (always-pull-latest); every other domain must be a fast no-op
on the second run (idempotency contract).

- [ ] **Step 2: Full check suite**

Run: `task lint && task test && task audit`
Expected: lint shows zero failure crosses (its aggregate always exits 0 by design); test and
audit exit clean, `claude:audit` and `claude-addons:audit` included.

- [ ] **Step 3: Measure in a fresh session**

In a new interactive Claude Code session in this repo, run `/context` and record the totals
next to the baseline table in this plan (expected: user-config overhead drops from ~17.9k to
~4,350 tokens; also spot-check that the Things MCP tools still appear as deferred schemas
behind ToolSearch). Then run `/doctor` -- the article introduces it as the rightsizing assistant
for skills and CLAUDE.md -- and treat its findings as follow-up items, not auto-applied
changes.

- [ ] **Step 4: Converge other machines**

On every other machine whose manifest lists `ecc` in `[claude].addons` (check
`manifests/machines/*.toml`): `git pull && task install`. The upgrade path re-runs the
installer and applies the same prunes. Today this is a no-op: `personal-laptop` is the only
machine listing `ecc` (atium and work-laptop declare no `[claude]` table; ci declares
`addons = []`).

- [ ] **Step 5: Reference -- final ecc.toml command arrays**

After Tasks 1-4, the arrays read exactly (consistency check, not an edit):

```toml
[install]
commands = [
  "claude plugin marketplace add https://github.com/affaan-m/everything-claude-code.git",
  "bash \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/plugins/marketplaces/ecc/install.sh\" --target claude --profile minimal --without baseline:commands --without baseline:rules",
  "rm -f \"$HOME/.claude/AGENTS.md\"",
  "find \"$HOME/.claude/agents\" -maxdepth 1 -name '*.md' ! -name 'architect.md' ! -name 'build-error-resolver.md' ! -name 'code-explorer.md' ! -name 'code-reviewer.md' ! -name 'code-simplifier.md' ! -name 'doc-updater.md' ! -name 'planner.md' ! -name 'python-reviewer.md' ! -name 'refactor-cleaner.md' ! -name 'security-reviewer.md' ! -name 'typescript-reviewer.md' -delete",
  "find \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/\" -maxdepth 1 -type l | while read -r l; do case \"$(readlink \"$l\")\" in \"$HOME/.claude/skills/ecc/\"*) rm -f \"$l\";; esac; done",
  "for s in agent-sort architecture-decision-records code-tour codebase-onboarding config-gc context-budget council skill-scout; do ln -sfn \"$HOME/.claude/skills/ecc/$s\" \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/$s\"; done",
  "ln -sfn \"$HOME/.claude/agents\" \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/agents/ecc\"",
  "grep -qxF 'claude/agents/ecc' \"$DOTFILEDIR/.git/info/exclude\" || echo 'claude/agents/ecc' >> \"$DOTFILEDIR/.git/info/exclude\"",
  "find \"$DOTFILEDIR/claude/skills\" -maxdepth 1 -type l | while read -r l; do case \"$(readlink \"$l\")\" in \"$HOME/.claude/skills/ecc/\"*) grep -qxF \"claude/skills/$(basename \"$l\")\" \"$DOTFILEDIR/.git/info/exclude\" || echo \"claude/skills/$(basename \"$l\")\" >> \"$DOTFILEDIR/.git/info/exclude\";; esac; done",
]

[upgrade]
commands = [
  "claude plugin marketplace update ecc",
  "bash \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/plugins/marketplaces/ecc/install.sh\" --target claude --profile minimal --without baseline:commands --without baseline:rules",
  "rm -f \"$HOME/.claude/AGENTS.md\"",
  "find \"$HOME/.claude/agents\" -maxdepth 1 -name '*.md' ! -name 'architect.md' ! -name 'build-error-resolver.md' ! -name 'code-explorer.md' ! -name 'code-reviewer.md' ! -name 'code-simplifier.md' ! -name 'doc-updater.md' ! -name 'planner.md' ! -name 'python-reviewer.md' ! -name 'refactor-cleaner.md' ! -name 'security-reviewer.md' ! -name 'typescript-reviewer.md' -delete",
  "find \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/\" -maxdepth 1 -type l | while read -r l; do case \"$(readlink \"$l\")\" in \"$HOME/.claude/skills/ecc/\"*) rm -f \"$l\";; esac; done",
  "for s in agent-sort architecture-decision-records code-tour codebase-onboarding config-gc context-budget council skill-scout; do ln -sfn \"$HOME/.claude/skills/ecc/$s\" \"${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills/$s\"; done",
  "find \"$DOTFILEDIR/claude/skills\" -maxdepth 1 -type l | while read -r l; do case \"$(readlink \"$l\")\" in \"$HOME/.claude/skills/ecc/\"*) grep -qxF \"claude/skills/$(basename \"$l\")\" \"$DOTFILEDIR/.git/info/exclude\" || echo \"claude/skills/$(basename \"$l\")\" >> \"$DOTFILEDIR/.git/info/exclude\";; esac; done",
]
```

---

## Decision: trimmed addon or vendored files

Tasks 1-4 keep the ECC addon lifecycle and prune against it. The case for vendoring
instead, measured on this machine: the kept surface is ~120 KB (11 agents ~66 KB, 8 skills
~54 KB) out of a ~78 MB marketplace clone plus a Node/npm installer that re-runs on every
`task install` (the addon pipeline re-executes `[upgrade].commands` whenever `[verify]`
passes -- always-pull-latest by design). The prune choreography Tasks 1-4 build exists only
to fight that re-copy.

Vendoring path, replacing Tasks 1-4 wholesale:

1. Copy the 11 agent files into `claude/agents/` and the 8 skill dirs into `claude/skills/`
   as repo-owned committed files -- the pattern `context-dump`, `goalsmith`, and Task 6's
   `verifying-dotfiles-changes` already use.
2. `task claude-addons:remove -- ecc` (runs `[remove].commands`, walks the footprint,
   deletes the settings fragment copy, recomposes settings.json).
3. Delete `manifests/claude-addons/ecc.toml` and `ecc.fragment.json`; drop `"ecc"` from
   `personal-laptop.toml` `[claude].addons`; drop the `node` formula and its comment (the
   installer was its only consumer); purge the ECC reference case from
   `docs/CLAUDE-ADDONS.md` and `manifests/claude-addons/README.md`; remove the stale ECC
   link lines from `.git/info/exclude`.
4. Re-run `task setup -- personal-laptop && task install && task lint && task audit`.

Trade-off: upstream skill/agent updates arrive only by manual re-copy (for mature markdown
files that rarely matters); in exchange the marketplace clone, npm/node bootstrap, prune
choreography, and the whole always-pull-latest-vs-curated-subset tension disappear.

Recommendation: vendor. It deletes machinery instead of curating against it, and removes
the payload-resurrection failure mode by construction. Tasks 1-4 stay in this plan for the
keep-the-addon path; if vendoring is chosen, ask for the expanded bite-sized task breakdown
before executing.

## Decision Deferred: superpowers plugin

The superpowers SessionStart injection (~1,000 tokens of mandatory-skill-invocation rules with
a red-flags table) is the one remaining absolutist block, and it is philosophically the old
paradigm ("if there is even a 1% chance... you MUST"). Recommendation: **keep it for now**.

- The workflow skills (brainstorming, writing-plans, executing-plans, worktrees,
  verification-before-completion) are actively used here -- `docs/superpowers/plans/` exists
  because of them -- and they are opinion-encoding, which the article endorses.
- Upstream is already converging on the new paradigm: `using-superpowers/SKILL.md` shrank
  from 5,899 bytes (6.0.3) to 3,063 bytes (6.1.1/6.2.0) in the plugin cache.
- Exit path if it stops earning its tokens: `task claude-addons:remove -- superpowers`, then
  vendor the handful of used skills into `claude/skills/` as repo-owned dirs. Vendoring today
  would copy most of the plugin and forfeit upstream updates for ~1k tokens -- poor trade.

Revisit after a few weeks of Fable 5 sessions: if the model reaches for the right skills
without the shouting, drop the plugin and vendor.

## Deferred / No Action (with reasons)

- **MCP servers:** the Things server's 28 tools are already schema-deferred behind ToolSearch
  (article shift 3, already adopted); claude.ai connectors cost no context until
  authenticated.
- **Permissions allowlist vs `auto-approve-reads.zsh`:** layered by design -- the static list
  is the prompt-free fast path, the hook catches compound read-only commands the list cannot
  express. Zero session-token cost either way.
- **Repo-owned hooks (`claude/hooks/`):** enforcement, not context -- they inject nothing
  into sessions. Keep all.
- **Memory directory:** already the native auto-memory shape (index + one fact per file);
  nothing to migrate.
- **`~/.claude/.agents/` and installer leftovers (`scripts/auto-update.js`,
  `scripts/setup-package-manager.js`):** disk-only ECC payload, never session-loaded;
  `[footprint] extra_paths` already covers them for removal day.
- **Article shift 2 (interface design):** aimed at tool authors; this repo's interfaces (task
  surface, hook messages, addon TOML schema) are already terse. No change earns tokens.

## Expected Outcome

Per-session user-config overhead drops from ~17.9k to ~4,350 tokens (about 75%), every removed
piece of information remains one hop away (docs, skill, or upstream payload on disk), and the
conflicting-guidance pairs (commit format, TDD mandate, abstraction policy, stale model
lineup) are eliminated rather than adjudicated per-session.
