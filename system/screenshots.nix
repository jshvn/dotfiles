{ config, lib, ... }:
{
  options.dotfiles.system.screenshots = lib.mkOption {
    type = lib.types.bool;
    description = "screenshot location, format, shadow, thumbnail";
  };

  config = lib.mkIf config.dotfiles.system.screenshots {
    system.defaults.screencapture = {
      location = "/Users/josh/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
      show-thumbnail = false;
    };
  };
}
