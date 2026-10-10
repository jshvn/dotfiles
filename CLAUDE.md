# Dotfiles v3 -- Project Instructions for AI Agents

## What This Is

macOS laptops declared as one nix-darwin configuration each. `machines/<name>.nix` names the
laptop and imports a profile (lerasium and harmonium import `profiles/personal.nix`); the
profile sets every option; `modules/`, `system/` and `apps/` declare the options and turn them
into nix-darwin and home-manager configuration. Nix evaluates and activates; Homebrew installs
every package; the shell is the repo's own zsh, linked straight from the checkout
(out-of-store symlinks) so an edit is live without a switch.

Three stages: evaluate (`nix eval` of the selected machine, the `SHAPE` in `Taskfile.yml`),
activate (`task install`: fast-forward, `darwin-rebuild switch`, antidote bundles), read back
(`task validate` walks the evaluation against the live system).

| Concept | Location |
|---------|----------|
| Machine (hostname, platform, profile import) | `machines/<name>.nix` |
| Profile (every switch, identity, free packages) | `profiles/<name>.nix` |
| Plumbing (user, link registry, packages, identity, shell, homebrew) | `modules/` |
| macOS settings, one file per System Settings concern | `system/` |
| Applications, one directory each | `apps/` |
| What the Taskfile runs, and the tests | `tasks/`, `tasks/tests/` |
| Shell startup files, theme, functions, shell-level aliases, MOTD | `shell/` |
| Git and SSH identities, public keys | `identity/` |
| Active machine name (machine-local) | `$XDG_STATE_HOME/dotfiles/machine` |
| Alias and login-env gates (machine-local, made by the switch) | `$XDG_STATE_HOME/dotfiles/aliases.d/`, `env.d/` |

## Finding Things

- Locked decisions, scope boundaries, constraints: `docs/DECISIONS.md`. Revisit only with
  new evidence.
- Every top-level concept directory has a README saying what belongs there and how to name it.
- Operator surface: `setup`, `install`, `rollback`; `show`, `diff`, `validate`, `audit`,
  `shell:startup-time`; `check`, `lint`, `fmt`, `test`. Bare `task` prints the banner.
- Verifying a change: the `jshvn-verifying-dotfiles-changes` skill (change type to exact
  commands, the tier model, the one-check rule).

## Gotchas

What the file system will not tell you:

- `nix flake check` on a git checkout sees only tracked or staged files. `git add -A` before
  `task check`, or a new file is silently absent from the evaluation.
- Every optional option has no default (`system.<concern>`, `apps.<name>.enable`,
  `shell.jgrid-net`, `repo.devToolchain`, `apps.raycast.freeCmdSpace`). Adding one means
  setting it in every profile, `work.nix` included, or `task check` fails naming it.
- A profile may not list a formula or cask base or an enabled app provides, nor an extension
  VS Code bundles: an assertion fails. Taps are derived from tap-qualified names; the one bare
  tap is in `modules/base.nix`.
- `dotfiles.apps."1password".enable` is readOnly: the identity sets it.
- Links only through `dotfiles.links` (home path to checkout path). Shell integration only
  through `dotfiles.shell.aliases` and `dotfiles.shell.env`: the switch links an enabled
  owner's file into `aliases.d/` or `env.d/`, and the startup files source whatever is there.
  `.zshrc` globs `shell/functions/` directly and never globs `shell/aliases/`.
- Every read task runs one `nix eval` (`SHAPE`) and pipes the JSON on: `validate` and `audit`
  to a script in `tasks/`, `show` and `diff` to jq. `homebrew.casks` and `homebrew.taps` are
  lists of records: read `.name`. The eval prints one
  `trace: Obsolete option ... expose-group-by-app` line; it is noise.
