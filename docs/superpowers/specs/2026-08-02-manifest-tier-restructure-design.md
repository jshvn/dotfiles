# Manifest Tier Restructure -- Design

**Date:** 2026-08-02
**Status:** approved, pending implementation plan
**Supersedes:** Task 8 / Phase 4 of the 2026-07-23 NixOS architecture
improvements plan (executed and deleted; see git history)

## Problem

A machine manifest does not tell you what is installed on that machine.
`work-laptop.toml` declares zero packages while installing 93 of them; the
rest arrive through `packages.bundles = [...]`, which resolves to six files
you must open and cross-reference. Answering "what is on this box?" means
reading seven files and mentally unioning them.

Six bundle files exist to express three distinct combinations:

| Machine | Bundles |
|---|---|
| personal-laptop | dotfiles, cli, dotfiles-gui, dev, productivity, apps |
| work-laptop | dotfiles, cli, dotfiles-gui, dev, productivity, apps |
| atium | dotfiles, cli, dotfiles-gui |
| ci | dotfiles, cli |

The two laptops are identical, so for them the abstraction buys nothing at
all. It is indirection without discrimination.

Duplication is not the counter-argument it first appears to be. Package
presence is not an invariant: personal-laptop having `bat` while work-laptop
does not is a decision, not a defect. Nothing breaks. This is unlike feature
accounting, where a missing flag means a broken symlink and total
explicitness is therefore enforced.

## Principle

NixOS has no bundle concept. Packages reach a system two ways: a flat
per-host list (`environment.systemPackages`), or a module pulling its own
packages as a side effect of being enabled (`services.nginx.enable = true`).
Below both sits a base system nobody declares. `nixpkgs` works as a catalog
without grouping because it is searchable, not because it is pre-sorted.

The rule taken from this: **a package appears in a machine file if and only
if it was a free choice.** Anything load-bearing is guaranteed structurally
and is therefore not worth reading.

## The three tiers

| Tier | Location | Rule | Size |
|---|---|---|---|
| Base | `manifests/base.toml` | Unconditional. Every machine running these dotfiles gets it. No machine names it. | 22 formulae |
| Feature-owned | `[<flag>.packages]` in `manifests/features.toml` | A concern owns its packages end-to-end. Enabling the flag pulls them; disabling drops them. | 5 flags |
| Discretionary | `[packages]` in `manifests/machines/<name>.toml` | Apps you chose. The only thing read to answer "what is on this box?" | 11 to 41 entries |

This maps directly onto NixOS's base system / modules / systemPackages.

## Target layout

```
manifests/
  base.toml            NEW   unconditional; no machine references it
  features.toml              + [<flag>.packages] tables on 5 flags
  machines/<name>.toml       [packages] discretionary only; `bundles` key gone
  bundles/             DELETED (all 6 files)
```

### base.toml (22 formulae, no casks)

```
antidote  cloudflared  coreutils  eza     fastfetch  git    git-delta
go-task   grc          grep       highlight  jq       libpsl  mas
ncdu      onefetch     openssh    tlrc    trippy     whois   yq      zsh
```

Bootstrap toolchain (the resolver and task system cannot run without it) plus
shell-config dependencies (aliases, functions and configs break without it).

### Flag to package mapping

```toml
[repo-dev-toolchain]                  # NEW flag
formulae = ["biome", "hyperfine", "ruff", "shellcheck", "shfmt", "taplo"]

[vscode]                              # NEW flag
casks  = ["visual-studio-code"]
vscode = [ ... 29 extension ids ... ]

[ghostty]              casks = ["ghostty"]
[one-password-ssh]     casks = ["1password"]   # provides the agent socket
[one-password-signing] casks = ["1password"]   # provides op-ssh-sign; union dedupes
```

`op-ssh-sign` resolves to `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`
in both git identity overlays, so the GUI cask is what the two 1Password flags
require. Nothing in the repo consumes the `op` CLI, so `1password-cli` is
discretionary.

`[vscode.packages] vscode = [...]` reads awkwardly -- flag name and bucket name
collide. `vscode` is still preferred over `visual-studio-code`; the nesting is
visible in one file only.

### New flag accounting

| Flag | personal-laptop | work-laptop | atium | ci |
|---|---|---|---|---|
| repo-dev-toolchain | enabled | enabled | disabled | enabled |
| vscode | enabled | enabled | disabled | disabled |

