# apps

One directory per application, owning everything about it: the install (a formula or cask in
`dotfiles.provided`), the config files beside it (linked straight from the checkout through
`dotfiles.links`), the shell integration (`aliases.zsh` linked into `aliases.d/`, `env.zsh`
into `env.d/`, only when the app is on), and any system setting that exists only for that app.

The rule for what is an app: anything with configuration attached to its install. Anything
merely installed is a package name in the profile.

| App | Option | Owns |
|-----|--------|------|
| `1password/` | readOnly, set by the identity | the cask, `agent.toml`, `env.zsh` (SSH_AUTH_SOCK) |
| `claude-code/` | `apps.claude-code.{enable,profile,ref,dir}` | the cask; the jshvn/ai checkout at its ref, its profile, its own `task install` (an activation step: `checkout.zsh`, `repo-sync.zsh`) |
| `conda/` | `apps.conda.enable` | the miniconda cask, `condarc` |
| `dust/` | `apps.dust.enable` | the formula, `config.toml`, the `dust` alias |
| `eza/` | none: a base app | the formula, `theme.yaml` |
| `ghostty/` | `apps.ghostty.enable` | the cask, `config`, the `g` launcher |
| `herdr/` | `apps.herdr.enable` | the formula, `config.toml` |
| `raycast/` | `apps.raycast.{enable,freeCmdSpace}` | the cask, the script-command directory (registered in Raycast by hand), Spotlight's Cmd+Space |
| `tlrc/` | none: a base app | the formula, `config.toml` |
| `vscode/` | `apps.vscode.{enable,extensions}` | the cask and the bundled extension set; a profile adds extras |

A base app (eza, tlrc) declares no option because `shell/` breaks without it; it is always
on. Every other app's `enable` has no default, so a profile must say yes or no.

Conventions:

- The config file's basename equals its destination basename (`apps/tlrc/config.toml` links
  to `~/.config/tlrc/config.toml`).
- Shell integration files carry the three-label banner and define functions, aliases or
  exports only; there is no gate inside the file. Whether the switch linked it is the gate.
- `apps/raycast/` is read by Raycast from the checkout path: Raycast > Settings > Extensions
  > Script Commands > Add Directories, once per machine.
- `repo-sync.zsh` is also what `task install` runs against this repo before a switch.

## Adding an app

1. Create `apps/<name>/default.nix` declaring `options.dotfiles.apps.<name>.enable` (no
   default) and, under `config = lib.mkIf ...`, its `dotfiles.provided.{formulae,casks}`,
   `dotfiles.links`, `dotfiles.shell.aliases.<name>` or `.env.<name>`.
2. Put its config files and `aliases.zsh` beside it.
3. Import it from `apps/default.nix`.
4. Set `dotfiles.apps.<name>.enable` in every profile; `task check` fails until you do.
5. Remove the formula or cask from any profile's `packages` list; it is provided now.
