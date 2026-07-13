# Claude Addons + Settings Composition

Canonical reference for the third-party Claude Code addon system + the
`claude/settings.json` build-artifact composition pipeline. Audience: operators
and AI agents working in this repo. For directory-local quick-reference see
[`manifests/claude-addons/README.md`](../manifests/claude-addons/README.md).
For project rules see [`CLAUDE.md`](../CLAUDE.md).

## Why this exists

`~/.config/claude/settings.json` is the file Claude Code reads at runtime.
Three writers historically fought over it:

1. **The repo.** Hand-edits to `claude/settings.json` (it's symlinked into the
   live config).
2. **Third-party installers.** `npx <something>-cc --claude --global` rewrites
   `settings.json` to register hooks, statusLine entries, etc.
3. **Self-healing hooks.** Once registered, those installed hooks fire on every
   tool call and can re-inject themselves into `settings.json` if removed.

Removing a third-party addon under the old model meant: hunt down its
scattered files in `hooks/`, `agents/`, `skills/`, `commands/`, kill them in
the right order so the hook scripts couldn't re-fire mid-removal, then surgically
strip its entries from `settings.json`. The pain class is documented in
[`CLAUDE.md`](../CLAUDE.md)'s Context section.

The fix is two-part and ships in v1 together:

- **Footprint manifests:** one TOML per known addon declares its install
  command, verify probe, file footprint, and remove commands. Add or remove
  an addon by editing one file + listing it in a machine manifest.
- **Settings.d composition:** `claude/settings.json` is regenerated from
  `claude/settings.d/*.json` fragments + preserved CLI-managed keys. The
  fragments are the source of truth; the live file is a build artifact.
  LINT-09 catches drift.

Together they eliminate the "who-writes-settings.json-last-wins" failure mode.

## Architecture

```
manifests/
  claude-addons/
    <name>.toml           Footprint manifest (required)
    <name>.fragment.json  Optional settings.json fragment template
    README.md             Directory-local quick-reference

claude/
  settings.d/
    00-base.json          Repo-owned: permissions + scalars
    10-hooks.json         Repo-owned: hook wiring
    99-addon-<name>.json  Addon-owned: copy of <name>.fragment.json
                          (written by claude-addons:install)
  settings.json           GENERATED build artifact (lockfile model)

install/
  claude-addons.zsh       Addon lifecycle: install/remove/list/validate

taskfiles/
  claude-addons.yml       Thin dispatcher to install/claude-addons.zsh
  claude.yml              CLI ensure + settings-compose + claude:audit (settings drift)
  lint.yml                LINT-09 drift detection
```

## Schema: `manifests/claude-addons/<name>.toml`

```toml
schema_version = 1

[meta]
name        = "<kebab-case-name>"        # required; matches filename stem
description = "<one-line description>"   # required
upstream    = "<homepage or repo URL>"   # required

[install]
# Sequential bash commands. Run via zsh -c. Must be idempotent.
commands     = ["<cmd>", "..."]           # required
self_healing = false                      # required; see "Self-healing" below

[upgrade]
# Optional. When [verify] already passes, claude-addons:install runs these
# instead of [install].commands so `task install` re-runs pull latest.
commands = ["<cmd>", "..."]

[verify]
# Required: at least one of these. Detects "is this installed?"
path    = "<filesystem path>"             # check file/dir existence
command = "<exit-0 check>"                # OR check via command

[footprint]
# Glob patterns relative to $XDG_CONFIG_HOME/claude/ this addon owns. Empty
# for marketplace-style addons (claude CLI owns ~/.config/claude/plugins/).
file_globs  = ["<glob>", "..."]           # required (may be empty)
# Absolute paths outside $XDG_CONFIG_HOME/claude/. Env vars expanded.
extra_paths = ["<path>", "..."]           # required (may be empty)

[remove]
# Sequential bash commands. Run BEFORE file_globs deletion. Disarm
# self-healing hooks here; run official uninstall for marketplace addons.
commands = ["<cmd>", "..."]               # required (may be empty array)
```

`[remove].settings_strip` from earlier design drafts was **dropped in v1**.
Settings.d composition makes manual key-stripping unnecessary: an addon's
keys live in `99-addon-<name>.json`; the remove task deletes that file and
recomposes. Old TOMLs containing `settings_strip` will silently ignore it.

### Optional paired fragment: `manifests/claude-addons/<name>.fragment.json`

JSON conforming to Claude Code's `settings.json` schema. If present, copied
to `claude/settings.d/99-addon-<name>.json` when the addon enables and
included in compose's deep-merge. Deleted on remove. Marketplace-style
addons that don't write `settings.json` keys directly (ECC) don't need a
fragment; npx-style addons that inject hooks (GSD-redux) do.

To derive a fragment template for a new addon:

```sh
cp claude/settings.json /tmp/before.json
<addon's install command>
diff <(jq -S . /tmp/before.json) <(jq -S . claude/settings.json) | less
# Capture the additions in manifests/claude-addons/<name>.fragment.json,
# then re-compose with the fragment in place to make the diff vanish.
```

