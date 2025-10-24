#!/usr/bin/env bash

set -e

if [[ -z $DOTFILEDIR ]]; then
  # Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  INSTALLFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  DOTFILEDIR="$(dirname "$(dirname "$INSTALLFILEDIR")")"
fi

# hidden config directory may not already exist, create it
mkdir -p "$HOME"/.config/

# Set up symbolic links for ZSH and Git pointing to this cloned repo
echo "Setting up symbolic links for ZSH, gitconfig, sshconfig"
ln -sf "$DOTFILEDIR"/zsh/.zprofile "$HOME"/.zprofile
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/aliases.zsh "$HOME"/.config/.aliases.zsh
ln -sf "$DOTFILEDIR"/zsh/functions.zsh "$HOME"/.config/.functions.zsh
ln -sf "$DOTFILEDIR"/zsh/.trippy.toml "$HOME"/.config/.trippy.toml

# setup git related links
mkdir -p "$HOME"/.config/git/
ln -sf "$DOTFILEDIR"/git/.gitconfig "$HOME"/.config/git/config
ln -sf "$DOTFILEDIR"/git/.stCommitMsg "$HOME"/.config/git/.stCommitMsg
ln -sf "$DOTFILEDIR"/git/.gitignore_global "$HOME"/.config/git/.gitignore_global
mkdir -p "$HOME"/.config/git/personal/
ln -sf "$DOTFILEDIR"/git/personal/.gitconfig-personal "$HOME"/.config/git/personal/.gitconfig-personal

# setup SSH related links
ln -sf "$DOTFILEDIR"/ssh/configs/config "$HOME"/.ssh/config
ln -sf "$DOTFILEDIR"/ssh/configs/personal/config_personal "$HOME"/.ssh/config_personal
ln -sf "$DOTFILEDIR"/ssh/keys/id_ed25519_personal.pub "$HOME"/.ssh/id_ed25519_personal.pub

# setup SSH 1Password agent config file filtering
# https://developer.1password.com/docs/ssh/agent/config
# directory may not already exist on first run, create it if not
mkdir -p "$HOME"/.config/1Password/ssh/
ln -sf "$DOTFILEDIR"/ssh/configs/agent.toml "$HOME"/.config/1Password/ssh/agent.toml

# setup SSH platform detection
ln -sf "$DOTFILEDIR"/ssh/configs/platform.sh "$HOME"/.ssh/platform.sh
