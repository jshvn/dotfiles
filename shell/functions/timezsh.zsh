#!/bin/zsh

# profile zsh startup time
function timezsh() {    # timezsh() will time how long it takes to start an interactive zsh shell. ex: $ timezsh
    # first run shell startup 4 times with /usr/bin/time to get average time
    local shell=${1-$SHELL}
    for i in $(seq 1 4); do /usr/bin/time "$shell" -i -c exit; done

    # now run with zprof to get detailed profiling info
    "$shell" -i -c 'zmodload zsh/zprof; source $ZDOTDIR/.zshrc; zprof'
}