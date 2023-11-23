###############################
#  Taps                       #
###############################

# none!

###############################
#  Binaries                   #
###############################

brew "coreutils"
brew "mas" # https://github.com/mas-cli/mas 
# install git since macOS git is often old
brew "git"

###############################
#  macOS Apps via Cask        #
###############################

# cask list: https://formulae.brew.sh/cask/

cask_args appdir: "/Applications"

# social
cask "discord" unless system("test -e /Applications/Discord.app")

# music 
cask "spotify" unless system("test -e /Applications/Spotify.app")

# development
cask "sourcetree" unless system("test -e /Applications/Sourcetree.app")
cask "sublime-text" unless system("test -e \"/Applications/Sublime Text.app\"")
cask "visual-studio-code" unless system("test -e \"/Applications/Visual Studio Code.app\"")

# utilities
cask "cyberduck" unless system("test -e /Applications/Cyberduck.app")
cask "mountain-duck" unless system("test -e \"/Applications/Mountain Duck.app\"")
cask "appcleaner" unless system("test -e /Applications/AppCleaner.app")
cask "protonvpn" unless system("test -e /Applications/ProtonVPN.app")
cask "dropbox" unless system("test -e /Applications/Dropbox.app")
cask "1password" unless system("test -e /Applications/1Password.app")

# productivity
cask "fantastical" unless system("test -e /Applications/Fantastical.app")
cask "cardhop" unless system("test -e /Applications/Cardhop.app")
cask "microsoft-word" unless system("test -e \"/Applications/Microsoft Word.app\"")
cask "microsoft-excel" unless system("test -e \"/Applications/Microsoft Excel.app\"")
cask "microsoft-powerpoint" unless system("test -e \"/Applications/Microsoft PowerPoint.app\"")

# browser
cask "firefox" unless system("test -e /Applications/Firefox.app")

# download these directly from source
cask "1password-cli"

###############################
#  macOS Apps via App Store   #
###############################

# to see existing macOS apps, run $ mast list

# Apple
mas "Xcode", id: 497799835

# Third Party
mas "Day One", id: 1055511498
mas "Slack", id: 803453959
mas "Magnet", id: 441258766
mas "Things", id: 904280696