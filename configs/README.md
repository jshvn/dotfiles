# configs

Per-tool configuration files deployed via symlinks into `~/.config/<tool>/`
(or, for dotfiles-internal consumers, read directly from the repo). Each tool
gets its own subdirectory; the source filename matches the destination filename
so `_:safe-link` calls are straightforward.

## Tools

| Tool | Files | Destination | Feature gate |
|------|-------|-------------|--------------|
| ghostty | `ghostty/config` | `~/.config/ghostty/config` | `features.ghostty` |
| tlrc | `tlrc/config.toml` | `~/.config/tlrc/config.toml` | always on |
| conda | `conda/condarc` | `~/.condarc` | always on |
| eza | `eza/theme.yaml` | `~/.config/eza/theme.yaml` | always on |
| motd | `motd/motd_tron.txt`, `motd/motd_sysinfo.jsonc` | no symlink -- read at runtime | always on (runtime-read) |

## How to add a tool config

1. Drop the config file at `configs/<tool>/<filename>` -- the basename must
   match the destination basename (match-destination-filename rule).
2. Add `configs/<tool>/README.md` documenting purpose, files, symlink
   destination, and feature gate.
3. Register a `_:safe-link` entry in `taskfiles/links.yml` under the `configs:`
   sub-task (never use bare `ln -s`; see `CLAUDE.md` LINT-03b).
4. If the tool needs feature-gating, register a kebab-case flag in
   `manifests/features.toml` (its own `[flag-name]` block), account for it in
   every machine's `[features]` enabled or disabled array, and wrap the link
   entry in `{{if index .MANIFEST.features "flag-name"}}`.

## Conventions

- **Match-destination-filename:** The source file basename inside
  `configs/<tool>/` must equal the destination basename so `_:safe-link`
  source and target share the same filename (e.g. tlrc's config lives at
  `configs/tlrc/config.toml` to match `~/.config/tlrc/config.toml`; eza's
  theme at `configs/eza/theme.yaml` to match `~/.config/eza/theme.yaml`).

- **Per-tool subdirectory always:** Even single-file tools get their
  own subdirectory (never a flat file directly under `configs/`). This keeps
  the layout extensible when a tool adds a second config file.

- **motd runtime-read exception:** `configs/motd/` files are read
  directly by `shell/functions/motd.zsh` at render time. No symlink is
  registered for motd. The subdirectory exists for structural symmetry only.
