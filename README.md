# Josh's dotfiles

[![ci](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml)

This repository declares personal macOS machines. Each machine has one nix-darwin
configuration.

- Nix applies the system configuration. This includes the macOS settings, the user account and
  the files in `/etc`.
- Homebrew installs all packages. Homebrew uses `mas` to install the App Store apps.
- Each configuration file in the home directory is a symbolic link to a file in this checkout.
  A change to a file applies in the next shell. You do not have to build again.

## Install

Before you start:

1. Install the Xcode Command Line Tools. These tools supply `git`. The first `git` command
   asks you to install them.
2. Sign in to the App Store. If you do not sign in, the install stops when `mas` installs the
   App Store apps.

Enter these commands:

```zsh
git clone https://github.com/jshvn/dotfiles.git ~/Git/personal/dotfiles
cd ~/Git/personal/dotfiles
./bootstrap.zsh <machine>
```

Replace `<machine>` with the name of a file in `machines/`, without `.nix`. Do not clone to a
different path. All links point into this path.

After the install:

1. Open a new terminal.
2. Sign in to 1Password.
3. Turn on the 1Password SSH agent.
4. Enter `update`.

The `jshvn/ai` and `jshvn/vscode-title-buttons` repositories clone over SSH. The first install
cannot clone them and shows a warning. Run update after configuring 1Password to install them.

### Update

```zsh
update
```

`update` is an alias for `task install`. You can use it in any directory.

If the install or the update stops before it completes, correct the cause. Then enter the same
command again. You can do the install or the update more than one time. The result is the same.

## Commands

| Command | Purpose |
|---------|---------|
| `task setup -- <machine>` | Saves the machine selection. |
| `task install [-- --yes]` | Updates the checkout and applies the configuration. Asks before it removes packages that are not declared. `--yes` gives the answer yes. Updates the zsh plugin bundles. |
| `task rollback` | Activates the previous generation. |
| `task show` | Shows the evaluated configuration as JSON. |
| `task diff` | Shows the changes that `task install` will make. The Nix closure diff shows first. The new Homebrew packages show second. |
| `task validate` | Compares the live system with the configuration. Exits with code 1 if they are different. |
| `task audit [-- --strict]` | Shows the state that is not in the configuration. Shows known CVEs. With `--strict`, exits with code 1 if it finds a problem. |
| `task shell:startup-time` | Measures the cold start time of an interactive zsh. The limit is 500 ms. |
| `task check` | Evaluates each machine and each profile in the pinned Nix image. |
| `task lint` | Checks the zsh scripts and the Nix format. `tasks/lint.zsh` contains the rules. |
| `task fmt` | Formats the Nix files. |
| `task test` | Does the smoke tests and the negative evaluations. |

The `check`, `lint`, `fmt` and `test` tasks operate in the pinned Nix image. These tasks need
Apple `container` or Docker. If the Apple `container` daemon is on, the Taskfile uses it. If
not, the Taskfile uses Docker. To always use Docker, set `ENGINE=docker`.

Enter `task` to show the menu. The menu groups the tasks by their effect on the Mac. Enter
`task --list` to show the generated list.

## Where things live

- `docs/DECISIONS.md` contains the locked decisions and the scope.
- `docs/SECURITY.md` describes the trust chain of the bootstrap.
- `docs/MACHINES.md` describes the purpose and the hardware of each machine.
- The README in each top-level directory tells what belongs in that directory.
- `CLAUDE.md` lists the constraints that the files do not show.
