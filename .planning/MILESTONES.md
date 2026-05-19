# Milestones

## v2.1 Cleanup (Shipped: 2026-05-19)

**Goal:** Make the v2 dotfiles repo lean, correct, and self-contained — port any silently-dropped v1 features, remove v1 entirely, redesign the public task surface, eliminate code/comment bloat and dead code, dedupe documentation.

**Phases completed:** 6 (Phases 9-14) | **Plans:** 24/24 | **Requirements:** 30/30 satisfied

### Key Accomplishments

- **v1-Drop Audit (Phase 9):** Read-only enumeration of every v1 leftover taskfile, install asset, `zsh/` tree content, and doc; produced `AUDIT.md` keep/drop classification with v2 owner column. Caught the live `/etc/zshenv` `ZDOTDIR` write bug that was silently breaking fresh-machine installs.
- **v1-Drop Remediation (Phase 10):** Implemented every "keep" item; fresh-machine install now produces a fully-functional first shell on first boot without manual remediation.
- **v1 Removal (Phase 11):** Deleted 8 v1 leftover taskfiles, the `zsh/` tree, 4 v1 Brewfiles, and the cutover infrastructure (`install/cutover-gate.zsh`, `cutover:ack` task, `docs/CUTOVER.md`). Simplified `Taskfile.yml`. Per-machine 7-day-soak model retired.
- **Task Surface Redesign (Phase 12):** Audited every `task --list` entry; applied keep/rename/internal/remove verdicts; reduced the operator surface to a curated 5-command top-level (`task install / setup / validate / test / lint`) plus 3 diagnostic namespaces (`show:* / audit:* / refresh:*`).
- **Code Review + Dead-Code Cleanup (Phase 13):** Repo-wide language-aware review surfaced 37 findings (2 HIGH, 18 MEDIUM, 17 LOW); all HIGH and most MEDIUM fixed in-phase. Notable: fixed the `links:*` target-match status-block bug so `readlink -f` is checked against the manifest-expected source (deliberately-corrupted-symlink test in `13-SMOKE.md`).
- **Comment + Doc Trim (Phase 14):** Stripped 1,378 comment lines (52% reduction) across 42 taskfile + `.zsh` files with the 3-label banner shape (D-01/D-02/D-03). Rewrote `README.md` humans-only, `docs/MANIFEST.md` motd-drift purged, `.claude/CLAUDE.md` deleted (content ported to root `CLAUDE.md`, 220 lines). Final SC#5 grep gate (`v1 bug / Gap N / D-NN / UAT Gap`) returns PASS in non-`.planning/` code.

### Gate Results

- **All 30 v2.1 requirements satisfied** (AUDIT-01..05, PORT-01..03, RMV-01..07, SURF-01..04, REVW-01..06, TRIM-01..05).
- **All 6 phases verified passed** with phase-level VERIFICATION.md reports.
- **End-to-end `task install && task validate` exits 0** on a converged personal-laptop after every commit and at milestone close.
- **Two non-blocking tech-debt items recorded** (Plan 14-02 strip-manifest scope gap; LSP-only YAML schema noise on LINT-08 fixture taskfiles).

### Diagnosed Bugs Resolved by v2.1 Cleanup

Three debug sessions closed without a labeled fix at v2.1 milestone close; verified resolved in current code on 2026-05-19 before v2.2 planning:

- `manifest-namespace-double-prefix` — fixed by Phase 12 task surface redesign (`taskfiles/manifest.yml` now declares bare task keys; double-prefix gone).
- `resolver-warn-fallback-broken` — fixed by Phase 13/14 template-dedup work (`RESOLVED_JSON_PATH` collapsed to a one-hop chain; bare-slash warning cannot reproduce).
- `validate-git-empty-useremail-after-install` — fixed by `validate:git` probe-dir rewrite (locates a real `.git` under `~/git/<identity>/` and probes from there; `task validate` exits 0 with `✓ git user.email matches identity`).

See `.planning/debug/` for the diagnosis transcripts (now flagged `status: verified-fixed`) and `.planning/milestones/v2.1-MILESTONE-AUDIT.md` for the full audit.

**Archive:** `.planning/milestones/v2.1-ROADMAP.md`, `.planning/milestones/v2.1-REQUIREMENTS.md`, `.planning/milestones/v2.1-MILESTONE-AUDIT.md`

---
