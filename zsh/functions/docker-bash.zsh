#!/bin/zsh

# Start a bash shell inside of a running Docker container
function docker-bash() {    # docker-bash() will start a bash session inside a docker container. ex: $ docker-bash portainer
    if [ -z "${1}" ]; then
        echo "ERROR: No container specified"
        echo "Running containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        return 1
    fi
    docker exec -ti "$1" /bin/bash
}