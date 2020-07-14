# Start a bash shell inside of a running Docker container
function docker-bash() {    # docker-bash() will start a bash session inside a docker container. ex: $ docker-bash portainer
  docker exec -ti $1 /bin/bash
}