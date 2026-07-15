# manifests/bundles

Shared package bundles -- TOML files that the resolver pulls into a machine's
resolved manifest based on the machine's `[packages] bundles = [...]` array.

## How it fits in

The resolver compiles the active machine's `manifests/machines/<name>.toml` into
`$XDG_STATE_HOME/dotfiles/resolved.json`. During that compile, for each bundle
name in the machine's `packages.bundles` array, the resolver reads
`manifests/bundles/<bundle>.toml` and unions its `[packages]` buckets
(`formulae`, `casks`, `mas`, `vscode`, `cargo`, `uv`, `npm`) with the machine's
inline entries.

The composer (`install/compose-brewfile.zsh`) then emits one Ruby DSL line per
entry into the cached Brewfile at `$XDG_CACHE_HOME/dotfiles/Brewfile`.

## Union order

Each bucket is concatenated across the included bundles (in the machine's
declared order), then the machine's inline entries, then deduped:

- `formulae`, `casks`, `vscode`, `cargo`, `uv`, `npm` -- bare-string values,
  deduplicated and sorted.
- `mas` -- deduplicated by `.id`; the machine's entry wins over a bundle's on a
  collision.

## Schema

```toml
# manifests/bundles/<name>.toml
[packages]
formulae = [           # bare strings
  "pkg1",
  "pkg2",
]
casks = [              # bare strings
  "app1",
]
mas = [                # { id, name } objects
  { id = 12345, name = "App" },
]
vscode = []            # extension ids
```

Shared TOMLs carry no `schema_version` -- they are data files, not machine
manifests.

## Files

- `dotfiles.toml` -- packages the dotfiles config directly uses, wraps, or
  configures. Every machine includes this (every machine's `bundles` array must
  contain `"dotfiles"`, enforced by `install/resolver.zsh`).
- `dotfiles-gui.toml` -- GUI packages the dotfiles config depends on
  (1Password GUI, ghostty). Any machine with a display includes this; truly
  headless servers omit it.
- `cli.toml` -- unwired CLI utilities (bat, fd, htop, wget, ...). Taken by every
  shell machine.
- `dev.toml` -- GUI developer applications (IDEs, etc.) plus the VSCode
  extension set. Workstation laptops only.
- `productivity.toml` -- desktop productivity suite plus MAS productivity apps.
  Workstation laptops only.
- `apps.toml` -- consumer GUI applications (browser, chat, media). Workstation
  laptops only.

## Adding a bundle

Add a new shared bundle when a tool set is wanted on two or more machines and has
no per-machine variation. Otherwise, put it in the machine's own `[packages]`
inline entries.

1. Create `manifests/bundles/<purpose>.toml` with a `[packages]` table holding
   any of `formulae`, `casks`, `mas`, `vscode`, `cargo`, `uv`, `npm`.
2. Add `<purpose>` to the relevant machines' `packages.bundles` arrays.
3. Run `task install` -- the resolver picks up the new bundle and the composer
   includes its entries.

## Verify

Verification is data-driven from `brew info --installed --json=v2`. No per-line
annotations are needed in bundle TOMLs.
