#!/bin/zsh

set -e

# hidden config directory may not already exist, create it
mkdir -p "$XDG_CONFIG_HOME"

# Set up symbolic links for ZSH and Git pointing to this cloned repo
echo "Setting up symbolic links for ZSH, gitconfig, sshconfig"
ln -sf "$DOTFILEDIR"/zsh/.zshenv "$HOME"/.zshenv
ln -sf "$DOTFILEDIR"/zsh/.zprofile "$HOME"/.zprofile
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/.zlogout "$HOME"/.zlogout
ln -sf "$DOTFILEDIR"/zsh/.trippy.toml "$XDG_CONFIG_HOME"/.trippy.toml

# setup git related links
mkdir -p "$XDG_CONFIG_HOME"/git/
ln -sf "$DOTFILEDIR"/git/.gitconfig "$XDG_CONFIG_HOME"/git/config
ln -sf "$DOTFILEDIR"/git/.stCommitMsg "$XDG_CONFIG_HOME"/git/.stCommitMsg
ln -sf "$DOTFILEDIR"/git/.gitignore_global "$XDG_CONFIG_HOME"/git/.gitignore_global
mkdir -p "$XDG_CONFIG_HOME"/git/personal/
ln -sf "$DOTFILEDIR"/git/personal/.gitconfig-personal "$XDG_CONFIG_HOME"/git/personal/.gitconfig-personal

# setup SSH related links
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
