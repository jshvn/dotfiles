# Phase 4: Identity Layer — Git + SSH per Machine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 04-identity-layer-git-ssh-per-machine
**Areas discussed:** Git wiring + gitdir paths, Server identity, SSH wiring + key inventory, 1Password scope

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Git wiring + gitdir paths | How `identity.git` interacts with `includeIf`; where the gitdir paths come from | ✓ |
| Server identity (the "none" question) | How v1's `config-server` git+SSH identity lands in v2 given the `"personal" \| "work" \| "none"` enum | ✓ |
| SSH wiring + key inventory | Active-identity loading; global `Host *` block placement; pub-key naming and scope | ✓ |
| 1Password scope: SSH agent vs git signing | Whether `features.one-password-ssh` covers commit signing too, or whether signing is a separate concern | ✓ |

**User's choice:** All four areas selected.

---

## Git wiring + gitdir paths

### Q1 — What does `identity.git` on a machine manifest mean in v2?

| Option | Description | Selected |
|--------|-------------|----------|
| Single identity per machine | Manifest is authoritative. Only the personal identity file is deployed and only the personal `includeIf` block is wired on personal-laptop. Cleanest mental model; matches the SSH design. | |
| Default identity + all `includeIf` blocks wired | Closer to v1: identity files for all known names get deployed on every machine, all three `includeIf gitdir:` blocks are always present, and `identity.git` sets the unconditional `[user]` block. You can cd into `~/git/work/` on personal-laptop and commit as work. | ✓ |
| You decide | Pick the cleanest fit given everything else in v2. | |

**User's choice:** Default identity + all `includeIf` blocks wired.
**Notes:** Establishes that gitdir-match drives identity at runtime; manifest is the documentary "intended" identity, not a runtime filter. Sets up D-01.

### Q2 — Where do the `includeIf gitdir:` paths come from?

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded in `identity/git/config` | Single committed file lists all gitdir paths for every machine. Cheapest; works if your filesystem layout never varies across machines. | ✓ |
| Per-identity paths inside each identity file | Each identity carries its own `[includeIf]` block. Lets a future machine override the path for one identity without touching others. | |
| Manifest-declared paths per identity | Resolver emits `includeIf` lines from a manifest field like `identity.git_workdirs`. Most flexible; most complex. | |

**User's choice:** Hardcoded in `identity/git/config`.
**Notes:** Locks D-02. Single committed file is symlinked to `~/.config/git/config` on every machine; same gitdir paths everywhere.

### Q3 — Which identity files get deployed (given all `includeIf` blocks are wired)?

| Option | Description | Selected |
|--------|-------------|----------|
| All identity files deployed everywhere | Same set of files on personal-laptop, work-laptop, and the servers. `identity.git` picks the default `[user]` block; every gitdir-match always works. Maximum portability. | ✓ |
| Only identity files matching the manifest deploy | If `identity.git = "personal"`, only `personal` is deployed. The other `includeIf` lines point at missing files (git silently ignores). | |
| Manifest grows to a list | Schema change: `identity.git = ["personal", "work"]` (an ordered list). | |

**User's choice:** All identity files deployed everywhere.
**Notes:** Locks D-03. Identity files are dormant on machines where the relevant gitdir doesn't exist.

### Q4 — How does manifest's `identity.git` translate into a runtime git config value (the default `[user.email]`)?

| Option | Description | Selected |
|--------|-------------|----------|
| Main config `[include]`s the active identity unconditionally | Tiny `~/.config/git/active` symlink points to the active identity file; main config does `[include] path = ~/.config/git/active`. | |
| Resolver writes a generated `[user]` block | Install task renders main git config from a template, substituting `[user] email = {active-identity-email}` based on resolved.json. | |
| Default identity ignored — gitdir must match | Main config has no unconditional identity include. Outside `~/git/<X>/` you get `[user] name = Josh Vaughen` but no email — git refuses to commit until you set one locally or move into a matched gitdir. | ✓ |

**User's choice:** Default identity ignored — gitdir must match for any identity to apply.
**Notes:** Locks D-04. Trade-off explicitly accepted: discipline > convenience. Manifest's `identity.git` becomes purely documentary on workstations (drives `task identity:validate` assertions).

**Decision:** Move to next area (Server identity).

---

## Server identity (the "none" question)

### Q1 — How should the v1 `config-server` git+SSH identity (Name=Server, email=server@jgrid.net, system ssh-agent, github.com deploy-key) land in v2?

