# Manifest Reference

## What This Is

Manifests are the source of truth for what each machine installs. Two TOML files describe each
machine: `manifests/defaults.toml` (shared baseline) and `manifests/machines/<name>.toml`
(per-machine identity, features, package bundles, and overrides). The resolver
(`install/resolver.zsh`) compiles them into a JSON file at
`$XDG_STATE_HOME/dotfiles/resolved.json`. Every go-task task reads that JSON via
`fromJson` -- no task reads TOML directly.

## Schema (v1)

### `defaults.toml` and `machines/<name>.toml` shape

**`manifests/defaults.toml`** -- shared baseline every machine inherits:

```toml
schema_version = 1

[meta]
description = "default -- machine must override"

[platform]
# Only "darwin" is accepted.
os = "darwin"

[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in a later phase.
# Conservative defaults (mostly off). kebab-case keys MUST be accessed via
# {{index .MANIFEST.features "name"}} in taskfiles (Go-template parser rejects "-" in dot-access).
one-password-ssh = false
claude-marketplace = true

[packages.brew]
# Bundle names map to manifests/bundles/<name>.toml.
bundles = ["dotfiles"]
# Additive escape hatch -- resolver computes the dedupe union of defaults plus machine extras.
extra_packages = []

[identity]
# Allowed: "personal" | "work" | "none". Drives Phase 4 git+SSH identity selection.
git = "none"
ssh = "none"
```

**`manifests/machines/personal-laptop.toml`** -- a concrete machine manifest:

```toml
schema_version = 1

[meta]
description = "Josh's personal MacBook -- Apple Silicon, primary dev machine"

[platform]
os = "darwin"
arch = "arm64"   # optional; resolver auto-detects via uname -m when absent

[features]
one-password-ssh = true       # required because identity.ssh is "personal"
one-password-signing = true   # required because identity.git is "personal"
macos-dock = true
macos-finder = true
macos-input = true
macos-spotlight = true
macos-screenshots = true
macos-security = true
macos-appearance = true
macos-display = true
claude-marketplace = true
ghostty = true
jgrid-net = true

[packages.brew]
bundles = ["dotfiles", "cli", "dotfiles-gui", "dev", "productivity", "apps"]

[packages.brew.extra_packages]
# node: the ecc Claude addon's hooks invoke the `node` binary directly.
formulae = ["node"]
casks = [
  { name = "cloudflare-warp" },
  { name = "discord" },
  { name = "dropbox" },
  { name = "nvidia-geforce-now" },
  { name = "proton-drive" },
  { name = "proton-mail" },
  { name = "protonvpn" },
  { name = "whatsapp" },
]
mas = []

[identity]
git = "personal"
ssh = "personal"

[claude]
# Full replace (not concat-with-defaults); addons are opted in per-machine.
addons = ["ecc", "superpowers"]
```

### Required fields

Every `manifests/machines/<name>.toml` must explicitly declare each of the following fields.
The validator rejects the manifest if any is missing or empty, even if `defaults.toml` would
supply a value -- silent inheritance of required fields is the drift class being guarded against.

| Field | Type | Allowed values | Notes |
|-------|------|---------------|-------|
| `schema_version` | integer | `1` | Must equal `1`; the resolver rejects a missing or mismatched value |
| `meta.description` | string | any | Free-text purpose statement for the machine |
| `platform.os` | string | `"darwin"` | macOS only |
| `features` | table | any key-value pairs | May be empty `{}`; each key is kebab-case |
| `packages.brew.bundles` | array of strings | non-empty; must include `"dotfiles"` | Each name N must have a `manifests/bundles/N.toml` file; the resolver folds its `[packages.brew]` typed buckets (formulae/casks/mas) into the resolved extras |
| `identity.git` | string | basename of a file under `identity/git/identities/` | Drives Phase 4 git config selection; resolver rejects names with no overlay file |
| `identity.ssh` | string | basename of a file under `identity/ssh/identities/` | Drives Phase 4 SSH config selection; resolver rejects names with no overlay file |

### Optional fields

