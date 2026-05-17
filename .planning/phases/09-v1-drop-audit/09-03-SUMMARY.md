---
phase: 09-v1-drop-audit
plan: 03
subsystem: planning/audit
tags: [audit, zsh-tree, wave-2, AUDIT-03]
dependency_graph:
  requires:
    - "09-01 (AUDIT.md skeleton + shards/ directory)"
  provides:
    - "shards/zsh-tree.md (43 audit rows -- 6 startup + 24 functions + 4 aliases + 7 configs + 2 styles)"
    - "AUDIT-03 coverage of the v1 zsh/ tree (file-by-file behavioral diff vs shell/)"
  affects:
    - ".planning/phases/09-v1-drop-audit/shards/zsh-tree.md"
tech_stack:
  added: []
  patterns:
    - "Per-shard parallel writes (Wave 2 pattern) -- this plan owns zsh-tree.md, no contention with 09-02 (taskfiles.md + install-assets.md) or 09-04 (docs.md)"
    - "Block-level rationale per startup file (D-08) -- one row per file with ';'-separated block dispositions in the rationale column"
    - "Behavioral diff classification per function (D-05) -- identical / ported-with-documented-delta / partial port / dropped"
    - "Per-machine effective-set comparison for aliases (D-06) -- builds personal-laptop / work-laptop / server-1 / server-2 effective sets from feature gates, set-diffs alias names AND body-level diffs RHS values"
    - "Body-level diff for configs/styles (D-07) -- diff each v1 file against its v2 sibling; presence-only check is rejected"
key_files:
  created: []
  modified:
    - ".planning/phases/09-v1-drop-audit/shards/zsh-tree.md"
decisions:
  - "Startup-file rows use the actual line count from `wc -l` for the file:line range"
  - "Block-level dispositions in rationale use a ';'-separated list (D-08) instead of one row per block, keeping the locked six-column shape (D-03)"
  - "v1 `update.zsh` (no v2 sibling) classified `dropped` / `drop` -- v2's `task install` (D-10 canonical pipeline) plus the v2 `update='task install'` alias in shell/aliases/dotfiles.zsh fully supersedes the function's behavior; no operator-useful behavior remains"
  - "v1 `general.zsh` classified `partially-ported` / `drop` -- finder/findershow/finderhide and g moved to gated v2 files (shell/aliases/finder.zsh under macos-finder, shell/aliases/ghostty.zsh under ghostty); D-09 intentional improvement; the unconditional v1 aliases that loaded on server profiles and broke on non-GUI machines (CONCERNS.md) are now correctly gated"
  - "All seven v1 configs and both v1 styles confirmed byte-identical to v2 siblings via `diff` (D-07 body-level check, not presence-only)"
  - "v1 `motd.zsh` and `pubkey.zsh` rows cite the D-10 bug cross-references explicitly: motd's synchronous fastfetch/git-log replaced by SHEL-11 24h-TTL cache; pubkey's stale id_rsa_adobe.pub docstring fixed to id_ed25519_personal.pub"
metrics:
  duration_seconds: 0
  completed_date: "2026-05-17"
requirements:
  - AUDIT-03
---

# Phase 9 Plan 3: Audit the v1 zsh/ Tree Against v2 shell/ Summary

Produced `.planning/phases/09-v1-drop-audit/shards/zsh-tree.md` -- 43 audit rows covering the entire v1 `zsh/` tree (6 startup files via D-08, 24 function files via D-05, 4 alias files via D-06 per-machine effective-set, 7 config files + 2 style files via D-07 body-level diff). Locked six-column shape (D-03) preserved across every row. The shard will be concatenated into AUDIT.md's `## zsh/ Tree` section by plan 09-05.

## Completed Tasks

