# Manifest Reference

## What This Is

Manifests are the source of truth for what each machine installs. Two TOML files describe each
machine: `manifests/defaults.toml` (shared baseline) and `manifests/machines/<name>.toml`
(per-machine identity, features, package bundles, and overrides). The resolver
(`install/resolver.zsh`) compiles them into a JSON file at
`$XDG_STATE_HOME/dotfiles/resolved.json`. Every go-task task reads that JSON via
`fromJson` — no task reads TOML directly.

## Schema (v1)

### `defaults.toml` and `machines/<name>.toml` shape

**`manifests/defaults.toml`** — shared baseline every machine inherits:

```toml
schema_version = 1

[meta]
description = "default -- machine must override"

[platform]
# v1 accepts only "darwin"; v2 will open the rule to "linux" as well.
os = "darwin"

[features]
# Opt-in feature flags. Each is consumed by exactly one task or asset in a later phase.
# Conservative defaults (mostly off). kebab-case keys MUST be accessed via
# {{index .MANIFEST.features "name"}} in taskfiles (Go-template parser rejects "-" in dot-access).
one-password-ssh = false
motd = true
claude-marketplace = true

[packages.brew]
# Bundle names map to packages/<name>.rb (Phase 5).
bundles = ["core"]
# Additive escape hatch -- resolver computes the dedupe union of defaults plus machine extras.
extra_packages = []

[identity]
# Allowed: "personal" | "work" | "none". Drives Phase 4 git+SSH identity selection.
git = "none"
ssh = "none"
```

**`manifests/machines/personal-laptop.toml`** — a concrete machine manifest:

```toml
schema_version = 1

[meta]
description = "Josh's personal MacBook -- Apple Silicon, primary dev machine"

[platform]
os = "darwin"
arch = "arm64"   # optional; resolver auto-detects via uname -m when absent

[features]
one-password-ssh = true
macos-dock = true
macos-finder = true
macos-input = true
macos-screenshots = true
macos-security = true
motd = true
claude-marketplace = true

[packages.brew]
bundles = ["core", "gui", "dev", "personal"]
extra_packages = ["docker-desktop"]

[identity]
git = "personal"
ssh = "personal"
```

### Required fields

Every `manifests/machines/<name>.toml` must explicitly declare each of the following fields.
The validator rejects the manifest if any is missing or empty, even if `defaults.toml` would
supply a value — silent inheritance of required fields is the drift class being guarded against.

| Field | Type | Allowed values | Notes |
|-------|------|---------------|-------|
| `meta.description` | string | any | Free-text purpose statement for the machine |
| `platform.os` | string | `"darwin"` | v1 only; v2 will add `"linux"` |
| `features` | table | any key-value pairs | May be empty `{}`; each key is kebab-case |
| `packages.brew.bundles` | array of strings | non-empty; must include `"core"` | Maps to `packages/<name>.rb` files (Phase 5) |
| `identity.git` | string | `"personal"` \| `"work"` \| `"server-1"` \| `"server-2"` \| `"none"` | Drives Phase 4 git config selection |
| `identity.ssh` | string | `"personal"` \| `"work"` \| `"server-1"` \| `"server-2"` \| `"none"` | Drives Phase 4 SSH config selection |

### Optional fields

| Field | Type | Notes |
|-------|------|-------|
| `meta.notes` | string | Freeform annotation; no semantic effect |
| `platform.arch` | string | `"arm64"` or `"x86_64"`; resolver auto-detects via `uname -m` when absent |
| `packages.brew.extra_packages` | array of strings | Additive escape hatch; deduplicated union with defaults value |

### Unknown keys

Unknown keys produce a warning to stderr but do not fail validation (exit 0). This permits
forward compatibility — a key added for a future phase does not break current validation.

Warning format: `unknown key: features.macos-dok at manifests/machines/personal-laptop.toml:14`

## Merge Semantics

The resolver applies a two-step merge: first a recursive deep-merge, then a special-case
concatenation for `extra_packages`.

### Rules

| What | Rule |
|------|------|
| Tables (maps) | Deep-merge — machine wins on conflict; sibling keys from defaults are preserved |
| Scalars | Machine value replaces defaults value |
| Arrays | Machine value replaces defaults value wholesale (see rationale below) |
| `packages.brew.extra_packages` | Special case: deduplicated union of defaults and machine arrays |

### Worked examples

#### Fixture 01 — map-over-map (deep-merge preserves siblings)

`defaults.toml`:
```toml
[features]
motd = true
claude-marketplace = true
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
    "motd": true,
    "claude-marketplace": true,
    "one-password-ssh": true,
    "macos-dock": true
  }
}
```

Rule: when both sides define keys in the same table, the resolved output contains all keys —
machine keys win on conflict; defaults keys with no machine counterpart are preserved.

#### Fixture 02 — list-replace (arrays replaced wholesale)

`defaults.toml`:
```toml
[packages.brew]
bundles = ["core"]
```

`machine.toml`:
```toml
[packages.brew]
bundles = ["core", "gui", "dev", "personal"]
```

`resolved.json`:
```json
{
  "packages": {
    "brew": {
      "bundles": ["core", "gui", "dev", "personal"]
    }
  }
}
```

Rule: the machine's `bundles` array completely replaces the defaults array. The defaults
value `["core"]` does not appear alongside the machine value.

