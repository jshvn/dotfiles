#!/bin/zsh

# afk func
function afk() {	# afk() will suspend the current session and lock the screen. ex: $ afk
    pmset displaysleepnow
}
