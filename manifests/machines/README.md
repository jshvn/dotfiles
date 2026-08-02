# manifests/machines

One self-contained TOML manifest per machine. Each declares `schema_version`, a
`[machine]` table (description, os, identity), a `[features]` table (`enabled`
and `disabled` arrays that account for every applicable flag in
`../features.toml`), a `[packages]` table, and an optional `[claude]` table.

`[packages]` lists discretionary choices only -- applications wanted on that
machine. Packages the dotfiles config itself needs are guaranteed elsewhere:
`../base.toml` for unconditional tooling, `[<flag>.packages]` in
`../features.toml` for a feature's own dependencies. Listing a package that
base or an enabled flag already provides is a hard error, so reading one of
these files tells you exactly what was chosen for that machine and nothing
else.

See `../../docs/MANIFEST.md` for the schema and worked examples.
Add a machine: create `<name>.toml` here, then `task setup -- <name>`.
