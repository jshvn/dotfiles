---
phase: 06
slug: os-defaults-macos-configuration
verifier: gsd-verifier
status: passed
must_haves_total: 18
must_haves_verified: 18
requirements: [OSCF-01, OSCF-02, OSCF-03, OSCF-04, OSCF-05]
requirements_verified: [OSCF-01, OSCF-02, OSCF-03, OSCF-04, OSCF-05]
created: 2026-05-15
---

# Phase 6: OS Defaults -- macOS Configuration -- Verification Report

**Phase Goal:** macOS defaults split into per-concern files, opt-in via manifest features,
idempotent on every run.

**Verified:** 2026-05-15
**Status:** passed

## Goal verification

The codebase actually delivers the phase goal. All five ROADMAP Phase 6 success criteria
resolve to verifiable evidence on disk:

1. **SC#1 (feature-gated per-concern apply):** `taskfiles/macos.yml` defines five
   `defaults:<concern>` tasks (`dock`, `finder`, `input`, `screenshots`, `security`), each
   wrapping its `cmds:` and `status:` heredocs with a template-time short-circuit
   `{{if not (index .MANIFEST.features "macos-<concern>")}}exit 0{{end}}` -- the RESEARCH
   Pattern 2 single-shell-block gate. When the feature is off, the heredoc renders to
   literal `exit 0` and skips. When on, it sources `os/defaults/<concern>.zsh` and runs
   `apply_<concern>`. Concrete evidence in macos.yml lines 140-208.
2. **SC#2 (idempotency via `status:` reading current defaults):** Every per-concern
   `status:` block sources the concern script and runs `verify_<concern>`, which iterates
   the `<CONCERN>_DEFAULTS` tuple array and calls `defaults read <domain> <key>` for each
   tuple (with bool round-trip normalization for `-bool` write_type). The live
   `task macos:validate` run on 2026-05-15 returned 19 check rows with exit 0 on a
   converged laptop, and the laptop-round-trip UAT (Test 3) confirmed a second
   `task macos:defaults` invocation prints zero apply info lines.
3. **SC#3 (`task macos:shell` uses `{{.BREW_ZSH}}` template var, not `$BREW_ZSH`):** The
   `shell:` task status block (macos.yml lines 237-243) uses `{{.BREW_ZSH}}` in both
   `grep -qxF` and `dscl ... UserShell` checks; `USER_NAME` is hoisted via
   `sh: id -un` so the status block carries zero `$BREW_ZSH` AND zero `$USER` shell-var
   references. The regression grep
   (`yq '.tasks.shell.status' taskfiles/macos.yml | grep -E '\$BREW_ZSH\b|\$USER\b'`)
   returns nothing. The v1 macos:shell:145 bug class is structurally closed on the
   producer side; the script-side counterpart (`os/shell-registration.zsh:66`'s
   `: "${BREW_ZSH:?...}"` mandatory-assertion) closes it on the consumer side.
4. **SC#4 (server-mode):** `manifests/machines/server-1.toml` and
   `manifests/machines/server-2.toml` both declare `macos-security = true` and omit the
   four GUI features; the deliberate-absence comment names the omitted keys. The Test 2
   UAT cross-machine resolver invocation
   (`zsh install/resolver.zsh --machine server-1 --stdout`) confirmed
   `macos-dock=false`, `macos-finder=false`, `macos-input=false`, `macos-screenshots=false`,
   `macos-security=true` per D-04. With those gates, `macos:defaults` would run only the
   security concern on servers, while `macos:shell` runs unconditionally (no feature gate).
5. **SC#5 (`task validate` asserts in-script expected values):** The `validate:` task in
   macos.yml (lines 255-305) is an always-rerun aggregator (`status: [false]`) that
   sources every enabled concern's script and runs `verify_<concern>`. The enumerate-all
   pattern (`failed=0; ... || failed=1; ... exit "$failed"`) reports drift on any
   concern without fast-failing. Live run returned 19 check rows + exit 0.

The phase goal is achieved.

## Per-plan deliverables

