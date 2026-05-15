# Phase 5: Packages Layer — Brewfile Composition + Verification - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the packages layer: minimal by-purpose Brewfile bundles in flat `packages/<purpose>.rb`, composed per-machine from the manifest into a single cached Brewfile, installed idempotently via `brew bundle check`, then verified post-install (every formula's bin resolves on PATH; every cask's `.app` exists in `/Applications`). Plus a drift audit that surfaces installed-but-undeclared packages. Replaces v1's named-by-machine `Brewfile-<profile>.rb` model with manifest-driven composition + per-machine `extra_packages` typed-bucket extras.

**Key architectural decision (sets the tone):** Minimal shared bundles, heavy per-machine extras. v2 keeps v1's "each machine is self-describing — add a tool to one machine = edit one file" UX, but replaces the named-suffix file shape with manifest-driven composition. Only TWO bundle files ship in v1: `core.rb` (server-safe CLI baseline, every machine) and `gui.rb` (laptop GUI baseline: 1Password + Ghostty + anything every laptop wants). Everything machine-specific — Slack, Discord, VS Code, Office, Docker Desktop, MAS apps, Proton, Spotify, etc. — lives in per-machine `extra_packages`. The ROADMAP success criterion #3 enumeration of `core / gui / dev / ops / personal` as five bundles is amended down to `core / gui` (see required edits below). The "no `Brewfile-<profile>.rb` filename pattern" prohibition stays — that's the v1 pattern v2 is structurally replacing.

**In scope:**

- `packages/core.rb` — server-safe CLI baseline (every machine). Port v1 `install/Brewfile.rb` verbatim with minor edits (drop `antigen` — replaced by `antidote` in P3; add `antidote` itself if not already there). Includes: `zsh`, `go-task`, `yq`, `wget`, `openssh`, `git`, `git-delta`, `eza`, `bat`, `fd`, `grep`, `jq`, `glow`, `highlight`, `grc`, `tlrc`, `trippy`, `coreutils`, `cloudflared`, `antidote`, `mas`, `htop`, `bottom`, `duf`, `ncdu`, `fastfetch`, `onefetch`, `whois`, `doggo`, `hugo`. Roughly v1's `Brewfile.rb` content. `cloudflared` lives here (cross-cutting tunnel CLI; needed by personal SSH identity per P4, plus general use). `mas` is the CLI; MAS *apps* live in per-machine `extra_packages.mas`.

- `packages/gui.rb` — laptop GUI baseline (any machine with a display). Minimum set: `1password`, `1password-cli`, `ghostty`. Anything beyond that goes per-machine. Servers do NOT include `gui`.

- `taskfiles/packages.yml` — replaces `taskfiles/brew-stub.yml`. Tasks: `packages:install` (compose + brew bundle install), `packages:compose` (render the composed Brewfile only; useful for inspection), `packages:verify` (per-package check/cross report), `packages:audit` (drift detection), `packages:validate` (composed into root `task validate` in P8). All reads of bundles + `packages.brew.extra_packages` happen against `resolved.json` via `ref: fromJson` (kebab-case features via `index`; `packages.brew.extra_packages` is dot-accessible).

- **Composed Brewfile cache** — atomic `mktemp+mv` write to `$XDG_CACHE_HOME/dotfiles/Brewfile` on every install. Regenerated each run (sub-second cost). Concatenation order: each bundle in `packages.brew.bundles` (in declared order) followed by `extra_packages.formulae`, `extra_packages.casks`, `extra_packages.mas` (in that order). Composer emits the Ruby DSL lines verbatim (no abstraction over `brew` / `cask` / `mas`).

- **Idempotency contract for `packages:install`** — `status:` block runs:
  1. `test -f $XDG_CACHE_HOME/dotfiles/Brewfile` (composed exists)
  2. `brew bundle check --file=$XDG_CACHE_HOME/dotfiles/Brewfile --no-upgrade` (everything declared is installed)
  Both must pass for the task to no-op. Status block uses `{{.X}}` template vars only (LINT-02 contract; v1 `macos:shell:145` bug class).

- **`packages.brew.extra_packages` schema change** — TOML shape becomes:
  ```toml
  [packages.brew.extra_packages]
  formulae = ["hugo", { name = "ripgrep", verify = "rg" }]
  casks    = [{ name = "slack", verify = "Slack" }]
  mas      = [{ id = 441258766, name = "Magnet" }]
  ```
  Replaces the current flat-array form (`extra_packages = ["docker-desktop"]`). Resolver deep-merge concatenates each sub-array (formulae, casks, mas) independently with dedupe. `formulae` accepts bare strings OR `{ name, verify }` objects (bare = `command -v <name>` works). `casks` REQUIRES `{ name, verify }` objects (D-04 below: no derivation, explicit on every cask). `mas` REQUIRES `{ id, name }` objects (id drives install; name drives verify).

