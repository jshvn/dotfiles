# manifests

Per-machine TOML manifests plus the shared baseline they inherit from.

- `defaults.toml` -- shared baseline (every machine inherits these values).
- `machines/<name>.toml` -- one TOML per machine; declares identity,
  features, package bundles, and any extras.
- `bundles/<purpose>.toml` -- purpose-named package bundles
  (`dotfiles`, `cli`, `dotfiles-gui`, `dev`, `productivity`, `apps`).
  See `bundles/README.md` for the catalog and merge semantics.
- `test/` -- golden-output fixtures for the deep-merge resolver.

The resolver (`install/resolver.zsh`) compiles `defaults.toml` plus the
active machine's TOML into `$XDG_STATE_HOME/dotfiles/resolved.json`.
Downstream tasks read `resolved.json` -- never the TOML files directly.

See `../docs/MANIFEST.md` for the schema reference, merge semantics, and
worked examples.

Add a new machine: create `machines/<name>.toml`, then run
`task setup -- <name>`.
