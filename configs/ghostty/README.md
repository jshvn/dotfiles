# Tool: ghostty

Ghostty is a GPU-accelerated terminal emulator written in Zig. This config
sets the font, color palette, opacity, window padding, and SSH environment
integration used on machines where the `ghostty` feature flag is enabled.

## Files

- `config` -- Ghostty's main configuration file; read from
  `~/.config/ghostty/config` at launch.

## Symlink destination

`~/.config/ghostty/config` -> `${DOTFILEDIR}/configs/ghostty/config`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

`features.ghostty` -- list `ghostty` in a machine's `[features] enabled` array
to enable the Ghostty alias group and the symlink registration. Machines
without Ghostty installed list it in `[features] disabled` instead.

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlink (Plan 06)
- `manifests/features.toml` -- registers the `ghostty` flag
