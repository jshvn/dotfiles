# Tool: herdr

Herdr is a terminal workspace manager for AI coding agents. This config sets
the theme (a DuoTone Dark Sky mapping over the catppuccin base, matching the
`highlight` alias style in `shell/theme.zsh`) and UI panel behavior.

## Files

- `config.toml` -- Herdr's main configuration file; read from
  `~/.config/herdr/config.toml` by the server (live-reloadable via
  `herdr server reload-config`).

## Symlink destination

`~/.config/herdr/config.toml` -> `${DOTFILEDIR}/configs/herdr/config.toml`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

`features.herdr` -- list `herdr` in a machine's `[features] enabled` array to
install the formula and the symlink. Machines without herdr list it in
`[features] disabled` instead. The flag owns the `herdr` formula in
`manifests/features.toml`.

## References

- `taskfiles/links.yml` -- `configs:herdr` sub-task registers the symlink
- `manifests/features.toml` -- registers the `herdr` flag and its formula