- Activation runs as root. A step that must run as the user is
  `sudo -u ${config.system.primaryUser} -H ...` with an explicit `PATH` if it needs Homebrew.
  What an activation script runs is copied into the store with its generation (`${./.}`,
  `${./file}`); everything else is linked straight from the checkout. nix-darwin's activate
  runs under `set -e` and moves `/run/current-system` only after `postActivation`, so a user
  step that depends on the network or hardware ends in `|| echo ... >&2` and leaves the
  read-back to `task validate`.
- nix-darwin writes a nested defaults value whole, never merging: the Spotlight hotkey (entry
  64 of `AppleSymbolicHotKeys`) stays a `-dict-add` activation script in `apps/raycast/`.
  nix-darwin has no `-currentHost` writes: ByHost keys go through home-manager's
  `targets.darwin.currentHostDefaults`. `tasks/validate.zsh` reads every defaults key back; a
  nix-darwin group it has no row for is a cross, so a new group needs a row in its `DOMAIN`
  table.
- This repo declares two `/etc` files: `/etc/zshenv` (the ZDOTDIR line) and `/etc/shells`
  (Homebrew zsh, through `environment.shells` in `modules/shell.nix`); nix-darwin also writes
  `/etc/nix/nix.conf` and others of its own. nix-darwin refuses any `/etc` file it did not
  write ("Unexpected files in /etc"): rename it `.before-nix-darwin`, as the README's First
  switch does for `/etc/zshenv` and `/etc/shells`. `programs.zsh` and `programs.bash` stay
  off; nix-darwin leaves Apple's `/etc/zshrc`, `/etc/zprofile` and `/etc/bashrc` alone, and
  the Nix installer's block at the top of `/etc/zshrc` and `/etc/bashrc` is what puts `nix`
  on an interactive shell's PATH. A non-interactive shell does not have it: `Taskfile.yml`
  calls nix by its absolute path, `/nix/var/nix/profiles/default/bin/nix` (`NIX`), because a
  Taskfile `env:` entry cannot override the caller's PATH.
- `task install` and `task rollback` run `sudo darwin-rebuild`, which prompts for a password.
  An agent cannot answer it: print the command, let Josh run it, read the result.
- Homebrew cleanup uninstalls what is not declared. The first switch on a new machine runs
  with `cleanup = "none"` and its `task audit` is read first (README, First switch).
- `path` is the zsh array tied to `$PATH`; never use it as a variable name. The `nixos/nix`
  image has no `sed`: mutate files in checks with bash `${var//old/new}`. `nix fmt` outside a
  git checkout needs `--tree-root`.
- `task diff` and the first switch leave a `result` symlink in the repo root; it is ignored.
- Executable `.zsh`: `set -euo pipefail`, the three-label banner (Purpose / Depends on / Side
  effects between `# ===` rules), messages via `tasks/messages.zsh`; `tasks/lint.zsh` enforces
  these plus `zsh -n` and no hardcoded `/opt/homebrew` or `/usr/local` outside a
  `# lint-allow: hardcoded-prefix` line. Scripts get the repo root as `DOTFILEDIR`; the
  Taskfile uses `{{.ROOT_DIR}}`.
- Machine identity is explicit (`task setup -- <name>`); never infer from hostname.
- One concept per file, flat directories: one alias topic / function / machine / profile /
  concern per file. The nestings that exist are `shell/functions/helpers/` (private
  primitives), `system/finder/` (a concern with shell integration) and every `apps/<name>/`.
- Tests live at `tasks/tests/`; `task test` is the single aggregator. The repo tree holds
  source only; no generated file is tracked.
- AI tooling config lives in `jshvn/ai` (`~/Git/personal/ai`): `apps.claude-code` clones it at
  the pinned ref and calls that repo's contract, `task setup -- <profile>` then `task install`,
  with `CLAUDE_CONFIG_DIR` passed explicitly (the claude CLI reads it; activation has no login
  environment); `task validate` runs its `task validate`. Dotfiles reads nothing else inside it.
- No AI attribution and no emojis anywhere, markdown included (hooks enforce both). Public
  keys only under `identity/ssh/keys/`.
