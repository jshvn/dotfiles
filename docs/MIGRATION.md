# Migration Guide: v1 to v2

## What This Is

This document is a per-concept guide for operators and AI agents moving from
the v1 profile-suffix model to the v2 manifest model. Read it top-to-bottom on
the first machine you cut over; on later visits, grep by an old path or task
name to land in the right section. Every section pairs prose (what changed
and why) with an old-path to new-path mapping table so the lookup-by-grep use
case is reliable.

The v1 repository stays installed on every machine throughout the cutover
window per the `CUTV-06` archive-not-delete rule -- if v2 regresses on a
given machine the operator falls back to v1 from the same disk and a row in
`docs/CUTOVER.md` moves back to `planning`. v1 is archived (renamed, never
deleted) only after every target machine has reached `cut-over` in the
state table.

## Profile suffix -> Machine manifest

v1 encoded each machine's install state through a `DOTFILES_PROFILE`
environment variable plus filename suffixes -- `Brewfile-<profile>.rb`,
`zsh/aliases/<profile>/`, hostname-based `Match exec` blocks in SSH config.
The v1 valid-profiles list (`personal` / `work` / `server` / `test`)
implied state by membership: the install pipeline branched on the profile
variable to pick a Brewfile, source the right alias directory, and gate
optional features. This worked but was brittle -- a typo in the profile
variable produced a silent miss, a forgotten suffix on a new file silently
excluded it from one profile, and `test` was declared in the valid list
without any backing install artifacts so selecting it crashed at runtime.

v2 replaces this entire scheme with a single TOML file per machine under
`manifests/machines/<name>.toml` that inherits from a shared baseline at
`manifests/defaults.toml`. The active machine is selected explicitly via
`task setup -- <machine-name>`, which writes the chosen name into
`$XDG_STATE_HOME/dotfiles/machine`; no hostname inference, no environment
variable to forget. The resolver (`install/resolver.zsh`) deep-merges the
baseline with the per-machine TOML once at setup time and writes the result
to `$XDG_STATE_HOME/dotfiles/resolved.json`, which every go-task task reads
via `fromJson`. The full schema (sections, types, deep-merge rules) lives
in `docs/MANIFEST.md`.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `Brewfile-personal.rb` | `packages/core.rb` + `packages/gui.rb` listed in `[packages.brew].bundles` of `manifests/machines/personal-laptop.toml`; one-offs go in `extra_packages` of the same TOML |
| `zsh/aliases/server.zsh` (per-profile dir) | `shell/aliases/<topic>.zsh` (flat layout), gated by feature flag in `manifests/machines/server-1.toml` |
| `DOTFILES_PROFILE=personal` env var | `task setup -- personal-laptop` (writes `$XDG_STATE_HOME/dotfiles/machine`) |
| `VALID_PROFILES=(personal work server test)` | `manifests/machines/*.toml` (file presence is the canonical machine list) |

## Antigen -> Antidote

v1 used Antigen for zsh plugin management. Antigen has been archived
upstream since January 2018 and pushes cold interactive shell startup
toward 500ms because it resolves plugin paths and runs `compinit` on every
shell. v2 switches to Antidote -- a static plugin manifest at
`configs/antidote/zsh_plugins.txt` with a bundle-cache load in `.zshrc`,
which is the primary lever for the 200ms cold-start target per `SHEL-04`.

The v1 prompt (`zsh/theme.zsh`, alanpeabody-based) ported as-is to
`shell/theme.zsh`. The Phase 0 recommendation to swap to Starship was
rejected during planning -- the existing prompt is small, fast, and not on
life support, and a prompt swap is a behavior change with no problem to
solve.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `zsh/.antigenrc` | `configs/antidote/zsh_plugins.txt` |
| `antigen apply` in `.zshrc` | `antidote load` against a static bundle file in `shell/.zshrc` |
| `zsh/theme.zsh` (alanpeabody-based) | `shell/theme.zsh` (ported as-is) |

## Brewfile-<profile>.rb -> packages/<purpose>.rb + extra_packages

v1 maintained one Brewfile per profile -- `Brewfile-personal.rb`,
`Brewfile-server.rb`, etc. Adding a package to one profile required
remembering to add it to the others or accepting the divergence; switching
machine type meant editing the Brewfile filename in shell scripts that
branched on `DOTFILES_PROFILE`.

