#!/bin/zsh

# =============================================================================
# shell/functions/sethostname.zsh -- interactive hostname rename wrapper
#
# Purpose:      Sourced-by-zshrc thin wrapper around os/hostname.zsh that
#               sets the system hostname AND writes the per-machine state
#               file at $XDG_STATE_HOME/dotfiles/hostname. After running,
#               the next `task install` reports the hostname step as
#               up-to-date.
# Depends on:   os/hostname.zsh; install/messages.zsh; sudo (for the three
#               scutil writes inside apply_hostname).
# Side effects: writes $XDG_STATE_HOME/dotfiles/hostname (atomic via mktemp
#               + mv inside write_hostname_state_file); runs three sudo
#               commands via apply_hostname (ComputerName, HostName,
#               LocalHostName).
# =============================================================================

# No `set -euo pipefail` -- this file is sourced by interactive zsh
# (via the function-loader in shell/.zshrc). Setting -e at file scope
# would propagate into the parent interactive shell and abort the session
# on any subsequent command non-zero exit. The function body uses explicit
# `return $?` to propagate failures from apply_hostname / write_hostname_
# state_file. Same convention as the other banner-bearing function files
# (_dotfiles_feature.zsh, _dotfiles_require_feature.zsh).

function sethostname() {    # sethostname() will set the machine's hostname to the given string. ex: $ sethostname JWORK
    local name="${1:-}"

    # Locate os/hostname.zsh via the three-tier fallback:
    #   1. $DOTFILEDIR exported by the caller (task hostname:* heredoc, or
    #      an explicit export in .zshrc / .zprofile);
    #   2. derive from this file's own sourced path -- ${(%):-%N} expands
    #      to the path of the currently sourced file; `:A:h` resolves to
    #      its absolute parent directory. repo_root is then ../..
    #      (shell/functions -> shell -> repo root);
    #   3. fall back to the canonical XDG_CONFIG_HOME dotfiles install
    #      location.
    local lib=""
    if [[ -n "${DOTFILEDIR:-}" && -f "${DOTFILEDIR}/os/hostname.zsh" ]]; then
        lib="${DOTFILEDIR}/os/hostname.zsh"
    else
        local self_dir="${${(%):-%N}:A:h}"
        local repo_root="${self_dir:h:h}"
        if [[ -f "${repo_root}/os/hostname.zsh" ]]; then
            lib="${repo_root}/os/hostname.zsh"
            export DOTFILEDIR="${repo_root}"
        elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/os/hostname.zsh" ]]; then
            lib="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/os/hostname.zsh"
            export DOTFILEDIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
        fi
    fi

    if [[ -z "$lib" ]]; then
        echo "sethostname: cannot locate os/hostname.zsh (export DOTFILEDIR)" >&2
        return 1
    fi

    source "$lib"
    write_hostname_state_file "$name" || return $?
    apply_hostname            "$name" || return $?
}
