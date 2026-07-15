# manifests

Self-contained per-machine TOML manifests, the feature-flag registry, and the
shared package bundles.

- `features.toml` -- the feature-flag registry: every valid flag with a
  description and optional `platforms` constraint. The single source of truth
  for the flag vocabulary.
- `machines/<name>.toml` -- one TOML per machine; declares identity, enabled and
  disabled features, package bundles, and any inline package extras.
- `bundles/<purpose>.toml` -- purpose-named package bundles
  (`dotfiles`, `cli`, `dotfiles-gui`, `dev`, `productivity`, `apps`).
  See `bundles/README.md` for the catalog.
- `claude-addons/<name>.toml` -- third-party Claude addon definitions.
- `test/` -- fixtures for the resolver.

The resolver (`install/resolver.zsh`) validates the active machine's TOML against
`features.toml` and the bundle set, then compiles it into
`$XDG_STATE_HOME/dotfiles/resolved.json`. Downstream tasks read `resolved.json`
-- never the TOML files directly.

See `../docs/MANIFEST.md` for the schema reference and worked examples.

Add a new machine: create `machines/<name>.toml`, then run `task setup -- <name>`.
