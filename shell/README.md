# shell

This directory contains the zsh configuration. Each login shell and each interactive shell
uses it. The switch links the five startup files into `$ZDOTDIR` (`~/.config/zsh`). These
links are out-of-store symlinks to the checkout. Thus a change here applies in the next shell.

## Files

- `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` and `.zlogout` are the startup files. zsh reads
  them in its documented sequence. Each file has one role:
  - `.zshenv` exports the XDG variables. zsh always reads it, so keep it small.
  - `.zprofile` operates for a login shell. It loads the Homebrew shellenv. Then it reads
    each fragment in `$XDG_STATE_HOME/dotfiles/env.d/`.
  - `.zshrc` operates for an interactive shell. It loads antidote, the theme and the
    functions. Then it reads each file in `$XDG_STATE_HOME/dotfiles/aliases.d/`.
  - `.zlogin` operates after `.zshrc` for a login shell. It shows the MOTD.
  - `.zlogout` operates when a login shell exits.
- `theme.zsh` starts the Starship prompt and sets the man-page and grc colours. `.zshrc` reads
  it after antidote loads the OMZ library and the plugins. The prompt itself is
  `apps/starship/starship.toml`. Terminal.app cannot draw the rounded pill ends, so
  `theme.zsh` gives it a copy with square ends, in `$XDG_CACHE_HOME/starship/`.
- `.zsh_plugins.txt` is the antidote plugin manifest. `use-omz` must be the first entry.
- `aliases/<topic>.zsh` contains the aliases for one shell-level topic. The topics are
  general, dotfiles, hardware, networking and jgrid. `modules/shell.nix` registers each file
  in `dotfiles.shell.aliases`.
- The aliases of an app or a System Settings concern are in the directory of that owner. For
  example, `apps/<name>/aliases.zsh` and `system/finder/aliases.zsh`. The owner registers
  them.
- An alias file has no gate. The switch links the file into `aliases.d/` only when its owner
  is on. `.zshrc` reads the files that are there.
- `functions/<name>.zsh` contains one function. The filename is the function name.
- `functions/helpers/_dotfiles_<name>.zsh` contains a private primitive. The functions use
  these primitives. `.zshrc` reads them first.
- `motd/` contains the Tron quotes, the fastfetch configuration and the jgrid logo. `motd.zsh`
  reads them when it shows the MOTD. The switch links no file in this directory.

## Add a shell-level alias topic

1. Create `aliases/<topic>.zsh` with the banner.
2. In `modules/shell.nix`, add `<topic> = "shell/aliases/<topic>.zsh"` to
   `dotfiles.shell.aliases`. If the topic depends on an option, put it in
   `lib.optionalAttrs`.
3. Enter `task install`.

## Add aliases for an app or a concern

1. Create `apps/<name>/aliases.zsh` or `system/<concern>/aliases.zsh`.
2. In the `default.nix` of that directory, register the file as
   `dotfiles.shell.aliases.<name>`.

## Add a login-shell fragment

Use a fragment for an environment variable that an app needs.

1. Create `apps/<name>/env.zsh`.
2. Register the file as `dotfiles.shell.env.<name>`. `.zprofile` reads it.

## Add a function

1. Create `functions/<name>.zsh`.
2. Put the docstring comment on the line that defines the function. `aliaslist` and
   `functionlist` read this comment.

A primitive that other functions call goes in `functions/helpers/`. Its name starts with
`_dotfiles_`.

## Performance budget

A cold interactive shell must start in less than 500 ms. On a Mac, `task test` measures the
start time with `hyperfine --warmup 1 --runs 5 'zsh -lic exit'`. The test fails if the time is
more than the limit in `Taskfile.yml`. Measure again after each change to a plugin or
a startup file.

## References

- `../CLAUDE.md` contains the project conventions.
- `../docs/DECISIONS.md` tells why the terminal uses the zsh of this repository.