## Lifecycle

### `task claude-addons:install`

Wired into `task install` after `task claude:install`. Steps:

1. Read `.claude.addons` from `resolved.json`.
2. For each enabled addon:
   - Run `[verify]` probe.
   - If not installed: run `[install].commands` sequentially.
   - If installed AND `[upgrade].commands` present: run `[upgrade].commands`
     instead (the "always-pull-latest on every `task install`" behavior).
   - If a paired fragment exists, copy it to
     `claude/settings.d/99-addon-<name>.json`.
3. Recompose `claude/settings.json` via `task claude:settings-compose`.

### `task claude-addons:remove -- <name>`

Operator surface for clean removal. Steps:

1. Read `manifests/claude-addons/<name>.toml`.
2. Run `[remove].commands` sequentially (disarm self-healing hooks; official
   uninstall for marketplace addons; etc.).
3. Walk `[footprint].file_globs` under `$XDG_CONFIG_HOME/claude/` with
   `rm -rf`. Path-safety guards reject absolute paths and `../` traversal.
4. Walk `[footprint].extra_paths` (absolute, env-var-expanded) with `rm -rf`.
5. Delete `claude/settings.d/99-addon-<name>.json` if present.
6. Recompose `claude/settings.json`.

After: `task claude-addons:audit` should report no orphan footprints.

### `task claude-addons:show`

Diagnostic table: Name | Enabled (in machine manifest) | Installed (verify
passes) | Description. Read-only.

### `task claude-addons:audit`

Drift detection: for every addon TOML NOT enabled on this machine, walk its
`file_globs` and `extra_paths`. Warn on any orphan paths found. This is the
"installed but not declared" case the user was in before this system existed.

### `task claude:audit`

The settings.json drift check. Runs compose to stdout, diffs against the
committed `claude/settings.json`, exits non-zero on drift. LINT-09 wraps this
and fails `task lint` on drift.

## Settings.d composition algorithm

`task claude:settings-compose` (internal task in `taskfiles/claude.yml`):

1. **Preserve CLI-managed keys.** Read current `claude/settings.json` and
   extract `enabledPlugins` + `extraKnownMarketplaces` (written by
   `claude plugin install` / `claude plugin marketplace add`) plus `model`
   when present (written by the `/model` command); the compose pipeline
   never owns them.
2. **Deep-merge fragments.** Read every `claude/settings.d/*.json` in numeric
   sort order. `jq -s 'reduce .[] as $f ({}; . * $f)'` deep-merges them (same
   `*` operator semantics the resolver uses for TOML; arrays replace, maps
   merge).
3. **Layer preserved keys.** Final `. * preserved` puts CLI-managed keys on
   top.
4. **Atomic write.** `mktemp` + `mv` into `claude/settings.json`. A sanity
   check asserts the composed output has `.permissions and .hooks` before
   the rename to avoid bricking the live config.

Numeric prefixes (`00-`, `10-`, `99-`) drive merge order. Later fragments
override earlier ones on key conflict. The convention is:

- `00-` -- base config (repo-owned)
- `10-` -- repo hook wiring
- `50-` -- reserved for per-machine overrides (none today)
- `99-` -- third-party addon overlays

## Worked examples

### Adding a marketplace-style addon (the superpowers pattern)

Superpowers is installed via the official `claude plugin` CLI; files live
under `~/.config/claude/plugins/` (CLI-managed). The TOML is short: install
registers the marketplace + plugin, verify probes `claude plugin list --json`,
footprint is empty (the CLI owns the plugin directory), remove uninstalls the
plugin. See [`manifests/claude-addons/superpowers.toml`](../manifests/claude-addons/superpowers.toml).

No paired fragment needed -- the plugin doesn't write hook entries into
`settings.json`. Compose preserves `enabledPlugins` and `extraKnownMarketplaces`
from the live file automatically.

### Installer-script addon with cherry-picked hooks (the ECC pattern)

ECC deliberately does NOT use the plugin path: the full ecc@ecc plugin injects
~228 skills, ~60 agents, ~93 commands, and ~29 always-on hooks into every
session, and the plugin mechanism offers no way to trim skills or disable
individual plugin hooks. Instead [`ecc.toml`](../manifests/claude-addons/ecc.toml):

- keeps the ecc *marketplace* registered (the clone is where `install.sh`
  lives; `claude plugin marketplace update ecc` is the upgrade fetch),
- runs `install.sh --target claude --profile minimal --without
  baseline:commands --with baseline:hooks` to copy a trimmed payload into
  `~/.claude/` (upstream hardcodes that target),
- symlinks the payload into `$XDG_CONFIG_HOME/claude/` where Claude Code
  reads it: one flat link per skill (user-scope skill discovery does not
  traverse a nested `skills/ecc/` dir) plus a single `agents/ecc` dir link
  (agent discovery does recurse). The links land in the repo working tree
  via the `claude/` symlink and are appended to `.git/info/exclude`,