| Option | Description | Selected |
|--------|-------------|----------|
| Add `"server"` as a fourth allowed identity value | Schema: enum expands to `"personal" \| "work" \| "server" \| "none"`. v1's `config-server` ports verbatim to a single shared `server` identity. | ✓ |
| Drop the dedicated server identity — servers use `"none"` | Servers get `identity.git = "none"`. No `identity/git/identities/server` file. Simpler schema; loses the server identity's dedicated email and `gpgsign=false`. | |
| Keep "server" only for git; SSH uses "none" on servers | Mixed asymmetric approach. | |

**User's choice:** Add `"server"` as a fourth allowed identity value.
**Notes:** Initial answer set up a single shared `server` identity. Subsequent question (Q2) refined this to per-server identities.

### Q2 — Does the per-server split also apply to the git identity?

| Option | Description | Selected |
|--------|-------------|----------|
| SSH splits, git stays shared | Single `identity/git/identities/server` shared by both servers. SSH splits per server. Asymmetric. | |
| Both split per server | `identity/git/identities/server-1` and `server-2` each with their own email. Symmetric. Schema enum further expands. | ✓ |
| Both stay shared ("server") | Walk back the per-server SSH split entirely. Single shared identity for both sides. | |

**User's choice:** Both split per server.
**Notes:** Schema enum now reads `"personal" \| "work" \| "server-1" \| "server-2" \| "none"`. Locks D-05 and D-06. Triggered the follow-up about server gitdir wiring (Q3).

### Q3 — On a server machine, how does git pick the user's email for an arbitrary repo (not under any `~/git/<X>/`)?

| Option | Description | Selected |
|--------|-------------|----------|
| Wildcard includeIf on servers only | Server identity files include a wide `[includeIf "gitdir:~/"]` pattern so every directory on the server matches and uses the server-N identity. | ✓ |
| Servers get an unconditional default include | Walking back Area 1's "no default" rule on server machines only — main config carries an unconditional include of the server identity. | |
| Servers manually set `user.email` per-repo | No default; each repo on the server sets its own. Discipline-enforcing; bites at `git commit` time. | |

**User's choice:** Wildcard includeIf on servers only.
**Notes:** Locks D-08. The wildcard `[includeIf gitdir:~/]` lives in a server-machine-only file (`~/.config/git/server-include.config`) materialized at install time; workstations leave the include line silently resolving to nothing.

### Q4 — Should each server's public key live in the repo?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — commit `server-1.pub` and `server-2.pub` | Symmetric with `id_ed25519_personal.pub`. Private keys stay on each server (provisioned locally). | ✓ |
| No — keep them out of the repo | v1 doesn't commit them now. Per-machine deploy keys are pasted into GitHub directly. | |
| Commit only the one personal pub key (status quo) | Only `personal.pub` lives in the repo. | |

**User's choice:** Yes — commit `server-1.pub` and `server-2.pub`.
**Notes:** Locks D-09. Cutover procedure (Phase 8 DOCS-08) documents the chicken-and-egg materialization (generate on server, paste back to repo, commit, push).

**Decision:** Move to next area (SSH wiring + key inventory).

---

## SSH wiring + key inventory

### Q1 — How does `~/.ssh/config` wire up the active identity?

| Option | Description | Selected |
|--------|-------------|----------|
| Shared main config + active-identity symlink | `identity/ssh/config` symlinked to `~/.ssh/config` on every machine. Contains the global `Host *` block plus `Include ~/.ssh/identities/active` (a symlink driven by manifest). | ✓ |
| Per-machine main config | `config-personal-laptop`, `config-work-laptop`, etc. — four committed top-level configs. More files; zero runtime indirection. | |
| Shared main + machine-named Include | `Include ~/.ssh/identities/{$DOTFILES_MACHINE}` resolved at install time. | |

**User's choice:** Shared main config + active-identity symlink.
**Notes:** Locks D-10, D-11, D-12. Single `Include` line in the main config never changes; only the `active` symlink target does.

### Q2 — Where do `identity/ssh/keys/*.pub` and `cloudflared.zsh` land at install time?

| Option | Description | Selected |
|--------|-------------|----------|
| Symlink everything into `~/.ssh/` flat (v1 pattern) | Pub keys at `~/.ssh/id_ed25519_<name>.pub`; `cloudflared.zsh` at `~/.ssh/cloudflared.zsh`. Minimum surprise. | |
| Symlink keys into `~/.ssh/identities/keys/` (scoped) | Pub keys land at `~/.ssh/identities/keys/<name>.pub`; cloudflared at `~/.ssh/identities/cloudflared.zsh`. Tidier `~/.ssh/` top level. | ✓ |
| Deploy all four pub keys; gate cloudflared on manifest | Same as option 1, but `cloudflared.zsh` conditionally deployed. | |

