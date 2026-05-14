---
phase: 03-shell-layer-flat-content-port
plan: 03
subsystem: shell

tags: [zsh, functions, manifest, motd, cache, jq, resolved-json, flat-layout]

# Dependency graph
requires:
  - phase: 01-manifest-engine-repository-skeleton
    provides: "resolved.json schema (.features object of bool flags) consumed by _dotfiles_feature"
  - phase: 03-shell-layer-flat-content-port/03-01
    provides: "shell/ skeleton dirs and .zshenv exporting XDG vars consumed by motd and _dotfiles_feature"
provides:
  - "24 function files under shell/functions/ (1 net-new helper + 23 v1 ports)"
  - "_dotfiles_feature lazy manifest-flag query primitive (D-06) gating Plan 04 alias wrappers"
  - "Cache-backed motd() satisfying SHEL-11 (24h TTL + async background refresh, atomic write)"
  - "Three DOTFILES_PROFILE-free refactors (aliaslist, functionlist, sshlist) consistent with the v2 flat layout"
  - "pubkey docstring CONCERNS bug fix (id_rsa_adobe.pub -> id_ed25519_personal.pub)"
affects:
  - "03-04-PLAN (aliases): finder.zsh / ghostty.zsh / jgrid.zsh consume _dotfiles_feature"
  - "03-02-PLAN (.zshrc): function-glob loop picks up shell/functions/*.zsh including the leading-underscore helper"
  - "Phase 4 IDNT-03: per-identity SSH config display deferred marker lives in sshlist.zsh"
  - "Phase 7 configs/<tool>/ cutover: motd.zsh still references v1 zsh/configs/motd_{sysinfo.jsonc,tron.txt}"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Lazy manifest-flag query via typeset -gA associative array + load-once guard"
    - "Atomic cache-write via .tmp temp file + zsh background-and-disown (&!)"
    - "Cold-path / warm-path split for cached output (synchronous tee on first run; cat + async refresh thereafter)"

key-files:
  created:
    - shell/functions/_dotfiles_feature.zsh
    - shell/functions/afk.zsh
    - shell/functions/aliaslist.zsh
    - shell/functions/cheat.zsh
    - shell/functions/docker.zsh
    - shell/functions/fs.zsh
    - shell/functions/functionlist.zsh
    - shell/functions/geoip.zsh
    - shell/functions/getcertnames.zsh
    - shell/functions/ghpubkey.zsh
    - shell/functions/host.zsh
    - shell/functions/info.zsh
    - shell/functions/ipv4lookup.zsh
    - shell/functions/ipv6lookup.zsh
    - shell/functions/mkcd.zsh
    - shell/functions/motd.zsh
    - shell/functions/permissions.zsh
    - shell/functions/prettyjson.zsh
    - shell/functions/pubkey.zsh
    - shell/functions/sethostname.zsh
    - shell/functions/sshlist.zsh
    - shell/functions/timezsh.zsh
    - shell/functions/vnc.zsh
    - shell/functions/whois.zsh
  modified: []

key-decisions:
  - "Implement the synchronous-first-render cold path (tee into cache) — fresh-machine login still gets output instead of a silent blank screen"
  - "Drop motd_sysinfo.jsonc / motd_tron.txt references from the file-level comment block to satisfy the strict count=1 acceptance criterion; the file-level header now describes the deferral in prose"
  - "Adopt PATTERNS.md Option 3 for sshlist (main-config only; per-identity deferred to Phase 4) instead of trying to drive it off resolved.json identity selectors now"

patterns-established:
  - "Private helper convention: leading underscore on the function name (_dotfiles_feature, _motd_render) signals 'not for interactive use' while keeping the file globbable by .zshrc"
  - "Graceful degrade by default: missing resolved.json yields false for every feature lookup so gated wrappers stay safe pre-install"
  - "Cache-then-refresh wrapper around an expensive renderer — applicable to any future shell-startup hot path beyond MOTD"

requirements-completed: [SHEL-07, SHEL-09, SHEL-11]

# Metrics
duration: ~5min
completed: 2026-05-14
---

# Phase 03 Plan 03: Shell Functions Content Port Summary

