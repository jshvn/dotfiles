# shell

Zsh startup files, theme, functions, shell-level aliases and the MOTD. Sourced by every login
or interactive shell on a converged machine. The switch links the five startup files into
`$ZDOTDIR` (`~/.config/zsh`) out of the Nix store, so an edit here is live in the next shell.

## Key files

- `.zshenv` / `.zprofile` / `.zshrc` / `.zlogin` / `.zlogout` -- startup files in zsh's
  documented order; one role per file. `.zshenv` exports XDG vars and is always sourced (must
  stay minimal). `.zprofile` runs on login (Homebrew shellenv, then every fragment in
  `$XDG_STATE_HOME/dotfiles/env.d/`), `.zshrc` on interactive (antidote, theme, functions,
  then every file in `$XDG_STATE_HOME/dotfiles/aliases.d/`), `.zlogin` after `.zshrc` on
  login (MOTD), `.zlogout` on login-shell exit.
- `theme.zsh` -- alanpeabody-based prompt; consumed by `.zshrc` after antidote loads OMZ lib
  and plugins.
- `.zsh_plugins.txt` -- antidote plugin manifest. use-omz must stay first.
- `aliases/<topic>.zsh` -- shell-level topics only (general, dotfiles, hardware, networking,
  jgrid), registered in `modules/shell.nix` under `dotfiles.shell.aliases`. An app's or a
  System Settings concern's aliases live beside it (`apps/<name>/aliases.zsh`,
  `system/finder/aliases.zsh`) and are registered there. There is no gate inside an alias
  file: the switch links it into `aliases.d/` only when its owner is on, and `.zshrc` sources
  what is there.
- `functions/<name>.zsh` -- one function per file; the filename equals the function name.
- `functions/helpers/_dotfiles_<name>.zsh` -- private primitives the above build on, sourced
  first.
- `motd/` -- the Tron quotes, the fastfetch config and the jgrid logo `motd.zsh` reads at
  render time; nothing here is linked.

## Adding a pattern

- **A shell-level alias topic.** Create `aliases/<topic>.zsh` with the banner, add
  `<topic> = "shell/aliases/<topic>.zsh"` to `dotfiles.shell.aliases` in `modules/shell.nix`
  (under `lib.optionalAttrs` if it depends on a switch), `task install`.
- **An app's or concern's aliases.** `apps/<name>/aliases.zsh` or
  `system/<concern>/aliases.zsh`, registered in that `default.nix` as
  `dotfiles.shell.aliases.<name>`.
- **A login-shell fragment** (an environment variable an app needs). `apps/<name>/env.zsh`,
  registered as `dotfiles.shell.env.<name>`; `.zprofile` sources it.
- **A function.** `functions/<name>.zsh`; add the docstring comment on the
  function-definition line (the `aliaslist` / `functionlist` convention). A primitive other
  functions call goes in `functions/helpers/` with a `_dotfiles_` prefix.

## Performance budget

Cold interactive shell start under 500 ms, measured by `task shell:startup-time`
(`hyperfine --warmup 1 --runs 5 'zsh -lic exit'`, failing above the budget set in
`Taskfile.yml`). Re-measure on every plugin change or startup-file edit.

## References

- `../CLAUDE.md` -- project conventions
- `../docs/DECISIONS.md` -- why the terminal must not change
