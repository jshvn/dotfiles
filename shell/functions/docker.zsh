#!/bin/zsh

# =============================================================================
# shell/functions/docker.zsh -- docker CLI wrapper
#
# Purpose:      Override `docker ps` to a tighter columns layout, and add
#               `docker <shell> <container>` shortcut for opening a shell
#               inside a running container.
# Depends on:   docker.
# Side effects: shadows the `docker` command for the interactive shell.
# =============================================================================

function docker() {
    if [[ "$1" == "ps" ]]; then
        shift
        command docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" "$@"
    elif [[ "$1" == "bash" || "$1" == "sh" || "$1" == "csh" || "$1" == "dash" || "$1" == "ksh" || "$1" == "tcsh" || "$1" == "zsh" ]]; then
        local shell="$1"
        shift
        if [[ -z "${1}" ]]; then
            echo "ERROR: No container specified"
            echo "Running containers:"
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
            return 1
        fi
        command docker exec -ti "$1" "/bin/$shell"
    else
        command docker "$@"
    fi
}
