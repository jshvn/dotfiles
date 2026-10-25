{ config, lib, ... }:
{
  options.dotfiles.system.security = lib.mkOption {
    type = lib.types.bool;
    description = "guest account off, ImageCapture hot-plug off, application firewall on, Touch ID for sudo";
  };

  config = lib.mkIf config.dotfiles.system.security {
    system.defaults.loginwindow.GuestEnabled = false;
    # a ByHost plist: nix-darwin cannot write -currentHost, home-manager can
    home-manager.users.${config.system.primaryUser}.targets.darwin.currentHostDefaults."com.apple.ImageCapture".disableHotPlug =
      true;
    # just the global switch (socketfilterfw --setglobalstate on); block-all, stealth mode and the
    # signed-software allowances stay unset, and the module leaves an unset option alone
    networking.applicationFirewall.enable = true;
    # pam_tid in /etc/pam.d/sudo_local, which macOS updates leave alone; the password still works
    security.pam.services.sudo_local.touchIdAuth = true;
    # ponytail: `sysadminctl -screenLock immediate` wants the account password on a tty, which a
    # switch does not have. It stays a one-time manual step per machine.
  };
}
