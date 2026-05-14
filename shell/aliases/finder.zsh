#!/bin/zsh
# shell/aliases/finder.zsh -- Finder GUI aliases.
#
# Purpose: Finder GUI wrappers gated on features.macos-finder via
# _dotfiles_feature per D-07. Replaces v1 zsh/aliases/common/general.zsh:27-31
# (the three Finder aliases that were always loaded in v1's common bucket but
# break on non-GUI machines).
#
# Why wrapper-function (D-07) rather than source-time gate (D-08): three
# discrete aliases. The wrapper-function gate gives a helpful stderr message
# when called on a server / non-GUI machine, instead of silently no-opping.

function finder() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "finder: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    open -a Finder ./
}

function findershow() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "findershow: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder
}

function finderhide() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "finderhide: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder
}
