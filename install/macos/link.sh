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

# Set up symbolic links for ZSH and Git pointing to this cloned repo
echo "Setting up symbolic links for ZSH, gitconfig, sshconfig"
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/aliases.zsh "$HOME"/.aliases.zsh
ln -sf "$DOTFILEDIR"/zsh/functions.zsh "$HOME"/.functions.zsh

# setup git related links
ln -sf "$DOTFILEDIR"/git/.gitconfig "$HOME"/.gitconfig
ln -sf "$DOTFILEDIR"/git/.gitignore_global "$HOME"/.gitignore_global
ln -sf "$DOTFILEDIR"/git/personal/.gitconfig-personal "$HOME"/.gitconfig-personal
ln -sf "$DOTFILEDIR"/git/work/.gitconfig-work "$HOME"/.gitconfig-work

# setup SSH related links
ln -sf "$DOTFILEDIR"/ssh/.ssh/configs/config "$HOME"/.ssh/config
ln -sf "$DOTFILEDIR"/ssh/.ssh/configs/config_personal "$HOME"/.ssh/config_personal
ln -sf "$DOTFILEDIR"/ssh/.ssh/configs/config_adobe "$HOME"/.ssh/config_adobe
ln -sf "$DOTFILEDIR"/ssh/.ssh/configs/config_dcds "$HOME"/.ssh/config_dcds
ln -sf "$DOTFILEDIR"/ssh/.ssh/configs/config_3di "$HOME"/.ssh/config_3di
ln -sf "$DOTFILEDIR"/ssh/.ssh/keys/id_ed25519_personal.pub "$HOME"/.ssh/id_ed25519_personal.pub
ln -sf "$DOTFILEDIR"/ssh/.ssh/keys/id_rsa_work.pub "$HOME"/.ssh/id_rsa_work.pub
