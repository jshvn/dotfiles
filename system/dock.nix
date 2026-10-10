{ config, lib, ... }:
{
  options.dotfiles.system.dock = lib.mkOption {
    type = lib.types.bool;
    description = "Desktop & Dock, Spaces edge switch, window tiling";
  };

  config = lib.mkIf config.dotfiles.system.dock {
    system.defaults.dock = {
      orientation = "bottom";
      tilesize = 45;
      autohide = true;
      mineffect = "genie";
      show-recents = false;
      mru-spaces = false;
      wvous-br-corner = 1;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
    };
    # keys without a typed option
    system.defaults.CustomUserPreferences."com.apple.dock" = {
      wvous-br-modifier = 0;
      workspaces-edge-delay = 1000.0;
    };
    system.defaults.WindowManager = {
      EnableTilingByEdgeDrag = true;
      EnableTopTilingByEdgeDrag = true;
    };
  };
}
