#!/bin/zsh

##############################
###### General
##############################

# this function allows you to easily list all of the available aliases
function aliaslist() {
    # grab all of the common aliases to both platforms
    local list=$(grep 'alias ' "$DOTFILEDIR/zsh/aliases.zsh" | awk '{$1=$1};1' | highlight --syntax=bash)

    echo "$list" | sort -u -d -s
}

# reload current configuration
alias reload="source ~/.zshrc"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# print the dotfile directory
alias dotfile='cd $DOTFILEDIR'
alias dotfiles='cd $DOTFILEDIR'

# enter ncdu
alias fsa='ncdu'

# shorthand for permissions function
alias perms='permissions'

# shorthands for directory listing
alias ls="$(which eza) --time-style long-iso"
alias ll='ls -alh'

# add formatting to glow command
alias glow='glow --style "$DOTFILEDIR/zsh/styles/glow_style.json" -w 120'

# open finder at current location
alias finder="open -a Finder ./"

# Show/hide hidden files in Finder
alias findershow="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias finderhide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# show last time macOS was installed
alias lastinstalled="ls -l /var/db/.AppleSetupDone"

##############################
###### Networking
##############################

local getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
local getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)

# flush dns cache
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# get current IP information. show all: $ ips
local activeinterfaces=$(ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } /status: active/ { print iface }' | tr '\n' ' ')
local getiploc=$(ipconfig getifaddr en0)

# replace traceroute with trip
alias traceroute="$(which trip) -u"

alias ipv4="echo IPv4: $getipv4"
alias ipv6="echo IPv6: $getipv6"
alias iploc="echo Local IP: $getiploc"
alias interfaces="echo Active Interfaces: $activeinterfaces"
alias ip="ipv4; ipv6; iploc;"
alias ips="ip; echo; ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }' | highlight --syntax=txt"

##############################
###### Hardware
##############################

# device information

alias gpu="system_profiler SPDisplaysDataType"
alias cpu="sysctl -n machdep.cpu.brand_string"

