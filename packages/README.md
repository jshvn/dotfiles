# packages

Per-purpose Homebrew bundles for v2 machines. Each bundle is a small shared
baseline -- the bulk of per-machine variation lives in
`../manifests/machines/<name>.toml` under `[packages.brew.extra_packages]`
(typed sub-table: `formulae`, `casks`, `mas`). v1 ships two bundles only
(`core.rb`, `gui.rb`) -- adding `dev.rb`/`ops.rb`/`personal.rb` is a future
extension when a tool is wanted on two or more machines and has no
per-machine variation (D-02 minimal-bundles philosophy). macOS-only in v1;
the flat layout (no `packages/brew/` subdirectory) collapses when Linux is
in scope -- see `../.planning/ROADMAP.md` for the deferred migration cost.

## Key files

- `core.rb` -- server-safe CLI baseline. Every machine includes this
  (every machine TOML's `bundles = [...]` array contains `"core"`).
  Roughly 30 formulas: shell tooling (zsh, antidote, go-task), text and
  search (jq, yq, ripgrep-substitutes via bat/eza/fd, grep, glow,
  highlight), system inspectors (htop, bottom, fastfetch, onefetch),
  network tools (cloudflared, doggo, whois, trippy), and the
  1Password command-line tool as a binary-only cask
  (`cask '1password-cli' # verify: bin:op` -- see Verify rules).
- `gui.rb` -- laptop GUI baseline. Any machine with a display includes
  this (laptops add `"gui"` to `bundles`; servers omit it -- PKGS-05).
  Minimum set: 1Password + Ghostty. Other GUI apps (Slack, Discord, VS
  Code, Office, Docker Desktop, MAS apps, etc.) live per-machine in the
  manifest TOML's `extra_packages.casks` and `extra_packages.mas`.
- `../manifests/machines/<name>.toml`
  `[packages.brew.extra_packages]` -- per-machine package extras typed
  sub-table. `formulae` accepts bare strings (default verify) or
  `{ name, verify }` objects (override). `casks` REQUIRES
  `{ name, verify }` objects on every entry (no derivation -- D-04).
  `mas` REQUIRES `{ id, name }` objects (id drives install; name drives
  the `/Applications/<name>.app` verify -- D-06).

## Adding a pattern

- **A bundle.** When? Only when a tool is wanted on two or more
  machines AND has no per-machine variation. Create
  `packages/<purpose>.rb`; add `<purpose>` to the relevant machines'
  `bundles = [...]`. v1 ships `core` and `gui` only -- adding `dev` or
  `ops` is acknowledged as a future extension (door open per D-02);
  premature bundle creation makes the per-machine-extras-as-catalog UX
  feel split.
- **A per-machine package.** Edit
  `../manifests/machines/<name>.toml`
  `[packages.brew.extra_packages]` typed sub-table (D-03): `formulae`
  (bare strings OR `{ name, verify }` objects), `casks` (REQUIRED
  `{ name, verify }` objects per D-04), `mas` (REQUIRED
  `{ id, name }` objects). The resolver concat+dedupes each sub-array
  with the defaults at resolve time; the composer renders one Ruby DSL
  line per entry into the cached Brewfile.
- **A verify-comment override.** When? Formula bin name differs from
  formula name (e.g. `bottom` ships `btm`, `git-delta` ships `delta`).
  Add `# verify: <bin>` suffix to the bundle line per D-05. Reminder:
  cask `# verify: <App>` is MANDATORY on every line -- there is no
  default and no derivation (D-04); a missing cask verify comment fails
  lint (LINT-09, Plan 04).

## Verify rules

`task packages:verify` (Plan 04) enforces:

- Formula default: `command -v <formula-name>` (e.g. `brew 'jq'`
  verifies `command -v jq`).
- Formula override: `command -v <bin>` from the `# verify: <bin>`
  comment (e.g. `brew 'git-delta' # verify: delta` verifies
  `command -v delta`).
- Cask: `test -d /Applications/<App>.app` from the mandatory
  `# verify: <App>` comment (e.g.
  `cask 'ghostty' # verify: Ghostty` verifies
  `test -d /Applications/Ghostty.app`).
- Cask (binary-only, gap-1): `command -v <bin>` from the
  `# verify: bin:<bin>` comment. Used for casks that ship a CLI
  binary instead of an `.app` bundle (e.g.
  `cask '1password-cli' # verify: bin:op` verifies
  `command -v op`, since Homebrew installs `op` to
  `/opt/homebrew/bin/` with no `/Applications/.app` artifact). The
  `bin:` prefix is the explicit opt-in -- bare `# verify: <App>`
  still defaults to the `/Applications/<App>.app` check.
- MAS: `test -d /Applications/<name>.app` where `<name>` is the `name`
  field of the `{ id, name }` object (D-06).

Verify runs as the final step of `task install` and is hard-fail with no
escape hatch -- D-10. Failures emit a check/cross table and exit
non-zero; the recovery path is "fix the manifest or the upstream
formula/cask, re-run `task install`."

## Composed Brewfile cache

The per-machine composed Brewfile lives at
`$XDG_CACHE_HOME/dotfiles/Brewfile` (D-08; CF-07 -- XDG cache, not
state, because it is cheaply regenerated). The composer (Plan 03) reads
the active machine's `packages.brew.bundles` array from
`$XDG_STATE_HOME/dotfiles/resolved.json`, concatenates each
`packages/<bundle>.rb` in declared order, then appends the rendered
typed-bucket extras (formulae, casks, mas, in that fixed order).

The cached Brewfile is overwritten atomically (mktemp+mv) on every
`task packages:install` run. Do NOT edit it by hand -- regeneration
clobbers manual changes. Inspect via `task packages:compose` (writes
the cache and prints the path) or `cat
$XDG_CACHE_HOME/dotfiles/Brewfile` after a run.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics,
  including the `[packages.brew.extra_packages]` typed sub-table
- `../CLAUDE.md` -- v2 conventions (flat directories, one concept per
  file, no `packages/brew/` subdirectory)
- `../.planning/REQUIREMENTS.md` -- PKGS-01..05 + VRFY-01..04 + DOCS-02
  traceability
