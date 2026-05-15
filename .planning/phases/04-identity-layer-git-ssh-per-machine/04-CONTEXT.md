# Phase 4: Identity Layer — Git + SSH per Machine - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the identity layer: manifest-driven git + SSH per machine, with no hostname literals and no filename suffixes anywhere in the identity-determining code path. Replace v1's `Match exec "cat .../profile = 'X'"` SSH config and v1's `config-<profile>.rb`-style git wiring with a clean three-layer model:

1. **Shared scaffolding** — One `identity/git/config` and one `identity/ssh/config` deployed to every machine. The git config carries tooling (aliases, delta, fetch.prune, etc.), the default `[user.name]`, and `[includeIf gitdir:~/git/<X>/]` blocks for personal and work. The SSH config carries the global `Host *` block (`SetEnv TERM=xterm-256color`) plus `Include ~/.ssh/identities/active`.

2. **Per-identity content** — Flat `identity/git/identities/<name>` and `identity/ssh/identities/<name>` files, one per identity (`personal`, `work`, `server-1`, `server-2`). Deployed on every machine; activated by `includeIf` (git) or by the `active` symlink (SSH).

3. **Manifest-driven selection** — Machine TOML declares `identity.git` and `identity.ssh` (string enum). `taskfiles/identity.yml` reads `resolved.json` to choose which identity file the SSH `active` symlink targets. Git side has no equivalent active-pointer on workstations (gitdir match drives selection); servers get a wildcard `gitdir:~/` includeIf so their single identity applies everywhere on the box.

**In scope:**
- Schema change in `manifests/defaults.toml` + `manifest:validate`: enum for `identity.git`/`identity.ssh` becomes `{"personal", "work", "server-1", "server-2", "none"}`.
- Schema additions to `[features]`: split `one-password-ssh` into `one-password-ssh` (agent + `IdentityAgent`) and `one-password-signing` (git `op-ssh-sign` program). Default `false`.
- New manifest validation rules: `identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true`; `identity.git ∈ {personal, work} ⇒ features.one-password-signing = true`.
- `identity/git/config` — main config: aliases, delta, fetch.prune, init.defaultBranch, status, core.editor, `[user] name = "Josh Vaughen"`, `[includeIf "gitdir/i:~/git/personal/"] path = identities/personal`, same for `~/git/work/`. v1 `git/config`'s `[includeIf gitdir:~/git/server/]` block is dropped (server identity is now per-machine; the workstation includeIf'd "server" gitdir convention doesn't carry).
- `identity/git/identities/personal` — port v1 `git/config-personal` verbatim (`name`, `email`, `signingkey`, `[github]`, `[gpg "ssh"] program = .../op-ssh-sign`, `[commit] gpgsign = true`).
- `identity/git/identities/work` — port v1 `git/config-work` verbatim (`name`, signing config, `[commit] gpgsign = true`). Email TBD by user before merge; current v1 file is incomplete (no email).
- `identity/git/identities/server-1` — new file. `name = "Server-1"`, `email = "server-1@jgrid.net"`, `gpgsign = false`. The wildcard `[includeIf "gitdir:~/"]` block is NOT inside this file (gitconfig `[includeIf]` only applies to the file being loaded, not its own location) — see D-08 for how the wildcard gets wired on server machines.
- `identity/git/identities/server-2` — same shape with `server-2` email.
- `identity/ssh/config` — main config: `Host * SetEnv TERM=xterm-256color`, then `Include ~/.ssh/identities/active`. One file, one Include.
- `identity/ssh/identities/personal` — port v1 `ssh/configs/config-personal` (Host * `IdentityAgent ...1password...`; `Host *.jgrid.net` block with `IdentityFile ~/.ssh/identities/keys/personal.pub`, `User josh`, `ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h`, `RemoteCommand`, `RequestTTY yes`; `Host *.plex.me` block).
- `identity/ssh/identities/work` — port v1 `ssh/configs/config-work` (Host * `IdentityAgent ...1password...`; placeholder for future work hosts).
- `identity/ssh/identities/server-1` — new file. `Host github.com IdentityFile ~/.ssh/id_ed25519_server-1, IdentitiesOnly yes, AddKeysToAgent yes`. No 1Password agent.
- `identity/ssh/identities/server-2` — same shape.
- `identity/ssh/keys/personal.pub` — port v1 `ssh/keys/id_ed25519_personal.pub` verbatim (rename).
- `identity/ssh/keys/server-1.pub` — new file. User provides the actual key contents before merge (or planner provides a placeholder + a docs/CUTOVER.md step to fill in on first server cutover).
- `identity/ssh/keys/server-2.pub` — same.
- `identity/ssh/cloudflared.zsh` — port v1 `ssh/cloudflared.zsh` verbatim (tiny `exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"` wrapper). Deployed on every machine (no conditional gate); only the personal SSH identity references it via `ProxyCommand`.
- `taskfiles/identity.yml` — new file. Reads `identity.git` and `identity.ssh` from `resolved.json`. Subtasks: `identity:install` (composes git + ssh + keys + cloudflared symlinks), `identity:git`, `identity:ssh`, `identity:validate`. Uses `_:safe-link` exclusively (no bare `ln`). Idempotent `status:` block uses `{{.X}}` template vars only (LINT-02 compliance).
- Install-pipeline participation: `taskfiles/links.yml`'s `all:` aggregator gains a `task: identity:install` entry (or the root `Taskfile.yml` does — planner picks). Phase 3's links.yml comment block already names P4 as the owner of the next aggregator extension.
- `task identity:validate` — asserts: (a) the four symlinks land where expected (`~/.config/git/config`, `~/.ssh/config`, `~/.ssh/identities/active`, `~/.ssh/identities/keys/<active>.pub` if applicable); (b) `git -C ~/git/personal config user.email` matches manifest expectation when the gitdir exists and `identity.git ∈ {personal, work}`; (c) `ssh-add -L` lists the expected key when `features.one-password-ssh = true`; (d) `identity/ssh/keys/` in repo contains only `*.pub` files. Composed into the root `task validate` (P8 finishes the composition; P4 just makes its piece available).
- Machine manifest edits: `server-1.toml` → `identity.git = "server-1"`, `identity.ssh = "server-1"`; `server-2.toml` → both `"server-2"`; `work-laptop.toml` → `features.one-password-signing = true` (it already has `one-password-ssh = true`); `personal-laptop.toml` → `features.one-password-signing = true`; servers leave both 1Password flags `false`.
- `identity/README.md` — replace the Phase 1 stub with the real README (purpose, key files, how to add an identity, how to add a machine). DOCS-02 anchor pattern continues.