| Task | Name                                                                                                                | Commit  | Files                                                       |
| ---- | ------------------------------------------------------------------------------------------------------------------- | ------- | ----------------------------------------------------------- |
| 1    | Audit six v1 startup files (D-08) and 24 v1 function files (D-05) into shards/zsh-tree.md                           | 49acf9d | .planning/phases/09-v1-drop-audit/shards/zsh-tree.md        |
| 2    | Audit zsh/aliases/ via per-machine effective-set diff (D-06) and zsh/configs/ + zsh/styles/ via body-level diff (D-07); append to shards/zsh-tree.md | 125de60 | .planning/phases/09-v1-drop-audit/shards/zsh-tree.md        |

## What Was Built

**shards/zsh-tree.md (43 rows, locked six-column shape per D-03):**

Row counts per block:

| Block | Rows | Decision basis |
|-------|------|-----------------|
| Startup files (D-08) | 6 (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`, `theme.zsh`) | One row per file; block-level rationale lists per-block disposition |
| Functions (D-05) | 24 (alphabetical) | Behavioral diff vs `shell/functions/<name>.zsh` sibling |
| Aliases (D-06) | 4 (`common/general.zsh`, `common/hardware.zsh`, `common/networking.zsh`, `personal/jgrid.zsh`) | Per-machine effective-set + body-level value diff |
| Configs (D-07) | 7 (`condarc`, `ghostty`, `glow.yml`, `motd_sysinfo.jsonc`, `motd_tron.txt`, `tlrc.toml`, `trippy.toml`) | Body-level diff vs `configs/<tool>/<file>` |
| Styles (D-07) | 2 (`eza_style.yaml`, `glow_style.json`) | Body-level diff vs `configs/<tool>/<file>` |

**Total:** 43 rows. Plan acceptance criteria required >=22 function rows and >=4 alias rows; final counts are 24 and 4 respectively.

## Function Files Classified `partially-ported` or `dropped` (Phase 10 keep candidates)

The list below is the actionable Phase 10 input for the function tree. Only one function file needs explicit Phase 10 keep work (`update.zsh`); the four `ported-with-documented-delta` entries listed under "Already-ported (with delta)" do not need Phase 10 work because the v2 implementation already covers their behavior under the manifest model.

**Dropped (1 file -- v1-only, no v2 sibling):**

- `zsh/functions/update.zsh` -- classified `dropped` / `drop`. The behavior (cd $DOTFILEDIR && task update) is fully superseded by v2's `task install` (D-10 canonical pipeline, "install IS update") and by the v2 `update='task install'` alias in `shell/aliases/dotfiles.zsh`. No Phase 10 port required; no Phase 11 deletion blocker.

**Partially-ported (0 files):** None. All v2 function siblings exist; no `partial port (v2 missing behavior X)` classifications.

**Already-ported with documented delta (4 files -- listed for reference; not Phase 10 keep candidates):**

- `zsh/functions/aliaslist.zsh` -- v2 drops profile-subdir walk; behavior preserved on personal-laptop under manifest model.
- `zsh/functions/functionlist.zsh` -- same: v2 drops profile-subdir walk.
- `zsh/functions/motd.zsh` -- v2 adds 24h-TTL cache + async refresh (SHEL-11) wrapping v1's render logic verbatim in `_motd_render`.
- `zsh/functions/pubkey.zsh` -- v2 fixes the CONCERNS.md docstring bug (`id_rsa_adobe.pub` -> `id_ed25519_personal.pub`).
- `zsh/functions/sshlist.zsh` -- v2 drops profile-config branch; Phase 4 (IDNT-03) will own SSH identity selection.

**Byte-identical ports (18 files):** afk, cheat, docker, fs, geoip, getcertnames, ghpubkey, host, info, ipv4lookup, ipv6lookup, mkcd, permissions, prettyjson, sethostname, timezsh, vnc, whois.

## Aliases Missing From v2 Per Machine

Per-machine effective-set comparison (D-06) findings:

**personal-laptop** (v1 set = `common/*.zsh` + `personal/jgrid.zsh`; v2 set = all flat `shell/aliases/*.zsh` minus the wrappers in `finder.zsh` + `ghostty.zsh`, plus `jgrid.zsh` gated on `jgrid-net=true`):

- Zero v1 alias names missing from v2; zero RHS value drift across hardware.zsh, networking.zsh, jgrid.zsh, and the non-finder/ghostty content of general.zsh.
- v2 adds one new alias: `update='task install'` (in `shell/aliases/dotfiles.zsh`), which replaces v1's `zsh/functions/update.zsh` wrapper.

**work-laptop** (v1 set = `common/*.zsh` only -- no `zsh/aliases/work/` exists per CONCERNS.md; v2 set = flat `shell/aliases/*.zsh` minus jgrid which is gated `false`):

- Zero v1 alias names missing from v2 (finder + g present via wrapper functions because `macos-finder=true` and `ghostty=true` on work-laptop).
- No value drift.

**server-1** and **server-2** (v1 set = `common/*.zsh` only; v2 set = flat `shell/aliases/*.zsh` minus jgrid/finder/ghostty -- all three feature flags `false`):

- Four v1 alias names absent from v2 server effective set: `finder`, `findershow`, `finderhide`, `g`. These were unconditional v1 entries in `zsh/aliases/common/general.zsh:26-31,40` that loaded on server machines without guards (CONCERNS.md macOS-only commands in common scope, and ghostty cask never installed on headless servers). **This is an intentional D-09 improvement**, not a regression: the v2 manifest gates correctly omit these from the server effective set so they no longer present `command not found` failures on invocation. The rows in shards/zsh-tree.md classify `general.zsh` as `partially-ported` / `drop` with the gating files (`shell/aliases/finder.zsh`, `shell/aliases/ghostty.zsh`) named as the v2 owners.
- No value drift on the alias bodies that ARE present in v2 (hardware.zsh, networking.zsh, and the non-finder/ghostty rows of general.zsh are all byte-identical).

## Configs With Non-Empty Body-Level Diff

**None.** All nine v1 config / style files are byte-identical to their v2 siblings (D-07 body-level diff returns empty for every file):

| v1 file | v2 sibling | Diff |
|---------|------------|------|
| zsh/configs/condarc | configs/conda/condarc | IDENTICAL |
| zsh/configs/ghostty | configs/ghostty/config | IDENTICAL (renamed) |
| zsh/configs/glow.yml | configs/glow/glow.yml | IDENTICAL |
| zsh/configs/motd_sysinfo.jsonc | configs/motd/motd_sysinfo.jsonc | IDENTICAL |
| zsh/configs/motd_tron.txt | configs/motd/motd_tron.txt | IDENTICAL |
| zsh/configs/tlrc.toml | configs/tlrc/config.toml | IDENTICAL (renamed) |
| zsh/configs/trippy.toml | configs/trippy/trippy.toml | IDENTICAL |
| zsh/styles/eza_style.yaml | configs/eza/theme.yaml | IDENTICAL (renamed) |
| zsh/styles/glow_style.json | configs/glow/glow_style.json | IDENTICAL |

Phase 7 TOOL-02 ported these correctly with zero operator-side hand-edit drift. Three files were renamed to match the tool's expected config-file convention (ghostty -> config, tlrc.toml -> config.toml, eza_style.yaml -> theme.yaml). The motd_*  files retain their v1 paths because v2 `shell/functions/motd.zsh:91,115` still reads from `${DOTFILEDIR}/zsh/configs/motd_*` -- this is a known Phase 10 keep candidate for path-migration to `${DOTFILEDIR}/configs/motd/`, but is unrelated to AUDIT-03's body-level diff scope (the file bodies are byte-identical).

## D-10 Bug Cross-References Landed

Confirmed cross-references in shards/zsh-tree.md for the CONCERNS.md known v1 bugs that v2 fixes:

| Row | CONCERNS.md bug | D-10 disposition |
|-----|------------------|------------------|
| `zsh/.zprofile:1-56` | Hardcoded `[[ "$(hostname -s)" != "server" ]]` literal hostname check (zsh/.zprofile:55-56) | rationale names the bug ("v1 line 55-56, hardcoded `[[ "$(hostname -s)" != "server" ]]` -- CONCERNS.md known bug") and the v2 fix (manifest-driven jq read of `features."one-password-ssh"` from `resolved.json`); classification `ported` / `drop` |
| `zsh/functions/pubkey.zsh:1-12` | Stale `id_rsa_adobe.pub` prior-employer docstring (zsh/functions/pubkey.zsh:4) | rationale names the v2 fix (`shell/functions/pubkey.zsh:4` references `id_ed25519_personal.pub`); classification `ported` / `drop` |
| `zsh/.zshrc:1-129` (bonus, not a CONCERNS.md "bug" but a CONCERNS.md "performance bottleneck") | `antigen apply` 200-500ms cold-start overhead (zsh/.zshrc:53-72) | rationale names the v2 fix (antidote bundle-cache loaded from `configs/antidote/zsh_plugins.txt` with mtime-based lazy rebuild, SHEL-04); classification `ported` / `drop` |

## Verification Results

All Task 1 acceptance criteria pass:

- 5 dotfile-prefixed startup rows (`grep -cE '^\| zsh/\.(zshenv|zprofile|zshrc|zlogin|zlogout)'` returns `5`)
- 1 theme.zsh row
- .zprofile row references hostname-server bug
- .zshrc row references antigen
- .zshenv row references DOTFILES_PROFILE / manifest model change
- 24 function-file rows (>= 22 required)
- pubkey.zsh and motd.zsh rows present
- update.zsh classified `dropped`
- v2 status column uses only the locked values
- No emojis

All Task 2 acceptance criteria pass:

- All 4 alias-file rows present (general, hardware, networking, jgrid)
- finder relocation note present (`macos-finder feature gate`)
- 7 config-file rows (>= 7 required)
- 2 style-file rows (>= 2 required)
- Per-machine effective-set references present
- v2 status + keep/drop columns use only the locked values across the entire file
- No emojis

## Deviations from Plan

None. The plan was executed exactly as written:

- Task 1 wrote the 6 startup-file rows and 24 function-file rows in the order specified (startup first in the exact order .zshenv, .zprofile, .zshrc, .zlogin, .zlogout, theme.zsh; then functions alphabetically).
- Task 2 appended (not overwrote) the 4 alias-file rows, 7 config-file rows, and 2 style-file rows in the order specified (aliases first sorted by file path, then configs alphabetically, then styles alphabetically).
- All file:line ranges derived from `wc -l` of the actual v1 file.
- All required D-10 cross-references landed in the specified rows.
- The shard does NOT contain a `## zsh/ Tree` header (that header lives in AUDIT.md already; plan 09-05 will concatenate the shard verbatim under that header).

## Known Stubs

None. The shard is a complete enumeration of every file in the v1 zsh/ tree (6 startup files + 24 functions + 4 alias files + 7 configs + 2 styles = 43 files), each with a row that records the v2 status, keep/drop decision, behavioral or body-level rationale, and v2 owner file. The only v1-only file (`update.zsh`) is explicitly classified `dropped` / `drop` with a substantive rationale; this is not a stub but a final classification.

## Threat Flags

None. This plan is read-only (T-09-03 disposition: `accept`). No v1 code was sourced or executed; all comparisons were textual via `diff`, `wc -l`, and `grep` / `comm` over alias-name sets. No new network endpoints, no auth paths, no file access patterns introduced.

## Self-Check: PASSED

**Created files:**

- `.planning/phases/09-v1-drop-audit/shards/zsh-tree.md` -- FOUND (43 lines, 30 + 13 row inserts across the two commits)
- `.planning/phases/09-v1-drop-audit/09-03-SUMMARY.md` -- this file (FOUND)

**Commits:**

- `49acf9d` -- FOUND (`docs(09-03): audit v1 zsh startup + functions in shards/zsh-tree.md`, 1 file changed, 30 insertions)
- `125de60` -- FOUND (`docs(09-03): audit v1 zsh aliases + configs/styles in shards/zsh-tree.md`, 1 file changed, 13 insertions)

All acceptance criteria for both tasks pass per the verification block above.