#### Fixture 03 — scalar-override (machine replaces defaults)

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

#### Fixture 04 — nested-table (deep-merge at arbitrary depth)

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

#### Fixture 05 — missing-keys (both sides preserved)

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
the resolved output — neither side's unique keys are dropped.

#### Fixture 06 — extra-packages-concat (additive union)

`defaults.toml`:
```toml
[packages.brew]
extra_packages = ["jq", "yq"]
```

`machine.toml`:
```toml
[packages.brew]
extra_packages = ["docker-desktop", "jq"]
```

`resolved.json`:
```json
{
  "packages": {
    "brew": {
      "extra_packages": ["docker-desktop", "jq", "yq"]
    }
  }
}
```

Rule: `extra_packages` is the single exception to the array-replace rule. The resolver
computes the deduplicated union: `jq` appears only once in the output even though it was
declared in both files.

### Why arrays replace (not concatenate)

Predictability. A machine that wants exactly `["core"]` in `bundles` must not be silently
extended by defaults `["core", "dev"]`. Wholesale replacement gives the machine file full
authority over every array field.

`extra_packages` is the intentional escape hatch for the additive case — explicitly
concatenated so a machine can add one-off packages without forking a bundle file.

## Adding a New Machine

1. Choose a kebab-case name (e.g., `server-1`, `work-laptop`). Machine names must match
   the regex `^[a-z0-9][a-z0-9-]*$`.

2. Create `manifests/machines/<name>.toml`. Copy an existing machine file as a starting
   point and edit the values. Keep the same field structure.

3. Declare all required fields (see the Required fields table above). The validator rejects
   the manifest if any required field is absent.

4. Validate the schema:

   ```zsh
   # Phase 1 invocation (direct; see CLI Reference note)
   task -t taskfiles/manifest.yml manifest:validate -- --machine <name>
   ```

5. Persist the selection and regenerate `resolved.json`:

   ```zsh
   task -t taskfiles/manifest.yml setup -- <name>
   ```

   This verifies the file exists, writes `$XDG_STATE_HOME/dotfiles/machine`, and
   regenerates `resolved.json`.

6. Inspect the resolved output:

   ```zsh
   task -t taskfiles/manifest.yml manifest:show
   ```

7. (Optional) Apply the install:

   ```zsh
   task install
   ```

## CLI Reference

> **Phase 1 note:** Until Phase 2 wires the manifest module into the root `Taskfile.yml`
> via `includes:`, invoke manifest tasks with the `-t` flag:
> `task -t taskfiles/manifest.yml <subtask>`. Phase 2 removes this requirement by adding
> `manifest: ./taskfiles/manifest.yml` to the root `includes:` block.

| Command | Description |
|---------|-------------|
| `task setup -- <name>` | Persist machine selection; runs validate and resolve |
| `task manifest:resolve` | (Re)compile `resolved.json` from defaults + active machine TOML |
| `task manifest:show [-- --machine <name>]` | Print resolved manifest (active machine by default) |
| `task manifest:validate [-- --machine <name>]` | Schema check — required fields + unknown-key warnings |
| `task manifest:test` | Run the six golden-output fixture tests |

## State Files

| File | Description |
|------|-------------|
| `$XDG_STATE_HOME/dotfiles/machine` | Single-line text file with the active machine name; written by `task setup` |
| `$XDG_STATE_HOME/dotfiles/resolved.json` | Compiled JSON; rebuilt by `manifest:resolve` when any source TOML is newer |

Both files are machine-local and are not committed to the repository.

## Feature-Flag Reference

The table below is seeded with the features declared in `defaults.toml` and `personal-laptop.toml`
as of Phase 1. Each subsequent phase extends this table with the flags it consumes.

| Feature | Owner phase | What it does | Default in `defaults.toml` |
|---------|-------------|--------------|---------------------------|
| `one-password-ssh` | Phase 4 | Enables 1Password SSH agent integration | `false` |
| `one-password-signing` | Phase 4 | Enables git commit signing via 1Password op-ssh-sign | `false` |
| `motd` | Phase 3 | Enables MOTD display on `.zlogin` | `true` |
| `claude-marketplace` | Phase 7 | Installs Claude marketplace plugins | `true` |
| `macos-dock` | Phase 6 | Runs `os/defaults/dock.zsh` | machine-set (not in defaults.toml) |
| `macos-finder` | Phase 6 | Runs `os/defaults/finder.zsh` | machine-set (not in defaults.toml) |
| `macos-input` | Phase 6 | Runs `os/defaults/input.zsh` | machine-set (not in defaults.toml) |
| `macos-screenshots` | Phase 6 | Runs `os/defaults/screenshots.zsh` | machine-set (not in defaults.toml) |
| `macos-security` | Phase 6 | Runs `os/defaults/security.zsh` | machine-set (not in defaults.toml) |

To access any of these in a taskfile, use `{{index .MANIFEST.features "feature-name"}}`.
Do not use dot-access (`{{.MANIFEST.features.one-password-ssh}}`) — Go-template parsing
rejects the `-` character in identifiers.

## Known Limitations (v1)

- Line numbers in unknown-key warnings may be imprecise for deeply nested keys.
- The rename flow is manual: rename the TOML file and edit `$XDG_STATE_HOME/dotfiles/machine`
  by hand.
- No JSON Schema file for editor validation — deferred to v2 (`TOOL-V2-01`).
