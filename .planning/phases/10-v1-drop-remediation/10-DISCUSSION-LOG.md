# Phase 10: v1-Drop Remediation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** 10-v1-drop-remediation
**Areas discussed:** Pipeline slot, Sudo handling, Validate hook, PORT-03 verify, Code location, Things rename

---

## Pipeline slot -- where the new /etc/zshenv ZDOTDIR write task sits

| Option | Description | Selected |
|--------|-------------|----------|
| First cmd in install (before links:all) | Earliest possible position inside `task install`; sudo prompt up front | |
| Install precondition (before deps) | Lift into the `preconditions:` block alongside `cutover_gate_check` | |
| Bootstrap.zsh, not task install | Move ZDOTDIR-write into `bootstrap.zsh` so it lands once on fresh machines | |
| Standalone task surfaced separately | Top-level `task shell:install-zdotdir` operator runs explicitly | |
| (free-text) when we link all of the shell configs for zsh, thats where we should make the update | User picked the time-point "when the v2 zsh symlinks land," not one of the four pre-defined slots | check |

**User's choice:** Free-text -- "when we link all of the shell configs for zsh, that's where we should make the update."
**Notes:** Resolved in CONTEXT.md as D-01: the ZDOTDIR write runs at the same operator-visible moment as the five `_:safe-link` calls for the zsh startup files. Physical home settled in the follow-up Code location question.

---

## Sudo handling -- /etc/zshenv write

| Option | Description | Selected |
|--------|-------------|----------|
| Refresh sudo cred up front, then use it lazily | `sudo -v` at the start; ZDOTDIR task uses `sudo tee` without re-prompting | |
| Plain `sudo tee` -- prompt when reached | Direct v1 port: `echo ... | sudo tee /etc/zshenv`. Sudo prompt mid-install | check |
| Skip sudo when no write needed | Status block uses sudo-free `grep -qF`; sudo only used on first install or after manual edit | |

**User's choice:** Plain `sudo tee` -- prompt when reached.
**Notes:** CONTEXT.md D-03 captures the literal v1-port shape. D-04 separately requires the status block to stay sudo-free (grep against world-readable /etc/zshenv) so steady-state re-runs never prompt -- that's the "skip sudo when no write needed" semantics layered onto the chosen approach as a free win.

---

## Validate hook -- where ZDOTDIR + XDG validation hangs in `task validate`

| Option | Description | Selected |
|--------|-------------|----------|
| New `shell:validate` component in aggregator | Add `shell` to the validate aggregator loop; symmetric with every other layer | check |
| Fold into links:validate | Tack /etc/zshenv + XDG dir checks onto the existing links:validate | |
| Fold into manifest:validate | Pull runtime-OS checks into the JSON-schema validate | |

**User's choice:** New `shell:validate` component in aggregator.
**Notes:** CONTEXT.md D-05 names the loop change. D-06 captures the open `taskfiles/shell.yml` include-alias question (rename / dual-alias / split) as Claude's Discretion -- planner picks based on least churn.

---

## PORT-03 verify -- fresh-machine first-shell guarantee

| Option | Description | Selected |
|--------|-------------|----------|
| Documented smoke procedure (no real fresh install) | Add a smoke-test section to docs; PORT-03 satisfied by procedure + manual run | check |
| VM-based fresh install in this phase | Clean macOS VM, run bootstrap + install end-to-end | |
| Real fresh-machine install on next available rebuild | Defer the real check to the next time you rebuild one of the four machines | |

**User's choice:** Documented smoke procedure (no real fresh install).
**Notes:** CONTEXT.md D-08 captures the choice; ROADMAP P10 SC#1 explicitly allows this. VM-based verification deferred to a later milestone if a real-rebuild regression surfaces.

---

## Code location -- where the ZDOTDIR write code physically lives

| Option | Description | Selected |
|--------|-------------|----------|
| New step inside `links:zsh` sub-task | Add the step inside `links.yml`'s `zsh:` task next to the 5 `_:safe-link` calls | check |
| New top-level task in taskfiles/shell.yml, called from links:zsh | Honor AUDIT.md's proposed owner; add `shell:zdotdir`, call from links.yml | |
| New top-level task in taskfiles/shell.yml, wired into root install pipeline | Insert as sibling step in root Taskfile.yml install cmds before links:all | |

**User's choice:** New step inside `links:zsh` sub-task.
**Notes:** CONTEXT.md D-02 captures this and the AUDIT.md owner-row amend (`taskfiles/shell.yml` -> `taskfiles/links.yml` for keep row #1).

---

## Things rename -- v1 'Things' vs v2 'Things3' MAS app-name drift

| Option | Description | Selected |
|--------|-------------|----------|
| Leave Things3 in manifest, amend AUDIT.md to mark as ported-with-name-delta | Things3 IS the canonical App Store name; mas resolves by id; update audit row keep -> drop | check |
| Rename Things3 -> Things in personal-laptop.toml (literal v1 fidelity) | Match v1 exactly; downside: mismatch with what `mas list` actually reports | |

**User's choice:** Leave Things3 in manifest; amend AUDIT.md.
**Notes:** CONTEXT.md D-07 captures the reclassification details and the counts-table update (Keep 3 -> 2, Drop 99 -> 100).

---

## Claude's Discretion

- Plan breakdown: one plan covering all three keep items + AUDIT amend + smoke doc, OR split per concern. Recommendation in CONTEXT.md: one plan (phase is small).
- Within D-02, the exact shape of the new ZDOTDIR step inside `links:zsh` (inline `cmd:` heredoc vs separate `zdotdir:` task referenced via `task: zdotdir`).
- D-06: `taskfiles/shell.yml` include strategy (rename `perf:` -> `shell:` / dual-alias / split into `perf.yml` + `shell.yml`).
- Where the PORT-03 smoke procedure section lives (new doc / `docs/MIGRATION.md` section / `shell/README.md`).
- Whether `shell:validate` should also check `$DOTFILES_MACHINE` export from first-shell perspective.

## Deferred Ideas

- Sudo-cred priming via upfront `sudo -v` -- revisit if mid-install prompt UX is jarring.
- VM-based fresh install for PORT-03 -- revisit if a real rebuild surfaces a regression the smoke procedure missed.
- Verbose `task install` sudo-prompt-ahead UX -- out of scope; align with SURF (Phase 12) or later UX work.
- `shell:validate` $DOTFILES_MACHINE export check -- log for later v2.x phase if not added in this phase.
