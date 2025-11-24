#!/bin/zsh

# Function to create parent directory and symlink
# Usage: safe_link <source> <target>
# Creates parent directory of target if it doesn't exist, then creates symlink
function safe_link() {
  local source="$1"
  local target="$2"
  
  if [[ -z "$source" || -z "$target" ]]; then
    echo "Error: safe_link requires both source and target arguments"
    return 1
  fi
  
  # Create parent directory if it doesn't exist
  local target_dir="$(dirname "$target")"
  if [[ ! -d "$target_dir" ]]; then
    mkdir -p "$target_dir"
  fi
  
  # Create symlink (force overwrite if exists)
  ln -sf "$source" "$target"
}

set -e

echo "Setting up symbolic links for ZSH, gitconfig, sshconfig, other tool configs"

# Set up symbolic links for ZSH
safe_link "$DOTFILEDIR"/zsh/.zshenv "$ZDOTDIR"/.zshenv
safe_link "$DOTFILEDIR"/zsh/.zprofile "$ZDOTDIR"/.zprofile
safe_link "$DOTFILEDIR"/zsh/.zshrc "$ZDOTDIR"/.zshrc
safe_link "$DOTFILEDIR"/zsh/.zlogin "$ZDOTDIR"/.zlogin
safe_link "$DOTFILEDIR"/zsh/.zlogout "$ZDOTDIR"/.zlogout

# setup git related links
safe_link "$DOTFILEDIR"/git/config "$XDG_CONFIG_HOME"/git/config
safe_link "$DOTFILEDIR"/git/ignore "$XDG_CONFIG_HOME"/git/ignore
safe_link "$DOTFILEDIR"/git/personal/config-personal "$XDG_CONFIG_HOME"/git/personal/config-personal
safe_link "$DOTFILEDIR"/git/work/config-work "$XDG_CONFIG_HOME"/git/work/config-work

# setup SSH related links
safe_link "$DOTFILEDIR"/ssh/configs/config "$HOME"/.ssh/config
safe_link "$DOTFILEDIR"/ssh/configs/personal/config_personal "$HOME"/.ssh/config_personal
safe_link "$DOTFILEDIR"/ssh/keys/id_ed25519_personal.pub "$HOME"/.ssh/id_ed25519_personal.pub

# setup SSH cloudflared proxy command script
safe_link "$DOTFILEDIR"/ssh/cloudflared.zsh "$HOME"/.ssh/cloudflared.zsh

# setup SSH 1Password agent config file filtering
# https://developer.1password.com/docs/ssh/agent/config
safe_link "$DOTFILEDIR"/ssh/configs/agent.toml "$XDG_CONFIG_HOME"/1Password/ssh/agent.toml

# setup trippy (traceroute visualizer) config file
safe_link "$DOTFILEDIR"/zsh/configs/trippy.toml "$XDG_CONFIG_HOME"/trippy/trippy.toml

# setup tlrc (tldr client) config file
safe_link "$DOTFILEDIR"/zsh/configs/tlrc.toml "$XDG_CONFIG_HOME"/tlrc/config.toml

# setup eza style config yaml file  
safe_link "$DOTFILEDIR"/zsh/styles/eza_style.yaml "$XDG_CONFIG_HOME"/eza/theme.yaml

# setup conda condarc file
safe_link "$DOTFILEDIR"/zsh/configs/condarc "$XDG_CONFIG_HOME"/conda/condarc

# setup ghostty config file
safe_link "$DOTFILEDIR"/zsh/configs/ghostty "$XDG_CONFIG_HOME"/ghostty/config

unset -f safe_link