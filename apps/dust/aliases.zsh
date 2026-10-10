#!/bin/zsh

# =============================================================================
# shell/aliases/dust.zsh -- dust with the File Provider folders excluded
#
# Purpose:      Every `dust` invocation, from any CWD, skips
#               ~/Library/CloudStorage (Dropbox, Proton Drive) and
#               ~/Library/Mobile Documents (iCloud Drive). Those are File
#               Provider mounts: each stat round-trips through the provider
#               extension, so a walk into them takes minutes. dust's config
#               file has no ignore-directory key, hence an alias; display
#               defaults live in configs/dust/config.toml.
# Depends on:   dust, $HOME.
# Side effects: defines alias `dust`.
# =============================================================================

alias dust='dust -X "$HOME/Library/CloudStorage" -X "$HOME/Library/Mobile Documents"'
