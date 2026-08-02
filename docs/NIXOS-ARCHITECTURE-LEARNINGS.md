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

Two borrowed principles shape the repo: **staged composition** and
**one convention per concern**.

### A. Build-then-activate

Composition is separated from activation. The realize stage emits a
**build directory** -- `$XDG_STATE_HOME/dotfiles/build/` holding the
composed Brewfile, the composed `settings.json`, and `links.map` (one
`target<TAB>source` line per expected symlink). Activation then applies it.

Because the desired state is materialized as files, `task diff` is a file
comparison rather than a recomputation: each `<domain>:diff` compares the
domain's artifact against the live system. That is the Nix property --
diff is a corollary of staging, not a feature built on top of it.

(Generations, NIXOS-IDEAS item 3, evaluated and rejected 2026-07-24:
Homebrew's rolling-release model means binaries never roll back regardless,
and the residual value -- a version record for bisecting "it worked last
week" -- addresses a problem that has not occurred in years of operation.
Config rollback is already git checkout + `task install`. The build dir
earns its keep on `task diff` alone.)

### B. The repo tree holds source only

Nix's hardest rule is that build products never live in the source tree.
Here that means two things:

1. Machine-generated addon fragments live at
   `$XDG_STATE_HOME/dotfiles/settings.d/99-addon-<name>.json`, not in
   `claude/settings.d/`. The repo's fragment dir is fully repo-owned, so
   `git status` no longer differs per machine.
2. The composed `settings.json` is built into
   `$XDG_STATE_HOME/dotfiles/build/` and installed onto
   `~/.config/claude/settings.json` as a real file. Nothing the Claude CLI
   writes can reach tracked source.

One impurity remains and is deliberate: compose reads `enabledPlugins`,
`extraKnownMarketplaces`, `model`, and `tui` back out of the live file,
because the CLI writes them there and cannot be redirected. Bounded to four
keys, one direction, and pointed away from the repo -- which is the honest
shape, not something to engineer around.

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

### D. install/ scripts name their pipeline stage

Every script under `install/` belongs to exactly one stage -- **lib**
(sourced, not executed), **evaluate**, **realize**, **operate**, or
**tests** -- and `install/README.md` lists them that way, so a new script
has to declare where it fits rather than implying it through a filename
prefix.

The one file to watch is `resolver.zsh` (668 lines against the 800-line
cap). The module system's internal split is the natural fracture line when
it bursts: *declare/validate* vs *merge/emit*.

### E. Testing -- colocation plus one uniform convention

Colocation is the right instinct -- nixpkgs colocates package tests; NixOS
keeps module tests addressable per component. What Nix adds is uniformity:
every component's tests are found the same way and aggregated by one runner.

One convention carries that here: `<domain>/tests/` -- `install/tests/`,
`manifests/tests/`, `taskfiles/tests/` -- with `task test` as the single
aggregator (this repo's `nix flake check`). Fixture layout inside each is
unconstrained; the `expect.txt` golden-file pattern is precisely how NixOS
module assertions are tested.

## What not to take

NIXOS-IDEAS.md's rejection list stands. The architecture-level version:
do not import the fixed-point merge, typed option trees, or inheritance
between manifests. Those exist because NixOS merges thousands of modules
from strangers; this repo has four machines and one author. Take the
**staging discipline** (evaluate -> materialize -> activate) and the
**purity rule** (never read your own output; no generated files in the
source tree), not the machinery.

## Status

All five borrows are delivered.

| Item | Delivered by |
|---|---|
| A -- build dir + `task diff` | 2026-08-02, build-then-activate |
| B -- Claude settings purity | 2026-08-02, build-then-activate |
| C -- feature-to-package mapping | 2026-08-02, manifest tier restructure |
| D -- install/ stage taxonomy | 2026-08-02, build-then-activate |
| E -- test-dir convention | 2026-08-02, build-then-activate |

Design records:
`docs/superpowers/specs/2026-08-02-build-then-activate-design.md` and
`docs/superpowers/specs/2026-08-02-manifest-tier-restructure-design.md`.

Generations (NIXOS-IDEAS item 3) stay rejected -- see the note in section A.
