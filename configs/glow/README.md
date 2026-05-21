# Tool: glow

Glow is a terminal-based markdown renderer from Charm. This directory holds
the main config file (word-wrap width, pager toggle, mouse support) and a
custom JSON style that applies Tron-adjacent terminal colors to rendered
headings, code blocks, and inline elements.

## Files

- `glow.yml` -- main Glow configuration; read from `~/.config/glow/glow.yml`
  at launch.
- `glow_style.json` -- custom color style; referenced from `glow.yml` via the
  `style` key (currently set to `"auto"` pending upstream bug resolution;
  see comment in `glow.yml`).

## Symlink destinations

`~/.config/glow/glow.yml`        -> `${DOTFILEDIR}/configs/glow/glow.yml`
`~/.config/glow/glow_style.json` -> `${DOTFILEDIR}/configs/glow/glow_style.json`

Both wired via `_:safe-link` entries in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

Always on -- no feature flag. Every machine that installs `glow` (declared in
`manifests/bundles/dotfiles.toml`) gets this config symlinked automatically.

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlinks (Plan 06)
