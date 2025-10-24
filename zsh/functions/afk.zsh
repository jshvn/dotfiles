#!/bin/zsh

# afk func
function afk() {	# afk() will suspend the current session and lock the screen. ex: $ afk
    autoload is-at-least
    if is-at-least 11.0 $(sw_vers -productVersion); then
        # big sur or greater
        osascript -e 'tell app "System Events" to key code 12 using {control down, command down}'
    else
        # catalina or lower
        /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
    fi
}