**Ported 23 v1 zsh functions to the flat shell/functions/ layout, added the _dotfiles_feature lazy manifest-flag helper (D-06), and converted motd to a 24h-TTL cache with atomic-write async refresh (SHEL-11).**

## Performance

- **Duration:** ~5 min (3 task commits across roughly 138 s of git wall-clock)
- **Started:** 2026-05-14T22:33:00Z (approximate; first commit at 22:35:28 -0700)
- **Completed:** 2026-05-14T22:38:02Z
- **Tasks:** 3
- **Files modified:** 24 created (0 modified — shell/functions/ was empty going in)

## Accomplishments
- Net-new `_dotfiles_feature` helper: jq-backed lazy read of `$XDG_STATE_HOME/dotfiles/resolved.json` into a `typeset -gA` associative array; O(1) lookups after first call; safe under `set -u`; gracefully degrades to `"false"` when resolved.json is missing.
- 18 v1 functions ported byte-stable (afk, cheat, docker, fs, geoip, getcertnames, ghpubkey, host, info, ipv4lookup, ipv6lookup, mkcd, permissions, prettyjson, sethostname, timezsh, vnc, whois) — `diff zsh/functions/<n>.zsh shell/functions/<n>.zsh` empty for every one.
- `pubkey.zsh` ported verbatim except the line-4 docstring example, which now reads `id_ed25519_personal.pub` (CONCERNS cosmetic-fix item closed).
- `aliaslist.zsh`, `functionlist.zsh`, `sshlist.zsh` rewritten to drop `DOTFILES_PROFILE` entirely; aliaslist + functionlist collapse the v1 Common/Profile dual-walk into a single Dotfiles header pointing at the flat `shell/aliases` and `shell/functions` directories; sshlist keeps the main-config Host enumeration and embeds an inline `# Per-identity SSH config display deferred to Phase 4 (IDNT-03).` marker.
- `motd.zsh` rewritten as a cache-backed wrapper around the v1 rendering logic: cold path `tee`s into `$XDG_CACHE_HOME/dotfiles/motd.cache` so a fresh-machine login still gets visible output; warm path `cat`s the cache instantly; stale path (`now - mtime > 86400`) spawns an atomic `_motd_render > ${cache}.tmp && mv` job with `&!` so the prompt never blocks. The full v1 rendering body (Tron color scheme, adaptive logo, fastfetch sysinfo, dotfiles git status, Tron quote pool, footer) ports verbatim into `_motd_render`.
- `update.zsh` deliberately not ported (CF-06) — Plan 04 will ship an `alias update='task install'` in its place.

## Task Commits

Each task committed atomically; all three commits pre-existed on the worktree branch before SUMMARY:

1. **Task 1: _dotfiles_feature helper + 18 verbatim ports + pubkey docstring fix** — `0e35c48` (feat)
2. **Task 2: aliaslist / functionlist / sshlist DOTFILES_PROFILE removal** — `1746c07` (feat)
3. **Task 3: motd.zsh 24h-TTL cache (SHEL-11)** — `87e57cf` (feat)

## Files Created/Modified
- `shell/functions/_dotfiles_feature.zsh` — lazy manifest-flag query helper (D-06)
- `shell/functions/{afk,cheat,docker,fs,geoip,getcertnames,ghpubkey,host,info,ipv4lookup,ipv6lookup,mkcd,permissions,prettyjson,sethostname,timezsh,vnc,whois}.zsh` — 18 byte-stable v1 ports
- `shell/functions/pubkey.zsh` — v1 port with single-line docstring fix
- `shell/functions/aliaslist.zsh` — flat-layout rewrite (drops profile walk)
- `shell/functions/functionlist.zsh` — flat-layout rewrite (drops profile walk)
- `shell/functions/sshlist.zsh` — main-config-only rewrite; per-identity portion deferred to Phase 4
- `shell/functions/motd.zsh` — cache-backed wrapper + verbatim v1 rendering body inside _motd_render

