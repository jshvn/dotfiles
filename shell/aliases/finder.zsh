#!/bin/zsh

# =============================================================================
# shell/aliases/finder.zsh -- Finder GUI wrappers
#
# Purpose:      Finder GUI wrappers (finder / findershow / finderhide);
#               gated on features.macos-finder via wrapper-function pattern
#               so calls on server / non-GUI machines surface a stderr
#               message instead of silently no-opping.
# Depends on:   shell/functions/_dotfiles_require_feature.zsh.
# Side effects: defines functions finder / findershow / finderhide;
#               feature-gated `open -a Finder` + `defaults write` +
#               `killall Finder` on macos-finder=true machines.
# =============================================================================

function finder() {
    _dotfiles_require_feature macos-finder || return 1
    open -a Finder ./
}

function findershow() {
    _dotfiles_require_feature macos-finder || return 1
    defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder
}

function finderhide() {
    _dotfiles_require_feature macos-finder || return 1
    defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder
}
