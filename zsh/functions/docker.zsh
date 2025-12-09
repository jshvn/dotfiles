#!/bin/zsh

# docker wrapper to customize subcommands
function docker() { # docker() will customize the functionality of docker. ex: $ docker bash
    if [[ "$1" == "ps" ]]; then
        shift
        command docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" "$@"
    elif [[ "$1" == "bash" || "$1" == "sh" || "$1" == "shell" ]]; then
        shift
        if [ -z "${1}" ]; then
            echo "ERROR: No container specified"
            echo "Running containers:"
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
            return 1
        fi
        command docker exec -ti "$1" /bin/bash
    else
        command docker "$@"
    fi
}
