# Tool: tlrc

tlrc is the official Rust-based tldr-pages client (tldr-rust). This config
controls the cache location, display style, indentation, and color theme for
rendered tldr pages, using a magenta/cyan palette that complements the
terminal theme.

## Files

- `config.toml` -- tlrc's main TOML configuration; read from
  `~/.config/tlrc/config.toml` at launch.

Note: renamed in transit from v1 `tlrc.toml` to `config.toml` per the
match-destination-filename rule. The destination path
`~/.config/tlrc/config.toml` dictates the basename; the source is renamed
to match when porting from v1.

## Symlink destination

`~/.config/tlrc/config.toml` -> `${DOTFILEDIR}/configs/tlrc/config.toml`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

Always on -- no feature flag. Every machine that installs `tlrc` (declared in
`manifests/bundles/dotfiles.toml`) gets this config symlinked automatically.

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlink
- `manifests/defaults.toml` -- rename-in-transit convention documented in
  `CLAUDE.md`
