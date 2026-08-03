# Borrowing from NixOS

What this repo takes from NixOS (and its ecosystem: home-manager,
nix-darwin, flakes) without adopting Nix itself -- covering both how NixOS is
architected internally and which of its features are worth borrowing.

Two questions, one document. "How is NixOS built?" explains the shape this
repo converged on; "what should we borrow next?" is the roadmap. Sections
run in that order: architecture, then what has already been borrowed, then
the open borrow list, then the standing refusals.

Method: a full walk of this repo (every taskfile, the resolver, shell/os
layers, docs), a survey of NixOS concepts and best-practice multi-host repo
layouts, and community evidence from people who have run both systems.
Caveat on sources: reddit.com blocks automated retrieval entirely, so
r/NixOS threads could not be quoted directly; the equivalent discussions
were captured from Hacker News, lobste.rs, NixOS Discourse, and first-person
migration blog posts -- the same population having the same arguments. All
sources are listed at the end.

## TL;DR

This repo independently reinvented the *declaration* and *validation* halves
of NixOS: per-machine manifests are `configuration.nix`, the feature registry
is a closed option vocabulary, `resolver.zsh` is module assertions,
`resolved.json` is the evaluated config, `status:` blocks are convergence,
and the audit tiers are drift detection. The *feedback* half -- preview and
diff -- was the gap, and closing it turned out to be a staging problem rather
than a feature problem. What remains missing is declared-state enforcement
and a package-name indirection layer, the latter being the actual key to
Ubuntu support. None of it requires a content-addressed store, a
configuration language, or atomic activation. The highest-leverage borrows,
in order:

1. `task diff` -- a dry-run "here is what install would change" plan.
   **Delivered 2026-08-02**, and it arrived as a corollary of adopting the
   evaluate/realize/activate staging rather than as a feature in its own
   right.
2. Declared-state enforcement -- `brew bundle cleanup` behind a per-machine
   flag, making the manifest authoritative instead of merely sufficient.
   **Next.**
3. Generation snapshots. **Rejected 2026-07-24** -- see item 3.
4. Per-OS package-name indirection in the resolver -- the overlay idea, and
   the design center of Linux support. **Blocked on a real Linux machine.**
5. A periodic clean-VM rebuild drill -- the "wipe and rebuild to 100%"
   property is the single most-defended NixOS benefit, and it is a testing
   discipline, not a Nix feature. **Blocked on the same.**

And the strongest finding in the other direction: the community's most common
landing spot after leaving Nix on macOS is Homebrew + a version manager +
plain declarative dotfiles -- i.e. this repo is the *destination* of that
migration path, not a stepping stone away from it. Do not adopt Nix; do take
the discipline that made its feedback loop cheap.

## How NixOS is architected

### The five-layer stack

NixOS is five layers, each consuming only the layer below:

| Layer | What it is | This repo's equivalent |
|---|---|---|
| Nix language | Pure, lazy, functional *data* language -- no I/O; same inputs always evaluate to the same result | TOML (deliberately dumber -- good) |
| Nix store | `/nix/store/<hash>-name` -- immutable, content-addressed artifacts | none (deliberately rejected) |
| Derivations | A build recipe: inputs -> pure function -> output path. Everything is a derivation: a package, a config file, a whole OS | `resolved.json` and the build dir |
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
`nginx.nix` contains the option vocabulary, the config-file generation, the
systemd unit, the user account, *and the packages the service needs*.
Enabling `services.nginx.enable = true` pulls all of it. Host files are thin
-- 30 lines of toggles -- because modules are thick. That is the argument
for `[<flag>.packages]` in the feature registry.

### The three-stage pipeline (the deepest idea)

Every `nixos-rebuild switch` is strictly staged:

1. **Evaluate** (pure, fast, no side effects): modules -> one config tree ->
   one derivation graph. Nothing touches disk.
2. **Realize** (build; still not the live system): build every artifact. At
   the end there exists a complete directory -- the "system toplevel" --
   containing everything the machine should be. The entire desired state is
   materialized as files before anything is touched.
3. **Activate** (the only impure step): flip symlinks from the old toplevel
   to the new one, restart changed services.

