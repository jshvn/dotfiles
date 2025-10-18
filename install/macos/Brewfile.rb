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
cask "discord" unless system("test -e /Applications/Discord.app")
cask "slack" unless system("test -e /Applications/Slack.app")

# music 
cask "spotify" unless system("test -e /Applications/Spotify.app")

# development
cask "sourcetree" unless system("test -e /Applications/Sourcetree.app")
cask "sublime-text" unless system("test -e \"/Applications/Sublime Text.app\"")
cask "visual-studio-code" unless system("test -e \"/Applications/Visual Studio Code.app\"")

# utilities
cask "appcleaner" unless system("test -e /Applications/AppCleaner.app")
cask "protonvpn" unless system("test -e /Applications/ProtonVPN.app")
cask "proton-mail" unless system("test -e \"/Applications/Proton Mail.app\"")
cask "proton-drive" unless system("test -e \"/Applications/Proton Drive.app\"")
cask "dropbox" unless system("test -e /Applications/Dropbox.app")
cask "1password" unless system("test -e /Applications/1Password.app")
cask "cryptomator" unless system("test -e /Applications/Cryptomator.app")
cask "raycast" unless system("test -e /Applications/Raycast.app")

# productivity
cask "standard-notes" unless system("test -e \"/Applications/Standard Notes.app\"")
cask "fantastical" unless system("test -e /Applications/Fantastical.app")
cask "cardhop" unless system("test -e /Applications/Cardhop.app")
cask "microsoft-word" unless system("test -e \"/Applications/Microsoft Word.app\"")
cask "microsoft-excel" unless system("test -e \"/Applications/Microsoft Excel.app\"")
cask "microsoft-powerpoint" unless system("test -e \"/Applications/Microsoft PowerPoint.app\"")

# games
cask "nvidia-geforce-now" unless system("test -e /Applications/GeForceNOW.app")

# browser
cask "firefox" unless system("test -e /Applications/Firefox.app")

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