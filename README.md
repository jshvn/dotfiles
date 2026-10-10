# Josh's dotfiles

[![ci](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml)

macOS laptops declared as one nix-darwin configuration per machine. Nix evaluates the
declaration and activates it; Homebrew installs every package; the shell is the repo's own
zsh, linked straight from the checkout (out-of-store symlinks) so an edit is live in the next
shell.

## Install

### Fresh machine

```zsh
git clone https://github.com/jshvn/dotfiles.git ~/Git/personal/dotfiles
cd ~/Git/personal/dotfiles
# Homebrew, go-task and Nix. The Homebrew and Nix installers are consent-gated, Nix needs sudo
./bootstrap.zsh
# lerasium or harmonium
task setup -- <machine>
```

Then open a new terminal (the Nix installer put `nix` on an interactive shell's PATH) and do
the first switch. The checkout path is fixed: `dotfiles.checkout` in `modules/default.nix`
is where every link points.

### First switch

Once per machine. nix-darwin refuses to overwrite `/etc` files it did not write, home-manager
refuses to replace paths it does not own, and Homebrew cleanup must not run before its audit
has been read.

```zsh
cd ~/Git/personal/dotfiles
export NIX_CONFIG='experimental-features = nix-command flakes'
M=$(cat ~/.local/state/dotfiles/machine)
# Homebrew cleanup stays off until the audit is read
sed -i '' 's/cleanup = "uninstall"/cleanup = "none"/' modules/homebrew.nix
# build the closure, no sudo
nix build ".#darwinConfigurations.$M.system"
# clear the way for home-manager, only if the build produced darwin-rebuild
test -x result/sw/bin/darwin-rebuild && task show | jq -r '.links | keys[]' | while read -r p; do
  if [[ -L ~/$p ]]; then rm ~/$p; elif [[ -e ~/$p ]]; then mv ~/$p ~/$p.before-v3; fi; done
# Run the next line as one command, and open no new terminal until it finishes,
# because between the move and the switch a new shell finds no ZDOTDIR.
test -x result/sw/bin/darwin-rebuild && sudo sh -c 'for f in /etc/zshenv /etc/shells; do [ -e $f ] && [ ! -L $f ] && mv $f $f.before-nix-darwin; done; true' && sudo env NIX_CONFIG="$NIX_CONFIG" ./result/sw/bin/darwin-rebuild switch --flake ".#$M"
```

If the switch stops at "Unexpected files in /etc", rename what it lists with the
`.before-nix-darwin` suffix and run the last command again. If it stops at "Build user group
has mismatching GID", set `ids.gids.nixbld` in `modules/default.nix` to the GID it reports,
`git add`, rebuild, switch again. Open a new terminal, then:

```zsh
cd ~/Git/personal/dotfiles
# every declared thing is on the machine
task validate
# what is on the machine beyond the declaration: read "Would uninstall"
task audit
# Homebrew cleanup back on
git checkout -- modules/homebrew.nix
# the second switch removes what the audit listed
task install
```

Remove the `*.before-v3` paths and anything else `task audit` lists; `task validate` and
`task audit` are then clean.

### Update

```zsh
# the update alias runs task install from any directory
update
```

`task install` fast-forwards the checkout (warn-only: offline, dirty or diverged never block),
builds and activates the selected machine with `darwin-rebuild switch` (sudo), and refreshes
the antidote bundles.

## Commands

| Command | Purpose |
|---------|---------|
| `task setup -- <machine>` | Persist the machine selection |
| `task install` | Fast-forward, switch, refresh plugin bundles |
| `task rollback` | Activate the previous generation |
| `task show` | The evaluated declaration as JSON |
| `task diff` | What install would change: the closure diff, then what brew bundle would add |
| `task validate` | Read the whole declaration back from the live system (exits 1 on drift) |
| `task audit [-- --strict]` | State beyond the declaration, known CVEs |
| `task shell:startup-time` | Cold interactive zsh start against the 500 ms budget |
| `task check` | Evaluate every machine and profile in the pinned nix image |
| `task lint` | zsh parse, `set -euo`, banners, no hardcoded prefix; `nix fmt -- --ci` |
| `task fmt` | Format the Nix sources in place |
| `task test` | Smoke tests and the negative evaluations |

`task check`, `lint`, `fmt` and `test` run in the pinned nix image, so they need Apple
`container` (daemon up) or Docker; the Taskfile uses `container` when its daemon is up, else
Docker, and `ENGINE=docker` forces Docker.

Run `task` for the banner; `task --list` for descriptions.

## Where things live

- `docs/DECISIONS.md` -- locked decisions and scope; `docs/SECURITY.md` -- bootstrap trust
  chain; `docs/MACHINES.md` -- per-machine purpose and hardware.
- Each top-level directory's README says what belongs there; `CLAUDE.md` has the gotchas.
