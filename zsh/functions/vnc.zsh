#!/bin/zsh    

# open vnc connection
function vnc() {    # vnc() will open a VNC connection to a given host. ex: $ vnc copper.jgrid.net
    if [ -z "${1}" ]; then
        echo "ERROR: No domain specified.";
        return 1;
    fi;
    open vnc://$1
}