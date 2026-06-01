#!/bin/zsh

# =============================================================================
# shell/functions/_dotfiles_feature.zsh -- lazy manifest feature query
#
# Purpose:      Read $XDG_STATE_HOME/dotfiles/resolved.json once per shell
#               and cache every feature flag in $_DOTFILES_FEATURES.
#               Subsequent lookups are O(1). Returns "false" on missing/
#               unreadable resolved.json (graceful degrade for pre-install).
# Depends on:   jq; $XDG_STATE_HOME/dotfiles/resolved.json.
# Side effects: populates global associative array $_DOTFILES_FEATURES on
#               first call; sets _dotfiles_features_loaded=1.
# =============================================================================

typeset -gA _DOTFILES_FEATURES
_dotfiles_features_loaded=0

function _dotfiles_feature() {    # _dotfiles_feature() prints a manifest feature flag's value (true/false). ex: $ _dotfiles_feature one-password-ssh
    local name="$1"
    if (( ! _dotfiles_features_loaded )); then
        local resolved="${XDG_STATE_HOME}/dotfiles/resolved.json"
        if [[ -r "$resolved" ]]; then
            local jq_output jq_status=0
            jq_output=$(jq -r '.features | to_entries[] | "\(.key)=\(.value)"' "$resolved" 2>/dev/null) || jq_status=$?
            if (( jq_status != 0 )); then
                echo "_dotfiles_feature: failed to parse $resolved (every feature will read as false)" >&2
            elif [[ -n "$jq_output" ]]; then
                while IFS='=' read -r k v; do
                    _DOTFILES_FEATURES[$k]="$v"
                done <<< "$jq_output"
            fi
        fi
        _dotfiles_features_loaded=1
    fi
    echo "${_DOTFILES_FEATURES[$name]:-false}"
}
