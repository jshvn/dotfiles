{ config, lib, ... }:
let
  user = config.system.primaryUser;
in
{
  options.dotfiles.system.dock = lib.mkOption {
    type = lib.types.bool;
    description = "Desktop & Dock, Spaces edge switch, window tiling and restore";
  };

  # the one non-bool under system: the app list is a profile's choice, the rest of the Dock is not
  options.dotfiles.system.dockApps = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf lib.types.str);
    description = "the Dock's apps, left to right; null leaves them alone";
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
      # written before Homebrew installs the casks, so on a Mac's first switch a cask app is
      # missing from the Dock until the next switch rewrites the list and restarts the Dock
      persistent-apps = config.dotfiles.system.dockApps;
      persistent-others = [
        {
          folder = {
            path = "${config.users.users.${user}.home}/Downloads";
            arrangement = "date-added";
            showas = "fan";
          };
        }
      ];
    };
    # keys without a typed option
    system.defaults.CustomUserPreferences."com.apple.dock" = {
      wvous-br-modifier = 0;
      workspaces-edge-delay = 1000.0;
    };
    # the restart dialog's "Reopen windows when logging back in"
    system.defaults.CustomUserPreferences."com.apple.loginwindow".TALLogoutSavesState = false;
    system.defaults.WindowManager = {
      EnableTilingByEdgeDrag = true;
      EnableTopTilingByEdgeDrag = true;
      EnableTiledWindowMargins = false;
    };
  };
}
