# apps

Each application has one directory. The directory contains all the parts of that application:

- The install. This is a formula or a cask in `dotfiles.provided`.
- The configuration files. `dotfiles.links` links each file from the checkout.
- The shell integration. The switch links `aliases.zsh` into `aliases.d/` and `env.zsh` into
  `env.d/`. The switch does this only when the app is on.
- The system settings that only this app uses.

An app is a package that has configuration. A package without configuration is not an app.
Put the name of that package in the `packages` lists of the profile.

| App | Option | Contents |
|-----|--------|----------|
| `1password/` | None. This is a base app. | Installs the cask. Links `agent.toml` from the profile. `env.zsh` sets `SSH_AUTH_SOCK`. `README.md` tells how to turn on the SSH agent. |
| `claude-code/` | `apps.claude-code.{enable,profile,ref,dir}` | Installs the cask. Keeps the jshvn/ai checkout at its ref. Selects the profile in that checkout and does its `task install`. `checkout.zsh` does these steps in an activation step. It uses `tasks/install-repo-sync.zsh` to fast-forward. |
| `conda/` | `apps.conda.enable` | Installs the miniconda cask. Links `condarc`. |
| `dust/` | `apps.dust.enable` | Installs the formula. Links `config.toml`. Adds the `dust` alias. |
| `eza/` | None. This is a base app. | Installs the formula. Links `theme.yaml`. |
| `firefox/` | `apps.firefox.enable` | Installs the cask. `env.zsh` sets `BROWSER`. |
| `ghostty/` | `apps.ghostty.enable` | Installs the cask. Links `config`. Adds the `g` launcher. |
| `git/` | None. This is a base app. | Installs git and git-delta. Links `config` and `ignore`. Links the `git` file of the profile. `config` includes that file for repositories under `~/git/`. |
| `herdr/` | `apps.herdr.enable` | Installs the formula. Links `config.toml`. |
| `raycast/` | `apps.raycast.{enable,freeCmdSpace}` | Installs the cask. Contains the script command directory. You must register this directory in Raycast manually. When `freeCmdSpace` is true, turns off the Spotlight Cmd+Space shortcut. |
| `ssh/` | None. This is a base app. | Installs openssh. Links `config`, which sends each host through the 1Password agent. `cloudflared.zsh` is the ProxyCommand for the tunnel. Links `ssh` and `key.pub` from the profile. Writes the GitHub host keys to `/etc/ssh/ssh_known_hosts`. |
| `starship/` | None. This is a base app. | Installs the formula. Links `starship.toml`, the prompt. `shell/theme.zsh` starts it. |
| `terraform/` | `apps.terraform.enable` | Installs the formula from the HashiCorp tap. `env.zsh` sets `CHECKPOINT_DISABLE`. |
| `tlrc/` | None. This is a base app. | Installs the formula. Links `config.toml`. `env.zsh` sets `TLRC_CONFIG`. |
| `vscode/` | `apps.vscode.{enable,extensions,vsix}` | Installs the cask and the bundled extensions. A profile can add more extensions. A profile can also add an extension from a VSIX in the repository of that extension. `vsix.zsh` installs these in an activation step. `env.zsh` sets `COPILOT_HOME`. |
| `wget/` | `apps.wget.enable` | Installs the formula. Links `wgetrc`, which keeps the HSTS cache in `~/.cache`. `env.zsh` sets `WGETRC`. |

A base app has no option and is always on. `shell/` does not work without eza, starship and
tlrc. The identity of each profile uses git, ssh and 1Password.

Each other app has an `enable` option with no default. Thus each profile must set it to true
or false.

## Conventions

- A configuration file has the same basename as its destination. For example,
  `apps/tlrc/config.toml` links to `~/.config/tlrc/config.toml`.
- Each shell integration file has the three-label banner. It contains only functions, aliases
  or exports.
- A shell integration file has no gate. The switch links the file only when the app is on.
  That is the gate.
- Raycast reads `apps/raycast/` from the checkout path. Add this directory one time on each
  machine. Go to Raycast > Settings > Extensions > Script Commands > Add Directories.

## Add an app

1. Create `apps/<name>/default.nix`. Declare `options.dotfiles.apps.<name>.enable` with no
   default.
2. Under `config = lib.mkIf ...`, declare the parts of the app:
   - `dotfiles.provided.formulae` or `dotfiles.provided.casks` for the install.
   - `dotfiles.links` for the configuration files.
   - `dotfiles.shell.aliases.<name>` or `dotfiles.shell.env.<name>` for the shell
     integration.
3. Put the configuration files and `aliases.zsh` in the same directory.
4. Import the directory in `apps/default.nix`.
5. Set `dotfiles.apps.<name>.enable` in each profile. If a profile does not set it,
   `task check` fails.
6. Remove the formula or the cask from the `packages` lists of each profile. The app supplies
   it now. If a profile still lists it, an assertion fails.
