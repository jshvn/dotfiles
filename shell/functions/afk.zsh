#!/bin/zsh

# =============================================================================
# shell/functions/afk.zsh -- away-from-keyboard helper
#
# Purpose:      Trigger immediate display sleep (which engages the screen
#               lock policy configured via os/defaults/security.zsh).
# Depends on:   pmset.
# Side effects: puts the display(s) to sleep.
# =============================================================================

function afk() {
    pmset displaysleepnow
}