Because stage 2 produces a real directory, `dry-activate`, `nvd diff`,
generations, and rollback come *for free* -- they are all operations on
directories that already exist. Diff, history, and rollback are not features
Nix built; they are corollaries of "compute the whole desired state before
applying any of it." This repo runs the same three stages
(`resolver.zsh` -> the build dir -> `task install`), which is why `task diff`
cost so little once the staging was in place.

### How the code is organized

- Hosts thin, modules thick; shared "profiles" are just modules that hosts
  import.
- `lib/` (pure helpers) strictly separated from packages and modules.
- Tests are addressable targets in the same build graph
  (`nix build .#checks.x86_64.nginx`): colocated with components, uniformly
  named, aggregated by one runner (`nix flake check`).

## Where this repo is already NixOS-shaped

| NixOS concept | This repo's equivalent | Status |
|---|---|---|
| `configuration.nix` per host | `manifests/machines/<name>.toml` | Have |
| Module options (closed vocabulary, typos are errors) | `manifests/features.toml` registry + unknown-key rejection in `install/resolver.zsh` | Have |
| Module `assertions` with human messages | `validate_manifest` (feature accounting, capability sentinels, cross-field rules) | Have |
| Evaluated config all consumers read | `resolved.json` via `{{.MANIFEST}}` | Have |
| Convergent activation (`nixos-rebuild switch`) | `task install` + `status:` idempotency | Have |
| Drift detection | `task audit` / `task validate` / `packages:verify` | Have (one-directional per tool) |
| hosts/ thin, modules/ thick | machine manifests are flag lists + discretionary packages; flags carry their own packages | Have |
| OS as a host attribute, not a repo fork | `machine.os` field + registry `platforms` | Have (schema accepts `linux`, unused) |
| Auto-import directories | `shell/aliases/*` and `shell/functions/*` globbing | Have |
| Dry-run / diff (`dry-activate`, `nvd diff`) | `task diff` vs the build dir | Have |
| Realize stage producing a whole desired state | `$XDG_STATE_HOME/dotfiles/build/` | Have |
| Build products never in the source tree | repo holds source only; generated files in the state tree | Have |
| Undeclared-state cleanup | audit reports drift but nothing removes it | **Missing** |
| Generations / history / rollback | state = two files, no history | **Missing** |
| Package-name indirection across OSes (overlays) | -- | **Missing** |
| flake.lock pinning | packages float (`brew bundle install --upgrade`, antidote pulls latest) | Missing, mostly unfixable (see below) |

The community keeps independently reinventing this repo's shape inside Nix:
the standard multi-host flake layout (shared core / platform layer / per-host
remainder, per-host feature toggles) is structurally identical to
base tier / feature registry / machine manifests.

## What real users value and regret (community evidence)

Benefits people who run NixOS actually defend, ranked by how often they came
up across the sources listed at the end:

1. **Wipe-and-rebuild reproducibility** -- new hardware to fully configured
   in 30-90 minutes, from git. The most defended benefit by a wide margin;
   Discourse regulars tell Arch users they will "never get it back 100%"
   without it.
2. **Rollback / generations** -- the benefit ex-users most openly admit they
   cannot replicate. The accepted non-Nix approximation is filesystem
   snapshots (APFS/ZFS/Btrfs) or git-revert + idempotent re-install.
3. **Single source of truth / "every tool is documented and intentional"** --
   notably, this is a *manifest* property, not a Nix property, and this repo
   already has it.
4. **Cross-machine consistency** -- value scales with machine count; several
   sources say Nix only decisively beats alternatives at fleet scale. Worth
   watching as the Ubuntu VM count grows.
5. **Fearless experimentation** -- psychological safety from cheap revert.
6. **Long-term stability** -- "once it works, it works forever."

Complaints that drive people away, ranked:

1. **The Nix language and documentation** -- "the number one threat to
   adoption"; "ChatGPT is Nix's only documentation." Dominant exit reason.
