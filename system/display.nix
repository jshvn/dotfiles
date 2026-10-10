{ config, lib, ... }:
{
  options.dotfiles.system.display = lib.mkOption {
    type = lib.types.bool;
    description = "built-in panel at the More Space HiDPI preset";
  };

  config = lib.mkIf config.dotfiles.system.display {
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
