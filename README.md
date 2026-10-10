# Josh's dotfiles

[![ci](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml)

macOS laptops declared as one nix-darwin configuration per machine. Nix evaluates the
declaration and activates it; Homebrew installs every package; the shell is the repo's own
zsh, linked out of the Nix store so an edit is live in the next shell.

## Install

### Fresh machine

```zsh
git clone https://github.com/jshvn/dotfiles.git ~/Git/personal/dotfiles
cd ~/Git/personal/dotfiles
./bootstrap.zsh              # Homebrew, go-task, Nix (each consent-gated; Nix needs sudo)
task setup -- <machine>      # lerasium or harmonium
```

Then open a new terminal (the Nix installer put `nix` on an interactive shell's PATH) and do
the first switch. The checkout path is fixed: `dotfiles.checkout` in `modules/default.nix`
is where every link points.

### First switch

Once per machine. nix-darwin refuses to overwrite `/etc` files it did not write, home-manager
refuses to replace paths it does not own, and Homebrew cleanup must not run before its audit
has been read.

```zsh
export NIX_CONFIG='experimental-features = nix-command flakes'
M=$(cat ~/.local/state/dotfiles/machine)
sed -i '' 's/cleanup = "uninstall"/cleanup = "none"/' modules/homebrew.nix   # until the audit is read
task show | jq -r '.links | keys[]' | while read -r p; do          # clear the way for home-manager
  if [[ -L ~/$p ]]; then rm ~/$p; elif [[ -e ~/$p ]]; then mv ~/$p ~/$p.before-v3; fi; done
nix build ".#darwinConfigurations.$M.system"                      # the closure, no sudo
sudo sh -c 'for f in /etc/zshenv /etc/shells; do [ -e $f ] && [ ! -L $f ] && mv $f $f.before-nix-darwin; done; true'
sudo env NIX_CONFIG="$NIX_CONFIG" ./result/sw/bin/darwin-rebuild switch --flake ".#$M"
```

If the switch stops at "Unexpected files in /etc", rename what it lists with the
`.before-nix-darwin` suffix and run the last command again. If it stops at "Build user group
has mismatching GID", set `ids.gids.nixbld` in `modules/default.nix` to the GID it reports,
`git add`, rebuild, switch again. Open a new terminal, then:

```zsh
task validate          # every declared thing is on the machine
task audit             # what is on the machine beyond the declaration: read "Would uninstall"
git checkout -- modules/homebrew.nix   # cleanup back on
task install           # the second switch removes what the audit listed
```

Remove the `*.before-v3` paths and anything else `task audit` lists; `task validate` and
`task audit` are then clean.

### Update

```zsh
update                 # task -d "$DOTFILEDIR" install
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

Run `task` for the banner; `task --list` for descriptions.

## Where things live

- `docs/DECISIONS.md` -- locked decisions and scope; `docs/SECURITY.md` -- bootstrap trust
  chain; `docs/MACHINES.md` -- per-machine purpose and hardware.
- Each top-level directory's README says what belongs there; `CLAUDE.md` has the gotchas.
