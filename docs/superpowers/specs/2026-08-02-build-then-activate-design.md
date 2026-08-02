# Build-Then-Activate -- Design

**Date:** 2026-08-02
**Status:** approved, pending implementation plan
**Baseline:** v2.5.0 (`f7bdee5`)
**Supersedes:** the 2026-07-23 NixOS architecture improvements plan (Phases 1
to 3; its Phase 4 was already superseded by the manifest tier restructure,
delivered in v2.5.0). That plan was executed and deleted -- see git history.

## Problem

Three symptoms, one root cause.

**1. Generated files live in the source tree.** Right now, on a clean
checkout with no work in progress:

```
$ git status --short
 M claude/settings.json
```

Nothing was edited. The Claude CLI wrote `model` and `tui` into
`claude/settings.json` -- a file the repo generates, tracks, and symlinks
live. Every `/model` invocation dirties the working tree.
`claude/settings.d/99-addon-ecc.json` is worse: it is written into the repo
by `task install` on whichever machines enable the `ecc` addon, so the
fragment directory is neither fully repo-owned nor fully generated and
`git status` differs per machine. LINT-09 exists solely to police this
arrangement.

**2. There is no materialized desired state, so there is no preview.**
Composition is interleaved with activation: `task install` composes a
Brewfile and applies it, composes `settings.json` and writes it live. The
question "what would `task install` change?" has no cheap answer because
nothing exists to compare against. This is why `task diff` reads as
"recompose the audit logic" rather than "diff two directories".

**3. Tests are found three different ways.** `install/test-*.zsh` (sibling
files), `manifests/test/fixtures/` (directory named `test`),
`taskfiles/test/lint-fixtures/` (nested one level deeper). Colocation is
right; the inconsistency means a new component's tests have no obvious home.

The root cause of 1 and 2 is the same: **the pipeline never separates
computing the desired state from applying it.** Fix that and both symptoms
resolve, plus `task diff` falls out as a corollary rather than a feature.

## Principle

From `docs/NIXOS-ARCHITECTURE-LEARNINGS.md`, take the staging discipline and
the purity rule, not the machinery:

| Stage | Purity | This repo |
|---|---|---|
| Evaluate | pure | `resolver.zsh`: manifests -> `resolved.json` |
| Realize | pure | compose: `resolved.json` + repo source -> `build/` |
| Activate | impure | install: `build/` -> the live system |

Two invariants follow, and everything in this design is downstream of them:

- **The repo tree contains source only.** No file that a task writes is
  tracked in git.
- **Every domain that installs something materializes it first.** If
  `task install` writes it, `build/` holds a copy of what it would write.

`task diff` is then a file comparison, not a computation.

## Target layout

Repo tree (changes only):

```
install/
  README.md                  (rewritten: stage taxonomy)
  messages.zsh               [lib]
  compose-settings.zsh       [lib]
  resolver.zsh               [evaluate]
  compose-brewfile.zsh       [realize]
  lint-rules.zsh             [operate]
  links-audit-scan.zsh       [operate]
  claude-addons.zsh          [operate]
  repo-sync.zsh              [operate]
  tests/
    hooks.zsh                (was install/test-hooks.zsh)
    links-audit.zsh          (was install/test-links-audit.zsh)
    repo-sync.zsh            (was install/test-repo-sync.zsh)
    shell-startup.zsh        (was install/test-shell-startup.zsh)
    settings-compose.zsh     (new)
manifests/
  tests/                     (was manifests/test/)
taskfiles/
  tests/lint-fixtures/       (was taskfiles/test/lint-fixtures/)
claude/
  settings.d/
    00-base.json             (repo-owned source)
    10-hooks.json            (repo-owned source)
                             (99-addon-*.json gone -- moved to state)
                             (settings.json gone -- moved to build)
```

State tree (`$XDG_STATE_HOME/dotfiles/`):

```
machine                      (existing)
resolved.json                (existing)
settings.d/                  (new: machine-generated addon fragments)
  99-addon-<name>.json
build/                       (new: the materialized desired state)
  Brewfile                   (moved from $XDG_CACHE_HOME/dotfiles/)
  settings.json
  links.map
```

Live system (unchanged except one entry):

```
~/.config/claude/settings.json   real file, copied from build/ by activation
                                 (was a symlink into the repo)
```

## Change 1 -- One test convention

A rename, not a redesign: every component's tests live at `<domain>/tests/`,
`task test` stays the single aggregator, fixture layout inside is untouched.

