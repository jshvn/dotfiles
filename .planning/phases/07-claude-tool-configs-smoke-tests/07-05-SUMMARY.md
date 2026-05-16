---
phase: 07-claude-tool-configs-smoke-tests
plan: 05
subsystem: configs
tags: [ghostty, glow, trippy, tlrc, conda, eza, motd, tool-configs, symlinks]

# Dependency graph
requires:
  - phase: 07-02
    provides: hardened _:safe-link helper that Plan 06 will use to register symlinks for these configs

provides:
  - configs/ghostty/config (Ghostty terminal config, gated on features.ghostty)
  - configs/glow/glow.yml and configs/glow/glow_style.json (Glow markdown viewer config + style)
  - configs/trippy/trippy.toml (Trippy traceroute TUI config)
  - configs/tlrc/config.toml (tlrc tldr-rust client config; renamed from v1 tlrc.toml per D-06)
  - configs/conda/condarc (Conda XDG-redirecting config)
  - configs/eza/theme.yaml (eza color theme; renamed from v1 eza_style.yaml per D-06)
  - configs/motd/motd_tron.txt and configs/motd/motd_sysinfo.jsonc (MOTD data files; no symlink)
  - configs/README.md with real tool table and how-to-add pattern
  - per-tool README.md for all seven subdirectories

affects:
  - 07-06 (links plan: uses these exact source paths to wire _:safe-link entries in taskfiles/links.yml)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-05: per-tool subdirectory under configs/ always, even single-file tools"
    - "D-06: source basename equals destination basename; rename in transit during port"
    - "D-08: motd configs live at configs/motd/ for symmetry but have no symlink; shell function reads repo path directly"

key-files:
  created:
    - configs/ghostty/config
    - configs/ghostty/README.md
    - configs/glow/glow.yml
    - configs/glow/glow_style.json
    - configs/glow/README.md
    - configs/trippy/trippy.toml
    - configs/trippy/README.md
    - configs/tlrc/config.toml
    - configs/tlrc/README.md
    - configs/conda/condarc
    - configs/conda/README.md
    - configs/eza/theme.yaml
    - configs/eza/README.md
    - configs/motd/motd_tron.txt
    - configs/motd/motd_sysinfo.jsonc
    - configs/motd/README.md
  modified:
    - configs/README.md (replaced P3 stub with real tool table)

key-decisions:
  - "Port via cp not mv: v1 sources stay byte-stable at zsh/configs/ and zsh/styles/ until P8 cutover (CF-11)"
  - "Ghostty v1 source is a flat file zsh/configs/ghostty; v2 destination is configs/ghostty/config matching Ghostty's expected XDG path"
  - "Two renames in transit: tlrc.toml -> config.toml (tlrc expects ~/.config/tlrc/config.toml) and eza_style.yaml -> theme.yaml (eza expects ~/.config/eza/theme.yaml)"

patterns-established:
  - "match-destination-filename (D-06): source basename == destination basename so _:safe-link calls are symmetric"
  - "per-tool subdirectory always (D-05): extensibility for future second config file per tool"
  - "motd runtime-read (D-08): configs/motd/ files exist without symlinks; shell/functions/motd.zsh reads from ${DOTFILEDIR}/configs/motd/ directly"

requirements-completed: [TOOL-02]

# Metrics
duration: 15min
completed: 2026-05-16
---

# Phase 07 Plan 05: Tool Configs Port Summary

**Seven v1 tool configs ported byte-identically to configs/<tool>/ subdirectories with two D-06 renames (tlrc.toml->config.toml, eza_style.yaml->theme.yaml), per-tool READMEs, and a real aggregate configs/README.md tool table**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-16
- **Completed:** 2026-05-16
- **Tasks:** 1
- **Files modified:** 17 (16 created + 1 updated)

## Accomplishments

