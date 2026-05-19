#!/bin/zsh

# =============================================================================
# shell/functions/_dotfiles_require_feature.zsh -- feature-gate guard helper
#
# Purpose:      Collapse the two-line `[[ "$(_dotfiles_feature X)" == "true"
#               ]] || { echo ... >&2; return 1; }` guard previously
#               duplicated in every wrapper-function alias.
# Depends on:   $_DOTFILES_FEATURES (populated by _dotfiles_feature).
# Side effects: prints "<wrapper>: feature '<X>' is disabled on this
#               machine" to stderr when the feature is off; returns 0
#               (enabled) or 1 (disabled).
#
# Arg shape:    $1 feature key (e.g. "macos-finder")
#               $2 (optional) wrapper-function name to embed in the stderr
#                  message; defaults to ${funcstack[2]} (calling function's
#                  name) so the typical call site is a single arg:
#                    function finder() {
#                      _dotfiles_require_feature macos-finder || return 1
#                      open -a Finder ./
#                    }
# =============================================================================

function _dotfiles_require_feature() {
    local feature="$1"
    local fn_name="${2:-${funcstack[2]:-${0}}}"
    [[ "$(_dotfiles_feature "$feature")" == "true" ]] && return 0
    echo "${fn_name}: feature '${feature}' is disabled on this machine" >&2
    return 1
}
