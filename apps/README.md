# apps

One directory per application, owning everything about it: the install (a formula or cask in
`dotfiles.provided`), the config files beside it (linked straight from the checkout through
`dotfiles.links`), the shell integration (`aliases.zsh` linked into `aliases.d/`, `env.zsh`
into `env.d/`, only when the app is on), and any system setting that exists only for that app.

The rule for what is an app: anything with configuration attached to its install. Anything
merely installed is a package name in the profile.

| App | Option | Owns |
|-----|--------|------|
| `1password/` | none: a base app | the cask, `env.zsh` (SSH_AUTH_SOCK), the link to the profile's `agent.toml`; `README.md` on the agent's by-hand switch |
| `claude-code/` | `apps.claude-code.{enable,profile,ref,dir}` | the cask; the jshvn/ai checkout at its ref, its profile, its own `task install` (an activation step: `checkout.zsh`, which fast-forwards with `tasks/install-repo-sync.zsh`) |
| `conda/` | `apps.conda.enable` | the miniconda cask, `condarc` |
| `dust/` | `apps.dust.enable` | the formula, `config.toml`, the `dust` alias |
| `eza/` | none: a base app | the formula, `theme.yaml` |
| `ghostty/` | `apps.ghostty.enable` | the cask, `config`, the `g` launcher |
| `git/` | none: a base app | git and git-delta, `config` (includes the profile's overlay under `~/git/`), `ignore`, the link to the profile's `git` |
| `herdr/` | `apps.herdr.enable` | the formula, `config.toml` |
| `raycast/` | `apps.raycast.{enable,freeCmdSpace}` | the cask, the script-command directory (registered in Raycast by hand), Spotlight's Cmd+Space |
| `ssh/` | none: a base app | openssh, `config` (every host through the 1Password agent), `cloudflared.zsh` (the tunnel ProxyCommand), the links to the profile's `ssh` and `key.pub`, GitHub's host keys in `/etc/ssh/ssh_known_hosts` |
| `tlrc/` | none: a base app | the formula, `config.toml` |
| `vscode/` | `apps.vscode.{enable,extensions}` | the cask and the bundled extension set; a profile adds extras |
| `wget/` | `apps.wget.enable` | the formula, `wgetrc` (the HSTS cache under `~/.cache`), `env.zsh` (WGETRC) |

A base app declares no option and is always on: `shell/` breaks without eza and tlrc, and
every profile's identity runs through git, ssh and 1Password. Every other app's `enable` has
no default, so a profile must say yes or no.

Conventions:

- The config file's basename equals its destination basename (`apps/tlrc/config.toml` links
  to `~/.config/tlrc/config.toml`).
- Shell integration files carry the three-label banner and define functions, aliases or
  exports only; there is no gate inside the file. Whether the switch linked it is the gate.
- `apps/raycast/` is read by Raycast from the checkout path: Raycast > Settings > Extensions
  > Script Commands > Add Directories, once per machine.

## Adding an app

1. Create `apps/<name>/default.nix` declaring `options.dotfiles.apps.<name>.enable` (no
   default) and, under `config = lib.mkIf ...`, its `dotfiles.provided.{formulae,casks}`,
   `dotfiles.links`, `dotfiles.shell.aliases.<name>` or `.env.<name>`.
2. Put its config files and `aliases.zsh` beside it.
3. Import it from `apps/default.nix`.
4. Set `dotfiles.apps.<name>.enable` in every profile; `task check` fails until you do.
5. Remove the formula or cask from any profile's `packages` list; it is provided now.
