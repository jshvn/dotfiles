#!/bin/zsh

# =============================================================================
# shell/functions/timezsh.zsh -- zsh startup profiler
#
# Purpose:      Run an interactive zsh four times with /usr/bin/time for an
#               average startup duration, then once with zsh/zprof for the
#               function-level breakdown.
# Depends on:   /usr/bin/time, zsh/zprof.
# Side effects: spawns short-lived interactive zsh subshells; stdout only.
# =============================================================================

function timezsh() {
    # first run shell startup 4 times with /usr/bin/time to get average time
    local shell=${1-$SHELL}
    for i in $(seq 1 4); do /usr/bin/time "$shell" -i -c exit; done

    # now run with zprof to get detailed profiling info
    "$shell" -i -c 'zmodload zsh/zprof; source $ZDOTDIR/.zshrc; zprof'
}