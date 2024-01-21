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

##############################
###### Networking
##############################

# alias traceroute to trip
alias traceroute="$(which trip) "

local getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
local getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)

####################################################################################
#################################### macOS #########################################
####################################################################################

# Execute setup depending on the system
if [[ `uname` == "Darwin" ]]; then

    ##############################
    ###### General
    ##############################

    # open finder at current location
    alias finder="open -a Finder ./"

    # Show/hide hidden files in Finder
    alias findershow="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
    alias finderhide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

    ##############################
    ###### Networking
    ##############################

    # flush dns cache
    alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

    # get current IP information. show all: $ ips
    local activeinterfaces=$(ifconfig | pcregrep -M -o '^[^\t:]+(?=:([^\n]|\n\t)*status: active)' | tr '\n' ' ')
    local getiploc=$(ipconfig getifaddr en0)

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

    ##############################
    ###### Web Browsing
    ##############################

    alias firefox="/Applications/Firefox.app/Contents/MacOS/firefox-bin"
    alias ff="firefox"



####################################################################################
#################################### Linux #########################################
####################################################################################

else 
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
fi