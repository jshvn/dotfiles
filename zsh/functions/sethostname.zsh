#!/bin/zsh

# set the computer's hostname to specified name
function sethostname() {    # sethostname() will set the machine's hostname to the given string. ex: $ sethostname JWORK
    if [[ -z "${1}" ]]; then
        echo "ERROR: No hostname specified.";
        return 1;
    fi;
    sudo scutil --set ComputerName "$1"
    sudo scutil --set HostName "$1"
    sudo scutil --set LocalHostName "$1"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$1"
}