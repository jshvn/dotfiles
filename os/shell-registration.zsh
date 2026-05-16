#!/bin/zsh
# os/shell-registration.zsh -- Register Homebrew zsh as the login shell.
#
# Purpose:
#   Ensure $BREW_ZSH is listed in /etc/shells, then chsh the current user
#   to that shell. Idempotent: every step checks the desired state first
#   and only acts on drift. Always-on for every macOS machine (D-03 --
#   no feature gate). Top-level under `os/` (NOT inside `os/defaults/`)
#   per OSCF-01 wording and CONTEXT D-03.
#
# Caller:
#   taskfiles/macos.yml -- macos:shell task (Plan 03). The task injects
#   BREW_ZSH as an exported env var from the {{.BREW_ZSH}} task-level
#   template var (`{{.HOMEBREW_PREFIX}}/bin/zsh`), then sources this file
#   and invokes apply_shell_registration (cmds:); the task's status: block
#   uses the same {{.BREW_ZSH}} template var directly for the idempotency
#   check (LINT-02 compliance).
#
# Side effects:
#   apply_shell_registration may append a line to /etc/shells via `sudo
#   tee -a` (an explanatory `info` message prints BEFORE sudo runs so the
#   prompt is contextual -- RESEARCH Pitfall 7) and may invoke `chsh -s`
#   to change the current user's registered login shell. Both steps are
#   no-ops on a converged machine.
#   verify_shell_registration is unprivileged and read-only.
#
#   /etc/shells append MUST happen before chsh (RESEARCH Pitfall 8):
#   macOS chsh validates the requested target against /etc/shells and
#   refuses non-listed paths.
#
# Bug-class structural fix:
#   v1 taskfiles/macos.yml lines 144-146 evaluated `grep -qxF "$BREW_ZSH"
#   /etc/shells` in the task `status:` block; $BREW_ZSH was unset in the
#   status-eval shell so the check always failed and the task re-applied
#   on every install. See .planning/codebase/CONCERNS.md lines 15-19.
#   The v2 fix lives on two sides: this script body uses $BREW_ZSH (legal
#   inside a script body), AND Plan 03's macos:shell task `status:` block
#   uses {{.BREW_ZSH}} (template var, resolved at task-graph build time --
#   always set; enforced by LINT-02). LINT-02 prevents the bug class from
#   re-emerging on the producer side.
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06).
#   Expects $DOTFILEDIR and $BREW_ZSH to be exported by the caller. The
#   `:?` parameter assertion on BREW_ZSH is the mandatory contract that
#   prevents the v1 bug class from re-emerging at the script layer too.

set -euo pipefail

# messages.zsh references a bare $DOTFILES_MESSAGES_LOADED in its double-source
# guard; under set -u that would abort. Pre-initialize the guard variable and
# the caller-supplied DOTFILEDIR var so this script is safe to source from a
# `set -euo pipefail` taskfile heredoc (matches install/resolver.zsh +
# install/compose-brewfile.zsh + install/cutover-gate.zsh pattern).
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:shell' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi

# Mandatory parameter assertion -- the structural-fix contract on the
# script side. The macos:shell task heredoc must export BREW_ZSH=
# "{{.BREW_ZSH}}" before sourcing this file; sourcing without BREW_ZSH
# set exits non-zero with an explanatory message rather than silently
# proceeding with an unset variable.
: "${BREW_ZSH:?BREW_ZSH must be set by the caller}"

apply_shell_registration() {
  if ! grep -qxF "$BREW_ZSH" /etc/shells; then
    info "Adding Homebrew zsh to /etc/shells..."
    echo "$BREW_ZSH" | sudo tee -a /etc/shells > /dev/null
    success "Homebrew zsh added to /etc/shells"
  fi
  # Read the REGISTERED login shell from Directory Services -- not the
  # currently-running shell ($SHELL). $SHELL reflects the parent process;
  # dscl reads the actual user-record default (RESEARCH Don't-Hand-Roll).
  # head -n 1 is cheap insurance against future dscl output variance
  # (RESEARCH Pitfall 4).
  local current_shell
  current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  if [[ "$current_shell" != "$BREW_ZSH" ]]; then
    info "Changing default shell from $current_shell to $BREW_ZSH..."
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
  current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  if [[ "$current_shell" == "$BREW_ZSH" ]]; then
    check "shell.user-default = $BREW_ZSH"
  else
    cross "shell.user-default: expected '$BREW_ZSH', got '$current_shell'"
    failed=1
  fi
  return $failed
}
