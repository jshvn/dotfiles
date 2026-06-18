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
  antigen loads `ohmyzsh/ohmyzsh git` (the v1 prompt is small, fast, and
  not on life support; no Starship swap in v1). antidote was evaluated
  and reverted; see `.zshrc:75` comment for rationale.
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
- **A feature flag.** Add the kebab-case key to `../manifests/defaults.toml`
  `[features]` with `false`. Set `true` in the machine TOMLs that want
  it. Consumers call `_dotfiles_feature <key>` to test.

## Performance budget

Cold interactive shell start: <= 200ms (SHEL-12). Measured via
`task shell:startup-time`, which runs `hyperfine --warmup 1 --runs 5 'zsh
-lic exit'` and fails non-zero when the 5-run mean exceeds the budget.
Re-measure on every plugin change or startup-file edit.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics
- `../CLAUDE.md` -- v2 conventions (flat directories, one concept per
  file, status-block templating rules)