2. **Iteration friction** -- rebuild loops for trivial config edits
   ("eating with chopsticks... holding the chopsticks with another set of
   chopsticks"). Symlinked plain files, which this repo uses, get instant
   edits with no rebuild.
3. **Maintenance cost exceeding payoff** -- multi-hour updates, surprise
   source compiles; one author counted 4 machine changes in 10 years as the
   entire reproducibility payout.
4. **macOS as a second-class platform** -- explicit consensus even among
   fans; validates this repo's original rejection of Nix.
5. **Ecosystem gaps** -- nixpkgs version lag, FHS-incompatible binaries,
   60 GB stores.
6. **Expertise concentration** -- Nix needs a resident expert; boring tools
   (TOML + task runner) have flat expertise requirements.

Hybrid setups people actually land on for mac + linux: Homebrew + mise +
plain dotfiles ("90% of the benefit for 1% of the effort"); Brewfile +
chezmoi when per-host file contents must diverge; home-manager-only on a
conventional OS (also the piece insiders most often drop -- its guarantees
leak exactly where dotfiles live); nix-darwin users keeping Homebrew for GUI
casks anyway. Even committed Nix users run a ~5% escape hatch of unmanaged
software -- the machine-manifest one-off `[packages]` table is exactly that
pattern, formalized.

One clarifying frame from the tool-comparison threads: Ansible-style systems
are *convergent* (nudge state toward the manifest), Nix is *congruent*
(reconstruct state from the manifest). Congruence is Nix's moat and enables
true rollback. The realistic goal here is aggressive convergence: detect and
correct drift in both directions, preview changes before applying.

## What has already been borrowed

The structural borrows, all delivered. Each is here because it names a
decision that should not be re-litigated, not to describe the code -- the
code and its READMEs are authoritative for that.

| Borrow | Delivered |
|---|---|
| A -- build-then-activate + `task diff` | 2026-08-02 |
| B -- repo tree holds source only | 2026-08-02 |
| C -- feature-to-package mapping | 2026-08-02 |
| D -- `install/` scripts name their stage | 2026-08-02 |
| E -- one test convention | 2026-08-02 |

### A. Build-then-activate

Composition is separated from activation. The realize stage emits
`$XDG_STATE_HOME/dotfiles/build/` holding the composed Brewfile, the composed
`settings.json`, and `links.map`. Activation applies it.

Because the desired state is materialized as files, `task diff` is a file
comparison rather than a recomputation. That is the Nix property: diff is a
corollary of staging, not a feature built on top of it.

### B. The repo tree holds source only

Nix's hardest rule is that build products never live in the source tree.
Machine-generated addon fragments live at
`$XDG_STATE_HOME/dotfiles/settings.d/`, and the composed `settings.json` is
built into the state tree and installed onto `~/.config/claude/settings.json`
as a real file. Nothing the Claude CLI writes can reach tracked source, so
`git status` no longer differs per machine.

One impurity remains and is deliberate: compose reads `enabledPlugins`,
`extraKnownMarketplaces`, `model`, and `tui` back out of the live file,
because the CLI writes them there and cannot be redirected. Bounded to those
keys, one direction, and pointed away from the repo -- the honest shape, not
something to engineer around.

### C. Feature-to-package mapping

Packages arrive in three tiers, mirroring NixOS's base system / modules /
`environment.systemPackages` split: `manifests/base.toml` (unconditional, no
machine names it), `[<flag>.packages]` in the registry (a concern owns its
packages end-to-end), and a machine's `[packages]` (deliberate choices only).

Bundles are gone. The drift class they created -- enable `ghostty` without
its cask, or vice versa -- is structurally impossible now, and the resolver
rejects a machine that re-declares anything base or an enabled flag already
provides. The invariant that makes a machine manifest readable: a package
appears there if and only if it was a free choice.

On the O(machines x flags) feature accounting: NixOS solves it with defaults
(`mkDefault`); item 9 below correctly defers that. At four machines, total
explicitness is the right trade.

### D. `install/` scripts name their pipeline stage

Every script under `install/` belongs to exactly one stage -- lib, evaluate,
realize, operate, or tests -- and `install/README.md` lists them that way, so
a new script declares where it fits rather than implying it through a
filename prefix.

The one file to watch is `resolver.zsh` -- the largest in the repo and the
closest to the 800-line cap.
The module system's internal split is the natural fracture line when it
bursts: *declare/validate* vs *merge/emit*.

### E. One test convention

Colocation is the right instinct -- nixpkgs colocates package tests; NixOS
keeps module tests addressable per component. What Nix adds is uniformity:
every component's tests are found the same way and aggregated by one runner.

`<domain>/tests/` carries that: `install/tests/`, `manifests/tests/`,
`taskfiles/tests/`, with `task test` as the single aggregator (this repo's
`nix flake check`). Fixture layout inside each is unconstrained; the
`expect.txt` golden-file pattern is precisely how NixOS module assertions are
tested.

## The borrow list

### 1. `task diff` -- dry-run preview (DELIVERED -- see borrow A)

`nixos-rebuild dry-activate` shows what activation would change; `nvd diff`
renders added/removed/upgraded packages between generations. chezmoi
independently converged on the identical UX (`chezmoi diff` then
`chezmoi apply`). Two unrelated ecosystems converging is why this ranked
first, and it is fully separable from Nix's storage model.

Two follow-ups from the original sketch were not carried over and remain
reasonable: addon install/remove deltas in the preview, and
`resolver.zsh --stdout` diffed against the cached `resolved.json`
(`manifest:audit` covers the second case today).

### 2. Declared-state enforcement -- `task packages:prune` (do)

**Nix:** everything not declared is absent. nix-darwin's Homebrew module
makes this concrete with `onActivation.cleanup = "zap"`: any brew/cask not in
the declared list is removed, so "the cask list becomes the source of truth
instead of whatever accumulates." Install-only declarative systems drift
monotonically; cleanup is what makes the manifest *authoritative* rather than
merely *sufficient*.

**Translation:** the mechanism already ships with brew:
`brew bundle cleanup --force --file=<composed Brewfile>`. Concretely:

- A per-machine opt-in (e.g. a `prune` feature flag, or a `[packages]`
  boolean) -- enforcement is a per-machine trust decision.
- `task packages:prune`: show the removal list (the existing `packages:audit`
  comm -23 output), confirm, execute. Optionally fold into `task install`
  when the flag is on.
- Keep the escape-hatch philosophy: a stray `brew install` on a non-prune
  machine stays *reported drift*, never a broken machine.
  Convergence-with-tolerance beats enforcement-by-construction for personal
  machines -- this is a lesson *from* Nix's pain, not just its features.
- Ubuntu analog: `apt-mark showmanual` diffed against the declared set.
- Same idea extends to the other audit domains already scanned (vscode
  extensions, cargo, uv, npm) if wanted later.

Effort: low. Payoff: high -- this is the single biggest seamlessness gap
between brew-bundle setups and nix-darwin.

### 3. Generation snapshots and a practical rollback story (REJECTED)

**Rejected 2026-07-24 by operator decision.** Homebrew is rolling-release and
refuses version pinning, so binaries never roll back regardless of what is
recorded. The residual value -- a version record for bisecting "it worked
last week" -- addresses a problem that has not occurred in years of
operation, and config rollback is already `git checkout` + `task install`.
The build dir earns its keep on `task diff` alone; nothing snapshot-shaped
was built alongside it.

Everything below is the design as evaluated, kept so the rejection can be
re-examined against real evidence rather than re-derived from scratch.
Revisit only if an actual "which version did I have?" incident happens.

**Nix:** every rebuild is a numbered generation; activation is atomic;
any generation is bootable/restorable. The felt value is fearlessness.

Full atomicity requires the content-addressed store -- unreplicable, skip.
But the value decomposes into replicable parts:

- Config rollback is *already git* (symlinked files + idempotent install).
  Make it explicit: at each successful converged `task install`, write
  `$XDG_STATE_HOME/dotfiles/generations/<n>.json` containing the git SHA,
  a package-versions snapshot (`brew list --versions`, tool versions), and a
  copy of `resolved.json`.
- `task generations:show` lists them; rollback = `git checkout <sha>` +
  `task install`. Honest ceiling (ponytail-grade): package *binaries* do not
  roll back -- brew keeps only current bottles -- but config, links, flags,
  and the declared package *set* do.
- This snapshot doubles as the debugging artifact for "it worked last week"
  (the useful half of flake.lock -- see next item).
- Optional extra on APFS machines: a filesystem snapshot before install is
  the community-standard rollback approximation. Probably overkill for
  dotfiles; note it and skip.

Effort: low. Payoff: medium (mostly legibility and history; occasionally a
rescue) -- judged not to clear the bar.

### 4. What to do about pinning (mostly: don't)

**Nix:** `flake.lock` pins every input to an exact revision; updates are an
explicit, reviewable commit.

**Hard constraint:** Homebrew explicitly refuses to be a version-pinning
system -- "brew bundle does not and will not have a concept of a Brewfile
lock file that can be used to pin versions" (homebrew-bundle#1188), and newer
brew removed lock-file generation entirely. apt is the same story outside
snapshot mirrors. Fighting this is fighting the platform; Nix's answer (the
store) is exactly the machinery already rejected.

