#!/bin/zsh
set -e

# Resolve DOTFILEDIR first (needed for sourcing messages)
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# Source messaging library
source "${DOTFILEDIR}/install/messages.zsh"

header "Dotfiles Bootstrap"

# Install go-task if not present
if ! command -v task &> /dev/null; then
  info "Installing go-task..."
  
  # Determine install location based on permissions
  if [[ -w /usr/local/bin ]]; then
    INSTALL_DIR="/usr/local/bin"
  else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    export PATH="$INSTALL_DIR:$PATH"
  fi
  
  # Install Task via official install script
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b "$INSTALL_DIR"
  
  success "go-task installed to $INSTALL_DIR"
else
  info "go-task already installed"
fi

# Run task install with any passed arguments
cd "$DOTFILEDIR"
task install "$@"
