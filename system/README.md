# system

This directory contains the macOS settings. Each System Settings concern has one file. Each
file declares its own option, `options.dotfiles.system.<concern>`. This option is a bool with
no default. The file declares its configuration under
`config = lib.mkIf config.dotfiles.system.<concern> { ... }`. A profile sets each concern to
true or false. The one exception is `dockApps` in `dock.nix`. It is a list that each profile
sets.

| Concern | Settings |
|---------|----------|
| `dock.nix` | Sets Desktop & Dock, the Spaces edge switch and window tiling. Sets the Dock apps from `dockApps` and the Downloads stack. Turns off tiled window margins. Turns off "Reopen windows when logging back in". |
| `finder/` | Sets the Finder defaults. `aliases.zsh` adds `finder`, `findershow` and `finderhide`. The switch links it into `aliases.d/`. |
| `input.nix` | Sets the keyboard and the trackpad. Turns off Genmoji suggestions. Turns off the input source shortcuts and the Finder search shortcut. |
| `screenshots.nix` | Sets the location, the format, the shadow and the thumbnail of screenshots. |
| `security.nix` | Turns off the guest account. Turns off ImageCapture hot-plug. This is a ByHost key, so home-manager writes it. Turns on the application firewall. Turns on Touch ID for `sudo`. |
| `updates.nix` | Turns off the automatic install of macOS updates. Turns off App Store app updates. |
| `appearance.nix` | Sets Dark mode and the icon style. |
| `display/` | Sets the built-in panel to the More Space preset. An activation script uses `display-mode.swift` in the same directory. Sets display sleep to 10 minutes on battery and on power. Turns off Universal Control. This is a ByHost key, so home-manager writes it. |
| `animations.nix` | Makes the AppKit window animations and the Quick Look animations short. |

Use the first method that works for a setting:

1. A typed nix-darwin option, `system.defaults.<group>.<key>`.
2. `system.defaults.CustomUserPreferences`, for a plain key that has no typed option.
   `system.defaults.CustomSystemPreferences` for a key in `/Library/Preferences`. Give the
   domain as its full path, for example `/Library/Preferences/com.apple.commerce`. Activation
   runs as root, so a bare domain writes to the preferences of root.
3. An activation script. Use a script only when `defaults write` is not the correct tool. For
   example, the display mode needs a CoreGraphics reconfiguration.

If a concern has other files next to its nix file, make the concern a directory. For example,
an `aliases.zsh` or a helper script.

nix-darwin has these limits:

- nix-darwin writes a nested value as a whole. It does not merge. Thus the symbolic hotkeys are
  `-dict-add` activation scripts in `apps/raycast/` and `input.nix`.
- nix-darwin cannot write `-currentHost` keys. home-manager writes them through
  `targets.darwin.currentHostDefaults`.
- `sysadminctl -screenLock` needs a password on a tty. Thus you must set the screen lock
  manually.

`tasks/validate.zsh` reads each key back from the live system. For a typed group, it uses its
`DOMAIN` table. This table maps each group to a defaults domain. It reads
`CustomUserPreferences`, `CustomSystemPreferences` and ByHost keys directly. If you add a typed
group, add a `DOMAIN` row. If you do not, `task validate` reports a failure. It does not read
back a list, such as the Dock apps.

## Add a concern

1. Create `system/<concern>.nix`. If the concern has other files, create
   `system/<concern>/default.nix` and put the files next to it.
2. If the concern has an `aliases.zsh`, register it as `dotfiles.shell.aliases.<concern>`.
3. Import the concern in `system/default.nix`.
4. Set `dotfiles.system.<concern>` in each profile. If a profile does not set it, `task check`
   fails.
5. On a machine that turns on the concern, enter `task install`.
6. Enter `task validate`.
