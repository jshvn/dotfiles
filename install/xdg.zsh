#!/bin/zsh

# -----------------------------------------------------------------------------
# xdg.zsh — Ensure XDG Base Directories exist
#
# Why this file exists:
# - Create once, early: we create the standard XDG directories during install so
#   subsequent steps (symlinks, configs, tools) can safely target them.
# - Idempotent and safe: mkdir -p avoids errors if directories already exist.
#
# Spec: https://specifications.freedesktop.org/basedir/latest/
# -----------------------------------------------------------------------------

echo "Ensuring XDG Base Directories exist..."

# Respect existing environment with sensible defaults if unset
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

mkdir -p "$XDG_CONFIG_HOME" \
         "$XDG_DATA_HOME" \
         "$XDG_STATE_HOME" \
         "$XDG_CACHE_HOME"