| Plan  | Claimed deliverable                                              | On-disk evidence                                                                                                                                                                                                                                          | Status     |
| ----- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| 06-01 | Four kebab-case `macos-*` keys in `manifests/defaults.toml`      | `manifests/defaults.toml:30-34` declares `macos-dock`, `macos-finder`, `macos-input`, `macos-screenshots`, `macos-security` all = false                                                                                                                   | VERIFIED   |
| 06-01 | `macos-finder` dual-consumer comment (D-01)                      | `manifests/defaults.toml:31` `# gates shell/aliases/finder.zsh (P3) + os/defaults/finder.zsh (P6) -- D-01 same-flag-two-consumers`                                                                                                                        | VERIFIED   |
| 06-01 | `macos-security = true` on server-1.toml + server-2.toml         | `manifests/machines/server-1.toml:18` and `server-2.toml:18` (identical); deliberate-absence comment on line 19 names the omitted keys                                                                                                                   | VERIFIED   |
| 06-02 | Five `os/defaults/<concern>.zsh` scripts with apply/verify       | `dock.zsh`, `finder.zsh`, `input.zsh`, `screenshots.zsh`, `security.zsh` all present; each defines `apply_<concern>` and `verify_<concern>` (grep confirmed)                                                                                              | VERIFIED   |
| 06-02 | `os/shell-registration.zsh` with apply/verify                    | `os/shell-registration.zsh:68 apply_shell_registration`; `:87 verify_shell_registration`; `:66 : "${BREW_ZSH:?...}"` mandatory caller assertion                                                                                                          | VERIFIED   |
| 06-02 | Every `os/*.zsh` starts with `set -euo pipefail`                 | Grep confirms `set -euo pipefail` in all six (`dock.zsh:` + `finder.zsh:` + `input.zsh:` + `screenshots.zsh:` + `security.zsh:` + `shell-registration.zsh:48`)                                                                                            | VERIFIED   |
| 06-02 | `os/README.md` DOCS-02 sibling README                            | `os/README.md` present; four-section structure (Purpose, Key files, Adding a pattern, References); documents dual-consumer + bug-class fix                                                                                                                | VERIFIED   |
| 06-03 | `taskfiles/macos.yml` with 8 tasks                               | `yq '.tasks \| keys'` enumerates `defaults`, `defaults:dock`, `defaults:finder`, `defaults:input`, `defaults:screenshots`, `defaults:security`, `shell`, `validate` (8 total; five `defaults:*` are `internal: true`)                                     | VERIFIED   |
| 06-03 | `Taskfile.yml includes.macos` flipped from stub                  | `Taskfile.yml:109` `macos:    ./taskfiles/macos.yml           # P6 ships real bodies`                                                                                                                                                                     | VERIFIED   |
| 06-03 | v1 preserved at `taskfiles/macos.v1.yml.bak` (CF-11)             | File exists (8300 bytes)                                                                                                                                                                                                                                  | VERIFIED   |
| 06-03 | Stub `taskfiles/macos-stub.yml` deleted                          | `ls taskfiles/macos-stub.yml` returns "No such file or directory"                                                                                                                                                                                         | VERIFIED   |
| 06-03 | `docs/MANIFEST.md` feature-flag table updated                    | `docs/MANIFEST.md:456-460` -- five `macos-*` rows all show `` `false` `` in the default column; `macos-finder` row records `Phase 3 + Phase 6` dual-consumer ownership                                                                                  | VERIFIED   |
| 06-03 | `.planning/REQUIREMENTS.md` OSCF-05 in-script wording            | Grep shows `OSCF-05: task validate asserts current defaults values match in-script expectations`                                                                                                                                                          | VERIFIED   |
| 06-03 | Per-concern tasks marked `internal: true`                        | Grep counts 5 `internal: true` lines under `tasks:` (one per concern: dock, finder, input, screenshots, security)                                                                                                                                         | VERIFIED   |
| 06-04 | `06-HUMAN-UAT.md` with 5 tests + sign-off                        | File present, 218 lines; Pre-conditions + Tests 1-5 + Sign-off + References; all five sign-off rows show `green`                                                                                                                                          | VERIFIED   |
| 06-04 | "Phase 6 UAT approved by:" line filled in                        | Line 200: `**Phase 6 UAT approved by:** Josh Vaughen  2026-05-15`                                                                                                                                                                                         | VERIFIED   |
| 06-04 | Tests 1 + 5 auto-passed                                          | Sign-off rows 1 + 5 marked `green`, dated 2026-05-15, tester recorded                                                                                                                                                                                     | VERIFIED   |
| 06-04 | Tests 2 + 3 + 4 human-passed                                     | Sign-off rows 2-4 marked `green`, dated 2026-05-15, tester `Josh Vaughen`, notes captured for each (server-mode resolver evidence + idempotency runtime check + deliberate-drift rollback)                                                                | VERIFIED   |

## Requirement traceability

| Requirement | Plan that delivered it | Evidence file:line                                                                                            | Status      |
| ----------- | ---------------------- | ------------------------------------------------------------------------------------------------------------- | ----------- |
| OSCF-01     | 06-02 (+ 06-03 wiring) | `os/defaults/{dock,finder,input,screenshots,security}.zsh` (5 files); `taskfiles/macos.yml:140-208`           | SATISFIED   |
| OSCF-02     | 06-01 (+ 06-03 wiring) | `manifests/defaults.toml:30-34` (5 kebab-case keys, default false); per-concern feature gates in `macos.yml`  | SATISFIED   |
| OSCF-03     | 06-02 (+ 06-03 wiring) | `verify_<concern>` reads `defaults read` per tuple; `taskfiles/macos.yml` status blocks call `verify_<concern>` for idempotency | SATISFIED   |
| OSCF-04     | 06-02 (+ 06-03 wiring) | `os/shell-registration.zsh:68,87` apply/verify; `taskfiles/macos.yml:237-243` shell:status uses `{{.BREW_ZSH}}` + `{{.USER_NAME}}` (zero shell-vars) | SATISFIED   |
| OSCF-05     | 06-02 (+ 06-03 wiring) | `taskfiles/macos.yml:255-305` validate task enumerates `verify_<concern>` per enabled concern; live run = 19 check rows, exit 0 | SATISFIED   |