**User's choice:** Symlink keys into `~/.ssh/identities/keys/` (scoped).
**Notes:** Locks D-13 and D-14. Identity files reference pub keys by `~/.ssh/identities/keys/<name>.pub`; `cloudflared.zsh` lands at `~/.ssh/identities/cloudflared.zsh`. Deployed on every machine even though only personal identity uses it.

**Decision:** Move to next area (1Password scope).

---

## 1Password scope: SSH agent vs git signing

### Q1 — Does `features.one-password-ssh` (or a renamed flag) gate git commit signing via 1Password?

| Option | Description | Selected |
|--------|-------------|----------|
| One flag covers both — rename to `features.one-password` | Single flag controls SSH agent socket export, SSH `IdentityAgent` directive, and git `op-ssh-sign` program path. | |
| Keep `one-password-ssh` for SSH; git signing inferred from identity | Personal/work identity files set `op-ssh-sign` unconditionally (assumes 1Password); server sets `gpgsign = false`. No new flag. | |
| Split: `one-password-ssh` and `one-password-signing` are independent flags | Two flags. SSH integration and git signing can be turned on/off independently. | ✓ |

**User's choice:** Split into two independent flags.
**Notes:** Locks D-15. `features.one-password-ssh` (agent socket + `IdentityAgent`) and `features.one-password-signing` (git `op-ssh-sign`) are independent in principle; both true on laptops, both false on servers in practice.

### Q2 — How do `personal`/`work` identity files handle the 1Password directives given the two flags are independent?

| Option | Description | Selected |
|--------|-------------|----------|
| Static identity files + manifest validation | Files always contain the directives. `manifest:validate` rejects machines where `identity.{ssh,git} ∈ {personal, work}` but the corresponding flag is false. Files inspectable as-committed. | ✓ |
| Conditional install — directives stripped when flag is false | Install task `sed`-strips lines based on flag. Deployed file diverges from source. | |
| Two variants of each identity (with/without 1Password) | `personal` and `personal-noop` (or similar). Doubles the file count. | |

**User's choice:** Static identity files + manifest validation.
**Notes:** Locks D-16. `manifest:validate` gains two cross-field rules: `identity.ssh ∈ {personal, work} ⇒ features.one-password-ssh = true`; `identity.git ∈ {personal, work} ⇒ features.one-password-signing = true`.

**Decision:** All four areas complete; ready for context write.

---

## Claude's Discretion

Captured in `<decisions>` "Claude's Discretion (planner concerns)" section of CONTEXT.md. Summary:

- Symlink target for the main git config (`~/.gitconfig` vs `~/.config/git/config`)
- `server-include.config` materialization strategy (template + substitution vs. generated)
- `task identity:install` aggregator placement (`taskfiles/links.yml` `all:` extension vs root `Taskfile.yml`)
- `task identity:validate` gitdir source for the `git -C` assertion
- Placeholder content for unfilled server pub keys
- `cloudflared.zsh` deployment-scope gating
- `task identity:validate` failure threshold during fresh-install cutover
- Exact rename + addition order in `manifests/defaults.toml` for the new `one-password-signing` flag

## Deferred Ideas

Captured in `<deferred>` section of CONTEXT.md. Summary:

- `task validate` composition (Phase 8 CUTV-01)
- `docs/CUTOVER.md` per-machine procedure (Phase 8 DOCS-08)
- `task links:reconcile` orphan detection (Phase 8 CUTV-02)
- Brewfile composition for `cloudflared` / `1password-cli` (Phase 5)
- `docs/MIGRATION.md` v1→v2 identity mapping (Phase 8 DOCS-05)
- Per-host `IdentityFile` directives for github personal vs work pushes (future hardening)
- `Match exec` revival for niche use cases (future hardening)
- Encrypted secrets in `identity/` (explicitly rejected per PROJECT.md OOS)
- Auto-detect `1Password.app` path (out of v1 scope)
- GPG signing as an alternative to `op-ssh-sign` (out of v1 scope)
- Per-shell `SSH_IDENTITY` env-var override (niche; not in v1)
- Work git email (TBD by user before P4 merges)
- Server pub-key materialization timing (placeholder vs omit; planner picks)
- `~/.ssh/identities/active` symlink target form (`~/.ssh/identities/<name>` relative recommended)
