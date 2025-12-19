#!/bin/zsh

# task wrapper for go-task
# Filters profile-specific tasks from task list output
# Profile names are dynamically sourced from taskfiles/profile.yml VALID_PROFILES
# Use profile:install, profile:brew, profile:links instead
function task() {    # task() wraps go-task and filters profile-specific tasks from list output. ex: $ task
    local task_bin
    task_bin="$(command -v task)"
    
    if [[ -z "$task_bin" ]]; then
        echo "ERROR: task binary not found"
        return 1
    fi
    
    # Check if we're running a list command (no args, "default", or "--list")
    if [[ $# -eq 0 || "$1" == "default" || "$1" == "--list" || "$1" == "-l" ]]; then
        # Extract VALID_PROFILES from profile.yml and build regex pattern
        local profile_yml="${DOTFILEDIR:-$HOME/Git/personal/dotfiles}/taskfiles/profile.yml"
        local profiles_pattern=""
        if [[ -f "$profile_yml" ]]; then
            # Parse VALID_PROFILES line, extract quoted value, replace spaces with |
            profiles_pattern=$(grep -E '^\s*VALID_PROFILES:' "$profile_yml" | sed -E 's/.*"([^"]+)".*/\1/' | tr ' ' '|')
        fi
        
        # Run task with PTY preserved via script to maintain color output
        # Then filter out profile-specific tasks
        # The regex accounts for ANSI color escape codes in the output
        script -q /dev/null "$task_bin" --list --color 2>&1 | grep -v -E "^\x1b\[33m\* \x1b\[0m\x1b\[32m($profiles_pattern):"
    else
        # Pass through to the real task binary
        command "$task_bin" "$@"
    fi
}