- **Verify rules** (committed alongside bundles):
  - **Formula default:** `command -v <formula-name>` resolves. Bundle line: `brew 'jq'` (no comment needed).
  - **Formula override:** `brew 'ripgrep' # verify: rg` — comment names the bin to test. For multi-binary formulas (`coreutils`, `grep`, `openssh`), pick ONE representative bin (e.g., `coreutils` # verify: gsha256sum; `grep` # verify: ggrep; `openssh` # verify: ssh).
  - **Cask requires explicit `# verify:` on every line.** No derivation. Bundle line: `cask 'ghostty' # verify: Ghostty`; verify checks `/Applications/Ghostty.app` exists.
  - **MAS:** verify checks `/Applications/<name>.app` exists (apps install to the same place as casks). `name` from the `{ id, name }` object IS the verify name — no separate verify field.

- **`task packages:verify` behavior** — enumerate ALL packages (don't stop at first failure), print a check/cross table, exit non-zero if any package failed. Used both standalone and as the final step of `task install` (VRFY-04). Hard fail — no `--no-verify` escape hatch (D-10). `task install` becomes idempotent end-to-end so the user re-triggers after fixing.

- **`task packages:audit` behavior** — drift detector. Reports installed-but-not-declared:
  - Formulae: `brew leaves` (top-level only; ignores dependencies — matches the "I `brew install`'d something manually" failure mode).
  - Casks: `brew list --cask` (no dep concept).
  - MAS apps: `mas list` (id + name).
  Diff against the union of (composed Brewfile contents) + (extras). Non-blocking by default (`exit 0`); `task packages:audit -- --strict` exits 1 for CI / pre-merge gates. Matches ROADMAP success #5 verbatim.

- **Manifest TOML migrations** (P5 deliverables):
  - `manifests/defaults.toml`: `[packages.brew] extra_packages = []` becomes `[packages.brew.extra_packages] formulae = [] / casks = [] / mas = []`.
  - `manifests/machines/personal-laptop.toml`: bundles trim to `["core", "gui"]`. Current `extra_packages = ["docker-desktop"]` becomes:
    ```toml
    [packages.brew.extra_packages]
    casks = [
      { name = "docker-desktop", verify = "Docker" },
      { name = "slack",          verify = "Slack" },
      { name = "discord",        verify = "Discord" },
      ...
    ]
    mas = [
      { id = 441258766, name = "Magnet" },
      { id = 904280696, name = "Things" },
    ]
    ```
    Full v1 personal package inventory migrates here.
  - `manifests/machines/work-laptop.toml`: bundles `["core", "gui"]`; extras carry work-cask inventory (slack, vscode, sourcetree, sublime-text, docker-desktop, miniconda, ms-office trio, zoom, fantastical, cardhop, firefox, raycast, appcleaner, alcove, things, magnet).
  - `manifests/machines/server-1.toml` and `server-2.toml`: bundles stay `["core"]`; extras empty (or near-empty).

- **Required ROADMAP / REQUIREMENTS edits (planner action items):**
  - `REQUIREMENTS.md` **PKGS-01**: text says `packages/brew/<purpose>.rb` and enumerates five bundles (`core, gui, dev, ops, personal`). Rewrite to: `packages/<purpose>.rb` (flat) and enumerate the v1 minimum `core, gui` — note that bundles are an as-needed grouping, not a fixed set.
  - `REQUIREMENTS.md` **PKGS-04**: text says "additive, concatenates with bundle contents." Expand to reflect the typed-bucket shape (`formulae` / `casks` / `mas`).
  - `ROADMAP.md` Phase 5 **success criterion #3**: enumerates exactly `core.rb, gui.rb, dev.rb, ops.rb, personal.rb` as the five bundle names. Amend to: bundles named by purpose (`core.rb`, `gui.rb`, +any future purpose-named additions) with NO `Brewfile-<profile>.rb` files anywhere; per-machine variation lives in `extra_packages` (typed buckets).
  - `docs/MANIFEST.md` schema reference: replace flat `extra_packages = []` row with the typed-bucket sub-table.
  - `PROJECT.md` Validated/Active sections: "Per-purpose bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`)" needs the same correction.

- **Install-pipeline participation** — `taskfiles/packages.yml`'s `packages:install` joins the root `task install` call graph (currently the brew-stub satisfies the slot). Final step of `task install` calls `task packages:verify` (VRFY-04 hard-fail contract; D-10 below).

- **`packages/README.md`** — replace Phase 1 stub with real README (purpose: minimal-bundles philosophy; how to add a bundle file vs add to a machine manifest; verify comment conventions; cask `# verify:` is mandatory).

**Out of scope (deferred to later phases or future versions):**

- `task validate` composition — P8 (CUTV-01). P5 ships `task packages:validate` ready to compose.
- `task links:reconcile` — P8. No interaction with packages.yml.
- Brew version pinning — not requested; out of v1 scope.
- A `dev` / `ops` / `personal` bundle if any machine ever wants them in the future — keep the door open (just add `packages/<name>.rb` and reference in the manifest), but don't ship them now.
- npm / cargo / pip package managers — out of v1 scope.
- Per-package install ordering / dependencies beyond what `brew bundle` itself handles.
- v1 `install/Brewfile*.rb` deletion — leave on disk until P8 (parallel-rewrite invariant; v1 stays byte-stable).

**Requirements addressed:** PKGS-01, PKGS-02, PKGS-03, PKGS-04, PKGS-05, VRFY-01, VRFY-02, VRFY-03, VRFY-04

</domain>

<decisions>
## Implementation Decisions

### Bundle Layout

- **D-01: Flat `packages/<purpose>.rb`** — not `packages/brew/<purpose>.rb`. Matches CLAUDE.md ("no `packages/brew/` subdirectory") and the ROADMAP Phase 5 success-criterion-#3 enumeration. REQUIREMENTS.md PKGS-01 currently says nested — that's the one that gets corrected, not the layout. Future package managers (if ever added) get their own top-level directory (`packages.npm`?), not nested under `packages/`.

- **D-02: Minimal bundles, heavy per-machine extras.** Only `core.rb` (server-safe CLI baseline) and `gui.rb` (laptop GUI baseline: 1Password + 1Password-CLI + Ghostty) ship as bundle files in v1. Drop `dev.rb`, `ops.rb`, `personal.rb` as named bundles — anything beyond the bare minimum lives in per-machine `extra_packages`. ROADMAP success criterion #3 amended; PROJECT.md "per-purpose bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`)" amended. v1's "self-describing per-machine" UX preserved without the named-suffix filename pattern. **Rationale (user-led):** "personal, server, work all allow me to add each individual brew package/cask/whatever to that machine profile. can't we maintain that flexibility in the new model?" — yes, via `extra_packages`; bundles become the small shared baseline rather than the per-machine catalog.

### extra_packages Schema

- **D-03: Typed-bucket sub-table.** TOML shape:
  ```toml
  [packages.brew.extra_packages]
  formulae = []  # bare strings OR { name, verify } objects
  casks    = []  # { name, verify } objects ONLY (D-04)
  mas      = []  # { id, name } objects ONLY
  ```
  Resolver deep-merges each sub-array independently with concat+dedupe. Composer emits the right Ruby DSL line per type — no name-to-type lookup, no network, no guessing. Replaces the current flat-array form (`extra_packages = ["docker-desktop"]`) in `defaults.toml` and every machine manifest. Migration cost is small (4 machine TOMLs + defaults.toml).

### Verify Rules

- **D-04: Cask verify is explicit on every line.** `cask '1password' # verify: 1Password` in bundle files; `{ name = "slack", verify = "Slack" }` in TOML extras. No derivation rule, no `brew info --json` runtime lookup. Reason: cask app-names diverge from cask-names enough (NVIDIA GeForce NOW, WhatsApp, Docker, Adobe Photoshop CC) that any heuristic produces enough false-negatives to undermine the contract. Doubling the authorship line-cost (every cask gets a comment) is acceptable in exchange for a verify pass that never lies.

- **D-05: Formula verify defaults to `command -v <formula>`; override via `# verify: <bin>`.** Bundle line `brew 'jq'` verifies `command -v jq`. Bundle line `brew 'ripgrep' # verify: rg` verifies `command -v rg`. For multi-binary formulas (`coreutils`, `grep`, `openssh`, `git`), pick ONE representative bin via override (`coreutils` # verify: gsha256sum; `grep` # verify: ggrep; `openssh` # verify: ssh) — proves the formula landed in a PATH-usable state without enumerating every bin (brew is atomic: a formula either installed or it didn't). TOML extras form: `{ name = "ripgrep", verify = "rg" }`; bare string `"hugo"` means "default rule applies."

- **D-06: MAS apps verify as `/Applications/<name>.app`.** Same check as casks. MAS apps install to `/Applications/` like casks; verify treats them identically. The `name` field in the `{ id, name }` object IS the verify name — no separate `verify` field. Examples: `{ id = 441258766, name = "Magnet" }` checks `/Applications/Magnet.app`; `{ id = 904280696, name = "Things" }` checks `/Applications/Things.app` (the v1 inventory uses these exact names).

- **D-07: `packages:verify` enumerates every package; doesn't stop at first failure.** Output is a check/cross table per package. Exit non-zero if any package failed (count of failures in the final summary line). Reason: a fresh install can land 80 packages with 3 failures; one-by-one fix-and-rerun is painful, full-enumeration lets the user fix all 3 in one go.

### Composition + Idempotency

- **D-08: Composed Brewfile at `$XDG_CACHE_HOME/dotfiles/Brewfile`** (cache, not state — regenerated cheaply on every install). Composition algorithm: read `packages.brew.bundles` from `resolved.json`, concatenate `packages/<bundle>.rb` files in declared order, then append rendered lines from `extra_packages.formulae`, `extra_packages.casks`, `extra_packages.mas` (in that fixed order). Atomic write: `mktemp` + `mv`. No per-machine suffix — the active machine's Brewfile is always at the same path (single-machine-active-at-a-time invariant from P1 D-15).

- **D-09: `packages:install` status block** uses TWO conditions:
  1. `test -f $XDG_CACHE_HOME/dotfiles/Brewfile` — composed file exists.
  2. `brew bundle check --file=$XDG_CACHE_HOME/dotfiles/Brewfile --no-upgrade` — exit 0 means everything declared is installed.
  Both pass → no-op. Either fails → regenerate composed + run `brew bundle install`. Status block uses `{{.X}}` template vars only (LINT-02 compliance). `brew bundle check --no-upgrade` is sub-second on a converged machine — matches the ROADMAP success criterion #2 target.

- **D-10: Verify is hard-fail at the install gate.** `task install`'s final step is `task packages:verify`; a missing bin or missing `.app` fails the entire `task install` with exit 1 after printing the full check/cross table. No `--no-verify` escape hatch, no env-var bypass. Reasons: (a) the whole point of VRFY-04 is "silent install failures caught at the verification layer"; an escape hatch becomes permanent muscle memory the moment one cask is broken upstream. (b) `task install` is idempotent end-to-end, so the recovery path is "fix the manifest or the upstream cask, re-run task install" — not "skip verify."

### Audit (Drift Detection)

- **D-11: `packages:audit` is non-blocking by default; `--strict` exits non-zero.** Matches ROADMAP success criterion #5 verbatim. Default: print drift list, exit 0 (informational; CI runs `task install` separately and that's the strict gate). `task packages:audit -- --strict` exits 1 for CI / pre-merge / a pre-commit hook if josh wants one later. Scope: `brew leaves` for formulae (top-level only — `brew install ripgrep` shows up; `brew install <dep-of-something-already-declared>` does NOT show up unless it's also a leaf), `brew list --cask` for casks (no dep concept on the cask side), `mas list` for MAS apps. Diff against the union of (composed Brewfile contents) + (TOML extras).

### Claude's Discretion (planner concerns)

- **MAS in `core.rb` vs absent on servers** — `mas` (the CLI tool) lives in `core.rb` because the resolver simplicity wins: every machine has `mas` installed even if the machine doesn't use any MAS *apps*. Cost: ~3MB per server. Acceptable. Planner can split it out (drop `mas` from `core.rb`, add to `gui.rb`) if the server cost feels wrong, but the default lands in `core.rb`.

- **MAS app naming sanity check** — verify against the real `mas list` output for known IDs (`mas list | grep -i magnet` shows the exact installed name) and use that as the `name` field. Planner sanity-checks this against josh's live machine before committing the manifest extras.

- **`packages:install` aggregator placement in `task install`** — currently `task install`'s `cmds:` calls `task brew:install` (against the stub). P5 renames the include from `brew:` to `packages:` in the root `Taskfile.yml` (`brew:` was the v1 namespace; `packages:` matches the new directory + concern). Update the root `install` task's `cmds:` to call `task packages:install` and `task packages:verify`. Planner picks final ordering: today's order is `links:all → brew:install → claude:install → macos:defaults → macos:shell → done`. P5 wants `packages:verify` AFTER `packages:install` and IDEALLY at the very end (after macos:shell) — that final position is the one the ROADMAP success criterion #6 mentions.

- **Composer implementation language** — could be a zsh script in `install/` (e.g., `install/compose-brewfile.zsh` reading `resolved.json` via `jq`) or inline in the `packages:install` task's `cmds:` block. The zsh-script-in-`install/` approach mirrors `install/resolver.zsh` from P1 and is more testable. Planner picks.

- **Header banner in the composed Brewfile** — emit a comment block at the top of the composed file naming the source bundles + machine + timestamp, so a confused human running `cat $XDG_CACHE_HOME/dotfiles/Brewfile` can see how it was assembled. Cost is one extra `cat <<EOF` block; benefit is one less "where did this come from?" question. Strongly recommended; planner finalizes the format.

- **Default `verify` name for unknown casks (LINT-09 proposal)** — D-04 says "required on every cask." If a planner-written bundle file ships a `cask '<foo>'` line without `# verify:`, the validator should reject it at compose time (or `task lint` should). LINT-rule extension: "cask line without `# verify:` comment fails lint." Strongly recommended addition to P2's lint suite (or a new LINT-09 added in P5).

- **MAS app verify when `mas` itself isn't installed on a server** — moot if `mas` is in `core.rb` (D-11 footnote) and servers have empty `mas` extras. If a server's manifest had a MAS app declared (it doesn't, but hypothetically), the verify would try to find the `.app` — same `/Applications/<name>.app` check — which would fail because servers don't have GUI app installs in the normal flow. Planner doesn't have to handle this; the schema already forbids the case implicitly (servers don't declare MAS apps).

- **What about `tap` directives in v1 brewfiles?** — v1 `install/Brewfile.rb` doesn't use `tap`. If a future formula requires a tap, it'd go inline in the bundle file (`tap 'foo/bar'` followed by `brew 'foo/bar/baz'`). The composer concatenates verbatim — no special handling needed.

- **`1Password CLI` cask vs formula** — Homebrew's `1password-cli` is a *cask* that installs the `op` binary on PATH but does not lay down a `.app` bundle. D-06 verify rule (`/Applications/<name>.app`) does not apply. Planner picks: keep as cask but treat as a verify-special-case (`command -v op`), OR move to `packages/core.rb` as a `brew '1password-cli' # verify: op` line (cleaner). Recommended: move to `core.rb` (or to `gui.rb`'s formula list if a separation matters) so the verify rule is uniform.

### Carried Forward (not re-decided in this discussion)

- **CF-01:** Manifest is the source of truth — `taskfiles/packages.yml` reads `packages.brew.bundles` and `packages.brew.extra_packages.*` from `resolved.json` via `ref: fromJson` (P1 D-15, P2/P4 confirmed pattern). No hostname inference.
- **CF-02:** kebab-case feature keys use `index` form in go-template; snake_case keys like `packages.brew.bundles` use dot access (CLAUDE.md, repeated in every prior CONTEXT).
- **CF-03:** `status:` blocks use `{{.X}}` template vars ONLY — never `$X` shell vars (LINT-02; the v1 `macos:shell:145` bug class). `packages:install`'s status block (D-09) conforms.
- **CF-04:** Every install task has a `status:` block; aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker (LINT-01/03a). `packages:install` is an aggregator IF the planner splits compose / brew-install / verify into sub-tasks; otherwise it carries its own `status:` block.
- **CF-05:** No bare `ln -s` outside `taskfiles/helpers.yml` (LINT-03b). P5 has no symlinks (no `packages/` symlinks declared in `taskfiles/links.yml` per the existing comment block); `_:safe-link` not used here.
- **CF-06:** `set -euo pipefail` on every executable `.zsh` (LINT-04). If composer lives in `install/compose-brewfile.zsh`, header conforms.
- **CF-07:** XDG everywhere — composed Brewfile at `$XDG_CACHE_HOME/dotfiles/Brewfile` matches CF and CLAUDE.md.
- **CF-08:** `deps: [manifest:resolve]` on every `packages:*` task that reads `resolved.json` — ensures fresh JSON (P1 D-14 pattern, reused by P4 `identity.yml`).
- **CF-09:** `install/messages.zsh` sourced via `{{.DOTFILES_MESSAGES}}` for check/cross output (P1 deliverable, used by P2/P3/P4).
- **CF-10:** Detect Homebrew prefix via `uname -m`; use `$HOMEBREW_PREFIX` (shell) / `{{.HOMEBREW_PREFIX}}` (task) — never hardcode `/opt/homebrew` (CLAUDE.md).
- **CF-11:** Parallel rewrite — v1 `install/Brewfile.rb`, `Brewfile-personal.rb`, `Brewfile-work.rb`, `Brewfile-server.rb` stay on disk; P8 owns their deletion (CONTEXT precedent from P1–P4).
- **CF-12:** No AI attribution in commits or source; no emojis (project convention, hook-enforced).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints, Out of Scope ("Inline profile branching in shared files — replaced by manifest-driven feature gates"), Validated/Active package lines (P5 updates these — see required edits in `<domain>`)
- `.planning/REQUIREMENTS.md` PKGS-01..05, VRFY-01..04 — Full requirements; PKGS-01 + PKGS-04 text needs editing per D-01 + D-03
- `.planning/ROADMAP.md` Phase 5 section — Goal, six success criteria, requirement mapping; success criterion #3 needs editing per D-02 (5-bundle enumeration → 2-bundle minimum, "no Brewfile-<profile>.rb" prohibition stays)
- `.planning/STATE.md` — Pre-Phase-5 state (Phases 1–4 complete; resolved.json + lint + shell + identity layers shipped)

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md` — Phase 1 decisions binding on P5:
  - **D-14:** Auto-rebuild via task precondition — `packages.yml` declares `deps: [manifest:resolve]`
  - **D-15:** `resolved.json` at `$XDG_STATE_HOME/dotfiles/resolved.json` — machine-local; one-active-machine-at-a-time invariant (D-08 composed Brewfile path follows)
  - **D-16:** Missing-state hard-fail pattern — `packages:install` aborts cleanly when state file or resolved.json is absent
- `.planning/phases/02-install-engine-bootstrap-idempotency-lint/02-CONTEXT.md` — Phase 2 decisions binding on P5:
  - **D-12:** All lint logic inlined in `taskfiles/lint.yml`; `taskfiles/packages.yml` must pass LINT-01..04 + LINT-07. P5 proposes a new lint rule (LINT-09: "cask line without `# verify:` comment fails lint" — see Claude's Discretion).
  - **D-13:** Lint severity model — LINT-02 (`$VAR` in `status:`) and LINT-03a (`cmds:` without `status:`) are blocking; `packages.yml` conforms.
- `.planning/phases/03-shell-layer-flat-content-port/03-CONTEXT.md` — Phase 3 decisions binding on P5:
  - **Antidote replaces antigen** — `core.rb` carries `antidote` (the new plugin manager); `antigen` is dropped. v1's `install/Brewfile.rb:71` `brew "antigen"` does NOT port forward.
- `.planning/phases/04-identity-layer-git-ssh-per-machine/04-CONTEXT.md` — Phase 4 decisions binding on P5:
  - **Deferred from P4, picked up by P5:** "Brewfile composition for `cloudflared` and `1password-cli`" — `cloudflared` in `core.rb` (D-domain); `1password-cli` lands as a formula-style entry (Claude's Discretion above). Personal SSH identity's `ProxyCommand` depends on `cloudflared` being on PATH — verify catches a missing install at the install gate.

### Existing v1 Codebase (sources for the port)
- `install/Brewfile.rb` — v1 common Brewfile; sourced verbatim for `packages/core.rb` (minus `antigen`)
- `install/Brewfile-personal.rb` — v1 personal-suffix Brewfile; sourced for `personal-laptop.toml` `extra_packages.casks` + `.mas` (NOT a v2 bundle file)
- `install/Brewfile-work.rb` — v1 work-suffix Brewfile; sourced for `work-laptop.toml` `extra_packages.casks` + `.mas`
- `install/Brewfile-server.rb` — v1 server-suffix Brewfile; v2 servers don't include `gui` so most contents drop. Anything actually needed on a v2 ops server goes into the server's `extra_packages` (in practice: empty or near-empty)
- `taskfiles/brew.yml` — v1 install/update/bundle tasks (with the `brew:bundle` no-status idempotency hole per CONCERNS.md tech-debt). NOT loaded by v2 (replaced by `taskfiles/brew-stub.yml` in P2, becomes `taskfiles/packages.yml` in P5).
- `taskfiles/brew-stub.yml` — Phase 2 stub for the `brew:` include slot in root `Taskfile.yml`. P5 replaces it with the real `taskfiles/packages.yml` (and updates the root include name from `brew:` to `packages:`).
- `.planning/codebase/CONCERNS.md` — Tech debt P5 must NOT reintroduce:
  - `brew:bundle` lacks `status:` (taskfiles/brew.yml:52-63) — P5's `packages:install` has the two-condition status from D-09.
  - `gsd-install` runs `npx` every install (taskfiles/claude.yml) — separate (P7 fixes); pattern lesson: every install task needs a real `status:` guard.

### Manifest Layer (P5 reads + writes)
- `manifests/defaults.toml` — P5 changes `extra_packages = []` to the typed-bucket sub-table (D-03). Existing `[packages.brew] bundles = ["core"]` stays.
- `manifests/machines/personal-laptop.toml` — P5 changes `bundles` from `["core", "gui", "dev", "personal"]` to `["core", "gui"]`; populates `extra_packages.{casks,mas}` from v1 `Brewfile-personal.rb`. `extra_packages = ["docker-desktop"]` migrates to `casks = [{ name = "docker-desktop", verify = "Docker" }]`.
- `manifests/machines/work-laptop.toml` — bundles trim to `["core", "gui"]`; populate extras from v1 `Brewfile-work.rb`.
- `manifests/machines/server-1.toml` and `server-2.toml` — bundles stay `["core"]`; extras stay empty (or near-empty).
- `docs/MANIFEST.md` — P5 updates the schema reference: `extra_packages` row becomes a sub-table block; the `[packages.brew]` section gains `bundles` + `extra_packages.{formulae,casks,mas}` rows.

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — v2 conventions: flat directories in v1 ("No packages/brew/ subdirectory"), one concept per file (one bundle per `packages/<purpose>.rb`), `status:` blocks use template vars only, no hardcoded `/opt/homebrew`
- `.claude/CLAUDE.md` — Project-level Claude instructions; reaffirms flat layout + manifest-as-truth + LINT contract
- `~/.config/claude/CLAUDE.md` — Global conventions (no AI attribution; no curl-to-sh; etc.)

### External Reference (Homebrew documentation)
- Homebrew `brew bundle` docs — `brew bundle check`, `--no-upgrade`, `--file=` flag semantics. Exit-0 = everything installed; exit-non-zero = action needed. Sub-second on converged machine (planner sanity-checks the assumption).
- Homebrew `brew leaves` — top-level formulae only; the right tool for drift detection (`packages:audit` D-11).
- `mas` CLI docs — `mas list` (id + name), `mas install <id>`, `mas signin <apple-id>` (auth state outside `task install`'s scope).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (port from v1; minor surgery in transit)
- **`install/Brewfile.rb`** — ports nearly verbatim to `packages/core.rb`. Surgery: drop `brew "antigen"` (P3 dropped antigen for antidote); add `brew "antidote"` if missing (P3 may have already declared it in `core.rb` planning — planner verifies). Per-line verify comments added to non-conformers (`coreutils` # verify: gsha256sum; `grep` # verify: ggrep; `openssh` # verify: ssh; `git-delta` # verify: delta; `bottom` # verify: btm; `trippy` # verify: trip).
- **`install/Brewfile-personal.rb`** — splits into `personal-laptop.toml`'s `extra_packages.casks` (with per-entry `verify` fields) and `.mas`. No more `.rb` file with this name — content moves into the manifest TOML.
- **`install/Brewfile-work.rb`** — same surgery, content moves into `work-laptop.toml`.
- **`install/Brewfile-server.rb`** — surgery: v2 servers are headless ops, so the GUI-cask content largely drops. `dropbox`, `appcleaner`, `1password`, `cryptomator` etc. are personal-Mac-server v1 holdovers that don't apply to v2 ops servers. Anything actually needed lands in `server-N.toml` `extra_packages`.
- **`install/messages.zsh`** — reused by `taskfiles/packages.yml` for `check`/`cross` validation output (P1 deliverable; used by P2/P3/P4).
- **`taskfiles/helpers.yml`** — `_:check-command` (assert `command -v <bin>` works) is a natural building block for `packages:verify`'s formula checks. `_:check-file` handles cask `.app` checks. Planner may use these directly or inline equivalent `command -v` / `test -d` checks.
- **`install/resolver.zsh` precedent** — the pattern for "a `.zsh` script in `install/` that reads `resolved.json` via jq and emits an artifact." `install/compose-brewfile.zsh` (if the planner picks that approach over inline-cmds) mirrors `resolver.zsh` shape.

### Established Patterns (binding on P5)
- **`status:` blocks use `{{.X}}` template vars only** — LINT-02. `packages:install` D-09 conforms.
- **Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker** — applies if `packages:install` is split into compose + brew-bundle + verify sub-tasks.
- **`set -euo pipefail` on every executable `.zsh`** — `install/compose-brewfile.zsh` (if used) conforms.
- **Manifest as runtime source of truth** — `packages.yml` reads `resolved.json` via go-task `fromJson`. `packages.brew.bundles` uses dot access (snake_case); `packages.brew.extra_packages.formulae/casks/mas` use dot access (all snake/dot-friendly keys).
- **`deps: [manifest:resolve]`** — every `packages:*` task that reads `resolved.json` declares this.
- **Public-only-content convention** — bundle files (`packages/*.rb`) and manifest extras carry no secrets (formula/cask names are public).

### Integration Points
- **`packages/` → `manifests/`** — `taskfiles/packages.yml` reads `packages.brew.bundles` and `packages.brew.extra_packages.{formulae,casks,mas}` from `resolved.json`.
- **`packages/` → root `Taskfile.yml`** — root's `includes:` block changes the `brew:` slot from `./taskfiles/brew-stub.yml` to `./taskfiles/packages.yml`, AND renames the include key from `brew:` to `packages:` (the v1 `brew:` namespace was tied to the old `brew.yml` semantics; v2 uses purpose-named `packages:`). Root `install` task's `cmds:` changes `task: brew:install` to `task: packages:install` and gains `task: packages:verify` as the new final step.
- **`packages/` → P4 `identity/`** — `cloudflared` in `core.rb` is the dependency P4 flagged; personal SSH identity's `ProxyCommand` works only when `command -v cloudflared` succeeds — verify catches a missing install at the install gate.
- **`packages/` → `task validate`** — P5 ships `task packages:validate` (and `packages:verify`); P8 composes the root `task validate` (CUTV-01).
- **`packages/` → `$XDG_CACHE_HOME/dotfiles/`** — first cache-path consumer in v2 (P1–P4 used state/config, not cache). Cache dir creation via `mkdir -p` inside the composer (no special helper needed; `_:safe-link` is for symlinks).

</code_context>

<specifics>
## Specific Ideas

- **`packages/core.rb` skeleton (port from `install/Brewfile.rb`):**
  ```ruby
  # packages/core.rb -- server-safe CLI baseline. Every machine includes this.
  #
  # Verify rules:
  #   brew '<name>'                  -> command -v <name>     (default)
  #   brew '<name>' # verify: <bin>  -> command -v <bin>      (override)

  brew 'zsh'
  brew 'go-task'
  brew 'yq'
  brew 'jq'
  brew 'git'
  brew 'git-delta'           # verify: delta
  brew 'openssh'             # verify: ssh
  brew 'wget'
  brew 'eza'
  brew 'bat'
  brew 'fd'
  brew 'grep'                # verify: ggrep
  brew 'glow'
  brew 'highlight'
  brew 'grc'
  brew 'htop'
  brew 'duf'
  brew 'whois'
  brew 'doggo'
  brew 'hugo'
  brew 'ncdu'
  brew 'tlrc'
  brew 'trippy'              # verify: trip
  brew 'cloudflared'
  brew 'fastfetch'
  brew 'onefetch'
  brew 'bottom'              # verify: btm
  brew 'coreutils'           # verify: gsha256sum
  brew 'mas'
  brew 'antidote'
  ```
  Planner verifies the per-line verify overrides against live `brew info`. Notable conformers needing override: `git-delta` (bin = `delta`), `grep` (bin = `ggrep` from coreutils-style GNU grep), `trippy` (bin = `trip`), `bottom` (bin = `btm`), `coreutils` (pick `gsha256sum` as representative).

- **`packages/gui.rb` skeleton:**
  ```ruby
  # packages/gui.rb -- laptop GUI baseline. Any machine with a display.
  #
  # Verify rules:
  #   cask '<name>' # verify: <App Name>  -> /Applications/<App Name>.app  (MANDATORY)

  cask '1password'      # verify: 1Password
  cask 'ghostty'        # verify: Ghostty
  ```
  `1password-cli` deliberately omitted from gui.rb — it's a CLI-only cask with no `.app` (D-discretion). Planner places it in `core.rb` as `brew '1password-cli' # verify: op` OR as a special-cased cask entry (planner picks; brew-formula path is cleaner).

- **`manifests/machines/personal-laptop.toml` `[packages]` block (after P5 migration):**
  ```toml
  [packages.brew]
  bundles = ["core", "gui"]

  [packages.brew.extra_packages]
  formulae = []  # all CLI lives in core.rb

  casks = [
    { name = "discord",              verify = "Discord" },
    { name = "slack",                verify = "Slack" },
    { name = "whatsapp",             verify = "WhatsApp" },
    { name = "spotify",              verify = "Spotify" },
    { name = "appcleaner",           verify = "AppCleaner" },
    { name = "raycast",              verify = "Raycast" },
    { name = "alcove",               verify = "Alcove" },
    { name = "protonvpn",            verify = "Proton VPN" },
    { name = "proton-mail",          verify = "Proton Mail" },
    { name = "proton-drive",         verify = "Proton Drive" },
    { name = "dropbox",              verify = "Dropbox" },
    { name = "cryptomator",          verify = "Cryptomator" },
    { name = "sourcetree",           verify = "Sourcetree" },
    { name = "sublime-text",         verify = "Sublime Text" },
    { name = "visual-studio-code",   verify = "Visual Studio Code" },
    { name = "standard-notes",       verify = "Standard Notes" },
    { name = "fantastical",          verify = "Fantastical" },
    { name = "cardhop",              verify = "Cardhop" },
    { name = "microsoft-word",       verify = "Microsoft Word" },
    { name = "microsoft-excel",      verify = "Microsoft Excel" },
    { name = "microsoft-powerpoint", verify = "Microsoft PowerPoint" },
    { name = "zoom",                 verify = "zoom.us" },
    { name = "firefox",              verify = "Firefox" },
    { name = "nvidia-geforce-now",   verify = "NVIDIA GeForce NOW" },
    { name = "cloudflare-warp",      verify = "Cloudflare WARP" },
    { name = "miniconda",            verify = "Miniconda" },
    { name = "docker-desktop",       verify = "Docker" },
  ]

  mas = [
    { id = 441258766, name = "Magnet" },
    { id = 904280696, name = "Things" },
  ]
  ```
  Planner sanity-checks every `verify` field against `mdfind -name '<App>.app' -onlyin /Applications` (or `ls /Applications/` after a fresh install) on josh's live machine — verify-name typos are the #1 false-positive source.

- **`manifests/machines/work-laptop.toml` `[packages]` block (after P5 migration):**
  ```toml
  [packages.brew]
  bundles = ["core", "gui"]

  [packages.brew.extra_packages]
  casks = [
    { name = "slack",                verify = "Slack" },
    { name = "spotify",              verify = "Spotify" },
    { name = "sourcetree",           verify = "Sourcetree" },
    { name = "sublime-text",         verify = "Sublime Text" },
    { name = "visual-studio-code",   verify = "Visual Studio Code" },
    { name = "appcleaner",           verify = "AppCleaner" },
    { name = "raycast",              verify = "Raycast" },
    { name = "alcove",               verify = "Alcove" },
    { name = "standard-notes",       verify = "Standard Notes" },
    { name = "fantastical",          verify = "Fantastical" },
    { name = "cardhop",              verify = "Cardhop" },
    { name = "microsoft-word",       verify = "Microsoft Word" },
    { name = "microsoft-excel",      verify = "Microsoft Excel" },
    { name = "microsoft-powerpoint", verify = "Microsoft PowerPoint" },
    { name = "zoom",                 verify = "zoom.us" },
    { name = "firefox",              verify = "Firefox" },
    { name = "miniconda",            verify = "Miniconda" },
    { name = "docker-desktop",       verify = "Docker" },
  ]

  mas = [
    { id = 441258766, name = "Magnet" },
    { id = 904280696, name = "Things" },
  ]
  ```

- **`manifests/machines/server-1.toml` and `server-2.toml` `[packages]` block** — stays:
  ```toml
  [packages.brew]
  bundles = ["core"]

  [packages.brew.extra_packages]
  formulae = []
  casks = []
  mas = []
  ```

- **`manifests/defaults.toml` `[packages.brew]` block (after P5 migration):**
  ```toml
  [packages.brew]
  bundles = ["core"]

  [packages.brew.extra_packages]
  formulae = []
  casks = []
  mas = []
  ```

- **`taskfiles/packages.yml` task names:**
  - `packages:install` — aggregator (or single task with two-condition status from D-09). Composes Brewfile + runs `brew bundle install`.
  - `packages:compose` — render the composed Brewfile only (inspection helper).
  - `packages:verify` — per-package check/cross; hard-fail at end (D-07 + D-10).
  - `packages:audit` — drift detector; non-blocking by default, `--strict` exits non-zero (D-11).
  - `packages:validate` — composed into root `task validate` in P8 (currently aliased to or wrapping `packages:verify`).

- **Composed Brewfile header (planner finalizes format):**
  ```ruby
  # AUTO-GENERATED by task packages:compose on 2026-MM-DD HH:MM:SS
  # Machine:  personal-laptop
  # Bundles:  core, gui
  # Extras:   28 casks, 2 mas, 0 formulae
  # DO NOT EDIT -- regenerated on every task install.
  ```

- **Composer pseudocode (whether in install/compose-brewfile.zsh or inline):**
  ```
  read $RESOLVED_JSON_PATH
  bundles = .packages.brew.bundles[]
  extras  = .packages.brew.extra_packages

  emit header banner
  for b in bundles:
    emit "# === bundle: ${b}.rb ==="
    cat packages/${b}.rb
  emit "# === extras (formulae) ==="
  for f in extras.formulae:
    emit "brew '${f.name|or f}'${verify_comment}"
  emit "# === extras (casks) ==="
  for c in extras.casks:
    emit "cask '${c.name}' # verify: ${c.verify}"
  emit "# === extras (mas) ==="
  for m in extras.mas:
    emit "mas '${m.name}', id: ${m.id}"

  atomic mv tempfile -> $XDG_CACHE_HOME/dotfiles/Brewfile
  ```

</specifics>

<deferred>
## Deferred Ideas

### Owned by later phases (do not pull into P5 scope)
- **`task validate` composition** — Phase 8 (CUTV-01). P5 ships `task packages:validate` ready to compose.
- **`task links:reconcile` orphan detection** — Phase 8 (CUTV-02). No packages.yml interaction.
- **`docs/CUTOVER.md` per-machine procedure** — Phase 8 (DOCS-08). The "what to do when verify fails on a fresh server because some upstream cask broke" recovery procedure lives there.
- **`docs/MIGRATION.md` v1→v2 mapping** — Phase 8 (DOCS-05). The "v1 `Brewfile-personal.rb` ⇒ v2 `personal-laptop.toml` `extra_packages.casks`" mapping table lives there.
- **`brew bundle dump` cleanup mode** — out of scope. `brew bundle cleanup --file=<composed>` would uninstall undeclared formulae/casks; matches `packages:audit --strict` intent but adds destructive action. Defer to PERF-V2 or a future cutover utility; v1 is detect-only via `audit`.
- **v1 `install/Brewfile*.rb` deletion** — Phase 8. v1 files stay byte-stable until cutover completes.
- **LINT-09 (lint cask-without-verify-comment)** — proposed in Claude's Discretion. Strongly recommended addition to `taskfiles/lint.yml`; planner picks whether P5 ships it or P2's lint suite gets a follow-up plan. If LINT-09 ships in P5, it lives in `taskfiles/lint.yml` (per P2 D-12 "all lint logic inlined here") and runs against `packages/*.rb`.

### Future hardening (out of v1 scope)
- **Brew version pinning** — `brew '<name>', args: { version: '1.2.3' }` exists; not used in v1. If josh needs deterministic versions later, the manifest grows a per-formula `version` field; verify checks the running version too.
- **npm / cargo / pip package manifests** — `[packages.npm.extra_packages]`, etc. Out of v1 scope. The typed-bucket pattern from D-03 generalizes naturally if these enter scope later.
- **Per-machine `tap` declarations** — v1 doesn't use `tap`. If a future formula needs a custom tap, it goes inline in the bundle file (`tap 'foo/bar'` line); the composer concatenates verbatim. No `taps = [...]` field needed.
- **Brew bundle pre-install snapshot for rollback** — PERF-V2 candidate per REQUIREMENTS.md. Not v1.
- **Strict-mode CI gate for `packages:audit`** — planner notes the CLI flag exists (D-11); actual CI wiring is a P8 / post-v1 task (GitHub Actions or pre-commit hook wiring isn't shipping in v1).
- **Per-bundle dry-run mode** — `DRY_RUN=1 task packages:install` prints the composed Brewfile + the `brew bundle check` result without acting. PERF-V2 candidate.
- **MAS auth bootstrap** — `mas signin <apple-id>` requires interactive auth. If a fresh server somehow declared MAS apps (it doesn't), the install would fail at the `mas install` step. Out of v1 scope to automate; servers don't declare MAS apps in practice.

### Open questions for later (not blocking P5)
- **`1password-cli` location** — placed via Claude's Discretion above. If `1password-cli` is a formula-style CLI without a `.app`, planner moves to `core.rb` as `brew '1password-cli' # verify: op` and removes any cask line. Verify live before committing.
- **`zoom`'s installed app name** — currently `zoom.us` (per v1 install observation). Planner sanity-checks against `ls /Applications/` on josh's live personal-laptop.
- **Empty `formulae = []` in every machine** — given heavy-extras + minimal-bundles, `formulae` extras may stay empty for v1's four machines (all CLI lives in `core.rb`). That's fine — typed-bucket lets it stay empty without schema fuss.

</deferred>

---

*Phase: 05-packages-layer-brewfile-composition-verification*
*Context gathered: 2026-05-15*
