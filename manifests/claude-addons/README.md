# manifests/claude-addons/

Footprint manifests for third-party Claude Code addons. One TOML per known
addon. The machine manifest's `[claude].addons` array selects which TOMLs
are enabled on each machine.

**Canonical reference:** [`docs/CLAUDE-ADDONS.md`](../../docs/CLAUDE-ADDONS.md)
has the full schema, lifecycle, settings.d composition algorithm, worked
examples, and troubleshooting. This README is the directory-local
quick-reference.

## Layout

| File | Purpose |
|------|---------|
| `<name>.toml` | Required. The addon's footprint manifest (schema below). |
| `<name>.fragment.json` | Optional. Settings.json fragment template; copied to `claude/settings.d/99-addon-<name>.json` on enable. |
| `README.md` | This file. |

Kebab-case filenames; `<name>` matches `[meta].name` inside the TOML.

## Schema (one page)

```toml
schema_version = 1

[meta]
name        = "<kebab-case-name>"        # matches the filename stem
description = "<one-line description>"
upstream    = "<homepage or repo URL>"

[install]
commands     = ["<shell command>", "..."]   # run in order; idempotent
self_healing = false                        # true if addon writes hook entries
                                            # into settings.json that re-inject

[upgrade]                                  # optional; omit if upgrade == install
commands = ["<shell command>", "..."]

[verify]                                   # at least one of:
path    = "<filesystem path>"               # detect via file existence
command = "<exit-0 check>"                  # OR detect via command exit code

[footprint]
file_globs  = ["<glob relative to ~/.config/claude/>", "..."]
extra_paths = ["<absolute path>", "..."]

[remove]
commands = ["<shell command>", "..."]      # run BEFORE file_globs deletion
```

**Removed in v1:** `[remove].settings_strip` -- settings.d composition makes
manual key stripping unnecessary; addon-injected keys live in the paired
`<name>.fragment.json` and disappear when the addon is removed.

## Two reference cases

- [`ecc.toml`](ecc.toml) -- marketplace-style addon. Installed via
  `claude plugin install ecc@ecc`. Empty `file_globs` (claude CLI owns the
  plugin footprint). No paired fragment (CLI manages `enabledPlugins`).
  **Enabled on `personal-laptop` only.**

- [`superpowers.toml`](superpowers.toml) -- marketplace-style addon from the
  official Anthropic marketplace (`anthropics/claude-plugins-official`).
  Installed via `claude plugin install superpowers@claude-plugins-official`.
  Empty `file_globs`, no paired fragment. `[remove]` uninstalls the plugin but
  leaves the shared official marketplace registered. **Enabled on
  `personal-laptop` only.**

## Adding a new addon

1. Create `manifests/claude-addons/<name>.toml` with the schema above.
2. If the addon injects settings.json keys at install time, create
   `manifests/claude-addons/<name>.fragment.json` capturing those keys
   (derive by `diff`ing settings.json before/after a manual install in a
   sandbox).
3. List the name in the target machine's manifest:
   `[claude] addons = ["ecc", "<name>"]`.
4. Run `task setup -- <machine>` to refresh the resolved manifest.
5. Run `task install` (or `task claude-addons:install`).
6. Verify: `task claude-addons:show` shows the addon as Installed.

See [`docs/CLAUDE-ADDONS.md`](../../docs/CLAUDE-ADDONS.md) for the full
procedure including how to derive the fragment template safely.

## Removing an addon

```
task claude-addons:remove -- <name>
```

The task runs `[remove].commands`, walks `[footprint].file_globs` +
`[footprint].extra_paths` with `rm -rf`, deletes the addon's
`claude/settings.d/99-addon-<name>.json` if present, and recomposes
`claude/settings.json`. Self-healing hooks cannot survive -- the fragment
is the source of truth.

To re-enable later: re-add the name to the machine manifest and
`task install`.
