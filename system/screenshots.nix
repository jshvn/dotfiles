{ config, lib, ... }:
{
  options.dotfiles.system.screenshots = lib.mkOption {
    type = lib.types.bool;
    description = "screenshot location, format, shadow, thumbnail";
  };

  config = lib.mkIf config.dotfiles.system.screenshots {
    # macOS falls back to the Desktop when the folder is missing, so the switch creates it
    home-manager.users.josh.home.file."Pictures/Screenshots/.keep".text = "";
    system.defaults.screencapture = {
      location = "/Users/josh/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
      show-thumbnail = false;
    };
  };
}
