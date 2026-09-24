# Tool: motd

The MOTD (message of the day) is a Tron-themed login greeting shown on
interactive shell login. It combines the jgrid logo (image or inline ASCII art), a
random Tron quote, and a fastfetch sysinfo template, rendered by
`shell/functions/motd.zsh`. These files are read directly from the repo at runtime -- they
are not symlinked.

## Files

- `motd_tron.txt` -- newline-separated Tron quotes; one line is chosen
  randomly at render time by `motd.zsh`.
- `motd_sysinfo.jsonc` -- fastfetch configuration (JSONC format, with
  inline comments) that controls which system-info modules are displayed.
- `motd_jgrid.png` -- the jgrid logo (`logo/jgrid-mark-on-dark-512.png` in
  `jshvn/jgrid.net`), drawn in place of the ASCII art in terminals with an
  image protocol (kitty, Ghostty, iTerm2, WezTerm) outside tmux.

## Symlink destination

No symlink -- these files are read at runtime by `shell/functions/motd.zsh`
directly from `${DOTFILEDIR}/configs/motd/`. The motd function uses
`motd_tron.txt`, `motd_sysinfo.jsonc` and `motd_jgrid.png` from there.

This is the runtime-read exception: motd files live under `configs/motd/` for
structural symmetry with the other tool subdirectories but require no symlink
because the shell function reads the repo path directly.

## Feature gate

Always on -- no feature flag. `.zshrc`'s functions glob defines the `motd`
function, and `.zlogin` calls it on login when the function is defined. These data files
are always present on disk and consume negligible footprint.

## References

- `shell/functions/motd.zsh` -- reads these files at render time
- `shell/.zlogin` -- calls `motd` on login
