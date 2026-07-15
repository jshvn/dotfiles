# manifests/machines

One self-contained TOML manifest per machine. Each declares `schema_version`, a
`[machine]` table (description, os, identity), a `[features]` table (`enabled`
and `disabled` arrays that account for every applicable flag in
`../features.toml`), a `[packages]` table (bundles plus any inline extras), and
an optional `[claude]` table.

See `../../docs/MANIFEST.md` for the schema and worked examples.
Add a machine: create `<name>.toml` here, then `task setup -- <name>`.