**Out of scope (deferred to later phases):**
- `task validate` composition (Phase 8, CUTV-01). P4 ships `task identity:validate` ready to be composed; P8 owns the composition itself.
- `task links:reconcile` orphan detection (Phase 8, CUTV-02).
- `docs/CUTOVER.md` per-machine procedure (Phase 8, DOCS-08). The first-cutover step that pastes server pub keys into the repo lives there.
- Brewfile composition for `1password-cli` / `cloudflared` packages (Phase 5). P4 assumes `cloudflared` is installed via `core.rb` or similar; if it isn't, the personal-identity ProxyCommand fails. Planner verifies the dependency exists in `packages/` planning.
- The actual private keys for `id_ed25519_server-1` and `id_ed25519_server-2` — provisioned manually on each server before cutover. Never enter the repo.
- v1 modifications on master — v1 stays byte-stable.

**Required ROADMAP / REQUIREMENTS edits (planner action items):**
- `REQUIREMENTS.md` IDNT-05: text says "1Password SSH agent integration enabled only when manifest declares `one-password-ssh = true`" — update to reflect the split into two flags (`one-password-ssh` + `one-password-signing`).
- `docs/MANIFEST.md` schema reference table: `identity.git` and `identity.ssh` Allowed values column expands from `"personal" | "work" | "none"` to `"personal" | "work" | "server-1" | "server-2" | "none"`. `[features]` block gains `one-password-signing` row.
- `manifests/defaults.toml` — add `one-password-signing = false` to the `[features]` block.
- Phase 1's CONTEXT.md D-03 (required-field set) referenced the old three-value enum; that text is now superseded by the v2-Phase-4 schema change. Note in the migration log only; no edit to historical CONTEXT.md.

**Requirements addressed:** IDNT-01, IDNT-02, IDNT-03, IDNT-04, IDNT-05, IDNT-06, IDNT-07, IDNT-08

</domain>

<decisions>
## Implementation Decisions

### Git Wiring + gitdir Paths

- **D-01: Default identity + all `includeIf` blocks wired.** `identity.git = "personal"` on the manifest does not narrow which `includeIf` blocks exist in `identity/git/config`. The main config carries `[includeIf gitdir:~/git/personal/]` and `[includeIf gitdir:~/git/work/]` blocks on every machine; gitdir match (not manifest) drives identity at runtime. Manifest's `identity.git` is informational + validation input (see D-04).
- **D-02: Gitdir paths hardcoded in `identity/git/config`.** Universal across machines. No per-machine override, no manifest-declared workdir lists. If the working-tree layout ever diverges across machines, that's a future-v2 problem; v1 ships with `~/git/personal/` and `~/git/work/` baked into a single committed config.
- **D-03: All identity files (`personal`, `work`, `server-1`, `server-2`) deployed on every machine.** Same set of files under `~/.config/git/identities/` regardless of which machine is active. Symmetric with SSH. Servers carry personal+work identity files even though they never load them (they're dormant on machines where the relevant gitdir doesn't exist).
- **D-04: No unconditional default `[include]` — gitdir match is the only way to set `[user.email]` on workstations.** Outside `~/git/<personal|work>/`, git inherits `[user] name = "Josh Vaughen"` from `identity/git/config` and has no email set. Committing in a one-off scratch dir fails until the user sets `user.email` locally or moves into a matched gitdir. Manifest's `identity.git` is documentary on workstations: it drives `task identity:validate` (asserts the right author from the right gitdir) but emits no runtime config. Trade-off explicitly accepted: discipline > convenience.

