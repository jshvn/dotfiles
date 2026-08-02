# NixOS Architecture Learnings

Companion to [NIXOS-IDEAS.md](NIXOS-IDEAS.md). That document is the
feature-borrow roadmap (diff, prune, generations, provider indirection).
This one is the layer underneath: how NixOS itself is organized and
architected, and what its *internal structure* teaches about the shape of
this repo -- specifically the areas that currently feel clunky (claude
settings composition, feature-to-package mapping, `install/` sprawl,
scattered test directories).

## How NixOS is architected

### The five-layer stack

NixOS is five layers, each consuming only the layer below:

| Layer | What it is | This repo's equivalent |
|---|---|---|
| Nix language | Pure, lazy, functional *data* language -- no I/O; same inputs always evaluate to the same result | TOML (deliberately dumber -- good) |
| Nix store | `/nix/store/<hash>-name` -- immutable, content-addressed artifacts | none (deliberately rejected) |
| Derivations | A build recipe: inputs -> pure function -> output path. Everything is a derivation: a package, a config file, a whole OS | partially: `resolved.json`, the composed Brewfile |
| nixpkgs | ~100k packages + `lib/` + `stdenv`, all plain functions returning derivations | Homebrew (external) |
| Module system | Merges hundreds of config fragments into one typed tree that builds *one* derivation: the system | `resolver.zsh` + taskfiles |

Each layer is boring on its own. The power is that every layer speaks the
same currency (files computed from inputs), so the whole OS becomes a
single build artifact.

### The module system

A NixOS module is a file that can do two things:

- **Declare options** -- typed, documented, defaulted:
  `options.services.nginx.enable = mkOption { type = bool; default = false; }`
- **Define config** -- values for options declared *anywhere*:
  `config = mkIf cfg.enable { systemd.services.nginx = ...; users.users.nginx = ...; environment.systemPackages = [ pkgs.nginx ]; }`

Evaluation is a fixed point: all modules merge simultaneously; any module
can read the final merged config while contributing to it. Merging is
type-driven (lists concatenate, attrsets deep-merge, scalars conflict
unless prioritized with `mkDefault`/`mkForce`), and `assertions` /
`warnings` fire on the merged result.

The architectural insight: **a module owns its concern end-to-end.**
`nginx.nix` contains the option vocabulary, the config-file generation,
the systemd unit, the user account, *and the packages the service needs*.
Enabling `services.nginx.enable = true` pulls all of it. Host files are
thin -- 30 lines of toggles -- because modules are thick.

### The three-stage pipeline (the deepest idea)

Every `nixos-rebuild switch` is strictly staged:

1. **Evaluate** (pure, fast, no side effects): modules -> one config
   tree -> one derivation graph. Nothing touches disk.
2. **Realize** (build; still not the live system): build every artifact.
   At the end there exists a complete directory -- the "system toplevel"
   -- containing everything the machine should be: every config file,
   every package, the activation script. The entire desired state is
   materialized as files before anything is touched.
3. **Activate** (the only impure step): flip symlinks from the old
   toplevel to the new one, restart changed services.

Because stage 2 produces a real directory, `dry-activate`, `nvd diff`,
generations, and rollback come *for free* -- they are all operations on
directories that already exist. Diff/history/rollback are not features
Nix built; they are corollaries of "compute the whole desired state
before applying any of it."

### How the code is organized

- Hosts thin, modules thick; shared "profiles" are just modules that
  hosts import.
- `lib/` (pure helpers) strictly separated from packages and modules.
- Tests are addressable targets in the same build graph
  (`nix build .#checks.x86_64.nginx`): colocated with components,
  uniformly named, aggregated by one runner (`nix flake check`).

## Learnings mapped to this repo

The clunky areas share two root causes: **impure composition** and
**inconsistent conventions**.

### A. Adopt build-then-activate (the big one)

Today composition is interleaved with activation: `task install`
composes the Brewfile, composes `settings.json`, and applies changes in
one pass. That is why `task diff` (NIXOS-IDEAS item 1) reads as "medium
effort recomposition of audit logic" -- there is no materialized desired
state to diff against.

The Nix-shaped restructure: the resolve/compose stage emits a complete
**build directory** -- `$XDG_STATE_HOME/dotfiles/build/` containing
`resolved.json`, the composed Brewfile, the composed `settings.json`,
and a link map (source -> target list). Then:

- `task diff` = compare build dir vs live system (trivial, uniform).
- `task install` = sync build dir -> system (activation only).
- Generation snapshot (NIXOS-IDEAS item 3) = keep the build dir,
  stamped with the git SHA.

One architectural move makes three roadmap items fall out as
corollaries, exactly as they do in Nix.

(Generations evaluated and rejected 2026-07-24: Homebrew's rolling-release
model means binaries never roll back regardless, and the residual value --
a version-record for bisecting "it worked last week" -- addresses a
problem that has not occurred in years of operation. Config rollback is
already git checkout + `task install`. The build dir is worth having for
`task diff` alone.)

