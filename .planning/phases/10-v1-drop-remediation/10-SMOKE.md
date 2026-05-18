# Phase 10: First-Shell Smoke Procedure

**Recorded:** <date>
**Procedure run on:** <machine-name> (existing v2-cut-over machine, NOT a real fresh install)
**Result:** PASS / FAIL

## What this is

A documented smoke procedure that exercises the fresh-machine first-shell
guarantee (PORT-03). v2.1 phase 10 accepts a procedure-based satisfaction of
PORT-03 per ROADMAP P10 SC#3 and CONTEXT D-08; a real fresh-machine install is
deferred to a later milestone. The procedure runs on an existing v2-cut-over
machine after PORT-01 (the /etc/zshenv ZDOTDIR write) and PORT-02
(`task shell:validate`) have landed; an operator launches a fresh terminal and
ticks each first-shell assertion below.

## Procedure

Run on an existing v2-cut-over machine after Phase 10's PORT-01 has landed.

### Pre-step setup

1. Verify `/etc/zshenv` contains the ZDOTDIR export:
   `grep -F 'export ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv`
2. Verify `task validate` exits 0 end-to-end: `task validate; echo "exit: $?"`.
3. Verify the new `shell:validate` row appears in the validate summary.

### First-shell assertions

Launch a fresh terminal (Ghostty, Terminal.app, or `zsh -li`). The new shell MUST satisfy:

- [ ] echo "$ZDOTDIR" prints $HOME/.config/zsh (sourced from /etc/zshenv)
- [ ] echo "$DOTFILES_MACHINE" prints the active machine name (sourced from shell/.zshenv)
- [ ] The alanpeabody-derived prompt renders (user, pwd, git branch tokens visible)
- [ ] type _dotfiles_feature shows "_dotfiles_feature is a function"
- [ ] alias lists the expected ported aliases (at minimum: reload, path, ll, t)
- [ ] motd output appears (or the cache file $XDG_CACHE_HOME/dotfiles/motd.cache exists)
- [ ] No "command not found" errors during shell init

### Pass criteria

Every checkbox above must be ticked. Record date, machine, and result in the
`## Run Log` table at the bottom of this file. Note any deviations
(e.g., manually-edited `/etc/zshenv` requiring a duplicate-line review per
RESEARCH.md Landmine 3) in the Notes column.

## Run Log

| Date | Machine | Result | Notes |
|------|---------|--------|-------|
| <date> | <machine> | PASS / FAIL | <any deviations> |