### Server Identity

- **D-05: Schema enum expands to `"personal" | "work" | "server-1" | "server-2" | "none"`.** `manifest:validate` accepts the four new values (one per machine) plus `"none"`. The old three-value enum from Phase 1 D-03 is superseded.
- **D-06: Both git AND ssh identity files split per server.** No single shared `server` identity — `server-1` and `server-2` each get their own files on both sides. Each has a distinct email (`server-1@jgrid.net`, `server-2@jgrid.net`) and distinct `IdentityFile` reference (`~/.ssh/id_ed25519_server-1`, `~/.ssh/id_ed25519_server-2`).
- **D-07: Manifest values for server machines.** `server-1.toml`: `identity.git = "server-1"`, `identity.ssh = "server-1"`. `server-2.toml`: both `"server-2"`. The Phase 1 commits used `identity.git = identity.ssh = "none"` on the server TOMLs — that gets updated as part of P4.
- **D-08: Wildcard `[includeIf]` on server machines only, applied at install time.** `identity.yml` on server machines (i.e., when `identity.git ∈ {"server-1", "server-2"}`) materializes a tiny machine-local include file at `~/.config/git/server-include.config` containing `[includeIf "gitdir:~/"] path = identities/server-N`. The main `identity/git/config` carries an unconditional `[include] path = server-include.config` line. On workstations, no `server-include.config` is materialized — the `[include]` line silently resolves to nothing (git treats missing `[include]` paths as a no-op, unlike `[includeIf]` which also matches nothing gracefully). The wildcard `gitdir:~/` effectively makes the server identity the universal author on its own box without breaking workstation gitdir semantics. **Planner concern:** decide whether `server-include.config` gets symlinked from a committed `identity/git/server-include.config.template` (with the `server-N` placeholder substituted at install time) or generated by the install task from `resolved.json` — both are acceptable; pick whichever is more inspectable.
- **D-09: Server pub keys committed: `identity/ssh/keys/server-1.pub` and `server-2.pub`.** Symmetric with `personal.pub`. Private keys never enter the repo (IDNT-06). At cutover time on each server, the operator generates `id_ed25519_server-N`, pastes the pub into the repo, commits, then pushes — the cutover procedure in DOCS-08 (Phase 8) documents this. P4 ships placeholder `.pub` files (or stubs with `# generated at cutover time`) so the layout is in place; users replace them on first server cutover.

### SSH Wiring + Key Inventory

- **D-10: Single shared `identity/ssh/config` symlinked to `~/.ssh/config` on every machine.** Carries the global `Host * SetEnv TERM=xterm-256color` block plus exactly one `Include ~/.ssh/identities/active` line. No per-machine SSH main config; no `Match exec`.
- **D-11: All identity files deployed at `~/.ssh/identities/<name>` on every machine.** `personal`, `work`, `server-1`, `server-2` — four symlinks, same set everywhere. Symmetric with git.
- **D-12: `~/.ssh/identities/active` is a symlink to the manifest-selected identity file, written by `taskfiles/identity.yml`.** Swapping identity = relink `active`. The `Include ~/.ssh/identities/active` line in the main config never changes; only the symlink target does. Status check: `test -L ~/.ssh/identities/active && readlink ~/.ssh/identities/active` matches expected target.
- **D-13: SSH pub keys land under `~/.ssh/identities/keys/<name>.pub` (scoped subdirectory).** Not flat in `~/.ssh/`. Identity files reference them by full `~/.ssh/identities/keys/<name>.pub` path. Cleaner `~/.ssh/` top level (only `config` and `identities/`).
- **D-14: `cloudflared.zsh` lands at `~/.ssh/identities/cloudflared.zsh`** — deployed on every machine even though only the personal SSH identity uses it. No conditional gate. If a machine has `cloudflared` Homebrew formula missing, the ProxyCommand fails loudly when the user actually tries to `ssh *.jgrid.net` — acceptable because that ssh attempt only happens on machines where the user expects jgrid access (i.e., where personal identity is active anyway).

### 1Password Scope

- **D-15: Split `features.one-password-ssh` into two independent flags.** Defaults both `false` in `manifests/defaults.toml`:
  - `features.one-password-ssh = true` — enables `SSH_AUTH_SOCK` export (Phase 3 already wires this in `shell/.zprofile`) AND the personal/work SSH identity files' `IdentityAgent ...1password...agent.sock` directive is meaningful.
  - `features.one-password-signing = true` — enables git commit signing via the 1Password `op-ssh-sign` program path baked into personal/work git identity files.
  - The two flags are independent in principle, in practice both true on laptops and both false on servers — but the split preserves future flexibility.
