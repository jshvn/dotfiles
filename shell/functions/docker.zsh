#!/bin/zsh

# docker wrapper to customize subcommands
function docker() { # docker() will customize the functionality of docker. ex: $ docker bash
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
