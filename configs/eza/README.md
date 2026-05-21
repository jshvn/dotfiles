# Tool: eza

eza is a modern replacement for `ls`, written in Rust, with extended metadata,
Git integration, and theming support. This config defines a color theme that
mirrors the classic `LS_COLORS` mapping while extending it to eza-specific
categories (permissions, sizes, Git status, and file-type groups).

## Files

- `theme.yaml` -- eza's color theme YAML; read from `~/.config/eza/theme.yaml`
  at launch.

Note: renamed in transit from v1 `eza_style.yaml` to `theme.yaml` per the
match-destination-filename rule. The eza CLI looks for the file at
`~/.config/eza/theme.yaml`; the source is renamed to match when porting from v1.

## Symlink destination

`~/.config/eza/theme.yaml` -> `${DOTFILEDIR}/configs/eza/theme.yaml`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `configs:` sub-task.

## Feature gate

Always on -- no feature flag. Every machine that installs `eza` (declared in
`manifests/bundles/dotfiles.toml`) gets this theme symlinked automatically.

## References

- `taskfiles/links.yml` -- `configs:` sub-task registers the symlink
- `manifests/defaults.toml` -- rename-in-transit convention documented in
  `CLAUDE.md`
