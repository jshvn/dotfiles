# Tool: trippy

Trippy is a TUI network diagnostic tool that combines traceroute and ping.
This config sets the tracing strategy, DNS resolver, color theme, and key
bindings for the interactive TUI, tuned for a dark terminal with a cyan/green
color scheme.

## Files

- `trippy.toml` -- Trippy's main TOML configuration; read from
  `~/.config/trippy/trippy.toml` at launch.

## Symlink destination

`~/.config/trippy/trippy.toml` -> `${DOTFILEDIR}/configs/trippy/trippy.toml`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

Always on -- no feature flag. Every machine that installs `trippy` (declared in
`packages/`) gets this config symlinked automatically.

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlink (Plan 06)