All five OSCF-* requirements declared for Phase 6 are accounted for and satisfied. No
orphaned requirements (REQUIREMENTS.md maps OSCF-01..05 to Phase 6 only; all five are
claimed by Phase 6 plans).

## Bug-class structural fix

Explicit verification that the v1 `macos:shell:145` `$BREW_ZSH`-in-status regression class
cannot re-emerge from `taskfiles/macos.yml`:

```
$ yq '.tasks.shell.status' taskfiles/macos.yml
- grep -qxF "{{.BREW_ZSH}}" /etc/shells
- '[[ "$(dscl . -read "/Users/{{.USER_NAME}}" UserShell 2>/dev/null | awk ''{print $2}'')" = "{{.BREW_ZSH}}" ]]'

$ yq '.tasks.shell.status' taskfiles/macos.yml | grep -E '\$BREW_ZSH\b|\$USER\b'
(no output -- exit 1; zero shell-var references)
```

Both status entries reference `{{.BREW_ZSH}}` and `{{.USER_NAME}}` (template variables
resolved at task-graph build time -- always set), zero `$BREW_ZSH`, zero `$USER`. The
`USER_NAME` hoist via `vars.USER_NAME: { sh: id -un }` closes the LINT-02 blind-spot
where a `$VAR` on the same line as `{{` would slip past the lint-regex filter (recorded
in commit `eb535b6` per the WR-01..06 code-review fixes). The script-side counterpart
(`os/shell-registration.zsh:66` `: "${BREW_ZSH:?...}"` mandatory assertion) makes the
contract two-sided -- a future caller that forgets to export `BREW_ZSH` aborts loudly
instead of silently re-running.

`task lint:taskfile` and `task lint:syntax` were green on `taskfiles/macos.yml` per the
live-validation results recorded in the phase context.

## Gaps

None. All 18 must-haves verified; all five ROADMAP success criteria satisfied with
on-disk evidence; UAT sign-off complete (5/5 green, approved); zero anti-patterns found
in Phase 6 files (no `TBD`/`FIXME`/`XXX`, no `TODO`/`HACK`/`placeholder` markers).

## Notes

- **Phase 8 deferred follow-up (documented, not a Phase 6 gap):** `task manifest:resolve`
  has an mtime-cache bug -- the status block in `taskfiles/manifest.yml:164-168` only
  invalidates `resolved.json` when manifest TOMLs are newer than `resolved.json`. When
  only the active-machine state file (`$XDG_STATE_HOME/dotfiles/machine`) changes, the
  cache is not invalidated and a stale `resolved.json` is served. The Phase 6 server-mode
  contract was proven via the direct `install/resolver.zsh --stdout` bypass; the manifest
  itself is correct (the bug is in cache invalidation, not the resolver). Recorded as a
  Phase 8 todo in the 06-HUMAN-UAT.md Test 2 sign-off notes and 06-01-SUMMARY.md
  Deviations section. Does NOT invalidate the Phase 6 contract.

- **Pre-existing lint failures in `common.yml`, `manifest.yml`, `brew.yml`, `claude.yml`**
  are documented in 06-02-SUMMARY.md and 06-04-SUMMARY.md as owned by Phase 7 (CLAUDE)
  and Phase 8 (cutover/wrap-up). They are NOT introduced by Phase 6. The Phase 6 file
  `taskfiles/macos.yml` is green on `lint:taskfile` and `lint:syntax` per the live
  validation results.

- **Code-review WR-01..06 fixes** landed in commit `eb535b6`:
  - WR-01..05: sysadminctl parser handles "Guest account disabled." + "Enabled = false" +
    "Enabled: No" forms (security.zsh:115-121 + :175-181)
  - WR-06: USER_NAME hoist closes the LINT-02 blind-spot on the shell:status block

- **CF-11 preservation invariant:** `taskfiles/macos.v1.yml.bak` retains the byte-stable
  v1 monolith for cross-reference until Phase 8 owns final deletion.

- **D-04 server contract verified at resolver level:** `personal-laptop` and
  `work-laptop` resolve all five `macos-*` = true; `server-1` and `server-2` resolve
  `macos-security = true` and the other four = false. Confirmed via direct resolver
  invocation; documented in 06-01-SUMMARY.md self-check.

---

*Verified: 2026-05-15*
*Verifier: Claude (gsd-verifier)*
