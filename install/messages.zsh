#!/bin/zsh

# =============================================================================
# install/messages.zsh -- shared messaging library
#
# Purpose:      Consistent ANSI-coloured info/success/warn/error/debug/
#               header/step/check/cross output for all install + task scripts.
# Depends on:   nothing.
# Side effects: defines DOTFILES_{RED,GREEN,YELLOW,BLUE,CYAN,BOLD,NC}
#               globals; defines info/success/warn/error/debug/header/step/
#               check/cross functions.
# =============================================================================

# Safe to source under `set -u`: the double-source guard uses the `:-`
# default expansion so referencing the variable when unset returns "" rather
# than aborting the caller. Callers MUST NOT pre-initialize the guard.
[[ -n "${DOTFILES_MESSAGES_LOADED:-}" ]] && return 0
DOTFILES_MESSAGES_LOADED=1

# ANSI color codes (\033 for maximum portability).
DOTFILES_RED='\033[0;31m'
DOTFILES_GREEN='\033[0;32m'
DOTFILES_YELLOW='\033[0;33m'
DOTFILES_BLUE='\033[0;34m'
DOTFILES_CYAN='\033[0;36m'
DOTFILES_BOLD='\033[1m'
DOTFILES_NC='\033[0m'

function info() {
    echo -e "${DOTFILES_BLUE}[INFO]${DOTFILES_NC} $*"
}

function success() {
    echo -e "${DOTFILES_GREEN}[SUCCESS]${DOTFILES_NC} $*"
}

function warn() {
    echo -e "${DOTFILES_YELLOW}[WARN]${DOTFILES_NC} $*" >&2
}

function error() {
    echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2
}

function debug() {
    [[ "${DOTFILES_DEBUG:-}" == "true" ]] && echo -e "${DOTFILES_CYAN}[DEBUG]${DOTFILES_NC} $*"
}

function header() {
    echo ""
    echo -e "${DOTFILES_GREEN}${DOTFILES_BOLD}── $* ──${DOTFILES_NC}"
}

function step() {
    echo -e "${DOTFILES_BLUE}→${DOTFILES_NC} $*"
}

function check() {
    echo -e "${DOTFILES_GREEN}✓${DOTFILES_NC} $*"
}

function cross() {
    echo -e "${DOTFILES_RED}✗${DOTFILES_NC} $*"
}
