#!/bin/zsh

# When adding new symlinks, ensure any parent directories exist

set -e

echo "Setting up symbolic links for ZSH, gitconfig, sshconfig, other tool configs"

# Set up symbolic links for ZSH
ln -sf "$DOTFILEDIR"/zsh/.zshenv "$HOME"/.zshenv
ln -sf "$DOTFILEDIR"/zsh/.zprofile "$HOME"/.zprofile
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/.zlogin "$HOME"/.zlogin
ln -sf "$DOTFILEDIR"/zsh/.zlogout "$HOME"/.zlogout

# setup git related links
mkdir -p "$XDG_CONFIG_HOME"/git/
ln -sf "$DOTFILEDIR"/git/.gitconfig "$XDG_CONFIG_HOME"/git/config
ln -sf "$DOTFILEDIR"/git/.stCommitMsg "$XDG_CONFIG_HOME"/git/.stCommitMsg
ln -sf "$DOTFILEDIR"/git/.gitignore_global "$XDG_CONFIG_HOME"/git/.gitignore_global
mkdir -p "$XDG_CONFIG_HOME"/git/personal/
ln -sf "$DOTFILEDIR"/git/personal/.gitconfig-personal "$XDG_CONFIG_HOME"/git/personal/.gitconfig-personal

# setup sourcetree related links
ln -sf "$DOTFILEDIR"/git/.gitflow_export "$HOME"/.gitflow_export
ln -sf "$DOTFILEDIR"/git/.hgignore_global "$HOME"/.hgignore_global

# setup SSH related links
mkdir -p "$HOME"/.ssh/
ln -sf "$DOTFILEDIR"/ssh/configs/config "$HOME"/.ssh/config
ln -sf "$DOTFILEDIR"/ssh/configs/personal/config_personal "$HOME"/.ssh/config_personal
ln -sf "$DOTFILEDIR"/ssh/keys/id_ed25519_personal.pub "$HOME"/.ssh/id_ed25519_personal.pub

# setup SSH 1Password agent config file filtering
# https://developer.1password.com/docs/ssh/agent/config
# directory may not already exist on first run, create it if not
mkdir -p "$XDG_CONFIG_HOME"/1Password/ssh/
ln -sf "$DOTFILEDIR"/ssh/configs/agent.toml "$XDG_CONFIG_HOME"/1Password/ssh/agent.toml

# setup SSH cloudflared proxy command script
ln -sf "$DOTFILEDIR"/ssh/cloudflared.zsh "$HOME"/.ssh/cloudflared.zsh

# setup trippy (traceroute visualizer) config file
ln -sf "$DOTFILEDIR"/zsh/configs/.trippy.toml "$XDG_CONFIG_HOME"/.trippy.toml

# setup tlrc (tldr client) config file
mkdir -p "$XDG_CONFIG_HOME"/tlrc/
ln -sf "$DOTFILEDIR"/zsh/configs/tlrc.toml "$XDG_CONFIG_HOME"/tlrc/config.toml

# setup eza style config yaml file  
mkdir -p "$XDG_CONFIG_HOME"/eza/
ln -sf "$DOTFILEDIR"/zsh/styles/eza_style.yaml "$XDG_CONFIG_HOME"/eza/theme.yaml