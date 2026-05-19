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
  Roughly 30 formulas: shell tooling (zsh, antigen, go-task; antidote
  was evaluated in Phase 3 D-01 and reverted -- see `../shell/.zshrc:75`
  comment for rationale), text and search (jq, yq, ripgrep-substitutes
  via bat/eza/fd, grep, glow,
  highlight), system inspectors (htop, bottom, fastfetch, onefetch),
  network tools (cloudflared, doggo, whois, trippy), and the
  1Password command-line tool as a binary-only cask
  (`cask '1password-cli'`; the `op` binary is installed under the
  Homebrew prefix and verified by `task packages:verify` via the
  `brew info` artifacts path -- see Verify rules below).
- `gui.rb` -- laptop GUI baseline. Any machine with a display includes
  this (laptops add `"gui"` to `bundles`; servers omit it -- PKGS-05).
  Minimum set: 1Password + Ghostty. Other GUI apps (Slack, Discord, VS
  Code, Office, Docker Desktop, MAS apps, etc.) live per-machine in the
  manifest TOML's `extra_packages.casks` and `extra_packages.mas`.
- `../manifests/machines/<name>.toml`
  `[packages.brew.extra_packages]` -- per-machine package extras typed
  sub-table. `formulae` accepts bare strings (default verify) or
  `{ name, verify }` objects (override). `casks` takes `{ name }`
  objects -- no per-entry `verify` field required (data-driven from
  `brew info` post-Gap-2 pivot). `mas` REQUIRES `{ id, name }` objects
  (id drives install; name drives the `/Applications/<name>.app`
  verify -- D-06).

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
  (bare strings OR `{ name, verify }` objects), `casks` (bare
  `{ name }` objects -- no verify field required), `mas` (REQUIRED
  `{ id, name }` objects). The resolver concat+dedupes each sub-array
  with the defaults at resolve time; the composer renders one Ruby DSL
  line per entry into the cached Brewfile.
- **Verify metadata.** No per-line annotations are required in bundle
  files and no per-cask `verify` field is required in machine TOMLs.
  Verify is data-driven from `brew info` post-Gap-2 pivot. See
  `## Verify rules` below for the user-facing model and
  `../docs/MANIFEST.md` `## Verify model` for the canonical reference.

## Verify rules

`task packages:verify` uses a two-layer model to confirm every declared
package is correctly installed.

**Layer 1** -- `brew bundle check --no-upgrade --file="$XDG_CACHE_HOME/dotfiles/Brewfile"`
confirms every package declared in the composed Brewfile is installed per
Homebrew's view of the world. Sub-second on a converged machine.

**Layer 2** -- `brew info --installed --json=v2` returns the full set of
installed formulae and casks with their artifact paths. `task packages:verify`
parses the artifact entries and asserts each declared artifact path actually
exists on disk.

For the canonical schema-level reference see `../docs/MANIFEST.md`
`## Verify model`.

**MAS exception.** Apple App Store apps have no `brew info` equivalent.
The `name` field in each `{ id, name }` MAS entry doubles as both the
install-list display name and the verify target
(`/Applications/<name>.app` existence check). This is the one place
per-entry verify metadata is still authored in v2 -- D-06 preserved.

**Failure semantics.** Verify is hard-fail at the install gate per D-10:
`task install`'s final step is `task packages:verify`; a missing artifact
fails the entire `task install` with exit 1 after printing the full
check/cross table. The recovery path is "fix the manifest or the upstream
formula/cask, re-run `task install`." No `--no-verify` escape hatch.

**Retired conventions.** The per-line verify comment annotations and
the `bin:` prefix convention used in earlier Phase 5 plans are retired.
Authors of new bundles or machine extras do NOT write per-line verify
annotations -- the `brew info` bulk path is authoritative and the
annotation metadata went stale on upstream renames (Gap 2 surface area,
discovered during Phase 5 UAT).

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

- `../docs/MANIFEST.md` -- manifest schema, merge semantics, and the
  `## Verify model` section (canonical two-layer verify reference)
- `../CLAUDE.md` -- v2 conventions (flat directories, one concept per
  file, no `packages/brew/` subdirectory)
- `../.planning/REQUIREMENTS.md` -- PKGS-01..05 + VRFY-01..04 + DOCS-02
  traceability
