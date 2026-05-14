#!/bin/zsh
# -----------------------------------------------------------------------------
# shell/functions/_dotfiles_feature.zsh -- lazy manifest feature query (D-06).
#
# Purpose: Reads $XDG_STATE_HOME/dotfiles/resolved.json once per shell and
#          caches every feature flag in the $_DOTFILES_FEATURES associative
#          array. Subsequent lookups are O(1).
#
# Callers: shell/.zshrc sources this via its function-glob loop (the leading
#          underscore is purely a naming hint — the glob still picks it up).
#          shell/aliases/finder.zsh, ghostty.zsh, and jgrid.zsh (Phase 3
#          Plan 04) call _dotfiles_feature from inside their wrapper
#          functions and source-time gates.
#
# Reads:   $XDG_STATE_HOME/dotfiles/resolved.json (compiled by the
#          manifest resolver in install/resolver.zsh).
#
# Side effects: Populates the global associative array $_DOTFILES_FEATURES
#               on first call and sets _dotfiles_features_loaded=1.
#
# Graceful degrade: If resolved.json is missing or unreadable, every lookup
#                   returns "false". This keeps gated wrappers safe on a
#                   pre-install or partially-bootstrapped machine.
#
# Usage:   [[ "$(_dotfiles_feature macos-finder)" == "true" ]]
# -----------------------------------------------------------------------------

typeset -gA _DOTFILES_FEATURES
_dotfiles_features_loaded=0

function _dotfiles_feature() {
    local name="$1"
    if (( ! _dotfiles_features_loaded )); then
        local resolved="${XDG_STATE_HOME}/dotfiles/resolved.json"
        if [[ -r "$resolved" ]]; then
            while IFS='=' read -r k v; do
                _DOTFILES_FEATURES[$k]="$v"
            done < <(jq -r '.features | to_entries[] | "\(.key)=\(.value)"' "$resolved" 2>/dev/null)
        fi
        _dotfiles_features_loaded=1
    fi
    echo "${_DOTFILES_FEATURES[$name]:-false}"
}
