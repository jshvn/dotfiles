#!/bin/zsh

# This script exists to ensure we are using the ZSH shell that is installed by Homebrew

function ensure_zbrewshell_in_etc_shells() {
  local zsh_brew_shell="$HOMEBREW_PREFIX/bin/zsh"
  
  if ! grep -qxF "$zsh_brew_shell" /etc/shells; then
      echo "Homebrew-installed ZSH is not currently present in /etc/shells, adding it now..."
      echo "$zsh_brew_shell" | sudo tee -a /etc/shells
  else
      echo "Homebrew-installed ZSH is already present in /etc/shells."
  fi
}

ensure_zbrewshell_in_etc_shells