v2 splits Brewfiles by purpose (`core.rb` for CLI tooling, `gui.rb` for
casks and GUI apps) and lets each machine TOML declare which bundles it
wants via `[packages.brew].bundles`. Per-machine one-offs go in the TOML's
`extra_packages` typed sub-table (`formulae`, `casks`, `mas`) so a server
machine can decline the `gui` bundle entirely while still pulling in a
single specific cask if needed (`PKGS-05` cask-isolation requirement). The
brew layer reads the resolved JSON and synthesizes a composed Brewfile
from the bundles list plus extra_packages.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `install/Brewfile-personal.rb` | `packages/core.rb` + `packages/gui.rb` (listed in `bundles` of `manifests/machines/personal-laptop.toml`); machine-specific casks go in `extra_packages.casks` |
| `install/Brewfile-server.rb` | `packages/core.rb` only -- the `gui` bundle is declined via the bundles list in `manifests/machines/server-1.toml` |
| Profile-keyed branch in install code to pick a Brewfile | `task packages:install` reads `resolved.json`, composes a single Brewfile from `bundles` + `extra_packages` |

## zsh/ -> shell/ (flat layout)

v1 nested zsh code by platform and topic: `zsh/aliases/darwin/<topic>.zsh`,
`zsh/aliases/linux/<topic>.zsh`, `zsh/functions/<name>.zsh`. The nesting
existed to support a future Linux server tier that never actually
materialized in v1 use, and the resulting depth made every alias edit a
two-step "which platform am I in" decision.

