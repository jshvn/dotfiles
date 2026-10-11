{ config, lib, ... }:
{
  options.dotfiles.system.updates = lib.mkOption {
    type = lib.types.bool;
    description = "macOS and App Store updates install only when asked";
  };

  config = lib.mkIf config.dotfiles.system.updates {
    system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
    # activation runs as root, so a bare domain would land in root's own preferences
    system.defaults.CustomSystemPreferences."/Library/Preferences/com.apple.commerce".AutoUpdate =
      false;
  };
}