The one non-mechanical piece is lint scoping. Two lint rules currently
exclude fixtures with `--exclude-dir='test'`, which matches by basename.
Renaming to `tests/` would make that exclusion swallow `install/tests/` and
`manifests/tests/` as well -- silently dropping our own test scripts out of
the LINT-10 (hardcoded prefix) scan. The exclusions become
`--exclude-dir='lint-fixtures'`, which is both precise and honest about why
the exclusion exists: those fixtures deliberately violate lint rules. The
two `find`-based exclusions are already path-anchored
(`-not -path '.../taskfiles/test/*'`) and just follow the rename.

Net coverage change: `install/tests/*.zsh` gain LINT-10 coverage they do not
have today.

## Change 2 -- The repo tree becomes source only

Two generated files leave the repo.

### Addon fragments -> state

`install/claude-addons.zsh` writes `99-addon-<name>.json` into
`$XDG_STATE_HOME/dotfiles/settings.d/`. Compose reads two directories:

```
settings_compose_fragments <repo_d> <state_d> <preserved_json> [jq_flag]
```

Repo fragments merge first (numeric filename prefix = priority), then state
fragments, then preserved CLI keys on top. The state directory may be
missing or empty -- a machine with no addons never creates it. `find` (not a
glob) enumerates fragments so an empty directory does not abort under zsh's
`nomatch`.

### settings.json -> build, and the live file stops being a symlink

Today `~/.config/claude/settings.json` symlinks into the repo, so CLI writes
land in tracked source. After this change:

```
claude/settings.d/*.json  +  state settings.d/*.json  +  preserved CLI keys
        |
        v  claude:settings-compose  [realize, pure]
$XDG_STATE_HOME/dotfiles/build/settings.json
        |
        v  claude:activate  [activate, impure -- mktemp + mv]
~/.config/claude/settings.json  (real file; the Claude CLI writes here)
```

`settings.json` leaves `CLAUDE_LINKS`, so `links:validate` and the orphan
scanner stop seeing it; `claude:validate` already covers it via
`claude:audit`. `claude/settings.json` is `git rm`'d.

The remaining impurity is deliberate and one-directional: compose reads
`enabledPlugins`, `extraKnownMarketplaces`, `model`, and `tui` from the live
file, because the Claude CLI writes them there and that cannot be prevented.
Reading them at their actual source is the honest interface. What changes is
that this read no longer touches the repo.

The `mv` (not `cp`) in activation matters: `cp` onto the existing symlink
would follow it and write into the repo. `mv` replaces the directory entry,
converting the symlink to a real file on the first run after migration.

### LINT-09 is deleted

LINT-09 checks that the tracked `claude/settings.json` matches the composed
output. With no tracked artifact there is nothing for a repo lint to check --
build-vs-live is runtime drift, which is `claude:audit`'s job, and it already
runs under `task audit` and `task validate`. The rule number is retired
alongside the existing LINT-01 and LINT-06 gaps so in-code `# LINT-NN:`
citations stay unambiguous.

### What is given up

`claude/settings.json` currently serves as a committed record of the
composed result. After removal that record is not in git. It stays
reproducible: fragments are in git, and `enabledPlugins` /
`extraKnownMarketplaces` are rewritten by the `claude plugin` CLI during
`claude-addons:install`, which is itself driven by the machine manifest's
`[claude].addons`. On a fresh machine the first `task install` composes
without the CLI keys and the addon step writes them back -- the same
two-pass convergence that happens today.

## Change 3 -- task diff

Three artifacts are materialized into the build dir; `task diff` compares
each against the live system.

> **As built (2026-08-02):** an internal `build` aggregate task was designed
> to materialize all three at once. It was dropped during implementation:
> with `task diff` deping it *and* each `<domain>:diff` deping its own
> realize step, every artifact composed twice, and removing the per-domain
> deps instead would let a standalone `task links:diff` read a stale map.
> Each `<domain>:diff` now deps exactly the one realize step it reads
> (`packages:compose`, `links:emit-map`, `claude:settings-compose`), which
> refreshes each artifact exactly once and leaves the aggregate with no
> consumer. The build dir is unchanged; only the aggregate task is gone.

| Domain | Build artifact | Compared against |
|---|---|---|
| packages | `build/Brewfile` | `brew bundle check` + `brew outdated`, intersected with the declared set |
| links | `build/links.map` (`target<TAB>source`) | `readlink -f` on each target |
| claude | `build/settings.json` | `~/.config/claude/settings.json` |

`links.map` requires factoring the `resolve_source()` case statement
currently inlined in `links:validate` into a shared taskfile var, so the
map emitter and the validator cannot drift apart.

`claude:audit` and `claude:diff` compute the same comparison and differ only
in exit contract: `audit` exits non-zero on drift (CI gate, aggregated by
`task audit`), `diff` always exits 0 and prints the patch. Making `audit`
consume `build/settings.json` removes its inline compose -- a net deletion.

