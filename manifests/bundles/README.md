# manifests/bundles

Shared package bundles -- typed-bucket TOML files that the resolver pulls
into a machine's resolved manifest based on the machine's
`packages.brew.bundles = [...]` array.

## How it fits in

The resolver compiles `manifests/defaults.toml` plus the active machine's
`manifests/machines/<name>.toml` into
`$XDG_STATE_HOME/dotfiles/resolved.json`. During that compile, for each
bundle name in the merged `packages.brew.bundles` array, the resolver also
reads `manifests/bundles/<bundle>.toml` and unions its typed buckets
(`formulae`, `casks`, `mas`) into `packages.brew.extra_packages` on the
output.

The composer (`install/compose-brewfile.zsh`) then emits one Ruby DSL line
per entry into the cached Brewfile at `$XDG_CACHE_HOME/dotfiles/Brewfile`.

## Merge order

Buckets are concatenated in this order, then deduped (machine wins):

1. `manifests/defaults.toml` `[packages.brew.extra_packages]`
2. `manifests/bundles/<bundle>.toml` `[packages.brew]` -- one per bundle in
   `packages.brew.bundles` array order
3. `manifests/machines/<name>.toml` `[packages.brew.extra_packages]`

Dedupe semantics match the existing `extra_packages` rules:
- `formulae` -- string-value for bare strings; `.name` for objects; an
  object wins over a bare string (carries any metadata fields).
- `casks` -- `.name`; last write wins on collision.
- `mas` -- `.id`; last write wins on collision.

## Schema

```toml
# manifests/bundles/<name>.toml
[packages.brew]
formulae = ["pkg1", "pkg2", ...]           # bare strings (canonical)
casks    = [ { name = "app1" }, ... ]      # { name } objects (required shape)
mas      = [ { id = 12345, name = "App" }, ... ]  # { id, name } objects required
```

No `schema_version` field is required on shared TOMLs -- they're data
files, not machine manifests.

## Files

- `dotfiles.toml` -- packages the dotfiles config directly uses, wraps, or
  configures. Every machine includes this (every machine TOML's
  `bundles = [...]` array must contain `"dotfiles"`, enforced by
  `install/resolver.zsh::validate_manifest`).
- `dotfiles-gui.toml` -- GUI packages the dotfiles config depends on
  (1Password GUI, ghostty). Any machine with a display includes this
  (laptops + hybrid-headless machines add `"dotfiles-gui"` to `bundles`;
  truly headless servers omit it).
- `cli.toml` -- unwired CLI utilities (bat, bottom, doggo, duf, fd, htop,
  hugo, wget). Sysadmin/dev ergonomic upgrades over system defaults;
  taken by every shell machine.
- `dev.toml` -- GUI developer applications (IDEs, Docker Desktop, etc.).
  Workstation laptops only.
- `productivity.toml` -- desktop productivity suite (office, PIM, launcher,
  window management) plus MAS productivity apps. Workstation laptops only.
- `apps.toml` -- consumer GUI applications (browser, chat, media). Workstation
  laptops only.

## Adding a bundle

When to add a new shared bundle: when a tool set is wanted on two or more
machines AND has no per-machine variation. Otherwise, put it in the
machine's `[packages.brew.extra_packages]` typed sub-table.

1. Create `manifests/bundles/<purpose>.toml` with `[packages.brew]` and
   any of `formulae`, `casks`, `mas`.
2. Add `<purpose>` to the relevant machines' `packages.brew.bundles`
   array in `manifests/machines/<name>.toml`.
3. Run `task install` -- the resolver will pick up the new bundle and the
   composer will include its entries.

## Verify

Verification is data-driven from `brew info --installed --json=v2`. No
per-line annotations needed in shared TOMLs. See `docs/MANIFEST.md`
`## Verify model` for the canonical two-layer reference.
