# modules

Plumbing: the options every profile sets and the machinery that turns them into nix-darwin and
home-manager configuration. Nothing here is named by a profile directly; a profile only sets
`dotfiles.*` options.

| File | Owns |
|------|------|
| `default.nix` | the imports; `dotfiles.checkout` (where every link points), `dotfiles.profile` (an enum of the directories under `profiles/`) and `dotfiles.links` (the one link registry, installed by home-manager as out-of-store symlinks); the one user and its login shell; Nix's own housekeeping (flakes on, weekly GC) |
| `packages.nix` | `dotfiles.packages.*` (a profile's free choices) and `dotfiles.provided.*` (what base and enabled apps contribute); the redundancy assertion; tap derivation; what reaches `homebrew.brews`, `casks`, `masApps`, `taps` |
| `base.nix` | the unconditional formulae (the bootstrap toolchain and what `shell/` breaks without) and the one bare tap, `homebrew/brew-vulns` |
| `homebrew.nix` | installing Homebrew itself when it is missing, just before `brew bundle`; `homebrew.onActivation`: update and upgrade on every switch; cleanup stays off, because `task install` uninstalls only after asking |
| `shell.nix` | the login shell's entry in `/etc/shells`, `/etc/zshenv`, the startup-file links, `dotfiles.shell.aliases` and `.env` (what the switch links into `aliases.d/` and `env.d/`), `shell.jgrid-net` |
| `repo.nix` | `repo.devToolchain` |

Rules that live here and fail evaluation when broken:

- an unaccounted switch: every optional option is declared without a default;
- a redundant package: `packages.nix` intersects a profile's lists with `provided`;
- a bundled extension listed again: `apps/vscode/default.nix`;
- a profile naming no `profiles/` directory: `dotfiles.profile` in `default.nix`.

`tasks/tests/negative.sh` proves each by breaking it.

## Adding a module

Declare options with `lib.mkOption` and no default where a profile must choose. Contribute
packages through `dotfiles.provided.*`, links through `dotfiles.links`, shell integration
through `dotfiles.shell.aliases` and `.env`. Import it from `default.nix`.
