##############################
###### General
##############################

# reload current configuration
alias reload="source ~/.zshrc"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

##############################
###### Networking
##############################

# get current IP information. show all: $ ips
activeinterfaces=$(ifconfig | pcregrep -M -o '^[^\t:]+(?=:([^\n]|\n\t)*status: active)' | tr '\n' ' ')
getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)
getiploc=$(ipconfig getifaddr en0)

alias ipv4="echo IPv4: $getipv4"
alias ipv6="echo IPv6: $getipv6"
alias iploc="echo Local IP: $getiploc"
alias interfaces="echo Active Interfaces: $activeinterfaces"
alias ip="ipv4; ipv6; iploc;"
alias ips="ip; echo; ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
