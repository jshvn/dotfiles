# Tool: motd

The MOTD (message of the day) is a Tron-themed login greeting shown on
interactive shell login. It combines a static ASCII art / quote file with a
fastfetch sysinfo template, rendered by `shell/functions/motd.zsh` with a
24-hour cache. These files are read directly from the repo at runtime -- they
are not symlinked.

## Files

- `motd_tron.txt` -- newline-separated Tron quotes; one line is chosen
  randomly at render time by `motd.zsh`.
- `motd_sysinfo.jsonc` -- fastfetch configuration (JSONC format, with
  inline comments) that controls which system-info modules are displayed.

## Symlink destination

No symlink -- these files are read at runtime by `shell/functions/motd.zsh`
directly from `${DOTFILEDIR}/configs/motd/`. The motd function uses
`${DOTFILEDIR}/configs/motd/motd_tron.txt` and
`${DOTFILEDIR}/configs/motd/motd_sysinfo.jsonc`.

This is the runtime-read exception: motd files live under `configs/motd/` for
structural symmetry with the other tool subdirectories but require no symlink
because the shell function reads the repo path directly.

## Feature gate

Always on -- no feature flag. `.zshrc`'s functions glob defines the `motd`
function, and `.zlogin` calls it unconditionally on login. These data files
are always present on disk and consume negligible footprint.

## References

- `shell/functions/motd.zsh` -- reads these files at render time
- `shell/.zlogin` -- calls `motd` on login
