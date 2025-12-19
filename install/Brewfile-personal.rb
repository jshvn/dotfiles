###############################
#  Utilities                  #
###############################

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

# utilities
cask "appcleaner"
cask "1password"
cask "raycast"
cask "alcove"
cask "protonvpn"
cask "proton-mail"
cask "proton-drive"
cask "dropbox"
cask "cryptomator"

# development
cask "sourcetree"
cask "sublime-text"
cask "visual-studio-code"
cask "ghostty"

# productivity
cask "standard-notes"
cask "fantastical"
cask "cardhop"
cask "microsoft-word"
cask "microsoft-excel"
cask "microsoft-powerpoint"
cask "zoom"

# browser
cask "firefox"

# games
cask "nvidia-geforce-now"

###############################
#  macOS Utilities via Cask   #
###############################

# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-to-warp/
cask "cloudflare-warp" 

cask "1password-cli"
cask "miniconda"
cask "docker-desktop"

###############################
#  macOS Apps via App Store   #
###############################

# to see existing macOS apps, run $ mas list

# Third Party
mas "Magnet", id: 441258766
mas "Things", id: 904280696