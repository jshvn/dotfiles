#!/bin/zsh

# =============================================================================
# shell/functions/afk.zsh -- away-from-keyboard helper
#
# Purpose:      Trigger immediate display sleep (which engages the screen
#               lock policy: sysadminctl -screenLock, set once per machine).
# Depends on:   pmset.
# Side effects: puts the display(s) to sleep.
# =============================================================================

function afk() {    # afk() sleeps the display immediately (engages the screen lock). ex: $ afk
    pmset displaysleepnow
}
