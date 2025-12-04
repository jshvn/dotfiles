#!/bin/zsh

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

# Execute and ensure ZDOTDIR is set system-wide
ensure_zdotdir_in_etc_zshenv

unset ensure_zdotdir_in_etc_zshenv