- Ported all nine config files (10 including glow's two files) from v1 `zsh/configs/` and `zsh/styles/` into seven per-tool subdirectories under `configs/`
- Executed two rename-in-transit operations per D-06: `tlrc.toml` -> `tlrc/config.toml` and `eza_style.yaml` -> `eza/theme.yaml`
- Wrote per-tool `README.md` for all seven subdirectories documenting purpose, files, symlink destination, and feature gate
- Replaced the P3 stub `configs/README.md` with a real body: tool table with all eight entries (antidote + seven new), how-to-add pattern, and the D-05/D-06/D-08 conventions
- All copies verified byte-identical via `diff -q`; v1 sources remain intact on disk (CF-11 parallel-rewrite invariant)

## Task Commits

1. **Task 1: Port seven tool configs into `configs/<tool>/` with per-tool READMEs** - `dee48d8` (feat)

## Files Created/Modified

- `configs/ghostty/config` - Ghostty terminal config (font, palette, opacity, SSH env integration)
- `configs/ghostty/README.md` - Purpose, destination, `features.ghostty` gate
- `configs/glow/glow.yml` - Glow markdown viewer config (width, mouse, pager settings)
- `configs/glow/glow_style.json` - Glow custom color style (Tron-adjacent terminal colors)
- `configs/glow/README.md` - Purpose, both destinations, always-on gate
- `configs/trippy/trippy.toml` - Trippy traceroute TUI config (strategy, DNS, theme, bindings)
- `configs/trippy/README.md` - Purpose, destination, always-on gate
- `configs/tlrc/config.toml` - tlrc tldr-rust config (cache, display, indent, styles); renamed from v1 `tlrc.toml`
- `configs/tlrc/README.md` - Purpose, rename-in-transit note, destination, always-on gate
- `configs/conda/condarc` - Conda XDG redirect (envs to DATA, pkgs to CACHE, telemetry off)
- `configs/conda/README.md` - Purpose, destination (~/.condarc), always-on gate
- `configs/eza/theme.yaml` - eza color theme mapping LS_COLORS to eza categories; renamed from v1 `eza_style.yaml`
- `configs/eza/README.md` - Purpose, rename-in-transit note, destination, always-on gate
- `configs/motd/motd_tron.txt` - Tron quotes (13 lines); runtime-read by motd.zsh
- `configs/motd/motd_sysinfo.jsonc` - fastfetch module config; runtime-read by motd.zsh
- `configs/motd/README.md` - Purpose, no-symlink D-08 explanation, `features.motd` runtime gate
- `configs/README.md` - Replaced P3 stub with real tool table, how-to-add guide, D-05/D-06/D-08 conventions

## Decisions Made

- Used `cp` not `git mv` so v1 sources remain at `zsh/configs/` and `zsh/styles/` until P8 cutover (CF-11).
- The v1 ghostty source is a flat file `zsh/configs/ghostty` (not `zsh/configs/ghostty/config` as the plan's mapping table suggested). The v2 destination is correctly `configs/ghostty/config` matching Ghostty's XDG config path. The copy used the actual on-disk v1 path.
- Aggregate `configs/README.md` includes the pre-existing `antidote` entry in the tool table (T-07-27 threat mitigation: preserve existing content while adding new).

## Deviations from Plan

None - plan executed exactly as written. The plan's v1 source mapping for ghostty listed `zsh/configs/ghostty/config` but the actual on-disk file is `zsh/configs/ghostty` (a flat file). The v2 destination `configs/ghostty/config` is correct per D-06 and the copy was done from the actual source path. This is a documentation discrepancy in the plan's interface table, not a functional deviation.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 06 (`taskfiles/links.yml` configs sub-task) can now reference all seven source paths
- Source paths for `_:safe-link` calls:
  - `configs/ghostty/config` -> `~/.config/ghostty/config` (gated on `features.ghostty`)
  - `configs/glow/glow.yml` -> `~/.config/glow/glow.yml`
  - `configs/glow/glow_style.json` -> `~/.config/glow/glow_style.json`
  - `configs/trippy/trippy.toml` -> `~/.config/trippy/trippy.toml`
  - `configs/tlrc/config.toml` -> `~/.config/tlrc/config.toml`
  - `configs/conda/condarc` -> `~/.condarc`
  - `configs/eza/theme.yaml` -> `~/.config/eza/theme.yaml`
  - motd files: no symlinks needed

---
*Phase: 07-claude-tool-configs-smoke-tests*
*Completed: 2026-05-16*