### B. Claude settings -- the clunk is an impurity, twice over

Two genuine "reads from its own output" problems:

1. `settings_preserved_keys` in `install/compose-settings.zsh` extracts
   CLI-managed keys from the generated artifact it is about to
   overwrite. The output is an input. This is why LINT-09 exists, why
   audit needs a `-S` normalization path, and why the whole thing feels
   delicate. Nix's rule: mutable state never lives inside a generated
   artifact -- but the Claude CLI forces it here (it writes
   `enabledPlugins` et al. into the live `settings.json`; that cannot be
   prevented). The honest fix makes the impurity explicit and
   one-directional: a capture step snapshots CLI-owned keys into
   `$XDG_STATE_HOME/dotfiles/claude-cli-state.json`, after which compose
   is a pure function of `settings.d fragments + state file`. Only the
   capture step ever reads the live file.
2. Worse: `claude/settings.d/99-addon-<name>.json` is a
   machine-generated file written into the repo source tree during addon
   install. Build products in the source tree is the thing Nix most
   fundamentally forbids -- git status differs per machine, and the
   fragment dir is neither fully repo-owned nor fully generated. Addon
   fragments belong in the state/build dir; compose reads
   `repo fragments + state fragments`.

With both fixes, the repo dir is pure source, the state dir is pure
machine-state, and the output is a pure function of the two.

### C. Feature-to-package mapping -- resolved

Packages now arrive in three tiers, mirroring NixOS's base system / modules /
`environment.systemPackages` split:

- `manifests/base.toml` -- unconditional; no machine declares it.
- `[<flag>.packages]` in the registry -- a concern owns its packages
  end-to-end, so enabling the flag pulls its tooling.
- a machine's `[packages]` -- deliberate choices only.

`manifests/bundles/` is gone. The drift class it created (enable `ghostty`
without its cask, or vice versa) is now structurally impossible, and a
resolver rule rejects a machine that re-declares anything base or an enabled
flag already provides. The invariant that makes a machine manifest readable:
a package appears there if and only if it was a free choice.

On the O(machines x flags) feature accounting: NixOS solves it with defaults
(`mkDefault`); NIXOS-IDEAS item 9 correctly defers that. At 4 machines, total
explicitness is the right trade.

### D. install/ sprawl -- name the pipeline stages

Twelve scripts, but really five roles: **lib** (`messages.zsh`,
`compose-settings.zsh` -- sourced, not executed), **evaluate**
(`resolver.zsh`), **compose** (`compose-brewfile.zsh`), **audit/operate**
(`links-audit-scan.zsh`, `claude-addons.zsh`, `repo-sync.zsh`,
`lint-rules.zsh`), and **tests** (`test-*.zsh` -- a third of the
directory). The clunk is that the pipeline taxonomy is implicit in
filename prefixes.

Two cheap moves: relocate `test-*.zsh` under a tests directory (the
directory halves), and watch `resolver.zsh` (672 lines, nearing the
800-line cap). The module system's internal split is the natural
fracture line when it bursts: *declare/validate* vs *merge/emit*. The
remaining files do not need subdirectories; they need the stage taxonomy
written down in `install/README.md` so the next script knows which stage
it belongs to.

### E. Testing -- colocation is right; the convention is inconsistent

Current reality: `install/test-*.zsh` (sibling files),
`manifests/test/fixtures/` (dir named `test`),
`taskfiles/test/lint-fixtures/` (nested differently). Colocation is the
right instinct -- nixpkgs colocates package tests; NixOS keeps module
tests addressable per component. What Nix adds is uniformity: every
component's tests are found the same way and aggregated by one runner.

The fix is a rename, not a redesign: one convention --
`<domain>/tests/` -- so `install/tests/`, `manifests/tests/`,
`taskfiles/tests/`, with `task test` remaining the single aggregator
(this repo's `nix flake check`). Fixture layout inside stays exactly as
is; the `expect.txt` golden-file pattern is precisely how NixOS module
assertions are tested.

## What not to take

NIXOS-IDEAS.md's rejection list stands. The architecture-level version:
do not import the fixed-point merge, typed option trees, or inheritance
between manifests. Those exist because NixOS merges thousands of modules
from strangers; this repo has four machines and one author. Take the
**staging discipline** (evaluate -> materialize -> activate) and the
**purity rule** (never read your own output; no generated files in the
source tree), not the machinery.

## Priority order

1. **Purity fixes for Claude settings** (B) -- smallest, kills the most
   daily annoyance, prerequisite hygiene for the build dir.
2. **Build-dir restructure** (A) -- makes NIXOS-IDEAS item 1 (`task diff`)
   a corollary of one refactor. (Item 3, generations, rejected -- see the
   note in section A.)
3. **Test-dir convention rename** (E) -- an afternoon.
4. **Feature -> package mapping in the registry** (C) -- done
   (2026-08-02); see
   docs/superpowers/specs/2026-08-02-manifest-tier-restructure-design.md.
5. **install/ taxonomy** (D) -- mostly falls out of item 3.
