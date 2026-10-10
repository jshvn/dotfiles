# Josh's dotfiles

[![ci](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml)

macOS laptops declared as one nix-darwin configuration per machine. Nix evaluates the
declaration and activates it; Homebrew installs every package; the shell is the repo's own
zsh, linked straight from the checkout (out-of-store symlinks) so an edit is live in the next
shell.

## Install

One command per Mac, fresh or already set up:

```zsh
git clone https://github.com/jshvn/dotfiles.git ~/Git/personal/dotfiles
cd ~/Git/personal/dotfiles
# lerasium or harmonium
./bootstrap.zsh <machine>
```

`bootstrap.zsh` installs Nix (skipped when present; its installer asks first and needs sudo),
then runs go-task from the flake's pinned nixpkgs to select the machine with `task setup` and
run the first `task install`. That install's switch installs Homebrew with Homebrew's own
installer, then every package, go-task included. Re-running it is safe. Then open a new
terminal; from then on `update` is the only command. The checkout path is fixed: `dotfiles.checkout` in
`modules/default.nix` is where every link points.

On a factory-fresh Mac, before that:

- The first `git` command offers to install the Xcode Command Line Tools; accept, then clone.
- Sign in to the App Store: the profile installs Mac App Store apps through `mas`, and
  `brew bundle` fails without a signed-in App Store, which stops the switch.
- The jshvn/ai checkout clones over SSH through 1Password's agent, so on a fresh Mac that step
  only warns. Once 1Password is signed in with its SSH agent on, run `task install` again.

The first `task install` on a Mac clears the way itself: it removes the symlinks at every path
home-manager will link, moves anything else there to `<path>.before-dotfiles` (check those,
then delete them), and moves `/etc/zshenv` and `/etc/shells` to `*.before-nix-darwin`, all only
after the build succeeds.

If a first install stops partway (a cask download, the App Store), fix the cause and run
`./bootstrap.zsh <machine>` again: until the switch completes, a terminal has an empty zsh
config and may have no Homebrew, so `task` is not on its PATH. If the switch stops at
"Unexpected files in /etc", rename each file it lists to `<file>.before-nix-darwin` (sudo) and
run `task install` again. If it stops at "Build user group has mismatching GID", set
`ids.gids.nixbld` in `modules/default.nix` to the GID it reports and run `task install` again.
If home-manager reports a path it "would clobber" (a file that appeared where a newly
registered link goes), move it aside and run `task install` again.

### Update

```zsh
# the update alias runs task install from any directory
update
```

`task install` fast-forwards the checkout (warn-only: offline, dirty or diverged never block),
builds and activates the selected machine with `darwin-rebuild switch` (sudo), then lists what
Homebrew has installed beyond the declaration and uninstalls it only if you say yes (`task install
-- --yes` answers yes up front; the switch itself never uninstalls), and refreshes the antidote
bundles.

## Commands

| Command | Purpose |
|---------|---------|
| `task setup -- <machine>` | Persist the machine selection |
| `task install [-- --yes]` | Fast-forward, build and switch, uninstall what is no longer declared after asking, refresh plugin bundles |
| `task rollback` | Activate the previous generation |
| `task show` | The evaluated declaration as JSON |
| `task diff` | What install would change: the closure diff, then what brew bundle would add |
| `task validate` | Read the whole declaration back from the live system (exits 1 on drift) |
| `task audit [-- --strict]` | State beyond the declaration, known CVEs |
| `task shell:startup-time` | Cold interactive zsh start against the 500 ms budget |
| `task check` | Evaluate every machine and profile in the pinned nix image |
| `task lint` | zsh parse, `set -euo`, banners, no hardcoded prefix, every task in the menu; `nix fmt -- --ci` |
| `task fmt` | Format the Nix sources in place |
| `task test` | Smoke tests and the negative evaluations |

`task check`, `lint`, `fmt` and `test` run in the pinned nix image, so they need Apple
`container` (daemon up) or Docker; the Taskfile uses `container` when its daemon is up, else
Docker, and `ENGINE=docker` forces Docker.

Run `task` for the menu, grouped by what each task does to the Mac; `task --list` for the
generated view.

## Where things live

- `docs/DECISIONS.md` -- locked decisions and scope; `docs/SECURITY.md` -- bootstrap trust
  chain; `docs/MACHINES.md` -- per-machine purpose and hardware.
- Each top-level directory's README says what belongs there; `CLAUDE.md` has the gotchas.
