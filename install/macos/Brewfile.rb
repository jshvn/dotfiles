###############################
#  Taps                       #
###############################

# none!

###############################
#  Utilities                  #
###############################

brew "coreutils"
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

# productivity
cask "standard-notes"
cask "fantastical"
cask "cardhop"
cask "microsoft-word"
cask "microsoft-excel"
cask "microsoft-powerpoint"

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