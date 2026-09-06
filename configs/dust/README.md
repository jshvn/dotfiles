# Tool: dust

dust is a Rust `du` replacement that prints a size-sorted tree with percent
bars. This config holds display defaults only.

## Files

- `config.toml` -- dust's TOML configuration; read from
  `~/.config/dust/config.toml` at launch. Keys are dust's long flag names in
  kebab-case.

Note: the basename follows the match-destination-filename rule -- the
destination path `~/.config/dust/config.toml` dictates the source basename.

## Why the cloud excludes are not here

dust's config schema has no `ignore-directory` (`-X`) key. Excluding
`~/Library/CloudStorage` (Dropbox, Proton Drive) and `~/Library/Mobile
Documents` (iCloud Drive) is done on the `dust` alias in
`shell/aliases/dust.zsh`. Those are File Provider folders: every stat goes
through the provider extension, so scanning them takes minutes for hundreds
of thousands of placeholders.

## Symlink destination

`~/.config/dust/config.toml` -> `${DOTFILEDIR}/configs/dust/config.toml`

Wired via the `_:safe-link` entry in `taskfiles/links.yml` `install-configs`
sub-task.

## Feature gate

Always on -- no feature flag. The link is harmless on a machine whose
manifest does not list `dust` in `[packages].formulae`.

## References

- `taskfiles/links.yml` -- `install-configs` sub-task registers the symlink
- `shell/aliases/dust.zsh` -- the alias carrying the `-X` excludes
- `../README.md` -- match-destination-filename convention
