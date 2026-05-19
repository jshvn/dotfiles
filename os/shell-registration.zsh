#!/bin/zsh

# =============================================================================
# os/shell-registration.zsh -- register Homebrew zsh as the login shell
#
# Purpose:      Ensure $BREW_ZSH is listed in /etc/shells, then chsh the
#               current user to that shell. Idempotent. Always-on for every
#               macOS machine (no feature gate).
# Depends on:   install/messages.zsh; $DOTFILEDIR + $BREW_ZSH exported by
#               caller (taskfiles/macos.yml install-shell task heredoc).
# Side effects: may append a line to /etc/shells via `sudo tee -a`; may
#               invoke `chsh -s` to change the user's registered login
#               shell. Both no-op on a converged machine.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:shell' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# Mandatory parameter assertion -- the structural contract on the script
# side. The caller must export BREW_ZSH before sourcing; without it, this
# `:?` exits non-zero with an explanatory message rather than silently
# proceeding with an unset variable.
: "${BREW_ZSH:?BREW_ZSH must be set by the caller}"

apply_shell_registration() {
  if ! grep -qxF "$BREW_ZSH" /etc/shells; then
    # info BEFORE sudo so the prompt is contextual.
    info "Adding Homebrew zsh to /etc/shells..."
    echo "$BREW_ZSH" | sudo tee -a /etc/shells > /dev/null
    success "Homebrew zsh added to /etc/shells"
  fi
  # Read the REGISTERED login shell from Directory Services -- NOT the
  # currently-running shell ($SHELL). $SHELL reflects the parent process;
  # dscl reads the actual user-record default. head -n 1 is cheap insurance
  # against future dscl output variance.
  local current_shell
  current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  if [[ "$current_shell" != "$BREW_ZSH" ]]; then
    info "Changing default shell from $current_shell to $BREW_ZSH..."
    # /etc/shells append MUST happen before chsh: macOS chsh validates the
    # requested target against /etc/shells and refuses non-listed paths.
    chsh -s "$BREW_ZSH" || { error "chsh failed; run manually: chsh -s $BREW_ZSH"; exit 1; }
  fi
}

verify_shell_registration() {
  local failed=0 current_shell
  if grep -qxF "$BREW_ZSH" /etc/shells; then
    check "shell.brew-zsh-in-etc-shells"
  else
    cross "shell.brew-zsh-not-in-etc-shells (expected: $BREW_ZSH)"
    failed=1
  fi
  current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  if [[ "$current_shell" == "$BREW_ZSH" ]]; then
    check "shell.user-default = $BREW_ZSH"
  else
    cross "shell.user-default: expected '$BREW_ZSH', got '$current_shell'"
    failed=1
  fi
  return $failed
}
