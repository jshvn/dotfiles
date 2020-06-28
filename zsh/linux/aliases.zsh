#!/bin/zsh

##############################
###### Docker
##############################

# docker helpers
alias dc="docker-compose"
alias dcu="docker-compose up -d"
alias dcd="docker-compose down"
alias dcr="docker-compose down && docker-compose up -d"
alias dcl="docker-compose logs -f"
alias dcupdate="docker-compose up -d --force-recreate --build"


##############################
###### Networking
##############################

# get current IP information. show all: $ ips
alias ipv4="echo IPv4: $getipv4"
alias ipv6="echo IPv6: $getipv6"
alias ip="ipv4; ipv6;"
alias ips="ip;"

##############################
###### Keys
##############################

# copy primary public key to clipboard
alias pubkey="more ~/.ssh/id_rsa.pub"


##############################
###### Hardware
##############################

# device information

alias gpu="sudo lshw -C display"
alias cpu="cat /proc/cpuinfo"