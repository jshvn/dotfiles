# getipv4
function getipv4() {    # getipv4() will return the current IPv4 address
    _getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
    echo $_getipv4
}

# getipv4
function getipv6() {    # getipv6() will return the current IPv4 address
    local _getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)
    echo $_getipv6
}