`ci` enables `repo-dev-toolchain` because it runs `task lint` and `task test`.
Same package set as today, now justified rather than inherited.

### Resulting machine files

Installed counts below are from `install/resolver.zsh --stdout`, not estimated.

| Machine | Today | After |
|---|---|---|
| personal-laptop | 62 lines, 8 declared, 101 installed | ~50 lines, 41 declared |
| work-laptop | 42 lines, 0 declared, 93 installed | ~45 lines, 33 declared |
| atium | 50 lines, 5 declared, 47 installed | ~30 lines, 17 declared |
| ci | 47 lines, 0 declared, 40 installed | ~25 lines, 11 declared |

The gap between "declared" and "installed" is the problem in one column.

## Schema v3

`packages.bundles` is currently required, non-empty, and must contain
`"dotfiles"`. All three rules disappear, so `schema_version` goes 2 to 3.
Four machine files, one author, no external consumers: no compatibility shim.
The resolver hard-errors on `schema_version = 2` with a message naming the
migration.

## Resolver changes (`install/resolver.zsh`, currently 672 lines)

Removed, roughly 65 lines:

- `bundle_files_for()` -- name validation, path-traversal guard, file-existence walk
- the `packages.bundles` validation block -- `!!seq` check, non-empty,
  contains-`dotfiles`, per-name file existence, bundle `platforms` gate (no
  bundle declares `platforms` today, so that path is dead on removal)
- `"packages.bundles"` from `REQUIRED_FIELDS`

Added, roughly 45 lines:

- `BASE_TOML` constant plus a hard error when missing or unparseable
- `feature_bucket <key>` -- union of `packages.<key>` across enabled flags only
- registry `[<flag>.packages]` shape validation -- seven legal bucket keys,
  bare strings except `mas` (`{ id, name }` objects)
- the redundancy rule (below)

Net: the resolver gets about 20 lines shorter, which matters at 672 against
the 800-line cap.

### Union order

```
base.toml  ->  enabled flags  ->  machine
```

Machine last, so its `mas` entries win the last-wins dedupe by `.id`.
Bare-string buckets stay `add | unique`; casks stay
`add | unique | map({name: .})`. The existing `PACKAGE_NAME_RE`
Brewfile-injection guard runs on the fully-unioned set, so base- and
flag-injected names inherit it.

### The redundancy rule

The tiers stay honest only if they cannot be blurred. A machine listing a
package that base or an **enabled** flag already provides is a hard error:

```
error: personal-laptop: packages.casks entry 'ghostty' is already provided
       by enabled feature 'ghostty' -- remove it from the machine manifest
```

This is what makes "if it is listed, it was a choice" true rather than
aspirational, and prevents machine files drifting back into full inventories.
It fires only on enabled flags: atium listing `1password` while both
1Password flags are disabled is correct and stays legal.

### Output contract

`resolved.json` loses `packages.brew.bundles` -- the only field removed.
Nothing else changes shape. Base and flag packages fold into the existing
output buckets, which are nested by provider rather than flat:

```
packages.brew.{formulae, casks, mas}
packages.vscode.extensions
packages.cargo.crates
packages.uv.tools
packages.npm.packages
```

(The seven bucket keys named on the TOML input side -- `formulae`, `casks`,
`mas`, `vscode`, `cargo`, `uv`, `npm` -- are the manifest vocabulary; the
resolver already maps them onto the nested output paths above. That mapping
is unchanged.)

So `compose-brewfile.zsh`, `taskfiles/packages.yml`, and every taskfile
`{{.MANIFEST}}` read are untouched.

### Fixture impact

`manifests/test/shared/` exists solely to feed bundle files to fixtures. With
bundles gone it becomes a single shared `base.toml`. The three fixtures that
specifically exercise bundle merging -- `typed-02-formulae-dedup`,
`typed-03-casks-mas-dedup`, `typed-04-vscode-union` -- need inputs rewritten
to exercise base + flag + machine merging instead. Their intent survives;
their fixture data does not. Every `expected.json` drops `bundles`. Two new
negative fixtures are required: bad registry packages shape, and a redundancy
violation.

This is the largest single chunk of work in the change, and it is
unavoidable: the merge semantics under test are exactly what changes.

## Migration

The union dedupes, so a package declared in both `base.toml` and
`dotfiles.toml` resolves identically. That makes the first phase additive and
provable.

### Phase A -- additive foundation

