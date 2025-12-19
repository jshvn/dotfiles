#!/bin/zsh
# Dotfiles messaging library
# Source this file to get consistent messaging functions
#
# Usage:
#   source "${DOTFILEDIR}/install/messages.zsh"
#   info "This is an info message"
#   success "Operation completed"
#   warn "This might cause issues"
#   error "Something went wrong"
#
# Optional functions:
#   debug "Debug output" (only shown if DOTFILES_DEBUG=true)
#   header "Section Name" (prints a styled section header)
#   step "Doing something" (prints a step indicator)
#   check "Item passed" (prints ✓ with message)
#   cross "Item failed" (prints ✗ with message)

# Prevent double-sourcing
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1

# Color codes (ANSI for broad compatibility)
# Using \033 instead of \e for maximum portability
DOTFILES_RED='\033[0;31m'
DOTFILES_GREEN='\033[0;32m'
DOTFILES_YELLOW='\033[0;33m'
DOTFILES_BLUE='\033[0;34m'
DOTFILES_CYAN='\033[0;36m'
DOTFILES_BOLD='\033[1m'
DOTFILES_NC='\033[0m'

# Core messaging functions
function info() {
    echo -e "${DOTFILES_BLUE}[INFO]${DOTFILES_NC} $*"
}

function success() {
    echo -e "${DOTFILES_GREEN}[SUCCESS]${DOTFILES_NC} $*"
}

function warn() {
    echo -e "${DOTFILES_YELLOW}[WARN]${DOTFILES_NC} $*"
}

function error() {
    echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2
}

# Extended messaging functions
function debug() {
    [[ "$DOTFILES_DEBUG" == "true" ]] && echo -e "${DOTFILES_CYAN}[DEBUG]${DOTFILES_NC} $*"
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