- **D-16: Static identity files + manifest validation enforces consistency.** `identity/{git,ssh}/identities/{personal,work}` contain the 1Password directives unconditionally — files are inspectable as-committed; no templating, no `sed`-stripping at install time. `manifest:validate` enforces:
  - `identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true`
  - `identity.git ∈ {personal, work} ⇒ features.one-password-signing = true`
  - Server identities (`server-1`, `server-2`) have no implication for either flag (their files don't reference 1Password).
  Validator exits non-zero with an actionable error if a machine declares e.g. `identity.ssh = "personal"` but `features.one-password-ssh = false`. P4 extends `taskfiles/manifest.yml`'s `manifest:validate` task with these two cross-field rules.

### Claude's Discretion (planner concerns)

- **Symlink target for the main git config** — `~/.gitconfig` vs `~/.config/git/config`. The XDG-aware path (`~/.config/git/config`) is preferred per global conventions, but git resolves `[include]` and `[includeIf]` `path =` values relative to the *current* config file's directory. Both work; XDG path is cleaner. Planner picks.
- **`server-include.config` materialization strategy** (D-08) — committed template + install-time substitution vs. generated-by-install. Both work. Pick whichever produces a more inspectable on-disk artifact.
- **`task identity:install` aggregator placement** — extend `taskfiles/links.yml` `all:` aggregator to add `- task: identity:install`, or extend the root `Taskfile.yml` directly. Phase 3's links.yml comment already names P4 as the next extender; pick the cleaner path.
- **Where does `task identity:validate` get gitdir from to run the `git -C` assertion?** — Best read from the `identity.git` value, mapping `personal → ~/git/personal`, etc. Skip the assertion silently when the gitdir doesn't exist on disk (servers don't have `~/git/personal/`).
- **Placeholder content for unfilled server pub keys** — Either ship empty `*.pub` files with a header comment (`# Replace with id_ed25519_server-1.pub during cutover; see docs/CUTOVER.md`) or skip committing them entirely until the first server cuts over. Planner picks; the cutover procedure (DOCS-08) covers either path.
- **`identity/ssh/cloudflared.zsh` deployment scope** — D-14 says "every machine"; alternative is gating on `identity.ssh = "personal"`. Planner may choose either; the conservative "deploy everywhere" is the documented default.
- **`task identity:validate` failure threshold** — should missing `~/.ssh/identities/keys/personal.pub` on a machine with `identity.ssh = "personal"` be a hard failure or a warning when the file genuinely hasn't been provisioned yet (e.g., fresh-install mid-bootstrap)? Planner picks; recommendation: hard failure, with cutover-mode flag to soften.
- **Exact rename in `manifests/defaults.toml`** — D-15 introduces `features.one-password-signing`; if any existing machine TOML already sets `features.one-password-ssh = true`, the planner adds `one-password-signing = true` alongside (matching the all-laptops-have-1Password assumption). Servers' `false` defaults need no edit.

### Carried Forward (not re-decided in this discussion)

- **CF-01:** Flat directory layout — `identity/git/identities/<name>`, `identity/ssh/identities/<name>` (Phase 1 D-10).
- **CF-02:** `_:safe-link` for every symlink; no bare `ln` (Phase 2 D-13, LINT-03b).
- **CF-03:** `status:` blocks use `{{.X}}` template vars only — never `$X` shell vars (Phase 2 D-12, LINT-02; the v1 `macos:shell:145` bug class).
- **CF-04:** Every install task has a `status:` block; aggregator tasks omit `status:` with the `# lint-allow: cmds-without-status` marker (Phase 2 D-12, LINT-01/LINT-03a).
- **CF-05:** Manifest is the source of truth — no hostname inference, no env-var sniffing (PROJECT.md, OOS).
- **CF-06:** `set -euo pipefail` on every executable `.zsh` (Phase 2 LINT-04). Sourced-only files exempt; `cloudflared.zsh` is executable so the header applies.
- **CF-07:** `_dotfiles_feature <name>` helper available from Phase 3 (Phase 3 D-06). `taskfiles/identity.yml` reads features from `resolved.json` directly (`index .MANIFEST.features "one-password-ssh"`) rather than calling the shell helper, since tasks read JSON.
- **CF-08:** `features.one-password-ssh` already drives `SSH_AUTH_SOCK` export in `shell/.zprofile` per Phase 3 — P4 reuses the existing wiring; no `.zprofile` changes.
- **CF-09:** Public keys only in `identity/ssh/keys/` (IDNT-06). Private keys never committed under any circumstance. `task identity:validate` asserts the directory contains only `*.pub` files.
- **CF-10:** Phase 1 D-14 (auto-rebuild via task precondition) — `taskfiles/identity.yml` declares `deps: [manifest:resolve]` so `resolved.json` is fresh before any identity task reads it.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Context
- `.planning/PROJECT.md` — Core value, constraints (parallel rewrite, no hostname inference, no AI attribution, no emojis), v1 feature parity contract, known v1 issues to fix structurally
- `.planning/REQUIREMENTS.md` — Full requirements list (IDNT-01..08 in scope for P4)
- `.planning/ROADMAP.md` Phase 4 section — Goal, success criteria, requirement mapping
- `.planning/STATE.md` — Pre-Phase-4 state (Phase 3 complete; antidote + flat shell content shipped)

