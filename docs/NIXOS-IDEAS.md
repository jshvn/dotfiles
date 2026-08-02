# Borrowing from NixOS

A research-backed plan for what this repo should steal from NixOS (and its
ecosystem: home-manager, nix-darwin, flakes) without adopting Nix itself --
covering seamlessness, legibility, multi-machine management, and
macOS + Ubuntu support.

Method: a full walk of this repo (every taskfile, the resolver, shell/os
layers, docs, and the approved Linux spec), a survey of NixOS concepts and
best-practice multi-host repo layouts, and community evidence from people who
have run both systems. Caveat on sources: reddit.com blocks automated
retrieval entirely, so r/NixOS threads could not be quoted directly; the
equivalent discussions were captured from Hacker News, lobste.rs, NixOS
Discourse, and first-person migration blog posts -- the same population
having the same arguments. All sources are listed at the end.

## TL;DR

This repo has already independently reinvented the *declaration* and
*validation* halves of NixOS: per-machine manifests are `configuration.nix`,
the feature registry is a closed option vocabulary, `resolver.zsh` is module
assertions, `resolved.json` is the evaluated config, `status:` blocks are
convergence, and the audit tiers are drift detection. What is missing is the
*feedback* half -- preview, diff, and history -- plus a package-name
indirection layer, which is the actual key to Ubuntu support. None of the
missing pieces require a content-addressed store, a configuration language,
or atomic activation. The highest-leverage borrows, in order:

1. `task diff` -- a dry-run "here is what install would change" plan.
2. Declared-state enforcement -- `brew bundle cleanup` behind a per-machine
   flag, making the manifest authoritative instead of merely sufficient.
3. Generation snapshots -- record git SHA + package versions + `resolved.json`
   at each converged install; cheap history and a practical rollback story.
4. Per-OS package-name indirection in the resolver -- the overlay idea, and
   the design center of Linux support.
5. A periodic clean-VM rebuild drill -- the "wipe and rebuild to 100%"
   property is the single most-defended NixOS benefit, and it is a testing
   discipline, not a Nix feature.

And the strongest finding in the other direction: the community's most common
landing spot after leaving Nix on macOS is Homebrew + a version manager +
plain declarative dotfiles -- i.e. this repo is the *destination* of that
migration path, not a stepping stone away from it. Do not adopt Nix; do
finish the feedback loop it would have provided.

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
| Dry-run / diff (`dry-activate`, `nvd diff`) | -- | **Missing** |
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
up across ~18 sources:

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

## The borrow list

### 1. `task diff` -- dry-run preview (do first)

**Nix:** `nixos-rebuild dry-activate` shows what activation would change;
`nvd diff` renders added/removed/upgraded packages between generations.
chezmoi independently converged on the identical UX (`chezmoi diff` then
`chezmoi apply`). Two unrelated ecosystems converging is strong evidence this
is the load-bearing UX idea, and it is fully separable from Nix's storage
model.

**Translation:** invert the existing audit machinery into a preview.
`task diff` = "what would `task install` do right now", composed from what
each domain already knows how to compute:

- `brew bundle check`/`brew bundle cleanup` dry output: install and removal
  lists against the composed Brewfile.
- Links that would be created or retargeted (the `readlink -f` checks that
  already exist in `links.yml` `status:` blocks, run in report mode).
- `claude:settings-compose` diff of composed output vs live `settings.json`
  (LINT-09 already computes this).
- Addon install/remove deltas.
- After a manifest edit: fresh `resolver.zsh --stdout` output diffed against
  the cached `resolved.json` (`jq -S` both sides; sorted-key output already
  exists for fixtures).

This transforms the operator experience from "run install and watch" to
"review a plan, then converge". Combined with generation snapshots (below),
`task diff -- <generation>` gives nvd-style "what changed on this machine
since <date>".

Effort: medium (mostly recomposition of existing audit logic). Payoff:
highest on this list.

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

### 3. Generation snapshots and a practical rollback story (do)

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
rescue).

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

**A decision the approved Linux spec has not made yet:** the spec
(`docs/superpowers/specs/2026-07-14-linux-server-support-design.md`) targets
Homebrew-on-Linux on x86_64 and explicitly lists arm64 Linux as out of scope.
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
  `docs/LINT-FIXES.md` already inventories every macOS-only call with its
  Linux remediation.
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
cost is O(machines x flags) feature accounting -- `ci.toml` lists all 15
flags as disabled -- and it grows linearly with both. When Ubuntu VMs
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

## Relationship to the approved Linux spec

`docs/superpowers/specs/2026-07-14-linux-server-support-design.md` (approved
for planning) already covers the mechanical seams: os enum relaxation and
cross-field rules, server identity overlays + keygen, HOMEBREW_PREFIX linux
branch, Brewfile cask/mas/vscode filtering, bootstrap `uname -s` dispatch,
hostnamectl/getent, LINT-05 guards, the `GREP` template var, and the
ubuntu-latest CI job. This document does not replace it. It adds, on top:

1. **The arm64 question (blocking, decide first).** The spec assumes
   x86_64 + linuxbrew; Apple-Silicon-hosted Ubuntu VMs are aarch64 where
   linuxbrew has no bottles. Verify the fleet's arch; if aarch64, promote
   the provider-indirection layer (item 5) from "nice design" to the
   foundation, with apt as the Linux provider.
2. **Provider indirection in the resolver** (item 5) rather than only
   filtering brew sections by OS (spec section 4) -- filtering handles
   "casks don't exist on Linux"; indirection also handles "fd is fd-find",
   which filtering cannot.
3. **`task diff` and generation snapshots** land before the Linux work if
   possible -- previewing changes matters twice as much when two OS families
   share one pipeline.
4. **The rebuild drill** (item 7) uses the VMs as the ongoing proof that a
   manifest fully reconstructs a machine.
5. Two stale references in the spec to fix when implementing: it cites the
   abandoned `manifests/defaults.toml` concept (section 8), and its scope
   line "headless servers" should widen to "headless servers and VMs".

## Phased roadmap

| Phase | Items | Depends on |
|---|---|---|
| 1. Feedback loop (macOS-only, immediate) | generation snapshots (3); `task diff` (1); content-hash status where mtime lies (8) | nothing |
| 2. Enforcement | `packages:prune` flag + task (2); prune preview folded into `task diff` | Phase 1 |
| 3. Linux foundation | arm64 decision; provider indirection in resolver (5); portable/system domain classification + OS gating (6); then the Linux spec sections 1-11 | spec + arm64 answer |
| 4. Proof | ubuntu-latest CI job (spec s.10); clean-VM rebuild drill against a real manifest (7) | Phase 3 |
| 5. Scale (only when needed) | roles/mkDefault layering (9); resolver warnings tier (10) | a 3rd+ machine class making duplication hurt |

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
