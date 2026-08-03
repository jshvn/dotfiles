# manifests

Self-contained per-machine TOML manifests, the feature-flag registry, and the
unconditional base package tier.

Packages reach a machine through exactly three tiers: `base.toml`
(unconditional), a feature's `[<flag>.packages]` (pulled in when the flag is
enabled), and the machine's own `[packages]` (deliberate choices). A machine
manifest lists the third only.

- `features.toml` -- the feature-flag registry: every valid flag with a
  description and optional `platforms` constraint. The single source of truth
  for the flag vocabulary.
- `machines/<name>.toml` -- one TOML per machine; declares identity, enabled and
  disabled features, and the machine's discretionary packages.
- `base.toml` -- the unconditional package tier every machine receives. No
  machine declares it; listing one of its packages in a machine manifest is a
  hard error.
- `claude-addons/<name>.toml` -- third-party Claude addon definitions.
- `tests/` -- fixtures for the resolver.

The resolver (`install/resolver.zsh`) validates the active machine's TOML against
`features.toml` and `base.toml`, then compiles it into
`$XDG_STATE_HOME/dotfiles/resolved.json`. Downstream tasks read `resolved.json`
-- never the TOML files directly.

See `../docs/MANIFEST.md` for the schema reference and worked examples.

Add a new machine: create `machines/<name>.toml`, then run `task setup -- <name>`.
