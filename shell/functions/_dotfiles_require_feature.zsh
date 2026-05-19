#!/bin/zsh
# -----------------------------------------------------------------------------
# shell/functions/_dotfiles_require_feature.zsh -- feature-gate guard for
# wrapper-function aliases (D-07 Class B helper).
#
# Purpose: Collapses the two-line `[[ "$(_dotfiles_feature X)" == "true" ]] ||
#          { echo "Y: feature 'X' is disabled on this machine" >&2; return 1; }`
#          guard that previously appeared in every D-07 wrapper-function alias
#          (REVW-04 / D-09 rule-of-three; 4 sites extracted in Plan 13-04).
#
# Callers: shell/aliases/finder.zsh (finder / findershow / finderhide) and
#          shell/aliases/ghostty.zsh (g). Each wrapper's first line becomes
#          `_dotfiles_require_feature <feature> || return 1`.
#
# Reads:   $_DOTFILES_FEATURES (populated by _dotfiles_feature on first call).
#
# Side effects: prints a one-line "<wrapper>: feature '<X>' is disabled on
#               this machine" message to stderr when the feature is off.
#               Returns 0 when enabled, 1 when disabled.
#
# Arg shape:
#   $1 (required)  -- feature key (e.g. "macos-finder", "ghostty")
#   $2 (optional)  -- wrapper-function name to embed in the stderr message.
#                      Defaults to ${funcstack[2]} (the calling function's
#                      name) so the typical call site is a single arg:
#                        function finder() {
#                          _dotfiles_require_feature macos-finder || return 1
#                          open -a Finder ./
#                        }
#
# Class: D-08 Class B (private internal helper; safe to extract / refactor).
#        Interactive D-08 Class A wrappers that call it are preserved per the
#        existing allowlist.
# -----------------------------------------------------------------------------

function _dotfiles_require_feature() {
    local feature="$1"
    local fn_name="${2:-${funcstack[2]:-${0}}}"
    [[ "$(_dotfiles_feature "$feature")" == "true" ]] && return 0
    echo "${fn_name}: feature '${feature}' is disabled on this machine" >&2
    return 1
}
