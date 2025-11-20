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
safe_link "$DOTFILEDIR"/zsh/.zshenv "$HOME"/.zshenv
safe_link "$DOTFILEDIR"/zsh/.zprofile "$HOME"/.zprofile
safe_link "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
safe_link "$DOTFILEDIR"/zsh/.zlogin "$HOME"/.zlogin
safe_link "$DOTFILEDIR"/zsh/.zlogout "$HOME"/.zlogout

# setup git related links
safe_link "$DOTFILEDIR"/git/.gitconfig "$XDG_CONFIG_HOME"/git/config
safe_link "$DOTFILEDIR"/git/.stCommitMsg "$XDG_CONFIG_HOME"/git/.stCommitMsg
safe_link "$DOTFILEDIR"/git/.gitignore_global "$XDG_CONFIG_HOME"/git/.gitignore_global
safe_link "$DOTFILEDIR"/git/personal/.gitconfig-personal "$XDG_CONFIG_HOME"/git/personal/.gitconfig-personal

# setup sourcetree related links
safe_link "$DOTFILEDIR"/git/.gitflow_export "$HOME"/.gitflow_export
safe_link "$DOTFILEDIR"/git/.hgignore_global "$HOME"/.hgignore_global

# setup SSH related links
safe_link "$DOTFILEDIR"/ssh/configs/config "$HOME"/.ssh/config
safe_link "$DOTFILEDIR"/ssh/configs/personal/config_personal "$HOME"/.ssh/config_personal
safe_link "$DOTFILEDIR"/ssh/keys/id_ed25519_personal.pub "$HOME"/.ssh/id_ed25519_personal.pub

# setup SSH 1Password agent config file filtering
# https://developer.1password.com/docs/ssh/agent/config
safe_link "$DOTFILEDIR"/ssh/configs/agent.toml "$XDG_CONFIG_HOME"/1Password/ssh/agent.toml

# setup SSH cloudflared proxy command script
safe_link "$DOTFILEDIR"/ssh/cloudflared.zsh "$HOME"/.ssh/cloudflared.zsh

# setup trippy (traceroute visualizer) config file
safe_link "$DOTFILEDIR"/zsh/configs/.trippy.toml "$XDG_CONFIG_HOME"/.trippy.toml

# setup tlrc (tldr client) config file
safe_link "$DOTFILEDIR"/zsh/configs/tlrc.toml "$XDG_CONFIG_HOME"/tlrc/config.toml

# setup eza style config yaml file  
safe_link "$DOTFILEDIR"/zsh/styles/eza_style.yaml "$XDG_CONFIG_HOME"/eza/theme.yaml

unset -f safe_link