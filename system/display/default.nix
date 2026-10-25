{ config, lib, ... }:
{
  options.dotfiles.system.display = lib.mkOption {
    type = lib.types.bool;
    description = "built-in panel at the More Space HiDPI preset, display sleep at 10 minutes, Universal Control off";
  };

  config = lib.mkIf config.dotfiles.system.display {
    # Lock Screen, "Turn display off on battery / on power adapter when inactive": systemsetup
    # sets every power source; task validate reads each back from pmset
    power.sleep.display = 10;
    # Displays > Advanced, "Link to Mac or iPad"; a ByHost key, so home-manager writes it
    home-manager.users.${config.system.primaryUser}.targets.darwin.currentHostDefaults."com.apple.universalcontrol".Disable =
      true;
    # a live CoreGraphics reconfiguration, not a defaults key: the Swift helper beside this file
    # is copied into the store with the generation that runs it; activation is root, the display
    # belongs to the user's session. A failure warns instead of aborting the switch (exit 2 is
    # normal with the lid closed on a dock or a mirrored display); task validate reads it back.
    system.activationScripts.postActivation.text = ''
      sudo -u ${config.system.primaryUser} -H /usr/bin/swift ${./display-mode.swift} apply \
        || echo "display: More Space not applied (exit $?; 2 = no active built-in panel)" >&2
    '';
  };
}