### Prior Phase Context (carries forward)
- `.planning/phases/01-manifest-engine-repository-skeleton/01-CONTEXT.md` — Phase 1 decisions binding on P4:
  - **D-03:** Required-field set in machine manifests includes `identity.git` and `identity.ssh` — P4's enum expansion (D-05) supersedes the three-value list
  - **D-10:** Flat directory layout binding on `identity/git/identities/` and `identity/ssh/identities/`
  - **D-14:** Auto-rebuild via task precondition — `identity.yml` declares `deps: [manifest:resolve]`
  - **D-15:** `resolved.json` at `$XDG_STATE_HOME/dotfiles/resolved.json` — machine-local
  - **D-16:** Missing-state hard-fail pattern — `identity:install` aborts cleanly when state file or resolved.json is absent
- `.planning/phases/02-install-engine-bootstrap-idempotency-lint/02-CONTEXT.md` — Phase 2 decisions binding on P4:
  - **D-12:** All lint logic inlined in `taskfiles/lint.yml`; `taskfiles/identity.yml` must pass LINT-01..04 + LINT-07
  - **D-13:** Lint severity model — LINT-02 (`$VAR` in `status:`) and LINT-03a (`cmds:` without `status:`) and LINT-03b (bare `ln`) are blocking; identity.yml conforms
- `.planning/phases/03-shell-layer-flat-content-port/03-CONTEXT.md` — Phase 3 decisions binding on P4:
  - **D-06 / D-08:** `_dotfiles_feature` helper exists; P4 may use it from shell side but `taskfiles/identity.yml` reads `resolved.json` directly via `fromJson`
  - **Carried `.zprofile` 1Password block** — already wires `SSH_AUTH_SOCK` based on `features.one-password-ssh`. P4 does not re-wire this; it ships only the identity-file side.

### Domain Research (already on disk)
- `.planning/research/STACK.md` — Tool versions; no P4-specific requirements
- `.planning/research/SUMMARY.md` — Synthesized research findings
- `.planning/research/PITFALLS.md` — Drift class (manifest vs runtime); applies to `~/.ssh/identities/active` symlink freshness

### Existing Codebase (v1 patterns — port what works, fix the known bug)
- `.planning/codebase/CONCERNS.md` — Live v1 bugs P4 must NOT reintroduce:
  - `.zprofile:55-56` literal `hostname -s != "server"` for 1Password — fixed in Phase 3 (`features.one-password-ssh` gate)
  - `ssh/configs/config:13-20` `Match exec "cat ~/.config/dotfiles/profile = 'X'"` — replaced by manifest-driven `~/.ssh/identities/active` symlink
  - `git/config:3-8` three `includeIf` blocks (personal/server/work) — personal+work blocks ported verbatim; server block removed (server identity is per-machine, wildcard-applied)
- `.planning/codebase/CONVENTIONS.md` — v1 naming/scripting conventions: `set -euo pipefail`, kebab-case files, no AI attribution, file-level comment block at top of every script
- `.planning/codebase/STRUCTURE.md` — v1 `git/` and `ssh/` trees (sources for the P4 port):
  - `git/config` + `git/config-personal` + `git/config-work` + `git/config-server` + `git/ignore`
  - `ssh/configs/config` + `ssh/configs/config-personal` + `ssh/configs/config-work` + `ssh/configs/config-server` + `ssh/configs/agent.toml`
  - `ssh/cloudflared.zsh`
  - `ssh/keys/id_ed25519_personal.pub`