v2 flattens everything under `shell/`. All four target machines are macOS
in v1 (laptops + Mac servers); Linux support is deferred to v2+ per
`PROJECT.md` Out-of-Scope. The flat layout drops the platform decision
entirely: one alias topic per file at `shell/aliases/<topic>.zsh`, one
function per file at `shell/functions/<name>.zsh`, and the zsh startup
files (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`,
`theme.zsh`) live at the top of `shell/`. When Linux re-enters scope in a
future version, the directory structure will reshape -- that migration
cost is documented in `PROJECT.md` and accepted as a known future re-org.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `zsh/aliases/darwin/<topic>.zsh` | `shell/aliases/<topic>.zsh` |
| `zsh/aliases/common/<topic>.zsh` | `shell/aliases/<topic>.zsh` |
| `zsh/functions/<name>.zsh` | `shell/functions/<name>.zsh` |
| `zsh/.zshrc`, `zsh/.zshenv`, etc. | `shell/.zshrc`, `shell/.zshenv`, etc. |
| Per-profile alias subdirectory loaded by `DOTFILES_PROFILE` branch | feature-gated alias guard via `_dotfiles_feature <name>` in a single flat alias file |

## gsd-install -> sentinel-gated claude:gsd + explicit claude:update

v1 had a `gsd-install` task that ran `npx` against the GSD installer on
every `task install` invocation. That meant every install paid the cost
of an `npx` startup plus a network round-trip even when GSD was already
present and converged. There was no `status:` guard, so the task always
re-ran -- one of the small but compound cost contributors to install
slowness over the v1 lifetime.

v2 splits this into two tasks. `task claude:gsd` is sentinel-gated: it
checks for a presence sentinel under `$XDG_STATE_HOME/dotfiles/` and
returns immediately via the `status:` block when the sentinel exists, so
GSD installs run exactly once per fresh machine. `task claude:update` is
the explicit forced-update path: it deletes the sentinel and re-runs the
installer. This matches `CLDE-03` (sentinel-idempotency pattern) and the
broader v2 rule that `task install` is the canonical entry and is a fast
no-op on a converged machine.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `gsd-install` task (no `status:` guard; `npx` every run) | `task claude:gsd` (sentinel-gated via `$XDG_STATE_HOME/dotfiles/`) |
| no v1 equivalent for forced GSD update | `task claude:update` (deletes the sentinel and re-runs the installer) |
| `npx` invocation on every `task install` | `task install` is a sub-second no-op on a converged machine; `claude:gsd` only runs when its sentinel is absent |

## Hostname-based Match exec -> manifest-driven identity gates

v1 selected SSH identity via `Match exec` blocks in `~/.ssh/config` that
shelled out to compare `hostname` against literal strings -- a pattern
that burned the project before (`.zprofile:55-56` literal-`"server"`
match silently breaks on hostnames containing `"server"` or on server
machines that did not carry that exact hostname). Git identity selection
followed the same fragile pattern: `git config user.email` branched on
hostname output via shell, with no recovery path when a machine's
hostname drifted.

v2 reads the machine name from `$XDG_STATE_HOME/dotfiles/machine` (set
explicitly by `task setup -- <machine-name>`) and selects identity via
the manifest `[identity]` block. The identity layer (`taskfiles/identity.yml`)
materializes the SSH and git `Include` directives via `_:safe-link`
against per-identity config files under `identity/ssh/identities/<name>/`
and `identity/git/identities/<name>/`. There are zero `hostname`
references anywhere in the identity path (`IDNT-01` through `IDNT-08`).
The relevant security context (private keys never committed; public keys
only under `identity/ssh/keys/`) is documented in `docs/SECURITY.md`.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `ssh/configs/Match-exec-hostname-personal` | `identity/ssh/identities/personal/` (selected by manifest `[identity].ssh` value) |
| `Match exec "hostname \| grep -q server"` in `~/.ssh/config` | `Include` directives materialized by `task identity:install` based on `resolved.json` |
| git `user.email` switch by `hostname` in shell | `includeIf gitdir` directive in `identity/git/identities/<identity>/config`, selected by manifest `[identity].git` |
| `.zprofile:55-56` literal `"server"` hostname check for 1Password | feature-gated `[features].one-password-ssh` consumed in `shell/.zprofile` via `_dotfiles_feature one-password-ssh` |

## macos:shell $BREW_ZSH -> {{.BREW_ZSH}}

v1's `macos:shell` task at line 145 used `$BREW_ZSH` (a shell variable
reference) inside its `status:` block. Shell variables are not in scope
during status evaluation in go-task -- the status block runs in the
task-graph build context, not in the shell-execution context. The
reference expanded to the empty string at status time, the comparison
always failed, the task always re-ran, and `task install` always paid
the cost of the shell-registration code path even on a fully-converged
machine.

v2 uses `{{.BREW_ZSH}}` (go-template variable form) inside the same
`status:` block. Template variables are resolved at task-graph build
time when status evaluation actually runs, so the comparison sees the
real path. Idempotency is restored. `LINT-02` enforces this rule
structurally for every taskfile in the repo -- `task lint` rejects any
`$X` (shell variable) inside any `status:` block.

Path mapping:

| Old (v1) | New (v2) |
|----------|----------|
| `taskfiles/macos.yml` `status: [test "$SHELL" = "$BREW_ZSH"]` | `taskfiles/macos.yml` `status: [test "$SHELL" = "{{.BREW_ZSH}}"]` |
| `$X` shell vars inside any `status:` block (LINT-02 violation class) | `{{.X}}` template vars only, enforced by `task lint` (`LINT-02`) |

## Rollback

If v2 regresses on machine X during the cutover window, fall back to v1
on that machine via this procedure. v1 stays installed throughout the
cutover window per `CUTV-06` (archive-not-delete), so the fallback path
runs entirely from local disk.

1. Stop using v2 on machine X. Close any open v2 shells; the next
   step revokes the v2 state files so any remaining v2 shell will see
   inconsistent state.

2. Revert the active machine sentinel. Run
   `rm "$XDG_STATE_HOME/dotfiles/machine"` to clear the active machine
   selection, then `rm "$XDG_STATE_HOME/dotfiles/cutover-ack"` to
   un-cut the machine. The cutover-gate reader will now block
   `task install` from the v2 branch on this machine, which is the
   desired state during rollback.

3. Re-source v1 zsh files from the v1 repo. The v1 repository is still
   installed during the cutover window per `CUTV-06` ("archive not
   delete"), so v1 zsh files are still on disk. Source the v1
   `.zshrc` directly (or open a new login shell, which will pick up
   v1's `.zshenv` from the v1 repo's symlink target) to restore v1
   shell behavior.

4. Record the regression in `docs/CUTOVER.md`. Update the per-machine
   state table: set the machine's `status` back to `planning`, write
   the regression description into the `notes` column, and clear the
   `cutover-date` and `last-validate-pass` columns so the soak counter
   does not run on a broken cutover. Open an issue or note the bug in
   the planning state so the next iteration of v2 can address it
   before the next cutover attempt on this machine.

## Archiving v1

After the LAST machine reaches `cut-over` status in `docs/CUTOVER.md`,
archive the v1 repository. Archive means rename and stash off the active
path, not delete -- v1 stays recoverable indefinitely.

Pre-condition: every row in the `## Per-machine cutover state` table
inside `docs/CUTOVER.md` shows `status: cut-over` and `days-on-v2` is at
least 7. If any row is still `soaking` or `installing`, do not archive.

1. Rename the v1 directory on every machine that still has it on disk.
   The canonical archive name suffix is `.archive` so v1 can be
   restored by reversing the rename if needed:

   ```zsh
   mv ~/Git/personal/dotfiles-v1 ~/Git/personal/dotfiles-v1.archive
   ```

2. Archive the v1 branch in the remote repository. If the project is
   tracked by a separate remote/branch for v1, push the v1 branch tip
   to a permanent archive ref so the history stays available even if
   the working tree is later removed:

   ```zsh
   git push origin master:refs/heads/archive/v1
   ```

3. Update `docs/CUTOVER.md` per-machine state column: change each
   machine's `status` from `cut-over` to `archived`. This is the
   terminal state for the cutover lifecycle; no further transitions
   apply.
