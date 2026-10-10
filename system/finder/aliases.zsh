#!/bin/zsh

# =============================================================================
# system/finder/aliases.zsh -- Finder GUI wrappers
#
# Purpose:      Finder GUI wrappers (finder / findershow / finderhide).
#               Linked into aliases.d by the switch when
#               dotfiles.system.finder is on; absent otherwise.
# Depends on:   Finder; defaults.
# Side effects: defines functions finder / findershow / finderhide;
#               `open -a Finder`, `defaults write com.apple.finder
#               AppleShowAllFiles`, `killall Finder`.
# =============================================================================

function finder() {
    open -a Finder ./
}

function findershow() {
    defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder
}

function finderhide() {
    defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder
}
