#!/bin/zsh
source "${DOTFILEDIR}/install/messages.zsh"

# Quit System Preferences.app if open
osascript -e 'tell application "System Preferences" to quit'

info "Applying macOS defaults..."
warn "Some settings require administrator credentials. You may be prompted for your password."

# General

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Dock Configuration
# Set dock position (bottom, left, right)
defaults write com.apple.dock orientation -string "bottom"

# Set dock icon size to 45px
defaults write com.apple.dock tilesize -int 45

# Automatically hide and show the dock
defaults write com.apple.dock autohide -bool true

# Set minimize/maximize window effect (genie, scale, suck)
defaults write com.apple.dock mineffect -string "genie"

# Show recent applications in Dock
defaults write com.apple.dock show-recents -bool true

# Don't rearrange spaces based on recent use
defaults write com.apple.dock mru-spaces -bool false

# Set interface style to dark, set icon and widget appearance to dark
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
defaults write NSGlobalDomain AppleIconAppearanceTheme -string RegularDark

# Set the default scroll direction to opposite of natural
defaults write -g com.apple.swipescrolldirection -bool false

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
if grep -q "enabled" <<< "$(sysadminctl -guestAccount status 2>&1)"; then
    warn "Guest account is enabled. Disabling it now..."
    sudo sysadminctl -guestAccount off
fi

# Hide the keyboard input menu from the menu bar
defaults write com.apple.TextInputMenu visible -bool false

# Disable Siri menu bar item
defaults write com.apple.Siri StatusMenuVisible -bool false

success "Defaults applied. Some changes require logout/restart to take effect."