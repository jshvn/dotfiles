{ config, lib, ... }:
{
  options.dotfiles.system.security = lib.mkOption {
    type = lib.types.bool;
    description = "guest account off, ImageCapture hot-plug off";
  };

  config = lib.mkIf config.dotfiles.system.security {
    system.defaults.loginwindow.GuestEnabled = false;
    # a ByHost plist: nix-darwin cannot write -currentHost, home-manager can
    home-manager.users.josh.targets.darwin.currentHostDefaults."com.apple.ImageCapture".disableHotPlug =
      true;
    # ponytail: `sysadminctl -screenLock immediate` wants the account password on a tty, which a
    # switch does not have. It stays a one-time manual step per machine.
  };
}
