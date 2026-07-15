# shell

Zsh startup files, theme, aliases, and functions. Sourced by every login or
interactive shell on a converged machine. macOS-only; the flat layout (no
platform subdirectories) reflects that single-platform scope.

## Key files

- `.zshenv` / `.zprofile` / `.zshrc` / `.zlogin` / `.zlogout` -- startup
  files in zsh's documented order; one role per file. `.zshenv` exports
  XDG vars and is always sourced (must stay minimal). `.zprofile` runs on
  login, `.zshrc` on interactive, `.zlogin` after `.zshrc` on login, and
  `.zlogout` on login-shell exit.
- `theme.zsh` -- alanpeabody-based prompt; consumed by `.zshrc` after
  antidote loads OMZ lib + plugins (small, fast, not on life support;
  no Starship swap).
- `.zsh_plugins.txt` -- antidote plugin manifest; read via `antidote load`
  in `.zshrc`. use-omz must stay first; OMZ `path:lib` provides
  prompt_subst + git prompt helpers that `theme.zsh` requires.
- `aliases/<topic>.zsh` -- flat layout, one topic per file. Gating
  happens inside the file: wrapper functions for 1-3 aliases;
  source-time `return 0` for bulk-alias loops.
- `functions/<name>.zsh` -- flat layout, one function per file; the
  filename equals the function name. `_dotfiles_feature` is the lazy
  manifest reader callers use to test feature flags.

## Adding a pattern

- **An alias.** Create `aliases/<topic>.zsh`. If the alias is GUI-coupled
  or identity-coupled, gate inside the file: wrapper-function gate for
  1-3 aliases -- each function calls `_dotfiles_feature <name>`
  before delegating; source-time gate for bulk-alias loops --
  prepend `[[ "$(_dotfiles_feature <name>)" == "true" ]] || return 0`.
- **A function.** Create `functions/<name>.zsh`; the filename equals the
  function name. Add a docstring as an inline comment on the
  function-definition line (the `aliaslist` / `functionlist` discovery
  convention).
- **A feature flag.** Register the kebab-case key as a `[<key>]` block in
  `../manifests/features.toml` (with a `description`). Then account for it in
  every machine's `[features]`: add it to `enabled` on machines that want it,
  `disabled` on those that don't. Consumers call `_dotfiles_feature <key>`
  to test.

## Performance budget

Target: cold interactive shell start <= 200ms. Measured via
`task shell:startup-time`, which runs `hyperfine --warmup 1 --runs 5 'zsh
-lic exit'` and fails non-zero when the 5-run mean exceeds the
`COLD_START_BUDGET` gate (currently 500ms in `../taskfiles/shell.yml`).
Re-measure on every plugin change or startup-file edit.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics
- `../CLAUDE.md` -- project conventions (flat directories, one concept per
  file, status-block templating rules)
