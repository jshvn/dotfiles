#!/usr/bin/env bash

# helper functions
disable_agent() {
    if [ -e "$1" ]; then
	    mv "$1" "$1_DISABLED" >/dev/null 2>&1 || sudo mv "$1" "$1_DISABLED" >/dev/null 2>&1
    fi 
}
unload_agent() {
	launchctl unload -w "$1" >/dev/null 2>&1
}

# Quit System Preferences.app if open
osascript -e 'tell application "System Preferences" to quit'

echo "We're setting our defaults and preferences now. Some of these may require us to use administrator credentials"
echo "to do so, so we'll ask for your user password if you haven't already authenticated with sudo."
echo "In some cases it takes awhile for changes to be made, so you may be asked for your adminstrator"
echo "credentials one more time."

# General

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Automatically hide and show the dock
defaults write com.apple.dock autohide -bool true

# Set dock icon size to 45px
defaults write com.apple.dock tilesize -int 45

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Stop photos from opening every time a device is plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Always open everything in Finder's column view.
# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Turn off the guest account
echo "If the guest account is enabled, we will disable it now"
if grep -q "enabled" <<< "$(sysadminctl -guestAccount status 2>&1)"; then
    echo "Bummer its enabled. You're going to need to give your password to complete this step"
    sudo sysadminctl -guestAccount off
fi

# Disable iTunes
disable_agent /Applications/iTunes.app/Contents/MacOS/iTunesHelper.app
unload_agent /System/Library/LaunchAgents/com.apple.rcd.plist

# Don't rearrange spaces based on recent use
defaults write com.apple.dock mru-spaces -bool false

echo "All done! Some of the defaults / preferences changes require a logout/restart to take effect."