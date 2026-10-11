# =============================================================================
# apps/firefox/env.zsh -- login-shell environment for Firefox
#
# Purpose:      Make Firefox the browser that shell tools open. Linked into
#               $XDG_STATE_HOME/dotfiles/env.d/ by the switch when the app is
#               on, and sourced from there by shell/.zprofile.
# Depends on:   the firefox cask at /Applications/Firefox.app.
# Side effects: exports BROWSER.
# =============================================================================

export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"
