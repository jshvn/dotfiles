# modules

This directory contains the plumbing. It declares the options that each profile sets. It
turns these options into nix-darwin and home-manager configuration. A profile does not refer
to a file here. A profile only sets `dotfiles.*` options.

| File | Contents |
|------|----------|
| `default.nix` | Imports the other modules. Declares `dotfiles.checkout`, the path that all links point into. Declares `dotfiles.profile`, an enum of the directories in `profiles/`. Declares `dotfiles.links`, the only link registry. home-manager installs each link as an out-of-store symlink. Declares the user and its login shell. Turns on Nix flakes. Starts the Nix garbage collection each week. |
| `packages.nix` | Declares `dotfiles.packages.*`, the free choices of a profile. Declares `dotfiles.provided.*`, the packages that the base and the enabled apps supply. Contains the assertion against redundant packages. Gets the taps from the package names. Sets `homebrew.brews`, `homebrew.casks`, `homebrew.masApps` and `homebrew.taps`. |
| `base.nix` | Lists the formulae that each machine gets. These include the bootstrap toolchain and the formulae that `shell/` needs. Contains the only bare tap, `homebrew/brew-vulns`. |
| `homebrew.nix` | Installs Homebrew if it is missing, just before `brew bundle`. Sets `homebrew.onActivation`. Each switch updates and upgrades the packages. Cleanup stays off, because `task prune` asks before it removes a package. |
| `shell.nix` | Adds the login shell to `/etc/shells`. Writes `/etc/zshenv`. Links the startup files. Declares `dotfiles.shell.aliases` and `dotfiles.shell.env`. The switch links these files into `aliases.d/` and `env.d/`. Declares `shell.jgrid-net`. |
| `repo.nix` | Declares `repo.devToolchain`. |

The modules enforce these rules. If you break a rule, the evaluation fails.

- Each optional option has no default. Thus each profile must set it.
- A profile must not list a package that the base or an app supplies. `packages.nix` compares
  the lists of the profile with `provided`.
- A profile must not list a bundled VS Code extension again. `apps/vscode/default.nix` makes
  this check.
- `dotfiles.profile` must name a directory in `profiles/`. `default.nix` makes this check.

`tasks/tests/negative.sh` breaks each rule to prove that the rule works.

## Add a module

1. Declare each option with `lib.mkOption`. If a profile must choose a value, do not give a
   default.
2. Supply packages through `dotfiles.provided.*`.
3. Supply links through `dotfiles.links`.
4. Supply shell integration through `dotfiles.shell.aliases` and `dotfiles.shell.env`.
5. Import the module in `default.nix`.
