###############################
#  Taps                       #
###############################

# none!

###############################
#  Utilities                  #
###############################

# we want ZSH as our default shell on all environments
# and not to use system as to keep it updated with latest
brew "zsh"

# wget for pulling web data
brew "wget"

# eza as ls replacement
brew "eza"

# install git since platform git is often old
brew "git"

# glow for markdown rendering in the terminal 
# https://github.com/charmbracelet/glow
brew "glow"

# highlight for syntax highlighting in the terminal
# http://www.andre-simon.de/doku/highlight/en/highlight.php
# https://gitlab.com/saalen/highlight
brew "highlight"

# install highlighting for several commands like whois, ping, etc
# https://github.com/garabik/grc
brew "grc"

# htop is a better top
brew "htop"

# duf is a better df
brew "duf"

# domain name lookup and information
brew "whois"

# name server record lookup and information
brew "doggo"

# bat is a better cat
brew "bat"

# hugo is useful for static site generation & deployment
brew "hugo"

# ncdu is a better tool for showing directory sizes
brew "ncdu"

# tlrc is like man, but better
brew "tlrc"

# trippy is like traceroute, but better
brew "trippy"

# fd is a find replacement
brew "fd"

# antigen is a plugin manager for zsh
brew "antigen"

# jq is a command line json parser
brew "jq"

# cloudflared client
brew "cloudflared"

# fastfetch used for printing system information
# neofetch was used previously, but it has been archived as of April 26, 2024
brew "fastfetch"

# onefetch used for printing git repo information
brew "onefetch"

# bottom is like htop
brew "bottom"

# coreutils for GNU utilities like gsha256sum
brew "coreutils"

# mas is a command line interface for the Mac App Store
brew "mas" # https://github.com/mas-cli/mas 

###############################
#  macOS Apps via Cask        #
###############################

# cask list: https://formulae.brew.sh/cask/

cask_args appdir: "/Applications"

# social
cask "discord"
cask "slack"

# music 
cask "spotify"

# development
cask "sourcetree"
cask "sublime-text"
cask "visual-studio-code"

# utilities
cask "appcleaner"
cask "protonvpn"
cask "proton-mail"
cask "proton-drive"
cask "dropbox"
cask "1password"
cask "cryptomator"
cask "raycast"
cask "alcove"

# productivity
cask "standard-notes"
cask "fantastical"
cask "cardhop"
cask "microsoft-word"
cask "microsoft-excel"
cask "microsoft-powerpoint"
cask "zoom"

# games
cask "nvidia-geforce-now"

# browser
cask "firefox"

###############################
#  macOS Utilities via Cask   #
###############################

cask "1password-cli"
cask "miniconda"
cask "docker-desktop"
# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-to-warp/
cask "cloudflare-warp" 

###############################
#  macOS Apps via App Store   #
###############################

# to see existing macOS apps, run $ mas list

# Apple
mas "Xcode", id: 497799835

# Third Party
mas "Day One", id: 1055511498
mas "Magnet", id: 441258766
mas "Things", id: 904280696