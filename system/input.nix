{ config, lib, ... }:
{
  options.dotfiles.system.input = lib.mkOption {
    type = lib.types.bool;
    description = "keyboard and trackpad defaults";
  };

  config = lib.mkIf config.dotfiles.system.input {
    system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
  };
}
