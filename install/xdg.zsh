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

# set ZDOTDIR 
ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# -----------------------------------------------------------------------------
# Function: ensure_zdotdir_in_etc_zshenv
# Purpose: Ensure /etc/zshenv exists and contains ZDOTDIR export
# -----------------------------------------------------------------------------
function ensure_zdotdir_in_etc_zshenv() {
  local etc_zshenv="/etc/zshenv"
  local zdotdir_export='export ZDOTDIR='"$ZDOTDIR"
  
  if [[ ! -f "$etc_zshenv" ]]; then
    echo "Creating $etc_zshenv with ZDOTDIR export..."
    echo "$zdotdir_export" | sudo tee "$etc_zshenv" > /dev/null
  else
    # File exists, check if the export is already present
    if grep -qF "$zdotdir_export" "$etc_zshenv"; then
      echo "$etc_zshenv already contains ZDOTDIR export."
    else
      echo "Adding ZDOTDIR export to existing $etc_zshenv..."
      echo "$zdotdir_export" | sudo tee -a "$etc_zshenv" > /dev/null
    fi
  fi
}

# Execute the function
ensure_zdotdir_in_etc_zshenv

unset ensure_zdotdir_in_etc_zshenv

echo "XDG Base Directories setup!"