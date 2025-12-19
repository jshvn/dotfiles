###############################
#  Utilities                  #
###############################

###############################
#  macOS Apps via Cask        #
###############################

# cask list: https://formulae.brew.sh/cask/

cask_args appdir: "/Applications"

# utilities
cask "dropbox"
cask "appcleaner"
cask "1password"
cask "cryptomator"

# development
cask "ghostty"


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