# Manifest Reference

## What This Is

A machine's install state is described by one self-contained TOML file,
`manifests/machines/<name>.toml`. The valid feature-flag vocabulary lives in a
registry, `manifests/features.toml`. Package bundles live under
`manifests/bundles/`. The resolver (`install/resolver.zsh`) validates a machine
against the registry and the bundle set, then compiles it into
`$XDG_STATE_HOME/dotfiles/resolved.json`. Every go-task task reads that JSON via
`fromJson` -- no task reads TOML directly.

There is no shared defaults file and no inheritance: a machine manifest declares
everything it wants on its own terms.

## Schema (v2)

### Machine manifest shape

```toml
schema_version = 2

[machine]
description = "Josh's personal MacBook -- Apple Silicon, primary dev machine"
os = "darwin"           # "darwin" | "linux"
arch = "arm64"          # optional: "arm64" | "x86_64"; resolver backfills via uname -m
identity = "personal"   # basename of overlay files under identity/{git,ssh}/identities/

[features]
# Two arrays that together account for every registry flag applicable to this
# machine's os. A flag whose registry `platforms` excludes this os is
# inapplicable and appears in neither list.
enabled = [
  "one-password-ssh",
  "repo-auto-update",
  "ghostty",
  # ...
]
disabled = [
  "server-include",
]

[packages]
# One table for every package manager. Bare strings everywhere except mas.
bundles = [                 # bundle names -> manifests/bundles/<name>.toml
  "dotfiles",
  "cli",
]
formulae = ["node"]         # one-off brew formulae for this machine
casks = ["discord"]         # bare cask names
mas = [                     # Mac App Store: { id = <number>, name = "..." }
  { id = 441258766, name = "Magnet" },
]
vscode = []                 # extension ids ("publisher.name")
cargo = []                  # crate names
uv = []                     # uv tool names
npm = []                    # global npm package names

[claude]
addons = ["ecc"]            # each -> manifests/claude-addons/<name>.toml
```

### Feature registry (`manifests/features.toml`)

Every valid flag is declared once:

```toml
[repo-auto-update]
description = "fast-forward the dotfiles repo from its remote before install"

[macos-dock]
description = "gate os/defaults/dock.zsh and macos:defaults:dock"
platforms = ["darwin"]      # optional; when present the flag applies only on these os
```

A machine that names a flag absent from this registry is rejected. A flag with
no `platforms` applies on every os.

### Bundle shape (`manifests/bundles/<name>.toml`)

Bundles use the same `[packages]` table as machines (minus `bundles`):

```toml
[packages]
formulae = [
  "bat",
  "fd",
]
casks = [
  "firefox",
]
mas = []
vscode = []
```

### Required fields

Every `manifests/machines/<name>.toml` must declare each of the following; the
validator rejects the manifest if any is missing or empty.

| Field | Type | Allowed values | Notes |
|-------|------|---------------|-------|
| `schema_version` | integer | `2` | Must equal `2` |
| `machine.description` | string | any | Free-text purpose statement |
| `machine.os` | string | `"darwin"` \| `"linux"` | v1 targets darwin; linux is accepted by the schema |
| `machine.identity` | string | basename of a file under both `identity/git/identities/` and `identity/ssh/identities/` | Drives git + SSH identity selection |
| `features.enabled` / `features.disabled` | arrays of strings | registry flag names | Must partition the applicable registry flags (see Feature accounting) |
| `packages.bundles` | array of strings | non-empty; must include `"dotfiles"` | Each name N must have `manifests/bundles/N.toml` |

### Optional fields

| Field | Type | Notes |
|-------|------|-------|
| `machine.arch` | string | `"arm64"` or `"x86_64"`; resolver backfills via `uname -m` when absent |
| `packages.formulae` / `casks` / `vscode` / `cargo` / `uv` / `npm` | arrays of strings | Per-machine one-off packages; unioned with the included bundles |
| `packages.mas` | array of `{ id, name }` objects | `id` must be an integer; `name` doubles as the `.app` verify name |
| `claude.addons` | array of strings | Each name must have `manifests/claude-addons/<name>.toml` |

## Feature accounting

`features.enabled` and `features.disabled` must, together, list exactly the
registry flags applicable to the machine's `os`:

- A flag whose `platforms` includes the machine's os (or has no `platforms`) is
  **applicable** and must appear in exactly one of the two lists.
- A flag whose `platforms` excludes the machine's os is **inapplicable** and
  must appear in **neither** list (it cannot be turned on, and listing it in
  `disabled` would falsely claim the machine deliberately lacks something it
  structurally cannot have).

Each of these is a hard error at `task setup`:

- a name in `enabled` or `disabled` that is not in the registry;
- a name in both lists, or duplicated within a list;
- an applicable flag in neither list (the error names the flag and both
  remedies);
- an inapplicable flag listed in either list.

The effect: adding a flag to the registry forces an explicit on/off decision on
every machine at its next `setup`. A flag can never be silently off.

`task features:show` prints the registry joined with the active machine's
resolved state -- one line per flag (on/off + description).