| Field | Type | Notes |
|-------|------|-------|
| `meta.notes` | string | Freeform annotation; no semantic effect |
| `platform.arch` | string | `"arm64"` or `"x86_64"`; resolver auto-detects via `uname -m` when absent |
| `packages.brew.extra_packages.formulae` | array of strings or `{name, verify}` objects | Per-machine formula extras; concat+dedupe across defaults + machine |
| `packages.brew.extra_packages.casks` | array of `{name}` objects | Per-machine cask extras; the legacy `verify` field is optional and ignored post-Gap-2 pivot (see ## Verify model) |
| `packages.brew.extra_packages.mas` | array of `{id, name}` objects | Per-machine MAS app extras; `name` doubles as the `.app` verify name |
| `packages.vscode.extensions` | array of strings | VSCode extension ids (`publisher.name`); union across defaults + bundles + machine, deduped by value |
| `packages.cargo.crates` | array of strings | Rust crates (`cargo install`); same union/dedupe as `vscode.extensions` |
| `packages.uv.tools` | array of strings | Python tools (`uv tool install`); same union/dedupe |
| `packages.npm.packages` | array of strings | Global npm packages (`npm install -g`); same union/dedupe (requires the `npm`/`node` CLI) |

### Non-brew package managers

`packages.vscode`/`cargo`/`uv`/`npm` are sibling typed buckets to
`packages.brew`, exposing the non-brew entry types that `brew bundle` gained in
Homebrew 6.0. Each holds a bare-string array
(`extensions`/`crates`/`tools`/`packages`). Unlike
the brew buckets -- whose bundle files use `[packages.brew]` while
defaults/machine files use `[packages.brew.extra_packages]` -- these use the
SAME path everywhere: `[packages.vscode] extensions = [...]` in `defaults.toml`,
any `manifests/bundles/<b>.toml`, or any `manifests/machines/<name>.toml`.

The resolver unions all three sources (`jq -s 'add | unique'`) into
`resolved.json`; the composer emits them into the same per-machine Brewfile as
`vscode '<id>'` / `cargo '<name>'` / `uv '<name>'` / `npm '<name>'` lines (after
casks/mas, so a providing cask like `visual-studio-code` installs first).
`brew bundle install` installs them and `brew bundle check` (Layer 1 of
`packages:verify`) verifies declared-but-missing entries -- no separate install
path. `task audit` drift-checks the reverse direction (installed-but-undeclared)
via each manager's list command: `code --list-extensions`,
`cargo install --list`, `uv tool list`, `npm ls -g` (the node-shipped `npm` and
`corepack` globals are excluded from drift).

Gating is by bundle inclusion: extensions declared in `bundles/dev.toml` reach
only machines that list `dev` in `packages.brew.bundles`. npm entries require
the `npm`/`node` CLI; declare them only on machines whose bundles supply node
(e.g. the `node` formula on `personal-laptop`). `pipx` and `go install` are out
of scope -- `pipx` is not a `brew bundle` entry type, and `go` was dropped (low
usage; its installed-package set has no reliable list command to audit drift).

### Unknown keys

Unknown keys produce a warning to stderr but do not fail validation (exit 0). This permits
forward compatibility -- a key added for a future phase does not break current validation.

Warning format: `unknown key: features.macos-dok at manifests/machines/personal-laptop.toml:14`

## Merge Semantics

The resolver applies a two-step merge: first a recursive deep-merge, then a special-case
concatenation for `extra_packages`.

### Rules

| What | Rule |
|------|------|
| Tables (maps) | Deep-merge -- machine wins on conflict; sibling keys from defaults are preserved |
| Scalars | Machine value replaces defaults value |
| Arrays | Machine value replaces defaults value wholesale (see rationale below) |
| `packages.brew.extra_packages` | Special case: deduplicated union of defaults and machine arrays |

### Worked examples

#### Fixture 01 -- map-over-map (deep-merge preserves siblings)

`defaults.toml`:
```toml
[features]
claude-marketplace = true
one-password-signing = false
```

`machine.toml`:
```toml
[features]
one-password-ssh = true
macos-dock = true
```

`resolved.json`:
```json
{
  "features": {
    "claude-marketplace": true,
    "one-password-signing": false,
    "one-password-ssh": true,
    "macos-dock": true
  }
}
```

Rule: when both sides define keys in the same table, the resolved output contains all keys --
machine keys win on conflict; defaults keys with no machine counterpart are preserved.

#### Fixture 02 -- list-replace (arrays replaced wholesale)

`defaults.toml`:
```toml
[packages.brew]
bundles = ["core"]
```

`machine.toml`:
```toml
[packages.brew]
bundles = ["core", "gui"]
```

`resolved.json`:
```json
{
  "packages": {
    "brew": {
      "bundles": ["core", "gui"]
    }
  }
}
```

Rule: the machine's `bundles` array completely replaces the defaults array. The defaults
value `["core"]` does not appear alongside the machine value.

#### Fixture 03 -- scalar-override (machine replaces defaults)

`defaults.toml`:
```toml
[meta]
description = "default"
```

`machine.toml`:
```toml
[meta]
description = "personal-laptop"
```

`resolved.json`:
```json
{
  "meta": {
    "description": "personal-laptop"
  }
}
```

Rule: machine scalar wins unconditionally. There is no "merge" for scalar values.

#### Fixture 04 -- nested-table (deep-merge at arbitrary depth)

`defaults.toml`:
```toml
[a.b.c.d]
shared = "defaults-value"
default_only = true

[a.b.c.d.e]
deep_nested = true
```

`machine.toml`:
```toml
[a.b.c.d]
shared = "machine-value"
machine_only = true

[a.b.c.d.e]
deep_nested_override = "yes"

[a.b.c.d.f]
totally_new = true
```

`resolved.json`:
```json
{
  "a": {
    "b": {
      "c": {
        "d": {
          "shared": "machine-value",
          "default_only": true,
          "machine_only": true,
          "e": {
            "deep_nested": true,
            "deep_nested_override": "yes"
          },
          "f": {
            "totally_new": true
          }
        }
      }
    }
  }
}
```

Rule: deep-merge is recursive to arbitrary depth. At each level, machine keys win on
conflict while defaults keys with no machine counterpart are preserved.

#### Fixture 05 -- missing-keys (both sides preserved)

`defaults.toml`:
```toml
[only_in_defaults]
key = "value"
```

`machine.toml`:
```toml
[only_in_machine]
key = "value"
```

`resolved.json`:
```json
{
  "only_in_defaults": {
    "key": "value"
  },
  "only_in_machine": {
    "key": "value"
  }
}
```

Rule: a key present only in defaults and a key present only in the machine both appear in
the resolved output -- neither side's unique keys are dropped.

#### Example -- extra-packages-concat (per-sub-array additive union)

This behavior has no numbered `06` fixture; it is exercised by the typed-bucket
fixtures (`typed-02-formulae-dedup`, `typed-03-casks-mas-dedup`,
`typed-04-vscode-union`). The worked example below is illustrative.

`defaults.toml`:
```toml
[packages.brew.extra_packages]
formulae = ["jq", "yq"]
casks = []
mas = []
```

`machine.toml`:
```toml
[packages.brew.extra_packages]
formulae = [{ name = "ripgrep" }]
casks = [{ name = "docker-desktop" }]
```

`resolved.json`:
```json
{
  "packages": {
    "brew": {
      "extra_packages": {
        "formulae": ["jq", "yq", { "name": "ripgrep" }],
        "casks": [{ "name": "docker-desktop" }],
        "mas": []
      }
    }
  }
}
```

Rule: `extra_packages` is the single exception to the array-replace rule, applied
per-sub-array. Each typed sub-array (`formulae`, `casks`, `mas`) is independently
concat+deduped with the corresponding defaults sub-array. Bare strings and
`{name}` objects coexist in `formulae`; `casks` and `mas` always carry typed
objects. In this example, `casks` is the machine's value because defaults
declared `casks = []`; `mas` resolves to `[]` because both sides are empty.

Per-sub-array union semantics replace the legacy flat-array union. The resolver
keeps backward-compat with the legacy flat-array shape so existing fixtures
continue to pass.

### Why arrays replace (not concatenate)

Predictability. A machine that wants exactly `["core"]` in `bundles` must not be silently
extended by defaults `["core", "dev"]`. Wholesale replacement gives the machine file full
authority over every array field.

`extra_packages` is the intentional escape hatch for the additive case -- explicitly
concatenated so a machine can add one-off packages without forking a bundle file.

## Verify model

`task packages:verify` uses a two-layer approach to confirm every declared package is
correctly installed after `task packages:install` runs.

**Layer 1 -- bundle presence check.** `brew bundle check --no-upgrade --file="$XDG_CACHE_HOME/dotfiles/Brewfile"`
confirms every package declared in the composed Brewfile is installed per Homebrew's view of
the world. This is the same check the `packages:install` status block exercises; it runs
sub-second on a converged machine.

**Layer 2 -- artifact-path probe.** `brew info --installed --json=v2` returns the full set of
installed formulae and installed casks with their artifact paths. `task packages:verify`
parses `.casks[].artifacts[]` for the appropriate artifact path entries and asserts each
declared artifact path actually exists on disk. For formulae, the bin-path entries in the
formula JSON confirm the binary is present.

This replaces the v1 per-line annotation approach (the `# verify: <bin>` bundle comment and
the `verify` field on cask objects in machine TOML extras). Those annotations went stale on
every upstream cask rename -- for example, `nvidia-geforce-now` installs `GeForceNOW.app`
not `NVIDIA GeForce NOW.app`; `protonvpn` installs `Proton VPN.app`; `miniconda` is a
binary-only cask with no `.app` artifact at all. The `brew info --installed --json=v2` bulk
call is authoritative (~200ms for the full installed set), never goes stale, and removes the
per-entry authorship cost entirely.

**MAS exception.** Apple App Store apps have no `brew info` equivalent. The `name` field in
each `{ id, name }` object doubles as both the install-list display name (drives `mas install
<id>` UX) and the verify target (`/Applications/<name>.app` existence check). This is the one
place per-entry verify metadata is still authored in v2, because Apple does not expose an
authoritative artifacts list the way Homebrew does.

The task body lives in `taskfiles/packages.yml :: packages:verify` (rewritten in Plan 05-08).
See that task for the implementation details.

## Adding a New Machine

1. Choose a kebab-case name (e.g., `atium`, `work-laptop`). Machine names must match
   the regex `^[a-z0-9_][a-z0-9_-]*$` (a leading underscore is reserved for the
   `_invalid-*` / `_warn-*` test fixtures; real machines start with a letter or digit).

2. Create `manifests/machines/<name>.toml`. Copy an existing machine file as a starting
   point and edit the values. Keep the same field structure.

3. Declare all required fields (see the Required fields table above). The validator rejects
   the manifest if any required field is absent.

4. Validate the schema:

   ```zsh
   task manifest:audit -- --machine <name>
   ```

5. Persist the selection and regenerate `resolved.json`:

   ```zsh
   task setup -- <name>
   ```

   This verifies the file exists, writes `$XDG_STATE_HOME/dotfiles/machine`, and
   regenerates `resolved.json`.

6. Inspect the resolved output:

   ```zsh
   task manifest:show
   ```

7. (Optional) Apply the install:

   ```zsh
   task install
   ```

## Adding a New Identity

Identities are filesystem-driven: the valid set for `identity.git` and `identity.ssh`
is the basenames of files under `identity/git/identities/` and
`identity/ssh/identities/`. No enum to update; the resolver and `taskfiles/identity.yml`
discover identities at evaluation time.

1. Drop a git overlay at `identity/git/identities/<name>` (gitconfig include
   fragment — see existing files for shape).

2. Drop an SSH overlay at `identity/ssh/identities/<name>` (Host blocks — see
   existing files for shape).

3. If the identity carries its own SSH key (not 1Password-managed), drop the
   public key at `identity/ssh/keys/<name>.pub`. Private keys never go in the repo.

4. For a **headless server** identity, set `features.server-include = true` on
   the machine manifest that uses it. The `server-include.config` is then
   materialized at install time with an unconditional `[includeIf "gitdir:~/"]`
   block, so the identity loads from `$HOME` directly.

5. For a **workstation** identity, add an `[includeIf "gitdir/i:~/git/<name>/"]`
   block to `identity/git/config` so the gitconfig overlay loads when working
   inside `~/git/<name>/`. This is the one manual step that's not yet automated;
   if you skip it, the symlink still materializes but `validate:git` will report
   no repo found.

6. Reference the new identity from a machine manifest:

   ```toml
   [identity]
   git = "<name>"
   ssh = "<name>"
   ```

7. Validate: `task manifest:audit -- --machine <machine>`.
   A typo in `<name>` is rejected with an error naming the missing overlay file.

## CLI Reference

| Command | Description |
|---------|-------------|
| `task setup -- <name>` | Persist machine selection; runs validate and resolve |
| `task manifest:show [-- --machine <name>]` | Print resolved manifest (active machine by default) |
| `task manifest:audit [-- --machine <name>]` | Schema check -- required fields + unknown-key warnings |
| `task test:manifest` | Run the golden-output fixture tests (deep-merge `01`-`05` plus the `typed-*` bucket fixtures) |

## State Files

| File | Description |
|------|-------------|
| `$XDG_STATE_HOME/dotfiles/machine` | Single-line text file with the active machine name; written by `task setup` |
| `$XDG_STATE_HOME/dotfiles/resolved.json` | Compiled JSON; rebuilt by `manifest:resolve` when any source TOML is newer |

Both files are machine-local and are not committed to the repository.

## Feature-Flag Reference

The feature flags -- their names, per-flag descriptions, and defaults -- are
declared inline under `[features]` in `manifests/defaults.toml`. That file is
the single source of truth; this doc deliberately does not duplicate the list
(the old hand-maintained table drifted out of sync with the declared flags).

To access any of these in a taskfile, use `{{index .MANIFEST.features "feature-name"}}`.
Do not use dot-access (`{{.MANIFEST.features.one-password-ssh}}`) -- Go-template parsing
rejects the `-` character in identifiers.

## Known Limitations (v1)

- Line numbers in unknown-key warnings may be imprecise for deeply nested keys.
- The rename flow is manual: rename the TOML file and edit `$XDG_STATE_HOME/dotfiles/machine`
  by hand.
- No JSON Schema file for editor validation.
