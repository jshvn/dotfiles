# Start a bash shell inside of a running Docker container
docker-bash() {
  docker exec -ti $1 /bin/bash
}


# Push a local SSH public key to another machine
# https://github.com/rtomayko/dotfiles/blob/rtomayko/.bashrc
push_ssh_key() {
  local _host
  test -f ~/.ssh/id_rsa.pub || ssh-keygen -t rsa
  for _host in "$@";
  do
    echo $_host
    ssh $_host 'cat >> ~/.ssh/authorized_keys' < ~/.ssh/id_rsa.pub
  done
}