## Decisions Made
- **Synchronous-first-render cold path for motd.** The PATTERNS.md sketch implied first-call-shows-nothing (mtime=0 always triggers async render). The plan's acceptance criteria explicitly call out "first login on a fresh machine: empty cache → cold path renders synchronously and writes cache". Implemented the `[[ ! -f "$cache" ]]` early-return that pipes `_motd_render | tee "$cache"` so the user sees output on first login instead of a silent prompt.
- **`motd_sysinfo.jsonc` / `motd_tron.txt` references appear exactly once each.** I initially mentioned both filenames in the file-level comment block AND in the rendering body, which fails the strict `grep -c ... = 1` acceptance criterion. Trimmed the comment block to talk about the deferral in prose; the literal filenames now appear only inside the rendering logic where the v1 paths are consumed.
- **Adopt PATTERNS.md Option 3 for sshlist.** Rather than parse `identity.ssh` from `resolved.json` or glob `ssh/configs/config-*`, sshlist shows just the main-config Host entries and leaves a Phase 4 (IDNT-03) deferral marker. This avoids inventing identity wiring before Phase 4 actually lands it.

## Deviations from Plan

None — plan executed exactly as written. All three tasks completed against the plan's `<action>` and `<acceptance_criteria>` blocks; the two micro-decisions above are explicitly called out by the plan as planner discretion (Pattern 14 "alternatively the planner may add a synchronous-first-render branch — but per PATTERNS.md Pattern 14 acceptance criteria, ‘first login on a fresh machine: empty cache → cold path renders synchronously and writes cache’. Implement the synchronous-first-render branch") and Pattern 16 (sshlist Option 3 is the recommended P3 shape).

## Issues Encountered

- **Acceptance count `grep -c motd_sysinfo.jsonc = 1`** initially failed because I duplicated the filename in the file-level comment block. Resolved by trimming the comment block to describe the deferral without naming the literal files. No code-behavior change.
- None of the v1 verbatim ports contained any DOTFILES_PROFILE references in the first place, so `grep -lr DOTFILES_PROFILE shell/functions/` came up empty without further intervention after the three rewrites landed.

## Self-Check: PASSED

Verified before writing this SUMMARY:

- `find shell/functions -name '*.zsh' | wc -l` → **24** (1 helper + 23 ports, no update.zsh)
- `for f in shell/functions/*.zsh; do zsh -n "$f" || echo FAIL; done` → no FAIL output (SHEL-09)
- `grep -lr DOTFILES_PROFILE shell/functions/` → empty
- `[ ! -e shell/functions/update.zsh ]` → succeeds (CF-06 honoured)
- 18-file byte-stable diff against `zsh/functions/<n>.zsh` → all empty
- `_dotfiles_feature` smoke: returns `false` for unknown flag both with and without `XDG_STATE_HOME` pointing at a real file
- motd: `function motd()` and `function _motd_render()` both defined once; `86400`, `motd.cache`, `stat -f %m`, `stat -c %Y`, `&!`, `${cache}.tmp`, `motd_sysinfo.jsonc`, `motd_tron.txt` all present at expected counts; `JGRID|J G R I D`, `SYSTEM ACCESS GRANTED`, `END OF LINE`, `fastfetch` all preserved from v1
- Commits present in `git log e473cf3..HEAD`: `0e35c48`, `1746c07`, `87e57cf`

## Next Phase Readiness
- Plan 04 (aliases) can now consume `_dotfiles_feature` from its gated wrapper files (finder, ghostty, jgrid).
- Plan 02 (.zshrc) will source every `shell/functions/*.zsh` via its function-glob loop — the leading-underscore helper file participates in that glob; the leading underscore is purely a naming hint.
- Phase 4 (IDNT-03) inherits the sshlist `# Per-identity SSH config display deferred to Phase 4 (IDNT-03).` marker — extend sshlist there once `_dotfiles_identity` or equivalent lands.
- Phase 7 inherits the motd config-path deferral — `motd.zsh` references `${DOTFILEDIR}/zsh/configs/motd_sysinfo.jsonc` and `${DOTFILEDIR}/zsh/configs/motd_tron.txt`; Phase 7 must update those two paths when configs/ moves to `configs/<tool>/`.

---
*Phase: 03-shell-layer-flat-content-port*
*Completed: 2026-05-14*