`resolved.json` byte-identical for all four machines.

Create `base.toml` duplicating `dotfiles.toml`'s unconditional 22. Add
`[<flag>.packages]` to the five flags. Mint `repo-dev-toolchain` and
`vscode`, accounted on every machine. Teach the resolver `feature_bucket`,
base fold-in, and registry shape validation. Bundles stay in place and keep
working.

Gate: `task manifest:show -- --machine N | jq -S .` matches its pre-change
snapshot for all four machines. Any diff is a bug, not a decision.

### Phase B -- bundle removal

`resolved.json` changes by exactly the prune list below.

Inline discretionary packages into the four machine files, delete
`manifests/bundles/`, drop `bundles` from the schema (v3), remove the bundle
machinery from the resolver, add the redundancy rule, rewrite the three
bundle-merge fixtures, update docs.

Gate: the before/after diff contains only these entries.

| Machine | Change | Why |
|---|---|---|
| atium | minus `biome hyperfine ruff shellcheck shfmt taplo` | `repo-dev-toolchain` disabled; atium does not lint this repo |
| atium | minus `1password-cli` | `op` unused; atium keeps the `1password` GUI as discretionary |
| ci | minus `1password-cli` | confirmed by operator |

Everything else is provably unchanged.

`1password-cli` becomes discretionary on the two laptops.

## Verification

| Gate | Instrument |
|---|---|
| Resolved set correctness | `jq -S .` diff of `manifest:show` for all 4 machines, per phase |
| Merge semantics | `task test` -- fixtures, including 2 new negative ones |
| Repo rules | `task lint` -- LINT-13 covers the new TOML arrays |
| Real convergence | `task install` on this laptop: expect zero package churn |
| Second opinion (if Phase 3 landed) | `task diff` before and after |

The four-machine snapshot diff is load-bearing. The others catch regressions;
that one proves the migration.

## Relationship to the existing NixOS plan

This replaced **Task 8 / Phase 4** of the 2026-07-23 NixOS architecture
improvements plan. That task added
`[<flag>.packages]`, resolver folding, and registry-shape validation -- a
strict subset of this design. Running both would implement the same resolver
changes twice toward conflicting end states. Task 8 is deleted from that
plan; its ghostty migration becomes one line here.

Sequencing against the other phases:

- **Phase 1 (test layout) should land first.** This change performs major
  surgery on `manifests/test*/fixtures/`; doing the `test/` to `tests/`
  rename afterward means touching those files twice.
- **Phases 2 and 3 are independent.** Phase 3 is useful to have first
  (`task diff` becomes a second opinion), but not required -- the
  verification above is exact without it.

## Non-goals

- **Per-package provenance in `resolved.json`.** Would enable a
  `packages:show --by-origin`. The machine file is the interface, not a task.
  Speculative.
- **Pruning beyond the table above.** Once machine files are explicit,
  trimming `ci`'s eleven CLI tools becomes attractive -- a separate, easy,
  reversible pass, easy only because of this change.
- **Backward compatibility for `schema_version = 2`.** Hard error with a
  migration hint.
- **Touching Phases 1 to 3 of the existing plan.** Untouched apart from
  deleting Task 8.

## Decisions

| Decision | Rationale |
|---|---|
| Machine file lists discretionary packages only | The glance is only useful if everything in it was a choice; 100-line inventories bury the 35 lines that carry information. |
| One base tier plus one new toolchain flag, not fine-grained modules | Feature accounting is enforced total-explicitness, so each flag costs 4 accounting lines. Only the lint toolchain has real optionality. |
| Delete `bundles/` entirely rather than keep one for VSCode | Keeping one file keeps the whole machinery -- name validation, `platforms`, the `resolved.json` field -- alive to serve a single consumer. |
| VSCode extensions onto a `vscode` flag | 29 ids inline would push a laptop manifest to ~80 lines and bury everything else. The editor concern owns its extensions. |
| atium gets 1Password as discretionary, not by enabling the flags | `identity/ssh/identities/atium` states it uses the local system ssh-agent, not 1Password. Enabling `one-password-ssh` would repoint `SSH_AUTH_SOCK` at a socket atium deliberately avoids. |
| Redundancy rule is a hard error | Without it the tiers blur back together and machine files drift into full inventories again. |
| Two-phase migration gated on `resolved.json` equality | Makes Phase A a provable no-op and reduces Phase B's review to a three-row diff. |
