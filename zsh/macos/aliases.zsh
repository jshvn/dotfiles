##############################
###### General
##############################

alias ls="/usr/local/bin/gls --color=always"

# open finder at current location
alias finder="open -a Finder ./"

# going afk
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# Show/hide hidden files in Finder
alias findershow="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias finderhide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

##############################
###### Networking
##############################

# flush dns cache
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

##############################
###### Keys
##############################

# copy primary public key to clipboard
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | echo '=> Public key copied to clipboard.'"

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