Activation for links and packages is deliberately not rewritten to read
`build/`: `packages:install` already consumes the built Brewfile, and
`links:install` keeps deriving targets from its own vars. The build dir
serves `task diff` and claude activation. This is ponytail'd with the
upgrade path (point `links:install` at `links.map`).

### Operator surface

```
task diff            Preview what task install would change   (new, public)
task packages:diff   \
task links:diff       > per-domain (new, public; the <domain>:<verb> grammar)
task claude:diff     /
```

`diff` joins the six-command lifecycle block in the `default:` banner
(LINT-08 requires it) and the CLAUDE.md operator table.

## Sequencing

Three phases, each independently shippable, in this order:

1. **Test layout.** No behavior change; makes the new test file in Phase 2
   land at its permanent path.
2. **Purity.** Prerequisite for Phase 3: `claude:diff` needs a build
   artifact and a live file that are two distinct paths.
3. **Diff.**

The manifest tier restructure that would have collided with Phase 1 already
landed (v2.5.0), so the fixture surgery risk noted in the previous design is
gone.

## Verification

| Gate | Instrument |
|---|---|
| No behavior change in Phase 1 | `task lint && task test` green before and after each rename |
| Compose semantics | `install/tests/settings-compose.zsh` -- 5 scenarios, written before the two-dir implementation |
| Live settings.json correctness | `jq -S . ~/.config/claude/settings.json` byte-identical to the pre-migration composed output, including `enabledPlugins` and `tui` |
| Repo purity | `git status --short` clean after `task install`; `git ls-files claude/` lists no generated file |
| Diff correctness | break one link (`rm ~/.config/eza/theme.yaml`), confirm `task diff` reports exactly it, repair with `task install`, confirm silence |
| Whole surface | `task lint && task test && task validate && task audit` |

The repo-purity gate is the one that proves the change: `task install`
followed by a clean `git status` is the property that does not hold today.

## Decisions

| Decision | Rationale |
|---|---|
| `claude/settings.json` moves to `build/` rather than staying tracked | It is a generated file in the source tree -- the exact thing the purity rule forbids -- and it dirties the working tree on every `/model` or TUI toggle. Keeping it would leave the daily annoyance in place and keep LINT-09 alive to police it. |
| Live `~/.config/claude/settings.json` becomes a real file, not a symlink into `build/` | A symlink would make build and live the same inode, collapsing `claude:diff` into a comparison of a file with itself. A copy keeps desired and live distinct, which is what makes diff meaningful and makes claude structurally identical to packages. |
| Preserved CLI keys still read from the live file | The Claude CLI writes them there; a capture-to-sidecar step would add a file without removing the read. Impurity acknowledged, bounded, and pointed away from the repo. |
| Build dir under `$XDG_STATE_HOME`, not `$XDG_CACHE_HOME` | It sits beside `machine` and `resolved.json`, the other per-machine desired-state files. Cache-clearing should not silently disable `task diff`. |
| Fixture lint exclusions keyed on `lint-fixtures`, not `tests` | A basename exclusion on `tests` would remove `install/tests/*.zsh` from the LINT-10 scan. The narrower key states the real reason for the exemption. |
| LINT-09 deleted rather than repointed at `build/` | A repo lint should check repo files. Build-vs-live drift is runtime, already covered by `claude:audit` under both `task audit` and `task validate`. |
| Activation still not driven by `links.map` | `links:install` works and is idempotent; rewriting it buys nothing today. Ponytail'd with the upgrade path so the option stays open. |

## Non-goals

- **Generation snapshots / rollback.** Cut by operator decision (2026-07-24)
  and unchanged here: Homebrew is rolling-release and refuses pinning, so
  binaries never roll back regardless; config rollback is already
  `git checkout` + `task install`. The build dir holds exactly what
  `task diff` consumes -- no `meta.json`, no `resolved.json` copy, no
  snapshot directory.
- **`diff` for macos / hostname / identity.** Neither has a build artifact;
  each would need bespoke `defaults read` / `scutil --get` drift logic. That
  is new drift detection, not a diff of the build dir. Revisit if the
  defaults surface grows.
- **`packages:prune` / declared-state enforcement.** `NIXOS-IDEAS.md` item 2;
  independent of this change.
- **Splitting `resolver.zsh`.** 668 lines against the 800 cap. The fracture
  line (declare/validate vs merge/emit) is documented; not needed yet.
- **Per-OS package-name indirection.** `NIXOS-IDEAS.md` item 4; belongs to
  Linux support, which is out of scope repo-wide.