Borrow the two things pinning is *for* instead:

- **Record**: the generation snapshot above answers "what versions did I have
  when it worked".
- **Real pinning only where it matters**: dev toolchains via managers that do
  pin (mise/asdf `.tool-versions`, `uv` lockfiles, `cargo install --locked`).
  The repo already declares tool minimums (yq/go-task/jq); record
  tested-good versions in the generation snapshot.

Effort saved: high. This is a deliberate non-goal, documented here to prevent
re-litigation.

### 5. Per-OS package-name indirection (the key to Ubuntu; do with Linux work)

**Nix:** overlays let consumers reference a stable name while a mapping layer
decides what it resolves to; home-manager spans macOS and Linux with
`isDarwin`/`isLinux` conditionals confined to the config layer. The
transferable idea is *name indirection*, and it is 90% of what "add Ubuntu"
actually requires: `fd` is `fd-find` on apt, casks and mas do not exist on
Linux, some packages are darwin-only. (comtrya demonstrates the non-Nix
version: one manifest, a package action that abstracts brew/apt/dnf.)

**Translation, consistent with existing rules** ("TOML parsing belongs in
resolver.zsh", no inline OS branching in shared files):

- Bundle/machine package entries stay logical names. Add optional per-OS
  overrides only where names diverge:
  `fd = { apt = "fd-find" }`, or `platforms = ["darwin"]` on an entry.
  Default rule: same name everywhere (true for most CLI tools).
- The **resolver** applies `machine.os` and emits a concrete per-provider
  install list into `resolved.json`. Taskfiles dispatch on *provider*
  (brew/apt), never on OS.
- The registry's existing `platforms` field is the precedent -- extend the
  same semantics to package entries.
- GUI packages (casks generally) simply become darwin-only; on Linux the
  install pipeline has fewer steps.

**A decision Linux support has not made yet:** the approved-but-since-deleted
Linux design targeted Homebrew-on-Linux on x86_64 and explicitly listed arm64
Linux as out of scope.
Ubuntu VMs on Apple Silicon hosts are aarch64, where Homebrew-on-Linux is
unsupported (no bottles; source builds). If the VM fleet is
Apple-Silicon-hosted, the brew-everywhere plan degrades badly there, and
apt + mise behind the provider indirection above becomes the primary Linux
path instead of linuxbrew. Resolve this before implementing spec section 3:
check `uname -m` on the actual VMs; if aarch64, either extend the provider
layer to apt from day one or scope linuxbrew to x86_64 servers only.

Effort: medium. Payoff: essential -- this *is* the Ubuntu design.

### 6. System/user layer split with OS-gated pipeline steps (do with Linux work)

**Nix:** home-manager's enduring insight is the axis split: user-level config
(shell, git, aliases, CLI tool configs) is ~95% OS-independent; system-level
config (packages, OS defaults, services) is where OSes differ. Every serious
multi-OS repo keeps these separate, so adding an OS only touches the thin
system layer.

**Translation:** classify existing domains along this line and gate pipeline
steps by OS in the resolver/taskfiles:

- Portable layer (should run unmodified on Ubuntu): `shell/`, `configs/`,
  `identity/` (minus 1Password specifics), `claude/`, functions/aliases.
  The LINT-05 portability warnings become load-bearing here --
  `os/README.md` inventories every macOS-only call with its Linux
  remediation.
- System layer (darwin-gated): `os/defaults/`, brew cask/mas/vscode
  sections, 1Password integration, hostname via `scutil` (Linux:
  `hostnamectl`, per the spec).
- The dustinlyons-style three-way split (shared / darwin / linux) is the
  community-converged shape. Note: the CLAUDE.md "flat directories, no
  os/darwin/ nesting" rule collapses the platform dimension *because* there
  is one OS; adding Linux is precisely when that dimension legitimately
  reappears. Plan that rule change consciously (the Linux spec's approach --
  inline dispatch at existing seams, no parallel tree -- is the right
  instinct; revisit only if `os/` grows a genuine Linux concern file).

Existence proof of the target topology: Mitchell Hashimoto's setup -- macOS
host for GUI + Linux VMs for dev, one repo, one command driving both.

Effort: low-medium (mostly classification and gating). Payoff: high;
prerequisite hygiene for item 5.

### 7. Clean-VM rebuild drill -- the "100% back" property (do, cheap)

The most defended NixOS benefit -- wipe-and-rebuild to a fully configured
machine -- is a *testing discipline*, not a Nix feature. CI already proves
half of it (fresh macos-latest runner: bootstrap, setup, install, converged
second install). The missing half is doing it against a *real* machine
profile, not just `ci.toml`. Once Ubuntu VMs exist, they make this nearly
free: periodically bootstrap a throwaway VM with a real server manifest and
run the full pipeline. The planned ubuntu-latest CI job (spec section 10)
covers the Linux `ci` profile; a scheduled or manual "rebuild drill" against
a production-shaped manifest closes the rest. This is also the honest answer
to Nix's congruence moat: prove convergence-from-zero regularly instead of
guaranteeing it by construction.

Effort: low (a VM and a checklist, later a scheduled CI job). Payoff: high
confidence, and it directly exercises the multi-machine story.

### 8. Content-hash `status:` checks (do opportunistically)

chezmoi's `run_onchange` scripts re-run when their *content hash* changes --
a clean generalization of the `status:` pattern for steps whose freshness
depends on inputs, not outputs. Candidate: `claude:settings-compose`
(hash the `settings.d/` fragment dir into the status check instead of, or in
addition to, mtime comparison). The existing mtime-gated `manifest:resolve`
and `packages:compose` freshness checks are already most of the way there;
use content hashes where mtime lies (e.g. git checkout normalizing mtimes).

Effort: low, per-site. Payoff: medium; fixes a real mtime bug class.

### 9. Layered defaults (mkDefault semantics) -- defer until a 3rd+ active machine class

**Nix:** `lib.mkDefault` sets a low-priority value any host can override
without editing the shared file; roles/profiles are named selection sets a
host opts into.

The repo deliberately chose self-contained manifests over inheritance
(clarity over DRY), and with 4 machines that remains right. The observable
cost is O(machines x flags) feature accounting -- `ci.toml` accounts for every
registry flag, disabling all but one -- and it grows linearly with both.
When Ubuntu VMs
multiply the machine count, revisit as: a `role` (named group of flag
selections) a manifest opts into, with machine-level entries winning,
precedence resolved in `resolver.zsh` and baked into `resolved.json` so
taskfiles never re-derive it. Precedence order:
machine > role > feature > base. Also from the community: the
"import all and enable" over-modularization failure mode (a 40-file module
tree for 2 machines) -- do not build this early.

This is already partly served: `manifests/base.toml` is the
EmergentMind-style "core" layer every machine shares, and keeping that floor
explicit is most of the legibility win.

Effort: medium. Payoff: high later, negative now.

### 10. Resolver `warnings` tier (nice-to-have)

NixOS `warnings` are non-fatal messages surfaced at build time (deprecations,
suspicious-but-legal combinations). The resolver's enumerate-all error
pattern extends naturally: a `VALIDATE_WARNINGS` counterpart printed at
`task setup` without failing it. First customers: deprecated flag names, a
darwin-only package listed by a linux machine (once item 5 lands), the
work-identity TODO placeholder.

Effort: low. Payoff: low-medium.

## What NOT to borrow

At the architecture level: do not import the fixed-point merge, typed option
trees, or inheritance between manifests. Those exist because NixOS merges
thousands of modules written by strangers; this repo has four machines and
one author. Take the **staging discipline** (evaluate -> realize -> activate)
and the **purity rule** (no generated files in the source tree), not the
machinery that enforces them at scale.

Item by item:

Documented to prevent re-litigation; each of these is a known Nix pain point
or a mismatch with this repo's constraints.

- **A configuration language.** The single biggest exit driver. Defense:
  TOML stays pure data; all logic lives in one readable resolver. The moment
  a manifest field wants conditionals or interpolation, add a resolver rule
  instead. (The per-OS package overrides in item 5 are data, not logic --
  that is the line.)
- **Typed option trees / deep module abstraction.** "Hard to know where to
  make changes unless you dig deep." Guard the `<domain>:<verb>` grammar and
  one-concept-per-file; reject meta-layers (auto-generated taskfiles,
  manifest inheritance chains).
- **All-or-nothing purity.** "In NixOS there are no quick edits." Keep the
  escape hatch: undeclared state is drift that audit reports (or prune
  removes, where opted in), never a broken machine.
- **Atomic switch / binary rollback.** Requires the store. Git + idempotent
  install + generation records capture the practical value.
- **True brew/apt version pinning.** The platforms refuse it (see item 4).
- **Encrypted-secrets-in-repo (sops-nix/agenix).** That machinery exists
  because the Nix store is world-readable. The 1Password
  capability-sentinel model (secrets never in repo, runtime-brokered) is
  strictly better for this use case.
- **Flake ceremony.** The input/output boilerplate serves the lock
  machinery; without the store it buys nothing.
- **Specialisations.** Solves dual-boot/hardware-profile problems this repo
  does not have; feature flags already cover "same machine, different
  capability sets".
- **Nix itself, still.** Community evidence strengthened the original
  rejection: macOS is Nix's weakest platform, even committed users keep
  Homebrew for casks, and the maintenance/expertise cost lands on one
  person. The fleet-scale caveat is real -- if the Ubuntu VM count grows
  into dozens of long-lived pet servers, congruent management starts paying
  for itself -- but disposable VMs rebuilt by `task install` are the cheaper
  answer at this scale.

## Linux support

Linux is out of scope repo-wide until a real Linux machine exists (see
CLAUDE.md). An earlier design document worked the mechanical seams -- os enum
relaxation and cross-field rules, server identity overlays + keygen, a
HOMEBREW_PREFIX linux branch, Brewfile cask/mas/vscode filtering, bootstrap
`uname -s` dispatch, hostnamectl/getent, LINT-05 guards, and an
ubuntu-latest CI job -- and was retired unexecuted. Rewrite it when the
machine arrives rather than resurrecting it; these are the decisions that
should survive into whatever replaces it:

1. **The arm64 question, blocking.** The old design assumed x86_64 +
   linuxbrew. Apple-Silicon-hosted Ubuntu VMs are aarch64, where linuxbrew
   has no bottles and everything builds from source. Check `uname -m` on the
   actual fleet first; if aarch64, apt behind the provider-indirection layer
   (item 5) becomes the primary path and linuxbrew scopes to x86_64 only.
2. **Provider indirection beats section filtering.** Filtering brew sections
   by OS handles "casks do not exist on Linux"; it cannot handle "fd is
   fd-find". Item 5 handles both.
3. **The rebuild drill (item 7) is the proof.** Disposable VMs rebuilt by
   `task install` are the ongoing evidence that a manifest fully
   reconstructs a machine.

## Roadmap

| Phase | Items | Depends on | Status |
|---|---|---|---|
| 1. Feedback loop | `task diff` (1) | nothing | done 2026-08-02 |
| 2. Enforcement | `packages:prune` flag + task (2); prune preview folded into `task diff` | Phase 1 | next |
| 3. Linux foundation | arm64 decision; provider indirection (5); portable/system domain classification + OS gating (6) | a real Linux machine | blocked |
| 4. Proof | ubuntu-latest CI job; clean-VM rebuild drill (7) | Phase 3 | blocked |
| 5. Scale (only when needed) | roles/mkDefault layering (9); resolver warnings tier (10) | a 3rd+ machine class making duplication hurt | not needed |

Generation snapshots (3) are rejected, not deferred -- see that item.
Content-hash `status:` checks (8) stay opportunistic: adopt one when an mtime
gate demonstrably lies, not as a sweep.

Each phase leaves the repo converged and shippable; nothing in a later phase
is load-bearing for an earlier one.

## Sources

NixOS concepts and mechanics:

- https://nix.dev/tutorials/module-system/deep-dive.html
- https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/module-system
- https://determinate.systems/blog/nix-flakes-explained/
- https://zero-to-nix.com/concepts/flakes/
- https://wiki.nixos.org/wiki/Nixos-rebuild
- https://librephoenix.com/2024-05-06-different-rollback-methods-in-nixos
- https://aly.codes/blog/2025-02-07-stop_using_nixos-rebuild_switch/
- https://sr.ht/~khumba/nvd/
- https://nixcademy.com/posts/mastering-nixpkgs-overlays-techniques-and-best-practice/
- https://github.com/LnL7/nix-darwin/blob/master/modules/homebrew.nix
- https://home-manager.dev/manual/25.11/
- https://saylesss88.github.io/flakes/specialisations_4.6.html

Multi-host repo layouts:

- https://github.com/Misterio77/nix-starter-configs
- https://github.com/EmergentMind/nix-config and
  https://unmovedcentre.com/posts/anatomy-of-a-nixos-config/
- https://github.com/dustinlyons/nixos-config
- https://github.com/mitchellh/nixos-config
- https://certifikate.io/blog/posts/2024/12/creating-a-multi-system-modular-nixos-configuration-with-flakes/
- https://bullo.sk/blog/nix-darwin-multi-host-setup/
- https://quanchobi.io/posts/nixos-overview/
- https://kobimedrish.com/posts/scaling_nixos_with_import_all_and_enable_pattern/

Community experience (leaving, hybridizing, comparing):

- https://news.ycombinator.com/item?id=44785093 (Why I'm Leaving NixOS After a Year)
- https://news.ycombinator.com/item?id=47339204 (back to Arch)
- https://news.ycombinator.com/item?id=42666851 (Death by a Thousand Cuts)
- https://news.ycombinator.com/item?id=30057287 (The Curse of NixOS)
- https://news.ycombinator.com/item?id=44208968 (Railway moving off Nix)
- https://news.ycombinator.com/item?id=31557430 (A decade of dotfiles; convergent vs congruent)
- https://news.ycombinator.com/item?id=48588413 (Stow to chezmoi)
- https://lobste.rs/s/lalc7r/moving_on_from_nix (to Homebrew + mise)
- https://lobste.rs/s/eojt4t/nix_on_macos_good_bad_ugly
- https://lobste.rs/s/wnnymx (you don't have to use Nix for dotfiles)
- https://lobste.rs/s/7trk9v/nix_nixos_my_pain_points
- https://discourse.nixos.org/t/should-i-use-nix-os/29215
- https://discourse.nixos.org/t/handling-secrets-in-nixos-an-overview-git-crypt-agenix-sops-nix-and-when-to-use-them/35462
- https://ayats.org/blog/no-home-manager
- https://hexacera.com/posts/nix-as-a-homebrew-replacement-a-failed-attempt
- https://htdocs.dev/posts/migrating-from-nix-and-home-manager-to-homebrew-and-chezmoi/
- https://pierrezemb.fr/posts/nixos-good-bad-ugly/
- https://stuxf.dev/blog/nix-a-year-of-pain/
- https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/
- https://carlosvaz.com/posts/declarative-macos-management-with-nix-darwin-and-home-manager/
- https://davi.sh/blog/2024/02/nix-home-manager/

Non-Nix prior art:

- https://www.chezmoi.io/user-guide/frequently-asked-questions/design/
- https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/
- https://docs.brew.sh/Brew-Bundle-and-Brewfile
- https://github.com/Homebrew/homebrew-bundle/issues/1188
- https://github.com/comtrya/comtrya
- https://manpages.debian.org/unstable/apt/apt-mark.8.en.html
- https://blog.rajpoot.dev/posts/devops/nix-devbox-dev-environments-2026/ (Devbox/mise for per-project envs)
