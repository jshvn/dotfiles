#!/bin/zsh

# =============================================================================
# shell/.zlogout -- zsh login-shell logout hook
#
# Purpose:      Finalization / cleanup on login-shell exit.
# Depends on:   nothing.
# Side effects: flushes shell history via `fc -W`.
# =============================================================================

# Flush history to disk on logout.
fc -W 2>/dev/null || true
