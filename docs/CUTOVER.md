# Cutover Reference

## What This Is

Per-machine cutover from v1 to v2 happens one machine at a time. The v1
repository stays installed on every machine throughout the cutover window so
the operator can fall back to v1 if v2 regresses on a given machine. After a
machine has run v2 cleanly for a 7-day soak period the row in the per-machine
state table below moves from `soaking` to `cut-over`; v1 is archived only
after every target machine has reached `cut-over`. Engineering is finished
when this document exists and the supporting task chain works; the cutover
itself is operational work that the operator drives manually.

## Fresh-machine verification

The fresh-machine procedure is the canonical task chain a clean Mac walks
through to install v2 from scratch. Run the steps in order; each step has a
deterministic exit state. If a step fails, do not proceed -- diagnose the
failure against the referenced source-of-truth doc and re-run that step.

1. Clone the v2 branch on the target Mac. Pick the install location that
   matches your repo convention (e.g., `~/Git/personal/dotfiles`) and check
   out the v2 branch:

    ```zsh
    git clone https://github.com/joshvaughen/dotfiles.git ~/Git/personal/dotfiles
    cd ~/Git/personal/dotfiles
    git checkout josh/dotfiles-v2-refactor
    ```

2. Run `./bootstrap.zsh`. The bootstrap script audits the network trust
   chain before fetching Homebrew, go-task, and yq; see `docs/SECURITY.md`
   for the full enumeration of trust anchors and HTTPS audit lines. On a
   first-time install the cutover-gate is invoked at the end of bootstrap
   for completeness but exits cleanly because no machine has been selected
   yet -- the machine file does not exist, so the gate skips the missing
   sentinel check and the script prints the next-step hint pointing at
   step 3.

3. Run `task setup -- <machine-name>`. This writes
   `$XDG_STATE_HOME/dotfiles/machine` and recomputes
   `$XDG_STATE_HOME/dotfiles/resolved.json` from
   `manifests/defaults.toml` and the matching
   `manifests/machines/<machine-name>.toml`. The `<machine-name>` token
   must match exactly one file under `manifests/machines/`; see
   `docs/MANIFEST.md` for the per-machine schema and the canonical list of
   accepted machine names.

4. Run `task cutover:ack -- <machine-name>` to write the per-machine
   cutover sentinel. This is the only step that unblocks `task install` on a
   v2-only machine; without the sentinel the install gate refuses to run
   and prints the actionable error from `install/cutover-gate.zsh`. The
   `cutover:ack` writer validates the supplied machine name against the
   active machine file from step 3 and rejects any mismatch, so a typo
   surfaces immediately instead of writing a sentinel that the gate would
   then reject on the next `task install`.

5. Run `task install`. This is the canonical install entry point -- `task
   update` is intentionally not a separate task in v2 because install IS
   update (one pipeline, one source of truth). Every install sub-task has a
   `status:` block, so a second `task install` immediately after the first
   is a fast no-op on a converged machine. The final step of the pipeline
   runs `task links:reconcile` in warn-only mode and surfaces any orphan
   symlinks via stderr without failing the install.

6. Run `task validate`. The composed validator runs every per-component
   validate (manifest, identity, links, macos, packages, claude) to
   completion regardless of any single failure and prints a check/cross/n/a
   summary table at the end. All six rows must show `check` or `n/a` on a
   freshly installed machine. Currently only `claude:validate` emits the
   `feature disabled -- skipped` sentinel substring that the aggregator
   renders as `n/a` (when `claude-marketplace` is false, e.g., on server-1
   and server-2). The other per-component validates return `check` even
   when their feature flags are off because the underlying validates
   internally no-op feature-gated work rather than emitting a separate skip
   marker; both forms are considered passing.

7. Begin the 7-day soak period. Do not delete or archive the v1 repo
   during the soak -- v1 remains on disk so a regression on any machine has
   a same-day fallback path. Record today's date in the
   `cutover-date` column of the per-machine state table below and move the
   machine's `status` to `soaking`.

8. After 7 days, update the per-machine state table below: set `status`
   to `cut-over`, write the last `task validate` pass date into
   `last-validate-pass`, and update `days-on-v2` (computed manually -- the
   operator subtracts `cutover-date` from today). After the last target
   machine reaches `cut-over`, archive the v1 repository per `docs/MIGRATION.md`
   section "Archiving v1" -- archive means rename and stash off the active
   path, not delete.

## Per-machine cutover state

The table tracks each target machine through the cutover lifecycle. Status
values move strictly in order: `planning` is the pre-cutover starting state;
`ready` means engineering is done and the operator is about to begin the
fresh-machine procedure; `installing` means the procedure is mid-flight (a
step between 1 and 6 has not yet completed cleanly); `soaking` means
`task validate` passed on the machine and the 7-day clock is running;
`cut-over` means the soak window has elapsed without regression; `archived`
is used after `docs/MIGRATION.md` archival of the v1 repo. The `days-on-v2`
column is updated manually by the operator -- v1 ships no helper task for
the soak counter, and an automated soak-check task is deliberately deferred
(see `.planning/phases/08-validation-cutover-readiness/08-CONTEXT.md`
section "Deferred Ideas").

| machine | status | cutover-date | last-validate-pass | days-on-v2 | notes |
|---------|--------|--------------|--------------------|------------|-------|
| personal-laptop | planning | - | - | - | primary dev box; Apple Silicon |
| work-laptop | planning | - | - | - | work identity; GUI + dev environment |
| server-1 | planning | - | - | - | headless ops; macos-security only |
| server-2 | planning | - | - | - | headless ops; macos-security only |
