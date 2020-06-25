alias reload="source ~/.zshrc"

# dns
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# finder
alias finder="open -a Finder ./"

# keys
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | echo '=> Public key copied to clipboard.'"

# ip information
alias ipv4="curl -4 simpip.com --max-time 1 --proto-default https --silent"
alias ipv6="curl -6 simpip.com --max-time 1 --proto-default https --silent"
alias ip="ipv4; ipv6"
alias iploc="ipconfig getifaddr en0"
alias ips="ip; ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# docker
alias dc="docker-compose"
alias dcu="docker-compose up -d"
alias dcd="docker-compose down"
alias dcr="docker-compose down && docker-compose up -d"
alias dcl="docker-compose logs -f"