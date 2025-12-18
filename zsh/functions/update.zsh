#!/bin/zsh

# update() will update the current dotfiles installation and dependencies
function update() {    # update() will update the current dotfiles installation and dependencies. ex: $ update
    # Save current directory
    local currentdir=$(pwd)

    # Navigate to dotfile install directory
    cd "$DOTFILEDIR"

    # Run task update (handles oh-my-zsh, tldr, antigen, profile-specific updates)
    if command -v task &> /dev/null; then
        task update
    else
        echo "Error: task not found. Run ./bootstrap.zsh to install."
        cd "$currentdir"
        return 1
    fi

    # Return to previous directory
    cd "$currentdir"
}