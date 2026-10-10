# system

macOS settings, one file per System Settings concern. Each file declares its own switch,
`options.dotfiles.system.<concern>` (bool, no default), and its own configuration under
`config = lib.mkIf config.dotfiles.system.<concern> { ... }`. A profile sets every concern
true or false.

| Concern | Covers |
|---------|--------|
| `dock.nix` | Desktop & Dock, Spaces edge switch, window tiling |
| `finder/` | Finder defaults, and `aliases.zsh` (finder, findershow, finderhide) linked into `aliases.d/` |
| `input.nix` | keyboard and trackpad |
| `screenshots.nix` | location, format, shadow, thumbnail |
| `security.nix` | guest account off; ImageCapture hot-plug off (a ByHost key, through home-manager); application firewall on |
| `appearance.nix` | Dark mode, icon style |
| `display.nix` | the built-in panel at the More Space preset, via `display-mode.swift` in an activation script |
| `animations.nix` | short AppKit window and Quick Look animations |

How a setting is expressed, in order of preference: a typed nix-darwin option
(`system.defaults.<group>.<key>`) where one exists; `system.defaults.CustomUserPreferences`
for a plain key it lacks; an activation script only where `defaults write` is the wrong tool
(the display mode is a CoreGraphics reconfiguration). A concern with shell integration is a
directory holding its `aliases.zsh`.

What nix-darwin cannot do: it writes a nested value whole, never merging (so the Spotlight
hotkey lives in `apps/raycast/`, as a `-dict-add`), and it has no `-currentHost` writes
(home-manager's `targets.darwin.currentHostDefaults` does those). `sysadminctl -screenLock`
needs a password on a tty and stays manual.

`tasks/validate.zsh` reads every key back from the live system: typed groups through its
`DOMAIN` table (group to defaults domain), `CustomUserPreferences` and ByHost keys directly.
A new typed group needs a `DOMAIN` row or validate crosses on it.

## Adding a concern

1. Create `system/<concern>.nix` (or `system/<concern>/default.nix` with an `aliases.zsh`
   beside it, registered as `dotfiles.shell.aliases.<concern>`).
2. Import it from `system/default.nix`.
3. Set `dotfiles.system.<concern>` in every profile; `task check` fails until you do.
4. `task install && task validate` on a machine that enables it.