### v1 Identity Files (direct ports, with documented divergences)
- `git/config` — main config; ports to `identity/git/config` with the `gitdir:~/git/server/` block dropped
- `git/config-personal` — ports to `identity/git/identities/personal` verbatim
- `git/config-work` — ports to `identity/git/identities/work` verbatim (email left to user before P4 merges)
- `git/config-server` — replaced by `identity/git/identities/server-1` and `server-2` (split per server; emails differ)
- `git/ignore` — global gitignore; ports to `identity/git/ignore` (referenced by main config's `core.excludesfile = ignore`)
- `ssh/configs/config` — replaced by `identity/ssh/config` (Match-exec dropped; single Include line replaces it)
- `ssh/configs/config-personal` — ports to `identity/ssh/identities/personal`; key path updates from `~/.ssh/id_ed25519_personal.pub` to `~/.ssh/identities/keys/personal.pub`
- `ssh/configs/config-work` — ports to `identity/ssh/identities/work`
- `ssh/configs/config-server` — replaced by `identity/ssh/identities/server-1` and `server-2` (deploy-key path updates)
- `ssh/configs/agent.toml` — 1Password agent config; lives outside the repo (in `~/.config/1Password/`) — out of scope for P4 (file is user-managed)
- `ssh/cloudflared.zsh` — ports to `identity/ssh/cloudflared.zsh` verbatim
- `ssh/keys/id_ed25519_personal.pub` — ports to `identity/ssh/keys/personal.pub`

### Manifest Layer (P4 reads + writes)
- `manifests/defaults.toml` — P4 adds `features.one-password-signing = false`; no other edits
- `manifests/machines/personal-laptop.toml` — P4 adds `features.one-password-signing = true`
- `manifests/machines/work-laptop.toml` — P4 adds `features.one-password-signing = true`
- `manifests/machines/server-1.toml` — P4 changes `identity.git = "server-1"`, `identity.ssh = "server-1"` (currently both `"none"`)
- `manifests/machines/server-2.toml` — P4 changes both to `"server-2"`
- `docs/MANIFEST.md` — P4 updates the schema reference table: enum values for `identity.git`/`identity.ssh` expand; `[features]` block gains `one-password-signing`

### Project Conventions (binding on every phase)
- `CLAUDE.md` (repo root) — v2 conventions: kebab-case feature names need `index` access in templates; manifests are source of truth (no hostname inference); flat `identity/{git,ssh}/identities/` in v1; XDG everywhere
- `.claude/CLAUDE.md` — Project-level Claude instructions
- `~/.config/claude/CLAUDE.md` — Global conventions (Code section, Git section: no AI attribution)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (port from v1; minor surgery in transit)
- **v1 `git/config`** — ports almost verbatim. Drop `[includeIf "gitdir/i:~/git/server/"]` block (server identity is per-machine in v2). Keep `[user] name = "Josh Vaughen"`, `[core]`, `[init]`, `[fetch]`, `[interactive]`, `[delta]`, `[status]`, `[alias]` blocks unchanged. Verify `core.excludesfile = ignore` path resolves correctly under the new XDG-aware location.
- **v1 `git/config-personal`** — ports verbatim to `identity/git/identities/personal`. `signingkey` value is the public SSH key string (already in repo as `ssh/keys/id_ed25519_personal.pub` content); `op-ssh-sign` path is the standard 1Password macOS install location.
- **v1 `git/config-work`** — ports verbatim to `identity/git/identities/work`. Note the file lacks an `email` line — work email needs to be filled in by user before P4 merges (or kept blank with a `# TODO: set work email` comment).
- **v1 `git/config-server`** — split into `server-1` and `server-2`. Email becomes `server-{N}@jgrid.net` (or similar — user picks). `[commit] gpgsign = false` stays.
- **v1 `ssh/configs/config-personal`** — ports verbatim with one path update: `IdentityFile ~/.ssh/id_ed25519_personal.pub` becomes `IdentityFile ~/.ssh/identities/keys/personal.pub` (matches D-13 scoped subdirectory). `ProxyCommand ~/.ssh/cloudflared.zsh ...` becomes `ProxyCommand ~/.ssh/identities/cloudflared.zsh ...` (matches D-14 scoped path). `RemoteCommand` and `RequestTTY` ports verbatim.
- **v1 `ssh/configs/config-work`** — ports verbatim (just the `Host * IdentityAgent ...` block; no host-specific entries yet).
- **v1 `ssh/configs/config-server`** — port the `Host github.com` block to `identity/ssh/identities/server-1` (and `server-2`), updating `IdentityFile ~/.ssh/id_ed25519_server` to `~/.ssh/id_ed25519_server-1` (and `-2`).
- **v1 `ssh/cloudflared.zsh`** — port verbatim. Already uses `$HOMEBREW_PREFIX` correctly.
- **v1 `ssh/keys/id_ed25519_personal.pub`** — rename to `identity/ssh/keys/personal.pub`.
- **`install/messages.zsh`** — reused by `taskfiles/identity.yml` for `check`/`cross` validation output (Phase 1 deliverable; available since P1).
- **`taskfiles/helpers.yml` `_:safe-link`** — sole symlink mechanism for P4 (no bare `ln` per LINT-03b).

### Established Patterns (binding on P4)
- **`status:` blocks use `{{.X}}` template vars only** — never `$X`. LINT-02 enforces (Phase 2 D-12).
- **Aggregator tasks omit `status:` with `# lint-allow: cmds-without-status` marker** — `identity:install` is an aggregator; idempotency lives in `identity:git`, `identity:ssh`, etc.
- **`set -euo pipefail` on every executable `.zsh`** — `identity/ssh/cloudflared.zsh` already conforms (v1 file has the header).
- **Manifest as runtime source of truth** — `identity.yml` reads `resolved.json` via go-task `fromJson` and `index` (kebab-case feature keys use `index`; snake_case keys like `identity.git` use dot access).
- **Public-key-only convention for `identity/ssh/keys/`** — IDNT-06; private keys live in `~/.ssh/` outside the repo, generated locally per machine.

### Integration Points
- **`identity/` → `manifests/`** — `taskfiles/identity.yml` reads `identity.git`, `identity.ssh`, `features.one-password-ssh`, `features.one-password-signing` from `resolved.json`. `deps: [manifest:resolve]` ensures fresh JSON.
- **`identity/` → `taskfiles/links.yml` (or root Taskfile.yml)** — `identity:install` joins the install pipeline. Phase 3's `links.yml` `all:` aggregator already names P4 as the next extender (`# P4 adds git/ssh/identity`).
- **`identity/` → `shell/`** — `.zprofile`'s `SSH_AUTH_SOCK` already gated by `features.one-password-ssh` (Phase 3). P4 ships only the identity-file side; no `.zprofile` changes.
- **`identity/` → `~/.ssh/`** — install creates `~/.ssh/identities/` directory plus the `active` symlink, the four identity-file symlinks, the `keys/` subdirectory, and `cloudflared.zsh`. Main `~/.ssh/config` symlinked from `identity/ssh/config`.
- **`identity/` → `~/.config/git/`** — install creates `~/.config/git/config` (symlinked from `identity/git/config`) plus `~/.config/git/identities/` directory with the four identity files plus (servers only) `~/.config/git/server-include.config`.
- **`identity/` → `task validate`** — P4 ships `task identity:validate`; P8 composes the root `task validate` (CUTV-01).

</code_context>

<specifics>
## Specific Ideas

- **Schema enum expansion** — `taskfiles/manifest.yml` `manifest:validate` task's enum check for `identity.git`/`identity.ssh` accepts:
  ```
  personal | work | server-1 | server-2 | none
  ```
  Future-proofing: any value matching an existing `identity/{git,ssh}/identities/<name>` file would also be accepted, but P4 enumerates the four explicit values for clarity.

- **Cross-field validation rules** (D-16) — added to `manifest:validate`:
  ```
  if identity.ssh in {"personal", "work"} and not features.one-password-ssh:
    error: machine "<name>": identity.ssh = "<X>" requires features.one-password-ssh = true
  if identity.git in {"personal", "work"} and not features.one-password-signing:
    error: machine "<name>": identity.git = "<X>" requires features.one-password-signing = true
  ```

- **`identity/ssh/config` sketch:**
  ```
  # identity/ssh/config -- main SSH config symlinked to ~/.ssh/config.
  # Active identity loaded via ~/.ssh/identities/active (symlink driven by manifest).
  Host *
      SetEnv TERM=xterm-256color

  Include ~/.ssh/identities/active
  ```

- **`identity/git/config` sketch:**
  ```
  [user]
      name = Josh Vaughen
  [includeIf "gitdir/i:~/git/personal/"]
      path = identities/personal
  [includeIf "gitdir/i:~/git/work/"]
      path = identities/work
  [include]
      path = server-include.config    ; servers materialize this; workstations leave it missing (silently no-op)
  [core]
      editor = code
      excludesfile = ignore
      pager = delta
  [init]
      defaultBranch = main
  [fetch]
      prune = true
  [interactive]
      diffFilter = delta --color-only
  [delta]
      navigate = true
      light = false
      side-by-side = true
      line-numbers = true
      syntax-theme = Monokai Extended
  [status]
      showUntrackedFiles = all
      submoduleSummary = true
  [alias]
      # ... all v1 aliases verbatim
  ```

- **Server-side `server-include.config` sketch** (materialized on server-1 by `identity.yml`):
  ```
  [includeIf "gitdir:~/"]
      path = identities/server-1
  ```

- **`identity/ssh/identities/personal` sketch:**
  ```
  Host *
      IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  Host *.jgrid.net
      IdentityFile ~/.ssh/identities/keys/personal.pub
      IdentitiesOnly yes
      User josh
      ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h
      RemoteCommand if [[ "$(uname)" = "Darwin" ]]; then cd ~/Git/personal/jgrid.net/; else cd ~/git/jgrid.net/; fi && exec $SHELL -l
      RequestTTY yes

  Host *.plex.me
      IdentityFile ~/.ssh/identities/keys/personal.pub
      IdentitiesOnly yes
      User josh
      ProxyCommand ~/.ssh/identities/cloudflared.zsh access ssh --hostname %h
  ```

- **`identity/ssh/identities/server-1` sketch:**
  ```
  Host github.com
      IdentityFile ~/.ssh/id_ed25519_server-1
      IdentitiesOnly yes
      AddKeysToAgent yes
  ```

- **`taskfiles/identity.yml` task names:**
  - `identity:install` — aggregator (no `status:`; uses `# lint-allow: cmds-without-status`)
  - `identity:git` — symlinks `identity/git/config` → `~/.config/git/config`; symlinks all four identity files into `~/.config/git/identities/`; if `identity.git ∈ {server-1, server-2}`, materializes `~/.config/git/server-include.config`
  - `identity:ssh` — symlinks `identity/ssh/config` → `~/.ssh/config`; symlinks all four identity files into `~/.ssh/identities/`; sets `~/.ssh/identities/active` symlink; symlinks pub keys into `~/.ssh/identities/keys/`; symlinks `cloudflared.zsh`
  - `identity:validate` — runs the four assertions from `<domain>` In scope

- **Updated machine TOML snippets** (P4 deliverables):
  ```toml
  # manifests/machines/server-1.toml
  [features]
  one-password-ssh = false
  one-password-signing = false
  motd = true
  claude-marketplace = false

  [identity]
  git = "server-1"
  ssh = "server-1"
  ```

  ```toml
  # manifests/machines/personal-laptop.toml (delta)
  [features]
  one-password-ssh = true
  one-password-signing = true   # NEW
  # ... rest unchanged
  ```

</specifics>

<deferred>
## Deferred Ideas

### Owned by later phases (do not pull into P4 scope)
- **`task validate` composition** — Phase 8 (CUTV-01). P4 ships `task identity:validate` ready to compose.
- **`docs/CUTOVER.md` per-machine procedure** — Phase 8 (DOCS-08). The first-cutover step where a server operator generates `id_ed25519_server-N`, pastes the pub into the repo, commits, and pushes lives in this doc.
- **`task links:reconcile` orphan detection** — Phase 8 (CUTV-02). Reconciles the `~/.ssh/identities/`, `~/.config/git/identities/`, and key symlinks.
- **Brewfile composition for `cloudflared` and `1password-cli`** — Phase 5. P4 assumes `cloudflared` lands via `core.rb` or similar; planner verifies during P4 planning that the dependency is queued for Phase 5.
- **`docs/MIGRATION.md` v1→v2 identity mapping** — Phase 8 (DOCS-05). The "v1 `config-personal` ⇒ v2 `identity/git/identities/personal`" mapping table lives there.

### Future hardening (out of v1 scope)
- **Per-host `IdentityFile` directives for github.com on workstations** — if josh later wants distinct keys for github personal vs work pushes, the personal/work identity files grow new blocks. v1 ships with 1Password Agent presenting all keys; per-host disambiguation is the agent's job.
- **`Match exec` revival for niche use cases** — v2 explicitly avoids `Match exec` in identity selection (the v1 bug it caused). If a future need arises (e.g., a specific host needs runtime-derived config), the planner adds a single `Match exec` block inside the relevant identity file at that time; the architecture allows it without compromising the manifest-driven core.
- **Encrypted secrets in `identity/`** — explicitly rejected per PROJECT.md OOS. 1Password is the secret store; never `git-crypt` / `transcrypt` / `sops`.
- **Auto-detect `1Password.app` path** — `op-ssh-sign` lives at `/Applications/1Password.app/Contents/MacOS/op-ssh-sign` by convention. If a user installs 1Password to a non-standard location, the identity file's signing path won't resolve. Out of v1 scope; if it bites, the path becomes a manifest field.
- **GPG signing as an alternative to `op-ssh-sign`** — explicitly out of v1 scope. 1Password SSH-signing is the v2 default.
- **Per-machine SSH identity selection without rebuilding `active` symlink** — e.g., per-shell `SSH_IDENTITY` env var that overrides the active. Niche; not in v1.

### Open questions for later (not blocking P4)
- **Work git email** — v1's `config-work` lacks an `email` line. Before P4 merges, josh fills this in or planner ships the file with `# TODO: set work email` and a P4 task to remind.
- **Server pub-key materialization timing** — D-09 acknowledges the chicken-and-egg (need to generate the key on the server, paste the pub back). Planner picks: ship empty `.pub` files with placeholder content vs. omit them until first cutover. Either is acceptable; the cutover procedure (P8) covers the gap.
- **`identity/ssh/identities/active` symlink target form** — should the symlink point to a path under `~/.ssh/identities/` (e.g., `personal` relative) or to the repo source (`/Users/josh/Git/personal/dotfiles/identity/ssh/identities/personal`)? Convention: point to `~/.ssh/identities/<name>` so `readlink active` returns a short readable name. Implementation detail; planner finalizes.

</deferred>

---

*Phase: 04-identity-layer-git-ssh-per-machine*
*Context gathered: 2026-05-14*