- registers ONLY the three session-persistence hooks via the paired
  [`ecc.fragment.json`](../manifests/claude-addons/ecc.fragment.json) --
  per-hook cherry-picking the plugin path cannot do.

**Array-replace caveat:** compose deep-merges with jq `*`, which merges maps
but REPLACES arrays. A fragment that defines `hooks.<Event>` replaces that
event's whole array from earlier fragments. `ecc.fragment.json` defines
`hooks.SessionStart`, so it restates the repo's post-compact entry from
`10-hooks.json`; editing the SessionStart wiring in `10-hooks.json` requires
mirroring the change there. Events a fragment doesn't mention are unaffected.

### Adding an npx-style addon with self-healing hooks

This is a hypothetical worked example -- no machine currently enables an
npx-style addon -- showing how the schema handles one. Such an installer
typically scatters files under `~/.config/claude/{hooks,agents,skills,
commands}/` and rewrites `settings.json`. The TOML captures the scatter via
`file_globs`; the paired fragment captures the settings.json keys.

`manifests/claude-addons/<name>.toml`:

```toml
[install]
commands     = ["npx -y <package>@latest --claude --global"]
self_healing = true

[verify]
path = "~/.config/claude/<marker-dir>"

[footprint]
file_globs = [
  "hooks/<prefix>-*",
  "agents/<prefix>-*.md",
  "skills/<prefix>-*/",
  "commands/<prefix>-*",
]
extra_paths = ["$XDG_STATE_HOME/dotfiles/<name>-installed"]

[remove]
commands = ["rm -f $XDG_CONFIG_HOME/claude/hooks/<prefix>-*"]
```

Plus `manifests/claude-addons/<name>.fragment.json` with the hooks and
statusLine entries the installer writes (derive via the diff recipe above).

To enable on a machine: list `"<name>"` in that machine's `[claude].addons`
array. To remove: `task claude-addons:remove -- <name>`. The
`[remove].commands` disarm the hook scripts before file_globs deletion, then
the fragment is deleted from settings.d, then compose runs.

Note: npx-style addons require Node.js on the machine (for `npx` and any
`node`-based hook commands the installer injects). The repo ships none enabled
by default for exactly that reason.

## Self-healing addons

`[install].self_healing = true` flags an addon whose installer wires hook
entries into `settings.json` that may re-inject themselves on subsequent
tool calls. These addons require:

- A paired `<name>.fragment.json` capturing the keys (so compose preserves
  them while the addon is enabled).
- `[remove].commands` that delete the hook scripts from disk before
  `file_globs` deletion runs. Otherwise a hook firing during the removal
  sequence can re-inject keys faster than compose erases them.

Marketplace addons (ECC) are `self_healing = false` -- their hook entries
live under the CLI-managed plugin directory, not in `settings.json`.

## Troubleshooting

### `task lint` fails with "LINT-09: claude/settings.json drift"

Run `task claude:settings-compose` to regenerate. If the recompose still
shows drift, run `task claude:audit` for the verbose diff. Common causes:

- A third-party tool wrote to `settings.json` directly (the very class
  settings.d is designed to neutralize). Recompose; the change is overwritten.
- You hand-edited `settings.json` expecting changes to stick. Edit the
  matching fragment in `claude/settings.d/` instead.

### `task claude-addons:audit` warns about orphan footprints

An addon's `file_globs` match files on disk but the addon isn't enabled in
the machine manifest. Two possible fixes:

- Enable it: add the name to `[claude].addons` in the machine TOML, then
  `task install`.
- Remove the orphans: `task claude-addons:remove -- <name>`.

### Addon install command fails mid-stream

`claude-addons:install` runs each entry in `[install].commands` sequentially
and aborts on the first non-zero exit. Fix the command (or the addon's
upstream issue), then re-run `task install`. The verify probe ensures
idempotency: already-succeeded steps don't repeat unnecessarily.

### CLI-managed keys (`enabledPlugins`, `extraKnownMarketplaces`) disappeared

Compose preserves these from the existing `claude/settings.json`. If the
live file was deleted before compose ran, those keys reset to empty. Re-run
`task claude-addons:install` for any marketplace-style addon (ECC) to
re-register the marketplace + plugin. The CLI writes the keys back.

### "Unknown addon" error at `task setup` or `task validate`

The machine TOML lists an addon name with no matching
`manifests/claude-addons/<name>.toml`. The resolver enforces this in
`validate_manifest()`. Either create the TOML or remove the name from
`[claude].addons`.

## Cross-references

- [`CLAUDE.md`](../CLAUDE.md) -- project rules; "Rules" section names this
  doc as the canonical reference for settings composition and addons.
- [`manifests/claude-addons/README.md`](../manifests/claude-addons/README.md)
   -- directory-local schema quick-reference.
- [`claude/README.md`](../claude/README.md) -- `claude/` directory orientation
  + symlink/compose shape.
- [`docs/MANIFEST.md`](MANIFEST.md) -- the broader manifest model this system
  extends.