## Identity and 1Password capability sentinels

`machine.identity` is a single name; the resolver expands it to both git and SSH
identity selection. The valid set is filesystem-driven: the basenames of files
under `identity/git/identities/` and `identity/ssh/identities/` (they pair 1:1).

An identity overlay may declare a capability with a sentinel comment:

- `# capability: one-password-ssh` in the ssh overlay -> the machine must
  `enable` `one-password-ssh`.
- `# capability: one-password-signing` in the git overlay -> the machine must
  `enable` `one-password-signing`.

The resolver greps for those exact sentinels; a machine using a
capability-declaring identity without the matching feature is rejected at
`task setup`.

## Package resolution

The resolver unions each `[packages]` bucket across the included bundles (in
declared order) and the machine's inline entries, then dedupes:

- `formulae`, `casks`, `vscode`, `cargo`, `uv`, `npm`: bare-string values,
  deduplicated (sorted); a name declared in several sources collapses to one.
- `mas`: deduplicated by `id`; the machine's entry wins over a bundle's on a
  collision.

Casks are authored as bare strings and emitted as `{ name }` objects in the
compiled output (the composer reads `.name`).

The `dotfiles` bundle is mandatory (every machine includes it) -- it carries the
core toolchain, so no machine has to re-list it.

## Compiled output (`resolved.json`)

The resolver emits a stable JSON contract consumed by every taskfile. Package
paths in the compiled artifact are `packages.brew.{formulae,casks,mas}` and
`packages.{vscode,cargo,uv,npm}`, each holding the resolved union of every
selected bundle plus the machine's inline entries; `packages.brew.bundles` is
the selection trace. `features` is materialized as a boolean map over the full
registry (enabled -> true, everything else -> false). `schema_version` is not
part of the compiled output.

## Array style

Multi-element arrays in `manifests/**/*.toml` are written one element per line
(trailing comma allowed). Empty and single-element arrays may stay inline. This
is enforced by LINT-13.

## Adding a New Machine

1. Choose a kebab-case name matching `^[a-z0-9_][a-z0-9_-]*$` (a leading
   underscore is reserved for test fixtures; real machines start with a letter
   or digit).

2. Create `manifests/machines/<name>.toml`. Copy an existing machine file and
   edit the values; keep the same field structure. Account for every registry
   flag in `enabled` or `disabled`.

3. Validate the schema:

   ```zsh
   task manifest:audit -- --machine <name>
   ```

4. Persist the selection and regenerate `resolved.json`:

   ```zsh
   task setup -- <name>
   ```

5. Inspect the resolved output and the feature state:

   ```zsh
   task manifest:show
   task features:show
   ```

6. (Optional) Apply the install:

   ```zsh
   task install
   ```

## Adding a New Feature Flag

1. Add a `[<flag>]` block to `manifests/features.toml` with a `description` and
   optional `platforms`.

2. Account for the new flag in every machine manifest (`enabled` or `disabled`);
   `task setup` on each machine reports an unaccounted flag until you do.

3. Add the consuming task or asset that gates on the flag. In taskfiles, access
   it via `{{index .MANIFEST.features "<flag>"}}` (kebab-case keys require the
   `index` form; see the LINT-11 note in `CLAUDE.md`).

## Adding a New Identity

Identities are filesystem-driven: the valid set for `machine.identity` is the
basenames of files under `identity/git/identities/` and
`identity/ssh/identities/`.

1. Drop a git overlay at `identity/git/identities/<name>` (gitconfig include
   fragment).

2. Drop an SSH overlay at `identity/ssh/identities/<name>` (Host blocks).

3. If the identity requires 1Password SSH or signing, add the matching
   `# capability: one-password-ssh` / `# capability: one-password-signing`
   sentinel comment to the ssh / git overlay so the resolver enforces the
   feature is enabled.

4. If the identity carries its own SSH key (not 1Password-managed), drop the
   public key at `identity/ssh/keys/<name>.pub`. Private keys never go in the repo.

5. Reference the new identity from a machine manifest:

   ```toml
   [machine]
   identity = "<name>"
   ```

6. Validate: `task manifest:audit -- --machine <machine>`. A typo is rejected
   with an error naming the missing overlay file.

## CLI Reference

| Command | Description |
|---------|-------------|
| `task setup -- <name>` | Persist machine selection; runs validate and resolve |
| `task manifest:show [-- --machine <name>]` | Print resolved manifest (active machine by default) |
| `task manifest:audit [-- --machine <name>]` | Schema check -- required fields, feature accounting, unknown keys |
| `task features:show` | Feature flags (on/off + description) for the active machine |
| `task test` | Run the smoke tests, including the manifest fixture suite |

## State Files

| File | Description |
|------|-------------|
| `$XDG_STATE_HOME/dotfiles/machine` | Single-line text file with the active machine name; written by `task setup` |
| `$XDG_STATE_HOME/dotfiles/resolved.json` | Compiled JSON; rebuilt by `manifest:resolve` when any source TOML is newer |

Both files are machine-local and are not committed to the repository.
